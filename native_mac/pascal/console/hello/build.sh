#!/bin/bash
set -e

if ! command -v fpc >/dev/null 2>&1; then
	echo "Free Pascal compiler was not found."
	echo "Install Free Pascal with:"
	echo "  brew install fpc"
	exit 1
fi

fpc hello.pas
