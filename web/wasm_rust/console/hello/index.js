import init, * as wasm from './hello.js';
async function run() {
	await init();
	wasm.hello();
}
run();
