#include <iostream>
#include <vector>
#include <unordered_map>
#include <variant>
//too complex.

class JsonValue;

using JsonKey = std::variant<std::string, uint64_t>;
using JsonList = std::vector<JsonValue>;
using JsonMap = std::unordered_map<JsonKey, JsonValue>;

template < typename T>
class copy_ptr {
public:
    copy_ptr() : _ptr(nullptr) {}
    copy_ptr(const copy_ptr &other) {
        _ptr = new T{*other._ptr};
    }
    copy_ptr(copy_ptr &&other) {
        _ptr = other._ptr;
        other._ptr = nullptr;
    }
    // this is not a universal reference, its T comes from
    // the class template not the function temaplate.
    copy_ptr(T &&t) : _ptr(new T{std::move(t)}) {}
    copy_ptr(const T &t) : _ptr(new T{t}) {}
    copy_ptr(T* ptr) : _ptr(new T{*ptr}) {}

    template <typename Arg>
    copy_ptr(std::initializer_list<Arg> l) : _ptr(new T{l}) {}

    T& operator*() {
        return *_ptr;
    }

    copy_ptr& operator=(copy_ptr other) {
        _ptr = other._ptr;
        other._ptr = nullptr;
        return *this;
    }

    ~copy_ptr() {
        delete _ptr;
    }

private:
    T *_ptr;
};

using JsonListPtr = copy_ptr<JsonList>;
using JsonMapPtr = copy_ptr<JsonMap>;


struct JsonValue {
    using JsonValueType = std::variant<std::string, uint64_t,
                                       JsonListPtr, JsonMapPtr>;
    JsonValueType _v;

public:
    JsonValue() = default;
    JsonValue(std::string v) : _v(v) {}
    JsonValue(const char* v) : _v(std::string(v)) {}
    JsonValue(uint64_t v) : _v(v) {}
    JsonValue(JsonListPtr v) : _v(v) {}
    JsonValue(JsonMapPtr v) : _v(v) {}

    JsonValue(std::initializer_list<JsonValue> l) : _v(JsonListPtr(JsonList(l))) {}

    //there is ambiguous
    //{{1,2}, {3,4}} could be either a list of list,
    //or a map. so it's just too hard to do the initialize.
};

int main () {
    std::vector<int> v = {12,3};
    copy_ptr<std::vector<int>> v3 = v;
    copy_ptr<std::vector<int>> v1;
    v1 = v;

    JsonList v2 = {1,2,3};
    JsonValue v4 = {1,2,3};
    //we cannot use {1,2} as it's deduced as int.
    //template deduction does not support implicit coversion.
    //however, JsonValue suport == 1, as normal ctor support
    //int -> uint64.
    JsonMap m = {{1u,2}, {3u,4}};
    return 0;
}
