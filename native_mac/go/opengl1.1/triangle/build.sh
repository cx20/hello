#!/bin/bash
set -e

if ! command -v go >/dev/null 2>&1; then
	echo "Go compiler was not found."
	echo "Install Go with:"
	echo "  brew install go"
	exit 1
fi

GO111MODULE=off CGO_ENABLED=1 go build -o hello .
