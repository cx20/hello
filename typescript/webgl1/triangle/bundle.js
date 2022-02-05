/*
 * ATTENTION: The "eval" devtool has been used (maybe by default in mode: "development").
 * This devtool is neither made for production nor for readable output files.
 * It uses "eval()" calls to create a separate source file in the browser devtools.
 * If you are trying to read the output file, select a different devtool (https://webpack.js.org/configuration/devtool/)
 * or disable the default devtool with "devtool: false".
 * If you are looking for production-ready output files, see mode: "production" (https://webpack.js.org/configuration/mode/).
 */
/******/ (() => { // webpackBootstrap
/******/ 	var __webpack_modules__ = ({

/***/ "./index.ts":
/*!******************!*\
  !*** ./index.ts ***!
  \******************/
/***/ (() => {

eval("const main = () => {\r\n    const canvas = document.querySelector('#canvas');\r\n    if (!(canvas instanceof HTMLCanvasElement)) {\r\n        throw new Error('No html canvas element.');\r\n    }\r\n    const gl = canvas.getContext('webgl');\r\n    const resizeCanvas = () => {\r\n        canvas.width = window.innerWidth;\r\n        canvas.height = window.innerHeight;\r\n        gl.viewport(0, 0, canvas.width, canvas.height);\r\n    };\r\n    resizeCanvas();\r\n    gl.clearColor(0, 0, 0, 0);\r\n    gl.clear(gl.COLOR_BUFFER_BIT);\r\n    const initShader = (type, source) => {\r\n        const shader = gl.createShader(gl[type]);\r\n        gl.shaderSource(shader, source);\r\n        gl.compileShader(shader);\r\n        return shader;\r\n    };\r\n    const vertexShader = initShader('VERTEX_SHADER', `\r\n    attribute vec3 position;\r\n    attribute vec4 color;\r\n    varying   vec4 vColor;\r\n    void main() {\r\n        vColor = color;\r\n        gl_Position = vec4(position, 1.0);\r\n    }\r\n    `);\r\n    const fragmentShader = initShader('FRAGMENT_SHADER', `\r\n    precision mediump float;\r\n    varying   vec4 vColor;\r\n\r\n    void main() {\r\n        gl_FragColor = vColor;\r\n    }\r\n    `);\r\n    const program = gl.createProgram();\r\n    gl.attachShader(program, vertexShader);\r\n    gl.attachShader(program, fragmentShader);\r\n    gl.linkProgram(program);\r\n    gl.useProgram(program);\r\n    const positionBuffer = gl.createBuffer();\r\n    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);\r\n    const positions = [\r\n        0.0, 0.5, 0.0,\r\n        -0.5, -0.5, 0.0,\r\n        0.5, -0.5, 0.0 // v2\r\n    ];\r\n    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);\r\n    const positionLoc = gl.getAttribLocation(program, 'position');\r\n    gl.vertexAttribPointer(positionLoc, 3, gl.FLOAT, false, 0, 0);\r\n    gl.enableVertexAttribArray(positionLoc);\r\n    const colorBuffer = gl.createBuffer();\r\n    gl.bindBuffer(gl.ARRAY_BUFFER, colorBuffer);\r\n    const colors = [\r\n        1.0, 0.0, 0.0, 1.0,\r\n        0.0, 1.0, 0.0, 1.0,\r\n        0.0, 0.0, 1.0, 1.0 // v2\r\n    ];\r\n    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(colors), gl.STATIC_DRAW);\r\n    const colorLoc = gl.getAttribLocation(program, 'color');\r\n    gl.vertexAttribPointer(colorLoc, 4, gl.FLOAT, false, 0, 0);\r\n    gl.enableVertexAttribArray(colorLoc);\r\n    gl.drawArrays(gl.TRIANGLES, 0, 3);\r\n};\r\nwindow.onload = main;\r\n\n\n//# sourceURL=webpack://ts-webpack/./index.ts?");

/***/ })

/******/ 	});
/************************************************************************/
/******/ 	
/******/ 	// startup
/******/ 	// Load entry module and return exports
/******/ 	// This entry module can't be inlined because the eval devtool is used.
/******/ 	var __webpack_exports__ = {};
/******/ 	__webpack_modules__["./index.ts"]();
/******/ 	
/******/ })()
;