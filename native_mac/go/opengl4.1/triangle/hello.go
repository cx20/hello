package main

/*
#cgo CFLAGS: -DGL_SILENCE_DEPRECATION
#cgo LDFLAGS: -framework Cocoa -framework OpenGL
void runOpenGLSample(void);
*/
import "C"

func main() {
	C.runOpenGLSample()
}
