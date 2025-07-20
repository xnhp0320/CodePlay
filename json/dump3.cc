#include <iostream>
#include <vector>
#include <unordered_map>
#include <variant>
#include <iomanip>

#include <boost/iostreams/concepts.hpp>
#include <boost/iostreams/filtering_stream.hpp>
//too complex.

class JsonValue;
struct JsonKey {
    std::variant<std::string, uint64_t> _v;
    JsonKey() = default;

    JsonKey(uint64_t value) : _v(value) {}
    JsonKey(std::string str) : _v(std::move(str)) {}
    JsonKey(const char *str) : _v(std::string(str)) {}
    bool operator==(const JsonKey &other) const {
        return _v == other._v;
    }
};

template <>
struct std::hash<JsonKey> {
    std::size_t operator()(const JsonKey &k) const {
        return std::hash<std::variant<std::string, uint64_t>>()(k._v);
    }
};


using JsonList = std::vector<JsonValue>;
using JsonMap = std::unordered_map<JsonKey, JsonValue>;


template < typename T>
class copy_ptr {
public:
    copy_ptr() : _ptr(nullptr) {}

    // do not use new T{} as {} will translated into std::intializer_list
    // when T is std::vector<JsonValue>, then the std::vector<JsonValue> { std::vector<JsonValue> }
    // will try to make a list of list JsonValue, treating std::vector<JsonValue>
    // this will create stack overflow as it create some sort of recursive ctor that never ends.
    // same as copy_ptr(T&&/const T&/T*)
    //
    // use a JsonList to construct a JsonValue: JsonValue(JsonList)
    //  -> construct JsonList
    //      -> construct JsonListPtr
    //          -> use JsonList as an element of std::vector<JsonValue> ---> this is wrong!
    //              -> use a JsonList cosntruct a JsonValue
    //                  -> loops
    //
    // It seems that if we use std::initializer_list to construct JsonMap/JsonList, which is a
    // pure std::variant. It will call copy constructor instead of move. Even I use pure rvalue,
    // like JsonList l = {JsonList{1,2,3}}. This should blame initializer_list, check
    // template/S.cc to see.
    copy_ptr(const copy_ptr &other) {
        _ptr = new T(*other._ptr);
    }
    copy_ptr(copy_ptr &&other) {
        _ptr = other._ptr;
        other._ptr = nullptr;
    }
    // this is not a universal reference, its T comes from
    // the class template not the function temaplate.
    //
    copy_ptr(const T&t) : _ptr(new T(t)) {}
    copy_ptr(T &&t) : _ptr(new T(std::move(t))) {}
    copy_ptr(T* ptr) : _ptr(new T(*ptr)) {}

    const T& operator*() const {
        return *_ptr;
    }

    T& operator*() {
        return *_ptr;
    }

    T* operator->() {
        return _ptr;
    }

    copy_ptr& operator=(copy_ptr other) {
        delete _ptr;
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
    JsonValue(const JsonValue &other) = default;
    JsonValue(JsonValue &&other) = default;

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

void
output(std::ostream &os, const JsonValue &v, size_t indent_depth);

void
output(std::ostream &os, const JsonMap &m, size_t indent_depth = 0) {
    os << "{\n";
    auto kv = m.cbegin();
    os << std::setw(indent_depth) << kv->first << ":";
    output(os, kv->second, indent_depth + 1);

    for (++kv; kv != m.cend(); ++kv) {
        os << ",\n" << std::setw(indent_depth) << kv->first << ":";
        output(os, kv->second, indent_depth + 1);
    }
    os << "\n}";
}

void
output(std::ostream &os, const JsonValue &v, size_t indent_depth = 0) {
    auto const & _v = v._v;

    if (std::holds_alternative<std::string>(_v)) {
        os << "\"" << std::get<0>(_v) << "\"";
    } else if (std::holds_alternative<uint64_t>(_v)) {
        os << std::get<1>(_v);
    } else if (std::holds_alternative<JsonListPtr>(_v)) {
        os << *std::get<2>(_v);
    } else {
        output(os, *std::get<3>(_v), indent_depth + 1);
    }
}

//try to write a pretty printer to add indent for Json Printer.
//use a PrettyPrinter as a ostream which will change every "\n"
//into a "\n" + "\t" * indent;
//
//A first idea is to use boost::iostreams Filters.
//well, filter cannot follow the print levels,
//so it's not a good choice.
//
//The second idea to use boost::iostreams Device,
//to design a special out device for JsonValue.
//which is still too complex, and it cannot be
//implemented as it's hard to put state(indent_depth)
//into the device(boost::iostream sink/source).

namespace io = boost::iostreams;


class IndentPrinter :  public io::output_filter {
    size_t _indent;
public:
    IndentPrinter(size_t indent) : _indent(indent) {}
    template<typename Sink>
    bool put(Sink &dest, int c) {
        if (c == '\n') {
            io::put(dest, '\n');
            for (size_t i = 0; i < _indent; ++i ) {
                io::put(dest, '\t');
            }
        } else {
            io::put(dest, c);
        }
        return true;
    }
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

    const auto& v = k._v;

    if (std::holds_alternative<std::string>(v)) {
        os << "\"" << std::get<0>(v) << "\"";
    } else if (std::holds_alternative<uint64_t>(v)) {
        os << std::get<1>(v);
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

    JsonList v2 = {"a","b","c"};
    JsonValue v4 = JsonList{1,2,3};
    JsonValue v5 = v2;

    //we cannot use {1,2} as it's deduced as int.
    //template deduction does not support implicit coversion.
    //however, JsonValue suport v == 1, as normal ctor support
    //implicit conversion(int -> uint64).
    //so instead of using JsonKey = std::variant<uint64_t, std::string>,
    //it's better to have a wrapper JsonKey class like JsonValue, wrapping
    //std::variant<uint64_t, std::string>, and provide a ctor accepting uint64_t
    //use C's implictly conversion to provide a little bit convinience.

    JsonValue m = JsonMap{{1,2}, {3,4}};
    JsonMap m2 = {{1, JsonList{1,2}}};
    JsonList v6 = {JsonList{1,2,3}, JsonList{2,3,4}};

    JsonValue m3 = JsonMap{{1, m}, {2, v5}};

    //std::cout << v4 << std::endl;
    //std::cout << m << std::endl;
    //std::cout << m2 << std::endl;
    //std::cout << m3 << std::endl;

    //IndentPrinter p(1);
    //io::filtering_ostream out;
    //out.push(p);
    //out.push(std::cout);

    //out << m3 << std::endl;

    output(std::cout , m3);

    return 0;
}
