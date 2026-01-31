preparation:
```
cd github
git clone https://github.com/microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat

SET VCPKG_ROOT=C:\github\vcpkg
SET PATH=%VCPKG_ROOT%;%PATH%

"C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Auxiliary\Build\vcvarsall.bat" x64
cd C:\github\hello\cpp\webgpu_dawn\triangle
vcpkg install

```


compile:
```
mkdir build
cd build
cmake .. -G "Visual Studio 18 2026" -A x64 -DCMAKE_TOOLCHAIN_FILE=C:/github/vcpkg/scripts/buildsystems/vcpkg.cmake
cmake --build . --config Release

```
Result:
```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
+------------------------------------------+
|                                          |
|                   / \                    |
|                 /     \                  |
|               /         \                |
|             /             \              |
|           /                 \            |
|         /                     \          |
|       /                         \        |
|     /                             \      |
|    - - - - - - - - - - - - - - - - -     |
+------------------------------------------+
```