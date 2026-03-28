use std::process::Command;

fn compile_shader(src: &str, dst: &str) {
    let status = Command::new("glslangValidator")
        .args(["-V", src, "-o", dst])
        .status()
        .expect("failed to execute glslangValidator");
    assert!(status.success(), "Failed to compile shader: {}", src);
}

fn main() {
    println!("cargo:rerun-if-changed=hello.vert");
    println!("cargo:rerun-if-changed=hello.frag");
    compile_shader("hello.vert", "hello.vert.spv");
    compile_shader("hello.frag", "hello.frag.spv");
}
