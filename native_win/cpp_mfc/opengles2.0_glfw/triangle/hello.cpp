#include <afxwin.h>
#include <tchar.h>

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

class CMainFrame : public CFrameWnd
{
public:
    CMainFrame();
    BOOL PreCreateWindow(CREATESTRUCT& cs);
protected:
    afx_msg int OnCreate(LPCREATESTRUCT lpCreateStruct);
    afx_msg void OnPaint();
    DECLARE_MESSAGE_MAP()
    
private:
    void InitOpenGL();
    void InitShader();
    void InitBuffer();

    GLFWwindow* m_window;
    HWND m_hwNative;
    
    GLuint m_shaderProgram;
    GLuint m_vao;
    GLuint m_vbo[2];
    GLint m_posAttrib;
    GLint m_colAttrib;
};
 
class CHelloApp : public CWinApp
{
public:
    BOOL InitInstance();
};
 
BOOL CHelloApp::InitInstance()
{
    m_pMainWnd = new CMainFrame;
    m_pMainWnd->ShowWindow(m_nCmdShow);
    m_pMainWnd->UpdateWindow();
    return TRUE;
}
 
CHelloApp App;
 
BEGIN_MESSAGE_MAP( CMainFrame, CFrameWnd )
    ON_WM_CREATE()
    ON_WM_PAINT()
END_MESSAGE_MAP()
 
CMainFrame::CMainFrame()
{
    Create( NULL, _T("Hello, World!") );
}
 
BOOL CMainFrame::PreCreateWindow(CREATESTRUCT& cs)
{
    CFrameWnd::PreCreateWindow(cs);
    cs.cx = 640;
    cs.cy = 480;

    return TRUE;
}

int CMainFrame::OnCreate(LPCREATESTRUCT lpCreateStruct)
{
    CFrameWnd::OnCreate(lpCreateStruct);
    
    InitOpenGL();
    InitShader();
    InitBuffer();

    return  0;
}


void CMainFrame::InitOpenGL()
{
    glfwInit();

    m_window = glfwCreateWindow(640, 480, "", NULL, NULL);
    glfwMakeContextCurrent( m_window );
    glfwSetWindowPos(m_window, 0, 0);

    m_hwNative = glfwGetWin32Window(m_window);
    ::SetParent(m_hwNative, m_hWnd);
    
    glewInit();
}

void CMainFrame::InitShader()
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

void CMainFrame::InitBuffer()
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

    glGenVertexArrays(1, &m_vao);
    glBindVertexArray(m_vao);
    
    glGenBuffers( 2, m_vbo );
    glBindBuffer( GL_ARRAY_BUFFER, m_vbo[0] );
    glEnableVertexArrayAttrib(m_vao, 0);
    glBufferData( GL_ARRAY_BUFFER, sizeof( vertices ), vertices, GL_STATIC_DRAW );
    glVertexAttribPointer(m_posAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);

    glBindBuffer( GL_ARRAY_BUFFER, m_vbo[1] );
    glEnableVertexArrayAttrib(m_vao, 1);
    glBufferData( GL_ARRAY_BUFFER, sizeof( colors ), colors, GL_STATIC_DRAW );
    glVertexAttribPointer(m_colAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);
}

void CMainFrame::OnPaint()
{
    CPaintDC dc(this);
    
    ::UpdateWindow( m_hwNative ); // TODO: This is a tentative fix. Needs investigate the right way.

    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glBindVertexArray( m_vao );

    glDrawArrays( GL_TRIANGLES, 0, 3 );

    glfwPollEvents();
    glfwSwapBuffers( m_window );
}