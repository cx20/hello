import std.string;
import std.conv;
import core.sys.windows.windef;
import core.sys.windows.winbase : OutputDebugStringA;
import core.stdc.stdio : snprintf;
import bindbc.glfw;
import bindbc.opengl;

void debugLog(const(char)* msg)
{
    OutputDebugStringA(msg);
}

void debugLogInt(const(char)* label, int value)
{
    char[256] buf = void;
    const int n = snprintf(buf.ptr, buf.length, "[opengl2.0_glfw/d] %s=%d\n", label, value);
    if (n > 0) {
        OutputDebugStringA(buf.ptr);
    }
}

GLuint[2] vbo;
GLint posAttrib;
GLint colAttrib;

// Shader sources
immutable string vertexSource = `
attribute vec3 position;
attribute vec3 color;
varying   vec4 vColor;
void main()
{
    vColor = vec4(color, 1.0);
    gl_Position = vec4(position, 1.0);
}`;

immutable string fragmentSource = `
varying vec4 vColor;
void main()
{
    gl_FragColor = vColor;
}`;

extern(Windows)
int WinMain(HINSTANCE /* hInstance */, HINSTANCE /* hPrevInstance */, LPSTR /* lpCmdLine */, int /* nCmdShow */)
{
    GLFWSupport ret = loadGLFW();
    debugLogInt("loadGLFW", cast(int)ret);
    if (ret != glfwSupport) {
        debugLog("[opengl2.0_glfw/d] loadGLFW default failed, trying explicit DLL path\n");

        ret = loadGLFW(toStringz("C:\\Libraries\\glfw-3.4.bin.WIN64\\lib-vc2022\\glfw3.dll"));
        debugLogInt("loadGLFW(C:/Libraries/glfw-3.4.../glfw3.dll)", cast(int)ret);

        if (ret != glfwSupport) {
            ret = loadGLFW(toStringz("C:\\Libraries\\glfw-3.3.8.bin.WIN64\\lib-vc2022\\glfw3.dll"));
            debugLogInt("loadGLFW(C:/Libraries/glfw-3.3.8.../glfw3.dll)", cast(int)ret);
        }

        if (ret != glfwSupport) {
            debugLog("[opengl2.0_glfw/d] loadGLFW failed\n");
            return 1;
        }
    }
    debugLog("[opengl2.0_glfw/d] loadGLFW ok\n");

    if (!glfwInit()) {
        return 1;
    }
    scope(exit) glfwTerminate();

    GLFWwindow* window = glfwCreateWindow(640, 480, "Hello, World!", null, null);
    if (window is null) {
        return 1;
    }
    glfwMakeContextCurrent(window);

    loadOpenGL();

    initShader();

    while (!glfwWindowShouldClose(window)) {
        glClearColor(0f, 0f, 0f, 1f);
        glClear(GL_COLOR_BUFFER_BIT);

        drawTriangle();

        glfwSwapBuffers(window);
        glfwPollEvents();
    }
    return 0;
}

void initShader()
{
    glGenBuffers(2, vbo.ptr);

    GLfloat[] vertices = [
          0.0f,  0.5f, 0.0f,
          0.5f, -0.5f, 0.0f,
         -0.5f, -0.5f, 0.0f
    ];

    GLfloat[] colors = [
         1.0f,  0.0f,  0.0f,
         0.0f,  1.0f,  0.0f,
         0.0f,  0.0f,  1.0f
    ];

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, vertices.length * GLfloat.sizeof, vertices.ptr, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, colors.length * GLfloat.sizeof, colors.ptr, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    // Create and compile the vertex shader
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    auto vs = vertexSource.toStringz;
    glShaderSource(vertexShader, 1, &vs, null);
    glCompileShader(vertexShader);

    // Create and compile the fragment shader
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    auto fs = fragmentSource.toStringz;
    glShaderSource(fragmentShader, 1, &fs, null);
    glCompileShader(fragmentShader);

    // Link the vertex and fragment shader into a shader program
    GLuint shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    glUseProgram(shaderProgram);

    // Specify the layout of the vertex data
    posAttrib = glGetAttribLocation(shaderProgram, "position");
    glEnableVertexAttribArray(posAttrib);

    colAttrib = glGetAttribLocation(shaderProgram, "color");
    glEnableVertexAttribArray(colAttrib);
}

void drawTriangle()
{
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);

    // Draw a triangle from the 3 vertices
    glDrawArrays(GL_TRIANGLES, 0, 3);
}
