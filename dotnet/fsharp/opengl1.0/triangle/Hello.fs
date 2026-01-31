open System
open System.Drawing
open System.Runtime.InteropServices
open System.Windows.Forms

type GLenum     = int
type GLfloat    = float32

let GL_TRIANGLES = 0x0004
let GL_COLOR_BUFFER_BIT = 0x00004000

let PFD_DOUBLEBUFFER   =  1
let PFD_DRAW_TO_WINDOW =  4
let PFD_SUPPORT_OPENGL = 32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type PIXELFORMATDESCRIPTOR =
    val mutable nSize           : int16
    val mutable nVersion        : int16
    val mutable dwFlags         : int
    val mutable iPixelType      : byte
    val mutable cColorBits      : byte
    val mutable cRedBits        : byte
    val mutable cRedShift       : byte
    val mutable cGreenBits      : byte
    val mutable cGreenShift     : byte
    val mutable cBlueBits       : byte
    val mutable cBlueShift      : byte
    val mutable cAlphaBits      : byte
    val mutable cAlphaShift     : byte
    val mutable cAccumBits      : byte
    val mutable cAccumRedBits   : byte
    val mutable cAccumGreenBits : byte
    val mutable cAccumBlueBits  : byte
    val mutable cAccumAlphaBits : byte
    val mutable cDepthBits      : byte
    val mutable cStencilBits    : byte
    val mutable cAuxBuffers     : byte
    val mutable iLayerType      : byte
    val mutable bReserved       : byte
    val mutable dwLayerMask     : int
    val mutable dwVisibleMask   : int
    val mutable dwDamageMask    : int

[<DllImport("user32.dll")>]
extern nativeint GetDC(nativeint hWnd)
[<DllImport("user32.dll")>]
extern int ReleaseDC(nativeint hWnd, nativeint hDC)
[<DllImport("gdi32.dll")>]
extern int ChoosePixelFormat(nativeint hDC, PIXELFORMATDESCRIPTOR& ppfd)
[<DllImport("gdi32.dll", SetLastError = true)>]
extern bool SetPixelFormat(nativeint hDC, int format, PIXELFORMATDESCRIPTOR& ppfd)
[<DllImport("gdi32.dll")>]
extern bool SwapBuffers(nativeint hDC)
[<DllImport("opengl32.dll")>]
extern nativeint wglCreateContext(nativeint hDC)
[<DllImport("opengl32.dll")>]
extern bool wglMakeCurrent(nativeint hDC, nativeint hGLRC)
[<DllImport("opengl32.dll")>]
extern bool wglDeleteContext(nativeint hGLRC)

[<DllImport("opengl32.dll")>]
extern void glClearColor(float32 red, float32 green, float32 blue, float32 alpha)
[<DllImport("opengl32.dll")>]
extern void glClear(int mask)
[<DllImport("opengl32.dll")>]
extern void glBegin(GLenum mode)
[<DllImport("opengl32.dll")>]
extern void glColor3f(GLfloat red, GLfloat green, GLfloat blue)
[<DllImport("opengl32.dll")>]
extern void glVertex2f(GLfloat x, GLfloat y)
[<DllImport("opengl32.dll")>]
extern void glEnd()

type HelloForm() =
    inherit Form()

    let mutable hDC   = 0n
    let mutable hGLRC = 0n

    override x.OnHandleCreated e =
        base.OnHandleCreated e
        let mutable pfd =
            PIXELFORMATDESCRIPTOR(
                nSize        = (Marshal.SizeOf<PIXELFORMATDESCRIPTOR>() |> int16),
                nVersion     = 1s,
                dwFlags      = (PFD_DOUBLEBUFFER ||| PFD_DRAW_TO_WINDOW ||| PFD_SUPPORT_OPENGL),
                cColorBits   = 32uy,
                cDepthBits   = 24uy,
                cStencilBits = 8uy)
        hDC <- GetDC x.Handle
        let format = ChoosePixelFormat(hDC, &pfd)
        ignore <| SetPixelFormat(hDC, format, &pfd)
        hGLRC <- wglCreateContext hDC
        ignore <| wglMakeCurrent(hDC, hGLRC)

    override x.Dispose disposing =
        ignore <| wglMakeCurrent(0n, 0n)
        ignore <| wglDeleteContext hGLRC
        ignore <| ReleaseDC(x.Handle, hDC)
        base.Dispose disposing

    override x.OnPaint e =
        base.OnPaint e
        ignore <| SwapBuffers hDC

[<EntryPoint; STAThread>] do
let form = new HelloForm(Text = "Hello, World!", ClientSize = Size(640, 480))
form.Paint.Add <| fun _ ->
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
    glClear(GL_COLOR_BUFFER_BIT)
    
    glBegin(GL_TRIANGLES)
    glColor3f(1.0f, 0.0f, 0.0f); glVertex2f( 0.0f,  0.50f)
    glColor3f(0.0f, 1.0f, 0.0f); glVertex2f( 0.5f, -0.50f)
    glColor3f(0.0f, 0.0f, 1.0f); glVertex2f(-0.5f, -0.50f)
    glEnd()

do Application.Run(form)
