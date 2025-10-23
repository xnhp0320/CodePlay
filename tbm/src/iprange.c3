module iprange;

import std::collections::range;
import tbmlib::cidr;
import tbmlib::common;

alias IpRange = range::Range {uint};
alias Cidr @private = cidr::Cidr {uint};

<* @require common::@cidr_valid(cidr)
*>
fn void IpRange.from_cidr(&self, Cidr cidr) {
    self.start = cidr.ip;
    self.end = cidr.ip | ((1u << cidr.cidr) - 1); 
}


