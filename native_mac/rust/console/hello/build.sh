#!/bin/sh

if ! command -v rustc >/dev/null 2>&1; then
	echo "Rust compiler was not found."
	echo "Install Rust with:"
	echo "brew install rust"
	exit 1
fi

rustc hello.rs -o hello