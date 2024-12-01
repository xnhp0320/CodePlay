cmake_minimum_required(VERSION 3.26)
project(fs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_BINARY_DIR "../")
set(CMAKE_SOURCE_DIR "../")

add_executable(fs fs.cc)
