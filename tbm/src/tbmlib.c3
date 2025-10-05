<*
@require STRIDE >= 3 && STRIDE <= 7
*>
module tbmlib {STRIDE};
import std::io;
import tbmlib_common;

const typeid[*] BITMAP_TYPES = { char, ushort, uint, ulong, uint128 };
typedef BitmapType = inline $typefrom(BITMAP_TYPES[STRIDE - 3]);
alias Ipv4Cidr = tbmlib_common::Ipv4Cidr;
typedef StrideTypeInner = inline char;

interface TbmAllocator {
    fn void*? alloc(usz nodes_count);
    fn void free(void * ptr);
}

typedef TrivalAllocator (TbmAllocator) = uptr;

fn void*? TrivalAllocator.alloc(&self, usz nodes_count) @dynamic {
    return calloc(nodes_count * TbmNode.sizeof);
}
fn void TrivalAllocator.free(&self, void *ptr) @dynamic {
    return free(ptr);
}

bitstruct StrideType : StrideTypeInner {
    StrideTypeInner val : 0 .. STRIDE - 1;
}

bitstruct InlStrideType : StrideTypeInner {
    StrideTypeInner val : 0 .. STRIDE - 2;
}

macro stride_mask($Type) {
    var mask = (1u << STRIDE) - 1;
    return ($Type)mask << ($Type.sizeof * 8 - STRIDE);
}

const BITMAP_WIDTH = (1 << STRIDE);
const INL_STRIDE = STRIDE - 1;

//Tree bitmap Node def
struct TbmNode {
    BitmapType external;
    bitstruct : BitmapType {
        BitmapType internal : 0 .. BITMAP_WIDTH - 2;
    }
    void *next;
}

const ROUTE_NUM = TbmNode.sizeof / uint.sizeof;

struct TbmRouteNode {
    uint[ROUTE_NUM] routes;
    //make sure the TbmRouteNode size equals to TbmNode
    char[TbmNode.sizeof % uint.sizoef] __pad @if(TbmNode.sizeof % uint.sizeof != 0);
}

struct Tbm {
    TbmNode root;
    TbmAllocator alloc;
}

<* @require #val < BITMAP_WIDTH
*>
macro @bitmap_set(BitmapType #bitmap, uint #val) {
    return #bitmap | ((BitmapType)1 << #val);
}


// 0/1 -> should be the position 1,
// 00/2 -> should be the position 3.
// 111/3 -> should be the position 14.
// this is for STRIDE == 4.
// The return value should in [0, (1 << STRIDE) - 2].

<* @require #prefix < (1 << (STRIDE - 1))
   @require #cidr >= 0 && #cidr < STRIDE
   @ensure return >= 0 && return <= (1 << STRIDE) - 2
*>
macro @inl_bitpos(uint #prefix, uint #cidr) {
    return ((1u << #cidr) - 1) + #prefix;
}

const BitmapType[1<<(STRIDE-1)] INL_CHECK_MAP = gen_inl_check_map();

macro gen_inl_check_map() {
    BitmapType[1<<(STRIDE-1)] $map;

    $for var $prefix = 0u; $prefix < (1 << (STRIDE - 1)); $prefix++:
        BitmapType $check_bitmap;
        var $p = $prefix;
        $for var $len = STRIDE - 1; $len >= 0; $len --:
            var $pos = @inl_bitpos($p, $len);
            $check_bitmap = @bitmap_set($check_bitmap, $pos);
            $p >>= 1;
        $endfor;
        $map[$prefix] = $check_bitmap;
    $endfor;
    return $map;
}

fn void? print_inl_check_map(OutStream out) @maydiscard {
    var $stride = @sprintf("0%s", STRIDE - 1);
    var $bitmap_width = @sprintf("0%s", BITMAP_WIDTH);
    foreach(i, v : INL_CHECK_MAP) {
        io::fprintf(out, "0b%" +++ $stride +++ "b ---> 0b%" +++ $bitmap_width +++"b\n",
                    i, v)!;
    }
}

<* @require offset < BITMAP_WIDTH
*>
macro BitmapType.count_bits(self, usz offset) {
    return $$popcount(self & (((BitmapType)1 << offset) - 1));
}

fn usz? BitmapType.check_inl_bitmap(self, InlStrideType prefix) {
    BitmapType check = INL_CHECK_MAP[prefix.val] & self;
    if (check != 0) {
        usz offset = BITMAP_WIDTH - 1 - (usz)$$clz(check);
        return (usz)check.count_bits(offset) + 1;
    }
    return tbmlib_common::MISSING?;
}

fn usz? BitmapType.check_exl_bitmap(self, StrideType prefix) {
    BitmapType check = self & ((BitmapType)1 << prefix.val);
    if (check != 0) {
        return (usz)self.count_bits(prefix.val);
    }
    return tbmlib_common::MISSING?;
}

macro StrideType.@from(&self, #cidr) {
    *self = {(StrideTypeInner)((#cidr.ip & stride_mask($typeof(#cidr.ip))) >> ($typeof(#cidr.ip).sizeof * 8 - STRIDE))};
    #cidr.ip <<= STRIDE;
    #cidr.cidr -= STRIDE;
}

fn void InlStrideType.from(&self, StrideType stride) {
    *self = { stride.val >> 1 };
}

fn TbmNode* TbmNode.next_exl(self, StrideType stride) {
    usz offset = self.external.check_exl_bitmap(stride)!!;
    return (TbmNode*)self.next + offset;
}

fn usz TbmNode.count_inl_nodes(self) {
    usz count = (usz)self.internal.popcount();
    return count == 0 ? 0 : (count + ROUTE_NUM) / ROUTE_NUM;
}

fn usz TbmNode.count_exl_nodes(self) {
    return (usz)self.external.popcount();
}

fn TbmNode*? TbmNode.insert_exl_node(&self, TbmAllocator alloc, StrideType stride) {
    //in case uint128, we have to cast to usz.
    usz tot_exl_count = self.count_exl_nodes();
    usz tot_inl_count = self.count_inl_nodes();
    usz before_exl_count = (usz)self.external.count_bits(stride.val);

    TbmNode *new_node = alloc.alloc(tot_exl_count + tot_inl_count + 1)!;
    TbmNode *copy_start = (TbmNode *)self.next - tot_inl_count;
    mem::copy(new_node, copy_start, (tot_inl_count + before_exl_count) * TbmNode.sizeof);

    copy_start += tot_inl_count + before_exl_count;
    TbmNode *new_after = new_node + tot_inl_count + before_exl_count + 1;
    mem::copy(new_after, copy_start, (tot_exl_count - before_exl_count) * TbmNode.sizeof);

    self.external = @bitmap_set(self.external, stride.val);
    alloc.free(self.next);
    self.next = new_node + tot_inl_count;
    return new_after - 1;
}

fn void? TbmNode.insert_exl(&self, TbmAllocator alloc, Ipv4Cidr prefix, uint v) {
    StrideType stride @noinit;
    stride.@from(&prefix);
    BitmapType external = self.external;
    usz prev_count = (usz)external.popcount();
    external = @bitmap_set(external, stride.val);
    usz post_count = (usz)external.popcount();
    if (post_count == prev_count) {
        return self.next_exl(stride).insert(alloc, prefix, v);
    } else {
        TbmNode *node = self.insert_exl_node(alloc, stride)!;
        return node.insert(alloc, prefix, v);
    }
}

fn uint* TbmNode.get_value(self, usz pos) {
    usz offset = (usz)self.internal.count_bits(pos);
    usz node_offset = (offset + ROUTE_NUM) / ROUTE_NUM;
    TbmRouteNode *node = (TbmRouteNode*)self.next - node_offset;
    return &node.routes[offset % ROUTE_NUM];
}

fn void TbmNode.insert_route(self, TbmRouteNode *new, TbmRouteNode *old, usz pos, uint v) {
    usz tot_count = (usz)self.internal.popcount();
    usz before_count = (usz)self.internal.count_bits(pos);
    usz copy_to_count;
    usz copy_from_count;
    TbmRouteNode *copy_to_node = new - 1;
    TbmRouteNode *copy_from_node = old - 1;
    usz copy_to_inside_count @noinit;
    usz copy_from_inside_count @noinit;
    while (copy_to_count < before_count) {
        copy_to_inside_count = copy_to_count % ROUTE_NUM;
        copy_from_inside_count = copy_from_count % ROUTE_NUM;
        copy_to_node.routes[copy_to_inside_count] = copy_from_node.routes[copy_from_inside_count];
        copy_to_count ++;
        copy_from_count ++;
        if (copy_to_count % ROUTE_NUM == 0) {
            copy_to_node --;
        }
        if (copy_from_count % ROUTE_NUM == 0) {
            copy_from_node --;
        }
    }

    copy_to_inside_count = copy_to_count % ROUTE_NUM;
    copy_to_node.routes[copy_to_inside_count] = v;
    copy_to_count ++;

    while (copy_to_count < tot_count + 1) {
        copy_to_inside_count = copy_to_count % ROUTE_NUM;
        copy_from_inside_count = copy_from_count % ROUTE_NUM;
        copy_to_node.routes[copy_to_inside_count] = copy_from_node.routes[copy_from_inside_count];
        copy_to_count ++;
        copy_from_count ++;
        if (copy_to_count % ROUTE_NUM == 0) {
            copy_to_node --;
        }
        if (copy_from_count % ROUTE_NUM == 0) {
            copy_from_node --;
        }
    }
}

fn void? TbmNode.insert_inl(&self, TbmAllocator alloc, Ipv4Cidr prefix, uint v) {
    usz prev_count = self.count_inl_nodes();
    BitmapType internal = self.internal;
    uint pos = @inl_bitpos(prefix.ip, prefix.cidr);
    internal = @bitmap_set(internal, pos);
    usz post_count = (usz)(internal.popcount() + ROUTE_NUM) / ROUTE_NUM;
    if (post_count == prev_count) {
        uint *value = self.get_value(pos);
        //update
        *value = v;
    } else {
        usz exl_nodes = self.count_exl_nodes();
        void *new_nodes = alloc.alloc(post_count + exl_nodes)!;
        void *new_exl = (TbmRouteNode*)new_nodes + post_count;
        mem::copy(new_exl, self.next, exl_nodes * TbmNode.sizeof);
        self.insert_route((TbmRouteNode*)new_nodes + post_count, self.next, pos, v);
        alloc.free((TbmRouteNode*)self.next - prev_count);
        self.next = new_exl;
        self.internal = internal;
    }
}

fn void? TbmNode.insert(&self, TbmAllocator alloc, Ipv4Cidr prefix, uint v) {
    if (prefix.cidr >= STRIDE) {
        return self.insert_exl(alloc, prefix, v);
    } else {
        return self.insert_inl(alloc, prefix, v);
    }
}

fn void? Tbm.insert(&self, Ipv4Cidr prefix, uint v) {
    return self.root.insert(self.alloc, prefix, v);
}
