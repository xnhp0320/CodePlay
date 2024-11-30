#include <boost/intrusive/list.hpp>
#include <iostream>


template <typename ...Options>
using list_base_hook = boost::intrusive::list_base_hook<Options...>;

template <typename T, typename ...Options>
using list = boost::intrusive::list<T, Options...>;

template <typename Hook>
using base_hook = boost::intrusive::base_hook<Hook>;

class Foo : public list_base_hook<> {
public:
    int i;
    Foo() : i(0) {}
    Foo(int x) : i(x) {}
};

using FooList = list<Foo, base_hook<list_base_hook<>>>; 

int main() {
    Foo f{1};
    Foo e{2};
    FooList  list;
    list.push_back(f);
    list.push_back(e);

    for (auto it = list.begin(); it != list.end(); ++it) {
        std::cout << it->i << std::endl;
    }
}
