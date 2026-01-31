let memory = new WebAssembly.Memory({
    initial: 1
});

function consoleLogString(offset, length) {
    let bytes = new Uint8Array(memory.buffer, offset, length);
    let string = new TextDecoder('utf8').decode(bytes);
    console.log(string);
};

let importObject = {
    console: {
        log: consoleLogString
    },
    js: {
        mem: memory
    }
};

WebAssembly.instantiateStreaming(fetch('hello.wasm'), importObject)
    .then(obj => {
        obj.instance.exports.hello();
    });
