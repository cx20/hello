$source = @"
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;

using GLenum  = System.UInt32;
using GLint   = System.UInt32;
using GLuint  = System.UInt32;
using GLsizei = System.UInt32;
using GLfloat = System.Single;

public class HelloForm : Form
{
    const int GL_TRIANGLES        = 0x0004;
    const int GL_TRIANGLE_STRIP   = 0x0005;
    
    const int GL_FLOAT            = 0x1406;
    const int GL_VERTEX_ARRAY     = 0x8074;
    const int GL_COLOR_ARRAY      = 0x8076;
    const int GL_COLOR_BUFFER_BIT = 0x00004000;
    
    const int GL_ARRAY_BUFFER     = 0x8892;
    const int GL_STATIC_DRAW      = 0x88E4;
    const int GL_FRAGMENT_SHADER  = 0x8B30;
    const int GL_VERTEX_SHADER    = 0x8B31;

    const int PFD_TYPE_RGBA      =  0;
    const int PFD_DOUBLEBUFFER   =  1;
    const int PFD_DRAW_TO_WINDOW =  4;
    const int PFD_SUPPORT_OPENGL = 32;
    
    [StructLayout(LayoutKind.Sequential)] 
    public struct PIXELFORMATDESCRIPTOR 
    {
        public ushort  nSize;
        public ushort  nVersion;
        public uint    dwFlags;
        public byte    iPixelType;
        public byte    cColorBits;
        public byte    cRedBits;
        public byte    cRedShift;
        public byte    cGreenBits;
        public byte    cGreenShift;
        public byte    cBlueBits;
        public byte    cBlueShift;
        public byte    cAlphaBits;
        public byte    cAlphaShift;
        public byte    cAccumBits;
        public byte    cAccumRedBits;
        public byte    cAccumGreenBits;
        public byte    cAccumBlueBits;
        public byte    cAccumAlphaBits;
        public byte    cDepthBits;
        public byte    cStencilBits;
        public byte    cAuxBuffers;
        public byte    iLayerType;
        public byte    bReserved;
        public uint    dwLayerMask;
        public uint    dwVisibleMask;
        public uint    dwDamageMask;
    }

    [DllImport("user32.dll")]
    static extern IntPtr GetDC(IntPtr ptr);
    [DllImport("user32.dll")]
    static extern IntPtr ReleaseDC(IntPtr hWnd, IntPtr hDc);
    
    [DllImport("gdi32.dll")]
    static extern int ChoosePixelFormat(IntPtr hdc, [In] ref PIXELFORMATDESCRIPTOR pfd);
    [DllImport("gdi32.dll")]
    static extern bool SetPixelFormat(IntPtr hdc, int format, [In] ref PIXELFORMATDESCRIPTOR pfd);
    [DllImport("gdi32.dll")]
    static extern bool SwapBuffers(IntPtr hDC);
    
    [DllImport("opengl32")]
    static extern IntPtr wglCreateContext( IntPtr hdc );
    [DllImport("opengl32")]
    static extern int wglMakeCurrent( IntPtr hdc, IntPtr hglrc );
    [DllImport("opengl32")]
    static extern int wglDeleteContext( IntPtr hglrc );
    [DllImport("opengl32")]
    static extern void glClearColor(float red, float green, float blue, float alpha);
    [DllImport("opengl32")]
    static extern void glClear(uint mask);
    [DllImport("opengl32")]
    static extern void glBegin(GLenum mode);
    [DllImport("opengl32")]
    static extern void glColor3f(GLfloat red, GLfloat green, GLfloat blue);
    [DllImport("opengl32")]
    static extern void glVertex2f(GLfloat x, GLfloat y);
    [DllImport("opengl32")]
    static extern void glEnd();
    [DllImport("opengl32")]
    static extern void glEnableClientState(GLenum array);
    [DllImport("opengl32")]
    static extern void glColorPointer(GLint size, GLenum type, GLsizei stride, IntPtr pointer);
    [DllImport("opengl32")]
    static extern void glVertexPointer(GLint size, GLenum type, GLsizei stride, IntPtr pointer);
    [DllImport("opengl32")]
    static extern void glDrawArrays(GLenum mode, GLint first, GLsizei count);
    [DllImport("opengl32")]
    static extern IntPtr wglGetProcAddress(string functionName);
    
    delegate void glGenBuffersDelegate(int n, uint[] buffers);
    delegate void glBindBufferDelegate(uint target, uint buffer);
    delegate void glBufferDataFloatDelegate(uint target, int size, float[] data, uint usage);
    delegate uint glCreateShaderDelegate(uint type);
    delegate void glShaderSourceDelegate(uint shader, int count, string[] @string, int[] length);
    delegate void glCompileShaderDelegate(uint shader);
    delegate uint glCreateProgramDelegate();
    delegate void glAttachShaderDelegate(uint program, uint shader);
    delegate void glLinkProgramDelegate(uint program);
    delegate void glUseProgramDelegate(uint program);
    delegate uint glGetAttribLocationDelegate(uint program, string name);
    delegate void glEnableVertexAttribArrayDelegate(uint index);
    delegate void glVertexAttribPointerDelegate(uint index, int size, uint type, bool normalized, int stride, IntPtr pointer);
    delegate IntPtr wglCreateContextAttribsARBDelegate(IntPtr hDC, IntPtr hShareContext, int[] attribList);

    glGenBuffersDelegate                glGenBuffers;
    glBindBufferDelegate                glBindBuffer;
    glBufferDataFloatDelegate           glBufferDataFloat;
    glCreateShaderDelegate              glCreateShader;
    glShaderSourceDelegate              glShaderSource;
    glCompileShaderDelegate             glCompileShader;
    glCreateProgramDelegate             glCreateProgram;
    glAttachShaderDelegate              glAttachShader;
    glLinkProgramDelegate               glLinkProgram;
    glUseProgramDelegate                glUseProgram;
    glGetAttribLocationDelegate         glGetAttribLocation;
    glEnableVertexAttribArrayDelegate   glEnableVertexAttribArray;
    glVertexAttribPointerDelegate       glVertexAttribPointer;
    wglCreateContextAttribsARBDelegate  wglCreateContextAttribsARB;

    IntPtr hDC   = (IntPtr)0;
    IntPtr hGLRC = (IntPtr)0;
    GLuint[] vbo;
    GLint posAttrib;
    GLint colAttrib;

    const string vertexSource =
        "#version 460 core                            \n" +
        "layout(location = 0) in  vec3 position;      \n" +
        "layout(location = 1) in  vec3 color;         \n" +
        "out vec4 vColor;                             \n" +
        "void main()                                  \n" +
        "{                                            \n" +
        "  vColor = vec4(color, 1.0);                 \n" +
        "  gl_Position = vec4(position, 1.0);         \n" +
        "}                                            \n";
    const string fragmentSource =
        "#version 460 core                            \n" +
        "precision mediump float;                     \n" +
        "in  vec4 vColor;                             \n" +
        "out vec4 outColor;                           \n" +
        "void main()                                  \n" +
        "{                                            \n" +
        "  outColor = vColor;                         \n" +
        "}                                            \n";

    public HelloForm()
    {
        this.Size = new Size( 640, 480 );
        this.Text = "Hello, World!";
        vbo = new uint[2];
    }
    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        
        EnableOpenGL();
        InitOpenGLFunc();
        InitShader();
    }
    
    protected override void OnPaint(PaintEventArgs e) {  
        base.OnPaint(e); 

        DrawTriangle();
    }
    
    protected override void OnClosed(EventArgs e) {
        base.OnClosed(e);
        
        DisableOpenGL();
    }

    void EnableOpenGL() {
        PIXELFORMATDESCRIPTOR pfd = new PIXELFORMATDESCRIPTOR();
        pfd.dwFlags    = PFD_SUPPORT_OPENGL | PFD_DRAW_TO_WINDOW | PFD_DOUBLEBUFFER;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cColorBits = 32;
        pfd.cAlphaBits = 8;
        pfd.cDepthBits = 24;
        
        this.hDC = GetDC(this.Handle);
        int format = ChoosePixelFormat(hDC, ref pfd);
        
        SetPixelFormat(hDC, format, ref pfd);
        
        IntPtr hGLRC_old = wglCreateContext( this.hDC );
        wglMakeCurrent(this.hDC, hGLRC_old);

        IntPtr wglCreateContextAttribsARBPtr = wglGetProcAddress("wglCreateContextAttribsARB");
        wglCreateContextAttribsARB = Marshal.GetDelegateForFunctionPointer<wglCreateContextAttribsARBDelegate>(wglCreateContextAttribsARBPtr);

        this.hGLRC = wglCreateContextAttribsARB(this.hDC, IntPtr.Zero, null);

        wglMakeCurrent(this.hDC, this.hGLRC);
        wglDeleteContext(hGLRC_old);
    }
    
    void InitOpenGLFunc() {
        IntPtr glGenBuffersPtr              = wglGetProcAddress("glGenBuffers");
        IntPtr glBindBufferPtr              = wglGetProcAddress("glBindBuffer");
        IntPtr glBufferDataPtr              = wglGetProcAddress("glBufferData");
        IntPtr glCreateShaderPtr            = wglGetProcAddress("glCreateShader");
        IntPtr glShaderSourcePtr            = wglGetProcAddress("glShaderSource");
        IntPtr glCompileShaderPtr           = wglGetProcAddress("glCompileShader");
        IntPtr glCreateProgramPtr           = wglGetProcAddress("glCreateProgram");
        IntPtr glAttachShaderPtr            = wglGetProcAddress("glAttachShader");
        IntPtr glLinkProgramPtr             = wglGetProcAddress("glLinkProgram");
        IntPtr glUseProgramPtr              = wglGetProcAddress("glUseProgram");
        IntPtr glGetAttribLocationPtr       = wglGetProcAddress("glGetAttribLocation");
        IntPtr glEnableVertexAttribArrayPtr = wglGetProcAddress("glEnableVertexAttribArray");
        IntPtr glVertexAttribPointerPtr     = wglGetProcAddress("glVertexAttribPointer");

        glGenBuffers               = Marshal.GetDelegateForFunctionPointer<glGenBuffersDelegate               >(glGenBuffersPtr             );
        glBindBuffer               = Marshal.GetDelegateForFunctionPointer<glBindBufferDelegate               >(glBindBufferPtr             );
        glBufferDataFloat          = Marshal.GetDelegateForFunctionPointer<glBufferDataFloatDelegate          >(glBufferDataPtr             );
        glCreateShader             = Marshal.GetDelegateForFunctionPointer<glCreateShaderDelegate             >(glCreateShaderPtr           );
        glShaderSource             = Marshal.GetDelegateForFunctionPointer<glShaderSourceDelegate             >(glShaderSourcePtr           );
        glCompileShader            = Marshal.GetDelegateForFunctionPointer<glCompileShaderDelegate            >(glCompileShaderPtr          );
        glCreateProgram            = Marshal.GetDelegateForFunctionPointer<glCreateProgramDelegate            >(glCreateProgramPtr          );
        glAttachShader             = Marshal.GetDelegateForFunctionPointer<glAttachShaderDelegate             >(glAttachShaderPtr           );
        glLinkProgram              = Marshal.GetDelegateForFunctionPointer<glLinkProgramDelegate              >(glLinkProgramPtr            );
        glUseProgram               = Marshal.GetDelegateForFunctionPointer<glUseProgramDelegate               >(glUseProgramPtr             );
        glGetAttribLocation        = Marshal.GetDelegateForFunctionPointer<glGetAttribLocationDelegate        >(glGetAttribLocationPtr      );
        glEnableVertexAttribArray  = Marshal.GetDelegateForFunctionPointer<glEnableVertexAttribArrayDelegate  >(glEnableVertexAttribArrayPtr);
        glVertexAttribPointer      = Marshal.GetDelegateForFunctionPointer<glVertexAttribPointerDelegate      >(glVertexAttribPointerPtr    );
    }
    
    void InitShader() {
        GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
        string[] shaderSource = new string[1];
        shaderSource[0] = vertexSource;
        glShaderSource(vertexShader, 1, shaderSource, null);
        glCompileShader(vertexShader);
        
        GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
        shaderSource[0] = fragmentSource;
        glShaderSource(fragmentShader, 1, shaderSource, null);
        glCompileShader(fragmentShader);

        GLuint shaderProgram = glCreateProgram();
        glAttachShader(shaderProgram, vertexShader);
        glAttachShader(shaderProgram, fragmentShader);
        glLinkProgram(shaderProgram);
        glUseProgram(shaderProgram);

        posAttrib = glGetAttribLocation(shaderProgram, "position");
        glEnableVertexAttribArray(posAttrib);

        colAttrib = glGetAttribLocation(shaderProgram, "color");
        glEnableVertexAttribArray(colAttrib);

        glGenBuffers(2, vbo);

        float[] vertices =
        {
            -0.5f, -0.5f, 0.0f,
             0.5f, -0.5f, 0.0f,
             0.0f,  0.5f, 0.0f 
        };

        float[] colors = {
             1.0f,  0.0f,  0.0f,
             0.0f,  1.0f,  0.0f,
             0.0f,  0.0f,  1.0f
        };
        
        glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
        glBufferDataFloat(GL_ARRAY_BUFFER, vertices.Length * sizeof(float), vertices, GL_STATIC_DRAW);
    
        glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
        glBufferDataFloat(GL_ARRAY_BUFFER, colors.Length * sizeof(float), colors, GL_STATIC_DRAW);
    }

    void DrawTriangle() {
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
        glVertexAttribPointer(posAttrib, 3, GL_FLOAT, false, 0, IntPtr.Zero);
        
        glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
        glVertexAttribPointer(colAttrib, 3, GL_FLOAT, false, 0, IntPtr.Zero);
        
        glClear(GL_COLOR_BUFFER_BIT);

        // Draw a triangle from the 3 vertices
        glDrawArrays(GL_TRIANGLES, 0, 3);

        SwapBuffers(this.hDC);
    }
    
    void DisableOpenGL() {
        wglMakeCurrent(IntPtr.Zero, IntPtr.Zero);
        wglDeleteContext(this.hGLRC);
        ReleaseDC(this.Handle, this.hDC);
    }

    [STAThread]
    public static void Main()
    {
        HelloForm form = new HelloForm();
        Application.Run(form);
    }
}
"@
$path = "C:\Windows\Microsoft.NET\Framework\v4.0.30319"
$assemblies = @(
	"$path\System.dll",
	"$path\System.Drawing.dll",
	"$path\System.Windows.Forms.dll",
	"$path\System.Runtime.InteropServices.dll"
)
$cp = [System.CodeDom.Compiler.CompilerParameters]::new($assemblies)
Add-Type -Language CSharp -TypeDefinition $source -CompilerParameters $cp
[void][HelloForm]::Main()
