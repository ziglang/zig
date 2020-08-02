// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const math = std.math;
const mem = std.mem;
const meta = std.meta;
const trait = meta.trait;
const autoHash = std.hash.autoHash;
const Wyhash = std.hash.Wyhash;
const Allocator = mem.Allocator;
const builtin = @import("builtin");
const hash_map = @This();

pub fn AutoArrayHashMap(comptime K: type, comptime V: type) type {
    return ArrayHashMap(K, V, getAutoHashFn(K), getAutoEqlFn(K), autoEqlIsCheap(K));
}

pub fn AutoArrayHashMapUnmanaged(comptime K: type, comptime V: type) type {
    return ArrayHashMapUnmanaged(K, V, getAutoHashFn(K), getAutoEqlFn(K), autoEqlIsCheap(K));
}

/// Builtin hashmap for strings as keys.
pub fn StringArrayHashMap(comptime V: type) type {
    return ArrayHashMap([]const u8, V, hashString, eqlString, true);
}

pub fn StringArrayHashMapUnmanaged(comptime V: type) type {
    return ArrayHashMapUnmanaged([]const u8, V, hashString, eqlString, true);
}

pub fn eqlString(a: []const u8, b: []const u8) bool {
    return mem.eql(u8, a, b);
}

pub fn hashString(s: []const u8) u32 {
    return @truncate(u32, std.hash.Wyhash.hash(0, s));
}

/// Insertion order is preserved.
/// Deletions perform a "swap removal" on the entries list.
/// Modifying the hash map while iterating is allowed, however one must understand
/// the (well defined) behavior when mixing insertions and deletions with iteration.
/// For a hash map that can be initialized directly that does not store an Allocator
/// field, see `ArrayHashMapUnmanaged`.
/// When `store_hash` is `false`, this data structure is biased towards cheap `eql`
/// functions. It does not store each item's hash in the table. Setting `store_hash`
/// to `true` incurs slightly more memory cost by storing each key's hash in the table
/// but only has to call `eql` for hash collisions.
/// If typical operations (except iteration over entries) need to be faster, prefer
/// the alternative `std.HashMap`.
pub fn ArrayHashMap(
    comptime K: type,
    comptime V: type,
    comptime hash: fn (key: K) u32,
    comptime eql: fn (a: K, b: K) bool,
    comptime store_hash: bool,
) type {
    return struct {
        unmanaged: Unmanaged,
        allocator: *Allocator,

        pub const Unmanaged = ArrayHashMapUnmanaged(K, V, hash, eql, store_hash);
        pub const Entry = Unmanaged.Entry;
        pub const Hash = Unmanaged.Hash;
        pub const GetOrPutResult = Unmanaged.GetOrPutResult;

        /// Deprecated. Iterate using `items`.
        pub const Iterator = struct {
            hm: *const Self,
            /// Iterator through the entry array.
            index: usize,

            pub fn next(it: *Iterator) ?*Entry {
                if (it.index >= it.hm.unmanaged.entries.items.len) return null;
                const result = &it.hm.unmanaged.entries.items[it.index];
                it.index += 1;
                return result;
            }

            /// Reset the iterator to the initial index
            pub fn reset(it: *Iterator) void {
                it.index = 0;
            }
        };

        const Self = @This();
        const Index = Unmanaged.Index;

        pub fn init(allocator: *Allocator) Self {
            return .{
                .unmanaged = .{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.unmanaged.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            return self.unmanaged.clearRetainingCapacity();
        }

        pub fn clearAndFree(self: *Self) void {
            return self.unmanaged.clearAndFree(self.allocator);
        }

        /// Deprecated. Use `items().len`.
        pub fn count(self: Self) usize {
            return self.items().len;
        }

        /// Deprecated. Iterate using `items`.
        pub fn iterator(self: *const Self) Iterator {
            return Iterator{
                .hm = self,
                .index = 0,
            };
        }

        /// If key exists this function cannot fail.
        /// If there is an existing item with `key`, then the result
        /// `Entry` pointer points to it, and found_existing is true.
        /// Otherwise, puts a new item with undefined value, and
        /// the `Entry` pointer points to it. Caller should then initialize
        /// the value (but not the key).
        pub fn getOrPut(self: *Self, key: K) !GetOrPutResult {
            return self.unmanaged.getOrPut(self.allocator, key);
        }

        /// If there is an existing item with `key`, then the result
        /// `Entry` pointer points to it, and found_existing is true.
        /// Otherwise, puts a new item with undefined value, and
        /// the `Entry` pointer points to it. Caller should then initialize
        /// the value (but not the key).
        /// If a new entry needs to be stored, this function asserts there
        /// is enough capacity to store it.
        pub fn getOrPutAssumeCapacity(self: *Self, key: K) GetOrPutResult {
            return self.unmanaged.getOrPutAssumeCapacity(key);
        }

        pub fn getOrPutValue(self: *Self, key: K, value: V) !*Entry {
            return self.unmanaged.getOrPutValue(self.allocator, key, value);
        }

        /// Increases capacity, guaranteeing that insertions up until the
        /// `expected_count` will not cause an allocation, and therefore cannot fail.
        pub fn ensureCapacity(self: *Self, new_capacity: usize) !void {
            return self.unmanaged.ensureCapacity(self.allocator, new_capacity);
        }

        /// Returns the number of total elements which may be present before it is
        /// no longer guaranteed that no allocations will be performed.
        pub fn capacity(self: *Self) usize {
            return self.unmanaged.capacity();
        }

        /// Clobbers any existing data. To detect if a put would clobber
        /// existing data, see `getOrPut`.
        pub fn put(self: *Self, key: K, value: V) !void {
            return self.unmanaged.put(self.allocator, key, value);
        }

        /// Inserts a key-value pair into the hash map, asserting that no previous
        /// entry with the same key is already present
        pub fn putNoClobber(self: *Self, key: K, value: V) !void {
            return self.unmanaged.putNoClobber(self.allocator, key, value);
        }

        /// Asserts there is enough capacity to store the new key-value pair.
        /// Clobbers any existing data. To detect if a put would clobber
        /// existing data, see `getOrPutAssumeCapacity`.
        pub fn putAssumeCapacity(self: *Self, key: K, value: V) void {
            return self.unmanaged.putAssumeCapacity(key, value);
        }

        /// Asserts there is enough capacity to store the new key-value pair.
        /// Asserts that it does not clobber any existing data.
        /// To detect if a put would clobber existing data, see `getOrPutAssumeCapacity`.
        pub fn putAssumeCapacityNoClobber(self: *Self, key: K, value: V) void {
            return self.unmanaged.putAssumeCapacityNoClobber(key, value);
        }

        /// Inserts a new `Entry` into the hash map, returning the previous one, if any.
        pub fn fetchPut(self: *Self, key: K, value: V) !?Entry {
            return self.unmanaged.fetchPut(self.allocator, key, value);
        }

        /// Inserts a new `Entry` into the hash map, returning the previous one, if any.
        /// If insertion happuns, asserts there is enough capacity without allocating.
        pub fn fetchPutAssumeCapacity(self: *Self, key: K, value: V) ?Entry {
            return self.unmanaged.fetchPutAssumeCapacity(key, value);
        }

        pub fn getEntry(self: Self, key: K) ?*Entry {
            return self.unmanaged.getEntry(key);
        }

        pub fn getIndex(self: Self, key: K) ?usize {
            return self.unmanaged.getIndex(key);
        }

        pub fn get(self: Self, key: K) ?V {
            return self.unmanaged.get(key);
        }

        pub fn contains(self: Self, key: K) bool {
            return self.unmanaged.contains(key);
        }

        /// If there is an `Entry` with a matching key, it is deleted from
        /// the hash map, and then returned from this function.
        pub fn remove(self: *Self, key: K) ?Entry {
            return self.unmanaged.remove(key);
        }

        /// Asserts there is an `Entry` with matching key, deletes it from the hash map,
        /// and discards it.
        pub fn removeAssertDiscard(self: *Self, key: K) void {
            return self.unmanaged.removeAssertDiscard(key);
        }

        pub fn items(self: Self) []Entry {
            return self.unmanaged.items();
        }

        pub fn clone(self: Self) !Self {
            var other = try self.unmanaged.clone(self.allocator);
            return other.promote(self.allocator);
        }
    };
}

/// General purpose hash table.
/// Insertion order is preserved.
/// Deletions perform a "swap removal" on the entries list.
/// Modifying the hash map while iterating is allowed, however one must understand
/// the (well defined) behavior when mixing insertions and deletions with iteration.
/// This type does not store an Allocator field - the Allocator must be passed in
/// with each function call that requires it. See `ArrayHashMap` for a type that stores
/// an Allocator field for convenience.
/// Can be initialized directly using the default field values.
/// This type is designed to have low overhead for small numbers of entries. When
/// `store_hash` is `false` and the number of entries in the map is less than 9,
/// the overhead cost of using `ArrayHashMapUnmanaged` rather than `std.ArrayList` is
/// only a single pointer-sized integer.
/// When `store_hash` is `false`, this data structure is biased towards cheap `eql`
/// functions. It does not store each item's hash in the table. Setting `store_hash`
/// to `true` incurs slightly more memory cost by storing each key's hash in the table
/// but guarantees only one call to `eql` per insertion/deletion.
pub fn ArrayHashMapUnmanaged(
    comptime K: type,
    comptime V: type,
    comptime hash: fn (key: K) u32,
    comptime eql: fn (a: K, b: K) bool,
    comptime store_hash: bool,
) type {
    return struct {
        /// It is permitted to access this field directly.
        entries: std.ArrayListUnmanaged(Entry) = .{},

        /// When entries length is less than `linear_scan_max`, this remains `null`.
        /// Once entries length grows big enough, this field is allocated. There is
        /// an IndexHeader followed by an array of Index(I) structs, where I is defined
        /// by how many total indexes there are.
        index_header: ?*IndexHeader = null,

        /// Modifying the key is illegal behavior.
        /// Modifying the value is allowed.
        /// Entry pointers become invalid whenever this ArrayHashMap is modified,
        /// unless `ensureCapacity` was previously used.
        pub const Entry = struct {
            /// This field is `void` if `store_hash` is `false`.
            hash: Hash,
            key: K,
            value: V,
        };

        pub const Hash = if (store_hash) u32 else void;

        pub const GetOrPutResult = struct {
            entry: *Entry,
            found_existing: bool,
        };

        pub const Managed = ArrayHashMap(K, V, hash, eql, store_hash);

        const Self = @This();

        const linear_scan_max = 8;

        pub fn promote(self: Self, allocator: *Allocator) Managed {
            return .{
                .unmanaged = self,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self, allocator: *Allocator) void {
            self.entries.deinit(allocator);
            if (self.index_header) |header| {
                header.free(allocator);
            }
            self.* = undefined;
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.entries.items.len = 0;
            if (self.index_header) |header| {
                header.max_distance_from_start_index = 0;
                switch (header.capacityIndexType()) {
                    .u8 => mem.set(Index(u8), header.indexes(u8), Index(u8).empty),
                    .u16 => mem.set(Index(u16), header.indexes(u16), Index(u16).empty),
                    .u32 => mem.set(Index(u32), header.indexes(u32), Index(u32).empty),
                    .usize => mem.set(Index(usize), header.indexes(usize), Index(usize).empty),
                }
            }
        }

        pub fn clearAndFree(self: *Self, allocator: *Allocator) void {
            self.entries.shrink(allocator, 0);
            if (self.index_header) |header| {
                header.free(allocator);
                self.index_header = null;
            }
        }

        /// If key exists this function cannot fail.
        /// If there is an existing item with `key`, then the result
        /// `Entry` pointer points to it, and found_existing is true.
        /// Otherwise, puts a new item with undefined value, and
        /// the `Entry` pointer points to it. Caller should then initialize
        /// the value (but not the key).
        pub fn getOrPut(self: *Self, allocator: *Allocator, key: K) !GetOrPutResult {
            self.ensureCapacity(allocator, self.entries.items.len + 1) catch |err| {
                // "If key exists this function cannot fail."
                return GetOrPutResult{
                    .entry = self.getEntry(key) orelse return err,
                    .found_existing = true,
                };
            };
            return self.getOrPutAssumeCapacity(key);
        }

        /// If there is an existing item with `key`, then the result
        /// `Entry` pointer points to it, and found_existing is true.
        /// Otherwise, puts a new item with undefined value, and
        /// the `Entry` pointer points to it. Caller should then initialize
        /// the value (but not the key).
        /// If a new entry needs to be stored, this function asserts there
        /// is enough capacity to store it.
        pub fn getOrPutAssumeCapacity(self: *Self, key: K) GetOrPutResult {
            const header = self.index_header orelse {
                // Linear scan.
                const h = if (store_hash) hash(key) else {};
                for (self.entries.items) |*item| {
                    if (item.hash == h and eql(key, item.key)) {
                        return GetOrPutResult{
                            .entry = item,
                            .found_existing = true,
                        };
                    }
                }
                const new_entry = self.entries.addOneAssumeCapacity();
                new_entry.* = .{
                    .hash = if (store_hash) h else {},
                    .key = key,
                    .value = undefined,
                };
                return GetOrPutResult{
                    .entry = new_entry,
                    .found_existing = false,
                };
            };

            switch (header.capacityIndexType()) {
                .u8 => return self.getOrPutInternal(key, header, u8),
                .u16 => return self.getOrPutInternal(key, header, u16),
                .u32 => return self.getOrPutInternal(key, header, u32),
                .usize => return self.getOrPutInternal(key, header, usize),
            }
        }

        pub fn getOrPutValue(self: *Self, allocator: *Allocator, key: K, value: V) !*Entry {
            const res = try self.getOrPut(allocator, key);
            if (!res.found_existing)
                res.entry.value = value;

            return res.entry;
        }

        /// Increases capacity, guaranteeing that insertions up until the
        /// `expected_count` will not cause an allocation, and therefore cannot fail.
        pub fn ensureCapacity(self: *Self, allocator: *Allocator, new_capacity: usize) !void {
            try self.entries.ensureCapacity(allocator, new_capacity);
            if (new_capacity <= linear_scan_max) return;

            // Ensure that the indexes will be at most 60% full if
            // `new_capacity` items are put into it.
            const needed_len = new_capacity * 5 / 3;
            if (self.index_header) |header| {
                if (needed_len > header.indexes_len) {
                    // An overflow here would mean the amount of memory required would not
                    // be representable in the address space.
                    const new_indexes_len = math.ceilPowerOfTwo(usize, needed_len) catch unreachable;
                    const new_header = try IndexHeader.alloc(allocator, new_indexes_len);
                    self.insertAllEntriesIntoNewHeader(new_header);
                    header.free(allocator);
                    self.index_header = new_header;
                }
            } else {
                // An overflow here would mean the amount of memory required would not
                // be representable in the address space.
                const new_indexes_len = math.ceilPowerOfTwo(usize, needed_len) catch unreachable;
                const header = try IndexHeader.alloc(allocator, new_indexes_len);
                self.insertAllEntriesIntoNewHeader(header);
                self.index_header = header;
            }
        }

        /// Returns the number of total elements which may be present before it is
        /// no longer guaranteed that no allocations will be performed.
        pub fn capacity(self: Self) usize {
            const entry_cap = self.entries.capacity;
            const header = self.index_header orelse return math.min(linear_scan_max, entry_cap);
            const indexes_cap = (header.indexes_len + 1) * 3 / 4;
            return math.min(entry_cap, indexes_cap);
        }

        /// Clobbers any existing data. To detect if a put would clobber
        /// existing data, see `getOrPut`.
        pub fn put(self: *Self, allocator: *Allocator, key: K, value: V) !void {
            const result = try self.getOrPut(allocator, key);
            result.entry.value = value;
        }

        /// Inserts a key-value pair into the hash map, asserting that no previous
        /// entry with the same key is already present
        pub fn putNoClobber(self: *Self, allocator: *Allocator, key: K, value: V) !void {
            const result = try self.getOrPut(allocator, key);
            assert(!result.found_existing);
            result.entry.value = value;
        }

        /// Asserts there is enough capacity to store the new key-value pair.
        /// Clobbers any existing data. To detect if a put would clobber
        /// existing data, see `getOrPutAssumeCapacity`.
        pub fn putAssumeCapacity(self: *Self, key: K, value: V) void {
            const result = self.getOrPutAssumeCapacity(key);
            result.entry.value = value;
        }

        /// Asserts there is enough capacity to store the new key-value pair.
        /// Asserts that it does not clobber any existing data.
        /// To detect if a put would clobber existing data, see `getOrPutAssumeCapacity`.
        pub fn putAssumeCapacityNoClobber(self: *Self, key: K, value: V) void {
            const result = self.getOrPutAssumeCapacity(key);
            assert(!result.found_existing);
            result.entry.value = value;
        }

        /// Inserts a new `Entry` into the hash map, returning the previous one, if any.
        pub fn fetchPut(self: *Self, allocator: *Allocator, key: K, value: V) !?Entry {
            const gop = try self.getOrPut(allocator, key);
            var result: ?Entry = null;
            if (gop.found_existing) {
                result = gop.entry.*;
            }
            gop.entry.value = value;
            return result;
        }

        /// Inserts a new `Entry` into the hash map, returning the previous one, if any.
        /// If insertion happens, asserts there is enough capacity without allocating.
        pub fn fetchPutAssumeCapacity(self: *Self, key: K, value: V) ?Entry {
            const gop = self.getOrPutAssumeCapacity(key);
            var result: ?Entry = null;
            if (gop.found_existing) {
                result = gop.entry.*;
            }
            gop.entry.value = value;
            return result;
        }

        pub fn getEntry(self: Self, key: K) ?*Entry {
            const index = self.getIndex(key) orelse return null;
            return &self.entries.items[index];
        }

        pub fn getIndex(self: Self, key: K) ?usize {
            const header = self.index_header orelse {
                // Linear scan.
                const h = if (store_hash) hash(key) else {};
                for (self.entries.items) |*item, i| {
                    if (item.hash == h and eql(key, item.key)) {
                        return i;
                    }
                }
                return null;
            };
            switch (header.capacityIndexType()) {
                .u8 => return self.getInternal(key, header, u8),
                .u16 => return self.getInternal(key, header, u16),
                .u32 => return self.getInternal(key, header, u32),
                .usize => return self.getInternal(key, header, usize),
            }
        }

        pub fn get(self: Self, key: K) ?V {
            return if (self.getEntry(key)) |entry| entry.value else null;
        }

        pub fn contains(self: Self, key: K) bool {
            return self.getEntry(key) != null;
        }

        /// If there is an `Entry` with a matching key, it is deleted from
        /// the hash map, and then returned from this function.
        pub fn remove(self: *Self, key: K) ?Entry {
            const header = self.index_header orelse {
                // Linear scan.
                const h = if (store_hash) hash(key) else {};
                for (self.entries.items) |item, i| {
                    if (item.hash == h and eql(key, item.key)) {
                        return self.entries.swapRemove(i);
                    }
                }
                return null;
            };
            switch (header.capacityIndexType()) {
                .u8 => return self.removeInternal(key, header, u8),
                .u16 => return self.removeInternal(key, header, u16),
                .u32 => return self.removeInternal(key, header, u32),
                .usize => return self.removeInternal(key, header, usize),
            }
        }

        /// Asserts there is an `Entry` with matching key, deletes it from the hash map,
        /// and discards it.
        pub fn removeAssertDiscard(self: *Self, key: K) void {
            assert(self.remove(key) != null);
        }

        pub fn items(self: Self) []Entry {
            return self.entries.items;
        }

        pub fn clone(self: Self, allocator: *Allocator) !Self {
            var other: Self = .{};
            try other.entries.appendSlice(allocator, self.entries.items);

            if (self.index_header) |header| {
                const new_header = try IndexHeader.alloc(allocator, header.indexes_len);
                other.insertAllEntriesIntoNewHeader(new_header);
                other.index_header = new_header;
            }
            return other;
        }

        fn removeInternal(self: *Self, key: K, header: *IndexHeader, comptime I: type) ?Entry {
            const indexes = header.indexes(I);
            const h = hash(key);
            const start_index = header.constrainIndex(h);
            var roll_over: usize = 0;
            while (roll_over <= header.max_distance_from_start_index) : (roll_over += 1) {
                const index_index = header.constrainIndex(start_index + roll_over);
                var index = &indexes[index_index];
                if (index.isEmpty())
                    return null;

                const entry = &self.entries.items[index.entry_index];

                const hash_match = if (store_hash) h == entry.hash else true;
                if (!hash_match or !eql(key, entry.key))
                    continue;

                const removed_entry = self.entries.swapRemove(index.entry_index);
                if (self.entries.items.len > 0 and self.entries.items.len != index.entry_index) {
                    // Because of the swap remove, now we need to update the index that was
                    // pointing to the last entry and is now pointing to this removed item slot.
                    self.updateEntryIndex(header, self.entries.items.len, index.entry_index, I, indexes);
                }

                // Now we have to shift over the following indexes.
                roll_over += 1;
                while (roll_over < header.indexes_len) : (roll_over += 1) {
                    const next_index_index = header.constrainIndex(start_index + roll_over);
                    const next_index = &indexes[next_index_index];
                    if (next_index.isEmpty() or next_index.distance_from_start_index == 0) {
                        index.setEmpty();
                        return removed_entry;
                    }
                    index.* = next_index.*;
                    index.distance_from_start_index -= 1;
                    index = next_index;
                }
                unreachable;
            }
            return null;
        }

        fn updateEntryIndex(
            self: *Self,
            header: *IndexHeader,
            old_entry_index: usize,
            new_entry_index: usize,
            comptime I: type,
            indexes: []Index(I),
        ) void {
            const h = if (store_hash) self.entries.items[new_entry_index].hash else hash(self.entries.items[new_entry_index].key);
            const start_index = header.constrainIndex(h);
            var roll_over: usize = 0;
            while (roll_over <= header.max_distance_from_start_index) : (roll_over += 1) {
                const index_index = header.constrainIndex(start_index + roll_over);
                const index = &indexes[index_index];
                if (index.entry_index == old_entry_index) {
                    index.entry_index = @intCast(I, new_entry_index);
                    return;
                }
            }
            unreachable;
        }

        /// Must ensureCapacity before calling this.
        fn getOrPutInternal(self: *Self, key: K, header: *IndexHeader, comptime I: type) GetOrPutResult {
            const indexes = header.indexes(I);
            const h = hash(key);
            const start_index = header.constrainIndex(h);
            var roll_over: usize = 0;
            var distance_from_start_index: usize = 0;
            while (roll_over <= header.indexes_len) : ({
                roll_over += 1;
                distance_from_start_index += 1;
            }) {
                const index_index = header.constrainIndex(start_index + roll_over);
                const index = indexes[index_index];
                if (index.isEmpty()) {
                    indexes[index_index] = .{
                        .distance_from_start_index = @intCast(I, distance_from_start_index),
                        .entry_index = @intCast(I, self.entries.items.len),
                    };
                    header.maybeBumpMax(distance_from_start_index);
                    const new_entry = self.entries.addOneAssumeCapacity();
                    new_entry.* = .{
                        .hash = if (store_hash) h else {},
                        .key = key,
                        .value = undefined,
                    };
                    return .{
                        .found_existing = false,
                        .entry = new_entry,
                    };
                }

                // This pointer survives the following append because we call
                // entries.ensureCapacity before getOrPutInternal.
                const entry = &self.entries.items[index.entry_index];
                const hash_match = if (store_hash) h == entry.hash else true;
                if (hash_match and eql(key, entry.key)) {
                    return .{
                        .found_existing = true,
                        .entry = entry,
                    };
                }
                if (index.distance_from_start_index < distance_from_start_index) {
                    // In this case, we did not find the item. We will put a new entry.
                    // However, we will use this index for the new entry, and move
                    // the previous index down the line, to keep the max_distance_from_start_index
                    // as small as possible.
                    indexes[index_index] = .{
                        .distance_from_start_index = @intCast(I, distance_from_start_index),
                        .entry_index = @intCast(I, self.entries.items.len),
                    };
                    header.maybeBumpMax(distance_from_start_index);
                    const new_entry = self.entries.addOneAssumeCapacity();
                    new_entry.* = .{
                        .hash = if (store_hash) h else {},
                        .key = key,
                        .value = undefined,
                    };

                    distance_from_start_index = index.distance_from_start_index;
                    var prev_entry_index = index.entry_index;

                    // Find somewhere to put the index we replaced by shifting
                    // following indexes backwards.
                    roll_over += 1;
                    distance_from_start_index += 1;
                    while (roll_over < header.indexes_len) : ({
                        roll_over += 1;
                        distance_from_start_index += 1;
                    }) {
                        const next_index_index = header.constrainIndex(start_index + roll_over);
                        const next_index = indexes[next_index_index];
                        if (next_index.isEmpty()) {
                            header.maybeBumpMax(distance_from_start_index);
                            indexes[next_index_index] = .{
                                .entry_index = prev_entry_index,
                                .distance_from_start_index = @intCast(I, distance_from_start_index),
                            };
                            return .{
                                .found_existing = false,
                                .entry = new_entry,
                            };
                        }
                        if (next_index.distance_from_start_index < distance_from_start_index) {
                            header.maybeBumpMax(distance_from_start_index);
                            indexes[next_index_index] = .{
                                .entry_index = prev_entry_index,
                                .distance_from_start_index = @intCast(I, distance_from_start_index),
                            };
                            distance_from_start_index = next_index.distance_from_start_index;
                            prev_entry_index = next_index.entry_index;
                        }
                    }
                    unreachable;
                }
            }
            unreachable;
        }

        fn getInternal(self: Self, key: K, header: *IndexHeader, comptime I: type) ?usize {
            const indexes = header.indexes(I);
            const h = hash(key);
            const start_index = header.constrainIndex(h);
            var roll_over: usize = 0;
            while (roll_over <= header.max_distance_from_start_index) : (roll_over += 1) {
                const index_index = header.constrainIndex(start_index + roll_over);
                const index = indexes[index_index];
                if (index.isEmpty())
                    return null;

                const entry = &self.entries.items[index.entry_index];
                const hash_match = if (store_hash) h == entry.hash else true;
                if (hash_match and eql(key, entry.key))
                    return index.entry_index;
            }
            return null;
        }

        fn insertAllEntriesIntoNewHeader(self: *Self, header: *IndexHeader) void {
            switch (header.capacityIndexType()) {
                .u8 => return self.insertAllEntriesIntoNewHeaderGeneric(header, u8),
                .u16 => return self.insertAllEntriesIntoNewHeaderGeneric(header, u16),
                .u32 => return self.insertAllEntriesIntoNewHeaderGeneric(header, u32),
                .usize => return self.insertAllEntriesIntoNewHeaderGeneric(header, usize),
            }
        }

        fn insertAllEntriesIntoNewHeaderGeneric(self: *Self, header: *IndexHeader, comptime I: type) void {
            const indexes = header.indexes(I);
            entry_loop: for (self.entries.items) |entry, i| {
                const h = if (store_hash) entry.hash else hash(entry.key);
                const start_index = header.constrainIndex(h);
                var entry_index = i;
                var roll_over: usize = 0;
                var distance_from_start_index: usize = 0;
                while (roll_over < header.indexes_len) : ({
                    roll_over += 1;
                    distance_from_start_index += 1;
                }) {
                    const index_index = header.constrainIndex(start_index + roll_over);
                    const next_index = indexes[index_index];
                    if (next_index.isEmpty()) {
                        header.maybeBumpMax(distance_from_start_index);
                        indexes[index_index] = .{
                            .distance_from_start_index = @intCast(I, distance_from_start_index),
                            .entry_index = @intCast(I, entry_index),
                        };
                        continue :entry_loop;
                    }
                    if (next_index.distance_from_start_index < distance_from_start_index) {
                        header.maybeBumpMax(distance_from_start_index);
                        indexes[index_index] = .{
                            .distance_from_start_index = @intCast(I, distance_from_start_index),
                            .entry_index = @intCast(I, entry_index),
                        };
                        distance_from_start_index = next_index.distance_from_start_index;
                        entry_index = next_index.entry_index;
                    }
                }
                unreachable;
            }
        }
    };
}

const CapacityIndexType = enum { u8, u16, u32, usize };

fn capacityIndexType(indexes_len: usize) CapacityIndexType {
    if (indexes_len < math.maxInt(u8))
        return .u8;
    if (indexes_len < math.maxInt(u16))
        return .u16;
    if (indexes_len < math.maxInt(u32))
        return .u32;
    return .usize;
}

fn capacityIndexSize(indexes_len: usize) usize {
    switch (capacityIndexType(indexes_len)) {
        .u8 => return @sizeOf(Index(u8)),
        .u16 => return @sizeOf(Index(u16)),
        .u32 => return @sizeOf(Index(u32)),
        .usize => return @sizeOf(Index(usize)),
    }
}

fn Index(comptime I: type) type {
    return extern struct {
        entry_index: I,
        distance_from_start_index: I,

        const Self = @This();

        const empty = Self{
            .entry_index = math.maxInt(I),
            .distance_from_start_index = undefined,
        };

        fn isEmpty(idx: Self) bool {
            return idx.entry_index == math.maxInt(I);
        }

        fn setEmpty(idx: *Self) void {
            idx.entry_index = math.maxInt(I);
        }
    };
}

/// This struct is trailed by an array of `Index(I)`, where `I`
/// and the array length are determined by `indexes_len`.
const IndexHeader = struct {
    max_distance_from_start_index: usize,
    indexes_len: usize,

    fn constrainIndex(header: IndexHeader, i: usize) usize {
        // This is an optimization for modulo of power of two integers;
        // it requires `indexes_len` to always be a power of two.
        return i & (header.indexes_len - 1);
    }

    fn indexes(header: *IndexHeader, comptime I: type) []Index(I) {
        const start = @ptrCast([*]Index(I), @ptrCast([*]u8, header) + @sizeOf(IndexHeader));
        return start[0..header.indexes_len];
    }

    fn capacityIndexType(header: IndexHeader) CapacityIndexType {
        return hash_map.capacityIndexType(header.indexes_len);
    }

    fn maybeBumpMax(header: *IndexHeader, distance_from_start_index: usize) void {
        if (distance_from_start_index > header.max_distance_from_start_index) {
            header.max_distance_from_start_index = distance_from_start_index;
        }
    }

    fn alloc(allocator: *Allocator, len: usize) !*IndexHeader {
        const index_size = hash_map.capacityIndexSize(len);
        const nbytes = @sizeOf(IndexHeader) + index_size * len;
        const bytes = try allocator.allocAdvanced(u8, @alignOf(IndexHeader), nbytes, .exact);
        @memset(bytes.ptr + @sizeOf(IndexHeader), 0xff, bytes.len - @sizeOf(IndexHeader));
        const result = @ptrCast(*IndexHeader, bytes.ptr);
        result.* = .{
            .max_distance_from_start_index = 0,
            .indexes_len = len,
        };
        return result;
    }

    fn free(header: *IndexHeader, allocator: *Allocator) void {
        const index_size = hash_map.capacityIndexSize(header.indexes_len);
        const ptr = @ptrCast([*]u8, header);
        const slice = ptr[0 .. @sizeOf(IndexHeader) + header.indexes_len * index_size];
        allocator.free(slice);
    }
};

test "basic hash map usage" {
    var map = AutoArrayHashMap(i32, i32).init(std.testing.allocator);
    defer map.deinit();

    testing.expect((try map.fetchPut(1, 11)) == null);
    testing.expect((try map.fetchPut(2, 22)) == null);
    testing.expect((try map.fetchPut(3, 33)) == null);
    testing.expect((try map.fetchPut(4, 44)) == null);

    try map.putNoClobber(5, 55);
    testing.expect((try map.fetchPut(5, 66)).?.value == 55);
    testing.expect((try map.fetchPut(5, 55)).?.value == 66);

    const gop1 = try map.getOrPut(5);
    testing.expect(gop1.found_existing == true);
    testing.expect(gop1.entry.value == 55);
    gop1.entry.value = 77;
    testing.expect(map.getEntry(5).?.value == 77);

    const gop2 = try map.getOrPut(99);
    testing.expect(gop2.found_existing == false);
    gop2.entry.value = 42;
    testing.expect(map.getEntry(99).?.value == 42);

    const gop3 = try map.getOrPutValue(5, 5);
    testing.expect(gop3.value == 77);

    const gop4 = try map.getOrPutValue(100, 41);
    testing.expect(gop4.value == 41);

    testing.expect(map.contains(2));
    testing.expect(map.getEntry(2).?.value == 22);
    testing.expect(map.get(2).? == 22);

    const rmv1 = map.remove(2);
    testing.expect(rmv1.?.key == 2);
    testing.expect(rmv1.?.value == 22);
    testing.expect(map.remove(2) == null);
    testing.expect(map.getEntry(2) == null);
    testing.expect(map.get(2) == null);

    map.removeAssertDiscard(3);
}

test "iterator hash map" {
    // https://github.com/ziglang/zig/issues/5127
    if (std.Target.current.cpu.arch == .mips) return error.SkipZigTest;

    var reset_map = AutoArrayHashMap(i32, i32).init(std.testing.allocator);
    defer reset_map.deinit();

    // test ensureCapacity with a 0 parameter
    try reset_map.ensureCapacity(0);

    try reset_map.putNoClobber(0, 11);
    try reset_map.putNoClobber(1, 22);
    try reset_map.putNoClobber(2, 33);

    var keys = [_]i32{
        0, 2, 1,
    };

    var values = [_]i32{
        11, 33, 22,
    };

    var buffer = [_]i32{
        0, 0, 0,
    };

    var it = reset_map.iterator();
    const first_entry = it.next().?;
    it.reset();

    var count: usize = 0;
    while (it.next()) |entry| : (count += 1) {
        buffer[@intCast(usize, entry.key)] = entry.value;
    }
    testing.expect(count == 3);
    testing.expect(it.next() == null);

    for (buffer) |v, i| {
        testing.expect(buffer[@intCast(usize, keys[i])] == values[i]);
    }

    it.reset();
    count = 0;
    while (it.next()) |entry| {
        buffer[@intCast(usize, entry.key)] = entry.value;
        count += 1;
        if (count >= 2) break;
    }

    for (buffer[0..2]) |v, i| {
        testing.expect(buffer[@intCast(usize, keys[i])] == values[i]);
    }

    it.reset();
    var entry = it.next().?;
    testing.expect(entry.key == first_entry.key);
    testing.expect(entry.value == first_entry.value);
}

test "ensure capacity" {
    var map = AutoArrayHashMap(i32, i32).init(std.testing.allocator);
    defer map.deinit();

    try map.ensureCapacity(20);
    const initial_capacity = map.capacity();
    testing.expect(initial_capacity >= 20);
    var i: i32 = 0;
    while (i < 20) : (i += 1) {
        testing.expect(map.fetchPutAssumeCapacity(i, i + 10) == null);
    }
    // shouldn't resize from putAssumeCapacity
    testing.expect(initial_capacity == map.capacity());
}

test "clone" {
    var original = AutoArrayHashMap(i32, i32).init(std.testing.allocator);
    defer original.deinit();

    // put more than `linear_scan_max` so we can test that the index header is properly cloned
    var i: u8 = 0;
    while (i < 10) : (i += 1) {
        try original.putNoClobber(i, i * 10);
    }

    var copy = try original.clone();
    defer copy.deinit();

    i = 0;
    while (i < 10) : (i += 1) {
        testing.expect(copy.get(i).? == i * 10);
    }
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
            if (comptime trait.hasUniqueRepresentation(K)) {
                return @truncate(u32, Wyhash.hash(0, std.mem.asBytes(&key)));
            } else {
                var hasher = Wyhash.init(0);
                autoHash(&hasher, key);
                return @truncate(u32, hasher.final());
            }
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

pub fn autoEqlIsCheap(comptime K: type) bool {
    return switch (@typeInfo(K)) {
        .Bool,
        .Int,
        .Float,
        .Pointer,
        .ComptimeFloat,
        .ComptimeInt,
        .Enum,
        .Fn,
        .ErrorSet,
        .AnyFrame,
        .EnumLiteral,
        => true,
        else => false,
    };
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
