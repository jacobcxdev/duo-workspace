#include <CoreAudio/CoreAudio.h>
#include <CoreAudio/AudioServerPlugIn.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <mach/mach_time.h>
#include <math.h>
#include <pthread.h>
#include <stdatomic.h>
#include <string.h>
#include "MicrophoneBuffer.h"

enum { Device = 2, InputStream = 3, ClockPeriod = 512 };
static pthread_mutex_t samplesLock = PTHREAD_MUTEX_INITIALIZER;
static DuoMicrophoneBuffer microphone;
static uint64_t clockOrigin;
static double ticksPerFrame;
static _Atomic UInt32 references = 1, ioClients = 0, streamActive = 1;

static AudioStreamBasicDescription format(void) {
    return (AudioStreamBasicDescription){.mSampleRate=DUO_MIC_SAMPLE_RATE, .mFormatID=kAudioFormatLinearPCM,
        .mFormatFlags=kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
        .mBytesPerPacket=4, .mFramesPerPacket=1, .mBytesPerFrame=4, .mChannelsPerFrame=DUO_MIC_CHANNEL_COUNT, .mBitsPerChannel=32};
}
static int64_t currentFrame(void) { return (int64_t)((mach_absolute_time() - clockOrigin) / ticksPerFrame); }
static double currentSeconds(void) { return (double)mach_absolute_time() / (ticksPerFrame * (double)DUO_MIC_SAMPLE_RATE); }

static HRESULT query(void *, REFIID, LPVOID *);
static ULONG retainDriver(void *);
static ULONG releaseDriver(void *);
static OSStatus initialize(AudioServerPlugInDriverRef, AudioServerPlugInHostRef);
static OSStatus createDevice(AudioServerPlugInDriverRef, CFDictionaryRef, const AudioServerPlugInClientInfo *, AudioObjectID *);
static OSStatus destroyDevice(AudioServerPlugInDriverRef, AudioObjectID);
static OSStatus addClient(AudioServerPlugInDriverRef, AudioObjectID, const AudioServerPlugInClientInfo *);
static OSStatus removeClient(AudioServerPlugInDriverRef, AudioObjectID, const AudioServerPlugInClientInfo *);
static OSStatus configuration(AudioServerPlugInDriverRef, AudioObjectID, UInt64, void *);
static Boolean hasProperty(AudioServerPlugInDriverRef, AudioObjectID, pid_t, const AudioObjectPropertyAddress *);
static OSStatus settable(AudioServerPlugInDriverRef, AudioObjectID, pid_t, const AudioObjectPropertyAddress *, Boolean *);
static OSStatus dataSize(AudioServerPlugInDriverRef, AudioObjectID, pid_t, const AudioObjectPropertyAddress *, UInt32, const void *, UInt32 *);
static OSStatus getData(AudioServerPlugInDriverRef, AudioObjectID, pid_t, const AudioObjectPropertyAddress *, UInt32, const void *, UInt32, UInt32 *, void *);
static OSStatus setData(AudioServerPlugInDriverRef, AudioObjectID, pid_t, const AudioObjectPropertyAddress *, UInt32, const void *, UInt32, const void *);
static OSStatus startIO(AudioServerPlugInDriverRef, AudioObjectID, UInt32);
static OSStatus stopIO(AudioServerPlugInDriverRef, AudioObjectID, UInt32);
static OSStatus timestamp(AudioServerPlugInDriverRef, AudioObjectID, UInt32, Float64 *, UInt64 *, UInt64 *);
static OSStatus willIO(AudioServerPlugInDriverRef, AudioObjectID, UInt32, UInt32, Boolean *, Boolean *);
static OSStatus phaseIO(AudioServerPlugInDriverRef, AudioObjectID, UInt32, UInt32, UInt32, const AudioServerPlugInIOCycleInfo *);
static OSStatus doIO(AudioServerPlugInDriverRef, AudioObjectID, AudioObjectID, UInt32, UInt32, UInt32, const AudioServerPlugInIOCycleInfo *, void *, void *);

static AudioServerPlugInDriverInterface interface = {NULL, query, retainDriver, releaseDriver,
    initialize, createDevice, destroyDevice, addClient, removeClient, configuration, configuration,
    hasProperty, settable, dataSize, getData, setData, startIO, stopIO, timestamp, willIO, phaseIO, doIO, phaseIO};
static AudioServerPlugInDriverInterface *interfacePointer = &interface;
static AudioServerPlugInDriverRef driver = &interfacePointer;

__attribute__((visibility("default"))) void *DuoMicrophone_Create(CFAllocatorRef allocator, CFUUIDRef type) {
    return CFEqual(type, kAudioServerPlugInTypeUUID) ? driver : NULL;
}
static HRESULT query(void *self, REFIID id, LPVOID *out) {
    if (!out || self != driver) return E_NOINTERFACE;
    *out = NULL;
    CFUUIDRef uuid = CFUUIDCreateFromUUIDBytes(NULL, id);
    bool matches = uuid && (CFEqual(uuid, IUnknownUUID) || CFEqual(uuid, kAudioServerPlugInDriverInterfaceUUID));
    if (uuid) CFRelease(uuid);
    if (!matches) return E_NOINTERFACE;
    *out = driver; atomic_fetch_add(&references, 1); return S_OK;
}
static ULONG retainDriver(void *self) { return self == driver ? atomic_fetch_add(&references, 1) + 1 : 0; }
static ULONG releaseDriver(void *self) {
    if (self != driver) return 0;
    UInt32 count = atomic_load(&references);
    while (count && !atomic_compare_exchange_weak(&references, &count, count - 1)) {}
    return count ? count - 1 : 0;
}
static OSStatus initialize(AudioServerPlugInDriverRef self, AudioServerPlugInHostRef host) {
    if (self != driver) return kAudioHardwareBadObjectError;
    mach_timebase_info_data_t timebase; mach_timebase_info(&timebase);
    ticksPerFrame = 1000000000.0 * timebase.denom / timebase.numer / (double)DUO_MIC_SAMPLE_RATE;
    clockOrigin = mach_absolute_time(); DuoMicBufferInitialize(&microphone); return noErr;
}
static OSStatus createDevice(AudioServerPlugInDriverRef self, CFDictionaryRef desc, const AudioServerPlugInClientInfo *client, AudioObjectID *out) {
    return kAudioHardwareUnsupportedOperationError;
}
static OSStatus destroyDevice(AudioServerPlugInDriverRef self, AudioObjectID id) { return kAudioHardwareUnsupportedOperationError; }
static OSStatus addClient(AudioServerPlugInDriverRef self, AudioObjectID id, const AudioServerPlugInClientInfo *client) {
    return self == driver && id == Device ? noErr : kAudioHardwareBadObjectError;
}
static OSStatus removeClient(AudioServerPlugInDriverRef self, AudioObjectID id, const AudioServerPlugInClientInfo *client) {
    return addClient(self, id, client);
}
static OSStatus configuration(AudioServerPlugInDriverRef self, AudioObjectID id, UInt64 action, void *info) {
    return self == driver && id == Device ? noErr : kAudioHardwareBadObjectError;
}

static UInt32 propertySize(AudioObjectID id, const AudioObjectPropertyAddress *a) {
    if (!a || (id != kAudioObjectPlugInObject && id != Device && id != InputStream)) return UINT32_MAX;
    switch (a->mSelector) {
        case kAudioObjectPropertyBaseClass: case kAudioObjectPropertyClass: case kAudioObjectPropertyOwner: return sizeof(UInt32);
        case kAudioObjectPropertyName: case kAudioObjectPropertyManufacturer: return sizeof(CFStringRef);
        case kAudioObjectPropertyOwnedObjects: return id == kAudioObjectPlugInObject || id == Device ? sizeof(AudioObjectID) : 0;
    }
    if (id == kAudioObjectPlugInObject) {
        switch (a->mSelector) {
            case kAudioPlugInPropertyBundleID: case kAudioPlugInPropertyResourceBundle: return sizeof(CFStringRef);
            case kAudioPlugInPropertyDeviceList: case kAudioPlugInPropertyTranslateUIDToDevice: return sizeof(AudioObjectID);
            case kAudioPlugInPropertyBoxList: case kAudioPlugInPropertyClockDeviceList: return 0;
        }
    } else if (id == Device) {
        switch (a->mSelector) {
            case kAudioDevicePropertyDeviceUID: case kAudioDevicePropertyModelUID: return sizeof(CFStringRef);
            case kAudioDevicePropertyTransportType: case kAudioDevicePropertyClockDomain:
            case kAudioDevicePropertyDeviceIsAlive: case kAudioDevicePropertyDeviceIsRunning:
            case kAudioDevicePropertyDeviceIsRunningSomewhere: case kAudioDevicePropertyDeviceCanBeDefaultDevice:
            case kAudioDevicePropertyDeviceCanBeDefaultSystemDevice: case kAudioDevicePropertyLatency:
            case kAudioDevicePropertySafetyOffset: case kAudioDevicePropertyZeroTimeStampPeriod:
            case kAudioDevicePropertyIsHidden: case kAudioDevicePropertyBufferFrameSize: return sizeof(UInt32);
            case kAudioDevicePropertyNominalSampleRate: return sizeof(Float64);
            case kAudioDevicePropertyAvailableNominalSampleRates: case kAudioDevicePropertyBufferFrameSizeRange: return sizeof(AudioValueRange);
            case kAudioDevicePropertyRelatedDevices: return sizeof(AudioObjectID);
            case kAudioDevicePropertyStreams: return a->mScope == kAudioObjectPropertyScopeOutput ? 0 : sizeof(AudioObjectID);
            case kAudioObjectPropertyControlList: return 0;
            case kAudioDevicePropertyPreferredChannelsForStereo: return 2 * sizeof(UInt32);
            case kAudioDevicePropertyStreamConfiguration: return offsetof(AudioBufferList, mBuffers) + (a->mScope == kAudioObjectPropertyScopeOutput ? 0 : sizeof(AudioBuffer));
            case kAudioObjectPropertyCustomPropertyInfoList: return 2 * sizeof(AudioServerPlugInCustomPropertyInfo);
            case DUO_MIC_INFO: case DUO_MIC_FEED: return sizeof(CFDataRef);
        }
    } else {
        switch (a->mSelector) {
            case kAudioStreamPropertyIsActive: case kAudioStreamPropertyDirection: case kAudioStreamPropertyTerminalType:
            case kAudioStreamPropertyStartingChannel: case kAudioStreamPropertyLatency: return sizeof(UInt32);
            case kAudioStreamPropertyVirtualFormat: case kAudioStreamPropertyPhysicalFormat: return sizeof(AudioStreamBasicDescription);
            case kAudioStreamPropertyAvailableVirtualFormats: case kAudioStreamPropertyAvailablePhysicalFormats: return sizeof(AudioStreamRangedDescription);
        }
    }
    return UINT32_MAX;
}
static Boolean hasProperty(AudioServerPlugInDriverRef self, AudioObjectID id, pid_t pid, const AudioObjectPropertyAddress *a) {
    return self == driver && propertySize(id, a) != UINT32_MAX;
}
static OSStatus settable(AudioServerPlugInDriverRef self, AudioObjectID id, pid_t pid, const AudioObjectPropertyAddress *a, Boolean *out) {
    if (!out || !hasProperty(self, id, pid, a)) return kAudioHardwareUnknownPropertyError;
    *out = (id == Device && (a->mSelector == DUO_MIC_FEED || a->mSelector == kAudioDevicePropertyNominalSampleRate)) ||
        (id == InputStream && (a->mSelector == kAudioStreamPropertyIsActive || a->mSelector == kAudioStreamPropertyVirtualFormat || a->mSelector == kAudioStreamPropertyPhysicalFormat));
    return noErr;
}
static OSStatus dataSize(AudioServerPlugInDriverRef self, AudioObjectID id, pid_t pid, const AudioObjectPropertyAddress *a, UInt32 qsize, const void *q, UInt32 *out) {
    if (!out || !hasProperty(self,id,pid,a)) return kAudioHardwareUnknownPropertyError;
    *out = propertySize(id,a); return noErr;
}
static OSStatus getData(AudioServerPlugInDriverRef self, AudioObjectID id, pid_t pid, const AudioObjectPropertyAddress *a, UInt32 qsize, const void *q, UInt32 capacity, UInt32 *outSize, void *out) {
    if (!outSize || !hasProperty(self,id,pid,a)) return kAudioHardwareUnknownPropertyError;
    UInt32 size = propertySize(id,a); *outSize = size;
    if (capacity < size || (size && !out)) return kAudioHardwareBadPropertySizeError;
    if (!size) return noErr;
    memset(out, 0, size);
    UInt32 value = 0; CFStringRef string = NULL;
    switch (a->mSelector) {
        case kAudioObjectPropertyBaseClass: value = kAudioObjectClassID; break;
        case kAudioObjectPropertyClass: value = id == Device ? kAudioDeviceClassID : id == InputStream ? kAudioStreamClassID : kAudioPlugInClassID; break;
        case kAudioObjectPropertyOwner: value = id == Device ? kAudioObjectPlugInObject : id == InputStream ? Device : kAudioObjectUnknown; break;
        case kAudioObjectPropertyName: string = id == InputStream ? CFSTR("Microphone input") : CFSTR("Duo Microphone"); break;
        case kAudioObjectPropertyManufacturer: string = CFSTR("Duo Workspace"); break;
        case kAudioObjectPropertyOwnedObjects: value = id == kAudioObjectPlugInObject ? Device : InputStream; break;
        case kAudioPlugInPropertyDeviceList: case kAudioDevicePropertyRelatedDevices: value = Device; break;
        case kAudioPlugInPropertyBundleID: string = CFSTR("local.duoworkspace.microphone.driver"); break;
        case kAudioPlugInPropertyResourceBundle: string = CFSTR(""); break;
        case kAudioPlugInPropertyTranslateUIDToDevice:
            if (qsize != sizeof(CFStringRef) || !q) return kAudioHardwareBadPropertySizeError;
            if (!*(CFStringRef const *)q || CFGetTypeID(*(CFStringRef const *)q) != CFStringGetTypeID()) return kAudioHardwareIllegalOperationError;
            value = CFEqual(*(CFStringRef const *)q, CFSTR(DUO_MIC_UID)) ? Device : kAudioObjectUnknown; break;
        case kAudioDevicePropertyDeviceUID: case kAudioDevicePropertyModelUID: string = CFSTR(DUO_MIC_UID); break;
        case kAudioDevicePropertyTransportType: value = kAudioDeviceTransportTypeVirtual; break;
        case kAudioDevicePropertyDeviceIsAlive: value = 1; break;
        case kAudioDevicePropertyDeviceIsRunning: case kAudioDevicePropertyDeviceIsRunningSomewhere: value = atomic_load(&ioClients) > 0; break;
        case kAudioDevicePropertyDeviceCanBeDefaultDevice: case kAudioDevicePropertyDeviceCanBeDefaultSystemDevice: value = a->mScope == kAudioObjectPropertyScopeInput; break;
        case kAudioDevicePropertyZeroTimeStampPeriod: case kAudioDevicePropertyBufferFrameSize: value = ClockPeriod; break;
        case kAudioDevicePropertyNominalSampleRate: *(Float64 *)out = DUO_MIC_SAMPLE_RATE; return noErr;
        case kAudioDevicePropertyAvailableNominalSampleRates: *(AudioValueRange *)out = (AudioValueRange){DUO_MIC_SAMPLE_RATE,DUO_MIC_SAMPLE_RATE}; return noErr;
        case kAudioDevicePropertyBufferFrameSizeRange: *(AudioValueRange *)out = (AudioValueRange){16,DUO_MIC_MAX_FRAMES}; return noErr;
        case kAudioDevicePropertyStreams: value = InputStream; break;
        case kAudioDevicePropertyPreferredChannelsForStereo: ((UInt32 *)out)[0] = 1; ((UInt32 *)out)[1] = 1; return noErr;
        case kAudioDevicePropertyStreamConfiguration: {
            AudioBufferList *list = out; list->mNumberBuffers = a->mScope == kAudioObjectPropertyScopeOutput ? 0 : 1;
            if (list->mNumberBuffers) list->mBuffers[0].mNumberChannels = 1;
            return noErr;
        }
        case kAudioObjectPropertyCustomPropertyInfoList: {
            AudioServerPlugInCustomPropertyInfo *info = out;
            info[0] = (AudioServerPlugInCustomPropertyInfo){DUO_MIC_FEED, kAudioServerPlugInCustomPropertyDataTypeCFPropertyList, kAudioServerPlugInCustomPropertyDataTypeNone};
            info[1] = (AudioServerPlugInCustomPropertyInfo){DUO_MIC_INFO, kAudioServerPlugInCustomPropertyDataTypeCFPropertyList, kAudioServerPlugInCustomPropertyDataTypeNone};
            return noErr;
        }
        case DUO_MIC_INFO: {
            pthread_mutex_lock(&samplesLock);
            DuoMicInfo info = {.version=DUO_MIC_VERSION, .ownerPID=microphone.owned ? microphone.ownerPID : 0, .framesWritten=microphone.framesWritten};
            *(CFDataRef *)out = CFDataCreate(NULL, (const UInt8 *)&info, sizeof(info));
            pthread_mutex_unlock(&samplesLock); return noErr;
        }
        case DUO_MIC_FEED: *(CFDataRef *)out = CFDataCreate(NULL, NULL, 0); return noErr;
        case kAudioStreamPropertyIsActive: value = atomic_load(&streamActive); break;
        case kAudioStreamPropertyDirection: case kAudioStreamPropertyStartingChannel: value = 1; break;
        case kAudioStreamPropertyTerminalType: value = kAudioStreamTerminalTypeMicrophone; break;
        case kAudioStreamPropertyVirtualFormat: case kAudioStreamPropertyPhysicalFormat: *(AudioStreamBasicDescription *)out = format(); return noErr;
        case kAudioStreamPropertyAvailableVirtualFormats: case kAudioStreamPropertyAvailablePhysicalFormats:
            *(AudioStreamRangedDescription *)out = (AudioStreamRangedDescription){format(), {DUO_MIC_SAMPLE_RATE,DUO_MIC_SAMPLE_RATE}}; return noErr;
    }
    if (string) { *(CFStringRef *)out = CFRetain(string); return noErr; }
    *(UInt32 *)out = value; return noErr;
}

static OSStatus acceptAudio(pid_t pid, CFDataRef data) {
    if (!data || CFGetTypeID(data) != CFDataGetTypeID() || CFDataGetLength(data) < (CFIndex)sizeof(DuoMicHeader)) return kAudioHardwareBadPropertySizeError;
    DuoMicHeader header; memcpy(&header, CFDataGetBytePtr(data), sizeof(header));
    if (header.version != DUO_MIC_VERSION || header.reserved || header.frames > DUO_MIC_MAX_FRAMES ||
        CFDataGetLength(data) != sizeof(header) + header.frames * sizeof(float)) return kAudioHardwareIllegalOperationError;
    pthread_mutex_lock(&samplesLock);
    bool accepted = DuoMicBufferSubmit(&microphone, pid, &header, CFDataGetBytePtr(data) + sizeof(header),
                                       currentSeconds(), currentFrame());
    pthread_mutex_unlock(&samplesLock);
    return accepted ? noErr : kAudioHardwareIllegalOperationError;
}
static OSStatus setData(AudioServerPlugInDriverRef self, AudioObjectID id, pid_t pid, const AudioObjectPropertyAddress *a, UInt32 qsize, const void *q, UInt32 size, const void *data) {
    Boolean writable = false;
    if (settable(self,id,pid,a,&writable) || !writable || !data) return kAudioHardwareIllegalOperationError;
    if (id == Device && a->mSelector == DUO_MIC_FEED) {
        if (size != sizeof(CFDataRef)) return kAudioHardwareBadPropertySizeError;
        return acceptAudio(pid, *(CFDataRef const *)data);
    }
    if (id == Device && a->mSelector == kAudioDevicePropertyNominalSampleRate)
        return size == sizeof(Float64) && *(const Float64 *)data == DUO_MIC_SAMPLE_RATE ? noErr : kAudioDeviceUnsupportedFormatError;
    if (a->mSelector == kAudioStreamPropertyIsActive) {
        if (size != sizeof(UInt32)) return kAudioHardwareBadPropertySizeError;
        atomic_store(&streamActive, *(const UInt32 *)data != 0); return noErr;
    }
    if (size != sizeof(AudioStreamBasicDescription)) return kAudioHardwareBadPropertySizeError;
    AudioStreamBasicDescription expected = format();
    return memcmp(data,&expected,sizeof(expected)) == 0 ? noErr : kAudioDeviceUnsupportedFormatError;
}
static OSStatus startIO(AudioServerPlugInDriverRef self, AudioObjectID id, UInt32 client) {
    if (self != driver || id != Device) return kAudioHardwareBadObjectError;
    atomic_fetch_add(&ioClients, 1); return noErr;
}
static OSStatus stopIO(AudioServerPlugInDriverRef self, AudioObjectID id, UInt32 client) {
    if (self != driver || id != Device) return kAudioHardwareBadObjectError;
    UInt32 count = atomic_load(&ioClients);
    while (count && !atomic_compare_exchange_weak(&ioClients, &count, count-1)) {}
    return noErr;
}
static OSStatus timestamp(AudioServerPlugInDriverRef self, AudioObjectID id, UInt32 client, Float64 *sampleTime, UInt64 *hostTime, UInt64 *seed) {
    if (self != driver || id != Device || !sampleTime || !hostTime || !seed) return kAudioHardwareBadObjectError;
    int64_t sample = currentFrame() / ClockPeriod * ClockPeriod;
    *sampleTime = sample; *hostTime = clockOrigin + (uint64_t)(sample * ticksPerFrame); *seed = 1; return noErr;
}
static OSStatus willIO(AudioServerPlugInDriverRef self, AudioObjectID id, UInt32 client, UInt32 operation, Boolean *will, Boolean *inPlace) {
    if (self != driver || id != Device || !will || !inPlace) return kAudioHardwareBadObjectError;
    *will = operation == kAudioServerPlugInIOOperationReadInput; *inPlace = true; return noErr;
}
static OSStatus phaseIO(AudioServerPlugInDriverRef self, AudioObjectID id, UInt32 client, UInt32 operation, UInt32 frames, const AudioServerPlugInIOCycleInfo *cycle) {
    return self == driver && id == Device ? noErr : kAudioHardwareBadObjectError;
}
static OSStatus doIO(AudioServerPlugInDriverRef self, AudioObjectID id, AudioObjectID stream, UInt32 client, UInt32 operation, UInt32 frames, const AudioServerPlugInIOCycleInfo *cycle, void *buffer, void *secondary) {
    if (self != driver || id != Device || stream != InputStream || !buffer || !cycle || frames > 16384) return kAudioHardwareIllegalOperationError;
    if (operation != kAudioServerPlugInIOOperationReadInput) return noErr;
    memset(buffer,0,frames*sizeof(float));
    if (!atomic_load(&streamActive) || !isfinite(cycle->mInputTime.mSampleTime) || cycle->mInputTime.mSampleTime < 0) return noErr;
    // The real-time callback never waits for the network writer or allocates.
    if (pthread_mutex_trylock(&samplesLock)) return noErr;
    DuoMicBufferRead(&microphone, buffer, frames, (int64_t)cycle->mInputTime.mSampleTime, currentSeconds());
    pthread_mutex_unlock(&samplesLock); return noErr;
}
