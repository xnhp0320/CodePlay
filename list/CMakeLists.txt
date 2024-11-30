cmake_minimum_required(VERSION 3.26)
find_package(Boost 1.86)
project(list)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

if (Boost_FOUND)
    include_directories(${Boost_INCLUDE_DIRS})
    add_executable(list list.cc)
endif()
