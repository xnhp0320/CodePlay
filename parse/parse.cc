#include <boost/parser/parser.hpp>
#include <string>
#include <vector>


namespace bp = boost::parser;

int main() {

    std::string input = "aa:bb:cc:dd:ee:ff";
    constexpr auto parse_oct = bp::repeat(2)[bp::hex_digit];
    constexpr auto parse_mac = bp::string_view[parse_oct >> bp::repeat(5)[':' >> parse_oct]];
    
    auto str = bp::parse(input, parse_mac, bp::ws, bp::trace::on);
    std::cout << *str << std::endl;
} 
