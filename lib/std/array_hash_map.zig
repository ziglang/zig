// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
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
const builtin = std.builtin;
const hash_map = @This();

/// An ArrayHashMap with default hash and equal functions.
/// See AutoContext for a description of the hash and equal implementations.
pub fn AutoArrayHashMap(comptime K: type, comptime V: type) type {
    return ArrayHashMap(K, V, AutoContext(K), !autoEqlIsCheap(K));
}

/// An ArrayHashMapUnmanaged with default hash and equal functions.
/// See AutoContext for a description of the hash and equal implementations.
pub fn AutoArrayHashMapUnmanaged(comptime K: type, comptime V: type) type {
    return ArrayHashMapUnmanaged(K, V, AutoContext(K), !autoEqlIsCheap(K));
}

/// Builtin hashmap for strings as keys.
pub fn StringArrayHashMap(comptime V: type) type {
    return ArrayHashMap([]const u8, V, StringContext, true);
}

pub fn StringArrayHashMapUnmanaged(comptime V: type) type {
    return ArrayHashMapUnmanaged([]const u8, V, StringContext, true);
}

pub const StringContext = struct {
    pub fn hash(self: @This(), s: []const u8) u32 {
        return hashString(s);
    }
    pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
        return eqlString(a, b);
    }
};

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
/// Context must be a struct type with two member functions:
///   hash(self, K) u32
///   eql(self, K, K) bool
/// Adapted variants of many functions are provided.  These variants
/// take a pseudo key instead of a key.  Their context must have the functions:
///   hash(self, PseudoKey) u32
///   eql(self, PseudoKey, K) bool
pub fn ArrayHashMap(
    comptime K: type,
    comptime V: type,
    comptime Context: type,
    comptime store_hash: bool,
) type {
    comptime std.hash_map.verifyContext(Context, K, K, u32);
    return struct {
        unmanaged: Unmanaged,
        allocator: *Allocator,
        ctx: Context,

        /// The ArrayHashMapUnmanaged type using the same settings as this managed map.
        pub const Unmanaged = ArrayHashMapUnmanaged(K, V, Context, store_hash);

        /// Pointers to a key and value in the backing store of this map.
        /// Modifying the key is allowed only if it does not change the hash.
        /// Modifying the value is allowed.
        /// Entry pointers become invalid whenever this ArrayHashMap is modified,
        /// unless `ensureCapacity` was previously used.
        pub const Entry = Unmanaged.Entry;

        /// A KV pair which has been copied out of the backing store
        pub const KV = Unmanaged.KV;

        /// The Data type used for the MultiArrayList backing this map
        pub const Data = Unmanaged.Data;
        /// The MultiArrayList type backing this map
        pub const DataList = Unmanaged.DataList;

        /// The stored hash type, either u32 or void.
        pub const Hash = Unmanaged.Hash;

        /// getOrPut variants return this structure, with pointers
        /// to the backing store and a flag to indicate whether an
        /// existing entry was found.
        /// Modifying the key is allowed only if it does not change the hash.
        /// Modifying the value is allowed.
        /// Entry pointers become invalid whenever this ArrayHashMap is modified,
        /// unless `ensureCapacity` was previously used.
        pub const GetOrPutResult = Unmanaged.GetOrPutResult;

        /// An Iterator over Entry pointers.
        pub const Iterator = Unmanaged.Iterator;

        const Self = @This();

        /// Create an ArrayHashMap instance which will use a specified allocator.
        pub fn init(allocator: *Allocator) Self {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call initContext instead.");
            return initContext(allocator, undefined);
        }
        pub fn initContext(allocator: *Allocator, ctx: Context) Self {
            return .{
                .unmanaged = .{},
                .allocator = allocator,
                .ctx = ctx,
            };
        }

        /// Frees the backing allocation and leaves the map in an undefined state.
        /// Note that this does not free keys or values.  You must take care of that
        /// before calling this function, if it is needed.
        pub fn deinit(self: *Self) void {
            self.unmanaged.deinit(self.allocator);
            self.* = undefined;
        }

        /// Clears the map but retains the backing allocation for future use.
        pub fn clearRetainingCapacity(self: *Self) void {
            return self.unmanaged.clearRetainingCapacity();
        }

        /// Clears the map and releases the backing allocation
        pub fn clearAndFree(self: *Self) void {
            return self.unmanaged.clearAndFree(self.allocator);
        }

        /// Returns the number of KV pairs stored in this map.
        pub fn count(self: Self) usize {
            return self.unmanaged.count();
        }

        /// Returns the backing array of keys in this map.
        /// Modifying the map may invalidate this array.
        pub fn keys(self: Self) []K {
            return self.unmanaged.keys();
        }
        /// Returns the backing array of values in this map.
        /// Modifying the map may invalidate this array.
        pub fn values(self: Self) []V {
            return self.unmanaged.values();
        }

        /// Returns an iterator over the pairs in this map.
        /// Modifying the map may invalidate this iterator.
        pub fn iterator(self: *const Self) Iterator {
            return self.unmanaged.iterator();
        }

        /// If key exists this function cannot fail.
        /// If there is an existing item with `key`, then the result
        /// `Entry` pointer points to it, and found_existing is true.
        /// Otherwise, puts a new item with undefined value, and
        /// the `Entry` pointer points to it. Caller should then initialize
        /// the value (but not the key).
        pub fn getOrPut(self: *Self, key: K) !GetOrPutResult {
            return self.unmanaged.getOrPutContext(self.allocator, key, self.ctx);
        }
        pub fn getOrPutAdapted(self: *Self, key: anytype, ctx: anytype) !GetOrPutResult {
            return self.unmanaged.getOrPutContextAdapted(key, ctx, self.ctx);
        }

        /// If there is an existing item with `key`, then the result
        /// `Entry` pointer points to it, and found_existing is true.
        /// Otherwise, puts a new item with undefined value, and
        /// the `Entry` pointer points to it. Caller should then initialize
        /// the value (but not the key).
        /// If a new entry needs to be stored, this function asserts there
        /// is enough capacity to store it.
        pub fn getOrPutAssumeCapacity(self: *Self, key: K) GetOrPutResult {
            return self.unmanaged.getOrPutAssumeCapacityContext(key, self.ctx);
        }
        pub fn getOrPutAssumeCapacityAdapted(self: *Self, key: anytype, ctx: anytype) GetOrPutResult {
            return self.unmanaged.getOrPutAssumeCapacityAdapted(key, ctx);
        }
        pub fn getOrPutValue(self: *Self, key: K, value: V) !GetOrPutResult {
            return self.unmanaged.getOrPutValueContext(self.allocator, key, value, self.ctx);
        }

        /// Deprecated: call `ensureUnusedCapacity` or `ensureTotalCapacity`.
        pub const ensureCapacity = ensureTotalCapacity;

        /// Increases capacity, guaranteeing that insertions up until the
        /// `expected_count` will not cause an allocation, and therefore cannot fail.
        pub fn ensureTotalCapacity(self: *Self, new_capacity: usize) !void {
            return self.unmanaged.ensureTotalCapacityContext(self.allocator, new_capacity, self.ctx);
        }

        /// Increases capacity, guaranteeing that insertions up until
        /// `additional_count` **more** items will not cause an allocation, and
        /// therefore cannot fail.
        pub fn ensureUnusedCapacity(self: *Self, additional_count: usize) !void {
            return self.unmanaged.ensureUnusedCapacityContext(self.allocator, additional_count, self.ctx);
        }

        /// Returns the number of total elements which may be present before it is
        /// no longer guaranteed that no allocations will be performed.
        pub fn capacity(self: *Self) usize {
            return self.unmanaged.capacity();
        }

        /// Clobbers any existing data. To detect if a put would clobber
        /// existing data, see `getOrPut`.
        pub fn put(self: *Self, key: K, value: V) !void {
            return self.unmanaged.putContext(self.allocator, key, value, self.ctx);
        }

        /// Inserts a key-value pair into the hash map, asserting that no previous
        /// entry with the same key is already present
        pub fn putNoClobber(self: *Self, key: K, value: V) !void {
            return self.unmanaged.putNoClobberContext(self.allocator, key, value, self.ctx);
        }

        /// Asserts there is enough capacity to store the new key-value pair.
        /// Clobbers any existing data. To detect if a put would clobber
        /// existing data, see `getOrPutAssumeCapacity`.
        pub fn putAssumeCapacity(self: *Self, key: K, value: V) void {
            return self.unmanaged.putAssumeCapacityContext(key, value, self.ctx);
        }

        /// Asserts there is enough capacity to store the new key-value pair.
        /// Asserts that it does not clobber any existing data.
        /// To detect if a put would clobber existing data, see `getOrPutAssumeCapacity`.
        pub fn putAssumeCapacityNoClobber(self: *Self, key: K, value: V) void {
            return self.unmanaged.putAssumeCapacityNoClobberContext(key, value, self.ctx);
        }

        /// Inserts a new `Entry` into the hash map, returning the previous one, if any.
        pub fn fetchPut(self: *Self, key: K, value: V) !?KV {
            return self.unmanaged.fetchPutContext(self.allocator, key, value, self.ctx);
        }

        /// Inserts a new `Entry` into the hash map, returning the previous one, if any.
        /// If insertion happuns, asserts there is enough capacity without allocating.
        pub fn fetchPutAssumeCapacity(self: *Self, key: K, value: V) ?KV {
            return self.unmanaged.fetchPutAssumeCapacityContext(key, value, self.ctx);
        }

        /// Finds pointers to the key and value storage associated with a key.
        pub fn getEntry(self: Self, key: K) ?Entry {
            return self.unmanaged.getEntryContext(key, self.ctx);
        }
        pub fn getEntryAdapted(self: Self, key: anytype, ctx: anytype) ?Entry {
            return self.unmanaged.getEntryAdapted(key, ctx);
        }

        /// Finds the index in the `entries` array where a key is stored
        pub fn getIndex(self: Self, key: K) ?usize {
            return self.unmanaged.getIndexContext(key, self.ctx);
        }
        pub fn getIndexAdapted(self: Self, key: anytype, ctx: anytype) ?usize {
            return self.unmanaged.getIndexAdapted(key, ctx);
        }

        /// Find the value associated with a key
        pub fn get(self: Self, key: K) ?V {
            return self.unmanaged.getContext(key, self.ctx);
        }
        pub fn getAdapted(self: Self, key: anytype, ctx: anytype) ?V {
            return self.unmanaged.getAdapted(key, ctx);
        }

        /// Find a pointer to the value associated with a key
        pub fn getPtr(self: Self, key: K) ?*V {
            return self.unmanaged.getPtrContext(key, self.ctx);
        }
        pub fn getPtrAdapted(self: Self, key: anytype, ctx: anytype) ?*V {
            return self.unmanaged.getPtrAdapted(key, ctx);
        }

        /// Check whether a key is stored in the map
        pub fn contains(self: Self, key: K) bool {
            return self.unmanaged.containsContext(key, self.ctx);
        }
        pub fn containsAdapted(self: Self, key: anytype, ctx: anytype) bool {
            return self.unmanaged.containsAdapted(key, ctx);
        }

        /// If there is an `Entry` with a matching key, it is deleted from
        /// the hash map, and then returned from this function. The entry is
        /// removed from the underlying array by swapping it with the last
        /// element.
        pub fn fetchSwapRemove(self: *Self, key: K) ?KV {
            return self.unmanaged.fetchSwapRemoveContext(key, self.ctx);
        }
        pub fn fetchSwapRemoveAdapted(self: *Self, key: anytype, ctx: anytype) ?KV {
            return self.unmanaged.fetchSwapRemoveContextAdapted(key, ctx, self.ctx);
        }

        /// If there is an `Entry` with a matching key, it is deleted from
        /// the hash map, and then returned from this function. The entry is
        /// removed from the underlying array by shifting all elements forward
        /// thereby maintaining the current ordering.
        pub fn fetchOrderedRemove(self: *Self, key: K) ?KV {
            return self.unmanaged.fetchOrderedRemoveContext(key, self.ctx);
        }
        pub fn fetchOrderedRemoveAdapted(self: *Self, key: anytype, ctx: anytype) ?KV {
            return self.unmanaged.fetchOrderedRemoveContextAdapted(key, ctx, self.ctx);
        }

        /// If there is an `Entry` with a matching key, it is deleted from
        /// the hash map. The entry is removed from the underlying array
        /// by swapping it with the last element.  Returns true if an entry
        /// was removed, false otherwise.
        pub fn swapRemove(self: *Self, key: K) bool {
            return self.unmanaged.swapRemoveContext(key, self.ctx);
        }
        pub fn swapRemoveAdapted(self: *Self, key: anytype, ctx: anytype) bool {
            return self.unmanaged.swapRemoveContextAdapted(key, ctx, self.ctx);
        }

        /// If there is an `Entry` with a matching key, it is deleted from
        /// the hash map. The entry is removed from the underlying array
        /// by shifting all elements forward, thereby maintaining the
        /// current ordering.  Returns true if an entry was removed, false otherwise.
        pub fn orderedRemove(self: *Self, key: K) bool {
            return self.unmanaged.orderedRemoveContext(key, self.ctx);
        }
        pub fn orderedRemoveAdapted(self: *Self, key: anytype, ctx: anytype) bool {
            return self.unmanaged.orderedRemoveContextAdapted(key, ctx, self.ctx);
        }

        /// Deletes the item at the specified index in `entries` from
        /// the hash map. The entry is removed from the underlying array
        /// by swapping it with the last element.
        pub fn swapRemoveAt(self: *Self, index: usize) void {
            self.unmanaged.swapRemoveAtContext(index, self.ctx);
        }

        /// Deletes the item at the specified index in `entries` from
        /// the hash map. The entry is removed from the underlying array
        /// by shifting all elements forward, thereby maintaining the
        /// current ordering.
        pub fn orderedRemoveAt(self: *Self, index: usize) void {
            self.unmanaged.orderedRemoveAtContext(index, self.ctx);
        }

        /// Create a copy of the hash map which can be modified separately.
        /// The copy uses the same context and allocator as this instance.
        pub fn clone(self: Self) !Self {
            var other = try self.unmanaged.cloneContext(self.allocator, self.ctx);
            return other.promoteContext(self.allocator, self.ctx);
        }
        /// Create a copy of the hash map which can be modified separately.
        /// The copy uses the same context as this instance, but the specified
        /// allocator.
        pub fn cloneWithAllocator(self: Self, allocator: *Allocator) !Self {
            var other = try self.unmanaged.cloneContext(allocator, self.ctx);
            return other.promoteContext(allocator, self.ctx);
        }
        /// Create a copy of the hash map which can be modified separately.
        /// The copy uses the same allocator as this instance, but the
        /// specified context.
        pub fn cloneWithContext(self: Self, ctx: anytype) !ArrayHashMap(K, V, @TypeOf(ctx), store_hash) {
            var other = try self.unmanaged.cloneContext(self.allocator, ctx);
            return other.promoteContext(self.allocator, ctx);
        }
        /// Create a copy of the hash map which can be modified separately.
        /// The copy uses the specified allocator and context.
        pub fn cloneWithAllocatorAndContext(self: Self, allocator: *Allocator, ctx: anytype) !ArrayHashMap(K, V, @TypeOf(ctx), store_hash) {
            var other = try self.unmanaged.cloneContext(allocator, ctx);
            return other.promoteContext(allocator, ctx);
        }

        /// Rebuilds the key indexes. If the underlying entries has been modified directly, users
        /// can call `reIndex` to update the indexes to account for these new entries.
        pub fn reIndex(self: *Self) !void {
            return self.unmanaged.reIndexContext(self.allocator, self.ctx);
        }

        /// Shrinks the underlying `Entry` array to `new_len` elements and discards any associated
        /// index entries. Keeps capacity the same.
        pub fn shrinkRetainingCapacity(self: *Self, new_len: usize) void {
            return self.unmanaged.shrinkRetainingCapacityContext(new_len, self.ctx);
        }

        /// Shrinks the underlying `Entry` array to `new_len` elements and discards any associated
        /// index entries. Reduces allocated capacity.
        pub fn shrinkAndFree(self: *Self, new_len: usize) void {
            return self.unmanaged.shrinkAndFreeContext(self.allocator, new_len, self.ctx);
        }

        /// Removes the last inserted `Entry` in the hash map and returns it.
        pub fn pop(self: *Self) KV {
            return self.unmanaged.popContext(self.ctx);
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
/// Context must be a struct type with two member functions:
///   hash(self, K) u32
///   eql(self, K, K) bool
/// Adapted variants of many functions are provided.  These variants
/// take a pseudo key instead of a key.  Their context must have the functions:
///   hash(self, PseudoKey) u32
///   eql(self, PseudoKey, K) bool
pub fn ArrayHashMapUnmanaged(
    comptime K: type,
    comptime V: type,
    comptime Context: type,
    comptime store_hash: bool,
) type {
    comptime std.hash_map.verifyContext(Context, K, K, u32);
    return struct {
        /// It is permitted to access this field directly.
        entries: DataList = .{},

        /// When entries length is less than `linear_scan_max`, this remains `null`.
        /// Once entries length grows big enough, this field is allocated. There is
        /// an IndexHeader followed by an array of Index(I) structs, where I is defined
        /// by how many total indexes there are.
        index_header: ?*IndexHeader = null,

        /// Modifying the key is allowed only if it does not change the hash.
        /// Modifying the value is allowed.
        /// Entry pointers become invalid whenever this ArrayHashMap is modified,
        /// unless `ensureCapacity` was previously used.
        pub const Entry = struct {
            key_ptr: *K,
            value_ptr: *V,
        };

        /// A KV pair which has been copied out of the backing store
        pub const KV = struct {
            key: K,
            value: V,
        };

        /// The Data type used for the MultiArrayList backing this map
        pub const Data = struct {
            hash: Hash,
            key: K,
            value: V,
        };

        /// The MultiArrayList type backing this map
        pub const DataList = std.MultiArrayList(Data);

        /// The stored hash type, either u32 or void.
        pub const Hash = if (store_hash) u32 else void;

        /// getOrPut variants return this structure, with pointers
        /// to the backing store and a flag to indicate whether an
        /// existing entry was found.
        /// Modifying the key is allowed only if it does not change the hash.
        /// Modifying the value is allowed.
        /// Entry pointers become invalid whenever this ArrayHashMap is modified,
        /// unless `ensureCapacity` was previously used.
        pub const GetOrPutResult = struct {
            key_ptr: *K,
            value_ptr: *V,
            found_existing: bool,
            index: usize,
        };

        /// The ArrayHashMap type using the same settings as this managed map.
        pub const Managed = ArrayHashMap(K, V, Context, store_hash);

        /// Some functions require a context only if hashes are not stored.
        /// To keep the api simple, this type is only used internally.
        const ByIndexContext = if (store_hash) void else Context;

        const Self = @This();

        const linear_scan_max = 8;

        const RemovalType = enum {
            swap,
            ordered,
        };

        /// Convert from an unmanaged map to a managed map.  After calling this,
        /// the promoted map should no longer be used.
        pub fn promote(self: Self, allocator: *Allocator) Managed {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call promoteContext instead.");
            return self.promoteContext(allocator, undefined);
        }
        pub fn promoteContext(self: Self, allocator: *Allocator, ctx: Context) Managed {
            return .{
                .unmanaged = self,
                .allocator = allocator,
                .ctx = ctx,
            };
        }

        /// Frees the backing allocation and leaves the map in an undefined state.
        /// Note that this does not free keys or values.  You must take care of that
        /// before calling this function, if it is needed.
        pub fn deinit(self: *Self, allocator: *Allocator) void {
            self.entries.deinit(allocator);
            if (self.index_header) |header| {
                header.free(allocator);
            }
            self.* = undefined;
        }

        /// Clears the map but retains the backing allocation for future use.
        pub fn clearRetainingCapacity(self: *Self) void {
            self.entries.len = 0;
            if (self.index_header) |header| {
                switch (header.capacityIndexType()) {
                    .u8 => mem.set(Index(u8), header.indexes(u8), Index(u8).empty),
                    .u16 => mem.set(Index(u16), header.indexes(u16), Index(u16).empty),
                    .u32 => mem.set(Index(u32), header.indexes(u32), Index(u32).empty),
                }
            }
        }

        /// Clears the map and releases the backing allocation
        pub fn clearAndFree(self: *Self, allocator: *Allocator) void {
            self.entries.shrinkAndFree(allocator, 0);
            if (self.index_header) |header| {
                header.free(allocator);
                self.index_header = null;
            }
        }

        /// Returns the number of KV pairs stored in this map.
        pub fn count(self: Self) usize {
            return self.entries.len;
        }

        /// Returns the backing array of keys in this map.
        /// Modifying the map may invalidate this array.
        pub fn keys(self: Self) []K {
            return self.entries.items(.key);
        }
        /// Returns the backing array of values in this map.
        /// Modifying the map may invalidate this array.
        pub fn values(self: Self) []V {
            return self.entries.items(.value);
        }

        /// Returns an iterator over the pairs in this map.
        /// Modifying the map may invalidate this iterator.
        pub fn iterator(self: Self) Iterator {
            const slice = self.entries.slice();
            return .{
                .keys = slice.items(.key).ptr,
                .values = slice.items(.value).ptr,
                .len = @intCast(u32, slice.len),
            };
        }
        pub const Iterator = struct {
            keys: [*]K,
            values: [*]V,
            len: u32,
            index: u32 = 0,

            pub fn next(it: *Iterator) ?Entry {
                if (it.index >= it.len) return null;
                const result = Entry{
                    .key_ptr = &it.keys[it.index],
                    // workaround for #6974
                    .value_ptr = if (@sizeOf(*V) == 0) undefined else &it.values[it.index],
                };
                it.index += 1;
                return result;
            }

            /// Reset the iterator to the initial index
            pub fn reset(it: *Iterator) void {
                it.index = 0;
            }
        };

        /// If key exists this function cannot fail.
        /// If there is an existing item with `key`, then the result
        /// `Entry` pointer points to it, and found_existing is true.
        /// Otherwise, puts a new item with undefined value, and
        /// the `Entry` pointer points to it. Caller should then initialize
        /// the value (but not the key).
        pub fn getOrPut(self: *Self, allocator: *Allocator, key: K) !GetOrPutResult {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getOrPutContext instead.");
            return self.getOrPutContext(allocator, key, undefined);
        }
        pub fn getOrPutContext(self: *Self, allocator: *Allocator, key: K, ctx: Context) !GetOrPutResult {
            const gop = try self.getOrPutContextAdapted(allocator, key, ctx, ctx);
            if (!gop.found_existing) {
                gop.key_ptr.* = key;
            }
            return gop;
        }
        pub fn getOrPutAdapted(self: *Self, allocator: *Allocator, key: anytype, key_ctx: anytype) !GetOrPutResult {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getOrPutContextAdapted instead.");
            return self.getOrPutContextAdapted(allocator, key, key_ctx, undefined);
        }
        pub fn getOrPutContextAdapted(self: *Self, allocator: *Allocator, key: anytype, key_ctx: anytype, ctx: Context) !GetOrPutResult {
            self.ensureTotalCapacityContext(allocator, self.entries.len + 1, ctx) catch |err| {
                // "If key exists this function cannot fail."
                const index = self.getIndexAdapted(key, key_ctx) orelse return err;
                const slice = self.entries.slice();
                return GetOrPutResult{
                    .key_ptr = &slice.items(.key)[index],
                    // workaround for #6974
                    .value_ptr = if (@sizeOf(*V) == 0) undefined else &slice.items(.value)[index],
                    .found_existing = true,
                    .index = index,
                };
            };
            return self.getOrPutAssumeCapacityAdapted(key, key_ctx);
        }

        /// If there is an existing item with `key`, then the result
        /// `Entry` pointer points to it, and found_existing is true.
        /// Otherwise, puts a new item with undefined value, and
        /// the `Entry` pointer points to it. Caller should then initialize
        /// the value (but not the key).
        /// If a new entry needs to be stored, this function asserts there
        /// is enough capacity to store it.
        pub fn getOrPutAssumeCapacity(self: *Self, key: K) GetOrPutResult {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getOrPutAssumeCapacityContext instead.");
            return self.getOrPutAssumeCapacityContext(key, undefined);
        }
        pub fn getOrPutAssumeCapacityContext(self: *Self, key: K, ctx: Context) GetOrPutResult {
            const gop = self.getOrPutAssumeCapacityAdapted(key, ctx);
            if (!gop.found_existing) {
                gop.key_ptr.* = key;
            }
            return gop;
        }
        /// If there is an existing item with `key`, then the result
        /// `Entry` pointers point to it, and found_existing is true.
        /// Otherwise, puts a new item with undefined key and value, and
        /// the `Entry` pointers point to it. Caller must then initialize
        /// both the key and the value.
        /// If a new entry needs to be stored, this function asserts there
        /// is enough capacity to store it.
        pub fn getOrPutAssumeCapacityAdapted(self: *Self, key: anytype, ctx: anytype) GetOrPutResult {
            const header = self.index_header orelse {
                // Linear scan.
                const h = if (store_hash) checkedHash(ctx, key) else {};
                const slice = self.entries.slice();
                const hashes_array = slice.items(.hash);
                const keys_array = slice.items(.key);
                for (keys_array) |*item_key, i| {
                    if (hashes_array[i] == h and checkedEql(ctx, key, item_key.*)) {
                        return GetOrPutResult{
                            .key_ptr = item_key,
                            // workaround for #6974
                            .value_ptr = if (@sizeOf(*V) == 0) undefined else &slice.items(.value)[i],
                            .found_existing = true,
                            .index = i,
                        };
                    }
                }

                const index = self.entries.addOneAssumeCapacity();
                // unsafe indexing because the length changed
                if (store_hash) hashes_array.ptr[index] = h;

                return GetOrPutResult{
                    .key_ptr = &keys_array.ptr[index],
                    // workaround for #6974
                    .value_ptr = if (@sizeOf(*V) == 0) undefined else &slice.items(.value).ptr[index],
                    .found_existing = false,
                    .index = index,
                };
            };

            switch (header.capacityIndexType()) {
                .u8 => return self.getOrPutInternal(key, ctx, header, u8),
                .u16 => return self.getOrPutInternal(key, ctx, header, u16),
                .u32 => return self.getOrPutInternal(key, ctx, header, u32),
            }
        }

        pub fn getOrPutValue(self: *Self, allocator: *Allocator, key: K, value: V) !GetOrPutResult {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getOrPutValueContext instead.");
            return self.getOrPutValueContext(allocator, key, value, undefined);
        }
        pub fn getOrPutValueContext(self: *Self, allocator: *Allocator, key: K, value: V, ctx: Context) !GetOrPutResult {
            const res = try self.getOrPutContextAdapted(allocator, key, ctx, ctx);
            if (!res.found_existing) {
                res.key_ptr.* = key;
                res.value_ptr.* = value;
            }
            return res;
        }

        /// Deprecated: call `ensureUnusedCapacity` or `ensureTotalCapacity`.
        pub const ensureCapacity = ensureTotalCapacity;

        /// Increases capacity, guaranteeing that insertions up until the
        /// `expected_count` will not cause an allocation, and therefore cannot fail.
        pub fn ensureTotalCapacity(self: *Self, allocator: *Allocator, new_capacity: usize) !void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call ensureTotalCapacityContext instead.");
            return self.ensureTotalCapacityContext(allocator, new_capacity, undefined);
        }
        pub fn ensureTotalCapacityContext(self: *Self, allocator: *Allocator, new_capacity: usize, ctx: Context) !void {
            if (new_capacity <= linear_scan_max) {
                try self.entries.ensureCapacity(allocator, new_capacity);
                return;
            }

            if (self.index_header) |header| {
                if (new_capacity <= header.capacity()) {
                    try self.entries.ensureCapacity(allocator, new_capacity);
                    return;
                }
            }

            const new_bit_index = try IndexHeader.findBitIndex(new_capacity);
            const new_header = try IndexHeader.alloc(allocator, new_bit_index);
            try self.entries.ensureCapacity(allocator, new_capacity);

            if (self.index_header) |old_header| old_header.free(allocator);
            self.insertAllEntriesIntoNewHeader(if (store_hash) {} else ctx, new_header);
            self.index_header = new_header;
        }

        /// Increases capacity, guaranteeing that insertions up until
        /// `additional_count` **more** items will not cause an allocation, and
        /// therefore cannot fail.
        pub fn ensureUnusedCapacity(
            self: *Self,
            allocator: *Allocator,
            additional_capacity: usize,
        ) !void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call ensureTotalCapacityContext instead.");
            return self.ensureUnusedCapacityContext(allocator, additional_capacity, undefined);
        }
        pub fn ensureUnusedCapacityContext(
            self: *Self,
            allocator: *Allocator,
            additional_capacity: usize,
            ctx: Context,
        ) !void {
            return self.ensureTotalCapacityContext(allocator, self.count() + additional_capacity, ctx);
        }

        /// Returns the number of total elements which may be present before it is
        /// no longer guaranteed that no allocations will be performed.
        pub fn capacity(self: Self) usize {
            const entry_cap = self.entries.capacity;
            const header = self.index_header orelse return math.min(linear_scan_max, entry_cap);
            const indexes_cap = header.capacity();
            return math.min(entry_cap, indexes_cap);
        }

        /// Clobbers any existing data. To detect if a put would clobber
        /// existing data, see `getOrPut`.
        pub fn put(self: *Self, allocator: *Allocator, key: K, value: V) !void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call putContext instead.");
            return self.putContext(allocator, key, value, undefined);
        }
        pub fn putContext(self: *Self, allocator: *Allocator, key: K, value: V, ctx: Context) !void {
            const result = try self.getOrPutContext(allocator, key, ctx);
            result.value_ptr.* = value;
        }

        /// Inserts a key-value pair into the hash map, asserting that no previous
        /// entry with the same key is already present
        pub fn putNoClobber(self: *Self, allocator: *Allocator, key: K, value: V) !void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call putNoClobberContext instead.");
            return self.putNoClobberContext(allocator, key, value, undefined);
        }
        pub fn putNoClobberContext(self: *Self, allocator: *Allocator, key: K, value: V, ctx: Context) !void {
            const result = try self.getOrPutContext(allocator, key, ctx);
            assert(!result.found_existing);
            result.value_ptr.* = value;
        }

        /// Asserts there is enough capacity to store the new key-value pair.
        /// Clobbers any existing data. To detect if a put would clobber
        /// existing data, see `getOrPutAssumeCapacity`.
        pub fn putAssumeCapacity(self: *Self, key: K, value: V) void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call putAssumeCapacityContext instead.");
            return self.putAssumeCapacityContext(key, value, undefined);
        }
        pub fn putAssumeCapacityContext(self: *Self, key: K, value: V, ctx: Context) void {
            const result = self.getOrPutAssumeCapacityContext(key, ctx);
            result.value_ptr.* = value;
        }

        /// Asserts there is enough capacity to store the new key-value pair.
        /// Asserts that it does not clobber any existing data.
        /// To detect if a put would clobber existing data, see `getOrPutAssumeCapacity`.
        pub fn putAssumeCapacityNoClobber(self: *Self, key: K, value: V) void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call putAssumeCapacityNoClobberContext instead.");
            return self.putAssumeCapacityNoClobberContext(key, value, undefined);
        }
        pub fn putAssumeCapacityNoClobberContext(self: *Self, key: K, value: V, ctx: Context) void {
            const result = self.getOrPutAssumeCapacityContext(key, ctx);
            assert(!result.found_existing);
            result.value_ptr.* = value;
        }

        /// Inserts a new `Entry` into the hash map, returning the previous one, if any.
        pub fn fetchPut(self: *Self, allocator: *Allocator, key: K, value: V) !?KV {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call fetchPutContext instead.");
            return self.fetchPutContext(allocator, key, value, undefined);
        }
        pub fn fetchPutContext(self: *Self, allocator: *Allocator, key: K, value: V, ctx: Context) !?KV {
            const gop = try self.getOrPutContext(allocator, key, ctx);
            var result: ?KV = null;
            if (gop.found_existing) {
                result = KV{
                    .key = gop.key_ptr.*,
                    .value = gop.value_ptr.*,
                };
            }
            gop.value_ptr.* = value;
            return result;
        }

        /// Inserts a new `Entry` into the hash map, returning the previous one, if any.
        /// If insertion happens, asserts there is enough capacity without allocating.
        pub fn fetchPutAssumeCapacity(self: *Self, key: K, value: V) ?KV {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call fetchPutAssumeCapacityContext instead.");
            return self.fetchPutAssumeCapacityContext(key, value, undefined);
        }
        pub fn fetchPutAssumeCapacityContext(self: *Self, key: K, value: V, ctx: Context) ?KV {
            const gop = self.getOrPutAssumeCapacityContext(key, ctx);
            var result: ?KV = null;
            if (gop.found_existing) {
                result = KV{
                    .key = gop.key_ptr.*,
                    .value = gop.value_ptr.*,
                };
            }
            gop.value_ptr.* = value;
            return result;
        }

        /// Finds pointers to the key and value storage associated with a key.
        pub fn getEntry(self: Self, key: K) ?Entry {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getEntryContext instead.");
            return self.getEntryContext(key, undefined);
        }
        pub fn getEntryContext(self: Self, key: K, ctx: Context) ?Entry {
            return self.getEntryAdapted(key, ctx);
        }
        pub fn getEntryAdapted(self: Self, key: anytype, ctx: anytype) ?Entry {
            const index = self.getIndexAdapted(key, ctx) orelse return null;
            const slice = self.entries.slice();
            return Entry{
                .key_ptr = &slice.items(.key)[index],
                // workaround for #6974
                .value_ptr = if (@sizeOf(*V) == 0) undefined else &slice.items(.value)[index],
            };
        }

        /// Finds the index in the `entries` array where a key is stored
        pub fn getIndex(self: Self, key: K) ?usize {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getIndexContext instead.");
            return self.getIndexContext(key, undefined);
        }
        pub fn getIndexContext(self: Self, key: K, ctx: Context) ?usize {
            return self.getIndexAdapted(key, ctx);
        }
        pub fn getIndexAdapted(self: Self, key: anytype, ctx: anytype) ?usize {
            const header = self.index_header orelse {
                // Linear scan.
                const h = if (store_hash) checkedHash(ctx, key) else {};
                const slice = self.entries.slice();
                const hashes_array = slice.items(.hash);
                const keys_array = slice.items(.key);
                for (keys_array) |*item_key, i| {
                    if (hashes_array[i] == h and checkedEql(ctx, key, item_key.*)) {
                        return i;
                    }
                }
                return null;
            };
            switch (header.capacityIndexType()) {
                .u8 => return self.getIndexWithHeaderGeneric(key, ctx, header, u8),
                .u16 => return self.getIndexWithHeaderGeneric(key, ctx, header, u16),
                .u32 => return self.getIndexWithHeaderGeneric(key, ctx, header, u32),
            }
        }
        fn getIndexWithHeaderGeneric(self: Self, key: anytype, ctx: anytype, header: *IndexHeader, comptime I: type) ?usize {
            const indexes = header.indexes(I);
            const slot = self.getSlotByKey(key, ctx, header, I, indexes) orelse return null;
            return indexes[slot].entry_index;
        }

        /// Find the value associated with a key
        pub fn get(self: Self, key: K) ?V {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getContext instead.");
            return self.getContext(key, undefined);
        }
        pub fn getContext(self: Self, key: K, ctx: Context) ?V {
            return self.getAdapted(key, ctx);
        }
        pub fn getAdapted(self: Self, key: anytype, ctx: anytype) ?V {
            const index = self.getIndexAdapted(key, ctx) orelse return null;
            return self.values()[index];
        }

        /// Find a pointer to the value associated with a key
        pub fn getPtr(self: Self, key: K) ?*V {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getPtrContext instead.");
            return self.getPtrContext(key, undefined);
        }
        pub fn getPtrContext(self: Self, key: K, ctx: Context) ?*V {
            return self.getPtrAdapted(key, ctx);
        }
        pub fn getPtrAdapted(self: Self, key: anytype, ctx: anytype) ?*V {
            const index = self.getIndexAdapted(key, ctx) orelse return null;
            // workaround for #6974
            return if (@sizeOf(*V) == 0) @as(*V, undefined) else &self.values()[index];
        }

        /// Check whether a key is stored in the map
        pub fn contains(self: Self, key: K) bool {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call containsContext instead.");
            return self.containsContext(key, undefined);
        }
        pub fn containsContext(self: Self, key: K, ctx: Context) bool {
            return self.containsAdapted(key, ctx);
        }
        pub fn containsAdapted(self: Self, key: anytype, ctx: anytype) bool {
            return self.getIndexAdapted(key, ctx) != null;
        }

        /// If there is an `Entry` with a matching key, it is deleted from
        /// the hash map, and then returned from this function. The entry is
        /// removed from the underlying array by swapping it with the last
        /// element.
        pub fn fetchSwapRemove(self: *Self, key: K) ?KV {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call fetchSwapRemoveContext instead.");
            return self.fetchSwapRemoveContext(key, undefined);
        }
        pub fn fetchSwapRemoveContext(self: *Self, key: K, ctx: Context) ?KV {
            return self.fetchSwapRemoveContextAdapted(key, ctx, ctx);
        }
        pub fn fetchSwapRemoveAdapted(self: *Self, key: anytype, ctx: anytype) ?KV {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call fetchSwapRemoveContextAdapted instead.");
            return self.fetchSwapRemoveContextAdapted(key, ctx, undefined);
        }
        pub fn fetchSwapRemoveContextAdapted(self: *Self, key: anytype, key_ctx: anytype, ctx: Context) ?KV {
            return self.fetchRemoveByKey(key, key_ctx, if (store_hash) {} else ctx, .swap);
        }

        /// If there is an `Entry` with a matching key, it is deleted from
        /// the hash map, and then returned from this function. The entry is
        /// removed from the underlying array by shifting all elements forward
        /// thereby maintaining the current ordering.
        pub fn fetchOrderedRemove(self: *Self, key: K) ?KV {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call fetchOrderedRemoveContext instead.");
            return self.fetchOrderedRemoveContext(key, undefined);
        }
        pub fn fetchOrderedRemoveContext(self: *Self, key: K, ctx: Context) ?KV {
            return self.fetchOrderedRemoveContextAdapted(key, ctx, ctx);
        }
        pub fn fetchOrderedRemoveAdapted(self: *Self, key: anytype, ctx: anytype) ?KV {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call fetchOrderedRemoveContextAdapted instead.");
            return self.fetchOrderedRemoveContextAdapted(key, ctx, undefined);
        }
        pub fn fetchOrderedRemoveContextAdapted(self: *Self, key: anytype, key_ctx: anytype, ctx: Context) ?KV {
            return self.fetchRemoveByKey(key, key_ctx, if (store_hash) {} else ctx, .ordered);
        }

        /// If there is an `Entry` with a matching key, it is deleted from
        /// the hash map. The entry is removed from the underlying array
        /// by swapping it with the last element.  Returns true if an entry
        /// was removed, false otherwise.
        pub fn swapRemove(self: *Self, key: K) bool {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call swapRemoveContext instead.");
            return self.swapRemoveContext(key, undefined);
        }
        pub fn swapRemoveContext(self: *Self, key: K, ctx: Context) bool {
            return self.swapRemoveContextAdapted(key, ctx, ctx);
        }
        pub fn swapRemoveAdapted(self: *Self, key: anytype, ctx: anytype) bool {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call swapRemoveContextAdapted instead.");
            return self.swapRemoveContextAdapted(key, ctx, undefined);
        }
        pub fn swapRemoveContextAdapted(self: *Self, key: anytype, key_ctx: anytype, ctx: Context) bool {
            return self.removeByKey(key, key_ctx, if (store_hash) {} else ctx, .swap);
        }

        /// If there is an `Entry` with a matching key, it is deleted from
        /// the hash map. The entry is removed from the underlying array
        /// by shifting all elements forward, thereby maintaining the
        /// current ordering.  Returns true if an entry was removed, false otherwise.
        pub fn orderedRemove(self: *Self, key: K) bool {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call orderedRemoveContext instead.");
            return self.orderedRemoveContext(key, undefined);
        }
        pub fn orderedRemoveContext(self: *Self, key: K, ctx: Context) bool {
            return self.orderedRemoveContextAdapted(key, ctx, ctx);
        }
        pub fn orderedRemoveAdapted(self: *Self, key: anytype, ctx: anytype) bool {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call orderedRemoveContextAdapted instead.");
            return self.orderedRemoveContextAdapted(key, ctx, undefined);
        }
        pub fn orderedRemoveContextAdapted(self: *Self, key: anytype, key_ctx: anytype, ctx: Context) bool {
            return self.removeByKey(key, key_ctx, if (store_hash) {} else ctx, .ordered);
        }

        /// Deletes the item at the specified index in `entries` from
        /// the hash map. The entry is removed from the underlying array
        /// by swapping it with the last element.
        pub fn swapRemoveAt(self: *Self, index: usize) void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call swapRemoveAtContext instead.");
            return self.swapRemoveAtContext(index, undefined);
        }
        pub fn swapRemoveAtContext(self: *Self, index: usize, ctx: Context) void {
            self.removeByIndex(index, if (store_hash) {} else ctx, .swap);
        }

        /// Deletes the item at the specified index in `entries` from
        /// the hash map. The entry is removed from the underlying array
        /// by shifting all elements forward, thereby maintaining the
        /// current ordering.
        pub fn orderedRemoveAt(self: *Self, index: usize) void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call orderedRemoveAtContext instead.");
            return self.orderedRemoveAtContext(index, undefined);
        }
        pub fn orderedRemoveAtContext(self: *Self, index: usize, ctx: Context) void {
            self.removeByIndex(index, if (store_hash) {} else ctx, .ordered);
        }

        /// Create a copy of the hash map which can be modified separately.
        /// The copy uses the same context and allocator as this instance.
        pub fn clone(self: Self, allocator: *Allocator) !Self {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call cloneContext instead.");
            return self.cloneContext(allocator, undefined);
        }
        pub fn cloneContext(self: Self, allocator: *Allocator, ctx: Context) !Self {
            var other: Self = .{};
            other.entries = try self.entries.clone(allocator);
            errdefer other.entries.deinit(allocator);

            if (self.index_header) |header| {
                const new_header = try IndexHeader.alloc(allocator, header.bit_index);
                other.insertAllEntriesIntoNewHeader(if (store_hash) {} else ctx, new_header);
                other.index_header = new_header;
            }
            return other;
        }

        /// Rebuilds the key indexes. If the underlying entries has been modified directly, users
        /// can call `reIndex` to update the indexes to account for these new entries.
        pub fn reIndex(self: *Self, allocator: *Allocator) !void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call reIndexContext instead.");
            return self.reIndexContext(allocator, undefined);
        }
        pub fn reIndexContext(self: *Self, allocator: *Allocator, ctx: Context) !void {
            if (self.entries.capacity <= linear_scan_max) return;
            // We're going to rebuild the index header and replace the existing one (if any). The
            // indexes should sized such that they will be at most 60% full.
            const bit_index = try IndexHeader.findBitIndex(self.entries.capacity);
            const new_header = try IndexHeader.alloc(allocator, bit_index);
            if (self.index_header) |header| header.free(allocator);
            self.insertAllEntriesIntoNewHeader(if (store_hash) {} else ctx, new_header);
            self.index_header = new_header;
        }

        /// Shrinks the underlying `Entry` array to `new_len` elements and discards any associated
        /// index entries. Keeps capacity the same.
        pub fn shrinkRetainingCapacity(self: *Self, new_len: usize) void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call shrinkRetainingCapacityContext instead.");
            return self.shrinkRetainingCapacityContext(new_len, undefined);
        }
        pub fn shrinkRetainingCapacityContext(self: *Self, new_len: usize, ctx: Context) void {
            // Remove index entries from the new length onwards.
            // Explicitly choose to ONLY remove index entries and not the underlying array list
            // entries as we're going to remove them in the subsequent shrink call.
            if (self.index_header) |header| {
                var i: usize = new_len;
                while (i < self.entries.len) : (i += 1)
                    self.removeFromIndexByIndex(i, if (store_hash) {} else ctx, header);
            }
            self.entries.shrinkRetainingCapacity(new_len);
        }

        /// Shrinks the underlying `Entry` array to `new_len` elements and discards any associated
        /// index entries. Reduces allocated capacity.
        pub fn shrinkAndFree(self: *Self, allocator: *Allocator, new_len: usize) void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call shrinkAndFreeContext instead.");
            return self.shrinkAndFreeContext(allocator, new_len, undefined);
        }
        pub fn shrinkAndFreeContext(self: *Self, allocator: *Allocator, new_len: usize, ctx: Context) void {
            // Remove index entries from the new length onwards.
            // Explicitly choose to ONLY remove index entries and not the underlying array list
            // entries as we're going to remove them in the subsequent shrink call.
            if (self.index_header) |header| {
                var i: usize = new_len;
                while (i < self.entries.len) : (i += 1)
                    self.removeFromIndexByIndex(i, if (store_hash) {} else ctx, header);
            }
            self.entries.shrinkAndFree(allocator, new_len);
        }

        /// Removes the last inserted `Entry` in the hash map and returns it.
        pub fn pop(self: *Self) KV {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call popContext instead.");
            return self.popContext(undefined);
        }
        pub fn popContext(self: *Self, ctx: Context) KV {
            const item = self.entries.get(self.entries.len - 1);
            if (self.index_header) |header|
                self.removeFromIndexByIndex(self.entries.len - 1, if (store_hash) {} else ctx, header);
            self.entries.len -= 1;
            return .{
                .key = item.key,
                .value = item.value,
            };
        }

        // ------------------ No pub fns below this point ------------------

        fn fetchRemoveByKey(self: *Self, key: anytype, key_ctx: anytype, ctx: ByIndexContext, comptime removal_type: RemovalType) ?KV {
            const header = self.index_header orelse {
                // Linear scan.
                const key_hash = if (store_hash) key_ctx.hash(key) else {};
                const slice = self.entries.slice();
                const hashes_array = if (store_hash) slice.items(.hash) else {};
                const keys_array = slice.items(.key);
                for (keys_array) |*item_key, i| {
                    const hash_match = if (store_hash) hashes_array[i] == key_hash else true;
                    if (hash_match and key_ctx.eql(key, item_key.*)) {
                        const removed_entry: KV = .{
                            .key = keys_array[i],
                            .value = slice.items(.value)[i],
                        };
                        switch (removal_type) {
                            .swap => self.entries.swapRemove(i),
                            .ordered => self.entries.orderedRemove(i),
                        }
                        return removed_entry;
                    }
                }
                return null;
            };
            return switch (header.capacityIndexType()) {
                .u8 => self.fetchRemoveByKeyGeneric(key, key_ctx, ctx, header, u8, removal_type),
                .u16 => self.fetchRemoveByKeyGeneric(key, key_ctx, ctx, header, u16, removal_type),
                .u32 => self.fetchRemoveByKeyGeneric(key, key_ctx, ctx, header, u32, removal_type),
            };
        }
        fn fetchRemoveByKeyGeneric(self: *Self, key: anytype, key_ctx: anytype, ctx: ByIndexContext, header: *IndexHeader, comptime I: type, comptime removal_type: RemovalType) ?KV {
            const indexes = header.indexes(I);
            const entry_index = self.removeFromIndexByKey(key, key_ctx, header, I, indexes) orelse return null;
            const slice = self.entries.slice();
            const removed_entry: KV = .{
                .key = slice.items(.key)[entry_index],
                .value = slice.items(.value)[entry_index],
            };
            self.removeFromArrayAndUpdateIndex(entry_index, ctx, header, I, indexes, removal_type);
            return removed_entry;
        }

        fn removeByKey(self: *Self, key: anytype, key_ctx: anytype, ctx: ByIndexContext, comptime removal_type: RemovalType) bool {
            const header = self.index_header orelse {
                // Linear scan.
                const key_hash = if (store_hash) key_ctx.hash(key) else {};
                const slice = self.entries.slice();
                const hashes_array = if (store_hash) slice.items(.hash) else {};
                const keys_array = slice.items(.key);
                for (keys_array) |*item_key, i| {
                    const hash_match = if (store_hash) hashes_array[i] == key_hash else true;
                    if (hash_match and key_ctx.eql(key, item_key.*)) {
                        switch (removal_type) {
                            .swap => self.entries.swapRemove(i),
                            .ordered => self.entries.orderedRemove(i),
                        }
                        return true;
                    }
                }
                return false;
            };
            return switch (header.capacityIndexType()) {
                .u8 => self.removeByKeyGeneric(key, key_ctx, ctx, header, u8, removal_type),
                .u16 => self.removeByKeyGeneric(key, key_ctx, ctx, header, u16, removal_type),
                .u32 => self.removeByKeyGeneric(key, key_ctx, ctx, header, u32, removal_type),
            };
        }
        fn removeByKeyGeneric(self: *Self, key: anytype, key_ctx: anytype, ctx: ByIndexContext, header: *IndexHeader, comptime I: type, comptime removal_type: RemovalType) bool {
            const indexes = header.indexes(I);
            const entry_index = self.removeFromIndexByKey(key, key_ctx, header, I, indexes) orelse return false;
            self.removeFromArrayAndUpdateIndex(entry_index, ctx, header, I, indexes, removal_type);
            return true;
        }

        fn removeByIndex(self: *Self, entry_index: usize, ctx: ByIndexContext, comptime removal_type: RemovalType) void {
            assert(entry_index < self.entries.len);
            const header = self.index_header orelse {
                switch (removal_type) {
                    .swap => self.entries.swapRemove(entry_index),
                    .ordered => self.entries.orderedRemove(entry_index),
                }
                return;
            };
            switch (header.capacityIndexType()) {
                .u8 => self.removeByIndexGeneric(entry_index, ctx, header, u8, removal_type),
                .u16 => self.removeByIndexGeneric(entry_index, ctx, header, u16, removal_type),
                .u32 => self.removeByIndexGeneric(entry_index, ctx, header, u32, removal_type),
            }
        }
        fn removeByIndexGeneric(self: *Self, entry_index: usize, ctx: ByIndexContext, header: *IndexHeader, comptime I: type, comptime removal_type: RemovalType) void {
            const indexes = header.indexes(I);
            self.removeFromIndexByIndexGeneric(entry_index, ctx, header, I, indexes);
            self.removeFromArrayAndUpdateIndex(entry_index, ctx, header, I, indexes, removal_type);
        }

        fn removeFromArrayAndUpdateIndex(self: *Self, entry_index: usize, ctx: ByIndexContext, header: *IndexHeader, comptime I: type, indexes: []Index(I), comptime removal_type: RemovalType) void {
            const last_index = self.entries.len - 1; // overflow => remove from empty map
            switch (removal_type) {
                .swap => {
                    if (last_index != entry_index) {
                        // Because of the swap remove, now we need to update the index that was
                        // pointing to the last entry and is now pointing to this removed item slot.
                        self.updateEntryIndex(header, last_index, entry_index, ctx, I, indexes);
                    }
                    // updateEntryIndex reads from the old entry index,
                    // so it needs to run before removal.
                    self.entries.swapRemove(entry_index);
                },
                .ordered => {
                    var i: usize = entry_index;
                    while (i < last_index) : (i += 1) {
                        // Because of the ordered remove, everything from the entry index onwards has
                        // been shifted forward so we'll need to update the index entries.
                        self.updateEntryIndex(header, i + 1, i, ctx, I, indexes);
                    }
                    // updateEntryIndex reads from the old entry index,
                    // so it needs to run before removal.
                    self.entries.orderedRemove(entry_index);
                },
            }
        }

        fn updateEntryIndex(
            self: *Self,
            header: *IndexHeader,
            old_entry_index: usize,
            new_entry_index: usize,
            ctx: ByIndexContext,
            comptime I: type,
            indexes: []Index(I),
        ) void {
            const slot = self.getSlotByIndex(old_entry_index, ctx, header, I, indexes);
            indexes[slot].entry_index = @intCast(I, new_entry_index);
        }

        fn removeFromIndexByIndex(self: *Self, entry_index: usize, ctx: ByIndexContext, header: *IndexHeader) void {
            switch (header.capacityIndexType()) {
                .u8 => self.removeFromIndexByIndexGeneric(entry_index, ctx, header, u8, header.indexes(u8)),
                .u16 => self.removeFromIndexByIndexGeneric(entry_index, ctx, header, u16, header.indexes(u16)),
                .u32 => self.removeFromIndexByIndexGeneric(entry_index, ctx, header, u32, header.indexes(u32)),
            }
        }
        fn removeFromIndexByIndexGeneric(self: *Self, entry_index: usize, ctx: ByIndexContext, header: *IndexHeader, comptime I: type, indexes: []Index(I)) void {
            const slot = self.getSlotByIndex(entry_index, ctx, header, I, indexes);
            self.removeSlot(slot, header, I, indexes);
        }

        fn removeFromIndexByKey(self: *Self, key: anytype, ctx: anytype, header: *IndexHeader, comptime I: type, indexes: []Index(I)) ?usize {
            const slot = self.getSlotByKey(key, ctx, header, I, indexes) orelse return null;
            const removed_entry_index = indexes[slot].entry_index;
            self.removeSlot(slot, header, I, indexes);
            return removed_entry_index;
        }

        fn removeSlot(self: *Self, removed_slot: usize, header: *IndexHeader, comptime I: type, indexes: []Index(I)) void {
            const start_index = removed_slot +% 1;
            const end_index = start_index +% indexes.len;

            var last_slot = removed_slot;
            var index: usize = start_index;
            while (index != end_index) : (index +%= 1) {
                const slot = header.constrainIndex(index);
                const slot_data = indexes[slot];
                if (slot_data.isEmpty() or slot_data.distance_from_start_index == 0) {
                    indexes[last_slot].setEmpty();
                    return;
                }
                indexes[last_slot] = .{
                    .entry_index = slot_data.entry_index,
                    .distance_from_start_index = slot_data.distance_from_start_index - 1,
                };
                last_slot = slot;
            }
            unreachable;
        }

        fn getSlotByIndex(self: *Self, entry_index: usize, ctx: ByIndexContext, header: *IndexHeader, comptime I: type, indexes: []Index(I)) usize {
            const slice = self.entries.slice();
            const h = if (store_hash) slice.items(.hash)[entry_index] else checkedHash(ctx, slice.items(.key)[entry_index]);
            const start_index = safeTruncate(usize, h);
            const end_index = start_index +% indexes.len;

            var index = start_index;
            var distance_from_start_index: I = 0;
            while (index != end_index) : ({
                index +%= 1;
                distance_from_start_index += 1;
            }) {
                const slot = header.constrainIndex(index);
                const slot_data = indexes[slot];

                // This is the fundamental property of the array hash map index.  If this
                // assert fails, it probably means that the entry was not in the index.
                assert(!slot_data.isEmpty());
                assert(slot_data.distance_from_start_index >= distance_from_start_index);

                if (slot_data.entry_index == entry_index) {
                    return slot;
                }
            }
            unreachable;
        }

        /// Must ensureCapacity before calling this.
        fn getOrPutInternal(self: *Self, key: anytype, ctx: anytype, header: *IndexHeader, comptime I: type) GetOrPutResult {
            const slice = self.entries.slice();
            const hashes_array = if (store_hash) slice.items(.hash) else {};
            const keys_array = slice.items(.key);
            const values_array = slice.items(.value);
            const indexes = header.indexes(I);

            const h = checkedHash(ctx, key);
            const start_index = safeTruncate(usize, h);
            const end_index = start_index +% indexes.len;

            var index = start_index;
            var distance_from_start_index: I = 0;
            while (index != end_index) : ({
                index +%= 1;
                distance_from_start_index += 1;
            }) {
                var slot = header.constrainIndex(index);
                var slot_data = indexes[slot];

                // If the slot is empty, there can be no more items in this run.
                // We didn't find a matching item, so this must be new.
                // Put it in the empty slot.
                if (slot_data.isEmpty()) {
                    const new_index = self.entries.addOneAssumeCapacity();
                    indexes[slot] = .{
                        .distance_from_start_index = distance_from_start_index,
                        .entry_index = @intCast(I, new_index),
                    };

                    // update the hash if applicable
                    if (store_hash) hashes_array.ptr[new_index] = h;

                    return .{
                        .found_existing = false,
                        .key_ptr = &keys_array.ptr[new_index],
                        // workaround for #6974
                        .value_ptr = if (@sizeOf(*V) == 0) undefined else &values_array.ptr[new_index],
                        .index = new_index,
                    };
                }

                // This pointer survives the following append because we call
                // entries.ensureCapacity before getOrPutInternal.
                const hash_match = if (store_hash) h == hashes_array[slot_data.entry_index] else true;
                if (hash_match and checkedEql(ctx, key, keys_array[slot_data.entry_index])) {
                    return .{
                        .found_existing = true,
                        .key_ptr = &keys_array[slot_data.entry_index],
                        // workaround for #6974
                        .value_ptr = if (@sizeOf(*V) == 0) undefined else &values_array[slot_data.entry_index],
                        .index = slot_data.entry_index,
                    };
                }

                // If the entry is closer to its target than our current distance,
                // the entry we are looking for does not exist.  It would be in
                // this slot instead if it was here.  So stop looking, and switch
                // to insert mode.
                if (slot_data.distance_from_start_index < distance_from_start_index) {
                    // In this case, we did not find the item. We will put a new entry.
                    // However, we will use this index for the new entry, and move
                    // the previous index down the line, to keep the max distance_from_start_index
                    // as small as possible.
                    const new_index = self.entries.addOneAssumeCapacity();
                    if (store_hash) hashes_array.ptr[new_index] = h;
                    indexes[slot] = .{
                        .entry_index = @intCast(I, new_index),
                        .distance_from_start_index = distance_from_start_index,
                    };
                    distance_from_start_index = slot_data.distance_from_start_index;
                    var displaced_index = slot_data.entry_index;

                    // Find somewhere to put the index we replaced by shifting
                    // following indexes backwards.
                    index +%= 1;
                    distance_from_start_index += 1;
                    while (index != end_index) : ({
                        index +%= 1;
                        distance_from_start_index += 1;
                    }) {
                        slot = header.constrainIndex(index);
                        slot_data = indexes[slot];
                        if (slot_data.isEmpty()) {
                            indexes[slot] = .{
                                .entry_index = displaced_index,
                                .distance_from_start_index = distance_from_start_index,
                            };
                            return .{
                                .found_existing = false,
                                .key_ptr = &keys_array.ptr[new_index],
                                // workaround for #6974
                                .value_ptr = if (@sizeOf(*V) == 0) undefined else &values_array.ptr[new_index],
                                .index = new_index,
                            };
                        }

                        if (slot_data.distance_from_start_index < distance_from_start_index) {
                            indexes[slot] = .{
                                .entry_index = displaced_index,
                                .distance_from_start_index = distance_from_start_index,
                            };
                            displaced_index = slot_data.entry_index;
                            distance_from_start_index = slot_data.distance_from_start_index;
                        }
                    }
                    unreachable;
                }
            }
            unreachable;
        }

        fn getSlotByKey(self: Self, key: anytype, ctx: anytype, header: *IndexHeader, comptime I: type, indexes: []Index(I)) ?usize {
            const slice = self.entries.slice();
            const hashes_array = if (store_hash) slice.items(.hash) else {};
            const keys_array = slice.items(.key);
            const h = checkedHash(ctx, key);

            const start_index = safeTruncate(usize, h);
            const end_index = start_index +% indexes.len;

            var index = start_index;
            var distance_from_start_index: I = 0;
            while (index != end_index) : ({
                index +%= 1;
                distance_from_start_index += 1;
            }) {
                const slot = header.constrainIndex(index);
                const slot_data = indexes[slot];
                if (slot_data.isEmpty() or slot_data.distance_from_start_index < distance_from_start_index)
                    return null;

                const hash_match = if (store_hash) h == hashes_array[slot_data.entry_index] else true;
                if (hash_match and checkedEql(ctx, key, keys_array[slot_data.entry_index]))
                    return slot;
            }
            unreachable;
        }

        fn insertAllEntriesIntoNewHeader(self: *Self, ctx: ByIndexContext, header: *IndexHeader) void {
            switch (header.capacityIndexType()) {
                .u8 => return self.insertAllEntriesIntoNewHeaderGeneric(ctx, header, u8),
                .u16 => return self.insertAllEntriesIntoNewHeaderGeneric(ctx, header, u16),
                .u32 => return self.insertAllEntriesIntoNewHeaderGeneric(ctx, header, u32),
            }
        }
        fn insertAllEntriesIntoNewHeaderGeneric(self: *Self, ctx: ByIndexContext, header: *IndexHeader, comptime I: type) void {
            const slice = self.entries.slice();
            const items = if (store_hash) slice.items(.hash) else slice.items(.key);
            const indexes = header.indexes(I);

            entry_loop: for (items) |key, i| {
                const h = if (store_hash) key else checkedHash(ctx, key);
                const start_index = safeTruncate(usize, h);
                const end_index = start_index +% indexes.len;
                var index = start_index;
                var entry_index = @intCast(I, i);
                var distance_from_start_index: I = 0;
                while (index != end_index) : ({
                    index +%= 1;
                    distance_from_start_index += 1;
                }) {
                    const slot = header.constrainIndex(index);
                    const next_index = indexes[slot];
                    if (next_index.isEmpty()) {
                        indexes[slot] = .{
                            .distance_from_start_index = distance_from_start_index,
                            .entry_index = entry_index,
                        };
                        continue :entry_loop;
                    }
                    if (next_index.distance_from_start_index < distance_from_start_index) {
                        indexes[slot] = .{
                            .distance_from_start_index = distance_from_start_index,
                            .entry_index = entry_index,
                        };
                        distance_from_start_index = next_index.distance_from_start_index;
                        entry_index = next_index.entry_index;
                    }
                }
                unreachable;
            }
        }

        inline fn checkedHash(ctx: anytype, key: anytype) u32 {
            comptime std.hash_map.verifyContext(@TypeOf(ctx), @TypeOf(key), K, u32);
            // If you get a compile error on the next line, it means that
            const hash = ctx.hash(key); // your generic hash function doesn't accept your key
            if (@TypeOf(hash) != u32) {
                @compileError("Context " ++ @typeName(@TypeOf(ctx)) ++ " has a generic hash function that returns the wrong type!\n" ++
                    @typeName(u32) ++ " was expected, but found " ++ @typeName(@TypeOf(hash)));
            }
            return hash;
        }
        inline fn checkedEql(ctx: anytype, a: anytype, b: K) bool {
            comptime std.hash_map.verifyContext(@TypeOf(ctx), @TypeOf(a), K, u32);
            // If you get a compile error on the next line, it means that
            const eql = ctx.eql(a, b); // your generic eql function doesn't accept (self, adapt key, K)
            if (@TypeOf(eql) != bool) {
                @compileError("Context " ++ @typeName(@TypeOf(ctx)) ++ " has a generic eql function that returns the wrong type!\n" ++
                    @typeName(bool) ++ " was expected, but found " ++ @typeName(@TypeOf(eql)));
            }
            return eql;
        }

        fn dumpState(self: Self, comptime keyFmt: []const u8, comptime valueFmt: []const u8) void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call dumpStateContext instead.");
            self.dumpStateContext(keyFmt, valueFmt, undefined);
        }
        fn dumpStateContext(self: Self, comptime keyFmt: []const u8, comptime valueFmt: []const u8, ctx: Context) void {
            const p = std.debug.print;
            p("{s}:\n", .{@typeName(Self)});
            const slice = self.entries.slice();
            const hash_status = if (store_hash) "stored" else "computed";
            p("  len={} capacity={} hashes {s}\n", .{ slice.len, slice.capacity, hash_status });
            var i: usize = 0;
            const mask: u32 = if (self.index_header) |header| header.mask() else ~@as(u32, 0);
            while (i < slice.len) : (i += 1) {
                const hash = if (store_hash) slice.items(.hash)[i] else checkedHash(ctx, slice.items(.key)[i]);
                if (store_hash) {
                    p(
                        "  [{}]: key=" ++ keyFmt ++ " value=" ++ valueFmt ++ " hash=0x{x} slot=[0x{x}]\n",
                        .{ i, slice.items(.key)[i], slice.items(.value)[i], hash, hash & mask },
                    );
                } else {
                    p(
                        "  [{}]: key=" ++ keyFmt ++ " value=" ++ valueFmt ++ " slot=[0x{x}]\n",
                        .{ i, slice.items(.key)[i], slice.items(.value)[i], hash & mask },
                    );
                }
            }
            if (self.index_header) |header| {
                p("\n", .{});
                switch (header.capacityIndexType()) {
                    .u8 => self.dumpIndex(header, u8),
                    .u16 => self.dumpIndex(header, u16),
                    .u32 => self.dumpIndex(header, u32),
                }
            }
        }
        fn dumpIndex(self: Self, header: *IndexHeader, comptime I: type) void {
            const p = std.debug.print;
            p("  index len=0x{x} type={}\n", .{ header.length(), header.capacityIndexType() });
            const indexes = header.indexes(I);
            if (indexes.len == 0) return;
            var is_empty = false;
            for (indexes) |idx, i| {
                if (idx.isEmpty()) {
                    is_empty = true;
                } else {
                    if (is_empty) {
                        is_empty = false;
                        p("  ...\n", .{});
                    }
                    p("  [0x{x}]: [{}] +{}\n", .{ i, idx.entry_index, idx.distance_from_start_index });
                }
            }
            if (is_empty) {
                p("  ...\n", .{});
            }
        }
    };
}

const CapacityIndexType = enum { u8, u16, u32 };

fn capacityIndexType(bit_index: u8) CapacityIndexType {
    if (bit_index <= 8)
        return .u8;
    if (bit_index <= 16)
        return .u16;
    assert(bit_index <= 32);
    return .u32;
}

fn capacityIndexSize(bit_index: u8) usize {
    switch (capacityIndexType(bit_index)) {
        .u8 => return @sizeOf(Index(u8)),
        .u16 => return @sizeOf(Index(u16)),
        .u32 => return @sizeOf(Index(u32)),
    }
}

/// @truncate fails if the target type is larger than the
/// target value.  This causes problems when one of the types
/// is usize, which may be larger or smaller than u32 on different
/// systems.  This version of truncate is safe to use if either
/// parameter has dynamic size, and will perform widening conversion
/// when needed.  Both arguments must have the same signedness.
fn safeTruncate(comptime T: type, val: anytype) T {
    if (@bitSizeOf(T) >= @bitSizeOf(@TypeOf(val)))
        return val;
    return @truncate(T, val);
}

/// A single entry in the lookup acceleration structure.  These structs
/// are found in an array after the IndexHeader.  Hashes index into this
/// array, and linear probing is used for collisions.
fn Index(comptime I: type) type {
    return extern struct {
        const Self = @This();

        /// The index of this entry in the backing store.  If the index is
        /// empty, this is empty_sentinel.
        entry_index: I,

        /// The distance between this slot and its ideal placement.  This is
        /// used to keep maximum scan length small.  This value is undefined
        /// if the index is empty.
        distance_from_start_index: I,

        /// The special entry_index value marking an empty slot.
        const empty_sentinel = ~@as(I, 0);

        /// A constant empty index
        const empty = Self{
            .entry_index = empty_sentinel,
            .distance_from_start_index = undefined,
        };

        /// Checks if a slot is empty
        fn isEmpty(idx: Self) bool {
            return idx.entry_index == empty_sentinel;
        }

        /// Sets a slot to empty
        fn setEmpty(idx: *Self) void {
            idx.entry_index = empty_sentinel;
            idx.distance_from_start_index = undefined;
        }
    };
}

/// the byte size of the index must fit in a usize.  This is a power of two
/// length * the size of an Index(u32).  The index is 8 bytes (3 bits repr)
/// and max_usize + 1 is not representable, so we need to subtract out 4 bits.
const max_representable_index_len = @bitSizeOf(usize) - 4;
const max_bit_index = math.min(32, max_representable_index_len);
const min_bit_index = 5;
const max_capacity = (1 << max_bit_index) - 1;
const index_capacities = blk: {
    var caps: [max_bit_index + 1]u32 = undefined;
    for (caps[0..max_bit_index]) |*item, i| {
        item.* = (1 << i) * 3 / 5;
    }
    caps[max_bit_index] = max_capacity;
    break :blk caps;
};

/// This struct is trailed by two arrays of length indexes_len
/// of integers, whose integer size is determined by indexes_len.
/// These arrays are indexed by constrainIndex(hash).  The
/// entryIndexes array contains the index in the dense backing store
/// where the entry's data can be found.  Entries which are not in
/// use have their index value set to emptySentinel(I).
/// The entryDistances array stores the distance between an entry
/// and its ideal hash bucket.  This is used when adding elements
/// to balance the maximum scan length.
const IndexHeader = struct {
    /// This field tracks the total number of items in the arrays following
    /// this header.  It is the bit index of the power of two number of indices.
    /// This value is between min_bit_index and max_bit_index, inclusive.
    bit_index: u8 align(@alignOf(u32)),

    /// Map from an incrementing index to an index slot in the attached arrays.
    fn constrainIndex(header: IndexHeader, i: usize) usize {
        // This is an optimization for modulo of power of two integers;
        // it requires `indexes_len` to always be a power of two.
        return @intCast(usize, i & header.mask());
    }

    /// Returns the attached array of indexes.  I must match the type
    /// returned by capacityIndexType.
    fn indexes(header: *IndexHeader, comptime I: type) []Index(I) {
        const start_ptr = @ptrCast([*]Index(I), @ptrCast([*]u8, header) + @sizeOf(IndexHeader));
        return start_ptr[0..header.length()];
    }

    /// Returns the type used for the index arrays.
    fn capacityIndexType(header: IndexHeader) CapacityIndexType {
        return hash_map.capacityIndexType(header.bit_index);
    }

    fn capacity(self: IndexHeader) u32 {
        return index_capacities[self.bit_index];
    }
    fn length(self: IndexHeader) usize {
        return @as(usize, 1) << @intCast(math.Log2Int(usize), self.bit_index);
    }
    fn mask(self: IndexHeader) u32 {
        return @intCast(u32, self.length() - 1);
    }

    fn findBitIndex(desired_capacity: usize) !u8 {
        if (desired_capacity > max_capacity) return error.OutOfMemory;
        var new_bit_index = @intCast(u8, std.math.log2_int_ceil(usize, desired_capacity));
        if (desired_capacity > index_capacities[new_bit_index]) new_bit_index += 1;
        if (new_bit_index < min_bit_index) new_bit_index = min_bit_index;
        assert(desired_capacity <= index_capacities[new_bit_index]);
        return new_bit_index;
    }

    /// Allocates an index header, and fills the entryIndexes array with empty.
    /// The distance array contents are undefined.
    fn alloc(allocator: *Allocator, new_bit_index: u8) !*IndexHeader {
        const len = @as(usize, 1) << @intCast(math.Log2Int(usize), new_bit_index);
        const index_size = hash_map.capacityIndexSize(new_bit_index);
        const nbytes = @sizeOf(IndexHeader) + index_size * len;
        const bytes = try allocator.allocAdvanced(u8, @alignOf(IndexHeader), nbytes, .exact);
        @memset(bytes.ptr + @sizeOf(IndexHeader), 0xff, bytes.len - @sizeOf(IndexHeader));
        const result = @ptrCast(*IndexHeader, bytes.ptr);
        result.* = .{
            .bit_index = new_bit_index,
        };
        return result;
    }

    /// Releases the memory for a header and its associated arrays.
    fn free(header: *IndexHeader, allocator: *Allocator) void {
        const index_size = hash_map.capacityIndexSize(header.bit_index);
        const ptr = @ptrCast([*]align(@alignOf(IndexHeader)) u8, header);
        const slice = ptr[0 .. @sizeOf(IndexHeader) + header.length() * index_size];
        allocator.free(slice);
    }

    // Verify that the header has sufficient alignment to produce aligned arrays.
    comptime {
        if (@alignOf(u32) > @alignOf(IndexHeader))
            @compileError("IndexHeader must have a larger alignment than its indexes!");
    }
};

test "basic hash map usage" {
    var map = AutoArrayHashMap(i32, i32).init(std.testing.allocator);
    defer map.deinit();

    try testing.expect((try map.fetchPut(1, 11)) == null);
    try testing.expect((try map.fetchPut(2, 22)) == null);
    try testing.expect((try map.fetchPut(3, 33)) == null);
    try testing.expect((try map.fetchPut(4, 44)) == null);

    try map.putNoClobber(5, 55);
    try testing.expect((try map.fetchPut(5, 66)).?.value == 55);
    try testing.expect((try map.fetchPut(5, 55)).?.value == 66);

    const gop1 = try map.getOrPut(5);
    try testing.expect(gop1.found_existing == true);
    try testing.expect(gop1.value_ptr.* == 55);
    try testing.expect(gop1.index == 4);
    gop1.value_ptr.* = 77;
    try testing.expect(map.getEntry(5).?.value_ptr.* == 77);

    const gop2 = try map.getOrPut(99);
    try testing.expect(gop2.found_existing == false);
    try testing.expect(gop2.index == 5);
    gop2.value_ptr.* = 42;
    try testing.expect(map.getEntry(99).?.value_ptr.* == 42);

    const gop3 = try map.getOrPutValue(5, 5);
    try testing.expect(gop3.value_ptr.* == 77);

    const gop4 = try map.getOrPutValue(100, 41);
    try testing.expect(gop4.value_ptr.* == 41);

    try testing.expect(map.contains(2));
    try testing.expect(map.getEntry(2).?.value_ptr.* == 22);
    try testing.expect(map.get(2).? == 22);

    const rmv1 = map.fetchSwapRemove(2);
    try testing.expect(rmv1.?.key == 2);
    try testing.expect(rmv1.?.value == 22);
    try testing.expect(map.fetchSwapRemove(2) == null);
    try testing.expect(map.swapRemove(2) == false);
    try testing.expect(map.getEntry(2) == null);
    try testing.expect(map.get(2) == null);

    // Since we've used `swapRemove` above, the index of this entry should remain unchanged.
    try testing.expect(map.getIndex(100).? == 1);
    const gop5 = try map.getOrPut(5);
    try testing.expect(gop5.found_existing == true);
    try testing.expect(gop5.value_ptr.* == 77);
    try testing.expect(gop5.index == 4);

    // Whereas, if we do an `orderedRemove`, it should move the index forward one spot.
    const rmv2 = map.fetchOrderedRemove(100);
    try testing.expect(rmv2.?.key == 100);
    try testing.expect(rmv2.?.value == 41);
    try testing.expect(map.fetchOrderedRemove(100) == null);
    try testing.expect(map.orderedRemove(100) == false);
    try testing.expect(map.getEntry(100) == null);
    try testing.expect(map.get(100) == null);
    const gop6 = try map.getOrPut(5);
    try testing.expect(gop6.found_existing == true);
    try testing.expect(gop6.value_ptr.* == 77);
    try testing.expect(gop6.index == 3);

    try testing.expect(map.swapRemove(3));
}

test "iterator hash map" {
    var reset_map = AutoArrayHashMap(i32, i32).init(std.testing.allocator);
    defer reset_map.deinit();

    // test ensureCapacity with a 0 parameter
    try reset_map.ensureTotalCapacity(0);

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
        buffer[@intCast(usize, entry.key_ptr.*)] = entry.value_ptr.*;
    }
    try testing.expect(count == 3);
    try testing.expect(it.next() == null);

    for (buffer) |v, i| {
        try testing.expect(buffer[@intCast(usize, keys[i])] == values[i]);
    }

    it.reset();
    count = 0;
    while (it.next()) |entry| {
        buffer[@intCast(usize, entry.key_ptr.*)] = entry.value_ptr.*;
        count += 1;
        if (count >= 2) break;
    }

    for (buffer[0..2]) |v, i| {
        try testing.expect(buffer[@intCast(usize, keys[i])] == values[i]);
    }

    it.reset();
    var entry = it.next().?;
    try testing.expect(entry.key_ptr.* == first_entry.key_ptr.*);
    try testing.expect(entry.value_ptr.* == first_entry.value_ptr.*);
}

test "ensure capacity" {
    var map = AutoArrayHashMap(i32, i32).init(std.testing.allocator);
    defer map.deinit();

    try map.ensureTotalCapacity(20);
    const initial_capacity = map.capacity();
    try testing.expect(initial_capacity >= 20);
    var i: i32 = 0;
    while (i < 20) : (i += 1) {
        try testing.expect(map.fetchPutAssumeCapacity(i, i + 10) == null);
    }
    // shouldn't resize from putAssumeCapacity
    try testing.expect(initial_capacity == map.capacity());
}

test "big map" {
    var map = AutoArrayHashMap(i32, i32).init(std.testing.allocator);
    defer map.deinit();

    var i: i32 = 0;
    while (i < 8) : (i += 1) {
        try map.put(i, i + 10);
    }

    i = 0;
    while (i < 8) : (i += 1) {
        try testing.expectEqual(@as(?i32, i + 10), map.get(i));
    }
    while (i < 16) : (i += 1) {
        try testing.expectEqual(@as(?i32, null), map.get(i));
    }

    i = 4;
    while (i < 12) : (i += 1) {
        try map.put(i, i + 12);
    }

    i = 0;
    while (i < 4) : (i += 1) {
        try testing.expectEqual(@as(?i32, i + 10), map.get(i));
    }
    while (i < 12) : (i += 1) {
        try testing.expectEqual(@as(?i32, i + 12), map.get(i));
    }
    while (i < 16) : (i += 1) {
        try testing.expectEqual(@as(?i32, null), map.get(i));
    }

    i = 0;
    while (i < 4) : (i += 1) {
        try testing.expect(map.orderedRemove(i));
    }
    while (i < 8) : (i += 1) {
        try testing.expect(map.swapRemove(i));
    }

    i = 0;
    while (i < 8) : (i += 1) {
        try testing.expectEqual(@as(?i32, null), map.get(i));
    }
    while (i < 12) : (i += 1) {
        try testing.expectEqual(@as(?i32, i + 12), map.get(i));
    }
    while (i < 16) : (i += 1) {
        try testing.expectEqual(@as(?i32, null), map.get(i));
    }
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
        try testing.expect(original.get(i).? == i * 10);
        try testing.expect(copy.get(i).? == i * 10);
        try testing.expect(original.getPtr(i).? != copy.getPtr(i).?);
    }

    while (i < 20) : (i += 1) {
        try testing.expect(original.get(i) == null);
        try testing.expect(copy.get(i) == null);
    }
}

test "shrink" {
    var map = AutoArrayHashMap(i32, i32).init(std.testing.allocator);
    defer map.deinit();

    // This test is more interesting if we insert enough entries to allocate the index header.
    const num_entries = 20;
    var i: i32 = 0;
    while (i < num_entries) : (i += 1)
        try testing.expect((try map.fetchPut(i, i * 10)) == null);

    try testing.expect(map.unmanaged.index_header != null);
    try testing.expect(map.count() == num_entries);

    // Test `shrinkRetainingCapacity`.
    map.shrinkRetainingCapacity(17);
    try testing.expect(map.count() == 17);
    try testing.expect(map.capacity() == 20);
    i = 0;
    while (i < num_entries) : (i += 1) {
        const gop = try map.getOrPut(i);
        if (i < 17) {
            try testing.expect(gop.found_existing == true);
            try testing.expect(gop.value_ptr.* == i * 10);
        } else try testing.expect(gop.found_existing == false);
    }

    // Test `shrinkAndFree`.
    map.shrinkAndFree(15);
    try testing.expect(map.count() == 15);
    try testing.expect(map.capacity() == 15);
    i = 0;
    while (i < num_entries) : (i += 1) {
        const gop = try map.getOrPut(i);
        if (i < 15) {
            try testing.expect(gop.found_existing == true);
            try testing.expect(gop.value_ptr.* == i * 10);
        } else try testing.expect(gop.found_existing == false);
    }
}

test "pop" {
    var map = AutoArrayHashMap(i32, i32).init(std.testing.allocator);
    defer map.deinit();

    // Insert just enough entries so that the map expands. Afterwards,
    // pop all entries out of the map.

    var i: i32 = 0;
    while (i < 9) : (i += 1) {
        try testing.expect((try map.fetchPut(i, i)) == null);
    }

    while (i > 0) : (i -= 1) {
        const pop = map.pop();
        try testing.expect(pop.key == i - 1 and pop.value == i - 1);
    }
}

test "reIndex" {
    var map = ArrayHashMap(i32, i32, AutoContext(i32), true).init(std.testing.allocator);
    defer map.deinit();

    // Populate via the API.
    const num_indexed_entries = 20;
    var i: i32 = 0;
    while (i < num_indexed_entries) : (i += 1)
        try testing.expect((try map.fetchPut(i, i * 10)) == null);

    // Make sure we allocated an index header.
    try testing.expect(map.unmanaged.index_header != null);

    // Now write to the underlying array list directly.
    const num_unindexed_entries = 20;
    const hash = getAutoHashFn(i32, void);
    var al = &map.unmanaged.entries;
    while (i < num_indexed_entries + num_unindexed_entries) : (i += 1) {
        try al.append(std.testing.allocator, .{
            .key = i,
            .value = i * 10,
            .hash = hash({}, i),
        });
    }

    // After reindexing, we should see everything.
    try map.reIndex();
    i = 0;
    while (i < num_indexed_entries + num_unindexed_entries) : (i += 1) {
        const gop = try map.getOrPut(i);
        try testing.expect(gop.found_existing == true);
        try testing.expect(gop.value_ptr.* == i * 10);
        try testing.expect(gop.index == i);
    }
}

test "auto store_hash" {
    const HasCheapEql = AutoArrayHashMap(i32, i32);
    const HasExpensiveEql = AutoArrayHashMap([32]i32, i32);
    try testing.expect(meta.fieldInfo(HasCheapEql.Data, .hash).field_type == void);
    try testing.expect(meta.fieldInfo(HasExpensiveEql.Data, .hash).field_type != void);

    const HasCheapEqlUn = AutoArrayHashMapUnmanaged(i32, i32);
    const HasExpensiveEqlUn = AutoArrayHashMapUnmanaged([32]i32, i32);
    try testing.expect(meta.fieldInfo(HasCheapEqlUn.Data, .hash).field_type == void);
    try testing.expect(meta.fieldInfo(HasExpensiveEqlUn.Data, .hash).field_type != void);
}

test "compile everything" {
    std.testing.refAllDecls(AutoArrayHashMap(i32, i32));
    std.testing.refAllDecls(StringArrayHashMap([]const u8));
    std.testing.refAllDecls(AutoArrayHashMap(i32, void));
    std.testing.refAllDecls(StringArrayHashMap(u0));
    std.testing.refAllDecls(AutoArrayHashMapUnmanaged(i32, i32));
    std.testing.refAllDecls(StringArrayHashMapUnmanaged([]const u8));
    std.testing.refAllDecls(AutoArrayHashMapUnmanaged(i32, void));
    std.testing.refAllDecls(StringArrayHashMapUnmanaged(u0));
}

pub fn getHashPtrAddrFn(comptime K: type, comptime Context: type) (fn (Context, K) u32) {
    return struct {
        fn hash(ctx: Context, key: K) u32 {
            return getAutoHashFn(usize, void)({}, @ptrToInt(key));
        }
    }.hash;
}

pub fn getTrivialEqlFn(comptime K: type, comptime Context: type) (fn (Context, K, K) bool) {
    return struct {
        fn eql(ctx: Context, a: K, b: K) bool {
            return a == b;
        }
    }.eql;
}

pub fn AutoContext(comptime K: type) type {
    return struct {
        pub const hash = getAutoHashFn(K, @This());
        pub const eql = getAutoEqlFn(K, @This());
    };
}

pub fn getAutoHashFn(comptime K: type, comptime Context: type) (fn (Context, K) u32) {
    return struct {
        fn hash(ctx: Context, key: K) u32 {
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

pub fn getAutoEqlFn(comptime K: type, comptime Context: type) (fn (Context, K, K) bool) {
    return struct {
        fn eql(ctx: Context, a: K, b: K) bool {
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

pub fn getAutoHashStratFn(comptime K: type, comptime Context: type, comptime strategy: std.hash.Strategy) (fn (Context, K) u32) {
    return struct {
        fn hash(ctx: Context, key: K) u32 {
            var hasher = Wyhash.init(0);
            std.hash.autoHashStrat(&hasher, key, strategy);
            return @truncate(u32, hasher.final());
        }
    }.hash;
}
