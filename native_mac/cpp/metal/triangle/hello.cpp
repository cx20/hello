#include <iostream>
#include <unistd.h>
#include "metal_wrapper.h"

int main() {
    MetalContext ctx = metal_create();
    if (!ctx) {
        std::cerr << "Failed to create Metal context" << std::endl;
        return 1;
    }
    std::cout << "Metal triangle created. Close window to exit." << std::endl;
    while (metal_is_running(ctx)) {
        metal_render(ctx);
        usleep(16667);
    }
    metal_destroy(ctx);
    return 0;
}
