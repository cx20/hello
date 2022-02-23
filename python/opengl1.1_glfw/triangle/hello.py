from OpenGL.GL import *
import glfw
import numpy as np

def main():
    glfw.init()
    
    window = glfw.create_window(640, 480, 'Hello, World!', None, None)
    glfw.make_context_current(window)
    
    while not glfw.window_should_close(window):
        colors =  np.array([
            [ 1.0, 0.0, 0.0],
            [ 0.0, 1.0, 0.0],
            [-0.0, 0.0, 1.0]
        ], dtype=np.float32)
        
        vertices =  np.array([
            [ 0.0, 0.5],
            [ 0.5,-0.5],
            [-0.5,-0.5]
        ], dtype=np.float32)
        
        glEnableClientState(GL_COLOR_ARRAY)
        glEnableClientState(GL_VERTEX_ARRAY)
        
        glColorPointer(3, GL_FLOAT, 0, colors)
        glVertexPointer(2, GL_FLOAT, 0, vertices)
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 3)
        
        glfw.swap_buffers(window)
        glfw.poll_events()
    
    glfw.destroy_window(window)
    glfw.terminate()

if __name__ == "__main__":
    main()
