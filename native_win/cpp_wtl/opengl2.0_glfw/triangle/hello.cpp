#include <atlbase.h>
#include <atlapp.h>
#include <atlcrack.h>

#define GLEW_STATIC
#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

// Shader sources
const GLchar* vertexSource =
    "attribute vec3 position;                     \n"
    "attribute vec3 color;                        \n"
    "varying   vec4 vColor;                       \n"
    "void main()                                  \n"
    "{                                            \n"
    "  vColor = vec4(color, 1.0);                 \n"
    "  gl_Position = vec4(position, 1.0);         \n"
    "}                                            \n";
const GLchar* fragmentSource =
    "precision mediump float;                     \n"
    "varying   vec4 vColor;                       \n"
    "void main()                                  \n"
    "{                                            \n"
    "  gl_FragColor = vColor;                     \n"
    "}                                            \n";

class CHelloWindow : public CWindowImpl<CHelloWindow>
{
public:
    BEGIN_MSG_MAP( CHelloWindow )
        MSG_WM_CREATE  ( OnCreate  )
        MSG_WM_PAINT   ( OnPaint   )
        MSG_WM_DESTROY ( OnDestroy )
    END_MSG_MAP()
 
    LRESULT OnCreate(LPCREATESTRUCT lpcs);
    void OnPaint( HDC hDC );
    void OnDestroy();

    void InitOpenGL();
    void InitShader();
    void InitBuffer();
    void DrawTriangle();

private:
    GLFWwindow* m_window;
    GLuint m_shaderProgram;
    GLuint m_vbo[2];
    GLint m_posAttrib;
    GLint m_colAttrib;
};

LRESULT CHelloWindow::OnCreate(LPCREATESTRUCT lpcs)
{
    InitOpenGL();
    InitShader();
    InitBuffer();
    
    ResizeClient( 640, 480 );
    
    return 0L;
}

void CHelloWindow::OnPaint( HDC hDC )
{
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    DrawTriangle();

    glfwSwapBuffers( m_window );
}

void CHelloWindow::OnDestroy()
{
    PostQuitMessage( 0 );
 
    glfwTerminate();
}

void CHelloWindow::InitOpenGL()
{
    glfwInit();

    glfwWindowHint( GLFW_CONTEXT_VERSION_MAJOR, 2 );
    glfwWindowHint( GLFW_CONTEXT_VERSION_MINOR, 0 );
    
    m_window = glfwCreateWindow( 640, 480, "Hello, World!", NULL, NULL );
    glfwMakeContextCurrent( m_window );
    glfwSetWindowPos(m_window, 0, 0);
    
    HWND hwNative = glfwGetWin32Window(m_window);
    ::SetParent(hwNative, m_hWnd);

    glewInit();
}

void CHelloWindow::InitShader()
{
    GLuint vs;
    GLuint fs;

    vs = glCreateShader( GL_VERTEX_SHADER );
    glShaderSource( vs, 1, &vertexSource, NULL );
    glCompileShader( vs );

    fs = glCreateShader( GL_FRAGMENT_SHADER );
    glShaderSource( fs, 1, &fragmentSource, NULL );
    glCompileShader( fs );

    m_shaderProgram = glCreateProgram();
    glAttachShader( m_shaderProgram, fs );
    glAttachShader( m_shaderProgram, vs );

    glLinkProgram( m_shaderProgram );
    glUseProgram( m_shaderProgram );

    m_posAttrib = glGetAttribLocation(m_shaderProgram, "position");
    glEnableVertexAttribArray(m_posAttrib);

    m_colAttrib = glGetAttribLocation(m_shaderProgram, "color");
    glEnableVertexAttribArray(m_colAttrib);
}

void CHelloWindow::InitBuffer()
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

    glGenBuffers( 2, m_vbo );
    glBindBuffer( GL_ARRAY_BUFFER, m_vbo[0] );
    glBufferData( GL_ARRAY_BUFFER, sizeof( vertices ), vertices, GL_STATIC_DRAW );
    glVertexAttribPointer(m_posAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);

    glBindBuffer( GL_ARRAY_BUFFER, m_vbo[1] );
    glBufferData( GL_ARRAY_BUFFER, sizeof( colors ), colors, GL_STATIC_DRAW );
    glVertexAttribPointer(m_colAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);
}

void CHelloWindow::DrawTriangle()
{
    glBindBuffer( GL_ARRAY_BUFFER, m_vbo[0] );
    glVertexAttribPointer(m_posAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);

    glBindBuffer( GL_ARRAY_BUFFER, m_vbo[1] );
    glVertexAttribPointer(m_colAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);

    glDrawArrays( GL_TRIANGLES, 0, 3 );
}

CAppModule _Module;
 
int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    _Module.Init(NULL, hInstance);
 
    CMessageLoop theLoop;
    _Module.AddMessageLoop(&theLoop);
 
    CHelloWindow wnd;
    wnd.Create( NULL, CWindow::rcDefault, _T("Hello, World!"), WS_OVERLAPPEDWINDOW | WS_VISIBLE );
    int nRet = theLoop.Run();
 
    _Module.RemoveMessageLoop();
    _Module.Term();
 
    return nRet;
}