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
    //
    // do not use new T{} as {} will translated into std::intializer_list
    // when T is std::vector<JsonValue>, then the std::vector<JsonValue> { std::vector<JsonValue> }
    // will try to make a list of list JsonValue, treating std::vector<JsonValue>
    // as a JsonValue.
    // this will create stack overflow as it create some sort of recursive ctor that never ends.
    copy_ptr(T &&t) : _ptr(new T(std::move(t))) {}
    copy_ptr(const T &t) : _ptr(new T(t)) {}
    copy_ptr(T* ptr) : _ptr(new T(*ptr)) {}

    template <typename Arg>
    copy_ptr(std::initializer_list<Arg> l) : _ptr(new T(l)) {}

    const T& operator*() const {
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

std::ostream & operator << (std::ostream& os, const JsonKey& k);
std::ostream & operator << (std::ostream& os, const JsonValue& k);
std::ostream & operator << (std::ostream& os, const JsonMap& k);
std::ostream & operator << (std::ostream& os, const JsonList& k);


struct JsonValue {
    using JsonValueType = std::variant<std::string, uint64_t,
                                       JsonListPtr, JsonMapPtr>;
    JsonValueType _v;

    JsonValue() = default;

    JsonValue(std::string v) : _v(std::move(v)) {}
    JsonValue(const char* v) : _v(std::string(v)) {}
    JsonValue(uint64_t v) : _v(v) {}

    //use pass by value. the v will accept either left value
    //or right value. The std::variant will call copy/move
    //ctor here. Since we are using copy_ptr, we anyway will
    //have one copy here. But when construct copy_ptr, using
    //move to avoid another copy.
    JsonValue(JsonList v) : _v(JsonListPtr(std::move(v))) {}
    JsonValue(JsonMap v) : _v(JsonMapPtr(std::move(v))) {}

    //there is ambiguous
    //{{1,2}, {3,4}} could be either a list of list,
    //or a map. so the best way is to explicit to
    //initialize it, so do not provide std::initializer_list
    //ctor.
};

std::ostream & operator << (std::ostream& os, const JsonValue& value) {
    const auto& v = value._v;

    if (std::holds_alternative<std::string>(v)) {
        os << "\"" << std::get<0>(v) << "\"";
    } else if (std::holds_alternative<uint64_t>(v)) {
        os << std::get<1>(v);
    } else if (std::holds_alternative<JsonListPtr>(v)) {
        os << *std::get<2>(v);
    } else {
        os << *std::get<3>(v);
    }

    return os;
}

std::ostream & operator << (std::ostream& os, const JsonList& l) {
    os << "[";
    auto v = l.cbegin();
    os << *v;
    for (++v; v != l.cend(); ++v) {
        os << "," << *v;
    }
    os << "]";
    return os;
}

std::ostream & operator << (std::ostream& os, const JsonKey& k) {

    if (std::holds_alternative<std::string>(k)) {
        os << "\"" << std::get<0>(k) << "\"";
    } else if (std::holds_alternative<uint64_t>(k)) {
        os << std::get<1>(k);
    }
    return os;
}

std::ostream & operator << (std::ostream& os, const JsonMap& m) {
    os << "{\n";
    auto kv = m.cbegin();
    os << kv->first << ":" << kv->second;

    for (++kv; kv != m.cend(); ++kv) {
        os << ",\n" << kv->first << ":" << kv->second;
    }
    os << "\n}";
    return os;
}


int main () {
    std::vector<int> v = {12,3};
    copy_ptr<std::vector<int>> v3 = v;
    copy_ptr<std::vector<int>> v1;
    v1 = v;

    JsonList v2 = {1,2,3};
    JsonValue v4 = JsonList{1,2,3};

    //we cannot use {1,2} as it's deduced as int.
    //template deduction does not support implicit coversion.
    //however, JsonValue suport v == 1, as normal ctor support
    //implicit conversion(int -> uint64).
    //so instead of using JsonKey = std::variant<uint64_t, std::string>
    //it's better to have a wrapper JsonKey class like JsonValue, wrapping
    //std::variant<uint64_t, std::string>, and provide a ctor accepting uint64_t
    //use C's implictly conversion to provide a little bit convinience.
    JsonValue m = JsonMap{{1u,2}, {3u,4}};
    std::cout << v4 << std::endl;
    std::cout << m << std::endl;
    return 0;
}
