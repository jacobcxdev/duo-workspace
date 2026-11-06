#include "DuoMicrophoneBridge.h"
#include <CoreFoundation/CoreFoundation.h>
#include <string.h>

AudioObjectID DuoMicFindDevice(void) {
    CFStringRef uid = CFSTR(DUO_MIC_UID);
    AudioObjectPropertyAddress address = {kAudioHardwarePropertyTranslateUIDToDevice,
        kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
    AudioObjectID device = kAudioObjectUnknown;
    UInt32 size = sizeof(device);
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, sizeof(uid), &uid,
                                  &size, &device) != noErr) return kAudioObjectUnknown;
    AudioObjectPropertyAddress infoAddress = {DUO_MIC_INFO, kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain};
    CFDataRef data = NULL; size = sizeof(data);
    if (AudioObjectGetPropertyData(device, &infoAddress, 0, NULL, &size, &data) != noErr || !data)
        return kAudioObjectUnknown;
    DuoMicInfo info = {0};
    if (CFGetTypeID(data) == CFDataGetTypeID() && CFDataGetLength(data) == sizeof(info))
        memcpy(&info, CFDataGetBytePtr(data), sizeof(info));
    CFRelease(data);
    return info.version == DUO_MIC_VERSION ? device : kAudioObjectUnknown;
}

OSStatus DuoMicSend(AudioObjectID device, uint32_t command, const uint8_t *token,
                    const float *samples, uint32_t frames) {
    if (!token || frames > DUO_MIC_MAX_FRAMES || (frames && !samples)) return kAudio_ParamError;
    uint8_t bytes[sizeof(DuoMicHeader) + DUO_MIC_MAX_FRAMES * sizeof(float)];
    DuoMicHeader header = {.version = DUO_MIC_VERSION, .command = command, .frames = frames};
    memcpy(header.token, token, 16); memcpy(bytes, &header, sizeof(header));
    if (frames) memcpy(bytes + sizeof(header), samples, frames * sizeof(float));
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, bytes, sizeof(header) + frames * sizeof(float));
    if (!data) return kAudio_MemFullError;
    AudioObjectPropertyAddress address = {DUO_MIC_FEED, kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain};
    OSStatus result = AudioObjectSetPropertyData(device, &address, 0, NULL, sizeof(data), &data);
    CFRelease(data);
    return result;
}
