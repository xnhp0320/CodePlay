#include <string>
#include <vector>
#include <list>
#include <array>
#include <unordered_map>
#include <iostream>
#include <sstream>

template <typename Iter>
std::string dumpList(const Iter &begin, const Iter &end) {
    std::stringstream ss;
    ss << "[";

    for (auto iter = begin; iter != end; ++iter) {
        ss << *iter << ",";
    }

    ss.seekp(-1, ss.cur);
    ss << "]";
    return ss.str();
}


template<typename T>
std::string dumpElem(const T& v) {
    std::stringstream ss;
    ss << v;
    return ss.str();
}

template<>
std::string dumpElem<std::string>(const std::string& v) {
    std::stringstream ss;
    ss << "\"" << v << "\"";
    return ss.str();
}


template <typename Iter>
std::string dumpMap(const Iter &begin, const Iter &end) {

    std::stringstream ss;
    ss << "{\n";

    for (auto iter = begin; iter != end; ++iter) {
        ss << dumpElem(iter->first) << ":" << dumpElem(iter->second) << ",\n";
    }

    ss.seekp(-1, ss.cur);
    ss.seekp(-1, ss.cur);
    ss << "\n}\n";
    return ss.str();
}

template <typename T>
class slice {
public:
    template <std::size_t N>
    static slice from(const T (&array)[N]) {
        return slice(array, N);
    }

    slice(const T* v, std::size_t N) : _v(v), _len(N) {}

    class iterator {
    public:
        iterator(const T* p) : _ptr(p) {};
        iterator(const iterator& other) : _ptr(other._ptr) {};
        
        iterator operator++ () {
            _ptr ++;
            return *this;
        }

        iterator operator++(int) {
            _ptr ++;
            return *this;
        }

        const T& operator*() {
            return *_ptr;
        }

        bool operator!=(const iterator& other) {
            return _ptr != other._ptr;
        }

        const T* _ptr;
    };

    iterator begin() {
        return iterator(_v);
    }

    iterator end() {
        return iterator(_v + _len);
    }

    const T* _v;
    std::size_t _len;
};


int main() {
    std::vector<int> ints = {1, 2, 3};
    std::list<int> ints2 = {1,2,3};
    std::array<int, 3> ints3 = {1,2,3};
    std::unordered_map<int, std::string> map = {{1, "a"}, {2, "b"}};

    int a[] = {1,2,3};
    auto s = slice<int>::from(a);

 
    std::cout << dumpList(ints.begin(), ints.end()) << std::endl;
    std::cout << dumpList(ints2.begin(), ints2.end()) << std::endl;
    std::cout << dumpList(ints3.begin(), ints3.end()) << std::endl;
    std::cout << dumpMap(map.begin(), map.end()) << std::endl;
    std::cout << dumpList(s.begin(), s.end()) << std::endl;
}
