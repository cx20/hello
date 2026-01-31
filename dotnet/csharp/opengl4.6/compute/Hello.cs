/*
 * OpenGL 4.6 Compute Shader Harmonograph (C# / WinForms / No external libs)
 *
 * - Creates a WinForms window
 * - Creates an OpenGL 4.6 core profile context via WGL_ARB_create_context
 * - Uses a compute shader to fill SSBOs (positions + colors)
 * - Uses a vertex/fragment shader to render GL_LINE_STRIP from SSBO data
 *
 * Build: csc Harmonograph.cs /r:System.Windows.Forms.dll /r:System.Drawing.dll
 */

using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;

using GLenum  = System.UInt32;
using GLint   = System.Int32;
using GLuint  = System.UInt32;
using GLsizei = System.Int32;
using GLfloat = System.Single;

class HelloForm : Form
{
    // OpenGL constants
    const uint GL_LINE_STRIP              = 0x0003;
    const uint GL_FLOAT                   = 0x1406;
    const uint GL_COLOR_BUFFER_BIT        = 0x00004000;
    const uint GL_DEPTH_BUFFER_BIT        = 0x00000100;
    const uint GL_SHADER_STORAGE_BUFFER   = 0x90D2;
    const uint GL_DYNAMIC_DRAW            = 0x88E8;
    const uint GL_FRAGMENT_SHADER         = 0x8B30;
    const uint GL_VERTEX_SHADER           = 0x8B31;
    const uint GL_COMPUTE_SHADER          = 0x91B9;
    const uint GL_COMPILE_STATUS          = 0x8B81;
    const uint GL_LINK_STATUS             = 0x8B82;
    const uint GL_INFO_LOG_LENGTH         = 0x8B84;
    const uint GL_SHADER_STORAGE_BARRIER_BIT = 0x00002000;
    const uint GL_TRUE                    = 1;

    // WGL constants
    const int WGL_CONTEXT_MAJOR_VERSION_ARB   = 0x2091;
    const int WGL_CONTEXT_MINOR_VERSION_ARB   = 0x2092;
    const int WGL_CONTEXT_FLAGS_ARB           = 0x2094;
    const int WGL_CONTEXT_PROFILE_MASK_ARB    = 0x9126;
    const int WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;

    const int PFD_TYPE_RGBA      =  0;
    const int PFD_DOUBLEBUFFER   =  1;
    const int PFD_DRAW_TO_WINDOW =  4;
    const int PFD_SUPPORT_OPENGL = 32;

    const int WIDTH  = 640;
    const int HEIGHT = 480;
    const int VERTEX_COUNT = 500000;

    [StructLayout(LayoutKind.Sequential)]
    public struct PIXELFORMATDESCRIPTOR
    {
        public ushort nSize;
        public ushort nVersion;
        public uint   dwFlags;
        public byte   iPixelType;
        public byte   cColorBits;
        public byte   cRedBits;
        public byte   cRedShift;
        public byte   cGreenBits;
        public byte   cGreenShift;
        public byte   cBlueBits;
        public byte   cBlueShift;
        public byte   cAlphaBits;
        public byte   cAlphaShift;
        public byte   cAccumBits;
        public byte   cAccumRedBits;
        public byte   cAccumGreenBits;
        public byte   cAccumBlueBits;
        public byte   cAccumAlphaBits;
        public byte   cDepthBits;
        public byte   cStencilBits;
        public byte   cAuxBuffers;
        public byte   iLayerType;
        public byte   bReserved;
        public uint   dwLayerMask;
        public uint   dwVisibleMask;
        public uint   dwDamageMask;
    }

    // Win32 imports
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

    // OpenGL 1.1 imports
    [DllImport("opengl32")]
    static extern IntPtr wglCreateContext(IntPtr hdc);
    [DllImport("opengl32")]
    static extern int wglMakeCurrent(IntPtr hdc, IntPtr hglrc);
    [DllImport("opengl32")]
    static extern int wglDeleteContext(IntPtr hglrc);
    [DllImport("opengl32")]
    static extern void glClearColor(float red, float green, float blue, float alpha);
    [DllImport("opengl32")]
    static extern void glClear(uint mask);
    [DllImport("opengl32")]
    static extern void glViewport(int x, int y, int width, int height);
    [DllImport("opengl32")]
    static extern IntPtr wglGetProcAddress(string functionName);
    [DllImport("opengl32")]
    static extern IntPtr glGetString(uint name);

    // Delegate types for OpenGL extension functions
    delegate void glGenBuffersDelegate(int n, uint[] buffers);
    delegate void glBindBufferDelegate(uint target, uint buffer);
    delegate void glBufferDataDelegate(uint target, IntPtr size, IntPtr data, uint usage);
    delegate void glBindBufferBaseDelegate(uint target, uint index, uint buffer);
    delegate uint glCreateShaderDelegate(uint type);
    delegate void glShaderSourceDelegate(uint shader, int count, string[] source, int[] length);
    delegate void glCompileShaderDelegate(uint shader);
    delegate void glGetShaderivDelegate(uint shader, uint pname, out int param);
    delegate void glGetShaderInfoLogDelegate(uint shader, int bufSize, out int length, System.Text.StringBuilder infoLog);
    delegate void glDeleteShaderDelegate(uint shader);
    delegate uint glCreateProgramDelegate();
    delegate void glAttachShaderDelegate(uint program, uint shader);
    delegate void glLinkProgramDelegate(uint program);
    delegate void glUseProgramDelegate(uint program);
    delegate void glGetProgramivDelegate(uint program, uint pname, out int param);
    delegate void glGetProgramInfoLogDelegate(uint program, int bufSize, out int length, System.Text.StringBuilder infoLog);
    delegate int  glGetUniformLocationDelegate(uint program, string name);
    delegate void glUniform1fDelegate(int location, float v0);
    delegate void glUniform2fDelegate(int location, float v0, float v1);
    delegate void glUniform1uiDelegate(int location, uint v0);
    delegate void glGenVertexArraysDelegate(int n, uint[] arrays);
    delegate void glBindVertexArrayDelegate(uint array);
    delegate void glDispatchComputeDelegate(uint num_groups_x, uint num_groups_y, uint num_groups_z);
    delegate void glMemoryBarrierDelegate(uint barriers);
    delegate void glDrawArraysDelegate(uint mode, int first, int count);
    delegate IntPtr wglCreateContextAttribsARBDelegate(IntPtr hDC, IntPtr hShareContext, int[] attribList);

    // Function pointers
    glGenBuffersDelegate             glGenBuffers;
    glBindBufferDelegate             glBindBuffer;
    glBufferDataDelegate             glBufferData;
    glBindBufferBaseDelegate         glBindBufferBase;
    glCreateShaderDelegate           glCreateShader;
    glShaderSourceDelegate           glShaderSource;
    glCompileShaderDelegate          glCompileShader;
    glGetShaderivDelegate            glGetShaderiv;
    glGetShaderInfoLogDelegate       glGetShaderInfoLog;
    glDeleteShaderDelegate           glDeleteShader;
    glCreateProgramDelegate          glCreateProgram;
    glAttachShaderDelegate           glAttachShader;
    glLinkProgramDelegate            glLinkProgram;
    glUseProgramDelegate             glUseProgram;
    glGetProgramivDelegate           glGetProgramiv;
    glGetProgramInfoLogDelegate      glGetProgramInfoLog;
    glGetUniformLocationDelegate     glGetUniformLocation;
    glUniform1fDelegate              glUniform1f;
    glUniform2fDelegate              glUniform2f;
    glUniform1uiDelegate             glUniform1ui;
    glGenVertexArraysDelegate        glGenVertexArrays;
    glBindVertexArrayDelegate        glBindVertexArray;
    glDispatchComputeDelegate        glDispatchCompute;
    glMemoryBarrierDelegate          glMemoryBarrier;
    glDrawArraysDelegate             glDrawArrays;
    wglCreateContextAttribsARBDelegate wglCreateContextAttribsARB;

    IntPtr hDC   = IntPtr.Zero;
    IntPtr hGLRC = IntPtr.Zero;

    uint vao;
    uint ssboPos, ssboCol;
    uint drawProgram, computeProgram;

    // Harmonograph parameters
    float A1 = 50.0f, f1 = 2.0f, p1 = 1.0f/16.0f, d1 = 0.02f;
    float A2 = 50.0f, f2 = 2.0f, p2 = 3.0f/2.0f,  d2 = 0.0315f;
    float A3 = 50.0f, f3 = 2.0f, p3 = 13.0f/15.0f, d3 = 0.02f;
    float A4 = 50.0f, f4 = 2.0f, p4 = 1.0f,       d4 = 0.02f;

    const float PI2 = 6.283185307179586f;
    Random rand = new Random();
    Timer timer;
    DateTime startTime;
    int frameCount = 0;
    DateTime lastFpsTime;

    // Shader sources
    const string vertexSource = @"
#version 460 core

layout(std430, binding=7) buffer Positions {
    vec4 pos[];
};

layout(std430, binding=8) buffer Colors {
    vec4 col[];
};

uniform vec2 resolution;
out vec4 vColor;

mat4 perspective(float fov, float aspect, float near, float far)
{
    float v = 1.0 / tan(radians(fov/2.0));
    float u = v / aspect;
    float w = near - far;
    return mat4(
        u, 0, 0, 0,
        0, v, 0, 0,
        0, 0, (near+far)/w, -1,
        0, 0, (near*far*2.0)/w, 0
    );
}

mat4 lookAt(vec3 eye, vec3 center, vec3 up)
{
    vec3 w = normalize(eye - center);
    vec3 u = normalize(cross(up, w));
    vec3 v = cross(w, u);
    return mat4(
        u.x, v.x, w.x, 0,
        u.y, v.y, w.y, 0,
        u.z, v.z, w.z, 0,
        -dot(u, eye), -dot(v, eye), -dot(w, eye), 1
    );
}

void main(void)
{
    vec4 p = pos[gl_VertexID];

    mat4 pMat = perspective(45.0, resolution.x / resolution.y, 0.1, 200.0);
    vec3 camera = vec3(0, 5, 10);
    vec3 center = vec3(0, 0, 0);
    mat4 vMat = lookAt(camera, center, vec3(0,1,0));

    gl_Position = pMat * vMat * p;
    vColor = col[gl_VertexID];
}
";

    const string fragmentSource = @"
#version 460 core
in vec4 vColor;
layout(location = 0) out vec4 outColor;
void main()
{
    outColor = vColor;
}
";

    const string computeSource = @"
#version 460 core

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding=7) buffer Positions {
    vec4 pos[];
};

layout(std430, binding=8) buffer Colors {
    vec4 col[];
};

uniform uint max_num;

uniform float A1; uniform float f1; uniform float p1; uniform float d1;
uniform float A2; uniform float f2; uniform float p2; uniform float d2;
uniform float A3; uniform float f3; uniform float p3; uniform float d3;
uniform float A4; uniform float f4; uniform float p4; uniform float d4;

vec3 hsv2rgb(float h, float s, float v)
{
    float c = v * s;
    float hp = h / 60.0;
    float x = c * (1.0 - abs(mod(hp, 2.0) - 1.0));
    vec3 rgb;

    if      (hp < 1.0) rgb = vec3(c, x, 0.0);
    else if (hp < 2.0) rgb = vec3(x, c, 0.0);
    else if (hp < 3.0) rgb = vec3(0.0, c, x);
    else if (hp < 4.0) rgb = vec3(0.0, x, c);
    else if (hp < 5.0) rgb = vec3(x, 0.0, c);
    else               rgb = vec3(c, 0.0, x);

    float m = v - c;
    return rgb + vec3(m);
}

void main()
{
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= max_num) return;

    float t = float(idx) * 0.001;
    float PI = 3.14159265;

    float x = A1 * sin(f1 * t + PI * p1) * exp(-d1 * t) +
              A2 * sin(f2 * t + PI * p2) * exp(-d2 * t);

    float y = A3 * sin(f3 * t + PI * p3) * exp(-d3 * t) +
              A4 * sin(f4 * t + PI * p4) * exp(-d4 * t);

    float z = A1 * cos(f1 * t + PI * p1) * exp(-d1 * t) +
              A2 * cos(f2 * t + PI * p2) * exp(-d2 * t);

    pos[idx] = vec4(x, y, z, 1.0);

    float hue = mod((t / 20.0) * 360.0, 360.0);
    vec3 rgb = hsv2rgb(hue, 1.0, 1.0);
    col[idx] = vec4(rgb, 1.0);
}
";

    public HelloForm()
    {
        this.ClientSize = new Size(WIDTH, HEIGHT);
        this.Text = "OpenGL 4.6 Compute Harmonograph (C#)";
        this.FormBorderStyle = FormBorderStyle.FixedSingle;
        this.MaximizeBox = false;
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);

        EnableOpenGL();
        InitOpenGLFunc();
        InitResources();

        // Setup timer for animation
        startTime = DateTime.Now;
        lastFpsTime = startTime;

        timer = new Timer();
        timer.Interval = 1; // ~1ms
        timer.Tick += OnTimer;
        timer.Start();
    }

    void OnTimer(object sender, EventArgs e)
    {
        // Exit after 60 seconds
        if ((DateTime.Now - startTime).TotalSeconds > 60)
        {
            timer.Stop();
            this.Close();
            return;
        }

        // Animate parameters
        f1 = (f1 + (float)rand.NextDouble() / 40.0f) % 10.0f;
        f2 = (f2 + (float)rand.NextDouble() / 40.0f) % 10.0f;
        f3 = (f3 + (float)rand.NextDouble() / 40.0f) % 10.0f;
        f4 = (f4 + (float)rand.NextDouble() / 40.0f) % 10.0f;
        p1 += (PI2 * 0.5f / 360.0f);

        // Run compute and draw
        RunCompute();
        Draw();

        // FPS calculation
        frameCount++;
        if ((DateTime.Now - lastFpsTime).TotalMilliseconds >= 1000)
        {
            float fps = frameCount * 1000.0f / (float)(DateTime.Now - lastFpsTime).TotalMilliseconds;
            frameCount = 0;
            lastFpsTime = DateTime.Now;
            this.Text = $"OpenGL 4.6 Compute Harmonograph (C#) - FPS: {fps:F1}";
        }
    }

    protected override void OnClosed(EventArgs e)
    {
        base.OnClosed(e);
        timer?.Stop();
        DisableOpenGL();
    }

    void EnableOpenGL()
    {
        PIXELFORMATDESCRIPTOR pfd = new PIXELFORMATDESCRIPTOR();
        pfd.nSize      = (ushort)Marshal.SizeOf(typeof(PIXELFORMATDESCRIPTOR));
        pfd.nVersion   = 1;
        pfd.dwFlags    = PFD_SUPPORT_OPENGL | PFD_DRAW_TO_WINDOW | PFD_DOUBLEBUFFER;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cColorBits = 24;
        pfd.cDepthBits = 24;

        this.hDC = GetDC(this.Handle);
        int format = ChoosePixelFormat(hDC, ref pfd);
        SetPixelFormat(hDC, format, ref pfd);

        // Create legacy context first
        IntPtr hGLRC_old = wglCreateContext(this.hDC);
        wglMakeCurrent(this.hDC, hGLRC_old);

        // Load wglCreateContextAttribsARB
        IntPtr wglCreateContextAttribsARBPtr = wglGetProcAddress("wglCreateContextAttribsARB");
        wglCreateContextAttribsARB = Marshal.GetDelegateForFunctionPointer<wglCreateContextAttribsARBDelegate>(wglCreateContextAttribsARBPtr);

        // Create OpenGL 4.6 core profile context
        int[] attribs = {
            WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
            WGL_CONTEXT_MINOR_VERSION_ARB, 6,
            WGL_CONTEXT_FLAGS_ARB, 0,
            WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
            0
        };

        this.hGLRC = wglCreateContextAttribsARB(this.hDC, IntPtr.Zero, attribs);
        wglMakeCurrent(this.hDC, this.hGLRC);
        wglDeleteContext(hGLRC_old);

        glViewport(0, 0, WIDTH, HEIGHT);
    }

    void InitOpenGLFunc()
    {
        glGenBuffers        = GetDelegate<glGenBuffersDelegate>("glGenBuffers");
        glBindBuffer        = GetDelegate<glBindBufferDelegate>("glBindBuffer");
        glBufferData        = GetDelegate<glBufferDataDelegate>("glBufferData");
        glBindBufferBase    = GetDelegate<glBindBufferBaseDelegate>("glBindBufferBase");
        glCreateShader      = GetDelegate<glCreateShaderDelegate>("glCreateShader");
        glShaderSource      = GetDelegate<glShaderSourceDelegate>("glShaderSource");
        glCompileShader     = GetDelegate<glCompileShaderDelegate>("glCompileShader");
        glGetShaderiv       = GetDelegate<glGetShaderivDelegate>("glGetShaderiv");
        glGetShaderInfoLog  = GetDelegate<glGetShaderInfoLogDelegate>("glGetShaderInfoLog");
        glDeleteShader      = GetDelegate<glDeleteShaderDelegate>("glDeleteShader");
        glCreateProgram     = GetDelegate<glCreateProgramDelegate>("glCreateProgram");
        glAttachShader      = GetDelegate<glAttachShaderDelegate>("glAttachShader");
        glLinkProgram       = GetDelegate<glLinkProgramDelegate>("glLinkProgram");
        glUseProgram        = GetDelegate<glUseProgramDelegate>("glUseProgram");
        glGetProgramiv      = GetDelegate<glGetProgramivDelegate>("glGetProgramiv");
        glGetProgramInfoLog = GetDelegate<glGetProgramInfoLogDelegate>("glGetProgramInfoLog");
        glGetUniformLocation= GetDelegate<glGetUniformLocationDelegate>("glGetUniformLocation");
        glUniform1f         = GetDelegate<glUniform1fDelegate>("glUniform1f");
        glUniform2f         = GetDelegate<glUniform2fDelegate>("glUniform2f");
        glUniform1ui        = GetDelegate<glUniform1uiDelegate>("glUniform1ui");
        glGenVertexArrays   = GetDelegate<glGenVertexArraysDelegate>("glGenVertexArrays");
        glBindVertexArray   = GetDelegate<glBindVertexArrayDelegate>("glBindVertexArray");
        glDispatchCompute   = GetDelegate<glDispatchComputeDelegate>("glDispatchCompute");
        glMemoryBarrier     = GetDelegate<glMemoryBarrierDelegate>("glMemoryBarrier");
        glDrawArrays        = GetDelegate<glDrawArraysDelegate>("glDrawArrays");
    }

    T GetDelegate<T>(string name) where T : Delegate
    {
        IntPtr ptr = wglGetProcAddress(name);
        if (ptr == IntPtr.Zero)
            throw new Exception($"Failed to get {name}");
        return Marshal.GetDelegateForFunctionPointer<T>(ptr);
    }

    uint CompileShader(uint type, string source)
    {
        uint shader = glCreateShader(type);
        string[] sources = { source };
        glShaderSource(shader, 1, sources, null);
        glCompileShader(shader);

        int status;
        glGetShaderiv(shader, GL_COMPILE_STATUS, out status);
        if (status != GL_TRUE)
        {
            int logLen;
            glGetShaderiv(shader, GL_INFO_LOG_LENGTH, out logLen);
            if (logLen > 1)
            {
                var log = new System.Text.StringBuilder(logLen);
                int actualLen;
                glGetShaderInfoLog(shader, logLen, out actualLen, log);
                MessageBox.Show(log.ToString(), "Shader Compile Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            return 0;
        }
        return shader;
    }

    uint LinkProgram(uint[] shaders)
    {
        uint program = glCreateProgram();
        foreach (var shader in shaders)
        {
            glAttachShader(program, shader);
        }
        glLinkProgram(program);

        int status;
        glGetProgramiv(program, GL_LINK_STATUS, out status);
        if (status != GL_TRUE)
        {
            int logLen;
            glGetProgramiv(program, GL_INFO_LOG_LENGTH, out logLen);
            if (logLen > 1)
            {
                var log = new System.Text.StringBuilder(logLen);
                int actualLen;
                glGetProgramInfoLog(program, logLen, out actualLen, log);
                MessageBox.Show(log.ToString(), "Program Link Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            return 0;
        }

        // Delete shaders after linking
        foreach (var shader in shaders)
        {
            glDeleteShader(shader);
        }

        return program;
    }

    void InitResources()
    {
        // Create VAO (required for core profile)
        uint[] vaos = new uint[1];
        glGenVertexArrays(1, vaos);
        vao = vaos[0];
        glBindVertexArray(vao);

        // Create SSBO for positions: vec4 * VERTEX_COUNT (16 bytes each)
        uint[] buffers = new uint[1];
        glGenBuffers(1, buffers);
        ssboPos = buffers[0];
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboPos);
        glBufferData(GL_SHADER_STORAGE_BUFFER, (IntPtr)(16 * VERTEX_COUNT), IntPtr.Zero, GL_DYNAMIC_DRAW);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 7, ssboPos);

        // Create SSBO for colors: vec4 * VERTEX_COUNT (16 bytes each)
        glGenBuffers(1, buffers);
        ssboCol = buffers[0];
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboCol);
        glBufferData(GL_SHADER_STORAGE_BUFFER, (IntPtr)(16 * VERTEX_COUNT), IntPtr.Zero, GL_DYNAMIC_DRAW);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 8, ssboCol);

        // Build draw program (VS + FS)
        uint vs = CompileShader(GL_VERTEX_SHADER, vertexSource);
        uint fs = CompileShader(GL_FRAGMENT_SHADER, fragmentSource);
        drawProgram = LinkProgram(new uint[] { vs, fs });

        // Set resolution uniform
        glUseProgram(drawProgram);
        int loc = glGetUniformLocation(drawProgram, "resolution");
        if (loc >= 0)
        {
            glUniform2f(loc, (float)WIDTH, (float)HEIGHT);
        }

        // Build compute program (CS)
        uint cs = CompileShader(GL_COMPUTE_SHADER, computeSource);
        computeProgram = LinkProgram(new uint[] { cs });
    }

    void SetUniformF(uint prog, string name, float v)
    {
        int loc = glGetUniformLocation(prog, name);
        if (loc >= 0) glUniform1f(loc, v);
    }

    void SetUniformU(uint prog, string name, uint v)
    {
        int loc = glGetUniformLocation(prog, name);
        if (loc >= 0) glUniform1ui(loc, v);
    }

    void RunCompute()
    {
        uint groupsX = (uint)((VERTEX_COUNT + 63) / 64);

        glUseProgram(computeProgram);

        SetUniformU(computeProgram, "max_num", (uint)VERTEX_COUNT);

        SetUniformF(computeProgram, "A1", A1);
        SetUniformF(computeProgram, "f1", f1);
        SetUniformF(computeProgram, "p1", p1);
        SetUniformF(computeProgram, "d1", d1);

        SetUniformF(computeProgram, "A2", A2);
        SetUniformF(computeProgram, "f2", f2);
        SetUniformF(computeProgram, "p2", p2);
        SetUniformF(computeProgram, "d2", d2);

        SetUniformF(computeProgram, "A3", A3);
        SetUniformF(computeProgram, "f3", f3);
        SetUniformF(computeProgram, "p3", p3);
        SetUniformF(computeProgram, "d3", d3);

        SetUniformF(computeProgram, "A4", A4);
        SetUniformF(computeProgram, "f4", f4);
        SetUniformF(computeProgram, "p4", p4);
        SetUniformF(computeProgram, "d4", d4);

        glDispatchCompute(groupsX, 1, 1);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
    }

    void Draw()
    {
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glUseProgram(drawProgram);
        glBindVertexArray(vao);
        glDrawArrays(GL_LINE_STRIP, 0, VERTEX_COUNT);

        SwapBuffers(this.hDC);
    }

    void DisableOpenGL()
    {
        wglMakeCurrent(IntPtr.Zero, IntPtr.Zero);
        if (this.hGLRC != IntPtr.Zero)
            wglDeleteContext(this.hGLRC);
        if (this.hDC != IntPtr.Zero)
            ReleaseDC(this.Handle, this.hDC);
    }

    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new HelloForm());
    }
}