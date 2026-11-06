#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "VirtualDisplayBridge.h"

// Private macOS display API, isolated to the host.
@interface DuoDisplayDescriptor : NSObject
@property(copy) NSString *name;
@property unsigned int maxPixelsWide, maxPixelsHigh, vendorID, productID, serialNum;
@property CGSize sizeInMillimeters;
@property(retain) dispatch_queue_t queue;
@end
@interface DuoDisplayMode : NSObject
- (instancetype)initWithWidth:(NSUInteger)width height:(NSUInteger)height refreshRate:(CGFloat)rate;
@end
@interface DuoDisplaySettings : NSObject
@property unsigned int hiDPI;
@property(retain) NSArray *modes;
@end
@interface DuoDisplay : NSObject
- (instancetype)initWithDescriptor:(id)descriptor;
- (BOOL)applySettings:(id)settings;
@property(readonly) CGDirectDisplayID displayID;
@end

@interface DuoDisplayOwner : NSObject
@property(strong) DuoDisplay *display;
@end
@implementation DuoDisplayOwner
@end

static bool DuoSizeValid(uint32_t width, uint32_t height, uint32_t scale) {
    return (scale == 1 || scale == 2) && width >= 320 && height >= 240 && width <= 4096 / scale && height <= 4096 / scale;
}

bool DuoVirtualDisplayAvailable(void) {
    return NSClassFromString(@"CGVirtualDisplay") && NSClassFromString(@"CGVirtualDisplayDescriptor") && NSClassFromString(@"CGVirtualDisplayMode") && NSClassFromString(@"CGVirtualDisplaySettings");
}

bool DuoApplyDisplaySize(void *handle, uint32_t width, uint32_t height, uint32_t scale) {
    if (!handle || !DuoSizeValid(width, height, scale) || !NSThread.isMainThread) return false;
    @autoreleasepool { @try {
        DuoDisplayOwner *owner = (__bridge DuoDisplayOwner *)handle;
        DuoDisplaySettings *settings = [[NSClassFromString(@"CGVirtualDisplaySettings") alloc] init];
        settings.hiDPI = scale == 2 ? 1 : 0;
        settings.modes = @[[[NSClassFromString(@"CGVirtualDisplayMode") alloc] initWithWidth:width height:height refreshRate:60]];
        return [owner.display applySettings:settings];
    } @catch (NSException *exception) { return false; } }
}

void *DuoCreateAdaptiveDisplay(uint32_t width, uint32_t height, uint32_t scale, uint32_t *displayID) {
    if (!displayID || !DuoSizeValid(width, height, scale) || !DuoVirtualDisplayAvailable() || !NSThread.isMainThread) return NULL;
    @autoreleasepool { @try {
        DuoDisplayDescriptor *d = [[NSClassFromString(@"CGVirtualDisplayDescriptor") alloc] init];
        d.name = @"Duo Workspace (temporary)";
        // Capacity is fixed at creation; both axes must allow later rotation.
        d.maxPixelsWide = 4096; d.maxPixelsHigh = 4096;
        d.vendorID = 0x4455; d.productID = 1; d.serialNum = arc4random_uniform(UINT32_MAX - 1) + 1;
        d.sizeInMillimeters = CGSizeMake(220, 140); d.queue = dispatch_get_main_queue();
        DuoDisplayOwner *owner = [DuoDisplayOwner new];
        owner.display = [[NSClassFromString(@"CGVirtualDisplay") alloc] initWithDescriptor:d];
        if (!owner.display) return NULL;
        if (!DuoApplyDisplaySize((__bridge void *)owner, width, height, scale)) return NULL;
        *displayID = owner.display.displayID;
        return (__bridge_retained void *)owner;
    } @catch (NSException *exception) { return NULL; } }
}

int32_t DuoSelectDisplaySize(void *handle, uint32_t width, uint32_t height, uint32_t scale) {
    if (!handle || !DuoSizeValid(width, height, scale) || !NSThread.isMainThread) return DuoDisplaySelectionFailed;
    @autoreleasepool {
        DuoDisplayOwner *owner = (__bridge DuoDisplayOwner *)handle;
        CGDirectDisplayID id = owner.display.displayID;
        CGDisplayModeRef current = CGDisplayCopyDisplayMode(id);
        bool matches = current && CGDisplayModeGetWidth(current) == width && CGDisplayModeGetHeight(current) == height
            && CGDisplayModeGetPixelWidth(current) == width * scale && CGDisplayModeGetPixelHeight(current) == height * scale;
        if (current) CGDisplayModeRelease(current);
        if (matches) return DuoDisplaySelectionReady;
        CFDictionaryRef options = (__bridge CFDictionaryRef)@{(__bridge NSString *)kCGDisplayShowDuplicateLowResolutionModes: @YES};
        CFArrayRef modes = CGDisplayCopyAllDisplayModes(id, options);
        if (!modes) return DuoDisplaySelectionPending;
        CGDisplayModeRef target = NULL;
        for (CFIndex index = 0; index < CFArrayGetCount(modes); index++) {
            CGDisplayModeRef mode = (CGDisplayModeRef)CFArrayGetValueAtIndex(modes, index);
            if (CGDisplayModeGetWidth(mode) == width && CGDisplayModeGetHeight(mode) == height
                && CGDisplayModeGetPixelWidth(mode) == width * scale && CGDisplayModeGetPixelHeight(mode) == height * scale) {
                target = mode; break;
            }
        }
        int32_t result = DuoDisplaySelectionPending;
        if (target) {
            CGDisplayConfigRef config = NULL;
            CGError error = CGBeginDisplayConfiguration(&config);
            if (error == kCGErrorSuccess) {
                error = CGConfigureDisplayWithDisplayMode(config, id, target, NULL);
                if (error == kCGErrorSuccess) error = CGCompleteDisplayConfiguration(config, kCGConfigureForSession);
                else CGCancelDisplayConfiguration(config);
            }
            result = error == kCGErrorSuccess ? DuoDisplaySelectionConfigured : DuoDisplaySelectionFailed;
        }
        // CoreGraphics mode objects are scoped to this operation, never held
        // across a sleep or past release of the virtual display.
        CFRelease(modes);
        return result;
    }
}

void DuoReleaseVirtualDisplay(void *handle) {
    if (!handle) return;
    @autoreleasepool {
        DuoDisplayOwner *owner = (__bridge_transfer DuoDisplayOwner *)handle;
        owner.display = nil;
    }
}
