#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <stdio.h>

GLFWwindow* window = NULL;
GLuint shaderProgram;
GLuint vao;
GLuint vbo[2];
GLint posAttrib;
GLint colAttrib;

GLfloat vertices[] = {
      0.0f,  0.5f, 0.0f, 
      0.5f, -0.5f, 0.0f, 
     -0.5f, -0.5f, 0.0f
};

GLfloat colors[] = {
     1.0f,  0.0f,  0.0f,
     0.0f,  1.0f,  0.0f,
     0.0f,  0.0f,  1.0f
};

// Shader sources
const GLchar* vertexSource =
    "#version 460 core                            \n"
    "layout(location = 0) in  vec3 position;      \n"
    "layout(location = 1) in  vec3 color;         \n"
    "out vec4 vColor;                             \n"
    "void main()                                  \n"
    "{                                            \n"
    "  vColor = vec4(color, 1.0);                 \n"
    "  gl_Position = vec4(position, 1.0);         \n"
    "}                                            \n";
const GLchar* fragmentSource =
    "#version 460 core                            \n"
    "precision mediump float;                     \n"
    "in  vec4 vColor;                             \n"
    "out vec4 outColor;                           \n"
    "void main()                                  \n"
    "{                                            \n"
    "  outColor = vColor;                         \n"
    "}                                            \n";


void InitOpenGL() {
    glfwInit();

    glfwWindowHint( GLFW_CONTEXT_VERSION_MAJOR, 4 );
    glfwWindowHint( GLFW_CONTEXT_VERSION_MINOR, 6 );
    glfwWindowHint( GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE );
    glfwWindowHint( GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE );

    window = glfwCreateWindow( 640, 480, "Hello, World!", NULL, NULL );
    glfwMakeContextCurrent( window );

    glewInit();
}

void InitShader() {
    GLuint vs;
    GLuint fs;

    vs = glCreateShader( GL_VERTEX_SHADER );
    glShaderSource( vs, 1, &vertexSource, NULL );
    glCompileShader( vs );

    fs = glCreateShader( GL_FRAGMENT_SHADER );
    glShaderSource( fs, 1, &fragmentSource, NULL );
    glCompileShader( fs );

    shaderProgram = glCreateProgram();
    glAttachShader( shaderProgram, fs );
    glAttachShader( shaderProgram, vs );

    glLinkProgram( shaderProgram );
    glUseProgram( shaderProgram );

    posAttrib = glGetAttribLocation(shaderProgram, "position");
    glEnableVertexAttribArray(posAttrib);

    colAttrib = glGetAttribLocation(shaderProgram, "color");
    glEnableVertexAttribArray(colAttrib);
}

void InitBuffer() {
    glGenVertexArrays(1, &vao);

    glBindVertexArray(vao);

    glGenBuffers( 2, vbo );
    glBindBuffer( GL_ARRAY_BUFFER, vbo[0] );
    glEnableVertexArrayAttrib(vao, 0);
    glBufferData( GL_ARRAY_BUFFER, sizeof( vertices ), vertices, GL_STATIC_DRAW );
    glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);

    glBindBuffer( GL_ARRAY_BUFFER, vbo[1] );
    glEnableVertexArrayAttrib(vao, 1);
    glBufferData( GL_ARRAY_BUFFER, sizeof( colors ), colors, GL_STATIC_DRAW );
    glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);

    glBindVertexArray(0);
}

int main() {
    InitOpenGL();
    InitShader();
    InitBuffer();

    while ( !glfwWindowShouldClose( window ) ) {
        glBindVertexArray( vao );

        glDrawArrays( GL_TRIANGLES, 0, 3 );

        glfwPollEvents();
        glfwSwapBuffers( window );
    }

    glfwTerminate();
    return 0;
}