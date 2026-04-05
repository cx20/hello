fn main() {
    cc::Build::new()
        .compiler("clang++")
        .file("metal_wrapper.mm")
        .flag("-fms-extensions")
        .flag("-fblocks")
        .compile("metal_wrapper");

    println!("cargo:rustc-link-lib=framework=Cocoa");
    println!("cargo:rustc-link-lib=framework=Metal");
    println!("cargo:rustc-link-lib=framework=MetalKit");
    println!("cargo:rustc-link-lib=framework=Foundation");
}
