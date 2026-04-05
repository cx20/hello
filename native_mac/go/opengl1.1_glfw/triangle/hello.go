package main

/*
#cgo CFLAGS: -DGL_SILENCE_DEPRECATION
void runSample(void);
*/
import "C"

func main() {
C.runSample()
}
