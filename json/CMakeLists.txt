cmake_minimum_required(VERSION 3.26)
#cmake_policy(SET CMP0167 OLD)
find_package(Boost 1.87)
set(CMAKE_CXX_COMPILER "/usr/local/Cellar/llvm/19.1.7_1/bin/clang++")
set(CMAKE_C_COMPILER "/usr/local/Cellar/llvm/19.1.7_1/bin/clang")

project(json)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_BINARY_DIR "../")
set(CMAKE_SOURCE_DIR "../")

if (Boost_FOUND)
    include_directories(${Boost_INCLUDE_DIRS})
    add_executable(json dump3.cc)
endif()
