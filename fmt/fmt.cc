#include <fmt/format.h>


int main() {
    std::string s = fmt::format("Hello World {}\n", 42);
    fmt::print("{}\n", s);

    return 0;
}
