cmake_minimum_required(VERSION 3.26)
project(abseil)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_BUILD_TYPE Debug)


add_subdirectory(abseil-cpp)
add_executable(abseil abseil.cc)
target_link_libraries(abseil absl::log absl::log_initialize absl::strings)
