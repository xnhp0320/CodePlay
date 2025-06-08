#include "trie.hh"
#include <cstdint>
#include <gtest/gtest.h>
#include <gmock/gmock.h>


TEST(Prefix, Test1) {
    prefix<uint16_t> p1 = { 0x4, 16 };
    auto str = p1.show();
    EXPECT_EQ(str, "0x0004/16");

    prefix<uint16_t> p2 = { 0x1234, 16 };
    str = p2.show();
    EXPECT_EQ(str, "0x1234/16");
}

TEST(Prefix, Test2) {
    prefix<uint16_t> p1 = { 0x8000, 4 };
    prefix<uint16_t> p2 = { 0x8000, 2 };
    EXPECT_EQ(p2.overlap(p1), true);
    EXPECT_EQ(p2.contains(p1), true);
}

TEST(IPPrefix, Test1) {
    ipv4_prefix p1 = { 0xc0a80000, 16 };
    auto str = p1.show();
    EXPECT_EQ(str, "192.168.0.0/16");
}

TEST(IPPrefix, Test2) {
    EXPECT_THROW({ipv4_prefix p1 = "192.168.10000.0/16";}, std::invalid_argument);
}

TEST(ACL, Test1) {
    acl_rule r = {"192.168.0.0/16", "0.0.0.0/0", "0-65535", "0-65535", "0-255"};
    EXPECT_EQ(r.show(), "192.168.0.0/16 0.0.0.0/0 0-65535 0-65535 0-255");
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

TEST(Trie, Test4) {
    trie<uint32_t> bt;
    bt.insert<uint16_t>({0x1234, 16}, 1);
    bt.insert<uint16_t>({0x4, 16}, 2);
    std::vector<prefix<uint16_t>> prefixes;
    bt.dump(prefixes);
    EXPECT_EQ(prefixes.size(), 2);
    EXPECT_THAT(prefixes, testing::UnorderedElementsAre(
        prefix<uint16_t>{0x1234, 16},
        prefix<uint16_t>{0x4, 16}
    ));
}

