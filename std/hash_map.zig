const std = @import("index.zig");
const debug = std.debug;
const assert = debug.assert;
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;
const builtin = @import("builtin");

const want_modification_safety = builtin.mode != builtin.Mode.ReleaseFast;
const debug_u32 = if (want_modification_safety) u32 else void;

pub fn HashMap(comptime K: type, comptime V: type, comptime hash: fn (key: K) u32, comptime eql: fn (a: K, b: K) bool) type {
    return struct {
        entries: []Entry,
        size: usize,
        max_distance_from_start_index: usize,
        allocator: *Allocator,
        // this is used to detect bugs where a hashtable is edited while an iterator is running.
        modification_count: debug_u32,

        const Self = this;

        pub const Entry = struct {
            used: bool,
            distance_from_start_index: usize,
            key: K,
            value: V,
        };

        pub const Iterator = struct {
            hm: *const Self,
            // how many items have we returned
            count: usize,
            // iterator through the entry array
            index: usize,
            // used to detect concurrent modification
            initial_modification_count: debug_u32,

            pub fn next(it: *Iterator) ?*Entry {
                if (want_modification_safety) {
                    assert(it.initial_modification_count == it.hm.modification_count); // concurrent modification
                }
                if (it.count >= it.hm.size) return null;
                while (it.index < it.hm.entries.len) : (it.index += 1) {
                    const entry = &it.hm.entries[it.index];
                    if (entry.used) {
                        it.index += 1;
                        it.count += 1;
                        return entry;
                    }
                }
                unreachable; // no next item
            }

            // Reset the iterator to the initial index
            pub fn reset(it: *Iterator) void {
                it.count = 0;
                it.index = 0;
                // Resetting the modification count too
                it.initial_modification_count = it.hm.modification_count;
            }
        };

        pub fn init(allocator: *Allocator) Self {
            return Self{
                .entries = []Entry{},
                .allocator = allocator,
                .size = 0,
                .max_distance_from_start_index = 0,
                .modification_count = if (want_modification_safety) 0 else {},
            };
        }

        pub fn deinit(hm: *const Self) void {
            hm.allocator.free(hm.entries);
        }

        pub fn clear(hm: *Self) void {
            for (hm.entries) |*entry| {
                entry.used = false;
            }
            hm.size = 0;
            hm.max_distance_from_start_index = 0;
            hm.incrementModificationCount();
        }

        pub fn count(hm: *const Self) usize {
            return hm.size;
        }

        /// Returns the value that was already there.
        pub fn put(hm: *Self, key: K, value: *const V) !?V {
            if (hm.entries.len == 0) {
                try hm.initCapacity(16);
            }
            hm.incrementModificationCount();

            // if we get too full (60%), double the capacity
            if (hm.size * 5 >= hm.entries.len * 3) {
                const old_entries = hm.entries;
                try hm.initCapacity(hm.entries.len * 2);
                // dump all of the old elements into the new table
                for (old_entries) |*old_entry| {
                    if (old_entry.used) {
                        _ = hm.internalPut(old_entry.key, old_entry.value);
                    }
                }
                hm.allocator.free(old_entries);
            }

            return hm.internalPut(key, value);
        }

        pub fn get(hm: *const Self, key: K) ?*Entry {
            if (hm.entries.len == 0) {
                return null;
            }
            return hm.internalGet(key);
        }

        pub fn contains(hm: *const Self, key: K) bool {
            return hm.get(key) != null;
        }

        pub fn remove(hm: *Self, key: K) ?*Entry {
            if (hm.entries.len == 0) return null;
            hm.incrementModificationCount();
            const start_index = hm.keyToIndex(key);
            {
                var roll_over: usize = 0;
                while (roll_over <= hm.max_distance_from_start_index) : (roll_over += 1) {
                    const index = (start_index + roll_over) % hm.entries.len;
                    var entry = &hm.entries[index];

                    if (!entry.used) return null;

                    if (!eql(entry.key, key)) continue;

                    while (roll_over < hm.entries.len) : (roll_over += 1) {
                        const next_index = (start_index + roll_over + 1) % hm.entries.len;
                        const next_entry = &hm.entries[next_index];
                        if (!next_entry.used or next_entry.distance_from_start_index == 0) {
                            entry.used = false;
                            hm.size -= 1;
                            return entry;
                        }
                        entry.* = next_entry.*;
                        entry.distance_from_start_index -= 1;
                        entry = next_entry;
                    }
                    unreachable; // shifting everything in the table
                }
            }
            return null;
        }

        pub fn iterator(hm: *const Self) Iterator {
            return Iterator{
                .hm = hm,
                .count = 0,
                .index = 0,
                .initial_modification_count = hm.modification_count,
            };
        }

        fn initCapacity(hm: *Self, capacity: usize) !void {
            hm.entries = try hm.allocator.alloc(Entry, capacity);
            hm.size = 0;
            hm.max_distance_from_start_index = 0;
            for (hm.entries) |*entry| {
                entry.used = false;
            }
        }

        fn incrementModificationCount(hm: *Self) void {
            if (want_modification_safety) {
                hm.modification_count +%= 1;
            }
        }

        /// Returns the value that was already there.
        fn internalPut(hm: *Self, orig_key: K, orig_value: *const V) ?V {
            var key = orig_key;
            var value = orig_value.*;
            const start_index = hm.keyToIndex(key);
            var roll_over: usize = 0;
            var distance_from_start_index: usize = 0;
            while (roll_over < hm.entries.len) : ({
                roll_over += 1;
                distance_from_start_index += 1;
            }) {
                const index = (start_index + roll_over) % hm.entries.len;
                const entry = &hm.entries[index];

                if (entry.used and !eql(entry.key, key)) {
                    if (entry.distance_from_start_index < distance_from_start_index) {
                        // robin hood to the rescue
                        const tmp = entry.*;
                        hm.max_distance_from_start_index = math.max(hm.max_distance_from_start_index, distance_from_start_index);
                        entry.* = Entry{
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

                var result: ?V = null;
                if (entry.used) {
                    result = entry.value;
                } else {
                    // adding an entry. otherwise overwriting old value with
                    // same key
                    hm.size += 1;
                }

                hm.max_distance_from_start_index = math.max(distance_from_start_index, hm.max_distance_from_start_index);
                entry.* = Entry{
                    .used = true,
                    .distance_from_start_index = distance_from_start_index,
                    .key = key,
                    .value = value,
                };
                return result;
            }
            unreachable; // put into a full map
        }

        fn internalGet(hm: *const Self, key: K) ?*Entry {
            const start_index = hm.keyToIndex(key);
            {
                var roll_over: usize = 0;
                while (roll_over <= hm.max_distance_from_start_index) : (roll_over += 1) {
                    const index = (start_index + roll_over) % hm.entries.len;
                    const entry = &hm.entries[index];

                    if (!entry.used) return null;
                    if (eql(entry.key, key)) return entry;
                }
            }
            return null;
        }

        fn keyToIndex(hm: *const Self, key: K) usize {
            return usize(hash(key)) % hm.entries.len;
        }
    };
}

test "basic hash map usage" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var map = HashMap(i32, i32, hash_i32, eql_i32).init(&direct_allocator.allocator);
    defer map.deinit();

    assert((map.put(1, 11) catch unreachable) == null);
    assert((map.put(2, 22) catch unreachable) == null);
    assert((map.put(3, 33) catch unreachable) == null);
    assert((map.put(4, 44) catch unreachable) == null);
    assert((map.put(5, 55) catch unreachable) == null);

    assert((map.put(5, 66) catch unreachable).? == 55);
    assert((map.put(5, 55) catch unreachable).? == 66);

    assert(map.contains(2));
    assert(map.get(2).?.value == 22);
    _ = map.remove(2);
    assert(map.remove(2) == null);
    assert(map.get(2) == null);
}

test "iterator hash map" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var reset_map = HashMap(i32, i32, hash_i32, eql_i32).init(&direct_allocator.allocator);
    defer reset_map.deinit();

    assert((reset_map.put(1, 11) catch unreachable) == null);
    assert((reset_map.put(2, 22) catch unreachable) == null);
    assert((reset_map.put(3, 33) catch unreachable) == null);

    var keys = []i32{
        1,
        2,
        3,
    };
    var values = []i32{
        11,
        22,
        33,
    };

    var it = reset_map.iterator();
    var count: usize = 0;
    while (it.next()) |next| {
        assert(next.key == keys[count]);
        assert(next.value == values[count]);
        count += 1;
    }

    assert(count == 3);
    assert(it.next() == null);
    it.reset();
    count = 0;
    while (it.next()) |next| {
        assert(next.key == keys[count]);
        assert(next.value == values[count]);
        count += 1;
        if (count == 2) break;
    }

    it.reset();
    var entry = it.next().?;
    assert(entry.key == keys[0]);
    assert(entry.value == values[0]);
}

fn hash_i32(x: i32) u32 {
    return @bitCast(u32, x);
}

fn eql_i32(a: i32, b: i32) bool {
    return a == b;
}
