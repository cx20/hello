cmake_minimum_required(VERSION 3.20)
project(hello)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Dawn CONFIG REQUIRED)

get_property(_targets DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY IMPORTED_TARGETS)
message(STATUS "Available imported targets: ${_targets}")

add_executable(${PROJECT_NAME} hello.cpp)

target_link_libraries(${PROJECT_NAME} PRIVATE
    dawn::webgpu_dawn
)

if(WIN32)
    file(GLOB D3DCOMPILER_DLL 
        "C:/Windows/system32/d3dcompiler_47.dll"
    )
    if(D3DCOMPILER_DLL)
        list(GET D3DCOMPILER_DLL 0 D3DCOMPILER_DLL_PATH)
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${D3DCOMPILER_DLL_PATH}"
                $<TARGET_FILE_DIR:${PROJECT_NAME}>
        )
    endif()
endif()
