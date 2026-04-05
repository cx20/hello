#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
fi

if ! pgrep -x XQuartz >/dev/null && ! pgrep -x X11.bin >/dev/null; then
    open -a /Applications/Utilities/XQuartz.app
fi

for _ in $(seq 1 50); do
    if [ -S /tmp/.X11-unix/X0 ]; then
        break
    fi
    sleep 0.1
done

if [ ! -S /tmp/.X11-unix/X0 ]; then
    echo "XQuartz did not create /tmp/.X11-unix/X0"
    echo "Try launching XQuartz manually and logging in again if this is the first run."
    exit 1
fi

if [ ! -x ./target/release/hello ]; then
    echo "./target/release/hello was not found. Run 'sh build.sh' first."
    exit 1
fi

exec ./target/release/hello
