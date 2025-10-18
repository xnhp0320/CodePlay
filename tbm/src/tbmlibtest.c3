module tbmlibtest;
import tbmlib;
import tbmlib::common;
import tbmlib::bitmap;
import tbmlib::cidr;
import std::io;
import std::collections::list;
import std::sort::is;
import std::math;

alias BitmapType6 = tbmlib::bitmap::BitmapType {6};
alias BitmapType7 = tbmlib::bitmap::BitmapType {7};

alias @bitmap_set6 = tbmlib::bitmap::@bitmap_set {6};

fn void test_bitmap6() @test {
    BitmapType6 v;
    assert(@bitmap_set6(v, 1) == 2);
}

fn void test_bitmap7() @test {
    BitmapType7 v;
    assert(@bitmap_set{7}(v, 1) == 2);
    assert(@bitmap_set{7}(v, 0) == 1);
}

alias BitmapType3 = tbmlib::bitmap::BitmapType {3};
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

    assert(@catch(bm.check_exl_bitmap(stride)) == tbmlib::common::MISSING);
    bm = 0b10000001;
    assert(bm.check_exl_bitmap(stride)!! == 1);
}

fn void test_value_insert3() @test {
    TbmNode{3, uint, uint} root;
    TempTbmAllocator{3, uint, uint} alloc;
    Cidr{uint} cidr = {.ip = 0, .cidr = 3 };
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
    Cidr {uint} cidr = {.ip = 0, .cidr = 3};
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

fn void output(Cidr{uint}* cidr, uint *value, void *aux) @local => @output(cidr, value, aux);


fn int stringcmp(String a, String b) {
    int res;
    foreach (i, c : a[:math::min(a.len, b.len)]) {
        if (c > b[i]) {
            return 1;
        } else if (c < b[i]) {
            return -1;
        }
    }
    return compare_to(a.len, b.len);
}

macro gen_iterate_test($s) {
    TbmNode{$s, uint, uint} root;
    TempTbmAllocator{$s, uint, uint} alloc;
    Cidr{uint} cidr = {.ip = 0x20000000, .cidr = 3 };

    @pool() {
        DString out = dstring::new(tmem, "");

        //0b001/3 -> 6
        root.insert(&alloc, cidr, 6)!!;

        //0b000/3 -> 1
        cidr = {.ip = 0, .cidr = 3 };
        root.insert(&alloc, cidr, 1)!!;

        //0b000000/6 -> 2
        cidr = {.ip = 0, .cidr = 6 };
        root.insert(&alloc, cidr, 2)!!;

        //0b11/2 -> 4
        cidr = {.ip = 0xc0000000, .cidr = 2};
        root.insert(&alloc, cidr, 4)!!;

        //0b1/1 -> 5
        cidr = {.ip = 0x80000000, .cidr = 1};
        root.insert(&alloc, cidr, 5)!!;

        //0b111000/6 -> 3
        cidr = {.ip = 0xe0000000, .cidr = 6 };
        root.insert(&alloc, cidr, 3)!!;

        cidr = {};
        root.iterate(&cidr, 0, &output, (void*)&out);

        Splitter split = out.str_view().tokenize_all("\n");
        //TODO: need to sort the splitter and make the result consistent with all stride.
        List{String} retlist;
        retlist.tinit();
        retlist.push(split.next()!!);
        retlist.push(split.next()!!);
        retlist.push(split.next()!!);
        retlist.push(split.next()!!);
        retlist.push(split.next()!!);
        retlist.push(split.next()!!);
        sort::insertionsort(&retlist, &stringcmp);

        assert(retlist[0] == "0x00000000/3 -> 1");
        assert(retlist[1] == "0x00000000/6 -> 2");
        assert(retlist[2] == "0x20000000/3 -> 6");
        assert(retlist[3] == "0x80000000/1 -> 5");
        assert(retlist[4] == "0xc0000000/2 -> 4");
        assert(retlist[5] == "0xe0000000/6 -> 3");
    };
}

macro @gen_tests(#test) {
    $for var $s = 3; $s <= 7; $s++:
        { #test($s); }
    $endfor;
}

fn void test_iterate() @test {
    @gen_tests(gen_iterate_test);
}

fn void test_add_exl() @test {
    TbmNode{3, uint, uint} root;
    TempTbmAllocator{3, uint, uint} alloc;

    @pool() {
        DString out = dstring::new(tmem, "");
        Cidr{uint} cidr;

        //0b111000/6 -> 3
        cidr = {.ip = 0xe0000000, .cidr = 6 };
        root.insert(&alloc, cidr, 3)!!;

        //0b000/3 -> 1
        cidr = {.ip = 0, .cidr = 3 };
        root.insert(&alloc, cidr, 1)!!;

        //0b001/3 -> 6
        cidr = {.ip = 0x20000000, .cidr = 3 };
        root.insert(&alloc, cidr, 6)!!;

        assert(root.external == 0b1000_0011);
        TbmNode{3, uint, uint} *next = root.next;
        assert(next.internal == 0b00000001);
        TbmValueNode{3, uint, uint} *vnode = next.next;
        vnode --;
        assert(vnode.values[0] == 1);

        next += 1;
        assert(next.internal == 0b0000_0001);
        vnode = next.next;
        vnode --;
        assert(vnode.values[0] == 6);

        next += 1;
        assert(next.internal == 0b0000_0000);
        assert(next.external == 0b0000_0001);
        next = next.next;
        vnode = next.next;
        vnode --;
        assert(vnode.values[0] == 3);
    };
}

fn void test_add_inl() @test {
    TbmNode{3, uint, uint} root;
    TempTbmAllocator{3, uint, uint} alloc;

    @pool() {
        DString out = dstring::new(tmem, "");
        Cidr{uint} cidr;

        //0b11/2 -> 3
        cidr = {.ip = 0xc0000000, .cidr = 2 };
        root.insert(&alloc, cidr, 3)!!;

        //0b00/2 -> 1
        cidr = {.ip = 0, .cidr = 2 };
        root.insert(&alloc, cidr, 1)!!;

        //0b0/1 -> 6
        cidr = {.ip = 0x00000000, .cidr = 1 };
        root.insert(&alloc, cidr, 6)!!;

        assert(root.external == 0b0);
        assert(root.internal == 0b01001010);

        TbmValueNode{3, uint, uint} *vnode = root.next;
        vnode --;
        assert(vnode.values[0] == 6);
        assert(vnode.values[1] == 1);
        assert(vnode.values[2] == 3);
    };

}

fn void test_add_inl_more() @test {
    TbmNode{3, uint, uint} root;
    TempTbmAllocator{3, uint, uint} alloc;

    @pool() {
        DString out = dstring::new(tmem, "");
        Cidr{uint} cidr;

        //0b11/2 -> 3
        cidr = {.ip = 0xc0000000, .cidr = 2 };
        root.insert(&alloc, cidr, 3)!!;

        //0b00/2 -> 1
        cidr = {.ip = 0, .cidr = 2 };
        root.insert(&alloc, cidr, 1)!!;

        //0b01/2 -> 1
        cidr = {.ip = 0x4000_0000, .cidr = 2 };
        root.insert(&alloc, cidr, 7)!!;

        //0b0/1 -> 6
        cidr = {.ip = 0x00000000, .cidr = 1 };
        root.insert(&alloc, cidr, 6)!!;

        //0b1/1 -> 8
        cidr = {.ip = 0x8000_0000, .cidr = 1 };
        root.insert(&alloc, cidr, 6)!!;

        assert(root.external == 0b0);
        assert(root.internal == 0b01011110);

        TbmValueNode{3, uint, uint} *vnode = root.next;
        vnode --;
        assert(vnode.values[0] == 6);
        assert(vnode.values[1] == 6);
        assert(vnode.values[2] == 1);
        assert(vnode.values[3] == 7);
        vnode --;
        assert(vnode.values[0] == 3);
    };

}

fn void test_remove_inl() @test {
    TbmNode{3, uint, uint} root;
    TempTbmAllocator{3, uint, uint} alloc;

    @pool() {
        DString out = dstring::new(tmem, "");
        Cidr{uint} cidr;

        //0b11/2 -> 3
        cidr = {.ip = 0xc0000000, .cidr = 2 };
        root.insert(&alloc, cidr, 3)!!;

        //0b00/2 -> 1
        cidr = {.ip = 0, .cidr = 2 };
        root.insert(&alloc, cidr, 1)!!;

        //0b0/1 -> 6
        cidr = {.ip = 0x00000000, .cidr = 1 };
        root.insert(&alloc, cidr, 6)!!;

        assert(root.external == 0b0);
        assert(root.internal == 0b01001010);

        TbmValueNode{3, uint, uint} *vnode = root.next;
        vnode --;
        assert(vnode.values[0] == 6);
        assert(vnode.values[1] == 1);
        assert(vnode.values[2] == 3);

        cidr = {.ip = 0, .cidr = 2};
        root.remove(&alloc, cidr)!!;
        assert(root.internal == 0b01000010);

        cidr = {.ip = 0, .cidr = 3};
        assert(@catch(root.remove(&alloc, cidr)) ==  tbmlib::common::PREFIX_NOT_EXIST);

        cidr = {.ip = 0x4000_0000, .cidr = 2};
        assert(@catch(root.remove(&alloc, cidr)) ==  tbmlib::common::PREFIX_NOT_EXIST);

        assert(vnode.values[0] == 6);
        assert(vnode.values[1] == 3);
    };
}

fn void test_remove_inl_more() @test {
    TbmNode{3, uint, uint} root;
    TempTbmAllocator{3, uint, uint} alloc;

    @pool() {
        DString out = dstring::new(tmem, "");
        Cidr{uint} cidr;
        //0b11/2 -> 3
        cidr = {.ip = 0xc0000000, .cidr = 2 };
        root.insert(&alloc, cidr, 3)!!;

        //0b00/2 -> 1
        cidr = {.ip = 0, .cidr = 2 };
        root.insert(&alloc, cidr, 1)!!;

        //0b01/2 -> 1
        cidr = {.ip = 0x4000_0000, .cidr = 2 };
        root.insert(&alloc, cidr, 7)!!;

        //0b0/1 -> 6
        cidr = {.ip = 0x00000000, .cidr = 1 };
        root.insert(&alloc, cidr, 6)!!;

        //0b1/1 -> 8
        cidr = {.ip = 0x8000_0000, .cidr = 1 };
        root.insert(&alloc, cidr, 6)!!;

        assert(root.external == 0b0);
        assert(root.internal == 0b01011110);

        TbmValueNode{3, uint, uint} *vnode = root.next;
        vnode --;
        assert(vnode.values[0] == 6);
        assert(vnode.values[1] == 6);
        assert(vnode.values[2] == 1);
        assert(vnode.values[3] == 7);
        vnode --;
        assert(vnode.values[0] == 3);

        cidr = {.ip = 0, .cidr = 2};
        root.remove(&alloc, cidr)!!;
        assert(root.internal == 0b01010110);

        cidr = {.ip = 0x8000_0000, .cidr = 2};
        assert(@catch(root.remove(&alloc, cidr)) == tbmlib::common::PREFIX_NOT_EXIST);

        vnode = root.next;
        vnode --;
        assert(vnode.values[0] == 6);
        assert(vnode.values[1] == 6);
        assert(vnode.values[2] == 7);
        assert(vnode.values[3] == 3);
    };
}

fn void test_remove_exl() @test {
    TbmNode{3, uint, uint} root;
    TempTbmAllocator{3, uint, uint} alloc;

    @pool() {
        DString out = dstring::new(tmem, "");
        Cidr{uint} cidr;

        //0b111000/6 -> 3
        cidr = {.ip = 0xe0000000, .cidr = 6 };
        root.insert(&alloc, cidr, 3)!!;

        //0b000/3 -> 1
        cidr = {.ip = 0, .cidr = 3 };
        root.insert(&alloc, cidr, 1)!!;

        //0b001/3 -> 6
        cidr = {.ip = 0x20000000, .cidr = 3 };
        root.insert(&alloc, cidr, 6)!!;

        cidr = {.ip = 0, .cidr = 6};
        assert(@catch(root.remove(&alloc, cidr)) == tbmlib::common::PREFIX_NOT_EXIST);

        cidr = {.ip = 0x20000000, .cidr = 3 };
        root.remove(&alloc, cidr)!!;

        assert(root.external == 0b1000_0001);
        TbmNode{3, uint, uint} *next = root.next;
        assert(next.internal == 0b0000_0001);
        TbmValueNode{3, uint, uint} *vnode = next.next;
        vnode --;
        assert(vnode.values[0] == 1);

        next += 1;
        assert(next.internal == 0b0);
        next = next.next;
        vnode = next.next;
        vnode --;
        assert(vnode.values[0] == 3);
    };
}

fn void test_del_all() @test {

    TbmNode{3, uint, uint} root;
    TempTbmAllocator{3, uint, uint} alloc;

    @pool() {
        DString out = dstring::new(tmem, "");

        Cidr{uint} cidr = {.ip = 0x2000_0000, .cidr = 3};
        //0b001/3 -> 6
        root.insert(&alloc, cidr, 6)!!;

        //0b000/3 -> 1
        cidr = {.ip = 0, .cidr = 3 };
        root.insert(&alloc, cidr, 1)!!;

        //0b000000/6 -> 2
        cidr = {.ip = 0, .cidr = 6 };
        root.insert(&alloc, cidr, 2)!!;

        //0b11/2 -> 4
        cidr = {.ip = 0xc0000000, .cidr = 2};
        root.insert(&alloc, cidr, 4)!!;

        //0b1/1 -> 5
        cidr = {.ip = 0x80000000, .cidr = 1};
        root.insert(&alloc, cidr, 5)!!;

        //0b111000/6 -> 3
        cidr = {.ip = 0xe0000000, .cidr = 6 };
        root.insert(&alloc, cidr, 3)!!;

        cidr = {.ip = 0x2000_0000, .cidr = 3};
        root.remove(&alloc, cidr)!!;

        cidr = {.ip = 0, .cidr = 3 };
        root.remove(&alloc, cidr)!!;

        cidr = {.ip = 0, .cidr = 6 };
        root.remove(&alloc, cidr)!!;

        cidr = {.ip = 0xc0000000, .cidr = 2};
        root.remove(&alloc, cidr)!!;

        cidr = {.ip = 0x80000000, .cidr = 1};
        root.remove(&alloc, cidr)!!;

        //0b111000/6 -> 3
        cidr = {.ip = 0xe0000000, .cidr = 6 };
        root.remove(&alloc, cidr)!!;

        assert(root.external == 0);
        assert(root.internal == 0);
        assert(root.next == null);
    };
}
