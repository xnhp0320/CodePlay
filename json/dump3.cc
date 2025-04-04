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

    //do not use Args&&, since you will overload
    //a && ctor with the original one, which is
    //dangous. We anyway will copy the args into
    //the T.
    template<typename ...Args>
    copy_ptr(Args... args) : _ptr(new T{std::move(args)...}) {}

    copy_ptr(T* ptr) : _ptr(new T{*ptr}) {}

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

    using value_type = JsonMap::value_type;

    JsonValue(std::initializer_list<value_type> l) : _v(JsonMapPtr(l)) {}
};

int main () {
    //std::vector<int> v = {12,3};
    //copy_ptr<std::vector<int>> v3 = v;
    //copy_ptr<std::vector<int>> v1;
    //v1 = v;

    JsonList v2 = {1,2,3};
    JsonValue v4 = {1,2,3};
    JsonValue m = {{1,2}, {3,4}};
    return 0;
}
