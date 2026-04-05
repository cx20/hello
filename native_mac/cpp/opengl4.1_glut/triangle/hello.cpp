#include <GLUT/glut.h>
#include <OpenGL/gl3.h>

#include <cstdio>
#include <cstdlib>

static const char* VERTEX_SHADER_SOURCE =
    "#version 410 core\n"
    "layout(location = 0) in vec3 position;\n"
    "layout(location = 1) in vec3 color;\n"
    "out vec3 vColor;\n"
    "void main() {\n"
    "    vColor = color;\n"
    "    gl_Position = vec4(position, 1.0);\n"
    "}\n";

static const char* FRAGMENT_SHADER_SOURCE =
    "#version 410 core\n"
    "in vec3 vColor;\n"
    "out vec4 outColor;\n"
    "void main() {\n"
    "    outColor = vec4(vColor, 1.0);\n"
    "}\n";

static GLuint program;
static GLuint vertexShader;
static GLuint fragmentShader;
static GLuint vertexArray;
static GLuint buffers[2];

static GLuint CompileShader(GLenum type, const char* source)
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);
    GLint status = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (!status) {
        GLchar log[1024];
        GLsizei len = 0;
        glGetShaderInfoLog(shader, sizeof(log), &len, log);
        std::fprintf(stderr, "shader compile error: %s\n", log);
        std::exit(1);
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
        std::fprintf(stderr, "program link error: %s\n", log);
        std::exit(1);
    }
    return prog;
}

static void Initialize()
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

    glGenVertexArrays(1, &vertexArray);
    glBindVertexArray(vertexArray);

    glGenBuffers(2, buffers);

    glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, nullptr);
    glEnableVertexAttribArray(0);

    glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(colors), colors, GL_STATIC_DRAW);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 0, nullptr);
    glEnableVertexAttribArray(1);

    glBindVertexArray(0);
}

static void Display()
{
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(program);
    glBindVertexArray(vertexArray);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glBindVertexArray(0);
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

static void OnClose()
{
    glDeleteBuffers(2, buffers);
    glDeleteVertexArrays(1, &vertexArray);
    glDeleteProgram(program);
    glDeleteShader(fragmentShader);
    glDeleteShader(vertexShader);
    std::exit(0);
}

static void Keyboard(unsigned char key, int x, int y)
{
    (void)x;
    (void)y;
    if (key == 27 || key == 'q' || key == 'Q') {
        OnClose();
    }
}

int main(int argc, char** argv)
{
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA | GLUT_3_2_CORE_PROFILE);
    glutInitWindowSize(640, 480);
    glutCreateWindow("Hello, OpenGL 4.1 World!");
    Initialize();
    glutDisplayFunc(Display);
    glutReshapeFunc(Reshape);
    glutWMCloseFunc(OnClose);
    glutKeyboardFunc(Keyboard);
    glutTimerFunc(16, Timer, 0);
    glutMainLoop();
    return 0;
}
