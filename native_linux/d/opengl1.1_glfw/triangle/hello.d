// OpenGL 1.1 (GLFW) Triangle - D Language
// Compile: gdc -o hello hello.d -lGL -lglfw

alias GLenum     = uint;
alias GLbitfield = uint;
alias GLfloat    = float;
alias GLint      = int;
alias GLsizei    = int;

enum GLenum GL_COLOR_BUFFER_BIT = 0x4000;
enum GLenum GL_FLOAT            = 0x1406;
enum GLenum GL_TRIANGLE_STRIP   = 0x0005;
enum GLenum GL_COLOR_ARRAY      = 0x8076;
enum GLenum GL_VERTEX_ARRAY     = 0x8074;

enum int GLFW_CONTEXT_VERSION_MAJOR = 0x00022002;
enum int GLFW_CONTEXT_VERSION_MINOR = 0x00022003;

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
    void glEnableClientState(GLenum array_);
    void glColorPointer(GLint size, GLenum type, GLsizei stride, const(void)* pointer);
    void glVertexPointer(GLint size, GLenum type, GLsizei stride, const(void)* pointer);
    void glDrawArrays(GLenum mode, GLint first, GLsizei count);
}

void main()
{
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 1);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
    GLFWwindow* window = glfwCreateWindow(640, 480, "Hello, World!", null, null);
    glfwMakeContextCurrent(window);

    while (!glfwWindowShouldClose(window)) {
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        GLfloat[9] colors = [
             1.0f,  0.0f,  0.0f,
             0.0f,  1.0f,  0.0f,
             0.0f,  0.0f,  1.0f,
        ];
        GLfloat[6] vertices = [
             0.0f,  0.5f,
             0.5f, -0.5f,
            -0.5f, -0.5f,
        ];

        glEnableClientState(GL_COLOR_ARRAY);
        glEnableClientState(GL_VERTEX_ARRAY);
        glColorPointer(3, GL_FLOAT, 0, colors.ptr);
        glVertexPointer(2, GL_FLOAT, 0, vertices.ptr);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwDestroyWindow(window);
    glfwTerminate();
}
