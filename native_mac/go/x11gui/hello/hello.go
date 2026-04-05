package main

/*
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <string.h>
#include <stdlib.h>

static long xclient_data_l(XClientMessageEvent *e, int i) {
	return e->data.l[i];
}
*/
import "C"
import "unsafe"

func main() {
	helloTitle := C.CString("Hello, World!")
	defer C.free(unsafe.Pointer(helloTitle))
	helloMessage := C.CString("Hello, X11 GUI(Go) World!")
	defer C.free(unsafe.Pointer(helloMessage))

	display := C.XOpenDisplay(nil)
	if display == nil {
		panic("Failed to open X display. Start XQuartz and set DISPLAY.")
	}
	screen := C.XDefaultScreen(display)

	foreground := C.XBlackPixel(display, screen)
	background := C.XWhitePixel(display, screen)

	var hint C.XSizeHints
	hint.x = 0
	hint.y = 0
	hint.width = 640
	hint.height = 480
	hint.flags = C.PPosition | C.PSize

	window := C.XCreateSimpleWindow(
		display, C.XDefaultRootWindow(display),
		hint.x, hint.y,
		C.uint(hint.width), C.uint(hint.height),
		5, foreground, background)

	wmDeleteCStr := C.CString("WM_DELETE_WINDOW")
	defer C.free(unsafe.Pointer(wmDeleteCStr))
	atomWmDeleteWindow := C.XInternAtom(display, wmDeleteCStr, 0)

	C.XSetStandardProperties(display, window, helloTitle, helloTitle,
		C.None, nil, 0, &hint)
	C.XSetWMProtocols(display, window, &atomWmDeleteWindow, 1)

	gc := C.XCreateGC(display, C.Drawable(window), 0, nil)
	C.XSetBackground(display, gc, background)
	C.XSetForeground(display, gc, foreground)

	C.XSelectInput(display, window, C.ButtonPressMask|C.KeyPressMask|C.ExposureMask)
	C.XMapRaised(display, window)

	done := false
	for !done {
		var ev C.XEvent
		C.XNextEvent(display, &ev)
		evType := *(*C.int)(unsafe.Pointer(&ev))
		switch evType {
		case C.Expose:
			C.XDrawImageString(display, C.Drawable(window), gc,
				5, 20, helloMessage, C.int(C.strlen(helloMessage)))
		case C.ClientMessage:
			xclient := (*C.XClientMessageEvent)(unsafe.Pointer(&ev))
			if C.xclient_data_l(xclient, 0) == C.long(atomWmDeleteWindow) {
				done = true
			}
		case C.DestroyNotify:
			done = true
		}
	}

	C.XFreeGC(display, gc)
	C.XDestroyWindow(display, window)
	C.XCloseDisplay(display)
}
