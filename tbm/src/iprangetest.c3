module iprangetest;
import iprange;
import tbmlib::cidr;
import tbmlib::common;
import std::io;

alias IpRangeList = iprange::IpRangeList{uint};
alias SegList = iprange::SegList{uint}; 
alias Seg = iprange::Seg{uint}; 
alias Cidr = cidr::Cidr{uint};
alias IpRangeList6 = iprange::IpRangeList{uint128};
alias SegList6 = iprange::SegList{uint128};
alias Seg6 = iprange::Seg{uint128};
alias Cidr6 = cidr::Cidr{uint128};

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

fn void test_do_lpm_0() @test {
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

    assert(sg_list.do_lpm(0xc000_0000)!! == 0);
    assert(sg_list.do_lpm(0xc000_0001)!! == 0);
    assert(sg_list.do_lpm(0xc000_0002)!! == 1);
    assert(sg_list.do_lpm(0xc000_003f)!! == 1);
    assert(sg_list.do_lpm(0xc000_0040)!! == 2);
    assert(sg_list.do_lpm(0xc000_007f)!! == 2);
    assert(sg_list.do_lpm(0xc000_0080)!! == 1);
    assert(sg_list.do_lpm(0xc000_00ff)!! == 1);
}

fn void test_do_lpm_1() @test {
    SegList sg_list;
    sg_list.init(mem);
    defer sg_list.free();
    sg_list.push({ .r = {0xc000_0000, 0xc000_0001}, .idx = 0});
    sg_list.push({ .r = {0xc000_0002, 0xc000_003f}, .idx = 1});
    sg_list.push({ .r = {0xc000_0040, 0xc000_007f}, .idx = 2});
    sg_list.push({ .r = {0xc000_0080, 0xc000_00ff}, .idx = 1});

    assert(@catch(sg_list.do_lpm(0xbfff_ffff)) == common::MISSING);
    assert(@catch(sg_list.do_lpm(0xc000_0100)) == common::MISSING);
}

fn void test_build_seg_8() @test {
    IpRangeList rl;
    rl.init(mem);
    defer rl.free();
    Cidr c = {0xca06_7100, 24};
    rl.push(iprange::iprange_from_cidr{uint}(c));
    c = {0xca06_73a7, 32};
    rl.push(iprange::iprange_from_cidr{uint}(c));
    c = {0xca06_7400, 23};
    rl.push(iprange::iprange_from_cidr{uint}(c));

    SegList sg_list = rl.build_segs()!!;
    defer sg_list.free();

    assert (sg_list[0] == (Seg){ .r = {0xca06_7100, 0xca06_71ff}, .idx = 0});
    assert (sg_list[1] == (Seg){ .r = {0xca06_73a7, 0xca06_73a7}, .idx = 1});
    assert (sg_list[2] == (Seg){ .r = {0xca06_7400, 0xca06_75ff}, .idx = 2});
}

fn void test_build_seg_ipv6_0() @test {
    IpRangeList6 rl;
    rl.init(mem);
    defer rl.free();
    Cidr6 c = {0x2001_0db8_0000_0000_0000_0000_0000_0000, 126};
    rl.push(iprange::iprange_from_cidr{uint128}(c));
    c = {0x2001_0db8_0000_0000_0000_0000_0000_0000, 124};
    rl.push(iprange::iprange_from_cidr{uint128}(c));
    c = {0x2001_0db8_0000_0000_0000_0000_0000_0008, 125};
    rl.push(iprange::iprange_from_cidr{uint128}(c));

    SegList6 sg_list = rl.build_segs()!!;
    defer sg_list.free();
    assert (sg_list[0] == (Seg6){ .r = {0x2001_0db8_0000_0000_0000_0000_0000_0000, 0x2001_0db8_0000_0000_0000_0000_0000_0003}, .idx = 0});
    assert (sg_list[1] == (Seg6){ .r = {0x2001_0db8_0000_0000_0000_0000_0000_0004, 0x2001_0db8_0000_0000_0000_0000_0000_0007}, .idx = 1});
    assert (sg_list[2] == (Seg6){ .r = {0x2001_0db8_0000_0000_0000_0000_0000_0008, 0x2001_0db8_0000_0000_0000_0000_0000_000f}, .idx = 2});
}

fn void test_do_lpm_ipv6_0() @test {
    IpRangeList6 rl;
    rl.init(mem);
    defer rl.free();
    Cidr6 c = {0x2001_0db8_0000_0000_0000_0000_0000_0000, 126};
    rl.push(iprange::iprange_from_cidr{uint128}(c));
    c = {0x2001_0db8_0000_0000_0000_0000_0000_0000, 124};
    rl.push(iprange::iprange_from_cidr{uint128}(c));
    c = {0x2001_0db8_0000_0000_0000_0000_0000_0008, 125};
    rl.push(iprange::iprange_from_cidr{uint128}(c));

    SegList6 sg_list = rl.build_segs()!!;
    defer sg_list.free();

    assert(sg_list.do_lpm(0x2001_0db8_0000_0000_0000_0000_0000_0000)!! == 0);
    assert(sg_list.do_lpm(0x2001_0db8_0000_0000_0000_0000_0000_0003)!! == 0);
    assert(sg_list.do_lpm(0x2001_0db8_0000_0000_0000_0000_0000_0004)!! == 1);
    assert(sg_list.do_lpm(0x2001_0db8_0000_0000_0000_0000_0000_0007)!! == 1);
    assert(sg_list.do_lpm(0x2001_0db8_0000_0000_0000_0000_0000_0008)!! == 2);
    assert(sg_list.do_lpm(0x2001_0db8_0000_0000_0000_0000_0000_000f)!! == 2);
    assert(@catch(sg_list.do_lpm(0x2001_0db7_ffff_ffff_ffff_ffff_ffff_ffff)) == common::MISSING);
    assert(@catch(sg_list.do_lpm(0x2001_0db8_0000_0000_0000_0000_0000_0010)) == common::MISSING);
}
