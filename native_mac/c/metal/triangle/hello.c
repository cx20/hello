#include <stdio.h>
#include <unistd.h>
#include "metal_wrapper.h"

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    
    // Create Metal context
    MetalContext ctx = metal_create();
    
    if (!ctx) {
        fprintf(stderr, "Failed to create Metal context\n");
        return 1;
    }
    
    fprintf(stdout, "Metal triangle created. Close window to exit.\n");
    
    // Wait for completion
    while (metal_is_running(ctx)) {
        metal_render(ctx);
        usleep(16667); // ~60 FPS
    }
    
    // Cleanup
    metal_destroy(ctx);
    
    return 0;
}
