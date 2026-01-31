#include "stdio.h"
#include "imgui.h"
#include "imgui_impl_sdl.h"
#include "imgui_impl_opengl3.h"

#define SDL_MAIN_HANDLED
#include <SDL.h>
#include <SDL_opengl.h>
#include <SDL_opengl_glext.h>

SDL_Window* window;
SDL_GLContext glContext;
GLuint shaderProgram;
GLuint vbo[2];
GLint posAttrib;
GLint colAttrib;

PFNGLGENBUFFERSPROC               glGenBuffers;
PFNGLBINDBUFFERPROC               glBindBuffer;
PFNGLBUFFERDATAPROC               glBufferData;
PFNGLCREATESHADERPROC             glCreateShader;
PFNGLSHADERSOURCEPROC             glShaderSource;
PFNGLCOMPILESHADERPROC            glCompileShader;
PFNGLCREATEPROGRAMPROC            glCreateProgram;
PFNGLATTACHSHADERPROC             glAttachShader;
PFNGLLINKPROGRAMPROC              glLinkProgram;
PFNGLUSEPROGRAMPROC               glUseProgram;
PFNGLGETATTRIBLOCATIONPROC        glGetAttribLocation;
PFNGLENABLEVERTEXATTRIBARRAYPROC  glEnableVertexAttribArray;
PFNGLVERTEXATTRIBPOINTERPROC      glVertexAttribPointer;

// Shader sources
const GLchar* vertexSource =
    "#version 330 core                            \n"
    "layout(location = 0) in  vec3 position;      \n"
    "layout(location = 1) in  vec3 color;         \n"
    "out vec4 vColor;                             \n"
    "void main()                                  \n"
    "{                                            \n"
    "  vColor = vec4(color, 1.0);                 \n"
    "  gl_Position = vec4(position, 1.0);         \n"
    "}                                            \n";
const GLchar* fragmentSource =
    "#version 330 core                            \n"
    "precision mediump float;                     \n"
    "in  vec4 vColor;                             \n"
    "out vec4 outColor;                           \n"
    "void main()                                  \n"
    "{                                            \n"
    "  outColor = vColor;                         \n"
    "}                                            \n";

void InitOpenGL();
void InitOpenGLFunc();
void InitShader();
void InitBuffer();

int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow){

    InitOpenGL();
    InitOpenGLFunc();
    InitShader();
    InitBuffer();

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();

    // imgui init
    ImGui_ImplSDL2_InitForOpenGL(window, glContext);
    ImGui_ImplOpenGL3_Init();


    SDL_Event ev;
    BOOL running = TRUE;
    while (running) {
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_QUIT)
                running = FALSE;
        }

        glClearColor(0.45f, 0.55f, 0.60f, 1.00f);
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram( shaderProgram );
        glBindBuffer( GL_ARRAY_BUFFER, vbo[0] );
        glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);

        glBindBuffer( GL_ARRAY_BUFFER, vbo[1] );
        glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);

        glDrawArrays( GL_TRIANGLES, 0, 3 );

        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplSDL2_NewFrame();
        ImGui::NewFrame();

        // gui
        {
            ImGui::Begin("Hello, World!");

            ImGui::Text("Hello, Dear ImGui (C++) World!");

            ImGui::End();
        }

        ImGui::Render();
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

        SDL_GL_SwapWindow(window);
    }

    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplSDL2_Shutdown();
    ImGui::DestroyContext();;

    SDL_DestroyWindow(window);
    SDL_GL_DeleteContext(glContext);

    SDL_Quit();

    return 0;
}

void InitOpenGL()
{
    SDL_Init(SDL_INIT_VIDEO);

    window = SDL_CreateWindow(
        "Hello, World!",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        640,
        480,
        SDL_WINDOW_OPENGL
    );

    glContext = SDL_GL_CreateContext(window);
}

void InitOpenGLFunc()
{
    glGenBuffers              = (PFNGLGENBUFFERSPROC)              wglGetProcAddress("glGenBuffers");
    glBindBuffer              = (PFNGLBINDBUFFERPROC)              wglGetProcAddress("glBindBuffer");
    glBufferData              = (PFNGLBUFFERDATAPROC)              wglGetProcAddress("glBufferData");
    glCreateShader            = (PFNGLCREATESHADERPROC)            wglGetProcAddress("glCreateShader");
    glShaderSource            = (PFNGLSHADERSOURCEPROC)            wglGetProcAddress("glShaderSource");
    glCompileShader           = (PFNGLCOMPILESHADERPROC)           wglGetProcAddress("glCompileShader");
    glCreateProgram           = (PFNGLCREATEPROGRAMPROC)           wglGetProcAddress("glCreateProgram");
    glAttachShader            = (PFNGLATTACHSHADERPROC)            wglGetProcAddress("glAttachShader");
    glLinkProgram             = (PFNGLLINKPROGRAMPROC)             wglGetProcAddress("glLinkProgram");
    glUseProgram              = (PFNGLUSEPROGRAMPROC)              wglGetProcAddress("glUseProgram");
    glGetAttribLocation       = (PFNGLGETATTRIBLOCATIONPROC)       wglGetProcAddress("glGetAttribLocation");
    glEnableVertexAttribArray = (PFNGLENABLEVERTEXATTRIBARRAYPROC) wglGetProcAddress("glEnableVertexAttribArray");
    glVertexAttribPointer     = (PFNGLVERTEXATTRIBPOINTERPROC)     wglGetProcAddress("glVertexAttribPointer");
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

    glGenBuffers( 2, vbo );
    glBindBuffer( GL_ARRAY_BUFFER, vbo[0] );
    glBufferData( GL_ARRAY_BUFFER, sizeof( vertices ), vertices, GL_STATIC_DRAW );
    glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);

    glBindBuffer( GL_ARRAY_BUFFER, vbo[1] );
    glBufferData( GL_ARRAY_BUFFER, sizeof( colors ), colors, GL_STATIC_DRAW );
    glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);
}
