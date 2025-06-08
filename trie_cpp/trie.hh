#ifndef TRIE_HH
#define TRIE_HH

#include <memory>
#include <fmt/format.h>
#include <concepts>
#include <vector>
#include <absl/strings/str_split.h>
#include <limits>
#include <string_view>


struct trie_node_base {
    std::unique_ptr<trie_node_base> left;
    std::unique_ptr<trie_node_base> right;

    size_t max_depth() const {
        if (!left && !right) {
            return 0;
        } else if (left && right) {
            return 1 + std::max(left->max_depth(), right->max_depth());
        } else if (left) {
            return 1 + left->max_depth();
        } else {
            return 1 + right->max_depth();
        }
    }

    virtual ~trie_node_base() = default;
};

template <typename T>
constexpr auto init_value() {
    if constexpr (std::is_unsigned_v<T> || std::is_signed_v<T>) {
        return 0;
    } else if (std::is_pointer_v<T>) {
        return nullptr;
    } else {
        return T{};
    }
}

template<typename T>
struct trie_node : public trie_node_base {
public:
    T value;
    trie_node(T v) : value{v} {}
    trie_node() : value{init_value<T>()} {}
    void set(T v) {
        value = v;
    }

    bool has_info() const {
        return value != init_value<T>();
    }
};

template<typename T>
struct range {
    T low;
    T high;

    static_assert(std::is_unsigned_v<T>, "T must be unsigned");
    range() = default;

    range(const char *s) : range(std::string_view(s)) {}
    range(T l, T h) : low{l}, high{h} {}

    range(std::string_view s) {
        std::vector<std::string_view> parts = absl::StrSplit(s, '-');
        if (parts.size() != 2) {
            throw std::invalid_argument(fmt::format("invalid range format {}", s));
        }

        auto v = std::stoul(std::string(parts[0]), nullptr, 10);
        if (v < 0 || v > std::numeric_limits<T>::max()) {
            throw std::invalid_argument(fmt::format("invalid range value {}", v));
        }
        low = v;

        v = std::stoul(std::string(parts[1]), nullptr, 10);
        if (v < 0 || v > std::numeric_limits<T>::max()) {
            throw std::invalid_argument(fmt::format("invalid range value {}", v));
        }
        high = v;
    }

    bool overlap(const range<T>& other) const {
        return low <= other.high && high >= other.low;
    }

    bool contains(const T v) const {
        return low <= v && high >= v;
    }

    bool contains(const range<T>& other) const {
        return low <= other.low && high >= other.high;
    }

    std::string show() const {
        return fmt::format("0x{:0{}x}-0x{:0{}x}", low, sizeof(T) * 2, high, sizeof(T) * 2);
    }
};

template <typename T>
struct prefix {
    T v;
    uint8_t len;

    static_assert(std::is_unsigned_v<T>, "T must be unsigned");
    prefix() = default;

    prefix(T v, uint8_t len) : v{v}, len{len} {
        T mask = ~((T(1) << (sizeof(T) * 8 - len)) - 1);
        if (v != (v & mask)) {
            throw std::invalid_argument(fmt::format("prefix does not match the length {:x}/{}", v, len));
        }

        if (len > sizeof(T) * 8) {
            throw std::invalid_argument(fmt::format("prefix length is too long len {}", len));
        }
    }

    bool operator==(const prefix<T>& other) const {
        return v == other.v && len == other.len;
    }

    std::string show() const {
        return fmt::format("0x{:0{}x}/{}", v, sizeof(T) * 2, len);
    }

    bool highest_bit_is_set() const {
        return v & (T(1) << (sizeof(T) * 8 - 1));
    }

    range<T> convert_to_range() const {
        T mask = ~((T(1) << (sizeof(T) * 8 - len)) - 1);
        return {static_cast<T>(v & mask),
                static_cast<T>(v | ~mask)};
    }

    bool overlap(const prefix<T>& other) const {
        auto other_range = other.convert_to_range();
        auto this_range = convert_to_range();
        return this_range.overlap(other_range);
    }

    bool match(const T value) const {
        auto range = convert_to_range();
        return range.contains(value);
    }

    bool contains(const prefix<T>& other) const {
        auto range = convert_to_range();
        auto other_range = other.convert_to_range();
        return range.contains(other_range);
    }
};


struct ipv4_prefix : public prefix<uint32_t> {

    ipv4_prefix() = default;
    ipv4_prefix(uint32_t v, uint8_t len) : prefix<uint32_t>(v, len) {}

    std::string show() const {
        return fmt::format("{}.{}.{}.{}/{}", (v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff, len);
    }

    ipv4_prefix(const char *s) : ipv4_prefix(std::string_view(s)) {}

    ipv4_prefix(std::string_view s) {
        std::vector<std::string_view> parts = absl::StrSplit(s, '/');
        if (parts.size() != 2) {
            throw std::invalid_argument(fmt::format("invalid ipv4 prefix {}", s));
        }

        const auto& ip = parts[0];
        std::vector<std::string_view> ip_parts = absl::StrSplit(ip, '.');
        if (ip_parts.size() != 4) {
            throw std::invalid_argument(fmt::format("invalid ipv4 prefix {}", s));
        }

        uint32_t v = 0;
        for (const auto& part : ip_parts) {
            auto _v = std::stoul(std::string(part));
            if (_v > 0xff) {
                throw std::invalid_argument(fmt::format("invalid ipv4 octet {}", _v));
            }
            v = (v << 8) | _v;
        }
        uint8_t _len = std::stoul(std::string(parts[1]));
        if (_len > 32) {
            throw std::invalid_argument(fmt::format("invalid ipv4 prefix length {}", _len));
        }
        uint8_t len = _len;
        *this = ipv4_prefix(v, len);
    }

};


struct acl_rule {
    using port_range = range<uint16_t>;
    using proto_range = range<uint8_t>;

    ipv4_prefix src;
    ipv4_prefix dst;
    port_range src_port;
    port_range dst_port;
    proto_range proto;

    acl_rule() = default;

    acl_rule(ipv4_prefix src, ipv4_prefix dst, port_range src_port, port_range dst_port, proto_range proto)
        : src{src}, dst{dst}, src_port{src_port}, dst_port{dst_port}, proto{proto} {}


    std::string show() const {
        return fmt::format("{} {} {} {} {}", src.show(), dst.show(), src_port.show(), dst_port.show(), proto.show());
    }
};



template <typename T>
class trie {
public:
    trie_node<T> root;
    trie() = default;

    template<typename P>
    void insert(prefix<P> p, T value) {

        trie_node_base* currNode = &root;
        while (p.len) {
            if (p.highest_bit_is_set()) {
                if (!currNode->right) {
                    currNode->right = std::make_unique<trie_node<T>>();
                }
                currNode = currNode->right.get();
            } else {
                if (!currNode->left) {
                    currNode->left = std::make_unique<trie_node<T>>();
                }
                currNode = currNode->left.get();
            }
            p.v <<= 1;
            p.len--;
        }

        trie_node<T> *tn = static_cast<trie_node<T>*>(currNode);
        tn->set(value);
    }

    template<typename P>
    std::optional<T> find(prefix<P> p) const {

        const trie_node_base* currNode = &root;

        while (p.len) {
            if (p.highest_bit_is_set()) {
                if (!currNode->right) {
                    return std::nullopt;
                }
                currNode = currNode->right.get();
            } else {
                if (!currNode->left) {
                    return std::nullopt;
                }
                currNode = currNode->left.get();
            }
            p.v <<= 1;
            p.len--;
        }

        const trie_node<T> *tn = static_cast<const trie_node<T>*>(currNode);
        return tn->value;
    }

    template<typename P>
    void dump(const trie_node_base* node, prefix<P> p, std::vector<prefix<P>>& prefixes) const {
        if ((static_cast<const trie_node<T>*>(node))->has_info()) {
            prefixes.push_back(p);
        }

        if (node->left) {
            prefix<P> left_p = prefix<P>(p.v, p.len + 1);
            dump(node->left.get(), left_p, prefixes);
        }
        if (node->right) {
            prefix<P> right_p = prefix<P>(p.v | (P(1) << (sizeof(P) * 8 - 1 - p.len)), p.len + 1);
            dump(node->right.get(), right_p, prefixes);
        }
    }

    template<typename P>
    void dump(std::vector<prefix<P>>& prefixes) const {
        dump(&root, {0, 0}, prefixes);
    }

    size_t max_depth() const {
        return root.max_depth();
    }

};


#endif
