SET VCPKG_ROOT=C:\github\vcpkg
SET PATH=%VCPKG_ROOT%;%PATH%

"C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Auxiliary\Build\vcvarsall.bat" x64
cd C:\github\hello\cpp\webgpu_dawn_glfw\triangle
vcpkg install
