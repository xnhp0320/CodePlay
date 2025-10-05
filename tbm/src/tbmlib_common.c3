module tbmlib_common;
faultdef MISSING;

struct Ipv4Cidr {
    uint ip;
    uint cidr;
}

interface TbmAllocator {
    fn void*? alloc(usz nodes_count);
    fn void free(void * ptr);
}
