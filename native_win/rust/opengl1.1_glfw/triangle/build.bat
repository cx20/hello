SET LIB=C:\Libraries\glfw-3.3.6.bin.WIN64\lib-vc2022;%LIB%
cargo build --release
copy target\release\hello.exe
