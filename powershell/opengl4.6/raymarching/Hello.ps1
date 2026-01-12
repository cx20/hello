$source = @"
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Diagnostics;

using GLenum  = System.UInt32;
using GLint   = System.UInt32;
using GLuint  = System.UInt32;
using GLsizei = System.UInt32;
using GLfloat = System.Single;

public class RaymarchingForm : Form
{
    const int GL_TRIANGLES        = 0x0004;
    const int GL_TRIANGLE_STRIP   = 0x0005;
    
    const int GL_FLOAT            = 0x1406;
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
    delegate int glGetUniformLocationDelegate(uint program, string name);
    delegate void glEnableVertexAttribArrayDelegate(uint index);
    delegate void glVertexAttribPointerDelegate(uint index, int size, uint type, bool normalized, int stride, IntPtr pointer);
    delegate void glUniform1fDelegate(int location, float v0);
    delegate void glUniform2fDelegate(int location, float v0, float v1);
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
    glGetUniformLocationDelegate        glGetUniformLocation;
    glEnableVertexAttribArrayDelegate   glEnableVertexAttribArray;
    glVertexAttribPointerDelegate       glVertexAttribPointer;
    glUniform1fDelegate                 glUniform1f;
    glUniform2fDelegate                 glUniform2f;
    wglCreateContextAttribsARBDelegate  wglCreateContextAttribsARB;

    IntPtr hDC   = (IntPtr)0;
    IntPtr hGLRC = (IntPtr)0;
    GLuint[] vbo;
    GLint posAttrib;
    int timeLocation;
    int resolutionLocation;
    
    Stopwatch stopwatch;
    Timer timer;

    const string vertexSource = @"
#version 460 core
layout(location = 0) in vec2 position;
out vec2 fragCoord;
void main()
{
    fragCoord = position * 0.5 + 0.5;
    gl_Position = vec4(position, 0.0, 1.0);
}
";

    const string fragmentSource = @"
#version 460 core
precision highp float;

in vec2 fragCoord;
out vec4 outColor;

uniform float iTime;
uniform vec2 iResolution;

const int MAX_STEPS = 100;
const float MAX_DIST = 100.0;
const float SURF_DIST = 0.001;

// Signed Distance Functions
float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Smooth minimum for blending shapes
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Scene distance function
float GetDist(vec3 p) {
    // Animated sphere
    float sphere = sdSphere(p - vec3(sin(iTime) * 1.5, 0.5 + sin(iTime * 2.0) * 0.3, 0.0), 0.5);
    
    // Rotating torus
    float angle = iTime * 0.5;
    vec3 torusPos = p - vec3(0.0, 0.5, 0.0);
    torusPos.xz = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * torusPos.xz;
    torusPos.xy = mat2(cos(angle * 0.7), -sin(angle * 0.7), sin(angle * 0.7), cos(angle * 0.7)) * torusPos.xy;
    float torus = sdTorus(torusPos, vec2(0.8, 0.2));
    
    // Ground plane
    float plane = p.y + 0.5;
    
    // Combine with smooth blending
    float d = smin(sphere, torus, 0.3);
    d = min(d, plane);
    
    return d;
}

// Calculate normal using gradient
vec3 GetNormal(vec3 p) {
    float d = GetDist(p);
    vec2 e = vec2(0.001, 0.0);
    vec3 n = d - vec3(
        GetDist(p - e.xyy),
        GetDist(p - e.yxy),
        GetDist(p - e.yyx)
    );
    return normalize(n);
}

// Raymarching
float RayMarch(vec3 ro, vec3 rd) {
    float dO = 0.0;
    for(int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * dO;
        float dS = GetDist(p);
        dO += dS;
        if(dO > MAX_DIST || dS < SURF_DIST) break;
    }
    return dO;
}

// Soft shadows
float GetShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
    float res = 1.0;
    float t = mint;
    for(int i = 0; i < 64 && t < maxt; i++) {
        float h = GetDist(ro + rd * t);
        if(h < 0.001)
            return 0.0;
        res = min(res, k * h / t);
        t += h;
    }
    return res;
}

// Ambient occlusion
float GetAO(vec3 p, vec3 n) {
    float occ = 0.0;
    float sca = 1.0;
    for(int i = 0; i < 5; i++) {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = GetDist(p + h * n);
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

void main()
{
    vec2 uv = fragCoord - 0.5;
    uv.x *= iResolution.x / iResolution.y;
    
    // Camera setup
    vec3 ro = vec3(0.0, 1.5, -4.0);
    vec3 rd = normalize(vec3(uv.x, uv.y, 1.0));
    
    // Light position
    vec3 lightPos = vec3(3.0, 5.0, -2.0);
    
    // Raymarching
    float d = RayMarch(ro, rd);
    
    vec3 col = vec3(0.0);
    
    if(d < MAX_DIST) {
        vec3 p = ro + rd * d;
        vec3 n = GetNormal(p);
        vec3 l = normalize(lightPos - p);
        vec3 v = normalize(ro - p);
        vec3 r = reflect(-l, n);
        
        // Material color based on position
        vec3 matCol = vec3(0.4, 0.6, 0.9);
        if(p.y < -0.49) {
            // Checkerboard floor
            float checker = mod(floor(p.x) + floor(p.z), 2.0);
            matCol = mix(vec3(0.2), vec3(0.8), checker);
        }
        
        // Lighting
        float diff = max(dot(n, l), 0.0);
        float spec = pow(max(dot(r, v), 0.0), 32.0);
        float ao = GetAO(p, n);
        float shadow = GetShadow(p + n * 0.01, l, 0.01, length(lightPos - p), 16.0);
        
        // Ambient
        vec3 ambient = vec3(0.1, 0.12, 0.15);
        
        col = matCol * (ambient * ao + diff * shadow) + vec3(1.0) * spec * shadow * 0.5;
        
        // Fog
        col = mix(col, vec3(0.05, 0.05, 0.1), 1.0 - exp(-0.02 * d * d));
    } else {
        // Background gradient
        col = mix(vec3(0.1, 0.1, 0.15), vec3(0.02, 0.02, 0.05), fragCoord.y);
    }
    
    // Gamma correction
    col = pow(col, vec3(0.4545));
    
    outColor = vec4(col, 1.0);
}
";

    public RaymarchingForm()
    {
        this.Size = new Size(800, 600);
        this.Text = "Raymarching - OpenGL 4.6 / PowerShell";
        this.DoubleBuffered = true;
        vbo = new uint[1];
        stopwatch = new Stopwatch();
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        
        EnableOpenGL();
        InitOpenGLFunc();
        InitShader();
        
        stopwatch.Start();
        
        timer = new Timer();
        timer.Interval = 16; // ~60 FPS
        timer.Tick += (s, args) => this.Invalidate();
        timer.Start();
    }
    
    protected override void OnPaint(PaintEventArgs e) {  
        base.OnPaint(e); 
        Render();
    }
    
    protected override void OnResize(EventArgs e) {
        base.OnResize(e);
        this.Invalidate();
    }
    
    protected override void OnClosed(EventArgs e) {
        base.OnClosed(e);
        if (timer != null) {
            timer.Stop();
        }
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
        
        IntPtr hGLRC_old = wglCreateContext(this.hDC);
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
        IntPtr glGetUniformLocationPtr      = wglGetProcAddress("glGetUniformLocation");
        IntPtr glEnableVertexAttribArrayPtr = wglGetProcAddress("glEnableVertexAttribArray");
        IntPtr glVertexAttribPointerPtr     = wglGetProcAddress("glVertexAttribPointer");
        IntPtr glUniform1fPtr               = wglGetProcAddress("glUniform1f");
        IntPtr glUniform2fPtr               = wglGetProcAddress("glUniform2f");

        glGenBuffers              = Marshal.GetDelegateForFunctionPointer<glGenBuffersDelegate              >(glGenBuffersPtr             );
        glBindBuffer              = Marshal.GetDelegateForFunctionPointer<glBindBufferDelegate              >(glBindBufferPtr             );
        glBufferDataFloat         = Marshal.GetDelegateForFunctionPointer<glBufferDataFloatDelegate         >(glBufferDataPtr             );
        glCreateShader            = Marshal.GetDelegateForFunctionPointer<glCreateShaderDelegate            >(glCreateShaderPtr           );
        glShaderSource            = Marshal.GetDelegateForFunctionPointer<glShaderSourceDelegate            >(glShaderSourcePtr           );
        glCompileShader           = Marshal.GetDelegateForFunctionPointer<glCompileShaderDelegate           >(glCompileShaderPtr          );
        glCreateProgram           = Marshal.GetDelegateForFunctionPointer<glCreateProgramDelegate           >(glCreateProgramPtr          );
        glAttachShader            = Marshal.GetDelegateForFunctionPointer<glAttachShaderDelegate            >(glAttachShaderPtr           );
        glLinkProgram             = Marshal.GetDelegateForFunctionPointer<glLinkProgramDelegate             >(glLinkProgramPtr            );
        glUseProgram              = Marshal.GetDelegateForFunctionPointer<glUseProgramDelegate              >(glUseProgramPtr             );
        glGetAttribLocation       = Marshal.GetDelegateForFunctionPointer<glGetAttribLocationDelegate       >(glGetAttribLocationPtr      );
        glGetUniformLocation      = Marshal.GetDelegateForFunctionPointer<glGetUniformLocationDelegate      >(glGetUniformLocationPtr     );
        glEnableVertexAttribArray = Marshal.GetDelegateForFunctionPointer<glEnableVertexAttribArrayDelegate >(glEnableVertexAttribArrayPtr);
        glVertexAttribPointer     = Marshal.GetDelegateForFunctionPointer<glVertexAttribPointerDelegate     >(glVertexAttribPointerPtr    );
        glUniform1f               = Marshal.GetDelegateForFunctionPointer<glUniform1fDelegate               >(glUniform1fPtr              );
        glUniform2f               = Marshal.GetDelegateForFunctionPointer<glUniform2fDelegate               >(glUniform2fPtr              );
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
        
        timeLocation = glGetUniformLocation(shaderProgram, "iTime");
        resolutionLocation = glGetUniformLocation(shaderProgram, "iResolution");

        glGenBuffers(1, vbo);

        // Fullscreen quad (two triangles)
        float[] vertices = {
            -1.0f, -1.0f,
             1.0f, -1.0f,
            -1.0f,  1.0f,
            -1.0f,  1.0f,
             1.0f, -1.0f,
             1.0f,  1.0f
        };
        
        glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
        glBufferDataFloat(GL_ARRAY_BUFFER, vertices.Length * sizeof(float), vertices, GL_STATIC_DRAW);
    }

    void Render() {
        float time = (float)stopwatch.Elapsed.TotalSeconds;
        
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glUniform1f(timeLocation, time);
        glUniform2f(resolutionLocation, (float)this.ClientSize.Width, (float)this.ClientSize.Height);

        glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
        glVertexAttribPointer(posAttrib, 2, GL_FLOAT, false, 0, IntPtr.Zero);
        
        glDrawArrays(GL_TRIANGLES, 0, 6);

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
        RaymarchingForm form = new RaymarchingForm();
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
[void][RaymarchingForm]::Main()

