import core.sys.windows.windef;
import bindbc.sdl;
import bindbc.opengl;

extern(Windows)
int WinMain(HINSTANCE /* hInstance */, HINSTANCE /* hPrevInstance */, LPSTR /* lpCmdLine */, int /* nCmdShow */)
{
    import core.sys.windows.winuser : MessageBoxA, MB_OK, MB_ICONERROR;
    import core.stdc.stdio : sprintf;
    import core.stdc.string : strlen;
    
    int result = 0;
    const SDLSupport ret = loadSDL();
    if (ret != sdlSupport) {
        char[512] errorMsg;
        sprintf(errorMsg.ptr, "Failed to load SDL2.dll\nPlease download SDL2-2.32.10-win32-x64.zip from:\nhttps://github.com/libsdl-org/SDL/releases\nExtract SDL2.dll and place it in the same folder as hello.exe");
        MessageBoxA(null, errorMsg.ptr, "SDL2 Loading Error", MB_OK | MB_ICONERROR);
        return 1;
    }
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

    SDL_GL_MakeCurrent(appWin, gContext);
    
    const GLSupport openglLoaded = loadOpenGL();
    if (openglLoaded == GLSupport.noLibrary) {
        char[256] errorMsg;
        sprintf(errorMsg.ptr, "Failed to load OpenGL library");
        MessageBoxA(null, errorMsg.ptr, "OpenGL Loading Error", MB_OK | MB_ICONERROR);
        return 1;
    }
    
    // OpenGLバージョンとベンダー情報を確認
    import core.stdc.string : strlen;
    const(char)* glVersion = cast(const(char)*)glGetString(GL_VERSION);
    const(char)* glVendor = cast(const(char)*)glGetString(GL_VENDOR);
    const(char)* glRenderer = cast(const(char)*)glGetString(GL_RENDERER);
    
    char[512] infoMsg;
    if (glVersion !is null && glVendor !is null) {
        sprintf(infoMsg.ptr, "OpenGL Version: %s\nVendor: %s\nRenderer: %s", glVersion, glVendor, glRenderer);
    } else {
        sprintf(infoMsg.ptr, "Failed to get OpenGL info - Context may not be valid");
    }
    MessageBoxA(null, infoMsg.ptr, "OpenGL Info", MB_OK);

    // OpenGL初期設定
    glViewport(0, 0, 640, 480);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    bool quit = false;
    SDL_Event event;
    while(!quit) {
        // イベント処理
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                quit = true;
            }
        }

        // 描画処理
        glClearColor(0.2f, 0.3f, 0.4f, 1.0f);  // 青みがかった灰色に変更してOpenGLが動作しているか確認
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glBegin(GL_TRIANGLES);
            glColor3f(1.0f, 0.0f, 0.0f);  glVertex3f( 0.0f,  0.5f, 0.0f);
            glColor3f(0.0f, 1.0f, 0.0f);  glVertex3f(-0.5f, -0.5f, 0.0f);
            glColor3f(0.0f, 0.0f, 1.0f);  glVertex3f( 0.5f, -0.5f, 0.0f);
        glEnd();

        SDL_GL_SwapWindow(appWin);
    }
    return result;
}