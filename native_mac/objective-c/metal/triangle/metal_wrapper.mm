#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#include "metal_wrapper.h"

@interface MetalViewDelegate : NSObject <MTKViewDelegate>
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@end

@implementation MetalViewDelegate

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    
    if (renderPassDescriptor == nil) {
        return;
    }
    
    id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder setRenderPipelineState:self.pipelineState];
    
    // Interleaved vertex data: position(x,y,z,w) + color(r,g,b,a)
    float vertices[] = {
         0.0f,  0.7f, 0.0f, 1.0f, 1.0f, 0.0f, 0.0f, 1.0f,
        -0.7f, -0.7f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f, 1.0f,
         0.7f, -0.7f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 1.0f
    };
    
    [renderEncoder setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

@end

typedef struct {
    NSWindow *window;
    MTKView *metalView;
    MetalViewDelegate *delegate;
} MetalContextInternal;

MetalContext metal_create() {
    MetalContextInternal *ctx = (MetalContextInternal *)malloc(sizeof(MetalContextInternal));

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    // Create window
    NSRect screenRect = [[NSScreen mainScreen] frame];
    NSRect windowRect = NSMakeRect(
        (screenRect.size.width - 800) / 2,
        (screenRect.size.height - 600) / 2,
        800,
        600
    );
    
    ctx->window = [[NSWindow alloc]
        initWithContentRect:windowRect
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered
        defer:NO
    ];
    [ctx->window setTitle:@"Metal Triangle"];
    [ctx->window makeKeyAndOrderFront:nil];
    
    // Create Metal view
    NSView *contentView = [ctx->window contentView];
    ctx->metalView = [[MTKView alloc] initWithFrame:[contentView bounds]];
    ctx->metalView.device = MTLCreateSystemDefaultDevice();
    ctx->metalView.paused = YES;
    ctx->metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    ctx->metalView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    if (!ctx->metalView.device) {
        NSLog(@"Metal is not supported on this device");
        return NULL;
    }
    
    // Setup delegate
    ctx->delegate = [[MetalViewDelegate alloc] init];
    ctx->delegate.device = ctx->metalView.device;
    ctx->delegate.commandQueue = [ctx->metalView.device newCommandQueue];
    
    // Compile shaders
    NSString *shaderSource = @
    "#include <metal_stdlib>\n"
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
    id<MTLLibrary> library = [ctx->metalView.device newLibraryWithSource:shaderSource options:nil error:&error];
    
    if (!library) {
        NSLog(@"Shader compilation failed: %@", error);
        return NULL;
    }
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"vertex_main"];
    pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    pipelineDescriptor.colorAttachments[0].pixelFormat = ctx->metalView.colorPixelFormat;
    
    ctx->delegate.pipelineState = [ctx->metalView.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    
    if (!ctx->delegate.pipelineState) {
        NSLog(@"Pipeline creation failed: %@", error);
        return NULL;
    }
    
    ctx->metalView.delegate = ctx->delegate;
    [[ctx->window contentView] addSubview:ctx->metalView];
    
    // Activate the application
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    return (MetalContext)ctx;
}

void metal_render(MetalContext ctx) {
    MetalContextInternal *context = (MetalContextInternal *)ctx;

    NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                        untilDate:[NSDate dateWithTimeIntervalSinceNow:0.0]
                                           inMode:NSDefaultRunLoopMode
                                          dequeue:YES];
    if (event) {
        [NSApp sendEvent:event];
    }

    [context->metalView draw];
}

bool metal_is_running(MetalContext ctx) {
    MetalContextInternal *context = (MetalContextInternal *)ctx;
    return context != NULL && context->window != nil && [context->window isVisible];
}

void metal_destroy(MetalContext ctx) {
    MetalContextInternal *context = (MetalContextInternal *)ctx;
    [context->window close];
    free(context);
}
