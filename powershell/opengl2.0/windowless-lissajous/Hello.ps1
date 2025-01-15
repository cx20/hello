$source = @"
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Collections.Generic;

using GLenum  = System.UInt32;
using GLint   = System.UInt32;
using GLuint  = System.UInt32;
using GLsizei = System.UInt32;
using GLfloat = System.Single;

public class HelloForm : Form
{
    const int GL_POINTS           = 0x0000;
    const int GL_LINE_STRIP       = 0x0003;
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
    static extern uint wglCreateContext( uint hdc );
    [DllImport("opengl32")]
    static extern int wglMakeCurrent( uint hdc, uint hglrc );
    [DllImport("opengl32")]
    static extern int wglDeleteContext( uint hglrc );
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
    delegate uint glGetUniformLocationDelegate(uint program, string name);
    delegate void glEnableVertexAttribArrayDelegate(uint index);
    delegate void glVertexAttribPointerDelegate(uint index, int size, uint type, bool normalized, int stride, IntPtr pointer);
    delegate void glUniform1fDelegate(uint location, float v0);

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
    glGetUniformLocationDelegate        glGetUniformLocation;
    glEnableVertexAttribArrayDelegate   glEnableVertexAttribArray;
    glVertexAttribPointerDelegate       glVertexAttribPointer;
    glUniform1fDelegate                 glUniform1f;

    IntPtr hDC   = (IntPtr)0;
    IntPtr hGLRC = (IntPtr)0;
    GLuint[] vbo;
    GLint posAttrib;
    GLint colAttrib;
    GLint angle_loc;

    float[] vertices = {};
    float[] colors = {};

    const int MAX = 72;
    const float A = 2.0F;
    const float B = 3.0F;
    const float SCALE = 1.0F;

    const string vertexSource =
        "attribute vec3 position;                                \n" +
        "attribute vec3 color;                                   \n" +
        "uniform float angle;                                    \n" +
        "varying   vec4 vColor;                                  \n" +
        "mat4 rotationY( in float angle ) {                      \n" +
        "   return mat4( cos(angle),  0.0, sin(angle), 0.0,      \n" +
        "                       0.0,  1.0,        0.0, 0.0,      \n" +
        "               -sin(angle),  0.0, cos(angle), 0.0,      \n" +
        "                       0.0,  0.0,        0.0, 1.0);     \n" +
        "}                                                       \n" +
        "void main()                                             \n" +
        "{                                                       \n" +
        "  vColor = vec4(color, 1.0);                            \n" +
        "  gl_Position = rotationY(angle) * vec4(position, 1.0); \n" +
        "  gl_PointSize = 10.0;                                  \n" +
        "}                                                       \n";

    const string fragmentSource =
        "precision mediump float;                                \n" +
        "varying   vec4 vColor;                                  \n" +
        "void main()                                             \n" +
        "{                                                       \n" +
        "  gl_FragColor = vColor;                                \n" +
        "}                                                       \n";

    public HelloForm()
    {
        //this.Size = new Size( 640, 480 );
        this.Size = new Size( 512, 512 );
        this.Text = "Hello, World!";

        this.FormBorderStyle = FormBorderStyle.None;
        this.BackColor = Color.Black;
        this.TransparencyKey = Color.Black;

        vbo = new uint[2];
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);

        var timer = new Timer();
        timer.Tick += new EventHandler(this.OnTick_FormsTimer);
        timer.Interval = 1;
        timer.Start();
        
        EnableOpenGL();
        InitOpenGLFunc();
        InitShader();
    }
    
    protected override void OnPaint(PaintEventArgs e) {  
        base.OnPaint(e); 
        //DrawTriangle();
    }
    
    public void OnTick_FormsTimer(object sender, EventArgs e)
    {
        DrawTriangle();
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
        this.hGLRC = (IntPtr)wglCreateContext( (uint)this.hDC );
        wglMakeCurrent((uint)this.hDC, (uint)this.hGLRC);
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
        IntPtr glGetUniformLocationPtr      = wglGetProcAddress("glGetUniformLocation");
        IntPtr glEnableVertexAttribArrayPtr = wglGetProcAddress("glEnableVertexAttribArray");
        IntPtr glVertexAttribPointerPtr     = wglGetProcAddress("glVertexAttribPointer");
        IntPtr glUniform1fPtr               = wglGetProcAddress("glUniform1f");

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
        glGetUniformLocation       = Marshal.GetDelegateForFunctionPointer<glGetUniformLocationDelegate       >(glGetUniformLocationPtr     );
        glEnableVertexAttribArray  = Marshal.GetDelegateForFunctionPointer<glEnableVertexAttribArrayDelegate  >(glEnableVertexAttribArrayPtr);
        glVertexAttribPointer      = Marshal.GetDelegateForFunctionPointer<glVertexAttribPointerDelegate      >(glVertexAttribPointerPtr    );
        glUniform1f                = Marshal.GetDelegateForFunctionPointer<glUniform1fDelegate                >(glUniform1fPtr              );
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
        
        angle_loc = glGetUniformLocation(shaderProgram, "angle");

        glGenBuffers(2, vbo);

        List<float> vertices_list = new List<float>();
        List<float> colors_list   = new List<float>();

        for ( int i = 0; i <= MAX; i++ ) {
            float x = (float)(0.5 * Math.Cos(2 * Math.PI * i / MAX * A));
            float y = (float)(0.5 * Math.Sin(2 * Math.PI * i / MAX * B));
            float z = (float)(0.5 * Math.Sin(2 * Math.PI * i / MAX * A));
            float r = (float)(x + 0.5);
            float g = (float)(y + 0.5);
            float b = (float)(z + 0.5);
            vertices_list.Add( x );
            vertices_list.Add( y );
            vertices_list.Add( z );
            colors_list.Add( r );
            colors_list.Add( g );
            colors_list.Add( b );
        }
        vertices = vertices_list.ToArray();
        colors   = colors_list.ToArray();
        
        glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
        glBufferDataFloat(GL_ARRAY_BUFFER, vertices.Length * sizeof(float), vertices, GL_STATIC_DRAW);
    
        glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
        glBufferDataFloat(GL_ARRAY_BUFFER, colors.Length * sizeof(float), colors, GL_STATIC_DRAW);
    }
    
    float rad = 0.0F;
    void DrawTriangle() {
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
        glVertexAttribPointer(posAttrib, 3, GL_FLOAT, false, 0, IntPtr.Zero);
        
        glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
        glVertexAttribPointer(colAttrib, 3, GL_FLOAT, false, 0, IntPtr.Zero);
        
        glClear(GL_COLOR_BUFFER_BIT);

        rad += (float)(Math.PI * 1.0 / 180.0);
        glUniform1f(angle_loc, rad);
        
        glDrawArrays(GL_LINE_STRIP, 0, (uint)vertices.Length/3);
        glDrawArrays(GL_POINTS, 0, (uint)vertices.Length/3);

        SwapBuffers(this.hDC);
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
