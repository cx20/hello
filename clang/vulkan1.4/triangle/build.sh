glslangValidator -V hello.vert -o hello_vert.spv
glslangValidator -V hello.frag -o hello_frag.spv
clang -o hello hello.c \
  `pkg-config --cflags vulkan` \
  `pkg-config --libs vulkan` \
  -lvulkan -lglfw
