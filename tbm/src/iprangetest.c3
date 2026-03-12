module iprangetest;
import iprange;
import tbmlib::cidr;
import std::io;

alias IpRangeList = iprange::IpRangeList{uint};
alias SegList = iprange::SegList{uint}; 
alias Seg = iprange::Seg{uint}; 
alias Cidr = cidr::Cidr{uint};

fn void test_build_seg_0() @test {
    IpRangeList rl;
    rl.init(mem);
    defer rl.free();
    Cidr c = {0xc000_0000, 30};
    rl.push(iprange::iprange_from_cidr{uint}(c));

    SegList sg_list = rl.build_segs()!!;
    defer sg_list.free();
    assert (sg_list[0] == (Seg){ .r = {0xc000_0000, 0xc000_0003}, .idx = 0});
    //foreach (s: sg_list) {
    //    io::printf("%s\n", s);
    //}
}

fn void test_build_seg_1() @test {
    IpRangeList rl;
    rl.init(mem);
    defer rl.free();
    Cidr c = {0xc000_0000, 30};
    rl.push(iprange::iprange_from_cidr{uint}(c));
    c = {0xc000_0000, 31};
    rl.push(iprange::iprange_from_cidr{uint}(c));

    SegList sg_list = rl.build_segs()!!;
    defer sg_list.free();
    assert (sg_list[0] == (Seg){ .r = {0xc000_0000, 0xc000_0001}, .idx = 1});
    assert (sg_list[1] == (Seg){ .r = {0xc000_0002, 0xc000_0003}, .idx = 0});
    //foreach (s: sg_list) {
    //    io::printf("%s\n", s);
    //}
}

fn void test_build_seg_2() @test {
    IpRangeList rl;
    rl.init(mem);
    defer rl.free();
    Cidr c = {0xc000_0000, 30};
    rl.push(iprange::iprange_from_cidr{uint}(c));
    c = {0xe000_0000, 31};
    rl.push(iprange::iprange_from_cidr{uint}(c));

    SegList sg_list = rl.build_segs()!!;
    defer sg_list.free();
    assert (sg_list[0] == (Seg){ .r = {0xc000_0000, 0xc000_0003}, .idx = 0});
    assert (sg_list[1] == (Seg){ .r = {0xe000_0000, 0xe000_0001}, .idx = 1});
    //foreach (s: sg_list) {
    //    io::printf("%s\n", s);
    //}
}

fn void test_build_seg_3() @test {
    IpRangeList rl;
    rl.init(mem);
    defer rl.free();
    Cidr c = {0xc000_0000, 30};
    rl.push(iprange::iprange_from_cidr{uint}(c));
    c = {0xc000_0002, 31};
    rl.push(iprange::iprange_from_cidr{uint}(c));

    SegList sg_list = rl.build_segs()!!;
    defer sg_list.free();
    //foreach (s: sg_list) {
    //    io::printf("%s\n", s);
    //}
    assert (sg_list[0] == (Seg){ .r = {0xc000_0000, 0xc000_0001}, .idx = 0});
    assert (sg_list[1] == (Seg){ .r = {0xc000_0002, 0xc000_0003}, .idx = 1});
}
