#import <Cocoa/Cocoa.h>
#import <OpenGL/gl3.h>

static const char* VERTEX_SHADER_SOURCE =
    "#version 110\n"
    "attribute vec3 position;\n"
    "attribute vec3 color;\n"
    "varying vec3 vColor;\n"
    "void main() {\n"
    "    vColor = color;\n"
    "    gl_Position = vec4(position, 1.0);\n"
    "}\n";

static const char* FRAGMENT_SHADER_SOURCE =
    "#version 110\n"
    "varying vec3 vColor;\n"
    "void main() {\n"
    "    gl_FragColor = vec4(vColor, 1.0);\n"
    "}\n";

static GLuint CompileShader(GLenum type, const char* source)
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    GLint status = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (!status) {
        GLchar log[1024];
        GLsizei len = 0;
        glGetShaderInfoLog(shader, sizeof(log), &len, log);
        [NSException raise:@"ShaderCompileError" format:@"%s", log];
    }

    return shader;
}

static GLuint LinkProgram(GLuint vs, GLuint fs)
{
    GLuint program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);

    GLint status = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (!status) {
        GLchar log[1024];
        GLsizei len = 0;
        glGetProgramInfoLog(program, sizeof(log), &len, log);
        [NSException raise:@"ProgramLinkError" format:@"%s", log];
    }

    return program;
}

@interface TriangleView : NSOpenGLView {
    GLuint program_;
    GLuint vertexShader_;
    GLuint fragmentShader_;
    GLuint buffers_[2];
    GLint positionLoc_;
    GLint colorLoc_;
}
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

- (void)dealloc
{
    [[self openGLContext] makeCurrentContext];

    if (buffers_[0] != 0 || buffers_[1] != 0) {
        glDeleteBuffers(2, buffers_);
    }
    if (program_ != 0) {
        glDeleteProgram(program_);
    }
    if (fragmentShader_ != 0) {
        glDeleteShader(fragmentShader_);
    }
    if (vertexShader_ != 0) {
        glDeleteShader(vertexShader_);
    }

#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)prepareOpenGL
{
    [super prepareOpenGL];
    [[self openGLContext] makeCurrentContext];

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

    vertexShader_ = CompileShader(GL_VERTEX_SHADER, VERTEX_SHADER_SOURCE);
    fragmentShader_ = CompileShader(GL_FRAGMENT_SHADER, FRAGMENT_SHADER_SOURCE);
    program_ = LinkProgram(vertexShader_, fragmentShader_);

    static const GLfloat vertices[] = {
         0.0f,  0.7f, 0.0f,
        -0.7f, -0.7f, 0.0f,
         0.7f, -0.7f, 0.0f
    };

    static const GLfloat colors[] = {
        1.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 1.0f
    };

    positionLoc_ = glGetAttribLocation(program_, "position");
    colorLoc_ = glGetAttribLocation(program_, "color");

    glGenBuffers(2, buffers_);

    glBindBuffer(GL_ARRAY_BUFFER, buffers_[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, buffers_[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(colors), colors, GL_STATIC_DRAW);
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
    glUseProgram(program_);

    glEnableVertexAttribArray((GLuint)positionLoc_);
    glBindBuffer(GL_ARRAY_BUFFER, buffers_[0]);
    glVertexAttribPointer((GLuint)positionLoc_, 3, GL_FLOAT, GL_FALSE, 0, (const void*)0);

    glEnableVertexAttribArray((GLuint)colorLoc_);
    glBindBuffer(GL_ARRAY_BUFFER, buffers_[1]);
    glVertexAttribPointer((GLuint)colorLoc_, 3, GL_FLOAT, GL_FALSE, 0, (const void*)0);

    glDrawArrays(GL_TRIANGLES, 0, 3);

    glDisableVertexAttribArray((GLuint)colorLoc_);
    glDisableVertexAttribArray((GLuint)positionLoc_);

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
    [self.window setTitle:@"Hello, OpenGL 2.0 World!"];
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

extern "C" void runOpenGLSample(void)
{

    @autoreleasepool {
        NSApplication* app = [NSApplication sharedApplication];
        AppDelegate* delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
}