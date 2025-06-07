#include "trie.hh"
#include <cstdint>
#include <gtest/gtest.h>


TEST(Prefix, Test1) {
    prefix<uint16_t> p1 = { 0x4, 16 };
    auto str = p1.show();
    EXPECT_EQ(str, "0x0004/16");

    prefix<uint16_t> p2 = { 0x1234, 16 };
    str = p2.show();
    EXPECT_EQ(str, "0x1234/16");
}

TEST(Trie, Test1) {
    trie<uint32_t> bt;
    bt.insert<uint16_t>({0x1234, 16}, 1);
    EXPECT_EQ(bt.max_depth(), 16);
}

TEST(Trie, Test2) {
    trie<uint32_t> bt;
    bt.insert<uint16_t>({0x1234, 16}, 1);
    auto value = bt.find<uint16_t>({0x1234, 16});
    EXPECT_EQ((bool)value, true);
    EXPECT_EQ(*value, 1);
}

TEST(Trie, Test3) {
    trie<uint32_t> bt;
    bt.insert<uint16_t>({0x1234, 16}, 1);
    bt.insert<uint16_t>({0x4, 16}, 2);

    auto value = bt.find<uint16_t>({0x1234, 16});
    EXPECT_EQ((bool)value, true);
    EXPECT_EQ(*value, 1);

    value = bt.find<uint16_t>({0x4, 16});
    EXPECT_EQ((bool)value, true);
    EXPECT_EQ(*value, 2);
}
