#ifndef DUO_MICROPHONE_BRIDGE_H
#define DUO_MICROPHONE_BRIDGE_H
#include <CoreAudio/CoreAudio.h>
#include <stdint.h>

#include "DuoMicrophoneProtocol.h"

AudioObjectID DuoMicFindDevice(void);
OSStatus DuoMicSend(AudioObjectID device, uint32_t command, const uint8_t *token,
                    const float *samples, uint32_t frames);
#endif
