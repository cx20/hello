import core.stdc.stdio;
import core.sys.posix.unistd : usleep;

extern(C):
alias MetalContext = void*;
MetalContext metal_create();
void metal_render(MetalContext ctx);
bool metal_is_running(MetalContext ctx);
void metal_destroy(MetalContext ctx);

void main() {
    MetalContext ctx = metal_create();
    if (!ctx) {
        fprintf(stderr, "Failed to create Metal context\n");
        return;
    }
    printf("Metal triangle created. Close window to exit.\n");
    while (metal_is_running(ctx)) {
        metal_render(ctx);
        usleep(16667);
    }
    metal_destroy(ctx);
}
