$source = @"
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;

using GLenum = System.UInt32;
using GLint = System.Int32;
using GLuint = System.UInt32;
using GLsizei = System.Int32;
using GLfloat = System.Single;

public class HelloForm : Form
{
    const int GL_TRIANGLES = 0x0004;
    const int GL_FLOAT = 0x1406;
    const int GL_VERTEX_ARRAY = 0x8074;
    const int GL_COLOR_ARRAY = 0x8076;
    const int GL_COLOR_BUFFER_BIT = 0x00004000;
    const int GL_ARRAY_BUFFER = 0x8892;
    const int GL_ELEMENT_ARRAY_BUFFER = 0x8893;
    const int GL_STATIC_DRAW = 0x88E4;
    const int GL_FRAGMENT_SHADER = 0x8B30;
    const int GL_VERTEX_SHADER = 0x8B31;
    const int GL_DEPTH_TEST = 0x0B71;
    const int GL_DEPTH_BUFFER_BIT = 0x00000100;

    const int PFD_TYPE_RGBA = 0;
    const int PFD_DOUBLEBUFFER = 1;
    const int PFD_DRAW_TO_WINDOW = 4;
    const int PFD_SUPPORT_OPENGL = 32;

    [StructLayout(LayoutKind.Sequential)]
    public struct PIXELFORMATDESCRIPTOR
    {
        public ushort nSize;
        public ushort nVersion;
        public uint dwFlags;
        public byte iPixelType;
        public byte cColorBits;
        public byte cRedBits;
        public byte cRedShift;
        public byte cGreenBits;
        public byte cGreenShift;
        public byte cBlueBits;
        public byte cBlueShift;
        public byte cAlphaBits;
        public byte cAlphaShift;
        public byte cAccumBits;
        public byte cAccumRedBits;
        public byte cAccumGreenBits;
        public byte cAccumBlueBits;
        public byte cAccumAlphaBits;
        public byte cDepthBits;
        public byte cStencilBits;
        public byte cAuxBuffers;
        public byte iLayerType;
        public byte bReserved;
        public uint dwLayerMask;
        public uint dwVisibleMask;
        public uint dwDamageMask;
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
    static extern IntPtr wglCreateContext(IntPtr hdc);
    [DllImport("opengl32.dll")]
    static extern int wglMakeCurrent(IntPtr hdc, IntPtr hglrc);
    [DllImport("opengl32.dll")]
    static extern int wglDeleteContext(IntPtr hglrc);
    [DllImport("opengl32.dll")]
    static extern void glClearColor(float red, float green, float blue, float alpha);
    [DllImport("opengl32.dll")]
    static extern void glClear(uint mask);
    [DllImport("opengl32.dll")]
    static extern IntPtr wglGetProcAddress(string functionName);
    [DllImport("opengl32.dll")]
    static extern void glEnable(uint cap);
    [DllImport("opengl32.dll")]
    static extern void glDrawElements(GLenum mode, GLsizei count, GLenum type, IntPtr indices);

    delegate void glGenBuffersDelegate(int n, uint[] buffers);
    delegate void glBindBufferDelegate(uint target, uint buffer);
    delegate void glBufferDataDelegate(uint target, int size, IntPtr data, uint usage);
    delegate void glBufferDataFloatDelegate(uint target, int size, float[] data, uint usage);
    delegate uint glCreateShaderDelegate(uint type);
    delegate void glShaderSourceDelegate(uint shader, int count, string[] @string, int[] length);
    delegate void glCompileShaderDelegate(uint shader);
    delegate uint glCreateProgramDelegate();
    delegate void glAttachShaderDelegate(uint program, uint shader);
    delegate void glLinkProgramDelegate(uint program);
    delegate void glUseProgramDelegate(uint program);
    delegate GLint glGetAttribLocationDelegate(uint program, string name);
    delegate void glEnableVertexAttribArrayDelegate(uint index);
    delegate void glVertexAttribPointerDelegate(uint index, int size, uint type, bool normalized, int stride, IntPtr pointer);
    delegate GLint glGetUniformLocationDelegate(GLuint program, string name);
    delegate void glUniformMatrix4fvDelegate(GLint location, GLsizei count, bool transpose, float[] value);

    glGenBuffersDelegate glGenBuffers;
    glBindBufferDelegate glBindBuffer;
    glBufferDataDelegate glBufferData;
    glBufferDataFloatDelegate glBufferDataFloat;
    glCreateShaderDelegate glCreateShader;
    glShaderSourceDelegate glShaderSource;
    glCompileShaderDelegate glCompileShader;
    glCreateProgramDelegate glCreateProgram;
    glAttachShaderDelegate glAttachShader;
    glLinkProgramDelegate glLinkProgram;
    glUseProgramDelegate glUseProgram;
    glGetAttribLocationDelegate glGetAttribLocation;
    glEnableVertexAttribArrayDelegate glEnableVertexAttribArray;
    glVertexAttribPointerDelegate glVertexAttribPointer;
    glGetUniformLocationDelegate glGetUniformLocation;
    glUniformMatrix4fvDelegate glUniformMatrix4fv;

    IntPtr hDC = (IntPtr)0;
    IntPtr hGLRC = (IntPtr)0;
    GLuint[] vbo;
    GLuint ibo;
    GLint posAttrib;
    GLint colAttrib;
    GLint uPMatrix;
    GLint uMVMatrix;
    float rad = 0.0f;
    float[] projectionMatrix = new float[16];
    float[] modelViewMatrix = new float[16];

    const string vertexSource =
        "attribute vec3 position;\n" +
        "attribute vec4 color;\n" +
        "uniform mat4 uPMatrix;\n" +
        "uniform mat4 uMVMatrix;\n" +
        "varying vec4 vColor;\n" +
        "void main() {\n" +
        "  vColor = color;\n" +
        "  gl_Position = uPMatrix * uMVMatrix * vec4(position, 1.0);\n" +
        "}\n";

    const string fragmentSource =
        "precision mediump float;\n" +
        "varying vec4 vColor;\n" +
        "void main() {\n" +
        "  gl_FragColor = vColor;\n" +
        "}\n";

    public HelloForm()
    {
        this.Size = new Size(640, 480);
        this.Text = "Hello, World!";
        vbo = new uint[2];

        this.FormBorderStyle = FormBorderStyle.None;
        this.BackColor = Color.Black;
        this.TransparencyKey = Color.Black;

        var timer = new Timer();
        timer.Tick += new EventHandler(this.OnTick_FormsTimer);
        timer.Interval = 1;
        timer.Start();
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        EnableOpenGL();
        InitOpenGLFunc();
        InitShader();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
    }

    public void OnTick_FormsTimer(object sender, EventArgs e)
    {
        DrawCube();
    }
    
    protected override void OnClosed(EventArgs e)
    {
        base.OnClosed(e);
        DisableOpenGL();
    }

    void EnableOpenGL()
    {
        PIXELFORMATDESCRIPTOR pfd = new PIXELFORMATDESCRIPTOR();
        pfd.dwFlags = PFD_SUPPORT_OPENGL | PFD_DRAW_TO_WINDOW | PFD_DOUBLEBUFFER;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cColorBits = 32;
        pfd.cAlphaBits = 8;
        pfd.cDepthBits = 24;

        this.hDC = GetDC(this.Handle);
        int format = ChoosePixelFormat(hDC, ref pfd);
        SetPixelFormat(hDC, format, ref pfd);
        this.hGLRC = wglCreateContext(this.hDC);
        wglMakeCurrent(this.hDC, this.hGLRC);
    }

    void InitOpenGLFunc()
    {
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
        IntPtr glGetUniformLocationPtr      = wglGetProcAddress("glGetUniformLocation");
        IntPtr glUniformMatrix4fvPtr        = wglGetProcAddress("glUniformMatrix4fv");

        glGenBuffers               = Marshal.GetDelegateForFunctionPointer<glGenBuffersDelegate               >(glGenBuffersPtr             );
        glBindBuffer               = Marshal.GetDelegateForFunctionPointer<glBindBufferDelegate               >(glBindBufferPtr             );
        glBufferData               = Marshal.GetDelegateForFunctionPointer<glBufferDataDelegate               >(glBufferDataPtr             );
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
        glGetUniformLocation       = Marshal.GetDelegateForFunctionPointer<glGetUniformLocationDelegate       >(glGetUniformLocationPtr     );
        glUniformMatrix4fv         = Marshal.GetDelegateForFunctionPointer<glUniformMatrix4fvDelegate         >(glUniformMatrix4fvPtr       );
    }

    void InitShader()
    {
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
        glEnableVertexAttribArray((GLuint)posAttrib);

        colAttrib = glGetAttribLocation(shaderProgram, "color");
        glEnableVertexAttribArray((GLuint)colAttrib);

        uPMatrix = glGetUniformLocation(shaderProgram, "uPMatrix");
        uMVMatrix = glGetUniformLocation(shaderProgram, "uMVMatrix");

        glGenBuffers(2, vbo);
        uint[] iboArray = new uint[1];
        glGenBuffers(1, iboArray);
        ibo = iboArray[0];

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
        float[] vertices = {
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

        float[] colors = {
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

        uint[] indices = {
             0,  1,  2,    0,  2,  3,  // Front face
             4,  5,  6,    4,  6,  7,  // Back face
             8,  9, 10,    8, 10, 11,  // Top face
            12, 13, 14,   12, 14, 15,  // Bottom face
            16, 17, 18,   16, 18, 19,  // Right face
            20, 21, 22,   20, 22, 23   // Left face
        };

        glEnable(GL_DEPTH_TEST);

        glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
        glBufferDataFloat(GL_ARRAY_BUFFER, vertices.Length * sizeof(float), vertices, GL_STATIC_DRAW);

        glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
        glBufferDataFloat(GL_ARRAY_BUFFER, colors.Length * sizeof(float), colors, GL_STATIC_DRAW);

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
        GCHandle handle = GCHandle.Alloc(indices, GCHandleType.Pinned);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.Length * sizeof(uint), handle.AddrOfPinnedObject(), GL_STATIC_DRAW);
        handle.Free();
    }

    void DrawCube()
    {
        rad += 0.02f;

        SetPerspectiveMatrix(45.0f, (float)Width / (float)Height, 1.0f, 100.0f, projectionMatrix);
        
        SetIdentityMatrix(modelViewMatrix);
        RotateMatrix(modelViewMatrix, rad, 1.0f, 1.0f, 1.0f);
        TranslateMatrix(modelViewMatrix, 0.0f, 0.0f, -3.0f);

        glUniformMatrix4fv(uPMatrix, 1, false, projectionMatrix);
        glUniformMatrix4fv(uMVMatrix, 1, false, modelViewMatrix);

        glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
        glVertexAttribPointer((GLuint)posAttrib, 3, GL_FLOAT, false, 0, IntPtr.Zero);

        glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
        glVertexAttribPointer((GLuint)colAttrib, 4, GL_FLOAT, false, 0, IntPtr.Zero);

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glDrawElements(GL_TRIANGLES, 36, 0x1405, IntPtr.Zero);

        SwapBuffers(this.hDC);
    }

    void SetPerspectiveMatrix(float fovy, float aspect, float near, float far, float[] matrix)
    {
        float f = (float)(1.0 / Math.Tan(fovy * Math.PI / 360.0));
        matrix[0] = f / aspect;
        matrix[1] = 0;
        matrix[2] = 0;
        matrix[3] = 0;
        matrix[4] = 0;
        matrix[5] = f;
        matrix[6] = 0;
        matrix[7] = 0;
        matrix[8] = 0;
        matrix[9] = 0;
        matrix[10] = (far + near) / (near - far);
        matrix[11] = -1;
        matrix[12] = 0;
        matrix[13] = 0;
        matrix[14] = (2 * far * near) / (near - far);
        matrix[15] = 0;
    }

    void SetIdentityMatrix(float[] matrix)
    {
        Array.Clear(matrix, 0, 16);
        matrix[0] = matrix[5] = matrix[10] = matrix[15] = 1.0f;
    }

    void TranslateMatrix(float[] matrix, float x, float y, float z)
    {
        matrix[12] = x;
        matrix[13] = y;
        matrix[14] = z;
    }

    void RotateMatrix(float[] matrix, float angle, float x, float y, float z)
    {
        // Normalize the input vector
        float len = (float)Math.Sqrt(x * x + y * y + z * z);
        if (len != 0)
        {
            x /= len;
            y /= len;
            z /= len;
        }

        float c = (float)Math.Cos(angle);
        float s = (float)Math.Sin(angle);
        float nc = 1 - c;

        float[] rot = new float[16];
        // Set up the rotation matrix elements correctly
        rot[0] = x * x * nc + c;
        rot[1] = x * y * nc + z * s;
        rot[2] = x * z * nc - y * s;
        rot[3] = 0.0f;

        rot[4] = x * y * nc - z * s;
        rot[5] = y * y * nc + c;
        rot[6] = y * z * nc + x * s;
        rot[7] = 0.0f;

        rot[8] = x * z * nc + y * s;
        rot[9] = y * z * nc - x * s;
        rot[10] = z * z * nc + c;
        rot[11] = 0.0f;

        rot[12] = 0.0f;
        rot[13] = 0.0f;
        rot[14] = 0.0f;
        rot[15] = 1.0f;

        // Matrix multiplication
        float[] temp = new float[16];
        Array.Copy(matrix, temp, 16);

        for (int i = 0; i < 4; i++)
        {
            for (int j = 0; j < 4; j++)
            {
                matrix[i * 4 + j] = 0;
                for (int k = 0; k < 4; k++)
                {
                    matrix[i * 4 + j] += temp[i * 4 + k] * rot[k * 4 + j];
                }
            }
        }
    }

    void DisableOpenGL()
    {
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
