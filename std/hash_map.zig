const assert = @import("index.zig").assert;
const math = @import("math.zig");
const mem = @import("mem.zig");
const Allocator = mem.Allocator;

const want_modification_safety = !@compile_var("is_release");
const debug_u32 = if (want_modification_safety) void else u32;

pub struct HashMap(K: type, V: type, hash: fn(key: K)->u32, eql: fn(a: K, b: K)->bool) {
    entries: []Entry,
    size: isize,
    max_distance_from_start_index: isize,
    allocator: &Allocator,
    // this is used to detect bugs where a hashtable is edited while an iterator is running.
    modification_count: debug_u32,

    const Self = HashMap(K, V, hash, eql);

    pub struct Entry {
        used: bool,
        distance_from_start_index: isize,
        key: K,
        value: V,
    }

    pub struct Iterator {
        hm: &Self,
        // how many items have we returned
        count: isize,
        // iterator through the entry array
        index: isize,
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
            unreachable{} // no next item
        }
    };
    
    pub fn init(hm: &Self, allocator: &Allocator, capacity: isize) {
        assert(capacity > 0);
        hm.allocator = allocator;
        hm.init_capacity(capacity);
    }

    pub fn deinit(hm: &Self) {
        free(_entries);
    }

    pub fn clear(hm: &Self) {
        for (hm.entries) |*entry| {
            entry.used = false;
        }
        hm.size = 0;
        hm.max_distance_from_start_index = 0;
        hm.increment_modification_count();
    }

    pub fn put(hm: &Self, key: K, value: V) {
        hm.increment_modification_count();
        hm.internal_put(key, value);

        // if we get too full (60%), double the capacity
        if (hm.size * 5 >= hm.entries.len * 3) {
            const old_entries = hm.entries;
            hm.init_capacity(hm.entries.len * 2);
            // dump all of the old elements into the new table
            for (old_entries) |*old_entry| {
                if (old_entry.used) {
                    hm.internal_put(old_entry.key, old_entry.value);
                }
            }
            hm.allocator.free(hm.allocator, ([]u8)(old_entries));
        }
    }

    pub fn get(hm: &Self, key: K) {
        return internal_get(key);
    }

    pub fn remove(hm: &Self, key: K) {
        hm.increment_modification_count();
        const start_index = hm.key_to_index(key);
        {var roll_over: isize = 0; while (roll_over <= hm.max_distance_from_start_index; roll_over += 1) {
            const index = (start_index + roll_over) % hm.entries.len;
            const entry = &hm.entries[index];

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
            unreachable{} // shifting everything in the table
        }}
        unreachable{} // key not found
    }

    pub fn entry_iterator(hm: &Self) -> Iterator {
        return Iterator {
            .hm = hm,
            .count = 0,
            .index = 0,
            .initial_modification_count = hm.modification_count,
        };
    }

    fn init_capacity(hm: &Self, capacity: isize) {
        hm.capacity = capacity;
        hm.entries = ([]Entry)(hm.allocator.alloc(hm.allocator, capacity * @sizeof(Entry)));
        hm.size = 0;
        hm.max_distance_from_start_index = 0;
        for (hm.entries) |*entry| {
            entry.used = false;
        }
    }

    fn increment_modification_count(hm: &Self) {
        if (want_modification_safety) {
            hm.modification_count += 1;
        }
    }

    fn internal_put(hm: &Self, K orig_key, V orig_value) {
        var key = orig_key;
        var value = orig_value;
        const start_index = key_to_index(key);
        var roll_over: isize = 0;
        var distance_from_start_index: isize = 0;
        while (roll_over < hm.entries.len; {roll_over += 1; distance_from_start_index += 1}) {
            const index = (start_index + roll_over) % hm.entries.len;
            const entry = &hm.entries[index];

            if (entry.used && !eql(entry.key, key)) {
                if (entry.distance_from_start_index < distance_from_start_index) {
                    // robin hood to the rescue
                    const tmp = *entry;
                    hm.max_distance_from_start_index = math.max(isize)(
                        hm.max_distance_from_start_index, distance_from_start_index);
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

            hm.max_distance_from_start_index = math.max(isize)(distance_from_start_index, hm.max_distance_from_start_index);
            *entry = {
                .used = true,
                .distance_from_start_index = distance_from_start_index,
                .key = key,
                .value = value,
            };
            return;
        }
        unreachable{} // put into a full map
    }

    fn internal_get(hm: &Self, key: K) -> ?&Entry {
        const start_index = key_to_index(key);
        {var roll_over: isize = 0; while (roll_over <= hm.max_distance_from_start_index; roll_over += 1) {
            const index = (start_index + roll_over) % hm.entries.len;
            const entry = &hm.entries[index];

            if (!entry.used) return null;
            if (eql(entry.key, key)) return entry;
        }}
        return null;
    }

    Entry *internal_get(const K &key) const {
        int start_index = key_to_index(key);
        for (int roll_over = 0; roll_over <= _max_distance_from_start_index; roll_over += 1) {
            int index = (start_index + roll_over) % _capacity;
            Entry *entry = &_entries[index];

            if (!entry->used)
                return NULL;

            if (EqualFn(entry->key, key))
                return entry;
        }
        return NULL;
    }

    fn key_to_index(hm: &Self, key: K) -> isize {
        return isize(hash(key)) % hm.entries.len;
    }
}

var global_allocator = Allocator {
    .alloc = global_alloc,
    .realloc = global_realloc,
    .free = global_free,
    .context = null,
};

var some_mem: [200]u8 = undefined;
var some_mem_index: isize = 0;

fn global_alloc(self: &Allocator, n: isize) -> %[]u8 {
    const result = some_mem[some_mem_index ... some_mem_index + n];
    some_mem_index += n;
    return result;
}

fn global_realloc(self: &Allocator, old_mem: []u8, new_size: isize) -> %[]u8 {
    const result = %return global_alloc(self, new_size);
    @memcpy(result.ptr, old_mem.ptr, old_mem.len);
    return result;
}

fn global_free(self: &Allocator, old_mem: []u8) {
}

#attribute("test")
fn basic_hash_map_test() {
    var map: HashMap(i32, i32, hash_i32, eql_i32);
    map.init(&global_allocator, 4);
    defer map.deinit();
}

fn hash_i32(x: i32) -> u32 {
    *(&u32)(&x)
}
fn eql_i32(a: i32, b: i32) -> bool {
    a == b
}
