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

class FooM: public list_base_hook<tag<tag1>, boost::intrusive::link_mode<boost::intrusive::auto_unlink>>,
            public list_base_hook<tag<tag2>, boost::intrusive::link_mode<boost::intrusive::auto_unlink>> {
public:
    int i;
    FooM(int _i) : i(_i) {}
};

using Foo1List = list<FooM, base_hook<Tag1Hook>, boost::intrusive::constant_time_size<false>>;
using Foo2List = list<FooM, base_hook<Tag2Hook>, boost::intrusive::constant_time_size<false>>;

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

    Foo1List  foo1_list;
    Foo2List  foo2_list;
    {
        FooM f{1};
        foo1_list.push_back(f);
        foo2_list.push_back(f);

        for (auto it = foo1_list.begin(); it != foo1_list.end(); ++it) {
            std::cout << it->i << std::endl;
        }

        (&f)->list_base_hook<tag<tag1>, boost::intrusive::link_mode<boost::intrusive::auto_unlink>>::unlink();
        (&f)->list_base_hook<tag<tag2>, boost::intrusive::link_mode<boost::intrusive::auto_unlink>>::unlink();
    }

    std::cout << "foo1_list size is " << foo1_list.size() << std::endl;
    std::cout << "foo2_list size is " << foo2_list.size() << std::endl;


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


//Usage: only use auto-unlink mode, however in this mode, you cannot use constant_time_size
//
//In the other mode, you cannnot remove a element without having the ref to its list container.
//e.g. you cannot do "ovs_list_remove(&node)" in other mode. The unlink() method only exist
//in auto_unlink mode.
//
//
//check out folly: https://github.com/facebook/folly/blob/main/folly/container/IntrusiveList.h
//this is basically a wrap on boost::intrusive::list.
//
