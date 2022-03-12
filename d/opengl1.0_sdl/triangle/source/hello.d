import core.sys.windows.windef;
import bindbc.sdl;
import bindbc.opengl;

extern(Windows)
int WinMain(HINSTANCE /* hInstance */, HINSTANCE /* hPrevInstance */, LPSTR /* lpCmdLine */, int /* nCmdShow */)
{
    int result = 0;
    const SDLSupport ret = loadSDL();
    SDL_Init(SDL_INIT_VIDEO);
    scope(exit) {
        SDL_Quit();
    }

    const windowFlags = SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI | SDL_WINDOW_SHOWN;
    SDL_Window* appWin = SDL_CreateWindow(
        "Hello, World!",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        640,
        480,
        windowFlags
    );
    scope(exit) {
        if (appWin !is null) {
            SDL_DestroyWindow(appWin);
        }
    }

    SDL_GLContext gContext = SDL_GL_CreateContext(appWin);
    scope(exit) {
        if (gContext !is null) {
            SDL_GL_DeleteContext(gContext);
        }
    }

    const GLSupport openglLoaded = loadOpenGL();
    SDL_GL_MakeCurrent(appWin, gContext);

    bool quit = false;
    while(!quit) {
        SDL_PumpEvents();

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor( 0f, 0f, 0f, 1f );

        glBegin( GL_TRIANGLES );
            glColor3f(1.0f, 0.0f, 0.0f);  glVertex3f( 0.0f , 0.5f, 0.0f);
            glColor3f(0.0f, 1.0f, 0.0f);  glVertex3f(-0.5f, -0.5f, 0.0f);
            glColor3f(0.0f, 0.0f, 1.0f);  glVertex3f( 0.5f, -0.5f, 0.0f);
        glEnd();

        glFlush();
        SDL_GL_SwapWindow(appWin);

        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                quit = true;
            }
        }
    }
    return result;
}