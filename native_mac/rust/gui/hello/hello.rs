extern "C" {
    fn createCocoaWindow();
}

fn main() {
    unsafe {
        createCocoaWindow();
    }
}
