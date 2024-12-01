#include <sstream>
#include <iostream>
#include <stdint.h>
#include <fmt/format.h>

class IPAddress;
std::istream& operator >> (std::istream& is, IPAddress &ip);

class IPAddress {
public:
    uint32_t ip;
    IPAddress() : ip(0) {}
    friend std::istream& operator >> (std::istream& is, IPAddress &ip);

    std::string toString() {
        return fmt::format("{}.{}.{}.{}",
                            (ip & 0xff000000) >> 24,
                            (ip & 0x00ff0000) >> 16,
                            (ip & 0x0000ff00) >> 8,
                            (ip & 0x000000ff) >> 0);
    }
};


std::istream& operator >> (std::istream& is, IPAddress &ip)
{
    std::istream::sentry s(is, true);
    if (s) {
        uint32_t v = 0;
        int oct_count = 0;

        int oct;
        if (is >> oct) {
            v = (v << 8) | oct;
        } else {
            is.setstate(std::istream::failbit);
            return is;
        }

        do {
            if (is.peek() == '.') {
                is.ignore(1);
                oct_count ++;
            } else {
                is.setstate(std::istream::failbit);
                return is;
            }
            //cannot use uint8_t, as uint8_t is a char.
            //it will only read a char, not a int.
            
            if (is >> oct) {
                v = (v << 8) | oct;
            } else {
                is.setstate(std::istream::failbit);
                return is;
            }
        } while (is.good() && oct_count < 3);

        ip.ip = v;
    }
    return is;
}

int main() {
    std::stringstream ss("   192.168.0.1   192.168.0.3    10.0.0.3");
    IPAddress ip1;
    IPAddress ip2;
    ss >> ip1 >> ip2;
    fmt::print("{} {}\n", ip1.toString(), ip2.toString());
    return 0;
}
