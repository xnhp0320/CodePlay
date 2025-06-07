#ifndef TRIE_HH
#define TRIE_HH

#include <memory>
#include <fmt/format.h>
#include <concepts>

struct trie_node_base {
    std::unique_ptr<trie_node_base> left;
    std::unique_ptr<trie_node_base> right;

    size_t max_depth() {
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


template<typename T>
struct trie_node : public trie_node_base {
public:
    T value;
    trie_node(T v) : value{v} {}
    trie_node() : value{0} {}
    void set(T v) {
        value = v;
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
};

template <typename T>
struct prefix {
    T v;
    size_t len;

    static_assert(std::is_unsigned_v<T>, "T must be unsigned");
    static_assert(sizeof(T) <= 8, "T must equal or less than 8 bytes");

    prefix(T v, size_t len) : v{v}, len{len} {
        T mask = (1ULL << len) - 1;
        if (v != (v & mask)) {
            throw std::runtime_error("prefix does not match the length");
        }
    }

    std::string show() const {
        return fmt::format("0x{:0{}x}/{}", v, sizeof(T) * 2, len);
    }

    bool highest_bit_is_set() const {
        return v & (1ULL << (sizeof(T) * 8 - 1));
    }

    range<T> covert_to_range() const {
        T mask = (1ULL << len) - 1;
        return {v & mask, v | ~mask};
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
};


template <typename T>
class trie {
public:
    std::unique_ptr<trie_node_base> root;
    trie() = default;

    template<typename P>
    void insert(prefix<P> p, T value) {
        if (!root) {
            root = std::make_unique<trie_node<T>>();
        }

        trie_node_base* currNode = root.get();
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
        if (!root) {
            return std::nullopt; 
        }

        trie_node_base* currNode = root.get();
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

        trie_node<T> *tn = static_cast<trie_node<T>*>(currNode);
        return tn->value;
    }

    size_t max_depth() const {
        if (!root) {
            return 0;
        }
        return root->max_depth();
    }

};


#endif
