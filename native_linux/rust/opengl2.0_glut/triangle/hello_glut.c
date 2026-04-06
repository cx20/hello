#include <GL/glut.h>
#include <GL/glext.h>
#include <stdio.h>
#include <stdlib.h>

static const char* VS_SRC =
    "#version 110\n"
    "attribute vec3 position;\n"
    "attribute vec3 color;\n"
    "varying vec3 vColor;\n"
    "void main() { vColor = color; gl_Position = vec4(position, 1.0); }\n";

static const char* FS_SRC =
    "#version 110\n"
    "varying vec3 vColor;\n"
    "void main() { gl_FragColor = vec4(vColor, 1.0); }\n";

static PFNGLCREATESHADERPROC        glCreateShader;
static PFNGLSHADERSOURCEPROC        glShaderSource;
static PFNGLCOMPILESHADERPROC       glCompileShader;
static PFNGLGETSHADERIVPROC         glGetShaderiv;
static PFNGLGETSHADERINFOLOGPROC    glGetShaderInfoLog;
static PFNGLCREATEPROGRAMPROC       glCreateProgram;
static PFNGLATTACHSHADERPROC        glAttachShader;
static PFNGLLINKPROGRAMPROC         glLinkProgram;
static PFNGLGETPROGRAMIVPROC        glGetProgramiv;
static PFNGLGETPROGRAMINFOLOGPROC   glGetProgramInfoLog;
static PFNGLUSEPROGRAMPROC          glUseProgram;
static PFNGLGENBUFFERSPROC          glGenBuffers;
static PFNGLBINDBUFFERPROC          glBindBuffer;
static PFNGLBUFFERDATAPROC          glBufferData;
static PFNGLGETATTRIBLOCATIONPROC   glGetAttribLocation;
static PFNGLENABLEVERTEXATTRIBARRAYPROC  glEnableVertexAttribArray;
static PFNGLDISABLEVERTEXATTRIBARRAYPROC glDisableVertexAttribArray;
static PFNGLVERTEXATTRIBPOINTERPROC glVertexAttribPointer;
static PFNGLDELETEBUFFERSPROC       glDeleteBuffers;
static PFNGLDELETEPROGRAMPROC       glDeleteProgram;
static PFNGLDELETESHADERPROC        glDeleteShader;

#define LOAD_PROC(type, name) name = (type)glutGetProcAddress(#name)

static GLuint gProgram, gVS, gFS;
static GLuint gBufs[2];
static GLint  gPosLoc, gColLoc;

static GLuint CompileShader(GLenum t, const char* src)
{
    GLuint s = glCreateShader(t);
    glShaderSource(s, 1, &src, NULL); glCompileShader(s);
    GLint ok=0; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) { GLchar log[1024]; GLsizei l=0; glGetShaderInfoLog(s,sizeof(log),&l,log); fprintf(stderr,"shader: %s\n",log); exit(1); }
    return s;
}

static GLuint LinkProgram(GLuint vs, GLuint fs)
{
    GLuint p = glCreateProgram();
    glAttachShader(p,vs); glAttachShader(p,fs); glLinkProgram(p);
    GLint ok=0; glGetProgramiv(p,GL_LINK_STATUS,&ok);
    if (!ok) { GLchar log[1024]; GLsizei l=0; glGetProgramInfoLog(p,sizeof(log),&l,log); fprintf(stderr,"link: %s\n",log); exit(1); }
    return p;
}

static void LoadProcs(void)
{
    LOAD_PROC(PFNGLCREATESHADERPROC, glCreateShader);
    LOAD_PROC(PFNGLSHADERSOURCEPROC, glShaderSource);
    LOAD_PROC(PFNGLCOMPILESHADERPROC, glCompileShader);
    LOAD_PROC(PFNGLGETSHADERIVPROC, glGetShaderiv);
    LOAD_PROC(PFNGLGETSHADERINFOLOGPROC, glGetShaderInfoLog);
    LOAD_PROC(PFNGLCREATEPROGRAMPROC, glCreateProgram);
    LOAD_PROC(PFNGLATTACHSHADERPROC, glAttachShader);
    LOAD_PROC(PFNGLLINKPROGRAMPROC, glLinkProgram);
    LOAD_PROC(PFNGLGETPROGRAMIVPROC, glGetProgramiv);
    LOAD_PROC(PFNGLGETPROGRAMINFOLOGPROC, glGetProgramInfoLog);
    LOAD_PROC(PFNGLUSEPROGRAMPROC, glUseProgram);
    LOAD_PROC(PFNGLGENBUFFERSPROC, glGenBuffers);
    LOAD_PROC(PFNGLBINDBUFFERPROC, glBindBuffer);
    LOAD_PROC(PFNGLBUFFERDATAPROC, glBufferData);
    LOAD_PROC(PFNGLGETATTRIBLOCATIONPROC, glGetAttribLocation);
    LOAD_PROC(PFNGLENABLEVERTEXATTRIBARRAYPROC, glEnableVertexAttribArray);
    LOAD_PROC(PFNGLDISABLEVERTEXATTRIBARRAYPROC, glDisableVertexAttribArray);
    LOAD_PROC(PFNGLVERTEXATTRIBPOINTERPROC, glVertexAttribPointer);
    LOAD_PROC(PFNGLDELETEBUFFERSPROC, glDeleteBuffers);
    LOAD_PROC(PFNGLDELETEPROGRAMPROC, glDeleteProgram);
    LOAD_PROC(PFNGLDELETESHADERPROC, glDeleteShader);
}

static void Initialize(void)
{
    static const GLfloat verts[] = { 0.0f,0.7f,0.0f, -0.7f,-0.7f,0.0f, 0.7f,-0.7f,0.0f };
    static const GLfloat cols[]  = { 1.0f,0.0f,0.0f, 0.0f,1.0f,0.0f, 0.0f,0.0f,1.0f };
    LoadProcs();
    glClearColor(0.0f,0.0f,0.0f,1.0f);
    gVS=CompileShader(GL_VERTEX_SHADER,VS_SRC); gFS=CompileShader(GL_FRAGMENT_SHADER,FS_SRC);
    gProgram=LinkProgram(gVS,gFS);
    gPosLoc=glGetAttribLocation(gProgram,"position"); gColLoc=glGetAttribLocation(gProgram,"color");
    glGenBuffers(2,gBufs);
    glBindBuffer(GL_ARRAY_BUFFER,gBufs[0]); glBufferData(GL_ARRAY_BUFFER,sizeof(verts),verts,GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER,gBufs[1]); glBufferData(GL_ARRAY_BUFFER,sizeof(cols),cols,GL_STATIC_DRAW);
}

static void Display(void)
{
    glClear(GL_COLOR_BUFFER_BIT); glUseProgram(gProgram);
    glEnableVertexAttribArray((GLuint)gPosLoc);
    glBindBuffer(GL_ARRAY_BUFFER,gBufs[0]); glVertexAttribPointer((GLuint)gPosLoc,3,GL_FLOAT,GL_FALSE,0,(const void*)0);
    glEnableVertexAttribArray((GLuint)gColLoc);
    glBindBuffer(GL_ARRAY_BUFFER,gBufs[1]); glVertexAttribPointer((GLuint)gColLoc,3,GL_FLOAT,GL_FALSE,0,(const void*)0);
    glDrawArrays(GL_TRIANGLES,0,3);
    glDisableVertexAttribArray((GLuint)gColLoc); glDisableVertexAttribArray((GLuint)gPosLoc);
    glutSwapBuffers();
}

static void Reshape(int w,int h){ glViewport(0,0,w,h); }
static void Timer(int v){ (void)v; glutPostRedisplay(); glutTimerFunc(16,Timer,0); }
static void OnClose(void){ glDeleteBuffers(2,gBufs); glDeleteProgram(gProgram); glDeleteShader(gFS); glDeleteShader(gVS); exit(0); }
static void Keyboard(unsigned char k,int x,int y){ (void)x;(void)y; if(k==27||k=='q'||k=='Q') OnClose(); }

void runSample(void)
{
    int argc=0;
    glutInit(&argc,NULL);
    glutInitDisplayMode(GLUT_DOUBLE|GLUT_RGBA);
    glutInitWindowSize(640,480);
    glutCreateWindow("Hello, OpenGL 2.0 World!");
    Initialize();
    glutDisplayFunc(Display); glutReshapeFunc(Reshape); glutCloseFunc(OnClose); glutKeyboardFunc(Keyboard); glutTimerFunc(16,Timer,0);
    glutMainLoop();
}
