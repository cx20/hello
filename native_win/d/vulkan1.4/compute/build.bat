glslc.exe hello.vert -o hello_vert.spv
glslc.exe hello.frag -o hello_frag.spv
glslc.exe hello.comp -o hello_comp.spv

dmd hello.d gdi32.lib user32.lib
