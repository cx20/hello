#!/bin/bash
set -e

if ! command -v go >/dev/null 2>&1; then
    echo "Go compiler was not found."
    echo "Install Go with: brew install go"
    exit 1
fi

GLFW_PREFIX=$(brew --prefix glfw 2>/dev/null)
if [ -z "$GLFW_PREFIX" ]; then
    echo "glfw is required. Install with: brew install glfw"
    exit 1
fi

CGO_CFLAGS="-DGL_SILENCE_DEPRECATION -I${GLFW_PREFIX}/include" \
CGO_LDFLAGS="-L${GLFW_PREFIX}/lib -lglfw -framework OpenGL -framework Cocoa -framework IOKit -framework CoreVideo" \
GO111MODULE=off CGO_ENABLED=1 go build -o hello .
