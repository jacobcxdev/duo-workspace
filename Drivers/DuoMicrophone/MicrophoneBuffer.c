#include "MicrophoneBuffer.h"
#include <math.h>
#include <string.h>

static void clearSamples(DuoMicrophoneBuffer *buffer) {
    memset(buffer->stamps, 0xff, sizeof(buffer->stamps));
    buffer->writeFrame = 0;
}
void DuoMicBufferInitialize(DuoMicrophoneBuffer *buffer) {
    memset(buffer, 0, sizeof(*buffer));
    clearSamples(buffer);
}
bool DuoMicBufferSubmit(DuoMicrophoneBuffer *buffer, int32_t pid, const DuoMicHeader *header,
                        const void *samples, double now, int64_t nowFrame) {
    if (header->version != DUO_MIC_VERSION || header->reserved || header->frames > DUO_MIC_MAX_FRAMES ||
        header->command < DUO_MIC_OPEN || header->command > DUO_MIC_CLOSE ||
        (header->command != DUO_MIC_WRITE && header->frames) || (header->frames && !samples)) return false;
    bool same = buffer->owned && !memcmp(buffer->ownerToken, header->token, 16) &&
        (!buffer->ownerPID || buffer->ownerPID == pid);
    if (header->command == DUO_MIC_OPEN) {
        if (buffer->owned && !same && now - buffer->lastWrite < 1) return false;
        buffer->owned = true; buffer->ownerPID = pid; memcpy(buffer->ownerToken, header->token, 16);
        buffer->lastWrite = now; buffer->framesWritten = 0; clearSamples(buffer);
    } else if (!same) return false;
    else if (header->command == DUO_MIC_CLOSE) { buffer->owned = false; clearSamples(buffer); }
    else {
        if (buffer->writeFrame < nowFrame + 240 || buffer->writeFrame > nowFrame + 24000)
            buffer->writeFrame = nowFrame + 1920;
        for (uint32_t index = 0; index < header->frames; ++index) {
            float value; memcpy(&value, (const uint8_t *)samples + index * sizeof(float), sizeof(value));
            if (!isfinite(value)) value = 0;
            int64_t frame = buffer->writeFrame + index;
            uint32_t slot = (uint32_t)(frame % DuoMicRingFrames);
            buffer->samples[slot] = fmaxf(-1, fminf(1, value)); buffer->stamps[slot] = frame;
        }
        buffer->writeFrame += header->frames; buffer->framesWritten += header->frames; buffer->lastWrite = now;
    }
    return true;
}
void DuoMicBufferRead(const DuoMicrophoneBuffer *buffer, float *output, uint32_t frames,
                      int64_t firstFrame, double now) {
    memset(output, 0, frames * sizeof(float));
    if (!buffer->owned || now - buffer->lastWrite >= .25) return;
    for (uint32_t index = 0; index < frames; ++index) {
        int64_t frame = firstFrame + index; uint32_t slot = (uint32_t)(frame % DuoMicRingFrames);
        if (buffer->stamps[slot] == frame) output[index] = buffer->samples[slot];
    }
}
