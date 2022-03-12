import std.stdio;
import std.string;
import std.conv;
import core.sys.windows.windef;
import bindbc.sdl;
import bindbc.opengl;

GLuint[2] vbo;
GLint posAttrib;
GLint colAttrib;
SDL_Window* window;
SDL_GLContext glContext;

// Shader sources
immutable string vertexSource = `
attribute vec3 position;                     
attribute vec3 color;                        
varying   vec4 vColor;                       
void main()                                  
{                                            
  vColor = vec4(color, 1.0);                 
  gl_Position = vec4(position, 1.0);         
}`;

immutable string fragmentSource = `
precision mediump float;                     
varying   vec4 vColor;                       
void main()                                  
{                                            
  gl_FragColor = vColor;                     
}`;

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


    InitShader();
    
    bool quit = false;
    while(!quit) {
        SDL_PumpEvents();

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor( 1f, 0f, 0f, 1f );
        
        DrawTriangle();

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

void InitShader()
{
    glGenBuffers(2, vbo.ptr);

    GLfloat[] vertices = [
          0.0f,  0.5f, 0.0f, 
          0.5f, -0.5f, 0.0f, 
         -0.5f, -0.5f, 0.0f
    ];

    GLfloat[] colors = [
         1.0f,  0.0f,  0.0f,
         0.0f,  1.0f,  0.0f,
         0.0f,  0.0f,  1.0f
    ];

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, vertices.sizeof, vertices.ptr, GL_STATIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, colors.sizeof, colors.ptr, GL_STATIC_DRAW);

    // Create and compile the vertex shader
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    auto vs = vertexSource.toStringz;
    glShaderSource(vertexShader, 1, &vs, null);
    glCompileShader(vertexShader);

    // Create and compile the fragment shader
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    auto fs = fragmentSource.toStringz;
    glShaderSource(fragmentShader, 1, &fs, null);
    glCompileShader(fragmentShader);

    // Link the vertex and fragment shader into a shader program
    GLuint shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    glUseProgram(shaderProgram);

    // Specify the layout of the vertex data
    posAttrib = glGetAttribLocation(shaderProgram, "position");
    glEnableVertexAttribArray(posAttrib);

    colAttrib = glGetAttribLocation(shaderProgram, "color");
    glEnableVertexAttribArray(colAttrib);
}

void DrawTriangle()
{
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);
    
    // Draw a triangle from the 3 vertices
    glDrawArrays(GL_TRIANGLES, 0, 3);
}
