#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>

static const GLfloat COLORS[] = {
    1.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 1.0f
};

static const GLfloat VERTICES[] = {
     0.0f,  0.7f,
    -0.7f, -0.7f,
     0.7f, -0.7f
};

@interface TriangleView : NSOpenGLView
@end

@implementation TriangleView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    NSOpenGLPixelFormatAttribute attrs[] = {
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFADoubleBuffer,
        0
    };

    NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    self = [super initWithFrame:frameRect pixelFormat:pixelFormat];
    return self;
}

- (void)prepareOpenGL
{
    [super prepareOpenGL];
    [[self openGLContext] makeCurrentContext];
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
}

- (void)reshape
{
    [super reshape];
    [[self openGLContext] makeCurrentContext];

    NSRect backingBounds = [self convertRectToBacking:[self bounds]];
    glViewport(0, 0, (GLsizei)backingBounds.size.width, (GLsizei)backingBounds.size.height);
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    [[self openGLContext] makeCurrentContext];

    glClear(GL_COLOR_BUFFER_BIT);

    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_VERTEX_ARRAY);

    glColorPointer(3, GL_FLOAT, 0, COLORS);
    glVertexPointer(2, GL_FLOAT, 0, VERTICES);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_COLOR_ARRAY);

    [[self openGLContext] flushBuffer];
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(strong) NSWindow* window;
@property(strong) NSTimer* timer;
@property(strong) TriangleView* view;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
    (void)notification;

    NSRect frame = NSMakeRect(0, 0, 640, 480);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window setTitle:@"Hello, OpenGL 1.1 World!"];
    [self.window center];

    self.view = [[TriangleView alloc] initWithFrame:frame];
    [self.window setContentView:self.view];
    [self.window makeKeyAndOrderFront:nil];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / 60.0)
                                                   target:self
                                                 selector:@selector(onTimer:)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (void)onTimer:(NSTimer*)timer
{
    (void)timer;
    [self.view setNeedsDisplay:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
    (void)sender;
    return YES;
}

@end

int main(int argc, const char* argv[])
{
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSApplication* app = [NSApplication sharedApplication];
        AppDelegate* delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }

    return 0;
}