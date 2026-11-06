#ifndef DUO_MICROPHONE_PROTOCOL_H
#define DUO_MICROPHONE_PROTOCOL_H
#include <stdint.h>

#define DUO_MIC_UID "local.duoworkspace.microphone"
#define DUO_MIC_VERSION 1
#define DUO_MIC_FEED 'dmif'
#define DUO_MIC_INFO 'dmii'
#define DUO_MIC_SAMPLE_RATE 48000
#define DUO_MIC_CHANNEL_COUNT 1
#define DUO_MIC_WIRE_BITS_PER_SAMPLE 16
#define DUO_MIC_MAX_FRAMES 4096
#define DUO_MIC_OPEN 1u
#define DUO_MIC_WRITE 2u
#define DUO_MIC_CLOSE 3u

typedef struct {
    uint32_t version;
    uint32_t command;
    uint8_t token[16];
    uint32_t frames;
    uint32_t reserved;
} DuoMicHeader;

typedef struct {
    uint32_t version;
    int32_t ownerPID;
    uint64_t framesWritten;
} DuoMicInfo;

#endif
