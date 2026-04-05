extern "C" {
    fn runSample();
}

fn main() {
    unsafe {
        runSample();
    }
}
