;; forked from https://opensource.com/article/21/3/hello-world-webassembly
(module
    ;; Imports from JavaScript namespace
    (import  "console"  "log" (func  $log (param  i32  i32))) ;; Import log function
    (import  "js"  "mem" (memory  1)) ;; Import 1 page of memory (64kb)
    
    ;; Data section of our module
    (data (i32.const 0) "Hello, WASM(WAT) World!")
    
    ;; Function declaration: Exported as hello(), no arguments
    (func (export  "hello")
        i32.const 0   ;; pass offset 0 to log
        i32.const 23  ;; pass length 23 to log (strlen of sample text)
        call  $log
    )
)
