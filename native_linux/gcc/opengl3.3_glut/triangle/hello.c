#include <GL/glut.h>
#include <GL/glext.h>
#include <stdio.h>
#include <stdlib.h>

static const char* VERTEX_SHADER_SOURCE =
    "#version 330 core\n"
    "layout(location = 0) in vec3 position;\n"
    "layout(location = 1) in vec3 color;\n"
    "out vec3 vColor;\n"
    "void main() {\n"
    "    vColor = color;\n"
    "    gl_Position = vec4(position, 1.0);\n"
    "}\n";

static const char* FRAGMENT_SHADER_SOURCE =
    "#version 330 core\n"
    "in vec3 vColor;\n"
    "out vec4 outColor;\n"
    "void main() {\n"
    "    outColor = vec4(vColor, 1.0);\n"
    "}\n";

static PFNGLCREATESHADERPROC            glCreateShader;
static PFNGLSHADERSOURCEPROC            glShaderSource;
static PFNGLCOMPILESHADERPROC           glCompileShader;
static PFNGLGETSHADERIVPROC             glGetShaderiv;
static PFNGLGETSHADERINFOLOGPROC        glGetShaderInfoLog;
static PFNGLCREATEPROGRAMPROC           glCreateProgram;
static PFNGLATTACHSHADERPROC            glAttachShader;
static PFNGLLINKPROGRAMPROC             glLinkProgram;
static PFNGLGETPROGRAMIVPROC            glGetProgramiv;
static PFNGLGETPROGRAMINFOLOGPROC       glGetProgramInfoLog;
static PFNGLUSEPROGRAMPROC              glUseProgram;
static PFNGLGENVERTEXARRAYSPROC         glGenVertexArrays;
static PFNGLBINDVERTEXARRAYPROC         glBindVertexArray;
static PFNGLGENBUFFERSPROC              glGenBuffers;
static PFNGLBINDBUFFERPROC              glBindBuffer;
static PFNGLBUFFERDATAPROC              glBufferData;
static PFNGLENABLEVERTEXATTRIBARRAYPROC glEnableVertexAttribArray;
static PFNGLVERTEXATTRIBPOINTERPROC     glVertexAttribPointer;
static PFNGLDELETEVERTEXARRAYSPROC      glDeleteVertexArrays;
static PFNGLDELETEBUFFERSPROC           glDeleteBuffers;
static PFNGLDELETEPROGRAMPROC           glDeleteProgram;
static PFNGLDELETESHADERPROC            glDeleteShader;

#define LOAD_PROC(type, name) name = (type)glutGetProcAddress(#name)

static GLuint program, vertexShader, fragmentShader, vertexArray;
static GLuint buffers[2];

static GLuint CompileShader(GLenum type, const char* source)
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    GLint status = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (!status) {
        GLchar log[1024]; GLsizei len = 0;
        glGetShaderInfoLog(shader, sizeof(log), &len, log);
        fprintf(stderr, "shader compile error: %s\n", log);
        exit(1);
    }
    return shader;
}

static GLuint LinkProgram(GLuint vs, GLuint fs)
{
    GLuint prog = glCreateProgram();
    glAttachShader(prog, vs);
    glAttachShader(prog, fs);
    glLinkProgram(prog);
    GLint status = 0;
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (!status) {
        GLchar log[1024]; GLsizei len = 0;
        glGetProgramInfoLog(prog, sizeof(log), &len, log);
        fprintf(stderr, "program link error: %s\n", log);
        exit(1);
    }
    return prog;
}

static void LoadProcs(void)
{
    LOAD_PROC(PFNGLCREATESHADERPROC,            glCreateShader);
    LOAD_PROC(PFNGLSHADERSOURCEPROC,            glShaderSource);
    LOAD_PROC(PFNGLCOMPILESHADERPROC,           glCompileShader);
    LOAD_PROC(PFNGLGETSHADERIVPROC,             glGetShaderiv);
    LOAD_PROC(PFNGLGETSHADERINFOLOGPROC,        glGetShaderInfoLog);
    LOAD_PROC(PFNGLCREATEPROGRAMPROC,           glCreateProgram);
    LOAD_PROC(PFNGLATTACHSHADERPROC,            glAttachShader);
    LOAD_PROC(PFNGLLINKPROGRAMPROC,             glLinkProgram);
    LOAD_PROC(PFNGLGETPROGRAMIVPROC,            glGetProgramiv);
    LOAD_PROC(PFNGLGETPROGRAMINFOLOGPROC,       glGetProgramInfoLog);
    LOAD_PROC(PFNGLUSEPROGRAMPROC,              glUseProgram);
    LOAD_PROC(PFNGLGENVERTEXARRAYSPROC,         glGenVertexArrays);
    LOAD_PROC(PFNGLBINDVERTEXARRAYPROC,         glBindVertexArray);
    LOAD_PROC(PFNGLGENBUFFERSPROC,              glGenBuffers);
    LOAD_PROC(PFNGLBINDBUFFERPROC,              glBindBuffer);
    LOAD_PROC(PFNGLBUFFERDATAPROC,              glBufferData);
    LOAD_PROC(PFNGLENABLEVERTEXATTRIBARRAYPROC, glEnableVertexAttribArray);
    LOAD_PROC(PFNGLVERTEXATTRIBPOINTERPROC,     glVertexAttribPointer);
    LOAD_PROC(PFNGLDELETEVERTEXARRAYSPROC,      glDeleteVertexArrays);
    LOAD_PROC(PFNGLDELETEBUFFERSPROC,           glDeleteBuffers);
    LOAD_PROC(PFNGLDELETEPROGRAMPROC,           glDeleteProgram);
    LOAD_PROC(PFNGLDELETESHADERPROC,            glDeleteShader);
}

static void Initialize(void)
{
    static const GLfloat vertices[] = { 0.0f,0.7f,0.0f, -0.7f,-0.7f,0.0f, 0.7f,-0.7f,0.0f };
    static const GLfloat colors[]   = { 1.0f,0.0f,0.0f,  0.0f,1.0f,0.0f,  0.0f,0.0f,1.0f  };

    LoadProcs();
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    vertexShader   = CompileShader(GL_VERTEX_SHADER,   VERTEX_SHADER_SOURCE);
    fragmentShader = CompileShader(GL_FRAGMENT_SHADER, FRAGMENT_SHADER_SOURCE);
    program        = LinkProgram(vertexShader, fragmentShader);
    glGenVertexArrays(1, &vertexArray);
    glBindVertexArray(vertexArray);
    glGenBuffers(2, buffers);
    glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, (const void*)0);
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(colors), colors, GL_STATIC_DRAW);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 0, (const void*)0);
    glEnableVertexAttribArray(1);
    glBindVertexArray(0);
}

void Display(void)
{
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(program);
    glBindVertexArray(vertexArray);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glBindVertexArray(0);
    glutSwapBuffers();
}

void Reshape(int width, int height) { glViewport(0, 0, width, height); }

void Timer(int value) { (void)value; glutPostRedisplay(); glutTimerFunc(16, Timer, 0); }

void OnClose(void)
{
    glDeleteBuffers(2, buffers);
    glDeleteVertexArrays(1, &vertexArray);
    glDeleteProgram(program);
    glDeleteShader(fragmentShader);
    glDeleteShader(vertexShader);
    exit(0);
}

void Keyboard(unsigned char key, int x, int y)
{
    (void)x; (void)y;
    if (key == 27 || key == 'q' || key == 'Q') OnClose();
}

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
