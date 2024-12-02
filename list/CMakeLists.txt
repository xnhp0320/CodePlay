cmake_minimum_required(VERSION 3.26)
cmake_policy(SET CMP0167 OLD)
find_package(Boost 1.86)
set(CMAKE_CXX_COMPILER "clang++")
set(CMAKE_C_COMPILER "clang")

project(list)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_BINARY_DIR "../")
set(CMAKE_SOURCE_DIR "../")

if (Boost_FOUND)
    include_directories(${Boost_INCLUDE_DIRS})
    add_executable(list list.cc)
    add_executable(list2 list2.cc)
    target_include_directories(list2 PRIVATE ".")
endif()
