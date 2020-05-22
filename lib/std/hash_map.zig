const std = @import("std.zig");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const math = std.math;
const mem = std.mem;
const meta = std.meta;
const autoHash = std.hash.autoHash;
const Wyhash = std.hash.Wyhash;
const Allocator = mem.Allocator;
const builtin = @import("builtin");

const want_modification_safety = std.debug.runtime_safety;
const debug_u32 = if (want_modification_safety) u32 else void;

pub fn AutoHashMap(comptime K: type, comptime V: type) type {
    return HashMap(K, V, getAutoHashFn(K), getAutoEqlFn(K));
}

/// Builtin hashmap for strings as keys.
pub fn StringHashMap(comptime V: type) type {
    return HashMap([]const u8, V, hashString, eqlString);
}

pub fn eqlString(a: []const u8, b: []const u8) bool {
    return mem.eql(u8, a, b);
}

pub fn hashString(s: []const u8) u32 {
    return @truncate(u32, std.hash.Wyhash.hash(0, s));
}

pub fn HashMap(comptime K: type, comptime V: type, comptime hash: fn (key: K) u32, comptime eql: fn (a: K, b: K) bool) type {
    return struct {
        entries: []Entry,
        size: usize,
        max_distance_from_start_index: usize,
        allocator: *Allocator,

        /// This is used to detect bugs where a hashtable is edited while an iterator is running.
        modification_count: debug_u32,

        const Self = @This();

        /// A *KV is a mutable pointer into this HashMap's internal storage.
        /// Modifying the key is undefined behavior.
        /// Modifying the value is harmless.
        /// *KV pointers become invalid whenever this HashMap is modified,
        /// and then any access to the *KV is undefined behavior.
        pub const KV = struct {
            key: K,
            value: V,
        };

        const Entry = struct {
            used: bool,
            distance_from_start_index: usize,
            kv: KV,
        };

        pub const GetOrPutResult = struct {
            kv: *KV,
            found_existing: bool,
        };

        pub const Iterator = struct {
            hm: *const Self,
            // how many items have we returned
            count: usize,
            // iterator through the entry array
            index: usize,
            // used to detect concurrent modification
            initial_modification_count: debug_u32,

            pub fn next(it: *Iterator) ?*KV {
                if (want_modification_safety) {
                    assert(it.initial_modification_count == it.hm.modification_count); // concurrent modification
                }
                if (it.count >= it.hm.size) return null;
                while (it.index < it.hm.entries.len) : (it.index += 1) {
                    const entry = &it.hm.entries[it.index];
                    if (entry.used) {
                        it.index += 1;
                        it.count += 1;
                        return &entry.kv;
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
                .entries = &[_]Entry{},
                .allocator = allocator,
                .size = 0,
                .max_distance_from_start_index = 0,
                .modification_count = if (want_modification_safety) 0 else {},
            };
        }

        pub fn deinit(hm: Self) void {
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

        pub fn count(self: Self) usize {
            return self.size;
        }

        /// If key exists this function cannot fail.
        /// If there is an existing item with `key`, then the result
        /// kv pointer points to it, and found_existing is true.
        /// Otherwise, puts a new item with undefined value, and
        /// the kv pointer points to it. Caller should then initialize
        /// the data.
        pub fn getOrPut(self: *Self, key: K) !GetOrPutResult {
            // TODO this implementation can be improved - we should only
            // have to hash once and find the entry once.
            if (self.get(key)) |kv| {
                return GetOrPutResult{
                    .kv = kv,
                    .found_existing = true,
                };
            }
            self.incrementModificationCount();
            try self.autoCapacity();
            const put_result = self.internalPut(key);
            assert(put_result.old_kv == null);
            return GetOrPutResult{
                .kv = &put_result.new_entry.kv,
                .found_existing = false,
            };
        }

        pub fn getOrPutValue(self: *Self, key: K, value: V) !*KV {
            const res = try self.getOrPut(key);
            if (!res.found_existing)
                res.kv.value = value;

            return res.kv;
        }

        fn optimizedCapacity(expected_count: usize) usize {
            // ensure that the hash map will be at most 60% full if
            // expected_count items are put into it
            var optimized_capacity = expected_count * 5 / 3;
            // an overflow here would mean the amount of memory required would not
            // be representable in the address space
            return math.ceilPowerOfTwo(usize, optimized_capacity) catch unreachable;
        }

        /// Increases capacity so that the hash map will be at most
        /// 60% full when expected_count items are put into it
        pub fn ensureCapacity(self: *Self, expected_count: usize) !void {
            const optimized_capacity = optimizedCapacity(expected_count);
            return self.ensureCapacityExact(optimized_capacity);
        }

        /// Sets the capacity to the new capacity if the new
        /// capacity is greater than the current capacity.
        /// New capacity must be a power of two.
        fn ensureCapacityExact(self: *Self, new_capacity: usize) !void {
            // capacity must always be a power of two to allow for modulo
            // optimization in the constrainIndex fn
            assert(math.isPowerOfTwo(new_capacity));

            if (new_capacity <= self.entries.len) {
                return;
            }

            const old_entries = self.entries;
            try self.initCapacity(new_capacity);
            self.incrementModificationCount();
            if (old_entries.len > 0) {
                // dump all of the old elements into the new table
                for (old_entries) |*old_entry| {
                    if (old_entry.used) {
                        self.internalPut(old_entry.kv.key).new_entry.kv.value = old_entry.kv.value;
                    }
                }
                self.allocator.free(old_entries);
            }
        }

        /// Returns the kv pair that was already there.
        pub fn put(self: *Self, key: K, value: V) !?KV {
            try self.autoCapacity();
            return putAssumeCapacity(self, key, value);
        }

        /// Calls put() and asserts that no kv pair is clobbered.
        pub fn putNoClobber(self: *Self, key: K, value: V) !void {
            assert((try self.put(key, value)) == null);
        }

        pub fn putAssumeCapacity(self: *Self, key: K, value: V) ?KV {
            assert(self.count() < self.entries.len);
            self.incrementModificationCount();

            const put_result = self.internalPut(key);
            put_result.new_entry.kv.value = value;
            return put_result.old_kv;
        }

        pub fn putAssumeCapacityNoClobber(self: *Self, key: K, value: V) void {
            assert(self.putAssumeCapacity(key, value) == null);
        }

        pub fn get(hm: *const Self, key: K) ?*KV {
            if (hm.entries.len == 0) {
                return null;
            }
            return hm.internalGet(key);
        }

        pub fn getValue(hm: *const Self, key: K) ?V {
            return if (hm.get(key)) |kv| kv.value else null;
        }

        pub fn contains(hm: *const Self, key: K) bool {
            return hm.get(key) != null;
        }

        /// Returns any kv pair that was removed.
        pub fn remove(hm: *Self, key: K) ?KV {
            if (hm.entries.len == 0) return null;
            hm.incrementModificationCount();
            const start_index = hm.keyToIndex(key);
            {
                var roll_over: usize = 0;
                while (roll_over <= hm.max_distance_from_start_index) : (roll_over += 1) {
                    const index = hm.constrainIndex(start_index + roll_over);
                    var entry = &hm.entries[index];

                    if (!entry.used) return null;

                    if (!eql(entry.kv.key, key)) continue;

                    const removed_kv = entry.kv;
                    while (roll_over < hm.entries.len) : (roll_over += 1) {
                        const next_index = hm.constrainIndex(start_index + roll_over + 1);
                        const next_entry = &hm.entries[next_index];
                        if (!next_entry.used or next_entry.distance_from_start_index == 0) {
                            entry.used = false;
                            hm.size -= 1;
                            return removed_kv;
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

        /// Calls remove(), asserts that a kv pair is removed, and discards it.
        pub fn removeAssertDiscard(hm: *Self, key: K) void {
            assert(hm.remove(key) != null);
        }

        pub fn iterator(hm: *const Self) Iterator {
            return Iterator{
                .hm = hm,
                .count = 0,
                .index = 0,
                .initial_modification_count = hm.modification_count,
            };
        }

        pub fn clone(self: Self) !Self {
            var other = Self.init(self.allocator);
            try other.initCapacity(self.entries.len);
            var it = self.iterator();
            while (it.next()) |entry| {
                try other.putNoClobber(entry.key, entry.value);
            }
            return other;
        }

        fn autoCapacity(self: *Self) !void {
            if (self.entries.len == 0) {
                return self.ensureCapacityExact(16);
            }
            // if we get too full (60%), double the capacity
            if (self.size * 5 >= self.entries.len * 3) {
                return self.ensureCapacityExact(self.entries.len * 2);
            }
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

        const InternalPutResult = struct {
            new_entry: *Entry,
            old_kv: ?KV,
        };

        /// Returns a pointer to the new entry.
        /// Asserts that there is enough space for the new item.
        fn internalPut(self: *Self, orig_key: K) InternalPutResult {
            var key = orig_key;
            var value: V = undefined;
            const start_index = self.keyToIndex(key);
            var roll_over: usize = 0;
            var distance_from_start_index: usize = 0;
            var got_result_entry = false;
            var result = InternalPutResult{
                .new_entry = undefined,
                .old_kv = null,
            };
            while (roll_over < self.entries.len) : ({
                roll_over += 1;
                distance_from_start_index += 1;
            }) {
                const index = self.constrainIndex(start_index + roll_over);
                const entry = &self.entries[index];

                if (entry.used and !eql(entry.kv.key, key)) {
                    if (entry.distance_from_start_index < distance_from_start_index) {
                        // robin hood to the rescue
                        const tmp = entry.*;
                        self.max_distance_from_start_index = math.max(self.max_distance_from_start_index, distance_from_start_index);
                        if (!got_result_entry) {
                            got_result_entry = true;
                            result.new_entry = entry;
                        }
                        entry.* = Entry{
                            .used = true,
                            .distance_from_start_index = distance_from_start_index,
                            .kv = KV{
                                .key = key,
                                .value = value,
                            },
                        };
                        key = tmp.kv.key;
                        value = tmp.kv.value;
                        distance_from_start_index = tmp.distance_from_start_index;
                    }
                    continue;
                }

                if (entry.used) {
                    result.old_kv = entry.kv;
                } else {
                    // adding an entry. otherwise overwriting old value with
                    // same key
                    self.size += 1;
                }

                self.max_distance_from_start_index = math.max(distance_from_start_index, self.max_distance_from_start_index);
                if (!got_result_entry) {
                    result.new_entry = entry;
                }
                entry.* = Entry{
                    .used = true,
                    .distance_from_start_index = distance_from_start_index,
                    .kv = KV{
                        .key = key,
                        .value = value,
                    },
                };
                return result;
            }
            unreachable; // put into a full map
        }

        fn internalGet(hm: Self, key: K) ?*KV {
            const start_index = hm.keyToIndex(key);
            {
                var roll_over: usize = 0;
                while (roll_over <= hm.max_distance_from_start_index) : (roll_over += 1) {
                    const index = hm.constrainIndex(start_index + roll_over);
                    const entry = &hm.entries[index];

                    if (!entry.used) return null;
                    if (eql(entry.kv.key, key)) return &entry.kv;
                }
            }
            return null;
        }

        fn keyToIndex(hm: Self, key: K) usize {
            return hm.constrainIndex(@as(usize, hash(key)));
        }

        fn constrainIndex(hm: Self, i: usize) usize {
            // this is an optimization for modulo of power of two integers;
            // it requires hm.entries.len to always be a power of two
            return i & (hm.entries.len - 1);
        }
    };
}

test "basic hash map usage" {
    var map = AutoHashMap(i32, i32).init(std.testing.allocator);
    defer map.deinit();

    testing.expect((try map.put(1, 11)) == null);
    testing.expect((try map.put(2, 22)) == null);
    testing.expect((try map.put(3, 33)) == null);
    testing.expect((try map.put(4, 44)) == null);

    try map.putNoClobber(5, 55);
    testing.expect((try map.put(5, 66)).?.value == 55);
    testing.expect((try map.put(5, 55)).?.value == 66);

    const gop1 = try map.getOrPut(5);
    testing.expect(gop1.found_existing == true);
    testing.expect(gop1.kv.value == 55);
    gop1.kv.value = 77;
    testing.expect(map.get(5).?.value == 77);

    const gop2 = try map.getOrPut(99);
    testing.expect(gop2.found_existing == false);
    gop2.kv.value = 42;
    testing.expect(map.get(99).?.value == 42);

    const gop3 = try map.getOrPutValue(5, 5);
    testing.expect(gop3.value == 77);

    const gop4 = try map.getOrPutValue(100, 41);
    testing.expect(gop4.value == 41);

    testing.expect(map.contains(2));
    testing.expect(map.get(2).?.value == 22);
    testing.expect(map.getValue(2).? == 22);

    const rmv1 = map.remove(2);
    testing.expect(rmv1.?.key == 2);
    testing.expect(rmv1.?.value == 22);
    testing.expect(map.remove(2) == null);
    testing.expect(map.get(2) == null);
    testing.expect(map.getValue(2) == null);

    map.removeAssertDiscard(3);
}

test "iterator hash map" {
    // https://github.com/ziglang/zig/issues/5127
    if (std.Target.current.cpu.arch == .mips) return error.SkipZigTest;

    var reset_map = AutoHashMap(i32, i32).init(std.testing.allocator);
    defer reset_map.deinit();

    try reset_map.putNoClobber(1, 11);
    try reset_map.putNoClobber(2, 22);
    try reset_map.putNoClobber(3, 33);

    // TODO this test depends on the hashing algorithm, because it assumes the
    // order of the elements in the hashmap. This should not be the case.
    var keys = [_]i32{
        1,
        3,
        2,
    };
    var values = [_]i32{
        11,
        33,
        22,
    };

    var it = reset_map.iterator();
    var count: usize = 0;
    while (it.next()) |next| {
        testing.expect(next.key == keys[count]);
        testing.expect(next.value == values[count]);
        count += 1;
    }

    testing.expect(count == 3);
    testing.expect(it.next() == null);
    it.reset();
    count = 0;
    while (it.next()) |next| {
        testing.expect(next.key == keys[count]);
        testing.expect(next.value == values[count]);
        count += 1;
        if (count == 2) break;
    }

    it.reset();
    var entry = it.next().?;
    testing.expect(entry.key == keys[0]);
    testing.expect(entry.value == values[0]);
}

test "ensure capacity" {
    var map = AutoHashMap(i32, i32).init(std.testing.allocator);
    defer map.deinit();

    try map.ensureCapacity(20);
    const initialCapacity = map.entries.len;
    testing.expect(initialCapacity >= 20);
    var i: i32 = 0;
    while (i < 20) : (i += 1) {
        testing.expect(map.putAssumeCapacity(i, i + 10) == null);
    }
    // shouldn't resize from putAssumeCapacity
    testing.expect(initialCapacity == map.entries.len);
}

pub fn getHashPtrAddrFn(comptime K: type) (fn (K) u32) {
    return struct {
        fn hash(key: K) u32 {
            return getAutoHashFn(usize)(@ptrToInt(key));
        }
    }.hash;
}

pub fn getTrivialEqlFn(comptime K: type) (fn (K, K) bool) {
    return struct {
        fn eql(a: K, b: K) bool {
            return a == b;
        }
    }.eql;
}

pub fn getAutoHashFn(comptime K: type) (fn (K) u32) {
    return struct {
        fn hash(key: K) u32 {
            var hasher = Wyhash.init(0);
            autoHash(&hasher, key);
            return @truncate(u32, hasher.final());
        }
    }.hash;
}

pub fn getAutoEqlFn(comptime K: type) (fn (K, K) bool) {
    return struct {
        fn eql(a: K, b: K) bool {
            return meta.eql(a, b);
        }
    }.eql;
}

pub fn getAutoHashStratFn(comptime K: type, comptime strategy: std.hash.Strategy) (fn (K) u32) {
    return struct {
        fn hash(key: K) u32 {
            var hasher = Wyhash.init(0);
            std.hash.autoHashStrat(&hasher, key, strategy);
            return @truncate(u32, hasher.final());
        }
    }.hash;
}
