module tbmlib::bitmap_slab <NodeType>;

const usz BITS_PER_WORD = ulong.sizeof * 8;
const usz SEGMENT_CACHE_SIZE = 32;

struct FreeSegment {
    usz offset;
    usz len;
}

struct BitmapSlabStats {
    usz alloc_requests;
    usz alloc_cache_hits;
    usz bitmap_fallback_scans;
    usz free_requests;
}

fn double BitmapSlabStats.cache_hit_ratio(&self) {
    if (self.alloc_requests == 0) {
        return 0.0;
    }
    return (double)self.alloc_cache_hits / self.alloc_requests;
}

struct BitmapSlab {
    NodeType[] storage;
    ulong[] bitmap;
    usz free_nodes;
    usz cache_entries;
    BitmapSlabStats stats;
    FreeSegment[SEGMENT_CACHE_SIZE] segment_cache;
}

fn void BitmapSlab.init(&self, usz total_nodes) {
    self.release();
    if (total_nodes == 0) {
        return;
    }

    self.storage = mem::new_array(NodeType, total_nodes);
    usz bitmap_words = (total_nodes + BITS_PER_WORD - 1) / BITS_PER_WORD;
    self.bitmap = mem::alloc_array(ulong, bitmap_words);
    
    foreach (&bm : self.bitmap) {
        *bm = ulong.max;
    }

    usz tail = total_nodes % BITS_PER_WORD;
    if (tail != 0) {
        self.bitmap[^1] = ((ulong)1 << tail) - 1;
    }

    self.free_nodes = total_nodes;
    self.cache_entries = 1;
    self.stats = {};
    self.segment_cache[0] = { 0, total_nodes };
}

fn void BitmapSlab.release(&self) {
    free(self.storage);
    free(self.bitmap);
    self.storage = {};
    self.bitmap = {};
    self.free_nodes = 0;
    self.cache_entries = 0;
    self.stats = {};
}

fn bool BitmapSlab.bit_is_free(&self, usz offset) {
    assert(offset < self.storage.len);
    usz word_idx = offset / BITS_PER_WORD;
    usz bit_idx = offset % BITS_PER_WORD;
    return (self.bitmap[word_idx] & ((ulong)1 << bit_idx)) != 0;
}

fn bool BitmapSlab.range_matches(&self, usz offset, usz node_count, bool want_free) {
    assert(offset + node_count <= self.storage.len);
    usz i = 0;
    while (i < node_count) {
        if (self.bit_is_free(offset + i) != want_free) {
            return false;
        }
        i++;
    }
    return true;
}

fn void BitmapSlab.set_range(&self, usz offset, usz node_count, bool mark_free) {
    assert(offset + node_count <= self.storage.len);
    usz i = 0;
    while (i < node_count) {
        usz bit_offset = offset + i;
        usz word_idx = bit_offset / BITS_PER_WORD;
        usz bit_idx = bit_offset % BITS_PER_WORD;
        ulong bit = (ulong)1 << bit_idx;
        if (mark_free) {
            self.bitmap[word_idx] |= bit;
        } else {
            self.bitmap[word_idx] &= ~bit;
        }
        i++;
    }
}

fn void BitmapSlab.clear_range(&self, usz offset, usz node_count) {
    char *bytes = (char*)(&self.storage[offset]);
    usz total_bytes = node_count * NodeType.sizeof;
    mem::clear(bytes, total_bytes);
}

fn void BitmapSlab.cache_remove(&self, usz idx) {
    assert(idx < self.cache_entries);
    usz i = idx;
    while (i + 1 < self.cache_entries) {
        self.segment_cache[i] = self.segment_cache[i + 1];
        i++;
    }
    self.cache_entries--;
}

fn isz BitmapSlab.find_cache_fit(&self, usz node_count) {
    isz best = -1;
    usz best_len = 0;
    usz i = 0;
    while (i < self.cache_entries) {
        FreeSegment seg = self.segment_cache[i];
        if (seg.len >= node_count && (best < 0 || seg.len < best_len)) {
            best = (isz)i;
            best_len = seg.len;
        }
        i++;
    }
    return best;
}

fn void BitmapSlab.cache_insert(&self, usz offset, usz node_count) {
    if (node_count == 0) {
        return;
    }

    usz start = offset;
    usz end = offset + node_count;
    usz i = 0;
    while (i < self.cache_entries) {
        FreeSegment seg = self.segment_cache[i];
        usz seg_end = seg.offset + seg.len;
        if (!(end < seg.offset || seg_end < start)) {
            if (seg.offset < start) {
                start = seg.offset;
            }
            if (seg_end > end) {
                end = seg_end;
            }
            self.cache_remove(i);
            continue;
        }
        i++;
    }

    FreeSegment merged = { start, end - start };
    if (self.cache_entries < SEGMENT_CACHE_SIZE) {
        self.segment_cache[self.cache_entries++] = merged;
        return;
    }

    usz smallest_idx = 0;
    usz smallest_len = self.segment_cache[0].len;
    i = 1;
    while (i < self.cache_entries) {
        if (self.segment_cache[i].len < smallest_len) {
            smallest_idx = i;
            smallest_len = self.segment_cache[i].len;
        }
        i++;
    }
    if (merged.len > smallest_len) {
        self.segment_cache[smallest_idx] = merged;
    }
}

fn usz BitmapSlab.bitmap_scan(&self, bool target, usz start, usz end) {
    if (start >= end) {
        return end;
    }

    usz word_idx = start / BITS_PER_WORD;
    ulong unit = target ? self.bitmap[word_idx] : ~self.bitmap[word_idx];
    unit >>= start % BITS_PER_WORD;
    if (unit == 0) {
        start -= start % BITS_PER_WORD;
        start += BITS_PER_WORD;
        word_idx++;

        while (start < end) {
            unit = target ? self.bitmap[word_idx] : ~self.bitmap[word_idx];
            if (unit != 0) {
                break;
            }
            start += BITS_PER_WORD;
            word_idx++;
        }
        if (start >= end) {
            return end;
        }
    }

    start += (usz)unit.ctz();
    return start < end ? start : end;
}

fn bool BitmapSlab.find_bitmap_fit(&self, usz node_count, usz *offset_out, usz *run_len) {
    self.stats.bitmap_fallback_scans++;
    usz search = 0;
    while (search < self.storage.len) {
        usz run_start = self.bitmap_scan(true, search, self.storage.len);
        if (run_start == self.storage.len) {
            return false;
        }

        usz run_end = self.bitmap_scan(false, run_start, self.storage.len);
        usz found_len = run_end - run_start;
        if (found_len >= node_count) {
            *offset_out = run_start;
            *run_len = found_len;
            return true;
        }
        search = run_end;
    }

    return false;
}

fn usz BitmapSlab.ptr_offset(&self, void *ptr) {
    uptr start = (uptr)self.storage.ptr;
    uptr addr = (uptr)ptr;
    assert(addr >= start);
    assert(addr < start + self.storage.len * NodeType.sizeof);
    assert((addr - start) % NodeType.sizeof == 0);
    return (addr - start) / NodeType.sizeof;
}

fn void*? BitmapSlab.alloc(&self, usz node_count) {
    if (node_count == 0) {
        return null;
    }

    if (node_count > self.free_nodes) {
        return mem::OUT_OF_MEMORY~; 
    }

    self.stats.alloc_requests++;
    usz offset;
    usz run_len;
    isz cached_idx = self.find_cache_fit(node_count);
    if (cached_idx >= 0) {
        self.stats.alloc_cache_hits++;
        offset = self.segment_cache[(usz)cached_idx].offset;
        assert(self.range_matches(offset, node_count, true));
        self.segment_cache[(usz)cached_idx].offset += node_count;
        self.segment_cache[(usz)cached_idx].len -= node_count;
        if (self.segment_cache[(usz)cached_idx].len == 0) {
            self.cache_remove((usz)cached_idx);
        }
    } else {
        bool found = self.find_bitmap_fit(node_count, &offset, &run_len);
        if (!found) {
            return mem::OUT_OF_MEMORY~;
        }
        assert(self.range_matches(offset, node_count, true));
        if (run_len > node_count) {
            self.cache_insert(offset + node_count, run_len - node_count);
        }
    }

    self.set_range(offset, node_count, false);
    self.clear_range(offset, node_count);
    self.free_nodes -= node_count;
    return &self.storage[offset];
}

fn void BitmapSlab.free(&self, void *ptr, usz node_count) {
    if (ptr == null || node_count == 0) {
        return;
    }

    self.stats.free_requests++;
    usz offset = self.ptr_offset(ptr);
    assert(offset + node_count <= self.storage.len);
    assert(self.range_matches(offset, node_count, false));

    self.set_range(offset, node_count, true);
    self.free_nodes += node_count;
    self.cache_insert(offset, node_count);
}
