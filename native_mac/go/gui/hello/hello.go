package main

/*
#cgo LDFLAGS: -framework Cocoa
void createCocoaWindow(void);
*/
import "C"

func main() {
	C.createCocoaWindow()
}
