#include <CoreAudio/CoreAudio.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <math.h>
#include <stdatomic.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "DuoMicrophoneBridge.h"

static float recording[192000];
static _Atomic unsigned count;
static OSStatus recordAudio(AudioDeviceID device, const AudioTimeStamp *now, const AudioBufferList *input,
                           const AudioTimeStamp *inputTime, AudioBufferList *output,
                           const AudioTimeStamp *outputTime, void *context) {
    if (!input || !input->mNumberBuffers || !input->mBuffers[0].mData) return noErr;
    unsigned offset=atomic_load(&count), frames=input->mBuffers[0].mDataByteSize/sizeof(float);
    if (frames>192000-offset) frames=192000-offset;
    memcpy(recording+offset,input->mBuffers[0].mData,frames*sizeof(float));
    atomic_store(&count,offset+frames); return noErr;
}
int main(int argc, char **argv) {
    AudioObjectID device=DuoMicFindDevice();
    if (!device) { puts("{\"passed\":false,\"reason\":\"device missing\"}"); return 2; }
    AudioDeviceIOProcID proc=NULL;
    OSStatus status=AudioDeviceCreateIOProcID(device,recordAudio,NULL,&proc);
    if (!status) status=AudioDeviceStart(device,proc);
    if (status) { printf("{\"passed\":false,\"audioStatus\":%d}\n",(int)status); return 3; }
    if (argc>1 && !strcmp(argv[1],"listen")) {
        sleep(3);
        AudioDeviceStop(device,proc); AudioDeviceDestroyIOProcID(device,proc);
        unsigned total=atomic_load(&count); double sum=0, peak=0;
        for (unsigned i=0;i<total;i++) { sum+=recording[i]*recording[i]; if (fabs(recording[i])>peak) peak=fabs(recording[i]); }
        printf("{\"device\":%u,\"samples\":%u,\"rms\":%.8f,\"peak\":%.8f}\n",device,total,sqrt(sum/(total?total:1)),peak);
        return total>DUO_MIC_SAMPLE_RATE?0:4;
    }
    UInt8 token[16]; memset(token,79,sizeof(token));
    status=DuoMicSend(device, DUO_MIC_OPEN,token,NULL,0);
    mach_timebase_info_data_t timebase; mach_timebase_info(&timebase);
    double ticksPerSecond=1e9*timebase.denom/timebase.numer;
    UInt64 origin=mach_absolute_time();
    float block[960];
    for (unsigned packet=0;packet<100 && !status;packet++) {
        for (unsigned i=0;i<960;i++) block[i]=.3f*sinf(2*M_PI*880*(packet*960+i)/(double)DUO_MIC_SAMPLE_RATE);
        status=DuoMicSend(device, DUO_MIC_WRITE,token,block,960);
        mach_wait_until(origin+(UInt64)((packet+1)*.02*ticksPerSecond));
    }
    unsigned end=atomic_load(&count);
    OSStatus stopped=DuoMicSend(device, DUO_MIC_CLOSE,token,NULL,0);
    usleep(350000);
    AudioDeviceStop(device,proc); AudioDeviceDestroyIOProcID(device,proc);
    unsigned total=atomic_load(&count), begin=4800, finish=end>2400?end-2400:0;
    double energy=0, real=0, imaginary=0, tail=0;
    for (unsigned i=begin;i<finish;i++) {
        energy+=recording[i]*recording[i];
        real+=recording[i]*cos(2*M_PI*880*i/(double)DUO_MIC_SAMPLE_RATE);
        imaginary+=recording[i]*sin(2*M_PI*880*i/(double)DUO_MIC_SAMPLE_RATE);
    }
    unsigned length=finish>begin?finish-begin:1;
    for (unsigned i=end+4800;i<total;i++) tail+=recording[i]*recording[i];
    double rms=sqrt(energy/length), tone=2*hypot(real,imaginary)/length;
    double tailRMS=sqrt(tail/(total>end+4800?total-end-4800:1));
    int passed=!status && !stopped && rms>.1 && rms<.3 && tone>.1 && tailRMS<.00001 && total>end+9600;
    printf("{\"passed\":%s,\"device\":%u,\"samples\":%u,\"rms\":%.6f,\"toneAmplitude\":%.6f,\"stoppedRMS\":%.8f,\"writeStatus\":%d}\n",
           passed?"true":"false",device,total,rms,tone,tailRMS,(int)status);
    return passed?0:4;
}
