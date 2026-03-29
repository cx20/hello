# Metal Triangle in C

This sample demonstrates that Metal can technically be called from C code using Objective-C++ wrappers.

**Note:** This is a technical proof-of-concept showing that Metal works with C. However, Metal is designed for Objective-C/Swift and requires significant bridging code when used from C.

## Build

```bash
sh build.sh
```

## Run

```bash
./hello
```

## Architecture

This implementation uses:
1. **metal_wrapper.h**: C interface (clean API)
2. **metal_wrapper.mm**: Objective-C++ implementation (handles Metal complexity)
3. **hello.c**: Pure C main program

The Objective-C++ wrapper bridges the gap between C's procedural style and Metal's Objective-C object-oriented design.

## Key Points

- Metal API is fundamentally Objective-C based
- C code cannot directly use Metal's object syntax
- Objective-C++ wrapper translates between C function calls and Metal objects
- Opaque pointers (void*) carry Metal context
- Memory management is simplified through the wrapper

## Performance Note

While this technically works, the overhead of bridging between C and Objective-C++ adds complexity:
- More code to maintain
- Added function call overhead
- Loss of type safety

**Recommendation:** For production Metal applications, use Swift or Objective-C directly.
