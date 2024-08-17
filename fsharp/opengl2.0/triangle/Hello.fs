open System
open System.Drawing
open System.Runtime.InteropServices
open System.Windows.Forms

[<Struct>]
type PIXELFORMATDESCRIPTOR =
    val mutable nSize: uint16
    val mutable nVersion: uint16
    val mutable dwFlags: uint32
    val mutable iPixelType: byte
    val mutable cColorBits: byte
    val mutable cRedBits: byte
    val mutable cRedShift: byte
    val mutable cGreenBits: byte
    val mutable cGreenShift: byte
    val mutable cBlueBits: byte
    val mutable cBlueShift: byte
    val mutable cAlphaBits: byte
    val mutable cAlphaShift: byte
    val mutable cAccumBits: byte
    val mutable cAccumRedBits: byte
    val mutable cAccumGreenBits: byte
    val mutable cAccumBlueBits: byte
    val mutable cAccumAlphaBits: byte
    val mutable cDepthBits: byte
    val mutable cStencilBits: byte
    val mutable cAuxBuffers: byte
    val mutable iLayerType: byte
    val mutable bReserved: byte
    val mutable dwLayerMask: uint32
    val mutable dwVisibleMask: uint32
    val mutable dwDamageMask: uint32

module OpenGL =
    [<DllImport("opengl32.dll")>]
    extern IntPtr wglGetProcAddress(string lpszProc)

    [<DllImport("opengl32.dll")>]
    extern void glClearColor(float32 red, float32 green, float32 blue, float32 alpha)

    [<DllImport("opengl32.dll")>]
    extern void glClear(uint32 mask)

    [<DllImport("opengl32.dll")>]
    extern void glDrawArrays(uint32 mode, int first, int count)

    [<DllImport("user32.dll")>]
    extern IntPtr GetDC(IntPtr hWnd)

    [<DllImport("user32.dll")>]
    extern int ReleaseDC(IntPtr hWnd, IntPtr hDC)

    [<DllImport("gdi32.dll")>]
    extern int ChoosePixelFormat(IntPtr hDC, PIXELFORMATDESCRIPTOR& ppfd)

    [<DllImport("gdi32.dll")>]
    extern bool SetPixelFormat(IntPtr hDC, int iPixelFormat, PIXELFORMATDESCRIPTOR& ppfd)

    [<DllImport("gdi32.dll")>]
    extern bool SwapBuffers(IntPtr hDC)

    [<DllImport("opengl32.dll")>]
    extern IntPtr wglCreateContext(IntPtr hDC)

    [<DllImport("opengl32.dll")>]
    extern bool wglMakeCurrent(IntPtr hDC, IntPtr hRC)

    [<DllImport("opengl32.dll")>]
    extern bool wglDeleteContext(IntPtr hRC)

    let GL_TRIANGLES = 0x0004u
    let GL_FLOAT = 0x1406u
    let GL_ARRAY_BUFFER = 0x8892u
    let GL_STATIC_DRAW = 0x88E4u
    let GL_FRAGMENT_SHADER = 0x8B30u
    let GL_VERTEX_SHADER = 0x8B31u
    let GL_COLOR_BUFFER_BIT = 0x00004000u

    let PFD_TYPE_RGBA = 0
    let PFD_DOUBLEBUFFER = 1
    let PFD_DRAW_TO_WINDOW = 4
    let PFD_SUPPORT_OPENGL = 32

    type glGenBuffersDelegate = delegate of int * uint32[] -> unit
    type glBindBufferDelegate = delegate of uint32 * uint32 -> unit
    type glBufferDataFloatDelegate = delegate of uint32 * int * float32[] * uint32 -> unit
    type glCreateShaderDelegate = delegate of uint32 -> uint32
    type glShaderSourceDelegate = delegate of uint32 * int * string[] * int[] -> unit
    type glCompileShaderDelegate = delegate of uint32 -> unit
    type glCreateProgramDelegate = delegate of unit -> uint32
    type glAttachShaderDelegate = delegate of uint32 * uint32 -> unit
    type glLinkProgramDelegate = delegate of uint32 -> unit
    type glUseProgramDelegate = delegate of uint32 -> unit
    type glGetAttribLocationDelegate = delegate of uint32 * string -> int
    type glEnableVertexAttribArrayDelegate = delegate of uint32 -> unit
    type glVertexAttribPointerDelegate = delegate of uint32 * int * uint32 * bool * int * IntPtr -> unit

    let getGLFunc<'T when 'T :> Delegate> (name: string) =
        let p = wglGetProcAddress(name)
        if p = IntPtr.Zero then
            failwithf "Failed to get address of %s" name
        Marshal.GetDelegateForFunctionPointer<'T>(p)

type HelloForm() as this =
    inherit Form()

    let mutable hDC = IntPtr.Zero
    let mutable hGLRC = IntPtr.Zero
    let mutable vbo = [|0u; 0u|]
    let mutable posAttrib = 0u
    let mutable colAttrib = 0u

    let mutable glGenBuffers = Unchecked.defaultof<OpenGL.glGenBuffersDelegate>
    let mutable glBindBuffer = Unchecked.defaultof<OpenGL.glBindBufferDelegate>
    let mutable glBufferDataFloat = Unchecked.defaultof<OpenGL.glBufferDataFloatDelegate>
    let mutable glCreateShader = Unchecked.defaultof<OpenGL.glCreateShaderDelegate>
    let mutable glShaderSource = Unchecked.defaultof<OpenGL.glShaderSourceDelegate>
    let mutable glCompileShader = Unchecked.defaultof<OpenGL.glCompileShaderDelegate>
    let mutable glCreateProgram = Unchecked.defaultof<OpenGL.glCreateProgramDelegate>
    let mutable glAttachShader = Unchecked.defaultof<OpenGL.glAttachShaderDelegate>
    let mutable glLinkProgram = Unchecked.defaultof<OpenGL.glLinkProgramDelegate>
    let mutable glUseProgram = Unchecked.defaultof<OpenGL.glUseProgramDelegate>
    let mutable glGetAttribLocation = Unchecked.defaultof<OpenGL.glGetAttribLocationDelegate>
    let mutable glEnableVertexAttribArray = Unchecked.defaultof<OpenGL.glEnableVertexAttribArrayDelegate>
    let mutable glVertexAttribPointer = Unchecked.defaultof<OpenGL.glVertexAttribPointerDelegate>

    let vertexSource = """
        attribute vec3 position;
        attribute vec3 color;
        varying vec4 vColor;
        void main() {
            vColor = vec4(color, 1.0);
            gl_Position = vec4(position, 1.0);
        }
    """

    let fragmentSource = """
        precision mediump float;
        varying vec4 vColor;
        void main() {
            gl_FragColor = vColor;
        }
    """

    do
        this.Size <- Size(640, 480)
        this.Text <- "Hello, World!"

    member private this.EnableOpenGL() =
        let mutable pfd = PIXELFORMATDESCRIPTOR()
        pfd.dwFlags <- uint32 (OpenGL.PFD_SUPPORT_OPENGL ||| OpenGL.PFD_DRAW_TO_WINDOW ||| OpenGL.PFD_DOUBLEBUFFER)
        pfd.iPixelType <- byte OpenGL.PFD_TYPE_RGBA
        pfd.cColorBits <- 32uy
        pfd.cAlphaBits <- 8uy
        pfd.cDepthBits <- 24uy
        
        hDC <- OpenGL.GetDC(this.Handle)
        let format = OpenGL.ChoosePixelFormat(hDC, &pfd)
        OpenGL.SetPixelFormat(hDC, format, &pfd) |> ignore

        hGLRC <- OpenGL.wglCreateContext(hDC)
        OpenGL.wglMakeCurrent(hDC, hGLRC) |> ignore

    member private this.InitOpenGLFunc() =
        glGenBuffers <- OpenGL.getGLFunc<OpenGL.glGenBuffersDelegate>("glGenBuffers")
        glBindBuffer <- OpenGL.getGLFunc<OpenGL.glBindBufferDelegate>("glBindBuffer")
        glBufferDataFloat <- OpenGL.getGLFunc<OpenGL.glBufferDataFloatDelegate>("glBufferData")
        glCreateShader <- OpenGL.getGLFunc<OpenGL.glCreateShaderDelegate>("glCreateShader")
        glShaderSource <- OpenGL.getGLFunc<OpenGL.glShaderSourceDelegate>("glShaderSource")
        glCompileShader <- OpenGL.getGLFunc<OpenGL.glCompileShaderDelegate>("glCompileShader")
        glCreateProgram <- OpenGL.getGLFunc<OpenGL.glCreateProgramDelegate>("glCreateProgram")
        glAttachShader <- OpenGL.getGLFunc<OpenGL.glAttachShaderDelegate>("glAttachShader")
        glLinkProgram <- OpenGL.getGLFunc<OpenGL.glLinkProgramDelegate>("glLinkProgram")
        glUseProgram <- OpenGL.getGLFunc<OpenGL.glUseProgramDelegate>("glUseProgram")
        glGetAttribLocation <- OpenGL.getGLFunc<OpenGL.glGetAttribLocationDelegate>("glGetAttribLocation")
        glEnableVertexAttribArray <- OpenGL.getGLFunc<OpenGL.glEnableVertexAttribArrayDelegate>("glEnableVertexAttribArray")
        glVertexAttribPointer <- OpenGL.getGLFunc<OpenGL.glVertexAttribPointerDelegate>("glVertexAttribPointer")

    member private this.InitShader() =
        let vertexShader = glCreateShader.Invoke(OpenGL.GL_VERTEX_SHADER)
        glShaderSource.Invoke(vertexShader, 1, [|vertexSource|], null)
        glCompileShader.Invoke(vertexShader)

        let fragmentShader = glCreateShader.Invoke(OpenGL.GL_FRAGMENT_SHADER)
        glShaderSource.Invoke(fragmentShader, 1, [|fragmentSource|], null)
        glCompileShader.Invoke(fragmentShader)

        let program = glCreateProgram.Invoke()
        glAttachShader.Invoke(program, vertexShader)
        glAttachShader.Invoke(program, fragmentShader)
        glLinkProgram.Invoke(program)
        glUseProgram.Invoke(program)

        posAttrib <- uint32 (glGetAttribLocation.Invoke(program, "position"))
        glEnableVertexAttribArray.Invoke(posAttrib)
        colAttrib <- uint32 (glGetAttribLocation.Invoke(program, "color"))
        glEnableVertexAttribArray.Invoke(colAttrib)

        glGenBuffers.Invoke(2, vbo)

        let vertices : float32[] = [| 
            -0.5f; -0.5f; 0.0f;
             0.5f; -0.5f; 0.0f;
             0.0f;  0.5f; 0.0f 
        |]

        let colors : float32[] = [| 
            1.0f; 0.0f; 0.0f;
            0.0f; 1.0f; 0.0f;
            0.0f; 0.0f; 1.0f 
        |]
        
        glBindBuffer.Invoke(OpenGL.GL_ARRAY_BUFFER, vbo.[0])
        glBufferDataFloat.Invoke(OpenGL.GL_ARRAY_BUFFER, vertices.Length * sizeof<float32>, vertices, OpenGL.GL_STATIC_DRAW)
        glBindBuffer.Invoke(OpenGL.GL_ARRAY_BUFFER, vbo.[1])
        glBufferDataFloat.Invoke(OpenGL.GL_ARRAY_BUFFER, colors.Length * sizeof<float32>, colors, OpenGL.GL_STATIC_DRAW)

    member private this.DrawTriangle() =
        OpenGL.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
        OpenGL.glClear(OpenGL.GL_COLOR_BUFFER_BIT)

        glBindBuffer.Invoke(OpenGL.GL_ARRAY_BUFFER, vbo.[0])
        glVertexAttribPointer.Invoke(posAttrib, 3, OpenGL.GL_FLOAT, false, 0, IntPtr.Zero)
        glBindBuffer.Invoke(OpenGL.GL_ARRAY_BUFFER, vbo.[1])
        glVertexAttribPointer.Invoke(colAttrib, 3, OpenGL.GL_FLOAT, false, 0, IntPtr.Zero)

        OpenGL.glDrawArrays(OpenGL.GL_TRIANGLES, 0, 3)

        OpenGL.SwapBuffers(hDC) |> ignore

    override this.OnHandleCreated e =
        base.OnHandleCreated e
        this.EnableOpenGL()
        this.InitOpenGLFunc()
        this.InitShader()

    override this.OnPaint e =
        base.OnPaint e
        this.DrawTriangle()

    override this.Dispose(disposing) =
        if disposing then
            if hGLRC <> IntPtr.Zero then
                OpenGL.wglMakeCurrent(IntPtr.Zero, IntPtr.Zero) |> ignore
                OpenGL.wglDeleteContext(hGLRC) |> ignore
                hGLRC <- IntPtr.Zero
            if hDC <> IntPtr.Zero then
                OpenGL.ReleaseDC(this.Handle, hDC) |> ignore
                hDC <- IntPtr.Zero
        base.Dispose(disposing)

[<EntryPoint>]
let main argv =
    Application.SetCompatibleTextRenderingDefault(false)
    Application.EnableVisualStyles()
    use form = new HelloForm()
    Application.Run(form)
    0
