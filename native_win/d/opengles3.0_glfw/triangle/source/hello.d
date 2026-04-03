import core.sys.windows.windef;
import bindbc.glfw;

// OpenGL ES 3.0 type aliases
alias GLenum     = uint;
alias GLuint     = uint;
alias GLint      = int;
alias GLsizei    = int;
alias GLbitfield = uint;
alias GLfloat    = float;
alias GLchar     = char;
alias GLboolean  = ubyte;
alias GLsizeiptr = ptrdiff_t;

// OpenGL ES 3.0 enums
enum GL_TRIANGLES        = 0x0004;
enum GL_FLOAT            = 0x1406;
enum GL_FALSE            = 0;
enum GL_ARRAY_BUFFER     = 0x8892;
enum GL_STATIC_DRAW      = 0x88E4;
enum GL_COLOR_BUFFER_BIT = 0x4000;
enum GL_VERTEX_SHADER    = 0x8B31;
enum GL_FRAGMENT_SHADER  = 0x8B30;

// Function pointer types
extern(C) {
    alias pglClearColor              = void function(GLfloat, GLfloat, GLfloat, GLfloat);
    alias pglClear                   = void function(GLbitfield);
    alias pglDrawArrays              = void function(GLenum, GLint, GLsizei);
    alias pglGenBuffers              = void function(GLsizei, GLuint*);
    alias pglBindBuffer              = void function(GLenum, GLuint);
    alias pglBufferData              = void function(GLenum, GLsizeiptr, const(void)*, GLenum);
    alias pglGenVertexArrays         = void function(GLsizei, GLuint*);
    alias pglBindVertexArray         = void function(GLuint);
    alias pglCreateShader            = GLuint function(GLenum);
    alias pglShaderSource            = void function(GLuint, GLsizei, const(GLchar)**, const(GLint)*);
    alias pglCompileShader           = void function(GLuint);
    alias pglCreateProgram           = GLuint function();
    alias pglAttachShader            = void function(GLuint, GLuint);
    alias pglLinkProgram             = void function(GLuint);
    alias pglUseProgram              = void function(GLuint);
    alias pglGetAttribLocation       = GLint function(GLuint, const(GLchar)*);
    alias pglEnableVertexAttribArray = void function(GLuint);
    alias pglVertexAttribPointer     = void function(GLuint, GLint, GLenum, GLboolean, GLsizei, const(void)*);
}

pglClearColor              glClearColor;
pglClear                   glClear;
pglDrawArrays              glDrawArrays;
pglGenBuffers              glGenBuffers;
pglBindBuffer              glBindBuffer;
pglBufferData              glBufferData;
pglGenVertexArrays         glGenVertexArrays;
pglBindVertexArray         glBindVertexArray;
pglCreateShader            glCreateShader;
pglShaderSource            glShaderSource;
pglCompileShader           glCompileShader;
pglCreateProgram           glCreateProgram;
pglAttachShader            glAttachShader;
pglLinkProgram             glLinkProgram;
pglUseProgram              glUseProgram;
pglGetAttribLocation       glGetAttribLocation;
pglEnableVertexAttribArray glEnableVertexAttribArray;
pglVertexAttribPointer     glVertexAttribPointer;

GLuint[2] vbo;
GLuint vao;
GLint posAttrib;
GLint colAttrib;

// Shader sources for OpenGL ES 3.0
immutable string vertexSource =
    "#version 300 es                              \n" ~
    "in  vec3 position;                           \n" ~
    "in  vec3 color;                              \n" ~
    "out vec4 vColor;                             \n" ~
    "void main()                                  \n" ~
    "{                                            \n" ~
    "  vColor = vec4(color, 1.0);                 \n" ~
    "  gl_Position = vec4(position, 1.0);         \n" ~
    "}                                            \n";

immutable string fragmentSource =
    "#version 300 es                              \n" ~
    "precision mediump float;                     \n" ~
    "in  vec4 vColor;                             \n" ~
    "out vec4 outColor;                           \n" ~
    "void main()                                  \n" ~
    "{                                            \n" ~
    "  outColor = vColor;                         \n" ~
    "}                                            \n";

void loadGLESFunctions()
{
    glClearColor              = cast(pglClearColor)              glfwGetProcAddress("glClearColor");
    glClear                   = cast(pglClear)                   glfwGetProcAddress("glClear");
    glDrawArrays              = cast(pglDrawArrays)              glfwGetProcAddress("glDrawArrays");
    glGenBuffers              = cast(pglGenBuffers)              glfwGetProcAddress("glGenBuffers");
    glBindBuffer              = cast(pglBindBuffer)              glfwGetProcAddress("glBindBuffer");
    glBufferData              = cast(pglBufferData)              glfwGetProcAddress("glBufferData");
    glGenVertexArrays         = cast(pglGenVertexArrays)         glfwGetProcAddress("glGenVertexArrays");
    glBindVertexArray         = cast(pglBindVertexArray)         glfwGetProcAddress("glBindVertexArray");
    glCreateShader            = cast(pglCreateShader)            glfwGetProcAddress("glCreateShader");
    glShaderSource            = cast(pglShaderSource)            glfwGetProcAddress("glShaderSource");
    glCompileShader           = cast(pglCompileShader)           glfwGetProcAddress("glCompileShader");
    glCreateProgram           = cast(pglCreateProgram)           glfwGetProcAddress("glCreateProgram");
    glAttachShader            = cast(pglAttachShader)            glfwGetProcAddress("glAttachShader");
    glLinkProgram             = cast(pglLinkProgram)             glfwGetProcAddress("glLinkProgram");
    glUseProgram              = cast(pglUseProgram)              glfwGetProcAddress("glUseProgram");
    glGetAttribLocation       = cast(pglGetAttribLocation)       glfwGetProcAddress("glGetAttribLocation");
    glEnableVertexAttribArray = cast(pglEnableVertexAttribArray) glfwGetProcAddress("glEnableVertexAttribArray");
    glVertexAttribPointer     = cast(pglVertexAttribPointer)     glfwGetProcAddress("glVertexAttribPointer");
}

void initShader()
{
    // Create and compile the vertex shader
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    const GLchar* vs = cast(const GLchar*)vertexSource.ptr;
    glShaderSource(vertexShader, 1, &vs, null);
    glCompileShader(vertexShader);

    // Create and compile the fragment shader
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    const GLchar* fs = cast(const GLchar*)fragmentSource.ptr;
    glShaderSource(fragmentShader, 1, &fs, null);
    glCompileShader(fragmentShader);

    // Link the vertex and fragment shader into a shader program
    GLuint shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    glUseProgram(shaderProgram);

    // Specify the layout of the vertex data
    posAttrib = glGetAttribLocation(shaderProgram, "position");
    glEnableVertexAttribArray(cast(GLuint)posAttrib);

    colAttrib = glGetAttribLocation(shaderProgram, "color");
    glEnableVertexAttribArray(cast(GLuint)colAttrib);
}

void initBuffer()
{
    GLfloat[9] vertices = [
          0.0f,  0.5f, 0.0f,
          0.5f, -0.5f, 0.0f,
         -0.5f, -0.5f, 0.0f
    ];

    GLfloat[9] colors = [
         1.0f,  0.0f,  0.0f,
         0.0f,  1.0f,  0.0f,
         0.0f,  0.0f,  1.0f
    ];

    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    glGenBuffers(2, vbo.ptr);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)vertices.sizeof, vertices.ptr, GL_STATIC_DRAW);
    glVertexAttribPointer(cast(GLuint)posAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)colors.sizeof, colors.ptr, GL_STATIC_DRAW);
    glVertexAttribPointer(cast(GLuint)colAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);

    glBindVertexArray(0);
}

extern(Windows)
int WinMain(HINSTANCE /* hInstance */, HINSTANCE /* hPrevInstance */, LPSTR /* lpCmdLine */, int /* nCmdShow */)
{
    const GLFWSupport ret = loadGLFW();
    if (ret != glfwSupport) {
        return 1;
    }

    if (!glfwInit()) {
        return 1;
    }
    scope(exit) glfwTerminate();

    glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);

    GLFWwindow* window = glfwCreateWindow(640, 480, "Hello, World!", null, null);
    if (window is null) {
        return 1;
    }
    glfwMakeContextCurrent(window);

    loadGLESFunctions();
    initShader();
    initBuffer();

    while (!glfwWindowShouldClose(window)) {
        glClearColor(0f, 0f, 0f, 1f);
        glClear(GL_COLOR_BUFFER_BIT);

        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, 3);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }
    return 0;
}
