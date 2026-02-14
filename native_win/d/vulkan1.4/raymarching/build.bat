glslc.exe hello.vert -o hello_vert.spv
glslc.exe hello.frag -o hello_frag.spv

dmd hello.d gdi32.lib user32.lib
