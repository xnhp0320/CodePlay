module tbmlib::bitmap_slab <NodeType>;

const usz BITS_PER_WORD = ulong.sizeof * 8;
const usz SEGMENT_CACHE_SIZE = 32;

struct FreeSegment {
    usz offset;
    usz len;
}

struct BitmapSlab {
    NodeType *storage;
    ulong *bitmap;
    usz total_nodes;
    usz free_nodes;
    usz bitmap_words;
    usz cache_entries;
    FreeSegment[SEGMENT_CACHE_SIZE] segment_cache;
}

fn bool BitmapSlab.init(&self, usz total_nodes) {
    self.release();
    if (total_nodes == 0) {
        return false;
    }

    self.storage = (NodeType*)calloc(total_nodes * NodeType.sizeof);
    if (self.storage == null) {
        return false;
    }

    self.bitmap_words = (total_nodes + BITS_PER_WORD - 1) / BITS_PER_WORD;
    self.bitmap = (ulong*)calloc(self.bitmap_words * ulong.sizeof);
    if (self.bitmap == null) {
        free(self.storage);
        self.storage = null;
        self.bitmap_words = 0;
        return false;
    }

    usz i = 0;
    while (i < self.bitmap_words) {
        self.bitmap[i] = ulong.max;
        i++;
    }
    usz tail = total_nodes % BITS_PER_WORD;
    if (tail != 0) {
        self.bitmap[self.bitmap_words - 1] = ((ulong)1 << tail) - 1;
    }

    self.total_nodes = total_nodes;
    self.free_nodes = total_nodes;
    self.cache_entries = 1;
    self.segment_cache[0] = { 0, total_nodes };
    return true;
}

fn void BitmapSlab.release(&self) {
    if (self.storage != null) {
        free(self.storage);
    }
    if (self.bitmap != null) {
        free(self.bitmap);
    }
    self.storage = null;
    self.bitmap = null;
    self.total_nodes = 0;
    self.free_nodes = 0;
    self.bitmap_words = 0;
    self.cache_entries = 0;
}

fn bool BitmapSlab.bit_is_free(&self, usz offset) {
    assert(offset < self.total_nodes);
    usz word_idx = offset / BITS_PER_WORD;
    usz bit_idx = offset % BITS_PER_WORD;
    return (self.bitmap[word_idx] & ((ulong)1 << bit_idx)) != 0;
}

fn bool BitmapSlab.range_matches(&self, usz offset, usz node_count, bool want_free) {
    assert(offset + node_count <= self.total_nodes);
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
    assert(offset + node_count <= self.total_nodes);
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
    char *bytes = (char*)(self.storage + offset);
    usz total_bytes = node_count * NodeType.sizeof;
    usz i = 0;
    while (i < total_bytes) {
        bytes[i] = 0;
        i++;
    }
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

fn bool BitmapSlab.find_bitmap_fit(&self, usz node_count, usz *offset_out, usz *run_len) {
    usz idx = 0;
    usz current_len = 0;
    usz current_start = 0;

    while (idx < self.total_nodes) {
        usz word_idx = idx / BITS_PER_WORD;
        if (self.bitmap[word_idx] == 0) {
            idx = (word_idx + 1) * BITS_PER_WORD;
            current_len = 0;
            current_start = idx;
            continue;
        }

        if (!self.bit_is_free(idx)) {
            idx++;
            current_len = 0;
            current_start = idx;
            continue;
        }

        if (current_len == 0) {
            current_start = idx;
        }
        current_len++;
        idx++;

        if (current_len == node_count) {
            while (idx < self.total_nodes && self.bit_is_free(idx)) {
                current_len++;
                idx++;
            }
            *offset_out = current_start;
            *run_len = current_len;
            return true;
        }
    }

    return false;
}

fn usz BitmapSlab.ptr_offset(&self, void *ptr) {
    uptr start = (uptr)self.storage;
    uptr addr = (uptr)ptr;
    assert(addr >= start);
    assert(addr < start + self.total_nodes * NodeType.sizeof);
    assert((addr - start) % NodeType.sizeof == 0);
    return (addr - start) / NodeType.sizeof;
}

fn void*? BitmapSlab.alloc(&self, usz node_count) {
    if (self.storage == null || node_count == 0 || node_count > self.free_nodes) {
        return null;
    }

    usz offset;
    usz run_len;
    isz cached_idx = self.find_cache_fit(node_count);
    if (cached_idx >= 0) {
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
            return null;
        }
        assert(self.range_matches(offset, node_count, true));
        if (run_len > node_count) {
            self.cache_insert(offset + node_count, run_len - node_count);
        }
    }

    self.set_range(offset, node_count, false);
    self.clear_range(offset, node_count);
    self.free_nodes -= node_count;
    return self.storage + offset;
}

fn void*? BitmapSlab.alloc_run(&self, usz node_count) {
    return self.alloc(node_count);
}

fn void BitmapSlab.free(&self, void *ptr, usz node_count) {
    if (ptr == null || node_count == 0) {
        return;
    }

    assert(self.storage != null);
    usz offset = self.ptr_offset(ptr);
    assert(offset + node_count <= self.total_nodes);
    assert(self.range_matches(offset, node_count, false));

    self.set_range(offset, node_count, true);
    self.free_nodes += node_count;
    self.cache_insert(offset, node_count);
}

fn void BitmapSlab.release_run(&self, void *ptr, usz node_count) {
    self.free(ptr, node_count);
}
