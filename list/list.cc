#include <boost/intrusive/list.hpp>
#include <iostream>


template <typename ...Options>
using list_base_hook = boost::intrusive::list_base_hook<Options...>;

template <typename T, typename ...Options>
using list = boost::intrusive::list<T, Options...>;

template <typename Hook>
using base_hook = boost::intrusive::base_hook<Hook>;

template <typename T>
using tag = boost::intrusive::tag<T>;

struct tag1 {};
struct tag2 {};

class Foo : public list_base_hook<boost::intrusive::link_mode<boost::intrusive::auto_unlink>> {
public:
    int i;
    Foo() : i(0) {}
    Foo(int x) : i(x) {}
};


using Tag1Hook = list_base_hook<tag<tag1>>;
using Tag2Hook = list_base_hook<tag<tag2>>;

class Bar : public Tag1Hook, public Tag2Hook {
public:
    int i;
    Bar(int x) : i(x) {}
};

using FooList = list<Foo, boost::intrusive::constant_time_size<false>>;


using Bar1List = list<Bar, base_hook<Tag1Hook>>;
using Bar2List = list<Bar, base_hook<Tag2Hook>>;

int main() {

    FooList  list;
    {
        Foo f{1};
        Foo e{2};
        list.push_back(f);
        list.push_back(e);

        for (auto it = list.begin(); it != list.end(); ++it) {
            std::cout << it->i << std::endl;
        }
        f.unlink();
    }

    std::cout << "list size is " << list.size() << std::endl;

    Bar1List bar1_list;
    Bar2List bar2_list;

    {
        Bar bar1{1};
        bar1_list.push_back(bar1);
        bar2_list.push_back(bar1);

        for (auto it = bar1_list.begin(); it != bar1_list.end(); ++it) {
            std::cout << it->i << std::endl;
        }

        for (auto it = bar2_list.begin(); it != bar2_list.end(); ++it) {
            std::cout << it->i << std::endl;
        }

        bar1_list.erase(Bar1List::s_iterator_to(bar1));
        bar2_list.erase(Bar2List::s_iterator_to(bar1));
    }

    std::cout << "list size is " << bar1_list.size() << std::endl;
}
