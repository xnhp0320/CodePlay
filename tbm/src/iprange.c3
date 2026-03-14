module iprange <KeyType>;

import std::collections::range;
import std::collections::list;
import tbmlib::cidr;
import tbmlib::common;

typedef IpRange = inline range::Range {KeyType};

fn usz? IpRange.to_format(&self, Formatter *f) @dynamic {
    return f.printf("[%x %x]", self.start, self.end);
}

alias Cidr @private = cidr::Cidr {KeyType};

<* @require common::@cidr_valid(cidr)
*>
fn IpRange iprange_from_cidr(Cidr cidr) {
    IpRange self;
    self.start = cidr.ip;
    if (cidr.cidr < $typeof(cidr.ip).sizeof * 8) {
        self.end = cidr.ip | (((KeyType)1 << ($typeof(cidr.ip).sizeof * 8 - cidr.cidr)) - 1);
    } else {
        self.end = cidr.ip;
    }

    return self;
}

fn Cidr cidr_from_iprange(IpRange r) {
    return { .ip = r.start, .cidr = (uint)(KeyType.sizeof * 8 - (r.end - r.start).popcount()) };
}

alias IpRangeList = List {IpRange};

import std::io;
import std::io::file;
import std::net;
import std::sort;
import std::collections::priorityqueue;

fn bool IpRange.less(&self, IpRange other) {
    return self.start < other.start; 
}

fn void? load_ipv4_rangelist(Allocator alloc, String filename, IpRangeList *rl) {
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

alias IdxList = List {uint};

fn uint pick_winner(IdxList *idx_list, IpRangeList *rl) {
    uint prefixlen = cidr_from_iprange(rl.[idx_list.[0]]).cidr;
    uint winner = idx_list.[0];
    foreach (idx : idx_list.array_view()[1 .. ]) {
        Cidr c = cidr_from_iprange(rl.[idx]);
        if (c.cidr > prefixlen) {
            winner = idx;
            prefixlen = c.cidr;
        }
    }
    return winner;
}

struct Seg (Printable) {
    IpRange r;
    uint idx; //points to the original IpRangeList.
}

fn bool Seg.equals(self, Seg other) @operator(==) {
    return self.r.start == other.r.start && self.r.end == other.r.end && self.idx == other.idx;
}

fn usz? Seg.to_format(&self, Formatter *f) @dynamic {
    return f.printf("[%x %x] %s\n", self.r.start, self.r.end, self.idx);
}

struct HeapItem {
    KeyType end;
    uint idx;
}

fn bool HeapItem.less(&self, HeapItem other) {
    return self.end < other.end;
}

alias Heap = PriorityQueue {HeapItem};
alias SegList = List {Seg};

fn uint? SegList.do_lpm(&self, KeyType ip) {
    if (self.len() == 0) {
        return common::MISSING~;
    }

    isz lo = 0;
    isz hi = (isz)self.len() - 1;

    while (lo <= hi) {
        isz mid = lo + ((hi - lo) / 2);
        Seg seg = self.[(usz)mid];
        if (ip < seg.r.start) {
            hi = mid - 1;
            continue;
        }
        if (ip > seg.r.end) {
            lo = mid + 1;
            continue;
        }
        return seg.idx;
    }

    return common::MISSING~;
}

fn SegList? IpRangeList.build_segs(&self) {

    List{uint} in_heap;
    in_heap.init(mem);
    defer in_heap.free();

    Heap h;
    h.init(mem);
    defer h.free();
    quicksort(self);

    h.push({self.[0].end, 0});
    KeyType start = self.[0].start;
    in_heap.push(0);

    SegList sg_list;
    sg_list.init(mem);

    uint idx = 1;
    while OUTER: (idx < self.len()) {
        KeyType curr_start = self.[idx].start;

        while (start <= curr_start) {
            if (curr_start == start) {
                //do not generate segs.
                in_heap.push(idx);
                h.push({self.[idx].end, idx});
                idx++;
                continue OUTER;
            }

            if (h.len() == 0) {
                start = curr_start;
                in_heap.push(idx);
                h.push({self.[idx].end, idx});
                idx++;
                continue OUTER;
            }

            //curr_start > start
            HeapItem top = h.first()!;
            if (curr_start <= top.end) {
                //[start, curr_start], [curr_start + 1, ..]
                uint winner = pick_winner(&in_heap, self);
                sg_list.push({.r = {start, curr_start - 1}, .idx = winner });
                start = curr_start;
                in_heap.push(idx);
                h.push({self.[idx].end, idx});
                idx ++;
                continue OUTER;
            } else {
                while (h.len() > 0 && curr_start > h.first()!.end) {
                    top = h.first()!;
                    if (top.end >= start) {
                        uint winner = pick_winner(&in_heap, self);
                        sg_list.push({.r = {start, top.end}, .idx = winner });
                        start = top.end + 1;
                    }
                    top = h.pop()!;
                    in_heap.remove_item(top.idx);
                }
            }
        }
    }

    //start should be the last range's start
    assert (start == self.array_view()[^1].start);
    HeapItem top;
    while (h.len() > 0) {
        top = h.first()!;
        if (top.end >= start) {
            uint winner = pick_winner(&in_heap, self);
            sg_list.push({.r = {start, top.end}, .idx = winner });
            start = top.end + 1;
        }
        top = h.pop()!;
        in_heap.remove_item(top.idx);
    }
    return sg_list;
}
