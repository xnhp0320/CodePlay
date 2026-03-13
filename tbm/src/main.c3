module tbm;

import tbmlib;
import tbmlib::cidr;
import std::io;
import std::io::file;
import std::net;

alias FibCidr = cidr::Cidr {uint};

fn usz? load_ipv4_fib_tbm(Allocator alloc, String filename, Tbm *tbm) <Tbm> {
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

macro gen_stride_report($s) {
    Tbm{$s, uint, FibCidr} tbm;
    TrivalAllocator{$s, uint, FibCidr} alloc;
    tbm.alloc = &alloc;

    usz rules = load_ipv4_fib_tbm{Tbm{$s, uint, FibCidr}}(mem, "ipv4_fib.txt", &tbm)!!;
    io::printf("fib=%s stride=%d %s\n", rules, $s, tbm.memory_stats());
}

macro report_all_stride_memory() {
    $for var $s = 3; $s <= 7; $s++:
        { gen_stride_report($s); }
    $endfor;
}

fn int main(String[] args) {
    report_all_stride_memory();
    return 0;
}
