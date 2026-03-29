#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

#include <iostream>

@interface Renderer : NSObject <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@end

@implementation Renderer

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
    (void)view;
    (void)size;
}

- (void)drawInMTKView:(MTKView *)view
{
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if (renderPassDescriptor == nil) {
        return;
    }

    id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder setRenderPipelineState:self.pipelineState];

    // Interleaved vertices: position + color.
    static const float vertices[] = {
         0.0f,  0.7f, 0.0f, 1.0f,   1.0f, 0.0f, 0.0f, 1.0f,
        -0.7f, -0.7f, 0.0f, 1.0f,   0.0f, 1.0f, 0.0f, 1.0f,
         0.7f, -0.7f, 0.0f, 1.0f,   0.0f, 0.0f, 1.0f, 1.0f
    };

    [renderEncoder setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [renderEncoder endEncoding];

    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

@end

int main(int argc, const char *argv[])
{
    (void)argc;
    (void)argv;

    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        NSRect screenRect = [[NSScreen mainScreen] frame];
        NSRect windowRect = NSMakeRect(
            (screenRect.size.width - 800) / 2,
            (screenRect.size.height - 600) / 2,
            800,
            600
        );

        NSWindow *window = [[NSWindow alloc]
            initWithContentRect:windowRect
                      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
                        backing:NSBackingStoreBuffered
                          defer:NO];
        [window setTitle:@"Metal Triangle (C++)"];
        [window makeKeyAndOrderFront:nil];

        NSView *contentView = [window contentView];
        MTKView *metalView = [[MTKView alloc] initWithFrame:[contentView bounds]];
        metalView.device = MTLCreateSystemDefaultDevice();
        metalView.paused = YES;
        metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        metalView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

        if (!metalView.device) {
            std::cerr << "Metal is not supported on this device." << std::endl;
            return 1;
        }

        Renderer *renderer = [[Renderer alloc] init];
        renderer.commandQueue = [metalView.device newCommandQueue];

        NSString *shaderSource =
            @"#include <metal_stdlib>\n"
             "using namespace metal;\n"
             "struct VertexIn {\n"
             "    float4 position;\n"
             "    float4 color;\n"
             "};\n"
             "struct VertexOut {\n"
             "    float4 position [[position]];\n"
             "    float4 color;\n"
             "};\n"
             "vertex VertexOut vertex_main(uint vid [[vertex_id]], constant VertexIn *vertices [[buffer(0)]]) {\n"
             "    VertexOut out;\n"
             "    out.position = vertices[vid].position;\n"
             "    out.color = vertices[vid].color;\n"
             "    return out;\n"
             "}\n"
             "fragment float4 fragment_main(VertexOut in [[stage_in]]) {\n"
             "    return in.color;\n"
             "}\n";

        NSError *error = nil;
        id<MTLLibrary> library = [metalView.device newLibraryWithSource:shaderSource options:nil error:&error];
        if (!library) {
            std::cerr << "Shader compilation failed: "
                      << [[error localizedDescription] UTF8String] << std::endl;
            return 1;
        }

        MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"vertex_main"];
        pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"fragment_main"];
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat;

        renderer.pipelineState = [metalView.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
        if (!renderer.pipelineState) {
            std::cerr << "Pipeline creation failed: "
                      << [[error localizedDescription] UTF8String] << std::endl;
            return 1;
        }

        metalView.delegate = renderer;
        [contentView addSubview:metalView];

        [NSApp activateIgnoringOtherApps:YES];

        bool running = true;
        while (running && [window isVisible]) {
            NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                                untilDate:[NSDate dateWithTimeIntervalSinceNow:0.0]
                                                   inMode:NSDefaultRunLoopMode
                                                  dequeue:YES];
            if (event) {
                [NSApp sendEvent:event];
            }

            [metalView draw];
        }
    }

    return 0;
}
