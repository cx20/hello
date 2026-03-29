FREEGLUT_PREFIX=$(brew --prefix freeglut 2>/dev/null)
if [ -z "$FREEGLUT_PREFIX" ]; then
	echo "freeglut is required. Install with: brew install freeglut"
	exit 1
fi

if [ ! -f "$FREEGLUT_PREFIX/include/GL/freeglut.h" ]; then
	echo "freeglut headers were not found in: $FREEGLUT_PREFIX/include/GL"
	echo "Try reinstalling: brew reinstall freeglut"
	exit 1
fi

cc -DGL_SILENCE_DEPRECATION -o hello hello.c -I"$FREEGLUT_PREFIX/include" -L"$FREEGLUT_PREFIX/lib" -lglut -framework OpenGL
