#define GLFW_INCLUDE_GLCOREARB
#include <GLFW/glfw3.h>

#include <stdio.h>
#include <stdlib.h>

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

int main(void)
{
    if (!glfwInit()) {
        return 1;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow* window = glfwCreateWindow(640, 480, "Hello, OpenGL 4.1 World!", NULL, NULL);
    if (!window) {
        glfwTerminate();
        return 1;
    }

    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);

    GLuint vs = CompileShader(GL_VERTEX_SHADER, VERTEX_SHADER_SOURCE);
    GLuint fs = CompileShader(GL_FRAGMENT_SHADER, FRAGMENT_SHADER_SOURCE);

    GLuint program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);

    GLint linkStatus = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &linkStatus);
    if (!linkStatus) {
        GLchar log[1024];
        GLsizei len = 0;
        glGetProgramInfoLog(program, sizeof(log), &len, log);
        fprintf(stderr, "program link error: %s\n", log);
        return 1;
    }

    GLfloat vertices[] = {
         0.0f,  0.7f, 0.0f,
        -0.7f, -0.7f, 0.0f,
         0.7f, -0.7f, 0.0f
    };

    GLfloat colors[] = {
        1.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 1.0f
    };

    GLuint vao = 0;
    GLuint buffers[2] = {0, 0};

    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

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

    while (!glfwWindowShouldClose(window)) {
        int width = 0;
        int height = 0;
        glfwGetFramebufferSize(window, &width, &height);
        glViewport(0, 0, width, height);

        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(program);
        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, 3);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glDeleteBuffers(2, buffers);
    glDeleteVertexArrays(1, &vao);
    glDeleteProgram(program);
    glDeleteShader(fs);
    glDeleteShader(vs);

    glfwDestroyWindow(window);
    glfwTerminate();

    return 0;
}
