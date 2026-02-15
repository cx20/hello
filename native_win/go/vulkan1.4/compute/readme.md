compile:
```
go build -ldflags="-H windowsgui" hello.go
```

Building with shader compilation:
```
glslc.exe hello.vert -o hello_vert.spv
glslc.exe hello.frag -o hello_frag.spv
glslc.exe hello.comp -o hello_comp.spv
go build -ldflags="-H windowsgui" hello.go
```

Result:
An animated harmonograph pattern is displayed, computed in real-time by a compute shader
and rendered with a custom-colored trail effect.

Note: This is a Vulkan 1.4 compute shader sample that calculates harmonograph curves 
using parametric equations and displays them as colored point trails on the screen.

