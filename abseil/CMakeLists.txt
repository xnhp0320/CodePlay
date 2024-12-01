cmake_minimum_required(VERSION 3.26)
project(abseil)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_BUILD_TYPE ReleaseWithDebug)


set(CMAKE_PREFIX_PATH "abseil-cpp/install")
find_package(absl REQUIRED)

add_executable(abseil abseil.cc)
target_link_libraries(abseil absl::log absl::log_initialize)
