#include <GLUT/glut.h>
#include <OpenGL/glext.h>
#include <stdio.h>
#include <stdlib.h>

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

static GLuint program;
static GLuint vertexShader;
static GLuint fragmentShader;
static GLuint buffers[2];
static GLint positionLoc;
static GLint colorLoc;

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
        GLchar log[1024];
        GLsizei len = 0;
        glGetProgramInfoLog(prog, sizeof(log), &len, log);
        fprintf(stderr, "program link error: %s\n", log);
        exit(1);
    }
    return prog;
}

static void Initialize(void)
{
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
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    vertexShader = CompileShader(GL_VERTEX_SHADER, VERTEX_SHADER_SOURCE);
    fragmentShader = CompileShader(GL_FRAGMENT_SHADER, FRAGMENT_SHADER_SOURCE);
    program = LinkProgram(vertexShader, fragmentShader);
    positionLoc = glGetAttribLocation(program, "position");
    colorLoc = glGetAttribLocation(program, "color");
    glGenBuffers(2, buffers);
    glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(colors), colors, GL_STATIC_DRAW);
}

static void Display(void)
{
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(program);
    glEnableVertexAttribArray((GLuint)positionLoc);
    glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
    glVertexAttribPointer((GLuint)positionLoc, 3, GL_FLOAT, GL_FALSE, 0, (const void*)0);
    glEnableVertexAttribArray((GLuint)colorLoc);
    glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
    glVertexAttribPointer((GLuint)colorLoc, 3, GL_FLOAT, GL_FALSE, 0, (const void*)0);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glDisableVertexAttribArray((GLuint)colorLoc);
    glDisableVertexAttribArray((GLuint)positionLoc);
    glutSwapBuffers();
}

static void Reshape(int width, int height)
{
    glViewport(0, 0, width, height);
}

static void Timer(int value)
{
    (void)value;
    glutPostRedisplay();
    glutTimerFunc(16, Timer, 0);
}

static void OnClose(void)
{
    glDeleteBuffers(2, buffers);
    glDeleteProgram(program);
    glDeleteShader(fragmentShader);
    glDeleteShader(vertexShader);
    exit(0);
}

static void Keyboard(unsigned char key, int x, int y)
{
    (void)x;
    (void)y;
    if (key == 27 || key == 'q' || key == 'Q') {
        OnClose();
    }
}

void runSample(void)
{
    int argc = 0;
    glutInit(&argc, NULL);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA);
    glutInitWindowSize(640, 480);
    glutCreateWindow("Hello, OpenGL 2.0 World!");
    Initialize();
    glutDisplayFunc(Display);
    glutReshapeFunc(Reshape);
    glutWMCloseFunc(OnClose);
    glutKeyboardFunc(Keyboard);
    glutTimerFunc(16, Timer, 0);
    glutMainLoop();
}
