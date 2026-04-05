glslangValidator -V hello.vert -o hello_vert.spv
glslangValidator -V hello.frag -o hello_frag.spv
fpc -Px86_64 hello.pas -k"-lvulkan -lglfw"
