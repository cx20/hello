use std::ffi::CString;
use std::mem;
use std::ptr;
use x11::xlib;

fn main() {
    unsafe {
        let display = xlib::XOpenDisplay(ptr::null());
        if display.is_null() {
            eprintln!("Failed to open X display. Start XQuartz and set DISPLAY.");
            return;
        }

        let screen = xlib::XDefaultScreen(display);
        let root = xlib::XRootWindow(display, screen);
        let foreground = xlib::XBlackPixel(display, screen);
        let background = xlib::XWhitePixel(display, screen);

        let window = xlib::XCreateSimpleWindow(
            display, root,
            0, 0, 640, 480,
            5, foreground, background,
        );

        let title = CString::new("Hello, World!").unwrap();
        xlib::XStoreName(display, window, title.as_ptr());

        let atom_name = CString::new("WM_DELETE_WINDOW").unwrap();
        let wm_delete_window = xlib::XInternAtom(display, atom_name.as_ptr(), xlib::False);
        let mut protocols = [wm_delete_window];
        xlib::XSetWMProtocols(display, window, protocols.as_mut_ptr(), 1);

        let gc = xlib::XCreateGC(display, window, 0, ptr::null_mut());
        xlib::XSetBackground(display, gc, background);
        xlib::XSetForeground(display, gc, foreground);

        xlib::XSelectInput(display, window,
            xlib::ButtonPressMask | xlib::KeyPressMask | xlib::ExposureMask);
        xlib::XMapRaised(display, window);

        let message = CString::new("Hello, X11 GUI(Rust) World!").unwrap();
        let message_len = message.as_bytes().len() as i32;

        let mut event: xlib::XEvent = mem::zeroed();
        loop {
            xlib::XNextEvent(display, &mut event);
            match event.type_ {
                xlib::Expose => {
                    xlib::XDrawImageString(
                        display, window, gc,
                        5, 20, message.as_ptr(), message_len,
                    );
                }
                xlib::ClientMessage => {
                    let xclient = event.client_message;
                    if xclient.data.as_longs()[0] as u64 == wm_delete_window {
                        break;
                    }
                }
                xlib::DestroyNotify => break,
                _ => {}
            }
        }

        xlib::XFreeGC(display, gc);
        xlib::XDestroyWindow(display, window);
        xlib::XCloseDisplay(display);
    }
}
