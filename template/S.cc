#include <iostream>

class S {
public:
    S() {std::cout <<"default" << std::endl;}
    S(S&&) { std::cout << "move" << std::endl;}
    S(const S &) { std::cout << "ctor" << std::endl;}
    S(int) {std::cout << "int" << std::endl;}
    S& operator=(S&& other) {std::cout << "move = " << std::endl; return *this;}
    S& operator=(const S& other) {std::cout << "copy = " << std::endl; return *this;}

    template<typename T>
    S(std::initializer_list<T> l) { *this = std::move(*l.begin()); }
};


int main() {
    S s = S(1);
    S s2 = { S(1) };
}

