#include <GL/glut.h>
#include <GL/glext.h>
#include <cstdio>
#include <cstdlib>

static const char* VERTEX_SHADER_SOURCE =
    "#version 330 core\n"
    "layout(location = 0) in vec3 position;\n"
    "layout(location = 1) in vec3 color;\n"
    "out vec3 vColor;\n"
    "void main() { vColor = color; gl_Position = vec4(position, 1.0); }\n";

static const char* FRAGMENT_SHADER_SOURCE =
    "#version 330 core\n"
    "in vec3 vColor;\n"
    "out vec4 outColor;\n"
    "void main() { outColor = vec4(vColor, 1.0); }\n";

static PFNGLCREATESHADERPROC        pglCreateShader;
static PFNGLSHADERSOURCEPROC        pglShaderSource;
static PFNGLCOMPILESHADERPROC       pglCompileShader;
static PFNGLGETSHADERIVPROC         pglGetShaderiv;
static PFNGLGETSHADERINFOLOGPROC    pglGetShaderInfoLog;
static PFNGLCREATEPROGRAMPROC       pglCreateProgram;
static PFNGLATTACHSHADERPROC        pglAttachShader;
static PFNGLLINKPROGRAMPROC         pglLinkProgram;
static PFNGLGETPROGRAMIVPROC        pglGetProgramiv;
static PFNGLGETPROGRAMINFOLOGPROC   pglGetProgramInfoLog;
static PFNGLUSEPROGRAMPROC          pglUseProgram;
static PFNGLGENBUFFERSPROC          pglGenBuffers;
static PFNGLBINDBUFFERPROC          pglBindBuffer;
static PFNGLBUFFERDATAPROC          pglBufferData;
static PFNGLENABLEVERTEXATTRIBARRAYPROC  pglEnableVertexAttribArray;
static PFNGLDISABLEVERTEXATTRIBARRAYPROC pglDisableVertexAttribArray;
static PFNGLVERTEXATTRIBPOINTERPROC pglVertexAttribPointer;
static PFNGLDELETEBUFFERSPROC       pglDeleteBuffers;
static PFNGLDELETEPROGRAMPROC       pglDeleteProgram;
static PFNGLDELETESHADERPROC        pglDeleteShader;
static PFNGLGENVERTEXARRAYSPROC     pglGenVertexArrays;
static PFNGLBINDVERTEXARRAYPROC     pglBindVertexArray;
static PFNGLDELETEVERTEXARRAYSPROC  pglDeleteVertexArrays;

#define LOAD(type, name) p##name = reinterpret_cast<type>(glutGetProcAddress(#name))

static GLuint program, vertexShader, fragmentShader;
static GLuint buffers[2];
static GLuint vertexArray;

static GLuint CompileShader(GLenum type, const char* src)
{
    GLuint sh = pglCreateShader(type);
    pglShaderSource(sh, 1, &src, nullptr);
    pglCompileShader(sh);
    GLint ok = 0; pglGetShaderiv(sh, GL_COMPILE_STATUS, &ok);
    if (!ok) { GLchar log[1024]; GLsizei len=0; pglGetShaderInfoLog(sh, sizeof(log), &len, log); std::fprintf(stderr, "shader error: %s\n", log); std::exit(1); }
    return sh;
}

static GLuint LinkProgram(GLuint vs, GLuint fs)
{
    GLuint p = pglCreateProgram();
    pglAttachShader(p, vs); pglAttachShader(p, fs); pglLinkProgram(p);
    GLint ok = 0; pglGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) { GLchar log[1024]; GLsizei len=0; pglGetProgramInfoLog(p, sizeof(log), &len, log); std::fprintf(stderr, "link error: %s\n", log); std::exit(1); }
    return p;
}

static void LoadProcs()
{
    LOAD(PFNGLCREATESHADERPROC, glCreateShader);
    LOAD(PFNGLSHADERSOURCEPROC, glShaderSource);
    LOAD(PFNGLCOMPILESHADERPROC, glCompileShader);
    LOAD(PFNGLGETSHADERIVPROC, glGetShaderiv);
    LOAD(PFNGLGETSHADERINFOLOGPROC, glGetShaderInfoLog);
    LOAD(PFNGLCREATEPROGRAMPROC, glCreateProgram);
    LOAD(PFNGLATTACHSHADERPROC, glAttachShader);
    LOAD(PFNGLLINKPROGRAMPROC, glLinkProgram);
    LOAD(PFNGLGETPROGRAMIVPROC, glGetProgramiv);
    LOAD(PFNGLGETPROGRAMINFOLOGPROC, glGetProgramInfoLog);
    LOAD(PFNGLUSEPROGRAMPROC, glUseProgram);
    LOAD(PFNGLGENBUFFERSPROC, glGenBuffers);
    LOAD(PFNGLBINDBUFFERPROC, glBindBuffer);
    LOAD(PFNGLBUFFERDATAPROC, glBufferData);
    LOAD(PFNGLENABLEVERTEXATTRIBARRAYPROC, glEnableVertexAttribArray);
    LOAD(PFNGLDISABLEVERTEXATTRIBARRAYPROC, glDisableVertexAttribArray);
    LOAD(PFNGLVERTEXATTRIBPOINTERPROC, glVertexAttribPointer);
    LOAD(PFNGLDELETEBUFFERSPROC, glDeleteBuffers);
    LOAD(PFNGLDELETEPROGRAMPROC, glDeleteProgram);
    LOAD(PFNGLDELETESHADERPROC, glDeleteShader);
    LOAD(PFNGLGENVERTEXARRAYSPROC, glGenVertexArrays);
    LOAD(PFNGLBINDVERTEXARRAYPROC, glBindVertexArray);
    LOAD(PFNGLDELETEVERTEXARRAYSPROC, glDeleteVertexArrays);
}

static void Initialize()
{
    static const GLfloat vertices[] = { 0.0f,0.7f,0.0f, -0.7f,-0.7f,0.0f, 0.7f,-0.7f,0.0f };
    static const GLfloat colors[]   = { 1.0f,0.0f,0.0f, 0.0f,1.0f,0.0f, 0.0f,0.0f,1.0f };
    LoadProcs();
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    vertexShader   = CompileShader(GL_VERTEX_SHADER, VERTEX_SHADER_SOURCE);
    fragmentShader = CompileShader(GL_FRAGMENT_SHADER, FRAGMENT_SHADER_SOURCE);
    program        = LinkProgram(vertexShader, fragmentShader);
    pglGenVertexArrays(1, &vertexArray);
    pglBindVertexArray(vertexArray);
    pglGenBuffers(2, buffers);
    pglBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
    pglBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    pglEnableVertexAttribArray(0);
    pglVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, nullptr);
    pglBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
    pglBufferData(GL_ARRAY_BUFFER, sizeof(colors), colors, GL_STATIC_DRAW);
    pglEnableVertexAttribArray(1);
    pglVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 0, nullptr);
    pglBindVertexArray(0);
}

static void Display()
{
    glClear(GL_COLOR_BUFFER_BIT);
    pglUseProgram(program);
    pglBindVertexArray(vertexArray);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    pglBindVertexArray(0);
    glutSwapBuffers();
}

static void Reshape(int w, int h) { glViewport(0, 0, w, h); }
static void Timer(int v) { (void)v; glutPostRedisplay(); glutTimerFunc(16, Timer, 0); }
static void OnClose()
{
    pglDeleteVertexArrays(1, &vertexArray);
    pglDeleteBuffers(2, buffers);
    pglDeleteProgram(program);
    pglDeleteShader(fragmentShader);
    pglDeleteShader(vertexShader);
    std::exit(0);
}
static void Keyboard(unsigned char k, int, int) { if (k==27||k=='q'||k=='Q') OnClose(); }

int main(int argc, char** argv)
{
    glutInit(&argc, argv);
    glutInitContextVersion(3, 3);
    glutInitContextProfile(GLUT_CORE_PROFILE);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA);
    glutInitWindowSize(640, 480);
    glutCreateWindow("Hello, OpenGL 3.3 World!");
    Initialize();
    glutDisplayFunc(Display);
    glutReshapeFunc(Reshape);
    glutCloseFunc(OnClose);
    glutKeyboardFunc(Keyboard);
    glutTimerFunc(16, Timer, 0);
    glutMainLoop();
    return 0;
}
