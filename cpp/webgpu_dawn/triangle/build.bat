mkdir build
cd build
cmake .. -G "Visual Studio 18 2026" -A x64 -DCMAKE_TOOLCHAIN_FILE=C:/github/vcpkg/scripts/buildsystems/vcpkg.cmake
cmake --build . --config Release
