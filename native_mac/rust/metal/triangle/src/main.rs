// Hello, World! in Rust + Metal (macOS)
// Calls the metal_wrapper C API (backed by Objective-C++) via FFI.
// Build: sh build.sh

use std::ffi::c_void;
use std::thread;
use std::time::Duration;

type MetalContext = *mut c_void;

extern "C" {
    fn metal_create() -> MetalContext;
    fn metal_render(ctx: MetalContext);
    fn metal_is_running(ctx: MetalContext) -> bool;
    fn metal_destroy(ctx: MetalContext);
}

fn main() {
    let ctx = unsafe { metal_create() };
    if ctx.is_null() {
        eprintln!("Failed to create Metal context");
        std::process::exit(1);
    }
    println!("Metal triangle created. Close window to exit.");
    while unsafe { metal_is_running(ctx) } {
        unsafe { metal_render(ctx) };
        thread::sleep(Duration::from_micros(16667));
    }
    unsafe { metal_destroy(ctx) };
}
