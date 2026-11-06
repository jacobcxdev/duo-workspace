#ifndef DUO_MICROPHONE_BUFFER_H
#define DUO_MICROPHONE_BUFFER_H
#include <stdbool.h>
#include <stdint.h>
#include "DuoMicrophoneProtocol.h"

enum { DuoMicRingFrames = DUO_MIC_SAMPLE_RATE * 2 };
typedef struct {
    float samples[DuoMicRingFrames];
    int64_t stamps[DuoMicRingFrames];
    uint8_t ownerToken[16];
    int32_t ownerPID;
    bool owned;
    double lastWrite;
    uint64_t framesWritten;
    int64_t writeFrame;
} DuoMicrophoneBuffer;

void DuoMicBufferInitialize(DuoMicrophoneBuffer *buffer);
bool DuoMicBufferSubmit(DuoMicrophoneBuffer *buffer, int32_t pid, const DuoMicHeader *header,
                        const void *samples, double now, int64_t nowFrame);
void DuoMicBufferRead(const DuoMicrophoneBuffer *buffer, float *output, uint32_t frames,
                      int64_t firstFrame, double now);
#endif
