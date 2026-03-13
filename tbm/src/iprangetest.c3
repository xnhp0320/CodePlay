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

fn void test_build_seg_4() @test {
    IpRangeList rl;
    rl.init(mem);
    defer rl.free();
    Cidr c = {0xc000_0000, 29};
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
    assert (sg_list[2] == (Seg){ .r = {0xc000_0004, 0xc000_0007}, .idx = 0});
}

fn void test_build_seg_5() @test {
    IpRangeList rl;
    rl.init(mem);
    defer rl.free();
    Cidr c = {0xc000_0000, 29};
    rl.push(iprange::iprange_from_cidr{uint}(c));
    c = {0xc000_0002, 32};
    rl.push(iprange::iprange_from_cidr{uint}(c));

    SegList sg_list = rl.build_segs()!!;
    defer sg_list.free();
    //foreach (s: sg_list) {
    //    io::printf("%s\n", s);
    //}
    assert (sg_list[0] == (Seg){ .r = {0xc000_0000, 0xc000_0001}, .idx = 0});
    assert (sg_list[1] == (Seg){ .r = {0xc000_0002, 0xc000_0002}, .idx = 1});
    assert (sg_list[2] == (Seg){ .r = {0xc000_0003, 0xc000_0007}, .idx = 0});
}

fn void test_build_seg_6() @test {
    IpRangeList rl;
    rl.init(mem);
    defer rl.free();
    Cidr c = {0xc000_0000, 29};
    rl.push(iprange::iprange_from_cidr{uint}(c));
    c = {0xc000_0002, 32};
    rl.push(iprange::iprange_from_cidr{uint}(c));
    c = {0xc000_0002, 31};
    rl.push(iprange::iprange_from_cidr{uint}(c));

    SegList sg_list = rl.build_segs()!!;
    //foreach (i, r: rl) {
    //    io::printf("%s %d\n", r, i);
    //}
    defer sg_list.free();
    //foreach (s: sg_list) {
    //    io::printf("%s\n", s);
    //}
    assert (sg_list[0] == (Seg){ .r = {0xc000_0000, 0xc000_0001}, .idx = 0});
    assert (sg_list[1] == (Seg){ .r = {0xc000_0002, 0xc000_0002}, .idx = 1});
    assert (sg_list[2] == (Seg){ .r = {0xc000_0003, 0xc000_0003}, .idx = 2});
    assert (sg_list[3] == (Seg){ .r = {0xc000_0004, 0xc000_0007}, .idx = 0});
}

fn void test_build_seg_7() @test {
    IpRangeList rl;
    rl.init(mem);
    defer rl.free();
    Cidr c = {0xc000_0000, 31};
    rl.push(iprange::iprange_from_cidr{uint}(c));
    c = {0xc000_0000, 24};
    rl.push(iprange::iprange_from_cidr{uint}(c));
    c = {0xc000_0040, 26};
    rl.push(iprange::iprange_from_cidr{uint}(c));

    SegList sg_list = rl.build_segs()!!;
    defer sg_list.free();
    assert (sg_list[0] == (Seg){ .r = {0xc000_0000, 0xc000_0001}, .idx = 0});
    assert (sg_list[1] == (Seg){ .r = {0xc000_0002, 0xc000_003f}, .idx = 1});
    assert (sg_list[2] == (Seg){ .r = {0xc000_0040, 0xc000_007f}, .idx = 2});
    assert (sg_list[3] == (Seg){ .r = {0xc000_0080, 0xc000_00ff}, .idx = 1});
}
