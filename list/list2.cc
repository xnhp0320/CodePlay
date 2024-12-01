#include <IntrusiveList.h>
#include <iostream>

class Foo {
public:
    IntrusiveListHook listHook;
    int i;
    Foo(int _i) : i(_i) {}
};

using FooList = IntrusiveList<Foo, &Foo::listHook>;

class Bar {
public:
    IntrusiveListHook hook1;
    IntrusiveListHook hook2;
    int i;
    Bar(int _i) : i(_i) {}
};

using Bar1List = IntrusiveList<Bar, &Bar::hook1>;
using Bar2List = IntrusiveList<Bar, &Bar::hook2>;


int main() {
    FooList list;
    {
        Foo f{1};
        list.push_back(f);
        f.listHook.unlink();
    }

    Bar1List bar1list;
    Bar2List bar2list;
    {
        Bar b{1};
        bar1list.push_back(b);
        bar2list.push_back(b);

        for (auto it = bar1list.begin();
                it != bar1list.end();
                ++it) {
            std::cout << it->i << std::endl;
        }

        b.hook1.unlink();
    }


    return 0;
}
