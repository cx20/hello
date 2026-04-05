package main

/*
#cgo CFLAGS: -DGL_SILENCE_DEPRECATION
#cgo LDFLAGS: -framework GLUT -framework OpenGL
void runSample(void);
*/
import "C"

func main() {
C.runSample()
}
