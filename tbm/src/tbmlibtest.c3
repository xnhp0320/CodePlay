module tbmlibtest;
import tbmlib;
import tbmlib_common;
import tbmlib_bitmap;
import std::io;

alias BitmapType6 = tbmlib_bitmap::BitmapType {6};
alias BitmapType7 = tbmlib_bitmap::BitmapType {7};

alias @bitmap_set6 = tbmlib_bitmap::@bitmap_set {6};

fn void test_bitmap6() @test {
    BitmapType6 v;
    assert(@bitmap_set6(v, 1) == 2);
}

fn void test_bitmap7() @test {
    BitmapType7 v;
    assert(@bitmap_set{7}(v, 1) == 2);
    assert(@bitmap_set{7}(v, 0) == 1);
}

alias BitmapType3 = tbmlib_bitmap::BitmapType {3};
fn void test_inl_check() @test {
    InlStrideType{3} stride = {0b11};
    //map == 0b01000101
    BitmapType3 bm = 0b01000000;

    assert(bm.check_inl_bitmap(stride)!! == 6);
    bm = 0b00000101;
    assert(bm.check_inl_bitmap(stride)!! == 2);
    stride = {0b10};
    //map == 0b00100101
    assert(bm.check_inl_bitmap(stride)!! == 2);
}

fn void test_exl_check() @test {
    StrideType{3} stride = { 0b111 };
    BitmapType3 bm = 0b0;

    usz? ret = bm.check_exl_bitmap(stride);
    if (catch e = ret) {
        assert(e == tbmlib_common::MISSING);
    }
    bm = 0b10000001;
    assert(bm.check_exl_bitmap(stride)!! == 1);
}

fn void test_value_insert3() @test {
    TbmNode{3, uint, uint} root;
    TempTbmAllocator{3, uint, uint} alloc;
    Cidr{3, uint, uint} cidr = {.ip = 0, .cidr = 3 };
    @pool() {
        root.insert(&alloc, cidr, 1)!!;
        assert(root.external == 0b1);
        assert(root.internal == 0b0);
        TbmNode{3, uint, uint} *next = root.next;
        assert(next.internal == 0b1);
        assert(next.external == 0b0);
        assert(*next.get_value(0) == 1);

        cidr = {.ip = 0, .cidr = 6 };
        root.insert(&alloc, cidr, 2)!!;
        assert(root.external == 0b1);
        next = root.next;
        assert(next.external == 0b1);
        next = next.next;
        assert(next.internal == 0b1);
        assert(*next.get_value(0) == 2);

        cidr = {.ip = 0xe0000000, .cidr = 6 };
        root.insert(&alloc, cidr, 3)!!;
        assert(root.external == 0b10000001);
        next = (TbmNode{3, uint, uint}*)root.next + 1;
        assert(next.external == 0b1);
        assert(next.internal == 0b0);
        next = next.next;
        assert(next.internal == 0b1);
        assert(*next.get_value(0) == 3);

        cidr = {.ip = 0xc0000000, .cidr = 2};
        root.insert(&alloc, cidr, 4)!!;
        assert(root.internal == 0b01000000);
        assert(*root.get_value(6) == 4);

        //update
        root.insert(&alloc, cidr, 5)!!;
        assert(*root.get_value(6) == 5);

    };
}

fn void test_cidr_print() @test {
    Cidr {3, uint, uint} cidr = {.ip = 0, .cidr = 3};
    @pool() {
        DString out = dstring::new(tmem, "");
        io::fprintf(&out, "%s", cidr)!!;
        assert (out.str_view() == "0x00000000/3");
    };
}

macro @output(#cidr, #value, #aux) @local {
    DString *str = (DString*)#aux;
    str.appendf("%s -> %d\n", *#cidr, *#value);
}

fn void output_3(Cidr{3, uint, uint}* cidr, uint *value, void *aux) @local => @output(cidr, value, aux);
fn void output_4(Cidr{4, uint, uint}* cidr, uint *value, void *aux) @local => @output(cidr, value, aux);
fn void output_5(Cidr{5, uint, uint}* cidr, uint *value, void *aux) @local => @output(cidr, value, aux);
fn void output_6(Cidr{6, uint, uint}* cidr, uint *value, void *aux) @local => @output(cidr, value, aux);
fn void output_7(Cidr{7, uint, uint}* cidr, uint *value, void *aux) @local => @output(cidr, value, aux);

macro gen_iterate_test($s) {
    TbmNode{$s, uint, uint} root;
    TempTbmAllocator{$s, uint, uint} alloc;
    Cidr{$s, uint, uint} cidr = {.ip = 0, .cidr = 3 };

    @pool() {
        DString out = dstring::new(tmem, "");
        root.insert(&alloc, cidr, 1)!!;
        cidr = {.ip = 0, .cidr = 6 };
        root.insert(&alloc, cidr, 2)!!;
        cidr = {.ip = 0xe0000000, .cidr = 6 };
        root.insert(&alloc, cidr, 3)!!;
        cidr = {.ip = 0xc0000000, .cidr = 2};
        root.insert(&alloc, cidr, 4)!!;
        cidr = {};
        root.iterate(&cidr, 0, &$eval(@sprintf("output_%s", $s)), (void*)&out);
        Splitter split = out.str_view().tokenize_all("\n");
        //TODO: need to sort the splitter and make the result consistent with all stride.
        assert(split.next()!! == "0xc0000000/2 -> 4");
        assert(split.next()!! == "0x00000000/3 -> 1");
        assert(split.next()!! == "0x00000000/6 -> 2");
        assert(split.next()!! == "0xe0000000/6 -> 3");
    };
}

macro @gen_tests(#test) {
    //$for var $s = 3; $s <= 7; $s++:
    #test(3);
    //$endfor;
}

fn void test_iterate() @test {
    @gen_tests(gen_iterate_test);
}
