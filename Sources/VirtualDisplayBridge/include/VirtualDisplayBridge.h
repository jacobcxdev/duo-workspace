#include <stdint.h>
#include <stdbool.h>

bool DuoVirtualDisplayAvailable(void);
void *DuoCreateAdaptiveDisplay(uint32_t width, uint32_t height, uint32_t scale, uint32_t *displayID);
bool DuoApplyDisplaySize(void *handle, uint32_t width, uint32_t height, uint32_t scale);
enum { DuoDisplaySelectionFailed = -1, DuoDisplaySelectionPending = 0,
       DuoDisplaySelectionReady = 1, DuoDisplaySelectionConfigured = 2 };
int32_t DuoSelectDisplaySize(void *handle, uint32_t width, uint32_t height, uint32_t scale);
void DuoReleaseVirtualDisplay(void *handle);
