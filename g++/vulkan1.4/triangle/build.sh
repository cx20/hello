glslangValidator -V hello.vert -o hello_vert.spv
glslangValidator -V hello.frag -o hello_frag.spv
g++ -o hello hello.cpp \
  `pkg-config --cflags vulkan` \
  `pkg-config --libs vulkan` \
  -lvulkan -lglfw
