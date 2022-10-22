#include <windows.h>
#include <tchar.h>
#include <gl/gl.h>
#include <time.h>
#include "linmath.h"

#ifndef APIENTRY
#define APIENTRY
#endif

#ifndef APIENTRYP
#define APIENTRYP APIENTRY *
#endif

#define GL_ARRAY_BUFFER                   0x8892
#define GL_ELEMENT_ARRAY_BUFFER           0x8893
#define GL_STATIC_DRAW                    0x88E4
#define GL_FRAGMENT_SHADER                0x8B30
#define GL_VERTEX_SHADER                  0x8B31

typedef ptrdiff_t GLsizeiptr;
typedef char GLchar;

typedef void (APIENTRYP PFNGLGENBUFFERSPROC) (GLsizei n, GLuint *buffers);
typedef void (APIENTRYP PFNGLBINDBUFFERPROC) (GLenum target, GLuint buffer);
typedef void (APIENTRYP PFNGLBUFFERDATAPROC) (GLenum target, GLsizeiptr size, const void *data, GLenum usage);
typedef GLuint (APIENTRYP PFNGLCREATESHADERPROC) (GLenum type);
typedef void (APIENTRYP PFNGLSHADERSOURCEPROC) (GLuint shader, GLsizei count, const GLchar* const* string, const GLint* length);
typedef void (APIENTRYP PFNGLCOMPILESHADERPROC) (GLuint shader);
typedef GLuint (APIENTRYP PFNGLCREATEPROGRAMPROC) (void);
typedef void (APIENTRYP PFNGLATTACHSHADERPROC) (GLuint program, GLuint shader);
typedef void (APIENTRYP PFNGLLINKPROGRAMPROC) (GLuint program);
typedef void (APIENTRYP PFNGLUSEPROGRAMPROC) (GLuint program);
typedef GLint (APIENTRYP PFNGLGETATTRIBLOCATIONPROC) (GLuint program, const GLchar* name);
typedef GLint (APIENTRYP PFNGLGETUNIFORMLOCATIONPROC) (GLuint program, const GLchar* name);
typedef void (APIENTRYP PFNGLENABLEVERTEXATTRIBARRAYPROC) (GLuint index);
typedef void (APIENTRYP PFNGLVERTEXATTRIBPOINTERPROC) (GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer);
typedef void (APIENTRYP PFNGLUNIFORMMATRIX4FVPROC) (GLint location, GLsizei count, GLboolean transpose, const GLfloat* value);

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
PFNGLGETUNIFORMLOCATIONPROC       glGetUniformLocation;
PFNGLENABLEVERTEXATTRIBARRAYPROC  glEnableVertexAttribArray;
PFNGLVERTEXATTRIBPOINTERPROC      glVertexAttribPointer;
PFNGLUNIFORMMATRIX4FVPROC         glUniformMatrix4fv;

LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
HGLRC EnableOpenGL(HDC hDC);
void DisableOpenGL(HWND hWnd, HDC hDC, HGLRC hRC);
void InitOpenGLFunc();
void InitShader();
void DrawCube();

// Shader sources
// Shader sources
const GLchar* vertexSource =
    "attribute vec3 position;                     \n"
    "attribute vec4 color;                        \n"
    "uniform mat4 uPMatrix;                       \n"
    "uniform mat4 uMVMatrix;                      \n"
    "varying   vec4 vColor;                       \n"
    "void main()                                  \n"
    "{                                            \n"
    "  vColor = color;                            \n"
    "  gl_Position = uPMatrix * uMVMatrix * vec4(position, 1.0);         \n"
    "}                                            \n";
const GLchar* fragmentSource =
    "precision mediump float;\n"
    "varying   vec4 vColor;                       \n"
    "void main()                                  \n"
    "{                                            \n"
    "  gl_FragColor = vColor;                     \n"
    "}                                            \n";

GLuint vbo[2];
GLuint ibo;
GLint posAttrib;
GLint colAttrib;

GLfloat rad = 0.0; 
GLint uPMatrix;
GLint uMVMatrix; 
mat4x4 projection_matrix;
mat4x4 model_view_matrix;

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
{
    WNDCLASSEX wcex;
    HWND hWnd;
    HDC hDC;
    HGLRC hRC;
    MSG msg;
    BOOL bQuit = FALSE;

    wcex.cbSize         = sizeof(WNDCLASSEX);
    wcex.style          = CS_OWNDC;
    wcex.lpfnWndProc    = WindowProc;
    wcex.cbClsExtra     = 0;
    wcex.cbWndExtra     = 0;
    wcex.hInstance      = hInstance;
    wcex.hIcon          = LoadIcon(NULL, IDI_APPLICATION);
    wcex.hCursor        = LoadCursor(NULL, IDC_ARROW);
    wcex.hbrBackground  = (HBRUSH)GetStockObject(BLACK_BRUSH);
    wcex.lpszMenuName   = NULL;
    wcex.lpszClassName  = _T("WindowClass");
    wcex.hIconSm        = LoadIcon(NULL, IDI_APPLICATION);

    if (!RegisterClassEx(&wcex))
        return 0;

    hWnd = CreateWindowEx(0,
                          _T("WindowClass"),
                          _T("Hello, World!"),
                          WS_OVERLAPPEDWINDOW,
                          CW_USEDEFAULT,
                          CW_USEDEFAULT,
                          640,
                          480,
                          NULL,
                          NULL,
                          hInstance,
                          NULL);

    ShowWindow(hWnd, nCmdShow);

    hDC = GetDC(hWnd);
    hRC = EnableOpenGL(hDC);
    
    InitOpenGLFunc();
    
    InitShader();

    while (!bQuit)
    {
        if (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
        {
            if (msg.message == WM_QUIT)
            {
                bQuit = TRUE;
            }
            else
            {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
        }
        else
        {
            glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

            DrawCube();

            SwapBuffers(hDC);

            Sleep (1);
        }
    }

    DisableOpenGL(hWnd, hDC, hRC);
    DestroyWindow(hWnd);

    return msg.wParam;
}

LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    switch (uMsg)
    {
        case WM_CLOSE:
            PostQuitMessage(0);
        break;

        case WM_DESTROY:
            return 0;

        default:
            return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }

    return 0;
}

HGLRC EnableOpenGL(HDC hDC)
{
    HGLRC hRC = NULL;
    
    PIXELFORMATDESCRIPTOR pfd;

    int iFormat;

    ZeroMemory(&pfd, sizeof(pfd));

    pfd.nSize = sizeof(pfd);
    pfd.nVersion = 1;
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = 24;
    pfd.cDepthBits = 16;
    pfd.iLayerType = PFD_MAIN_PLANE;

    iFormat = ChoosePixelFormat(hDC, &pfd);

    SetPixelFormat(hDC, iFormat, &pfd);

    hRC = wglCreateContext(hDC);
    wglMakeCurrent(hDC, hRC);

    return  hRC;
}

void DisableOpenGL(HWND hWnd, HDC hDC, HGLRC hRC)
{
    wglMakeCurrent(NULL, NULL);
    wglDeleteContext(hRC);
    ReleaseDC(hWnd, hDC);
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
    glGetUniformLocation      = (PFNGLGETUNIFORMLOCATIONPROC)      wglGetProcAddress("glGetUniformLocation");
    glEnableVertexAttribArray = (PFNGLENABLEVERTEXATTRIBARRAYPROC) wglGetProcAddress("glEnableVertexAttribArray");
    glVertexAttribPointer     = (PFNGLVERTEXATTRIBPOINTERPROC)     wglGetProcAddress("glVertexAttribPointer");
    glUniformMatrix4fv        = (PFNGLUNIFORMMATRIX4FVPROC)        wglGetProcAddress("glUniformMatrix4fv");
}

void InitShader()
{
    // Create a Vertex Buffer Object and copy the vertex data to it
    glGenBuffers(2, vbo);
    glGenBuffers(1, &ibo);

    // Cube data
    //             1.0 y 
    //              ^  -1.0 
    //              | / z
    //              |/       x
    // -1.0 -----------------> +1.0
    //            / |
    //      +1.0 /  |
    //           -1.0
    // 
    //         [7]------[6]
    //        / |      / |
    //      [3]------[2] |
    //       |  |     |  |
    //       | [4]----|-[5]
    //       |/       |/
    //      [0]------[1]
    //
    GLfloat vertices[] = {
        // Front face
        -0.5f, -0.5f,  0.5f, // v0
         0.5f, -0.5f,  0.5f, // v1
         0.5f,  0.5f,  0.5f, // v2
        -0.5f,  0.5f,  0.5f, // v3
        // Back face
        -0.5f, -0.5f, -0.5f, // v4
         0.5f, -0.5f, -0.5f, // v5
         0.5f,  0.5f, -0.5f, // v6
        -0.5f,  0.5f, -0.5f, // v7
        // Top face
         0.5f,  0.5f,  0.5f, // v2
        -0.5f,  0.5f,  0.5f, // v3
        -0.5f,  0.5f, -0.5f, // v7
         0.5f,  0.5f, -0.5f, // v6
        // Bottom face
        -0.5f, -0.5f,  0.5f, // v0
         0.5f, -0.5f,  0.5f, // v1
         0.5f, -0.5f, -0.5f, // v5
        -0.5f, -0.5f, -0.5f, // v4
         // Right face
         0.5f, -0.5f,  0.5f, // v1
         0.5f,  0.5f,  0.5f, // v2
         0.5f,  0.5f, -0.5f, // v6
         0.5f, -0.5f, -0.5f, // v5
         // Left face
        -0.5f, -0.5f,  0.5f, // v0
        -0.5f,  0.5f,  0.5f, // v3
        -0.5f,  0.5f, -0.5f, // v7
        -0.5f, -0.5f, -0.5f  // v4
    };

    GLfloat colors[] = {
        1.0f, 0.0f, 0.0f, 1.0f, // Front face
        1.0f, 0.0f, 0.0f, 1.0f, // Front face
        1.0f, 0.0f, 0.0f, 1.0f, // Front face
        1.0f, 0.0f, 0.0f, 1.0f, // Front face
        1.0f, 1.0f, 0.0f, 1.0f, // Back face
        1.0f, 1.0f, 0.0f, 1.0f, // Back face
        1.0f, 1.0f, 0.0f, 1.0f, // Back face
        1.0f, 1.0f, 0.0f, 1.0f, // Back face
        0.0f, 1.0f, 0.0f, 1.0f, // Top face
        0.0f, 1.0f, 0.0f, 1.0f, // Top face
        0.0f, 1.0f, 0.0f, 1.0f, // Top face
        0.0f, 1.0f, 0.0f, 1.0f, // Top face
        1.0f, 0.5f, 0.5f, 1.0f, // Bottom face
        1.0f, 0.5f, 0.5f, 1.0f, // Bottom face
        1.0f, 0.5f, 0.5f, 1.0f, // Bottom face
        1.0f, 0.5f, 0.5f, 1.0f, // Bottom face
        1.0f, 0.0f, 1.0f, 1.0f, // Right face
        1.0f, 0.0f, 1.0f, 1.0f, // Right face
        1.0f, 0.0f, 1.0f, 1.0f, // Right face
        1.0f, 0.0f, 1.0f, 1.0f, // Right face
        0.0f, 0.0f, 1.0f, 1.0f, // Left face
        0.0f, 0.0f, 1.0f, 1.0f, // Left face
        0.0f, 0.0f, 1.0f, 1.0f, // Left face
        0.0f, 0.0f, 1.0f, 1.0f  // Left face
    };

    GLuint indices[] = {
         0,  1,  2,    0,  2,  3,  // Front face
         4,  5,  6,    4,  6,  7,  // Back face
         8,  9, 10,    8, 10, 11,  // Top face
        12, 13, 14,   12, 14, 15,  // Bottom face
        16, 17, 18,   16, 18, 19,  // Right face
        20, 21, 22,   20, 22, 23   // Left face
    };

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(colors), colors, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

    // Create and compile the vertex shader
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexSource, nullptr);
    glCompileShader(vertexShader);

    // Create and compile the fragment shader
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentSource, nullptr);
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

    uPMatrix = glGetUniformLocation(shaderProgram,  "uPMatrix");
    uMVMatrix = glGetUniformLocation(shaderProgram, "uMVMatrix"); 
}

void DrawCube()
{
    //rad += M_PI * 1.0 / 180.0;
    rad = (double)clock() / CLOCKS_PER_SEC;

    mat4x4_perspective(projection_matrix, 45, (float)640 / (float)480, 1, 100);
    mat4x4_identity(model_view_matrix);
    mat4x4_translate_in_place(model_view_matrix, 0.0, 0.0, -2.0);
    mat4x4_rotate(model_view_matrix, model_view_matrix, 1.0, 1.0, 1.0, rad);

    glUniformMatrix4fv(uPMatrix,  1, GL_FALSE, (const GLfloat*)projection_matrix);
    glUniformMatrix4fv(uMVMatrix, 1, GL_FALSE, (const GLfloat*)model_view_matrix);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glVertexAttribPointer(colAttrib, 4, GL_FLOAT, GL_FALSE, 0, 0);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // Draw a cube from the 36 vertices
    glDrawElements(GL_TRIANGLES, 36, GL_UNSIGNED_INT, 0);
}
