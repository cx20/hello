package main

/*
#cgo LDFLAGS: -lGL -lglut
void runSample(void);
*/
import "C"

func main() {
C.runSample()
}
