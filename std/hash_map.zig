const debug = @import("debug.zig");
const assert = debug.assert;
const math = @import("math.zig");
const mem = @import("mem.zig");
const Allocator = mem.Allocator;

const want_modification_safety = !@compileVar("is_release");
const debug_u32 = if (want_modification_safety) u32 else void;

pub fn HashMap(inline K: type, inline V: type, inline hash: fn(key: K)->u32,
    inline eql: fn(a: K, b: K)->bool) -> type
{
    SmallHashMap(K, V, hash, eql, @sizeOf(usize))
}

pub struct SmallHashMap(K: type, V: type, hash: fn(key: K)->u32, eql: fn(a: K, b: K)->bool, static_size: usize) {
    entries: []Entry,
    size: usize,
    max_distance_from_start_index: usize,
    allocator: &Allocator,
    // if the hash map is small enough, we use linear search through these
    // entries instead of allocating memory
    prealloc_entries: [static_size]Entry,
    // this is used to detect bugs where a hashtable is edited while an iterator is running.
    modification_count: debug_u32,

    const Self = this;

    pub struct Entry {
        used: bool,
        distance_from_start_index: usize,
        key: K,
        value: V,
    }

    pub struct Iterator {
        hm: &Self,
        // how many items have we returned
        count: usize,
        // iterator through the entry array
        index: usize,
        // used to detect concurrent modification
        initial_modification_count: debug_u32,

        pub fn next(it: &Iterator) -> ?&Entry {
            if (want_modification_safety) {
                assert(it.initial_modification_count == it.hm.modification_count); // concurrent modification
            }
            if (it.count >= it.hm.size) return null;
            while (it.index < it.hm.entries.len; it.index += 1) {
                const entry = &it.hm.entries[it.index];
                if (entry.used) {
                    it.index += 1;
                    it.count += 1;
                    return entry;
                }
            }
            @unreachable() // no next item
        }
    }
    
    pub fn init(hm: &Self, allocator: &Allocator) {
        hm.entries = hm.prealloc_entries[0...];
        hm.allocator = allocator;
        hm.size = 0;
        hm.max_distance_from_start_index = 0;
        hm.prealloc_entries = zeroes; // sets used to false for all entries
        hm.modification_count = zeroes;
    }

    pub fn deinit(hm: &Self) {
        if (hm.entries.ptr != &hm.prealloc_entries[0]) {
            hm.allocator.free(Entry, hm.entries);
        }
    }

    pub fn clear(hm: &Self) {
        for (hm.entries) |*entry| {
            entry.used = false;
        }
        hm.size = 0;
        hm.max_distance_from_start_index = 0;
        hm.incrementModificationCount();
    }

    pub fn put(hm: &Self, key: K, value: V) -> %void {
        hm.incrementModificationCount();

        const resize = if (hm.entries.ptr == &hm.prealloc_entries[0]) {
            // preallocated entries table is full
            hm.size == hm.entries.len
        } else {
            // if we get too full (60%), double the capacity
            hm.size * 5 >= hm.entries.len * 3
        };
        if (resize) {
            const old_entries = hm.entries;
            %return hm.initCapacity(hm.entries.len * 2);
            // dump all of the old elements into the new table
            for (old_entries) |*old_entry| {
                if (old_entry.used) {
                    hm.internalPut(old_entry.key, old_entry.value);
                }
            }
            if (old_entries.ptr != &hm.prealloc_entries[0]) {
                hm.allocator.free(Entry, old_entries);
            }
        }

        hm.internalPut(key, value);
    }

    pub fn get(hm: &Self, key: K) -> ?&Entry {
        return hm.internalGet(key);
    }

    pub fn remove(hm: &Self, key: K) {
        hm.incrementModificationCount();
        const start_index = hm.keyToIndex(key);
        {var roll_over: usize = 0; while (roll_over <= hm.max_distance_from_start_index; roll_over += 1) {
            const index = (start_index + roll_over) % hm.entries.len;
            var entry = &hm.entries[index];

            assert(entry.used); // key not found

            if (!eql(entry.key, key)) continue;

            while (roll_over < hm.entries.len; roll_over += 1) {
                const next_index = (start_index + roll_over + 1) % hm.entries.len;
                const next_entry = &hm.entries[next_index];
                if (!next_entry.used || next_entry.distance_from_start_index == 0) {
                    entry.used = false;
                    hm.size -= 1;
                    return;
                }
                *entry = *next_entry;
                entry.distance_from_start_index -= 1;
                entry = next_entry;
            }
            @unreachable() // shifting everything in the table
        }}
        @unreachable() // key not found
    }

    pub fn entryIterator(hm: &Self) -> Iterator {
        return Iterator {
            .hm = hm,
            .count = 0,
            .index = 0,
            .initial_modification_count = hm.modification_count,
        };
    }

    fn initCapacity(hm: &Self, capacity: usize) -> %void {
        hm.entries = %return hm.allocator.alloc(Entry, capacity);
        hm.size = 0;
        hm.max_distance_from_start_index = 0;
        for (hm.entries) |*entry| {
            entry.used = false;
        }
    }

    fn incrementModificationCount(hm: &Self) {
        if (want_modification_safety) {
            hm.modification_count +%= 1;
        }
    }

    fn internalPut(hm: &Self, orig_key: K, orig_value: V) {
        var key = orig_key;
        var value = orig_value;
        const start_index = hm.keyToIndex(key);
        var roll_over: usize = 0;
        var distance_from_start_index: usize = 0;
        while (roll_over < hm.entries.len; {roll_over += 1; distance_from_start_index += 1}) {
            const index = (start_index + roll_over) % hm.entries.len;
            const entry = &hm.entries[index];

            if (entry.used && !eql(entry.key, key)) {
                if (entry.distance_from_start_index < distance_from_start_index) {
                    // robin hood to the rescue
                    const tmp = *entry;
                    hm.max_distance_from_start_index = math.max(hm.max_distance_from_start_index,
                        distance_from_start_index);
                    *entry = Entry {
                        .used = true,
                        .distance_from_start_index = distance_from_start_index,
                        .key = key,
                        .value = value,
                    };
                    key = tmp.key;
                    value = tmp.value;
                    distance_from_start_index = tmp.distance_from_start_index;
                }
                continue;
            }

            if (!entry.used) {
                // adding an entry. otherwise overwriting old value with
                // same key
                hm.size += 1;
            }

            hm.max_distance_from_start_index = math.max(distance_from_start_index, hm.max_distance_from_start_index);
            *entry = Entry {
                .used = true,
                .distance_from_start_index = distance_from_start_index,
                .key = key,
                .value = value,
            };
            return;
        }
        @unreachable() // put into a full map
    }

    fn internalGet(hm: &Self, key: K) -> ?&Entry {
        const start_index = hm.keyToIndex(key);
        {var roll_over: usize = 0; while (roll_over <= hm.max_distance_from_start_index; roll_over += 1) {
            const index = (start_index + roll_over) % hm.entries.len;
            const entry = &hm.entries[index];

            if (!entry.used) return null;
            if (eql(entry.key, key)) return entry;
        }}
        return null;
    }

    fn keyToIndex(hm: &Self, key: K) -> usize {
        return usize(hash(key)) % hm.entries.len;
    }
}

fn basicHashMapTest() {
    @setFnTest(this, true);

    var map: HashMap(i32, i32, hash_i32, eql_i32) = undefined;
    map.init(&debug.global_allocator);
    defer map.deinit();

    %%map.put(1, 11);
    %%map.put(2, 22);
    %%map.put(3, 33);
    %%map.put(4, 44);
    %%map.put(5, 55);

    assert((??map.get(2)).value == 22);
    map.remove(2);
    assert(if (const entry ?= map.get(2)) false else true);
}

fn hash_i32(x: i32) -> u32 {
    *(&u32)(&x)
}
fn eql_i32(a: i32, b: i32) -> bool {
    a == b
}
