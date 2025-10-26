module tbm;
import tbmlib::bitmap;
import iprange;
import std::io;


fn int main(String[] args)
{
    IpRangeList rl;
    rl.init(mem);
    iprange::load_rangelist(mem, "ipv4_fib.txt", &rl)!!; 
    rl.sort();

    foreach(r : rl) {
        io::printf("%s\n", iprange::cidr_from_iprange(r));
    }

	return 0;
}
