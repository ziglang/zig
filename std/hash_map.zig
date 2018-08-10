const std = @import("index.zig");
const debug = std.debug;
const assert = debug.assert;
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;
const builtin = @import("builtin");

const want_modification_safety = builtin.mode != builtin.Mode.ReleaseFast;
const debug_u32 = if (want_modification_safety) u32 else void;

pub fn AutoHashMap(comptime K: type, comptime V: type) type {
    return HashMap(K, V, getAutoHashFn(K), getAutoEqlFn(K));
}

pub fn HashMap(comptime K: type, comptime V: type, comptime hash: fn (key: K) u32, comptime eql: fn (a: K, b: K) bool) type {
    return struct {
        entries: []Entry,
        size: usize,
        max_distance_from_start_index: usize,
        allocator: *Allocator,
        // this is used to detect bugs where a hashtable is edited while an iterator is running.
        modification_count: debug_u32,

        const Self = this;

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
                .entries = []Entry{},
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
            try self.ensureCapacity();
            const put_result = self.internalPut(key);
            assert(put_result.old_kv == null);
            return GetOrPutResult{
                .kv = &put_result.new_entry.kv,
                .found_existing = false,
            };
        }

        fn ensureCapacity(self: *Self) !void {
            if (self.entries.len == 0) {
                return self.initCapacity(16);
            }

            // if we get too full (60%), double the capacity
            if (self.size * 5 >= self.entries.len * 3) {
                const old_entries = self.entries;
                try self.initCapacity(self.entries.len * 2);
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
            self.incrementModificationCount();
            try self.ensureCapacity();

            const put_result = self.internalPut(key);
            put_result.new_entry.kv.value = value;
            return put_result.old_kv;
        }

        pub fn get(hm: *const Self, key: K) ?*KV {
            if (hm.entries.len == 0) {
                return null;
            }
            return hm.internalGet(key);
        }

        pub fn contains(hm: *const Self, key: K) bool {
            return hm.get(key) != null;
        }

        pub fn remove(hm: *Self, key: K) ?*KV {
            if (hm.entries.len == 0) return null;
            hm.incrementModificationCount();
            const start_index = hm.keyToIndex(key);
            {
                var roll_over: usize = 0;
                while (roll_over <= hm.max_distance_from_start_index) : (roll_over += 1) {
                    const index = (start_index + roll_over) % hm.entries.len;
                    var entry = &hm.entries[index];

                    if (!entry.used) return null;

                    if (!eql(entry.kv.key, key)) continue;

                    while (roll_over < hm.entries.len) : (roll_over += 1) {
                        const next_index = (start_index + roll_over + 1) % hm.entries.len;
                        const next_entry = &hm.entries[next_index];
                        if (!next_entry.used or next_entry.distance_from_start_index == 0) {
                            entry.used = false;
                            hm.size -= 1;
                            return &entry.kv;
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

        pub fn clone(self: Self) !Self {
            var other = Self.init(self.allocator);
            try other.initCapacity(self.entries.len);
            var it = self.iterator();
            while (it.next()) |entry| {
                assert((try other.put(entry.key, entry.value)) == null);
            }
            return other;
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
                const index = (start_index + roll_over) % self.entries.len;
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
                    const index = (start_index + roll_over) % hm.entries.len;
                    const entry = &hm.entries[index];

                    if (!entry.used) return null;
                    if (eql(entry.kv.key, key)) return &entry.kv;
                }
            }
            return null;
        }

        fn keyToIndex(hm: Self, key: K) usize {
            return usize(hash(key)) % hm.entries.len;
        }
    };
}

test "basic hash map usage" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var map = AutoHashMap(i32, i32).init(&direct_allocator.allocator);
    defer map.deinit();

    assert((try map.put(1, 11)) == null);
    assert((try map.put(2, 22)) == null);
    assert((try map.put(3, 33)) == null);
    assert((try map.put(4, 44)) == null);
    assert((try map.put(5, 55)) == null);

    assert((try map.put(5, 66)).?.value == 55);
    assert((try map.put(5, 55)).?.value == 66);

    const gop1 = try map.getOrPut(5);
    assert(gop1.found_existing == true);
    assert(gop1.kv.value == 55);
    gop1.kv.value = 77;
    assert(map.get(5).?.value == 77);

    const gop2 = try map.getOrPut(99);
    assert(gop2.found_existing == false);
    gop2.kv.value = 42;
    assert(map.get(99).?.value == 42);

    assert(map.contains(2));
    assert(map.get(2).?.value == 22);
    _ = map.remove(2);
    assert(map.remove(2) == null);
    assert(map.get(2) == null);
}

test "iterator hash map" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var reset_map = AutoHashMap(i32, i32).init(&direct_allocator.allocator);
    defer reset_map.deinit();

    assert((try reset_map.put(1, 11)) == null);
    assert((try reset_map.put(2, 22)) == null);
    assert((try reset_map.put(3, 33)) == null);

    var keys = []i32{
        3,
        2,
        1,
    };
    var values = []i32{
        33,
        22,
        11,
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

pub fn getAutoHashFn(comptime K: type) (fn (K) u32) {
    return struct {
        fn hash(key: K) u32 {
            comptime var rng = comptime std.rand.DefaultPrng.init(0);
            return autoHash(key, &rng.random, u32);
        }
    }.hash;
}

pub fn getAutoEqlFn(comptime K: type) (fn (K, K) bool) {
    return struct {
        fn eql(a: K, b: K) bool {
            return autoEql(a, b);
        }
    }.eql;
}

// TODO improve these hash functions
pub fn autoHash(key: var, comptime rng: *std.rand.Random, comptime HashInt: type) HashInt {
    switch (@typeInfo(@typeOf(key))) {
        builtin.TypeId.NoReturn,
        builtin.TypeId.Opaque,
        builtin.TypeId.Undefined,
        builtin.TypeId.ArgTuple,
        => @compileError("cannot hash this type"),

        builtin.TypeId.Void,
        builtin.TypeId.Null,
        => return 0,

        builtin.TypeId.Int => |info| {
            const unsigned_x = @bitCast(@IntType(false, info.bits), key);
            if (info.bits <= HashInt.bit_count) {
                return HashInt(unsigned_x) ^ comptime rng.scalar(HashInt);
            } else {
                return @truncate(HashInt, unsigned_x ^ comptime rng.scalar(@typeOf(unsigned_x)));
            }
        },

        builtin.TypeId.Float => |info| {
            return autoHash(@bitCast(@IntType(false, info.bits), key), rng);
        },
        builtin.TypeId.Bool => return autoHash(@boolToInt(key), rng),
        builtin.TypeId.Enum => return autoHash(@enumToInt(key), rng),
        builtin.TypeId.ErrorSet => return autoHash(@errorToInt(key), rng),
        builtin.TypeId.Promise, builtin.TypeId.Fn => return autoHash(@ptrToInt(key), rng),

        builtin.TypeId.Namespace,
        builtin.TypeId.Block,
        builtin.TypeId.BoundFn,
        builtin.TypeId.ComptimeFloat,
        builtin.TypeId.ComptimeInt,
        builtin.TypeId.Type,
        => return 0,

        builtin.TypeId.Pointer => |info| switch (info.size) {
            builtin.TypeInfo.Pointer.Size.One => @compileError("TODO auto hash for single item pointers"),
            builtin.TypeInfo.Pointer.Size.Many => @compileError("TODO auto hash for many item pointers"),
            builtin.TypeInfo.Pointer.Size.Slice => {
                const interval = std.math.max(1, key.len / 256);
                var i: usize = 0;
                var h = comptime rng.scalar(HashInt);
                while (i < key.len) : (i += interval) {
                    h ^= autoHash(key[i], rng, HashInt);
                }
                return h;
            },
        },

        builtin.TypeId.Optional => @compileError("TODO auto hash for optionals"),
        builtin.TypeId.Array => @compileError("TODO auto hash for arrays"),
        builtin.TypeId.Struct => @compileError("TODO auto hash for structs"),
        builtin.TypeId.Union => @compileError("TODO auto hash for unions"),
        builtin.TypeId.ErrorUnion => @compileError("TODO auto hash for unions"),
    }
}

pub fn autoEql(a: var, b: @typeOf(a)) bool {
    switch (@typeInfo(@typeOf(a))) {
        builtin.TypeId.NoReturn,
        builtin.TypeId.Opaque,
        builtin.TypeId.Undefined,
        builtin.TypeId.ArgTuple,
        => @compileError("cannot test equality of this type"),
        builtin.TypeId.Void,
        builtin.TypeId.Null,
        => return true,
        builtin.TypeId.Bool,
        builtin.TypeId.Int,
        builtin.TypeId.Float,
        builtin.TypeId.ComptimeFloat,
        builtin.TypeId.ComptimeInt,
        builtin.TypeId.Namespace,
        builtin.TypeId.Block,
        builtin.TypeId.Promise,
        builtin.TypeId.Enum,
        builtin.TypeId.BoundFn,
        builtin.TypeId.Fn,
        builtin.TypeId.ErrorSet,
        builtin.TypeId.Type,
        => return a == b,

        builtin.TypeId.Pointer => |info| switch (info.size) {
            builtin.TypeInfo.Pointer.Size.One => @compileError("TODO auto eql for single item pointers"),
            builtin.TypeInfo.Pointer.Size.Many => @compileError("TODO auto eql for many item pointers"),
            builtin.TypeInfo.Pointer.Size.Slice => {
                if (a.len != b.len) return false;
                for (a) |a_item, i| {
                    if (!autoEql(a_item, b[i])) return false;
                }
                return true;
            },
        },

        builtin.TypeId.Optional => @compileError("TODO auto eql for optionals"),
        builtin.TypeId.Array => @compileError("TODO auto eql for arrays"),
        builtin.TypeId.Struct => @compileError("TODO auto eql for structs"),
        builtin.TypeId.Union => @compileError("TODO auto eql for unions"),
        builtin.TypeId.ErrorUnion => @compileError("TODO auto eql for unions"),
    }
}
