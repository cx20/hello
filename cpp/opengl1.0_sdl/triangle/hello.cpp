#include <stdio.h>
#include <SDL.h>
#include <SDL_opengl.h>
#include <tchar.h>

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
{
    SDL_Window* window;
    SDL_GLContext glContext;

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

    SDL_Event ev;
    BOOL running = TRUE;
    while (running) {
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_QUIT)
                running = FALSE;
        }

        glBegin(GL_TRIANGLES);
            glColor3f(1.0f, 0.0f, 0.0f);  glVertex3f( 0.0f , 0.5f, 0.0f);
            glColor3f(0.0f, 1.0f, 0.0f);  glVertex3f(-0.5f, -0.5f, 0.0f);
            glColor3f(0.0f, 0.0f, 1.0f);  glVertex3f( 0.5f, -0.5f, 0.0f);
        glEnd();    

        SDL_GL_SwapWindow(window);
    }
    
    SDL_DestroyWindow(window);
    SDL_GL_DeleteContext(glContext);

    SDL_Quit();

    return 0;
}
