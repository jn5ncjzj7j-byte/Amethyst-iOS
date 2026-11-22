#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalFX/MetalFX.h>

void AMELogFrameGenerationCapabilities(void) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        NSLog(@"[MisgFrameGen] No default Metal device is available");
        return;
    }

    NSLog(@"[MisgFrameGen] Metal device: %@", device.name);

    if (@available(iOS 26.0, *)) {
        BOOL supported = [MTLFXFrameInterpolatorDescriptor supportsDevice:device];
        BOOL metal4Supported = [MTLFXFrameInterpolatorDescriptor supportsMetal4FX:device];
        NSLog(@"[MisgFrameGen] MetalFX frame interpolation: %@", supported ? @"supported" : @"not supported");
        NSLog(@"[MisgFrameGen] Metal 4 frame interpolation: %@", metal4Supported ? @"supported" : @"not supported");
    } else {
        NSLog(@"[MisgFrameGen] MetalFX frame interpolation capability query requires iOS 26 or newer");
    }

    [device release];
}
