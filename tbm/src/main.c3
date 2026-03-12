module tbm;
import tbmlib::bitmap;
import iprange;
import std::io;


fn int main(String[] args)
{
    IpRangeList{uint} rl;
    rl.init(mem);
    iprange::load_rangelist {uint}(mem, "ipv4_fib.txt", &rl)!!; 

    foreach(r : rl) {
        io::printf("%s\n", iprange::cidr_from_iprange {uint}(r));
    }

	return 0;
}
