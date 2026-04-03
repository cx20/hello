import core.sys.windows.windef;
import core.sys.windows.winbase : OutputDebugStringA;
import core.stdc.stdio : snprintf;
import std.string : toStringz;
import bindbc.glfw;
import bindbc.opengl;

void debugLog(const(char)* msg)
{
    OutputDebugStringA(msg);
}

void debugLogInt(const(char)* label, int value)
{
    char[256] buf = void;
    const int n = snprintf(buf.ptr, buf.length, "[opengl1.0_glfw/d] %s=%d\n", label, value);
    if (n > 0) {
        OutputDebugStringA(buf.ptr);
    }
}

extern(Windows)
int WinMain(HINSTANCE /* hInstance */, HINSTANCE /* hPrevInstance */, LPSTR /* lpCmdLine */, int /* nCmdShow */)
{
    int frame = 0;
    GLFWSupport ret;
    debugLog("[opengl1.0_glfw/d] WinMain start\n");

    ret = loadGLFW();
    debugLogInt("loadGLFW", cast(int)ret);
    if (ret != glfwSupport) {
        debugLog("[opengl1.0_glfw/d] loadGLFW default failed, trying explicit DLL path\n");

        ret = loadGLFW(toStringz("C:\\Libraries\\glfw-3.4.bin.WIN64\\lib-vc2022\\glfw3.dll"));
        debugLogInt("loadGLFW(C:/Libraries/glfw-3.4.../glfw3.dll)", cast(int)ret);

        if (ret != glfwSupport) {
            ret = loadGLFW(toStringz("C:\\Libraries\\glfw-3.3.8.bin.WIN64\\lib-vc2022\\glfw3.dll"));
            debugLogInt("loadGLFW(C:/Libraries/glfw-3.3.8.../glfw3.dll)", cast(int)ret);
        }

        if (ret != glfwSupport) {
            debugLog("[opengl1.0_glfw/d] loadGLFW failed\n");
            return 1;
        }
    }
    debugLog("[opengl1.0_glfw/d] loadGLFW ok\n");

    if (!glfwInit()) {
        debugLog("[opengl1.0_glfw/d] glfwInit failed\n");
        return 1;
    }
    scope(exit) glfwTerminate();
    debugLog("[opengl1.0_glfw/d] glfwInit ok\n");

    GLFWwindow* window = glfwCreateWindow(640, 480, "Hello, World!", null, null);
    if (window is null) {
        debugLog("[opengl1.0_glfw/d] glfwCreateWindow failed (null)\n");
        return 1;
    }
    debugLog("[opengl1.0_glfw/d] glfwCreateWindow ok\n");

    glfwMakeContextCurrent(window);
    if (glfwGetCurrentContext() is null) {
        debugLog("[opengl1.0_glfw/d] glfwMakeContextCurrent failed\n");
        return 1;
    }
    debugLog("[opengl1.0_glfw/d] glfwMakeContextCurrent ok\n");

    const GLSupport openglLoaded = loadOpenGL();
    debugLogInt("loadOpenGL", cast(int)openglLoaded);
    if (openglLoaded == GLSupport.noLibrary) {
        debugLog("[opengl1.0_glfw/d] loadOpenGL failed: noLibrary\n");
        return 1;
    }
    debugLog("[opengl1.0_glfw/d] loadOpenGL ok\n");

    debugLog("[opengl1.0_glfw/d] Enter render loop\n");

    while (!glfwWindowShouldClose(window)) {
        if ((frame % 300) == 0) {
            debugLogInt("frame", frame);
        }

        glClearColor(0f, 0f, 0f, 1f);
        glClear(GL_COLOR_BUFFER_BIT);

        glBegin(GL_TRIANGLES);
            glColor3f(1.0f, 0.0f, 0.0f);  glVertex2f( 0.0f,  0.5f);
            glColor3f(0.0f, 1.0f, 0.0f);  glVertex2f( 0.5f, -0.5f);
            glColor3f(0.0f, 0.0f, 1.0f);  glVertex2f(-0.5f, -0.5f);
        glEnd();

        glfwSwapBuffers(window);
        glfwPollEvents();
        frame++;
    }

    debugLog("[opengl1.0_glfw/d] Exit render loop\n");
    return 0;
}
