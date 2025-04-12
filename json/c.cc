#include <vector>
#include <iostream>


int main() {
    std::vector<int> x = {1,2,3};
    std::vector<int> y(x);
    for (auto v : y) {
        std::cout << v << std::endl;
    }
}
