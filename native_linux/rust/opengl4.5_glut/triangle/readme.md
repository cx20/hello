## How to build

```sh
gcc -c hello_glut.c -o hello_glut.o
ar rcs libhello_glut.a hello_glut.o
rustc hello.rs -o hello -L . -l static=hello_glut -C link-arg=-lGL -C link-arg=-lglut
./hello
```
