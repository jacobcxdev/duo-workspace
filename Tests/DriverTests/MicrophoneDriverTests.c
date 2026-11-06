#include <assert.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
#include <CoreAudio/AudioServerPlugIn.h>
#include "../../Drivers/DuoMicrophone/MicrophoneBuffer.h"

extern void *DuoMicrophone_Create(CFAllocatorRef allocator, CFUUIDRef type);
static DuoMicrophoneBuffer microphone;
static bool submit(int32_t pid, uint32_t command, uint8_t token, const float *input, uint32_t frames, double now) {
    DuoMicHeader header = {.version=DUO_MIC_VERSION, .command=command, .frames=frames};
    memset(header.token, token, sizeof(header.token));
    return DuoMicBufferSubmit(&microphone,pid,&header,input,now,(int64_t)(now*DUO_MIC_SAMPLE_RATE));
}
int main(void) {
    AudioServerPlugInDriverRef driver = DuoMicrophone_Create(NULL,kAudioServerPlugInTypeUUID);
    AudioServerPlugInHostInterface hostInterface={0};
    assert(driver && (*driver)->Initialize(driver,&hostInterface)==noErr);
    assert(!DuoMicrophone_Create(NULL,kAudioServerPlugInDriverInterfaceUUID));
    AudioObjectPropertyAddress address = {kAudioPlugInPropertyDeviceList,kAudioObjectPropertyScopeGlobal,0};
    UInt32 bytes=0; AudioObjectID device=0,stream=0;
    assert((*driver)->GetPropertyDataSize(driver,kAudioObjectPlugInObject,11,&address,0,NULL,&bytes)==noErr && bytes==sizeof(device));
    assert((*driver)->GetPropertyData(driver,kAudioObjectPlugInObject,11,&address,0,NULL,bytes,&bytes,&device)==noErr && device);
    address=(AudioObjectPropertyAddress){kAudioDevicePropertyStreams,kAudioObjectPropertyScopeInput,0};
    assert((*driver)->GetPropertyData(driver,device,11,&address,0,NULL,sizeof(stream),&bytes,&stream)==noErr && stream);
    address.mScope=kAudioObjectPropertyScopeOutput;
    assert((*driver)->GetPropertyDataSize(driver,device,11,&address,0,NULL,&bytes)==noErr && bytes==0);
    address=(AudioObjectPropertyAddress){DUO_MIC_FEED,kAudioObjectPropertyScopeGlobal,0};
    DuoMicHeader header={.version=DUO_MIC_VERSION,.command=DUO_MIC_OPEN};
    CFDataRef packet=CFDataCreate(NULL,(const UInt8 *)&header,sizeof(header));
    assert((*driver)->SetPropertyData(driver,device,11,&address,0,NULL,sizeof(packet),&packet)==noErr);
    assert((*driver)->SetPropertyData(driver,device,11,&address,0,NULL,0,&packet)!=noErr);
    CFRelease(packet);
    Float64 sampleTime; UInt64 hostTime,seed;
    assert((*driver)->GetZeroTimeStamp(driver,device,1,&sampleTime,&hostTime,&seed)==noErr && seed==1 && hostTime>0);

    DuoMicBufferInitialize(&microphone);
    assert(submit(11,DUO_MIC_OPEN,42,NULL,0,0));
    assert(!submit(12,DUO_MIC_OPEN,99,NULL,0,.01));
    float input[960],output[960],second[960];
    for (unsigned i=0;i<960;i++) input[i]=(float)i/1920;
    assert(!submit(12,DUO_MIC_WRITE,42,input,960,0));
    assert(!submit(11,DUO_MIC_WRITE,99,input,960,0));
    assert(submit(11,DUO_MIC_WRITE,42,input,960,0));
    DuoMicBufferRead(&microphone,output,960,1920,.01);
    DuoMicBufferRead(&microphone,second,960,1920,.01);
    assert(!memcmp(input,output,sizeof(input)) && !memcmp(output,second,sizeof(output)));
    assert(submit(11,DUO_MIC_CLOSE,42,NULL,0,.02));
    DuoMicBufferRead(&microphone,output,960,1920,.02);
    for (unsigned i=0;i<960;i++) assert(output[i]==0);
    assert(submit(11,DUO_MIC_OPEN,42,NULL,0,1));
    input[0]=NAN;input[1]=4;input[2]=-4;
    assert(submit(11,DUO_MIC_WRITE,42,input,960,1));
    DuoMicBufferRead(&microphone,output,960,49920,1.01);
    assert(output[0]==0 && output[1]==1 && output[2]==-1);
    DuoMicBufferRead(&microphone,output,960,49920,1.3);
    for (unsigned i=0;i<960;i++) assert(output[i]==0);
    assert(!submit(12,DUO_MIC_OPEN,99,NULL,0,1.9));
    assert(submit(12,DUO_MIC_OPEN,99,NULL,0,2.1));
    puts("Duo Microphone checks passed: HAL input-only ABI/clock, ownership, fan-out, mute, timeout, PCM bounds.");
    return 0;
}
