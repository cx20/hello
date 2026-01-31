#include <windows.h>
#include <tchar.h>

#define GLEW_STATIC
#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <stdio.h>

GLFWwindow* window = NULL;
GLuint shaderProgram;
GLuint vao;
GLuint vbo[2];
GLint posAttrib;
GLint colAttrib;

// Shader sources
const GLchar* vertexSource =
    "#version 300 es                              \n"
    "in  vec3 position;                           \n"
    "in  vec3 color;                              \n"
    "out vec4 vColor;                             \n"
    "void main()                                  \n"
    "{                                            \n"
    "  vColor = vec4(color, 1.0);                 \n"
    "  gl_Position = vec4(position, 1.0);         \n"
    "}                                            \n";
const GLchar* fragmentSource =
    "#version 300 es                              \n"
    "precision mediump float;                     \n"
    "in  vec4 vColor;                             \n"
    "out vec4 outColor;                           \n"
    "void main()                                  \n"
    "{                                            \n"
    "  outColor = vColor;                         \n"
    "}                                            \n";

void InitOpenGL();
void InitShader();
void InitBuffer();
void DrawTriangle();

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
{
    InitOpenGL();
    InitShader();
    InitBuffer();

    while ( !glfwWindowShouldClose( window ) ) {
        DrawTriangle();
        
        glfwPollEvents();
        glfwSwapBuffers( window );
    }

    glfwTerminate();
    return 0;
}

void InitOpenGL()
{
    glfwInit();

    window = glfwCreateWindow( 640, 480, "Hello, World!", NULL, NULL );
    glfwMakeContextCurrent( window );

    glewInit();
}

void InitShader()
{
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

void InitBuffer()
{
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

void DrawTriangle()
{
    glBindVertexArray( vao );

    glDrawArrays( GL_TRIANGLES, 0, 3 );
}