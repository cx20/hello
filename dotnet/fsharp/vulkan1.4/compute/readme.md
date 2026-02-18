compile:
```
fsc Hello.fs
```
Result:
```
==========================================
Vulkan 1.4 Harmonograph (F#)
==========================================

Compiling GLSL shaders with shaderc...

[1/3] Compiling compute shader...
      Compute shader: XXXX bytes (SPIR-V)
[2/3] Compiling vertex shader...
      Vertex shader: XXXX bytes (SPIR-V)
[3/3] Compiling fragment shader...
      Fragment shader: XXXX bytes (SPIR-V)

Shader Compilation: SUCCESS

Harmonograph Features:
  - Mathematical harmonograph using 4 damped sinusoids
  - Compute shader calculates 500,000 path points
  - Storage buffers store positions and colors
  - HSV color mapping for smooth color animation
  - Line strip rendering of the computed path
```
