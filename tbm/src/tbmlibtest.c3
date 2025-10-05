module tbmlibtest @test;
import tbmlib;
import tbmlib_common;
import std::io;

alias BitmapType6 = tbmlib::BitmapType {6};
alias BitmapType7 = tbmlib::BitmapType {7};

alias @bitmap_set6 = tbmlib::@bitmap_set {6};

fn void test_bitmap6() {
    BitmapType6 v;
    assert(@bitmap_set6(v, 1) == 2);
}

fn void test_bitmap7() {
    BitmapType7 v;
    assert(@bitmap_set{7}(v, 1) == 2);
    assert(@bitmap_set{7}(v, 0) == 1);
}

fn void test_inl_check() {
    InlStrideType{3} stride = {0b11};
    //map == 0b01000101
    BitmapType{3} bm = 0b01000000;

    assert(bm.check_inl_bitmap(stride)!! == 1);
    bm = 0b00000101;
    assert(bm.check_inl_bitmap(stride)!! == 2);
    stride = {0b10};
    //map == 0b00100101
    assert(bm.check_inl_bitmap(stride)!! == 2);
}

fn void test_exl_check() {
    StrideType{3} stride = { 0b111 };
    BitmapType{3} bm = 0b0;

    usz? ret = bm.check_exl_bitmap(stride);
    if (catch e = ret) {
        assert(e == tbmlib_common::MISSING);
    }
    bm = 0b10000001;
    assert(bm.check_exl_bitmap(stride)!! == 1);
}

fn void test_route_insert() {
    TbmNode{3} root;
    TempTbmAllocator{3} alloc;
    Ipv4Cidr cidr = {.ip = 0, .cidr = 3 };
    @pool() {
        root.insert(&alloc, cidr, 1)!!;
        assert(root.external == 0b1);
        assert(root.internal == 0b0);
        TbmNode{3} *next = root.next;
        assert(next.internal == 0b1);
        assert(next.external == 0b0);
        assert(*next.get_route(0) == 1);

        cidr = {.ip = 0, .cidr = 6 };
        root.insert(&alloc, cidr, 2)!!;
        assert(root.external == 0b1);
        next = root.next;
        assert(next.external == 0b1);
        next = next.next;
        assert(next.internal == 0b1);
        assert(*next.get_route(0) == 2);

        cidr = {.ip = 0xe0000000, .cidr = 6 };
        root.insert(&alloc, cidr, 3)!!;
        assert(root.external == 0b10000001);
        next = (TbmNode{3}*)root.next + 1;
        assert(next.external == 0b1);
        assert(next.internal == 0b0);
        next = next.next;
        assert(next.internal == 0b1);
        assert(*next.get_route(0) == 3);

        cidr = {.ip = 0xc0000000, .cidr = 2};
        root.insert(&alloc, cidr, 4)!!;
        assert(root.internal == 0b01000000);
        assert(*root.get_route(6) == 4);
    };
}
