module tbmlib_common;
faultdef MISSING;

struct Ipv4Cidr {
    uint ip;
    uint cidr;
}

<* @require $defined(#cidr.ip) && $defined(#cidr.cidr) : `Expect anything with .ip and .cidr is defined`
*>
macro bool @cidr_valid(#cidr) {
    if (#cidr.cidr == 0) {
        return #cidr.ip == 0;
    }

    $typeof(#cidr.ip) mask = $typeof(#cidr.ip).max << ($typeof(#cidr.ip).sizeof * 8 - #cidr.cidr);
    return #cidr.ip & mask == #cidr.ip;
}

interface TbmAllocator {
    fn void*? alloc(usz nodes_count);
    fn void free(void * ptr);
}
