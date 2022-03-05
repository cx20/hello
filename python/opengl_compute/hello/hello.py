# forked from https://gaz.hateblo.jp/entry/2018/12/28/002720

from OpenGL.GL import *
from OpenGL.WGL import *
from ctypes import *
from ctypes.wintypes import *
import sys
import random

vsh = """
#version 430

struct Particle{
    vec4 pos;
};

layout(std430, binding=7) buffer particles{
    Particle par[];
};

uniform vec2 resolution;
out vec4 vColor;

mat4 perspective(float fov, float aspect, float near, float far)
{
    float v = 1./tan(radians(fov/2.)), u = v/aspect, w = near-far;
    return mat4(u,0,0,0,0,v,0,0,0,0,(near+far)/w,-1,0,0,near*far*2./w,1);
}

mat4 lookAt(vec3 eye, vec3 center, vec3 up)
{
  vec3 w = normalize(eye - center);
  vec3 u = normalize(cross(up, w));
  vec3 v = normalize(cross(w, u));
  return mat4(
    u.x, v.x, w.x, 0,
    u.y, v.y, w.y, 0,
    u.z, v.z, w.z, 0,
    -dot(u, eye), -dot(u, eye), -dot(w, eye), 1
  );
}

void main(void){    
  mat4 pMat = perspective(45.0, resolution.x / resolution.y, 0.1, 200.0);
  vec3 camera = vec3(0,5,10);
  vec3 center = vec3(0,0,0);
  mat4 vMat = lookAt(camera, center, vec3(0,1,0));    
  gl_Position = pMat*vMat*par[gl_VertexID].pos;
  //gl_Position = vec4(par[gl_VertexID].pos.x, par[gl_VertexID].pos.y, par[gl_VertexID].pos.z, par[gl_VertexID].pos.w * 1.0);
  
  vColor = vec4(
  	gl_Position.x * 0.1 + 0.5,
  	gl_Position.y * 0.1 + 0.5,
  	gl_Position.z * 0.1 + 0.5,
  	1.0);
}
"""

fsh = """
#version 430

in  vec4 vColor;
out vec4 fragColor;

void main()
{
    //fragColor = vec4(1.0);
    fragColor = vColor;
}
"""

csh = """
#version 430

struct Particle{
    vec4 pos;
};

layout(std430, binding=7) buffer particles{
    Particle par[];
};

uniform float time;
uniform uint max_num;

uniform float f1;
uniform float f2;
uniform float f3;
uniform float f4;

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

#define PI 3.14159265359
#define PI2 ( PI * 2.0 )

vec2 rotate( in vec2 p, in float t )
{
  return p * cos( -t ) + vec2( p.y, -p.x ) * sin( -t );
}   


float hash(float n)
{
  return fract(sin(n)*753.5453123);
}

float A1 = 0.2, p1 = 1.0/16.0,  d1 = 0.02;
float A2 = 0.2, p2 = 3.0/2.0,   d2 = 0.0315;
float A3 = 0.2, p3 = 13.0/15.0, d3 = 0.02;
float A4 = 0.2, p4 = 1.0,       d4 = 0.02;
/*
float A1 = 0.2, p1 = 1.0/16.0,  d1 = 0.02;
float A2 = 0.2, p2 = 3.0/2.0,   d2 = 0.0315;
float A3 = 0.2, p3 = 13.0/15.0, d3 = 0.02;
float A4 = 0.2, p4 = 1.0,       d4 = 0.02;
float PI = 3.141592;
*/
void main(){
  uint id = gl_GlobalInvocationID.x;
  float theta = hash(float(id)*0.3123887) * PI2 + time;
  
    p1 = theta;
    //p1 = time;
    
    float t = theta;
    float x = A1 * sin(f1 * t + PI * p1) * exp(-d1 * t) + A2 * sin(f2 * t + PI * p2) * exp(-d2 * t);
    float y = A3 * sin(f3 * t + PI * p3) * exp(-d3 * t) + A4 * sin(f4 * t + PI * p4) * exp(-d4 * t);
    float z = A1 * cos(f1 * t + PI * p1) * exp(-d1 * t) + A2 * cos(f2 * t + PI * p2) * exp(-d2 * t);
/*
  par[id].pos.x = cos(theta)+1.5;
  par[id].pos.y = sin(theta)*1.8;
  par[id].pos.z = sin(theta)*2.0;
*/  
  par[id].pos.x = x;
  par[id].pos.y = y;
  par[id].pos.z = z;

  par[id].pos.w = 1.0;
  par[id].pos.xz = rotate(par[id].pos.xz, hash(float(id)*0.5123)*PI2);
  par[id].pos.xyz *= 5.0;
}
"""

winmm = windll.winmm 
kernel32 = windll.kernel32
user32 = windll.user32

XRES = 640
YRES = 480

WS_OVERLAPPEDWINDOW = 0xcf0000
WS_VISIBLE = 0x10000000
PM_REMOVE = 1
WM_NCLBUTTONDOWN = 161
HTCLOSE = 20
VK_ESCAPE = 27
PFD_SUPPORT_OPENGL = 32
PFD_DOUBLEBUFFER = 1

hWnd = user32.CreateWindowExA(0,0xC018,0,WS_OVERLAPPEDWINDOW|WS_VISIBLE,30,30,XRES,YRES,0,0,0,0)
hdc = user32.GetDC(hWnd)   
user32.SetForegroundWindow(hWnd)
pfd = PIXELFORMATDESCRIPTOR(0,1,PFD_SUPPORT_OPENGL|PFD_DOUBLEBUFFER,32,0,0,0,0,0,0,0,0,0,0,0,0,0,32,0,0,0,0,0,0,0)
SetPixelFormat(hdc, ChoosePixelFormat(hdc, pfd), pfd)
hGLrc = wglCreateContext(hdc)
wglMakeCurrent(hdc, hGLrc)

max_num = 10000    

glClearColor(0, 0, 0, 1)
glEnable(GL_CULL_FACE)
glCullFace(GL_BACK)
glEnable(GL_DEPTH_TEST)
glDepthFunc(GL_LEQUAL)

program = glCreateProgram()
for s, t in zip((vsh, fsh), (GL_VERTEX_SHADER, GL_FRAGMENT_SHADER)):    
    shader = glCreateShader(t)
    glShaderSource(shader, s)
    glCompileShader(shader)
    if glGetShaderiv(shader, GL_COMPILE_STATUS) != GL_TRUE:
        raise RuntimeError(glGetShaderInfoLog(shader).decode())
    glAttachShader(program, shader)
glLinkProgram(program)
glUseProgram(program)
glUniform2f(glGetUniformLocation(program, "resolution"), XRES , YRES)
    
computeProg = glCreateProgram()
shader = glCreateShader(GL_COMPUTE_SHADER)
glShaderSource(shader, csh)
glCompileShader(shader)
if glGetShaderiv(shader, GL_COMPILE_STATUS) != GL_TRUE:
    raise RuntimeError(glGetShaderInfoLog(shader).decode())
glAttachShader(computeProg, shader)
glLinkProgram(computeProg)
glUseProgram(computeProg)

ssbo = glGenBuffers(1)
glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo)
glBufferData(GL_SHADER_STORAGE_BUFFER, 4 * 4 * max_num, None, GL_STATIC_DRAW)

glUseProgram(program);
glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 7, ssbo)
glUseProgram(computeProg)
glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 7, ssbo)

duration = 60
msg = MSG()
lpmsg = pointer(msg)
zero = winmm.timeGetTime()
done = False
fps, cnt, s0 = 0, 0, 0

f1 = 2
f2 = 2
f3 = 2
f4 = 2

while done==False:
    while user32.PeekMessageA(lpmsg, 0, 0, 0, PM_REMOVE):
        if (msg.message == WM_NCLBUTTONDOWN and msg.wParam == HTCLOSE): done = True
        user32.DispatchMessageA(lpmsg)
    if(user32.GetAsyncKeyState(VK_ESCAPE)):  done = True
    t = (winmm.timeGetTime() - zero)*0.0001
    f1 = (f1 + random.random() / 100) % 10;
    f2 = (f2 + random.random() / 100) % 10;
    f3 = (f3 + random.random() / 100) % 10;
    f4 = (f4 + random.random() / 100) % 10;
    
    glUseProgram(computeProg);
    glUniform1f(glGetUniformLocation(computeProg, "time"), t)

    glUniform1f(glGetUniformLocation(computeProg, "f1"), f1)
    glUniform1f(glGetUniformLocation(computeProg, "f2"), f2)
    glUniform1f(glGetUniformLocation(computeProg, "f3"), f3)
    glUniform1f(glGetUniformLocation(computeProg, "f4"), f4)

    glDispatchCompute(max_num//128, 1, 1)
    
    glUseProgram(program);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glDrawArrays(GL_POINTS, 0, max_num)
    
    SwapBuffers(hdc)
    
    cnt += 1
    if (t - s0 > 1):
        fps = cnt      
        cnt = 0
        s0 = t
    sys.stdout.write("\r FPS : %d TIME : %f" %(fps,t))
    sys.stdout.flush()
    
    if (t > duration):  done = True
    
wglMakeCurrent(0, 0)
wglDeleteContext(hGLrc)
user32.ReleaseDC(hWnd, hdc)
user32.PostQuitMessage(0)
user32.DestroyWindow(hWnd)
