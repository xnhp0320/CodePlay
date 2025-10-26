module iprange;

import std::collections::range;
import std::collections::list;
import tbmlib::cidr;
import tbmlib::common;

typedef IpRange = inline range::Range {uint};
alias Cidr @private = cidr::Cidr {uint};

<* @require common::@cidr_valid(cidr)
*>
fn IpRange iprange_from_cidr(Cidr cidr) {
    IpRange self;
    self.start = cidr.ip;
    if (cidr.cidr < $typeof(cidr.ip).sizeof * 8) {
        self.end = cidr.ip | ((1u << cidr.cidr) - 1);
    } else {
        self.end = $typeof(cidr.ip).max;
    }

    return self;
}

fn Cidr cidr_from_iprange(IpRange r) {
    return { .ip = r.start, .cidr = (uint)((r.end - r.start).popcount()) };
}

alias IpRangeList = List {IpRange};

import std::io;
import std::io::file;
import std::net;
import std::sort::qs;

fn void? load_rangelist(Allocator alloc, String filename, IpRangeList *rl) {
    File f = file::open(filename, "r")!;
    defer (void)f.close();
    usz idx = 0;
    InetAddress addr;
    while (1) {
        if (try String line = io::readline(alloc, &f)) {
            if (idx % 2 == 0) {
                addr = net::ipv4_from_str(line)!;
            } else {
                uint cidr = line.to_uint()!;
                Cidr c;
                c.from(&addr, cidr);
                rl.push(iprange_from_cidr(c));
            }
        } else {
            break;
        }
        idx ++;
    }
}

fn int range_start_cmp(IpRange a, IpRange b) {
    return a.start >= b.start ? 1 : -1;
}

fn int range_end_cmp(IpRange a, IpRange b) {
    return a.end >= b.end ? 1 : -1;
}

fn void IpRangeList.sort(&self) {
    quicksort(self, &range_start_cmp);
    usz idx = 0;
    usz begin = 0;
    while (idx < self.size) {
        if (self.get(begin).start != self.get(idx).start) {

            if (idx - begin > 1) {
                quicksort(self.entries[begin .. idx - 1], &range_end_cmp);
            }

            begin = idx;
        }
        idx ++;
    }
}

alias CmpFn = fn bool(IpRange, uint);

fn bool less(IpRange r, uint v) @inline {
    return r.start < v;
}

fn bool large(IpRange r, uint v) @inline {
    return v >= r.start;
}

//find the first IpRange where start >= v.
macro usz lower_bound(list, v, CmpFn cmp) {
    usz count = list.size;
    usz first = 0;
    usz it @noinit;
    usz step @noinit;

    while (count > 0) {
        it = first;
        step = count / 2;
        it += step;

        if (cmp(list[it], v)) {
            first = ++it;
            count -= step + 1;
        } else {
            count = step;
        }
    }
    return first;
}

macro usz upper_bound(iplist, v, CmpFn cmp) {
    usz count = iplist.size;
    usz first = 0;
    usz it @noinit;
    usz step @noinit;

    while (count > 0) {
        it = first;
        step = count / 2;
        it += step;

        if (cmp(iplist[it], v)) {
            first = ++it;
            count -= step + 1;
        } else {
            count = step;
        }
    }

    return first;
}


fn void test_lower_bound() @test {
    IpRangeList rl;
    @pool() {
        rl.tinit_with_array( { {0,1}, {0,2}, {2,3}, {2,4}, {2,6} } );

        assert(lower_bound(rl, 1, &less) == 2);
        assert(lower_bound(rl, 2, &less) == 2);
    };
}

fn void test_upper_bound() @test {
    IpRangeList rl;
    @pool() {
        rl.tinit_with_array( { {0,1}, {0,2}, {2,3}, {2,4}, {2,6} } );
        assert(upper_bound(rl, 1, &large) == 2);
        assert(upper_bound(rl, 2, &large) == 5);
    };
}

fn usz IpRangeList.search(&self, uint v) {
}

