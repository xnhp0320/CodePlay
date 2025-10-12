module tbmlib::common;
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

macro @foreach_1bit(bm; @body(pos)) {
    while (bm != 0) {
        uint pos = (uint)bm.ctz();
        @body(pos);
        bm = bm & (bm - 1);
    }
}

<*
@require STRIDE >= 3 && STRIDE <= 7
*>
module tbmlib::bitmap {STRIDE};
import tbmlib::common;
import std::io;
const typeid[*] BITMAP_TYPES @private = { char, ushort, uint, ulong, uint128 };
typedef BitmapType = inline $typefrom(BITMAP_TYPES[STRIDE - 3]);
alias stride_mask @private = tbmlib::common::stride_mask;
typedef StrideTypeInner = inline char;
bitstruct StrideType : StrideTypeInner {
    StrideTypeInner val : 0 .. STRIDE - 1;
}

bitstruct InlStrideType : StrideTypeInner {
    StrideTypeInner val : 0 .. STRIDE - 2;
}

const BITMAP_WIDTH = (1 << STRIDE);
const INL_STRIDE = STRIDE - 1;

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
   @require #len >= 0 && #len < STRIDE
   @ensure return >= 0 && return <= (1 << STRIDE) - 2
*>
macro @inl_bitpos(uint #prefix, uint #len) {
    return ((1u << #len) - 1) + #prefix;
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
        return BITMAP_WIDTH - 1 - (usz)check.clz();
    }
    return tbmlib::common::MISSING?;
}

fn usz? BitmapType.check_exl_bitmap(self, StrideType prefix) {
    BitmapType check = self & ((BitmapType)1 << prefix.val);
    if (check != 0) {
        return (usz)self.count_bits(prefix.val);
    }
    return tbmlib::common::MISSING?;
}

macro @shift_cidr(#cidr) {
    #cidr.ip <<= STRIDE;
    #cidr.cidr -= STRIDE;
}

<* @require $defined(#cidr.ip) && $defined(#cidr.cidr) : `Expect anything with .ip and .cidr is defined`
   @require $typeof(#cidr).kindof == TypeKind.POINTER
   @require #cidr.cidr >= STRIDE
*>
macro StrideType @cidr_shift(#cidr) {
    defer @shift_cidr(#cidr);
    return {(StrideTypeInner) ((#cidr.ip & stride_mask($typeof(#cidr.ip), STRIDE)) >> ($typeof(#cidr.ip).sizeof * 8 - STRIDE))};
}

fn void InlStrideType.from(&self, StrideType stride) {
    *self = { stride.val >> 1 };
}

//Tree bitmap Node def
struct TbmNode {
    BitmapType external;
    bitstruct : BitmapType {
        BitmapType internal : 0 .. BITMAP_WIDTH - 2;
    }
    void *next;
}

fn TbmNode* TbmNode.next_exl(&self, StrideType stride) {
    usz offset = self.external.check_exl_bitmap(stride)!!;
    return (TbmNode*)self.next + offset;
}

fn usz TbmNode.count_exl_nodes(&self) {
    return (usz)self.external.popcount();
}

typedef TrivalAllocator (TbmAllocator) = uptr;
fn void*? TrivalAllocator.alloc(&self, usz nodes_count) @dynamic {
    return calloc(nodes_count * TbmNode.sizeof);
}
fn void TrivalAllocator.free(&self, void *ptr) @dynamic {
    return free(ptr);
}

typedef TempTbmAllocator (TbmAllocator) = uptr;
fn void*? TempTbmAllocator.alloc(&self, usz nodes_count) @dynamic {
    return tcalloc(nodes_count * TbmNode.sizeof);
}

fn void TempTbmAllocator.free(&self, void *ptr) @dynamic {

}


module tbmlib::cidr {KeyType};
import std::io;

struct Cidr (Printable) {
    KeyType ip;
    uint cidr;
}

fn usz? Cidr.to_format(&self, Formatter *f) @dynamic {
    var $fmt = @sprintf("0x%%0%sx", KeyType.sizeof * 2);
    return f.printf($fmt +++ "/%d", self.ip, self.cidr);
}

<*
@require STRIDE >= 3 && STRIDE <= 7
@require KeyType.sizeof <= 16
@require ValueType.sizeof <= 8 : `Too large ValueType, maybe use a pointer?`
*>
module tbmlib {STRIDE, KeyType, ValueType};
import std::io;
import tbmlib::common;
import tbmlib::bitmap;

alias @remove_wildcard @private = tbmlib::common::@remove_wildcard;
alias stride_mask @private = tbmlib::common::stride_mask;

alias BITMAP_WIDTH @private = tbmlib::bitmap::BITMAP_WIDTH {STRIDE};
alias INL_STRIDE @private = tbmlib::bitmap::INL_STRIDE {STRIDE};
alias INL_CHECK_MAP @private = tbmlib::bitmap::INL_CHECK_MAP {STRIDE};
alias @bitmap_set @private = tbmlib::bitmap::@bitmap_set {STRIDE};
alias @inl_bitpos @private = tbmlib::bitmap::@inl_bitpos {STRIDE};
alias BitmapType @private = tbmlib::bitmap::BitmapType {STRIDE};
alias StrideType @private = tbmlib::bitmap::StrideType {STRIDE};
alias InlStrideType @private = tbmlib::bitmap::InlStrideType {STRIDE};
alias StrideTypeInner @private = tbmlib::bitmap::StrideTypeInner {STRIDE};
alias Cidr @private = tbmlib::cidr::Cidr {KeyType};
alias TbmNode @private = tbmlib::bitmap::TbmNode {STRIDE};
alias @cidr_shift @private = tbmlib::bitmap::@cidr_shift {STRIDE};

const ROUTE_NUM = TbmNode.sizeof / ValueType.sizeof;
$assert(TbmNode.sizeof >= ValueType.sizeof);

struct TbmValueNode {
    ValueType[ROUTE_NUM] values;
    //make sure the TbmRouteNode size equals to TbmNode
    char[TbmNode.sizeof % ValueType.sizoef] __pad @if(TbmNode.sizeof % ValueType.sizeof != 0);
}

struct TbmValueIter {
    TbmValueNode *node;
    usz inside_idx;
}

fn TbmValueIter TbmValueNode.values_iter(&self) {
    return { self - 1, 0 };
}

fn ValueType *TbmValueIter.next(&self) {
    uint *ret = &self.node.values[self.inside_idx];
    self.inside_idx ++;
    if (self.inside_idx == ROUTE_NUM) {
        self.node --;
        self.inside_idx = 0;
    }
    return ret;
}

struct Tbm {
    TbmNode root;
    TbmAllocator alloc;
}

macro StrideType @key_shift(KeyType #ip) {
    defer #ip <<= STRIDE;
    return {(StrideTypeInner)((#ip & stride_mask($typeof(#ip), STRIDE)) >> ($typeof(#ip).sizeof * 8 - STRIDE))};
}

fn usz TbmNode.count_inl_nodes(&self) {
    usz count = (usz)self.internal.popcount();
    return count == 0 ? 0 : (count + ROUTE_NUM) / ROUTE_NUM;
}

fn TbmNode*? TbmNode.insert_exl_node(&self, TbmAllocator alloc, StrideType stride) {
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

fn void? TbmNode.insert_exl(&self, TbmAllocator alloc, Cidr prefix, KeyType v) {
    StrideType stride = @cidr_shift(&prefix);
    BitmapType external = self.external;
    //in case uint128, we have to cast to usz.
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

fn ValueType* TbmNode.get_value(&self, usz pos) {
    usz offset = (usz)self.internal.count_bits(pos);
    usz node_offset = (offset + ROUTE_NUM) / ROUTE_NUM;
    TbmValueNode *node = (TbmValueNode*)self.next - node_offset;
    return &node.values[offset % ROUTE_NUM];
}

fn void TbmNode.insert_value(&self, TbmValueNode *new, TbmValueNode *old,
                             usz pos, ValueType v) {
    TbmValueIter new_iter = new.values_iter();
    if (old == null) {
        *new_iter.next() = v;
        return;
    }

    usz tot_count = (usz)self.internal.popcount();
    usz before_count = (usz)self.internal.count_bits(pos);
    usz copy_count;
    TbmValueIter old_iter = old.values_iter();
    while (copy_count < before_count) {
        *new_iter.next() = *old_iter.next();
        copy_count ++;
    }
    *new_iter.next() = v;
    copy_count ++;
    while (copy_count < tot_count + 1) {
        *new_iter.next() = *old_iter.next();
        copy_count ++;
    }
}

fn void? TbmNode.insert_inl(&self, TbmAllocator alloc, Cidr prefix, ValueType v) {
    usz prev_count = self.count_inl_nodes();
    BitmapType internal = self.internal;
    uint pos = @inl_bitpos(@remove_wildcard(prefix), prefix.cidr);
    internal = @bitmap_set(internal, pos);
    usz post_count = (usz)(internal.popcount() + ROUTE_NUM) / ROUTE_NUM;
    if (post_count == prev_count) {
        ValueType *value = self.get_value(pos);
        //update
        *value = v;
    } else {
        usz exl_nodes = self.count_exl_nodes();
        void *new_nodes = alloc.alloc(post_count + exl_nodes)!;
        void *new_exl = (TbmNode*)new_nodes + post_count;
        mem::copy(new_exl, self.next, exl_nodes * TbmNode.sizeof);
        self.insert_value((TbmValueNode*)new_nodes + post_count, self.next, pos, v);
        alloc.free((TbmValueNode*)self.next - prev_count);
        self.next = new_exl;
        self.internal = internal;
    }
}
<* @require tbmlib::common::@cidr_valid(prefix)
*>
fn void? TbmNode.insert(&self, TbmAllocator alloc, Cidr prefix, ValueType v) {
    if (prefix.cidr >= STRIDE) {
        return self.insert_exl(alloc, prefix, v);
    } else {
        return self.insert_inl(alloc, prefix, v);
    }
}

fn void? Tbm.insert(&self, Cidr prefix, ValueType v) {
    return self.root.insert(self.alloc, prefix, v);
}
const uint NODE_CACHE_SIZE = (KeyType.sizeof * 8) / STRIDE;

struct SearchCache {
    TbmNode *node;
    StrideType stride;
}

fn ValueType? Tbm.lookup(&self, KeyType ip) {
    TbmNode *node = &self.root;
    SearchCache[NODE_CACHE_SIZE] cache @noinit;
    uint cache_idx;
    StrideType stride @noinit;

    while(1) {
        stride = @key_shift(ip);
        if (try offset = node.external.check_exl_bitmap(stride)) {
            cache[cache_idx ++] = {node, stride};
            node = (TbmNode *)node.next;
        } else {
            InlStrideType inl_stride @noinit;
            inl_stride.from(stride);
            if (try offset = node.internal.check_inl_bitmap(inl_stride)) {
                return *node.get_value(offset);
            } else {
                foreach_r(&c : cache[:cache_idx]) {
                    inl_stride.from(c.stride);
                    if (try offset = c.node.internal.check_inl_bitmap(inl_stride)) {
                        return *node.get_value(offset);
                    }
                }
            }
            break;
        }
    }

    return tbmlib::common::VALUE_NOT_FOUND?;
}

alias Iterator = fn void(Cidr* cidr, ValueType *value, void *aux);
alias @foreach_1bit = tbmlib::common::@foreach_1bit;

fn void TbmNode.iterate(&self, Cidr* cidr, uint depth, Iterator f, void *aux) {
    @foreach_1bit(self.internal; uint pos) {
        //pos -> (prefix, len)
        //remember that we have  ((1 << len) - 1) + prefix = pos
        //since len belongs to [0, STRIDE - 1], we can search from
        //0, 1, 3, 7, 15, ...

        //another way to do this is to plus one to `pos`, then we know
        //that pos + 1 >= (1<<len), so could check the bits by
        //uint.sizeof * 8 - (pos+1).clz() - 1:
        uint len = uint.sizeof * 8 - (pos+1).clz() - 1;
        KeyType prefix = (KeyType)(pos - ((1u << len) - 1));

        Cidr curr_cidr = *cidr;
        curr_cidr.ip |= prefix << (KeyType.sizeof * 8 - depth - len);
        curr_cidr.cidr += (uint)len;
        f(&curr_cidr, self.get_value(pos), aux);
    };

    @foreach_1bit(self.external; uint pos) {
        TbmNode *node = self.next_exl( { (StrideTypeInner) pos } );
        Cidr curr_cidr = *cidr;
        curr_cidr.ip |= pos << (KeyType.sizeof * 8 - depth - STRIDE);
        curr_cidr.cidr += STRIDE;
        node.iterate(&curr_cidr, depth + STRIDE, f, aux);
    };
}

fn void Tbm.iterate(&self, Iterator f, void *aux) {
    Cidr cidr;
    self.root.iterate(&cidr, 0, f, aux);
}

fn void? Tbm.remove(&self, TbmAllocator alloc, Cidr prefix) {

}
