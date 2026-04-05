#ifndef METAL_WRAPPER_H
#define METAL_WRAPPER_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer to Metal context
typedef void* MetalContext;

// Create Metal context and window
MetalContext metal_create();

// Render one frame
void metal_render(MetalContext ctx);

// Check if window is still open
bool metal_is_running(MetalContext ctx);

// Cleanup
void metal_destroy(MetalContext ctx);

#ifdef __cplusplus
}
#endif

#endif // METAL_WRAPPER_H
