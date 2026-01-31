use wasm_bindgen::prelude::*;
use web_sys::console::log_1;

fn log(s: &String) {
    log_1(&JsValue::from(s));
}

#[wasm_bindgen]
pub fn hello() {
    log(&"Hello, WASM(Rust) World!".to_string());
}
