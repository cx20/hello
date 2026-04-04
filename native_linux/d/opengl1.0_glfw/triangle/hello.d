// OpenGL 1.0 (GLFW) Triangle - D Language
// Compile: gdc -o hello hello.d -lGL -lglfw

alias GLenum     = uint;
alias GLbitfield = uint;
alias GLfloat    = float;

enum GLenum GL_COLOR_BUFFER_BIT = 0x4000;
enum GLenum GL_TRIANGLES        = 0x0004;

struct GLFWwindow;

extern(C) {
    int         glfwInit();
    void        glfwTerminate();
    GLFWwindow* glfwCreateWindow(int w, int h, const(char)* title, void* monitor, void* share);
    void        glfwDestroyWindow(GLFWwindow* window);
    void        glfwMakeContextCurrent(GLFWwindow* window);
    int         glfwWindowShouldClose(GLFWwindow* window);
    void        glfwSwapBuffers(GLFWwindow* window);
    void        glfwPollEvents();

    void glClear(GLbitfield mask);
    void glClearColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a);
    void glBegin(GLenum mode);
    void glEnd();
    void glColor3f(GLfloat r, GLfloat g, GLfloat b);
    void glVertex2f(GLfloat x, GLfloat y);
}

void main()
{
    glfwInit();
    GLFWwindow* window = glfwCreateWindow(640, 480, "Hello, World!", null, null);
    glfwMakeContextCurrent(window);

    while (!glfwWindowShouldClose(window)) {
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glBegin(GL_TRIANGLES);
            glColor3f(1.0f, 0.0f, 0.0f); glVertex2f( 0.0f,  0.5f);
            glColor3f(0.0f, 1.0f, 0.0f); glVertex2f( 0.5f, -0.5f);
            glColor3f(0.0f, 0.0f, 1.0f); glVertex2f(-0.5f, -0.5f);
        glEnd();

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwDestroyWindow(window);
    glfwTerminate();
}
