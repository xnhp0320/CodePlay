#ifndef TRIE_HH
#define TRIE_HH

#include <memory>
#include <fmt/format.h>
#include <concepts>
#include <vector>


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

    bool overlap(const range<T>& other) const {
        return low <= other.high && high >= other.low;
    }

    bool contains(const T v) const {
        return low <= v && high >= v;
    }

    bool contains(const range<T>& other) const {
        return low <= other.low && high >= other.high;
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
            throw std::runtime_error(fmt::format("prefix does not match the length {:x}/{}", v, len));
        }

        if (len > sizeof(T) * 8) {
            throw std::runtime_error(fmt::format("prefix length is too long len {}", len));
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

    range<T> covert_to_range() const {
        T mask = ~((T(1) << (sizeof(T) * 8 - len)) - 1);
        return {static_cast<T>(v & mask),
                static_cast<T>(v | ~mask)};
    }

    bool overlap(const prefix<T>& other) const {
        auto other_range = other.covert_to_range();
        auto this_range = covert_to_range();
        return this_range.overlap(other_range);
    }

    bool match(const T value) const {
        auto range = covert_to_range();
        return range.contains(value);
    }

    bool contains(const prefix<T>& other) const {
        auto range = covert_to_range();
        auto other_range = other.covert_to_range();
        return range.contains(other_range);
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
            prefix<P> right_p = prefix<P>(p.v | (1ULL << (sizeof(P) * 8 - 1 - p.len)), p.len + 1);
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
