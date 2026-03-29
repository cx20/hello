#!/bin/bash
set -e

if command -v dmd >/dev/null 2>&1; then
	dmd -ofhello hello.d
elif command -v ldc2 >/dev/null 2>&1; then
	ldc2 -of=hello hello.d
elif command -v gdc >/dev/null 2>&1; then
	gdc -o hello hello.d
else
	echo "No D compiler found (dmd/ldc2/gdc)."
	echo "Install one of the following:"
	echo "  brew install dmd"
	echo "  brew install ldc"
	echo "  brew install gdc"
	exit 1
fi