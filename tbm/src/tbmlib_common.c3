module tbmlib_common;
faultdef MISSING, VALUE_NOT_FOUND;

<* @require $defined(#cidr.ip) && $defined(#cidr.cidr) : `Expect anything with .ip and .cidr is defined`
*>
macro bool @cidr_valid(#cidr) {
    if (#cidr.cidr == 0) {
        return #cidr.ip == 0;
    }

    $typeof(#cidr.ip) mask = $typeof(#cidr.ip).max << ($typeof(#cidr.ip).sizeof * 8 - #cidr.cidr);
    return #cidr.ip & mask == #cidr.ip;
}

//change prefix form: 0xc0000000/2 into the form: 0b11/2, it's like remove the wildcards.
<* @require $defined(#cidr.ip) && $defined(#cidr.cidr) : `Expect anything with .ip and .cidr is defined`
*>
macro @remove_wildcard(#cidr) {
    return #cidr.cidr == 0 ? 0 : (uint)(#cidr.ip >> ($typeof(#cidr.ip).sizeof * 8 - #cidr.cidr));
}

macro stride_mask($Type, shift) {
    var mask = (1u << shift) - 1;
    return ($Type)mask << ($Type.sizeof * 8 - shift);
}

interface TbmAllocator {
    fn void*? alloc(usz nodes_count);
    fn void free(void * ptr);
}
