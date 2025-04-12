
#include <iostream>

class A {
public:
    A (size_t a) {}
};

class B : A {
public:
    //B (size_t a) {} ---> not working.
    B (size_t a) : A(a) {}
};

int main() {
    B b(1);
};
    
