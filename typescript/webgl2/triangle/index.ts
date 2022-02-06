const main = () => {
    const canvas = document.querySelector('#canvas');
    if (!(canvas instanceof HTMLCanvasElement)) {
        throw new Error('No html canvas element.');
    }
    const gl = canvas.getContext('webgl2');

    const resizeCanvas = () => {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
        gl.viewport(0, 0, canvas.width, canvas.height);
    }

    resizeCanvas();

    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    const initShader = (type: 'VERTEX_SHADER' | 'FRAGMENT_SHADER', source: string) => {
        const shader = gl.createShader(gl[type]);
        gl.shaderSource(shader, source);
        gl.compileShader(shader);
        return shader;
    }

    const vertexShader = initShader('VERTEX_SHADER', `#version 300 es
    in  vec3 position;
    in  vec4 color;
    out vec4 vColor;

    void main() {
        vColor = color;
        gl_Position = vec4(position, 1.0);
    }
    `);

    const fragmentShader = initShader('FRAGMENT_SHADER', `#version 300 es
    precision mediump float;

    in vec4 vColor;
    out vec4 fragColor;

    void main() {
        fragColor = vColor;
    }
    `);

    const program = gl.createProgram();

    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);
    gl.useProgram(program);

    const positionBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    const positions = [
         0.0,  0.5, 0.0, // v0
        -0.5, -0.5, 0.0, // v1
         0.5, -0.5, 0.0  // v2
    ];
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);

    const positionLoc = gl.getAttribLocation(program, 'position');
    gl.vertexAttribPointer(positionLoc, 3, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(positionLoc);

    const colorBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, colorBuffer);
    const colors = [ 
         1.0, 0.0, 0.0, 1.0, // v0
         0.0, 1.0, 0.0, 1.0, // v1
         0.0, 0.0, 1.0, 1.0  // v2
    ];
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(colors), gl.STATIC_DRAW);

    const colorLoc = gl.getAttribLocation(program, 'color');
    gl.vertexAttribPointer(colorLoc, 4, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(colorLoc);

    gl.drawArrays(gl.TRIANGLES, 0, 3);
}

window.onload = main;