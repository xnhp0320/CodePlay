module tbmlibtest;
import iprange;
import tbmlib;
import tbmlib::common;
import tbmlib::bitmap;
import tbmlib::bitmap_slab;
import tbmlib::cidr;
import std::io;
import std::io::file;
import std::collections::list;
import std::sort;
import std::math;
import std::net;
import std::time::clock;

const uint FIB_TBM_STRIDE = 5;
alias BitmapType6 = tbmlib::bitmap::BitmapType {6};
alias BitmapType7 = tbmlib::bitmap::BitmapType {7};
alias UintBitmapSlab = bitmap_slab::BitmapSlab {uint};
alias FibCidr = cidr::Cidr {uint};
alias FibIpRangeList = iprange::IpRangeList {uint};
alias FibSegList = iprange::SegList {uint};
alias FibTbm = Tbm {FIB_TBM_STRIDE, uint, FibCidr};
alias FibAlloc = TempTbmAllocator {FIB_TBM_STRIDE, uint, FibCidr};
alias FibBenchAlloc = TrivalAllocator {FIB_TBM_STRIDE, uint, FibCidr};
alias FibSlabAlloc = SlabAllocator {FIB_TBM_STRIDE, uint, FibCidr};
alias FibCidr6 = cidr::Cidr {uint128};
alias FibIpRangeList6 = iprange::IpRangeList {uint128};
alias FibSegList6 = iprange::SegList {uint128};
alias FibTbm6 = Tbm {FIB_TBM_STRIDE, uint128, uint};
alias FibAlloc6 = TempTbmAllocator {FIB_TBM_STRIDE, uint128, uint};
List{uint} fib_bench_ips;
FibTbm fib_bench_tbm;
FibBenchAlloc fib_bench_alloc;
ulong fib_bench_checksum;
FibTbm fib_large_slab_tbm;
FibSlabAlloc fib_large_slab_alloc;
usz fib_large_slab_rules;
bool fib_bench_ready;
bool fib_large_slab_bench_ready;

alias @bitmap_set6 = tbmlib::bitmap::@bitmap_set {6};

fn void init_benchmarks() @init {
    set_benchmark_warmup_iterations(1);
    set_benchmark_func_iterations("tbmlibtest::benchmark_tbm_ipv4_lookup", 1);
    set_benchmark_func_iterations("tbmlibtest::benchmark_bitmap_slab_large_fib_load", 1);
}

fn void test_bitmap6() @test {
    BitmapType6 v;
    assert(@bitmap_set6(v, 1) == 2);
}

fn void test_bitmap7() @test {
    BitmapType7 v;
    assert(@bitmap_set{7}(v, 1) == 2);
    assert(@bitmap_set{7}(v, 0) == 1);
}

fn void test_bitmap_slab_alloc_free() @test {
    UintBitmapSlab slab;
    slab.init(32);
    defer slab.release();

    uint *first = slab.alloc(5)!!;
    uint *second = slab.alloc(3)!!;

    assert(first == slab.storage.ptr);
    assert(second == &slab.storage[5]);
    assert(slab.free_nodes == 24);
    assert(slab.stats.alloc_requests == 2);
    assert(slab.stats.alloc_cache_hits == 2);
    assert(slab.stats.bitmap_fallback_scans == 0);
    assert(slab.cache_entries == 1);
    assert(slab.segment_cache[0].offset == 8);
    assert(slab.segment_cache[0].len == 24);

    slab.free(first, 5);
    assert(slab.free_nodes == 29);
    assert(slab.stats.free_requests == 1);
    assert(slab.cache_entries == 2);

    uint *reused = slab.alloc(4)!!;
    assert(reused == slab.storage.ptr);
    assert(slab.free_nodes == 25);
    assert(slab.stats.alloc_requests == 3);
    assert(slab.stats.alloc_cache_hits == 3);
    assert(slab.stats.bitmap_fallback_scans == 0);
    assert(slab.cache_entries == 2);

    bool saw_tail;
    bool saw_remainder;
    usz i = 0;
    while (i < slab.cache_entries) {
        if (slab.segment_cache[i].offset == 8 && slab.segment_cache[i].len == 24) {
            saw_tail = true;
        }
        if (slab.segment_cache[i].offset == 4 && slab.segment_cache[i].len == 1) {
            saw_remainder = true;
        }
        i++;
    }
    assert(saw_tail);
    assert(saw_remainder);
}

fn void test_bitmap_slab_merge_free_segments() @test {
    UintBitmapSlab slab;
    slab.init(32);
    defer slab.release();

    uint *a = slab.alloc(4)!!;
    uint *b = slab.alloc(6)!!;
    uint *c = slab.alloc(3)!!;
    assert(a == slab.storage);
    assert(b == &slab.storage[4]);
    assert(c == &slab.storage[10]);

    slab.free(b, 6);
    slab.free(c, 3);

    uint *merged = slab.alloc(8)!!;
    assert(merged == &slab.storage[4]);
    assert(slab.free_nodes == 20);
}

fn void test_bitmap_slab_bitmap_scan_fallback() @test {
    UintBitmapSlab slab;
    slab.init(20);
    defer slab.release();

    slab.cache_entries = 0;
    uint *ptr = slab.alloc(5)!!;

    assert(ptr == slab.storage.ptr);
    assert(slab.free_nodes == 15);
    assert(slab.stats.alloc_requests == 1);
    assert(slab.stats.alloc_cache_hits == 0);
    assert(slab.stats.bitmap_fallback_scans == 1);
    assert(slab.cache_entries == 1);
    assert(slab.segment_cache[0].offset == 5);
    assert(slab.segment_cache[0].len == 15);
}

fn void test_bitmap_slab_cache_hit_ratio() @test {
    UintBitmapSlab slab;
    slab.init(16);
    defer slab.release();

    assert(slab.stats.cache_hit_ratio() == 0.0);
    uint *ptr = slab.alloc(4)!!;
    assert(ptr == slab.storage.ptr);
    assert(slab.stats.cache_hit_ratio() == 1.0);

    slab.cache_entries = 0;
    uint *ptr2 = slab.alloc(2)!!;
    assert(ptr2 == &slab.storage[4]);
    assert(slab.stats.alloc_requests == 2);
    assert(slab.stats.alloc_cache_hits == 1);
    assert(slab.stats.cache_hit_ratio() == 0.5);
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

fn void test_cidr_from_full_prefix() @test {
    InetAddress addr = net::ipv4_from_str("202.6.115.167")!!;
    Cidr {uint} cidr;
    cidr.from(&addr, 32);
    assert(cidr.ip == 0xca06_73a7);
    assert(cidr.cidr == 32);
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

fn void test_lookup_sibling_external() @test {
    Tbm{3, uint, uint} tbm;
    TempTbmAllocator{3, uint, uint} alloc;
    tbm.alloc = &alloc;

    @pool() {
        Cidr{uint} cidr = {.ip = 0, .cidr = 3 };
        tbm.insert(cidr, 1)!!;

        cidr = {.ip = 0x2000_0000, .cidr = 3 };
        tbm.insert(cidr, 6)!!;

        assert(tbm.lookup(0x0000_0000)!! == 1);
        assert(tbm.lookup(0x2000_0000)!! == 6);
        assert(@catch(tbm.lookup(0x4000_0000)) == common::VALUE_NOT_FOUND);
    };
}

fn void test_lookup_cached_fallback() @test {
    Tbm{3, uint, uint} tbm;
    TempTbmAllocator{3, uint, uint} alloc;
    tbm.alloc = &alloc;

    @pool() {
        Cidr{uint} cidr = {.ip = 0x0000_0000, .cidr = 1 };
        tbm.insert(cidr, 9)!!;

        cidr = {.ip = 0x0000_0000, .cidr = 6 };
        tbm.insert(cidr, 2)!!;

        assert(tbm.lookup(0x0000_0000)!! == 2);
        assert(tbm.lookup(0x1000_0000)!! == 9);
        assert(@catch(tbm.lookup(0x8000_0000)) == common::VALUE_NOT_FOUND);
    };
}

fn void test_memory_stats() @test {
    Tbm{3, uint, uint} tbm;
    TempTbmAllocator{3, uint, uint} alloc;
    tbm.alloc = &alloc;

    @pool() {
        Cidr{uint} cidr = {.ip = 0xc000_0000, .cidr = 2 };
        tbm.insert(cidr, 4)!!;

        cidr = {.ip = 0x0000_0000, .cidr = 6 };
        tbm.insert(cidr, 2)!!;

        TbmMemoryStats{3, uint, uint} stats = tbm.memory_stats();
        assert(stats.tbm_nodes == 5);
        assert(stats.total_memory == 5 * TbmNode{3, uint, uint}.sizeof);
    };
}

fn void test_slab_allocator_tbm_roundtrip() @test {
    Tbm{3, uint, uint} tbm;
    SlabAllocator{3, uint, uint} alloc;
    alloc.init(32);
    defer alloc.release();
    tbm.alloc = &alloc;

    Cidr{uint} cidr = {.ip = 0, .cidr = 3 };
    tbm.insert(cidr, 1)!!;

    cidr = {.ip = 0x2000_0000, .cidr = 3 };
    tbm.insert(cidr, 6)!!;

    cidr = {.ip = 0xe000_0000, .cidr = 6 };
    tbm.insert(cidr, 3)!!;

    cidr = {.ip = 0xc000_0000, .cidr = 2 };
    tbm.insert(cidr, 4)!!;

    assert(tbm.lookup(0x0000_0000)!! == 1);
    assert(tbm.lookup(0x2000_0000)!! == 6);
    assert(tbm.lookup(0xe000_0000)!! == 3);
    assert(tbm.lookup(0xf000_0000)!! == 4);

    TbmMemoryStats{3, uint, uint} stats = tbm.memory_stats();
    assert(alloc.slab.free_nodes == alloc.slab.storage.len - (stats.tbm_nodes - 1));

    cidr = {.ip = 0, .cidr = 3 };
    tbm.root.remove(&alloc, cidr)!!;
    cidr = {.ip = 0x2000_0000, .cidr = 3 };
    tbm.root.remove(&alloc, cidr)!!;
    cidr = {.ip = 0xe000_0000, .cidr = 6 };
    tbm.root.remove(&alloc, cidr)!!;
    cidr = {.ip = 0xc000_0000, .cidr = 2 };
    tbm.root.remove(&alloc, cidr)!!;

    assert(tbm.root.internal == 0);
    assert(tbm.root.external == 0);
    assert(tbm.root.next == null);
    assert(alloc.slab.free_nodes == alloc.slab.storage.len);
}

fn void? load_ipv4_fib_tbm(Allocator alloc, String filename, FibTbm *tbm) {
    File f = file::open(filename, "r")!;
    defer (void)f.close();
    usz idx = 0;
    InetAddress addr;

    while (1) {
        if (try String line = io::readline(alloc, &f)) {
            if (idx % 2 == 0) {
                addr = net::ipv4_from_str(line)!;
            } else {
                uint prefixlen = line.to_uint()!;
                FibCidr c;
                c.from(&addr, prefixlen);
                tbm.insert(c, c)!!;
            }
        } else {
            break;
        }
        idx++;
    }
}

fn usz? load_ipv4_fib_tbm_count(Allocator alloc, String filename, FibTbm *tbm) {
    File f = file::open(filename, "r")!;
    defer (void)f.close();
    usz idx = 0;
    InetAddress addr;

    while (1) {
        if (try String line = io::readline(alloc, &f)) {
            if (idx % 2 == 0) {
                addr = net::ipv4_from_str(line)!;
            } else {
                uint prefixlen = line.to_uint()!;
                FibCidr c;
                c.from(&addr, prefixlen);
                tbm.insert(c, c)!!;
            }
        } else {
            break;
        }
        idx++;
    }
    return idx / 2;
}

fn void? load_ipv4_fib_ips(Allocator alloc, String filename, List{uint} *ips) {
    File f = file::open(filename, "r")!;
    defer (void)f.close();
    usz idx = 0;

    while (1) {
        if (try String line = io::readline(alloc, &f)) {
            if (idx % 2 == 0) {
                ips.push(net::ipv4_from_str(line)!.ip4.val);
            }
        } else {
            break;
        }
        idx++;
    }
}

fn void? load_ipv6_fib_tbm(Allocator alloc, String filename, FibTbm6 *tbm) {
    File f = file::open(filename, "r")!;
    defer (void)f.close();
    usz idx = 0;
    uint route_idx = 0;
    InetAddress addr;

    while (1) {
        if (try String line = io::readline(alloc, &f)) {
            if (idx % 2 == 0) {
                addr = net::ipv6_from_str(line)!;
            } else {
                uint prefixlen = line.to_uint()!;
                FibCidr6 c;
                c.from(&addr, prefixlen);
                tbm.insert(c, route_idx)!!;
                route_idx++;
            }
        } else {
            break;
        }
        idx++;
    }
}

fn void? load_ipv6_fib_rangelist(Allocator alloc, String filename, FibIpRangeList6 *rl) {
    File f = file::open(filename, "r")!;
    defer (void)f.close();
    usz idx = 0;
    InetAddress addr;

    while (1) {
        if (try String line = io::readline(alloc, &f)) {
            if (idx % 2 == 0) {
                addr = net::ipv6_from_str(line)!;
            } else {
                uint prefixlen = line.to_uint()!;
                FibCidr6 c;
                c.from(&addr, prefixlen);
                rl.push(iprange::iprange_from_cidr{uint128}(c));
            }
        } else {
            break;
        }
        idx++;
    }
}

fn void? assert_ipv6_fib_lookup_matches(Allocator alloc, String filename, FibSegList6 *seg_list, FibIpRangeList6 *rl, FibTbm6 *tbm) {
    File f = file::open(filename, "r")!;
    defer (void)f.close();
    usz idx = 0;
    uint128 ip;

    while (1) {
        if (try String line = io::readline(alloc, &f)) {
            if (idx % 2 == 0) {
                ip = net::ipv6_from_str(line)!.ip6.val;
            } else {
                uint range_idx = seg_list.do_lpm(ip)!!;
                FibCidr6 range_cidr = iprange::cidr_from_iprange{uint128}(rl.[range_idx]);
                uint tbm_idx = tbm.lookup(ip)!!;
                FibCidr6 tbm_cidr = iprange::cidr_from_iprange{uint128}(rl.[tbm_idx]);
                assert(range_cidr.ip == tbm_cidr.ip);
                assert(range_cidr.cidr == tbm_cidr.cidr);
            }
        } else {
            break;
        }
        idx++;
    }
}

fn void ensure_ipv4_fib_benchmark_data() {
    if (fib_bench_ready) {
        return;
    }
    if (!fib_bench_ips.is_initialized()) {
        fib_bench_ips.init(mem);
    }
    fib_bench_tbm.alloc = &fib_bench_alloc;
    @pool() {
        String filename = "ipv4_fib.txt";
        load_ipv4_fib_ips(tmem, filename, &fib_bench_ips)!!;
        load_ipv4_fib_tbm(tmem, filename, &fib_bench_tbm)!!;
    };
    fib_bench_ready = true;
}

fn void ensure_ipv4_large_slab_benchmark_data() {
    if (fib_large_slab_bench_ready) {
        return;
    }

    fib_large_slab_alloc.init(1_000_000);
    fib_large_slab_tbm.alloc = &fib_large_slab_alloc;
    @pool() {
        String filename = "ipv4_fib_large.txt";
        fib_large_slab_rules = load_ipv4_fib_tbm_count(tmem, filename, &fib_large_slab_tbm)!!;
    };
    fib_large_slab_bench_ready = true;
}

fn void? assert_ipv4_fib_lookup_matches(Allocator alloc, String filename, FibSegList *seg_list, FibIpRangeList *rl, FibTbm *tbm) {
    File f = file::open(filename, "r")!;
    defer (void)f.close();
    usz idx = 0;
    uint ip;

    while (1) {
        if (try String line = io::readline(alloc, &f)) {
            if (idx % 2 == 0) {
                ip = net::ipv4_from_str(line)!.ip4.val;
            } else {
                uint range_idx = seg_list.do_lpm(ip)!!;
                FibCidr range_cidr = iprange::cidr_from_iprange{uint}(rl.[range_idx]);
                FibCidr tbm_cidr = tbm.lookup(ip)!!;
                assert(range_cidr.ip == tbm_cidr.ip);
                assert(range_cidr.cidr == tbm_cidr.cidr);
            }
        } else {
            break;
        }
        idx++;
    }
}

fn void test_ipv4_fib_lookup_consistency() @test {
    FibIpRangeList rl;
    rl.init(mem);
    defer rl.free();

    FibAlloc alloc;
    FibTbm tbm;
    tbm.alloc = &alloc;

    @pool() {
        String filename = "ipv4_fib.txt";
        iprange::load_ipv4_rangelist{uint}(tmem, filename, &rl)!!;
        FibSegList seg_list = rl.build_segs()!!;
        defer seg_list.free();

        load_ipv4_fib_tbm(tmem, filename, &tbm)!!;
        assert_ipv4_fib_lookup_matches(tmem, filename, &seg_list, &rl, &tbm)!!;
    };
}

fn void test_ipv6_fib_lookup_consistency() @test {
    FibIpRangeList6 rl;
    rl.init(mem);
    defer rl.free();

    FibAlloc6 alloc;
    FibTbm6 tbm;
    tbm.alloc = &alloc;

    @pool() {
        String filename = "ipv6_fib.txt";
        load_ipv6_fib_rangelist(tmem, filename, &rl)!!;
        FibSegList6 seg_list = rl.build_segs()!!;
        defer seg_list.free();

        load_ipv6_fib_tbm(tmem, filename, &tbm)!!;
        assert_ipv6_fib_lookup_matches(tmem, filename, &seg_list, &rl, &tbm)!!;
    };
}

fn void benchmark_tbm_ipv4_lookup() @benchmark {
    ensure_ipv4_fib_benchmark_data();

    const uint ROUNDS = 16;
    ulong checksum = 0;
    usz total_lookups = fib_bench_ips.len() * ROUNDS;
    Clock started = clock::now();
    @start_benchmark();
    uint round = 0;
    while (round < ROUNDS) {
        foreach (ip : fib_bench_ips) {
            FibCidr cidr = fib_bench_tbm.lookup(ip)!!;
            checksum += (ulong)cidr.ip + cidr.cidr;
        }
        round++;
    }
    @end_benchmark();
    long elapsed_ns = (long)started.mark();
    double avg_lookup_ns = (double)elapsed_ns / total_lookups;
    double mpps = ((double)total_lookups * 1000.0) / elapsed_ns;
    fib_bench_checksum = checksum;
    @log_benchmark("avg lookup: %.2f ns, speed: %.2f Mpps, lookups=%d, ips=%d, rounds=%d, checksum=%d",
        avg_lookup_ns, mpps, total_lookups, fib_bench_ips.len(), ROUNDS, checksum);
}

fn void benchmark_bitmap_slab_large_fib_load() @benchmark {
    Clock started = clock::now();
    @start_benchmark();
    ensure_ipv4_large_slab_benchmark_data();
    @end_benchmark();
    long elapsed_ns = (long)started.mark();
    double elapsed_ms = (double)elapsed_ns / 1_000_000.0;
    @log_benchmark("large fib load: %.2f ms, rules=%d, allocs=%d, cache_hits=%d, hit_rate=%.4f, scans=%d, frees=%d",
        elapsed_ms,
        fib_large_slab_rules,
        fib_large_slab_alloc.slab.stats.alloc_requests,
        fib_large_slab_alloc.slab.stats.alloc_cache_hits,
        fib_large_slab_alloc.slab.stats.cache_hit_ratio(),
        fib_large_slab_alloc.slab.stats.bitmap_fallback_scans,
        fib_large_slab_alloc.slab.stats.free_requests);
}
