using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;

using GLenum  = System.UInt32;
using GLfloat = System.Single;
 
class HelloForm : Form
{
    const int GL_TRIANGLES = 0x0004;
    const int GL_COLOR_BUFFER_BIT = 0x00004000;

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
    
    [DllImport("opengl32.dll")]
    static extern IntPtr wglCreateContext( IntPtr hdc );
    [DllImport("opengl32.dll")]
    static extern int wglMakeCurrent( IntPtr hdc, IntPtr hglrc );
    [DllImport("opengl32.dll")]
    static extern int wglDeleteContext( IntPtr hglrc );
    [DllImport("opengl32.dll")]
    static extern void glClearColor(float red, float green, float blue, float alpha);
    [DllImport("opengl32.dll")]
    static extern void glClear(uint mask);
    [DllImport("opengl32.dll")]
    static extern void glBegin(GLenum mode);
    [DllImport("opengl32.dll")]
    static extern void glColor3f(GLfloat red, GLfloat green, GLfloat blue);
    [DllImport("opengl32.dll")]
    static extern void glVertex2f(GLfloat x, GLfloat y);
    [DllImport("opengl32.dll")]
    static extern void glEnd();

    IntPtr hDC   = (IntPtr)0;
    IntPtr hGLRC = (IntPtr)0;

    public HelloForm()
    {
        this.Size = new Size( 640, 480 );
        this.Text = "Hello, World!";
    }
    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);

        PIXELFORMATDESCRIPTOR pfd = new PIXELFORMATDESCRIPTOR();
        pfd.dwFlags    = PFD_SUPPORT_OPENGL | PFD_DRAW_TO_WINDOW | PFD_DOUBLEBUFFER;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cColorBits = 32;
        pfd.cAlphaBits = 8;
        pfd.cDepthBits = 24;
        
        this.hDC = GetDC(this.Handle);
        int format = ChoosePixelFormat(hDC, ref pfd);
        
        SetPixelFormat(hDC, format, ref pfd);
        this.hGLRC = (IntPtr)wglCreateContext( this.hDC );
        wglMakeCurrent(this.hDC, this.hGLRC);
    }
    
    protected override void OnPaint(PaintEventArgs e) {  
        base.OnPaint(e); 

        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        glBegin(GL_TRIANGLES);
        glColor3f(1.0f, 0.0f, 0.0f); glVertex2f( 0.0f,  0.50f);
        glColor3f(0.0f, 1.0f, 0.0f); glVertex2f( 0.5f, -0.50f);
        glColor3f(0.0f, 0.0f, 1.0f); glVertex2f(-0.5f, -0.50f);
        glEnd();

        SwapBuffers(this.hDC);
    }
    
    [STAThread]
    static void Main()
    {
        HelloForm form = new HelloForm();
        Application.Run(form);
    }
}
