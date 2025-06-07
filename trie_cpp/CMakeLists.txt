cmake_minimum_required(VERSION 3.26)
set(CMAKE_CXX_COMPILER "/usr/local/opt/llvm/bin/clang++")
project(fmt)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)


include(FetchContent)

FetchContent_Declare(
  fmt
  GIT_REPOSITORY https://github.com/fmtlib/fmt
  GIT_TAG        e69e5f977d458f2650bb346dadf2ad30c5320281) # 10.2.1
FetchContent_MakeAvailable(fmt)


FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/52eb8108c5bdec04579160ae17225d66034bd723.zip
)
# For Windows: Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

enable_testing()
add_executable(trie_test trie_test.cc)
target_compile_options(trie_test PRIVATE -fsanitize=address -fno-omit-frame-pointer)
target_link_options(trie_test PRIVATE -fsanitize=address)
target_link_libraries(trie_test fmt::fmt GTest::gtest_main)

include(GoogleTest)
gtest_discover_tests(trie_test)

