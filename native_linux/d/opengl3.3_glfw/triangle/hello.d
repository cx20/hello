// OpenGL 3.3 (GLFW) Triangle - D Language
// Compile: gdc -o hello hello.d -lGL -lglfw

alias GLenum     = uint;
alias GLbitfield = uint;
alias GLuint     = uint;
alias GLint      = int;
alias GLsizei    = int;
alias GLfloat    = float;
alias GLboolean  = ubyte;
alias GLchar     = char;
alias GLsizeiptr = ptrdiff_t;

enum GLenum GL_FALSE            = 0;
enum GLenum GL_TRUE             = 1;
enum GLenum GL_COLOR_BUFFER_BIT = 0x4000;
enum GLenum GL_FLOAT            = 0x1406;
enum GLenum GL_TRIANGLES        = 0x0004;
enum GLenum GL_ARRAY_BUFFER     = 0x8892;
enum GLenum GL_STATIC_DRAW      = 0x88E4;
enum GLenum GL_VERTEX_SHADER    = 0x8B31;
enum GLenum GL_FRAGMENT_SHADER  = 0x8B30;

enum int GLFW_CONTEXT_VERSION_MAJOR = 0x00022002;
enum int GLFW_CONTEXT_VERSION_MINOR = 0x00022003;
enum int GLFW_OPENGL_FORWARD_COMPAT = 0x00022006;
enum int GLFW_OPENGL_PROFILE        = 0x00022008;
enum int GLFW_OPENGL_CORE_PROFILE   = 0x00032001;

struct GLFWwindow;

extern(C) {
    int         glfwInit();
    void        glfwTerminate();
    void        glfwWindowHint(int hint, int value);
    GLFWwindow* glfwCreateWindow(int w, int h, const(char)* title, void* monitor, void* share);
    void        glfwDestroyWindow(GLFWwindow* window);
    void        glfwMakeContextCurrent(GLFWwindow* window);
    int         glfwWindowShouldClose(GLFWwindow* window);
    void        glfwSwapBuffers(GLFWwindow* window);
    void        glfwPollEvents();

    void glClear(GLbitfield mask);
    void glClearColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a);
    void glDrawArrays(GLenum mode, GLint first, GLsizei count);

    void   glGenVertexArrays(GLsizei n, GLuint* arrays);
    void   glBindVertexArray(GLuint array_);
    void   glGenBuffers(GLsizei n, GLuint* buffers);
    void   glBindBuffer(GLenum target, GLuint buffer);
    void   glBufferData(GLenum target, GLsizeiptr size, const(void)* data, GLenum usage);
    GLuint glCreateShader(GLenum type);
    void   glShaderSource(GLuint shader, GLsizei count, const(GLchar*)* string_, const(GLint)* length);
    void   glCompileShader(GLuint shader);
    GLuint glCreateProgram();
    void   glAttachShader(GLuint program, GLuint shader);
    void   glLinkProgram(GLuint program);
    void   glUseProgram(GLuint program);
    GLint  glGetAttribLocation(GLuint program, const(GLchar)* name);
    void   glEnableVertexAttribArray(GLuint index);
    void   glVertexAttribPointer(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const(void)* pointer);
}

immutable string vertexSource =
    "#version 330 core                            \n" ~
    "layout(location = 0) in  vec3 position;      \n" ~
    "layout(location = 1) in  vec3 color;         \n" ~
    "out vec4 vColor;                             \n" ~
    "void main()                                  \n" ~
    "{                                            \n" ~
    "  vColor = vec4(color, 1.0);                 \n" ~
    "  gl_Position = vec4(position, 1.0);         \n" ~
    "}                                            \n";

immutable string fragmentSource =
    "#version 330 core                            \n" ~
    "precision mediump float;                     \n" ~
    "in  vec4 vColor;                             \n" ~
    "out vec4 outColor;                           \n" ~
    "void main()                                  \n" ~
    "{                                            \n" ~
    "  outColor = vColor;                         \n" ~
    "}                                            \n";

__gshared GLuint vao;
__gshared GLuint[2] vbo;

void initShader()
{
    GLfloat[9] vertices = [
          0.0f,  0.5f, 0.0f,
          0.5f, -0.5f, 0.0f,
         -0.5f, -0.5f, 0.0f,
    ];
    GLfloat[9] colors = [
         1.0f,  0.0f,  0.0f,
         0.0f,  1.0f,  0.0f,
         0.0f,  0.0f,  1.0f,
    ];

    const(GLchar)* vSrc = vertexSource.ptr;
    const(GLchar)* fSrc = fragmentSource.ptr;

    GLuint vs = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vs, 1, &vSrc, null);
    glCompileShader(vs);

    GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs, 1, &fSrc, null);
    glCompileShader(fs);

    GLuint prog = glCreateProgram();
    glAttachShader(prog, vs);
    glAttachShader(prog, fs);
    glLinkProgram(prog);
    glUseProgram(prog);

    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    glGenBuffers(2, vbo.ptr);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, vertices.sizeof, vertices.ptr, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, colors.sizeof, colors.ptr, GL_STATIC_DRAW);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 0, null);

    glBindVertexArray(0);
}

void main()
{
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    GLFWwindow* window = glfwCreateWindow(640, 480, "Hello, World!", null, null);
    glfwMakeContextCurrent(window);

    initShader();

    while (!glfwWindowShouldClose(window)) {
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwDestroyWindow(window);
    glfwTerminate();
}
