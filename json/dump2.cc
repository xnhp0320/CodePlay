#include <variant>
#include <cstdint>
#include <vector>
#include <unordered_map>
#include <iostream>
#include <memory>


using JsonKey = std::variant<std::string, uint64_t>;
struct JsonList;
struct JsonMap;
using JsonListPtr = JsonList*;
using JsonMapPtr = JsonMap*;
using JsonValue = std::variant<std::string, uint64_t,
                               JsonListPtr,
                               JsonMapPtr>;

std::ostream & operator << (std::ostream& os, const JsonKey& k);
std::ostream & operator << (std::ostream& os, const JsonValue& k);
std::ostream & operator << (std::ostream& os, const JsonMap& k);
std::ostream & operator << (std::ostream& os, const JsonList& k);

std::ostream & operator << (std::ostream& os, const JsonValue& v) {
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

struct JsonList {
  std::vector<JsonValue> _v;
  
  JsonList(std::initializer_list<JsonValue> l) : _v(l) {}
};

struct JsonMap {
  std::unordered_map<JsonKey, JsonValue> _v;
  using value_type = std::unordered_map<JsonKey, JsonValue>::value_type;
  JsonMap(std::initializer_list<value_type> l) : _v(l) {}
};

std::ostream & operator << (std::ostream& os, const JsonList& l) {
  os << "[";
  auto v = l._v.cbegin();
  os << *v;
  for (++v; v != l._v.cend(); ++v) {
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
  auto kv = m._v.cbegin();
  os << kv->first << ":" << kv->second;

  for (++kv; kv != m._v.cend(); ++kv) {
    os << ",\n" << kv->first << ":" << kv->second;
  }
  os << "\n}";
  return os;
}

int main() {
  JsonList v = {1u, 2u};
  std::cout << v << std::endl;
  JsonMap m = {{"a", "b"}, {"c", "d"}};
  std::cout << m << std::endl;
  JsonMap m2 = {{"a", &m}, {"b", &m}};
  std::cout << m2 << std::endl;

  return 0;
}
