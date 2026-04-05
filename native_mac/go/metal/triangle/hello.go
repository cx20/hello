// Hello, World! in Go + Metal (macOS)
// Uses CGo to call the metal_wrapper C API backed by Objective-C++.
// Build: sh build.sh

package main

/*
#include "metal_wrapper.h"
#include <unistd.h>
*/
import "C"
import (
	"fmt"
	"os"
)

func main() {
	ctx := C.metal_create()
	if ctx == nil {
		fmt.Fprintln(os.Stderr, "Failed to create Metal context")
		os.Exit(1)
	}
	fmt.Println("Metal triangle created. Close window to exit.")
	for C.metal_is_running(ctx) {
		C.metal_render(ctx)
		C.usleep(16667)
	}
	C.metal_destroy(ctx)
}
