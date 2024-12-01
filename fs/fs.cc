#include <sstream>
#include <iostream>
#include <stdint.h>

class IP;
std::istream& operator >> (std::istream& is, IP &ip);

class IP {
public:
    uint32_t ip;
    IP() : ip(0) {}
    friend std::istream& operator >> (std::istream& is, IP &ip);
};


std::istream& operator >> (std::istream& is, IP &ip)
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
    std::stringstream ss("   192.168.0.1   xx.168.0.3    10.0.0.3");
    IP ip1;
    IP ip2;
    ss >> ip1 >> ip2;
    std::cout << std::hex << ip1.ip <<  " " << ip2.ip << std::endl;
    return 0;
}
