const std = @import("std.zig");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const math = std.math;
const mem = std.mem;
const autoHash = std.hash.autoHash;
const Wyhash = std.hash.Wyhash;
const Allocator = mem.Allocator;
const hash_map = @This();

/// An `ArrayHashMap` with default hash and equal functions.
///
/// See `AutoContext` for a description of the hash and equal implementations.
pub fn AutoArrayHashMap(comptime K: type, comptime V: type) type {
    return ArrayHashMap(K, V, AutoContext(K), !autoEqlIsCheap(K));
}

/// An `ArrayHashMapUnmanaged` with default hash and equal functions.
///
/// See `AutoContext` for a description of the hash and equal implementations.
pub fn AutoArrayHashMapUnmanaged(comptime K: type, comptime V: type) type {
    return ArrayHashMapUnmanaged(K, V, AutoContext(K), !autoEqlIsCheap(K));
}

/// An `ArrayHashMap` with strings as keys.
pub fn StringArrayHashMap(comptime V: type) type {
    return ArrayHashMap([]const u8, V, StringContext, true);
}

/// An `ArrayHashMapUnmanaged` with strings as keys.
pub fn StringArrayHashMapUnmanaged(comptime V: type) type {
    return ArrayHashMapUnmanaged([]const u8, V, StringContext, true);
}

pub const StringContext = struct {
    pub fn hash(self: @This(), s: []const u8) u32 {
        _ = self;
        return hashString(s);
    }
    pub fn eql(self: @This(), a: []const u8, b: []const u8, b_index: usize) bool {
        _ = self;
        _ = b_index;
        return eqlString(a, b);
    }
};

pub fn eqlString(a: []const u8, b: []const u8) bool {
    return mem.eql(u8, a, b);
}

pub fn hashString(s: []const u8) u32 {
    return @as(u32, @truncate(std.hash.Wyhash.hash(0, s)));
}

/// Deprecated in favor of `ArrayHashMapWithAllocator` (no code changes needed)
/// or `ArrayHashMapUnmanaged` (will need to update callsites to pass an
/// allocator). After Zig 0.14.0 is released, `ArrayHashMapWithAllocator` will
/// be removed and `ArrayHashMapUnmanaged` will be a deprecated alias. After
/// Zig 0.15.0 is released, the deprecated alias `ArrayHashMapUnmanaged` will
/// be removed.
pub const ArrayHashMap = ArrayHashMapWithAllocator;

/// A hash table of keys and values, each stored sequentially.
///
/// Insertion order is preserved. In general, this data structure supports the same
/// operations as `std.ArrayList`.
///
/// Deletion operations:
/// * `swapRemove` - O(1)
/// * `orderedRemove` - O(N)
///
/// Modifying the hash map while iterating is allowed, however, one must understand
/// the (well defined) behavior when mixing insertions and deletions with iteration.
///
/// See `ArrayHashMapUnmanaged` for a variant of this data structure that accepts an
/// `Allocator` as a parameter when needed rather than storing it.
pub fn ArrayHashMapWithAllocator(
    comptime K: type,
    comptime V: type,
    /// A namespace that provides these two functions:
    /// * `pub fn hash(self, K) u32`
    /// * `pub fn eql(self, K, K, usize) bool`
    ///
    /// The final `usize` in the `eql` function represents the index of the key
    /// that's already inside the map.
    comptime Context: type,
    /// When `false`, this data structure is biased towards cheap `eql`
    /// functions and avoids storing each key's hash in the table. Setting
    /// `store_hash` to `true` incurs more memory cost but limits `eql` to
    /// being called only once per insertion/deletion (provided there are no
    /// hash collisions).
    comptime store_hash: bool,
) type {
    return struct {
        unmanaged: Unmanaged,
        allocator: Allocator,
        ctx: Context,

        /// The ArrayHashMapUnmanaged type using the same settings as this managed map.
        pub const Unmanaged = ArrayHashMapUnmanaged(K, V, Context, store_hash);

        /// Pointers to a key and value in the backing store of this map.
        /// Modifying the key is allowed only if it does not change the hash.
        /// Modifying the value is allowed.
        /// Entry pointers become invalid whenever this ArrayHashMap is modified,
        /// unless `ensureTotalCapacity`/`ensureUnusedCapacity` was previously used.
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
        /// unless `ensureTotalCapacity`/`ensureUnusedCapacity` was previously used.
        pub const GetOrPutResult = Unmanaged.GetOrPutResult;

        /// An Iterator over Entry pointers.
        pub const Iterator = Unmanaged.Iterator;

        const Self = @This();

        /// Create an ArrayHashMap instance which will use a specified allocator.
        pub fn init(allocator: Allocator) Self {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call initContext instead.");
            return initContext(allocator, undefined);
        }
        pub fn initContext(allocator: Allocator, ctx: Context) Self {
            return .{
                .unmanaged = .empty,
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

        /// Puts the hash map into a state where any method call that would
        /// cause an existing key or value pointer to become invalidated will
        /// instead trigger an assertion.
        ///
        /// An additional call to `lockPointers` in such state also triggers an
        /// assertion.
        ///
        /// `unlockPointers` returns the hash map to the previous state.
        pub fn lockPointers(self: *Self) void {
            self.unmanaged.lockPointers();
        }

        /// Undoes a call to `lockPointers`.
        pub fn unlockPointers(self: *Self) void {
            self.unmanaged.unlockPointers();
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

        /// Returns the backing array of keys in this map. Modifying the map may
        /// invalidate this array. Modifying this array in a way that changes
        /// key hashes or key equality puts the map into an unusable state until
        /// `reIndex` is called.
        pub fn keys(self: Self) []K {
            return self.unmanaged.keys();
        }
        /// Returns the backing array of values in this map. Modifying the map
        /// may invalidate this array. It is permitted to modify the values in
        /// this array.
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
            return self.unmanaged.getOrPutContextAdapted(self.allocator, key, ctx, self.ctx);
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
        pub fn capacity(self: Self) usize {
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

        /// Find the actual key associated with an adapted key
        pub fn getKey(self: Self, key: K) ?K {
            return self.unmanaged.getKeyContext(key, self.ctx);
        }
        pub fn getKeyAdapted(self: Self, key: anytype, ctx: anytype) ?K {
            return self.unmanaged.getKeyAdapted(key, ctx);
        }

        /// Find a pointer to the actual key associated with an adapted key
        pub fn getKeyPtr(self: Self, key: K) ?*K {
            return self.unmanaged.getKeyPtrContext(key, self.ctx);
        }
        pub fn getKeyPtrAdapted(self: Self, key: anytype, ctx: anytype) ?*K {
            return self.unmanaged.getKeyPtrAdapted(key, ctx);
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
        pub fn cloneWithAllocator(self: Self, allocator: Allocator) !Self {
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
        pub fn cloneWithAllocatorAndContext(self: Self, allocator: Allocator, ctx: anytype) !ArrayHashMap(K, V, @TypeOf(ctx), store_hash) {
            var other = try self.unmanaged.cloneContext(allocator, ctx);
            return other.promoteContext(allocator, ctx);
        }

        /// Set the map to an empty state, making deinitialization a no-op, and
        /// returning a copy of the original.
        pub fn move(self: *Self) Self {
            self.unmanaged.pointer_stability.assertUnlocked();
            const result = self.*;
            self.unmanaged = .empty;
            return result;
        }

        /// Recomputes stored hashes and rebuilds the key indexes. If the
        /// underlying keys have been modified directly, call this method to
        /// recompute the denormalized metadata necessary for the operation of
        /// the methods of this map that lookup entries by key.
        ///
        /// One use case for this is directly calling `entries.resize()` to grow
        /// the underlying storage, and then setting the `keys` and `values`
        /// directly without going through the methods of this map.
        ///
        /// The time complexity of this operation is O(n).
        pub fn reIndex(self: *Self) !void {
            return self.unmanaged.reIndexContext(self.allocator, self.ctx);
        }

        /// Sorts the entries and then rebuilds the index.
        /// `sort_ctx` must have this method:
        /// `fn lessThan(ctx: @TypeOf(ctx), a_index: usize, b_index: usize) bool`
        pub fn sort(self: *Self, sort_ctx: anytype) void {
            return self.unmanaged.sortContext(sort_ctx, self.ctx);
        }

        /// Shrinks the underlying `Entry` array to `new_len` elements and
        /// discards any associated index entries. Keeps capacity the same.
        ///
        /// Asserts the discarded entries remain initialized and capable of
        /// performing hash and equality checks. Any deinitialization of
        /// discarded entries must take place *after* calling this function.
        pub fn shrinkRetainingCapacity(self: *Self, new_len: usize) void {
            return self.unmanaged.shrinkRetainingCapacityContext(new_len, self.ctx);
        }

        /// Shrinks the underlying `Entry` array to `new_len` elements and
        /// discards any associated index entries. Reduces allocated capacity.
        ///
        /// Asserts the discarded entries remain initialized and capable of
        /// performing hash and equality checks. It is a bug to call this
        /// function if the discarded entries require deinitialization. For
        /// that use case, `shrinkRetainingCapacity` can be used instead.
        pub fn shrinkAndFree(self: *Self, new_len: usize) void {
            return self.unmanaged.shrinkAndFreeContext(self.allocator, new_len, self.ctx);
        }

        /// Removes the last inserted `Entry` in the hash map and returns it if count is nonzero.
        /// Otherwise returns null.
        pub fn pop(self: *Self) ?KV {
            return self.unmanaged.popContext(self.ctx);
        }
    };
}

/// A hash table of keys and values, each stored sequentially.
///
/// Insertion order is preserved. In general, this data structure supports the same
/// operations as `std.ArrayListUnmanaged`.
///
/// Deletion operations:
/// * `swapRemove` - O(1)
/// * `orderedRemove` - O(N)
///
/// Modifying the hash map while iterating is allowed, however, one must understand
/// the (well defined) behavior when mixing insertions and deletions with iteration.
///
/// This type does not store an `Allocator` field - the `Allocator` must be passed in
/// with each function call that requires it. See `ArrayHashMap` for a type that stores
/// an `Allocator` field for convenience.
///
/// Can be initialized directly using the default field values.
///
/// This type is designed to have low overhead for small numbers of entries. When
/// `store_hash` is `false` and the number of entries in the map is less than 9,
/// the overhead cost of using `ArrayHashMapUnmanaged` rather than `std.ArrayList` is
/// only a single pointer-sized integer.
///
/// Default initialization of this struct is deprecated; use `.empty` instead.
pub fn ArrayHashMapUnmanaged(
    comptime K: type,
    comptime V: type,
    /// A namespace that provides these two functions:
    /// * `pub fn hash(self, K) u32`
    /// * `pub fn eql(self, K, K, usize) bool`
    ///
    /// The final `usize` in the `eql` function represents the index of the key
    /// that's already inside the map.
    comptime Context: type,
    /// When `false`, this data structure is biased towards cheap `eql`
    /// functions and avoids storing each key's hash in the table. Setting
    /// `store_hash` to `true` incurs more memory cost but limits `eql` to
    /// being called only once per insertion/deletion (provided there are no
    /// hash collisions).
    comptime store_hash: bool,
) type {
    return struct {
        /// It is permitted to access this field directly.
        /// After any modification to the keys, consider calling `reIndex`.
        entries: DataList = .{},

        /// When entries length is less than `linear_scan_max`, this remains `null`.
        /// Once entries length grows big enough, this field is allocated. There is
        /// an IndexHeader followed by an array of Index(I) structs, where I is defined
        /// by how many total indexes there are.
        index_header: ?*IndexHeader = null,

        /// Used to detect memory safety violations.
        pointer_stability: std.debug.SafetyLock = .{},

        /// A map containing no keys or values.
        pub const empty: Self = .{
            .entries = .{},
            .index_header = null,
        };

        /// Modifying the key is allowed only if it does not change the hash.
        /// Modifying the value is allowed.
        /// Entry pointers become invalid whenever this ArrayHashMap is modified,
        /// unless `ensureTotalCapacity`/`ensureUnusedCapacity` was previously used.
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
        /// unless `ensureTotalCapacity`/`ensureUnusedCapacity` was previously used.
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

        const linear_scan_max = @as(comptime_int, @max(1, @as(comptime_int, @min(
            std.atomic.cache_line / @as(comptime_int, @max(1, @sizeOf(Hash))),
            std.atomic.cache_line / @as(comptime_int, @max(1, @sizeOf(K))),
        ))));

        const RemovalType = enum {
            swap,
            ordered,
        };

        const Oom = Allocator.Error;

        /// Convert from an unmanaged map to a managed map.  After calling this,
        /// the promoted map should no longer be used.
        pub fn promote(self: Self, gpa: Allocator) Managed {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call promoteContext instead.");
            return self.promoteContext(gpa, undefined);
        }
        pub fn promoteContext(self: Self, gpa: Allocator, ctx: Context) Managed {
            return .{
                .unmanaged = self,
                .allocator = gpa,
                .ctx = ctx,
            };
        }

        pub fn init(gpa: Allocator, key_list: []const K, value_list: []const V) Oom!Self {
            var self: Self = .{};
            errdefer self.deinit(gpa);
            try self.reinit(gpa, key_list, value_list);
            return self;
        }

        /// An empty `value_list` may be passed, in which case the values array becomes `undefined`.
        pub fn reinit(self: *Self, gpa: Allocator, key_list: []const K, value_list: []const V) Oom!void {
            try self.entries.resize(gpa, key_list.len);
            @memcpy(self.keys(), key_list);
            if (value_list.len == 0) {
                @memset(self.values(), undefined);
            } else {
                assert(key_list.len == value_list.len);
                @memcpy(self.values(), value_list);
            }
            try self.reIndex(gpa);
        }

        /// Frees the backing allocation and leaves the map in an undefined state.
        /// Note that this does not free keys or values.  You must take care of that
        /// before calling this function, if it is needed.
        pub fn deinit(self: *Self, gpa: Allocator) void {
            self.pointer_stability.assertUnlocked();
            self.entries.deinit(gpa);
            if (self.index_header) |header| {
                header.free(gpa);
            }
            self.* = undefined;
        }

        /// Puts the hash map into a state where any method call that would
        /// cause an existing key or value pointer to become invalidated will
        /// instead trigger an assertion.
        ///
        /// An additional call to `lockPointers` in such state also triggers an
        /// assertion.
        ///
        /// `unlockPointers` returns the hash map to the previous state.
        pub fn lockPointers(self: *Self) void {
            self.pointer_stability.lock();
        }

        /// Undoes a call to `lockPointers`.
        pub fn unlockPointers(self: *Self) void {
            self.pointer_stability.unlock();
        }

        /// Clears the map but retains the backing allocation for future use.
        pub fn clearRetainingCapacity(self: *Self) void {
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

            self.entries.len = 0;
            if (self.index_header) |header| {
                switch (header.capacityIndexType()) {
                    .u8 => @memset(header.indexes(u8), Index(u8).empty),
                    .u16 => @memset(header.indexes(u16), Index(u16).empty),
                    .u32 => @memset(header.indexes(u32), Index(u32).empty),
                }
            }
        }

        /// Clears the map and releases the backing allocation
        pub fn clearAndFree(self: *Self, gpa: Allocator) void {
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

            self.entries.shrinkAndFree(gpa, 0);
            if (self.index_header) |header| {
                header.free(gpa);
                self.index_header = null;
            }
        }

        /// Returns the number of KV pairs stored in this map.
        pub fn count(self: Self) usize {
            return self.entries.len;
        }

        /// Returns the backing array of keys in this map. Modifying the map may
        /// invalidate this array. Modifying this array in a way that changes
        /// key hashes or key equality puts the map into an unusable state until
        /// `reIndex` is called.
        pub fn keys(self: Self) []K {
            return self.entries.items(.key);
        }
        /// Returns the backing array of values in this map. Modifying the map
        /// may invalidate this array. It is permitted to modify the values in
        /// this array.
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
                .len = @as(u32, @intCast(slice.len)),
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
        pub fn getOrPut(self: *Self, gpa: Allocator, key: K) Oom!GetOrPutResult {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getOrPutContext instead.");
            return self.getOrPutContext(gpa, key, undefined);
        }
        pub fn getOrPutContext(self: *Self, gpa: Allocator, key: K, ctx: Context) Oom!GetOrPutResult {
            const gop = try self.getOrPutContextAdapted(gpa, key, ctx, ctx);
            if (!gop.found_existing) {
                gop.key_ptr.* = key;
            }
            return gop;
        }
        pub fn getOrPutAdapted(self: *Self, gpa: Allocator, key: anytype, key_ctx: anytype) Oom!GetOrPutResult {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getOrPutContextAdapted instead.");
            return self.getOrPutContextAdapted(gpa, key, key_ctx, undefined);
        }
        pub fn getOrPutContextAdapted(self: *Self, gpa: Allocator, key: anytype, key_ctx: anytype, ctx: Context) Oom!GetOrPutResult {
            self.ensureTotalCapacityContext(gpa, self.entries.len + 1, ctx) catch |err| {
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
                for (keys_array, 0..) |*item_key, i| {
                    if (hashes_array[i] == h and checkedEql(ctx, key, item_key.*, i)) {
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
                // The slice length changed, so we directly index the pointer.
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

        pub fn getOrPutValue(self: *Self, gpa: Allocator, key: K, value: V) Oom!GetOrPutResult {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getOrPutValueContext instead.");
            return self.getOrPutValueContext(gpa, key, value, undefined);
        }
        pub fn getOrPutValueContext(self: *Self, gpa: Allocator, key: K, value: V, ctx: Context) Oom!GetOrPutResult {
            const res = try self.getOrPutContextAdapted(gpa, key, ctx, ctx);
            if (!res.found_existing) {
                res.key_ptr.* = key;
                res.value_ptr.* = value;
            }
            return res;
        }

        /// Increases capacity, guaranteeing that insertions up until the
        /// `expected_count` will not cause an allocation, and therefore cannot fail.
        pub fn ensureTotalCapacity(self: *Self, gpa: Allocator, new_capacity: usize) Oom!void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call ensureTotalCapacityContext instead.");
            return self.ensureTotalCapacityContext(gpa, new_capacity, undefined);
        }
        pub fn ensureTotalCapacityContext(self: *Self, gpa: Allocator, new_capacity: usize, ctx: Context) Oom!void {
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

            if (new_capacity <= linear_scan_max) {
                try self.entries.ensureTotalCapacity(gpa, new_capacity);
                return;
            }

            if (self.index_header) |header| {
                if (new_capacity <= header.capacity()) {
                    try self.entries.ensureTotalCapacity(gpa, new_capacity);
                    return;
                }
            }

            try self.entries.ensureTotalCapacity(gpa, new_capacity);
            const new_bit_index = try IndexHeader.findBitIndex(new_capacity);
            const new_header = try IndexHeader.alloc(gpa, new_bit_index);

            if (self.index_header) |old_header| old_header.free(gpa);
            self.insertAllEntriesIntoNewHeader(if (store_hash) {} else ctx, new_header);
            self.index_header = new_header;
        }

        /// Increases capacity, guaranteeing that insertions up until
        /// `additional_count` **more** items will not cause an allocation, and
        /// therefore cannot fail.
        pub fn ensureUnusedCapacity(
            self: *Self,
            gpa: Allocator,
            additional_capacity: usize,
        ) Oom!void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call ensureTotalCapacityContext instead.");
            return self.ensureUnusedCapacityContext(gpa, additional_capacity, undefined);
        }
        pub fn ensureUnusedCapacityContext(
            self: *Self,
            gpa: Allocator,
            additional_capacity: usize,
            ctx: Context,
        ) Oom!void {
            return self.ensureTotalCapacityContext(gpa, self.count() + additional_capacity, ctx);
        }

        /// Returns the number of total elements which may be present before it is
        /// no longer guaranteed that no allocations will be performed.
        pub fn capacity(self: Self) usize {
            const entry_cap = self.entries.capacity;
            const header = self.index_header orelse return @min(linear_scan_max, entry_cap);
            const indexes_cap = header.capacity();
            return @min(entry_cap, indexes_cap);
        }

        /// Clobbers any existing data. To detect if a put would clobber
        /// existing data, see `getOrPut`.
        pub fn put(self: *Self, gpa: Allocator, key: K, value: V) Oom!void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call putContext instead.");
            return self.putContext(gpa, key, value, undefined);
        }
        pub fn putContext(self: *Self, gpa: Allocator, key: K, value: V, ctx: Context) Oom!void {
            const result = try self.getOrPutContext(gpa, key, ctx);
            result.value_ptr.* = value;
        }

        /// Inserts a key-value pair into the hash map, asserting that no previous
        /// entry with the same key is already present
        pub fn putNoClobber(self: *Self, gpa: Allocator, key: K, value: V) Oom!void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call putNoClobberContext instead.");
            return self.putNoClobberContext(gpa, key, value, undefined);
        }
        pub fn putNoClobberContext(self: *Self, gpa: Allocator, key: K, value: V, ctx: Context) Oom!void {
            const result = try self.getOrPutContext(gpa, key, ctx);
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
        pub fn fetchPut(self: *Self, gpa: Allocator, key: K, value: V) Oom!?KV {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call fetchPutContext instead.");
            return self.fetchPutContext(gpa, key, value, undefined);
        }
        pub fn fetchPutContext(self: *Self, gpa: Allocator, key: K, value: V, ctx: Context) Oom!?KV {
            const gop = try self.getOrPutContext(gpa, key, ctx);
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
                for (keys_array, 0..) |*item_key, i| {
                    if (hashes_array[i] == h and checkedEql(ctx, key, item_key.*, i)) {
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

        /// Find the actual key associated with an adapted key
        pub fn getKey(self: Self, key: K) ?K {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getKeyContext instead.");
            return self.getKeyContext(key, undefined);
        }
        pub fn getKeyContext(self: Self, key: K, ctx: Context) ?K {
            return self.getKeyAdapted(key, ctx);
        }
        pub fn getKeyAdapted(self: Self, key: anytype, ctx: anytype) ?K {
            const index = self.getIndexAdapted(key, ctx) orelse return null;
            return self.keys()[index];
        }

        /// Find a pointer to the actual key associated with an adapted key
        pub fn getKeyPtr(self: Self, key: K) ?*K {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getKeyPtrContext instead.");
            return self.getKeyPtrContext(key, undefined);
        }
        pub fn getKeyPtrContext(self: Self, key: K, ctx: Context) ?*K {
            return self.getKeyPtrAdapted(key, ctx);
        }
        pub fn getKeyPtrAdapted(self: Self, key: anytype, ctx: anytype) ?*K {
            const index = self.getIndexAdapted(key, ctx) orelse return null;
            return &self.keys()[index];
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
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

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
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

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
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

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
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

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
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

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
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

            self.removeByIndex(index, if (store_hash) {} else ctx, .ordered);
        }

        /// Create a copy of the hash map which can be modified separately.
        /// The copy uses the same context as this instance, but is allocated
        /// with the provided allocator.
        pub fn clone(self: Self, gpa: Allocator) Oom!Self {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call cloneContext instead.");
            return self.cloneContext(gpa, undefined);
        }
        pub fn cloneContext(self: Self, gpa: Allocator, ctx: Context) Oom!Self {
            var other: Self = .{};
            other.entries = try self.entries.clone(gpa);
            errdefer other.entries.deinit(gpa);

            if (self.index_header) |header| {
                // TODO: I'm pretty sure this could be memcpy'd instead of
                // doing all this work.
                const new_header = try IndexHeader.alloc(gpa, header.bit_index);
                other.insertAllEntriesIntoNewHeader(if (store_hash) {} else ctx, new_header);
                other.index_header = new_header;
            }
            return other;
        }

        /// Set the map to an empty state, making deinitialization a no-op, and
        /// returning a copy of the original.
        pub fn move(self: *Self) Self {
            self.pointer_stability.assertUnlocked();
            const result = self.*;
            self.* = .empty;
            return result;
        }

        /// Recomputes stored hashes and rebuilds the key indexes. If the
        /// underlying keys have been modified directly, call this method to
        /// recompute the denormalized metadata necessary for the operation of
        /// the methods of this map that lookup entries by key.
        ///
        /// One use case for this is directly calling `entries.resize()` to grow
        /// the underlying storage, and then setting the `keys` and `values`
        /// directly without going through the methods of this map.
        ///
        /// The time complexity of this operation is O(n).
        pub fn reIndex(self: *Self, gpa: Allocator) Oom!void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call reIndexContext instead.");
            return self.reIndexContext(gpa, undefined);
        }

        pub fn reIndexContext(self: *Self, gpa: Allocator, ctx: Context) Oom!void {
            // Recompute all hashes.
            if (store_hash) {
                for (self.keys(), self.entries.items(.hash)) |key, *hash| {
                    const h = checkedHash(ctx, key);
                    hash.* = h;
                }
            }
            try rebuildIndex(self, gpa, ctx);
        }

        /// Modify an entry's key without reordering any entries.
        pub fn setKey(self: *Self, gpa: Allocator, index: usize, new_key: K) Oom!void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call setKeyContext instead.");
            return setKeyContext(self, gpa, index, new_key, undefined);
        }

        pub fn setKeyContext(self: *Self, gpa: Allocator, index: usize, new_key: K, ctx: Context) Oom!void {
            const key_ptr = &self.entries.items(.key)[index];
            key_ptr.* = new_key;
            if (store_hash) self.entries.items(.hash)[index].* = checkedHash(ctx, key_ptr.*);
            try rebuildIndex(self, gpa, undefined);
        }

        fn rebuildIndex(self: *Self, gpa: Allocator, ctx: Context) Oom!void {
            if (self.entries.capacity <= linear_scan_max) return;

            // We're going to rebuild the index header and replace the existing one (if any). The
            // indexes should sized such that they will be at most 60% full.
            const bit_index = try IndexHeader.findBitIndex(self.entries.capacity);
            const new_header = try IndexHeader.alloc(gpa, bit_index);
            if (self.index_header) |header| header.free(gpa);
            self.insertAllEntriesIntoNewHeader(if (store_hash) {} else ctx, new_header);
            self.index_header = new_header;
        }

        /// Sorts the entries and then rebuilds the index.
        /// `sort_ctx` must have this method:
        /// `fn lessThan(ctx: @TypeOf(ctx), a_index: usize, b_index: usize) bool`
        /// Uses a stable sorting algorithm.
        pub inline fn sort(self: *Self, sort_ctx: anytype) void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call sortContext instead.");
            return sortContextInternal(self, .stable, sort_ctx, undefined);
        }

        /// Sorts the entries and then rebuilds the index.
        /// `sort_ctx` must have this method:
        /// `fn lessThan(ctx: @TypeOf(ctx), a_index: usize, b_index: usize) bool`
        /// Uses an unstable sorting algorithm.
        pub inline fn sortUnstable(self: *Self, sort_ctx: anytype) void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call sortUnstableContext instead.");
            return self.sortContextInternal(.unstable, sort_ctx, undefined);
        }

        pub inline fn sortContext(self: *Self, sort_ctx: anytype, ctx: Context) void {
            return sortContextInternal(self, .stable, sort_ctx, ctx);
        }

        pub inline fn sortUnstableContext(self: *Self, sort_ctx: anytype, ctx: Context) void {
            return sortContextInternal(self, .unstable, sort_ctx, ctx);
        }

        fn sortContextInternal(
            self: *Self,
            comptime mode: std.sort.Mode,
            sort_ctx: anytype,
            ctx: Context,
        ) void {
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

            switch (mode) {
                .stable => self.entries.sort(sort_ctx),
                .unstable => self.entries.sortUnstable(sort_ctx),
            }
            const header = self.index_header orelse return;
            header.reset();
            self.insertAllEntriesIntoNewHeader(if (store_hash) {} else ctx, header);
        }

        /// Shrinks the underlying `Entry` array to `new_len` elements and
        /// discards any associated index entries. Keeps capacity the same.
        ///
        /// Asserts the discarded entries remain initialized and capable of
        /// performing hash and equality checks. Any deinitialization of
        /// discarded entries must take place *after* calling this function.
        pub fn shrinkRetainingCapacity(self: *Self, new_len: usize) void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call shrinkRetainingCapacityContext instead.");
            return self.shrinkRetainingCapacityContext(new_len, undefined);
        }

        /// Shrinks the underlying `Entry` array to `new_len` elements and
        /// discards any associated index entries. Keeps capacity the same.
        ///
        /// Asserts the discarded entries remain initialized and capable of
        /// performing hash and equality checks. Any deinitialization of
        /// discarded entries must take place *after* calling this function.
        pub fn shrinkRetainingCapacityContext(self: *Self, new_len: usize, ctx: Context) void {
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

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

        /// Shrinks the underlying `Entry` array to `new_len` elements and
        /// discards any associated index entries. Reduces allocated capacity.
        ///
        /// Asserts the discarded entries remain initialized and capable of
        /// performing hash and equality checks. It is a bug to call this
        /// function if the discarded entries require deinitialization. For
        /// that use case, `shrinkRetainingCapacity` can be used instead.
        pub fn shrinkAndFree(self: *Self, gpa: Allocator, new_len: usize) void {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call shrinkAndFreeContext instead.");
            return self.shrinkAndFreeContext(gpa, new_len, undefined);
        }

        /// Shrinks the underlying `Entry` array to `new_len` elements and
        /// discards any associated index entries. Reduces allocated capacity.
        ///
        /// Asserts the discarded entries remain initialized and capable of
        /// performing hash and equality checks. It is a bug to call this
        /// function if the discarded entries require deinitialization. For
        /// that use case, `shrinkRetainingCapacityContext` can be used
        /// instead.
        pub fn shrinkAndFreeContext(self: *Self, gpa: Allocator, new_len: usize, ctx: Context) void {
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

            // Remove index entries from the new length onwards.
            // Explicitly choose to ONLY remove index entries and not the underlying array list
            // entries as we're going to remove them in the subsequent shrink call.
            if (self.index_header) |header| {
                var i: usize = new_len;
                while (i < self.entries.len) : (i += 1)
                    self.removeFromIndexByIndex(i, if (store_hash) {} else ctx, header);
            }
            self.entries.shrinkAndFree(gpa, new_len);
        }

        /// Removes the last inserted `Entry` in the hash map and returns it.
        /// Otherwise returns null.
        pub fn pop(self: *Self) ?KV {
            if (@sizeOf(ByIndexContext) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call popContext instead.");
            return self.popContext(undefined);
        }
        pub fn popContext(self: *Self, ctx: Context) ?KV {
            if (self.entries.len == 0) return null;
            self.pointer_stability.lock();
            defer self.pointer_stability.unlock();

            const item = self.entries.get(self.entries.len - 1);
            if (self.index_header) |header|
                self.removeFromIndexByIndex(self.entries.len - 1, if (store_hash) {} else ctx, header);
            self.entries.len -= 1;
            return .{
                .key = item.key,
                .value = item.value,
            };
        }

        fn fetchRemoveByKey(
            self: *Self,
            key: anytype,
            key_ctx: anytype,
            ctx: ByIndexContext,
            comptime removal_type: RemovalType,
        ) ?KV {
            const header = self.index_header orelse {
                // Linear scan.
                const key_hash = if (store_hash) key_ctx.hash(key) else {};
                const slice = self.entries.slice();
                const hashes_array = if (store_hash) slice.items(.hash) else {};
                const keys_array = slice.items(.key);
                for (keys_array, 0..) |*item_key, i| {
                    const hash_match = if (store_hash) hashes_array[i] == key_hash else true;
                    if (hash_match and key_ctx.eql(key, item_key.*, i)) {
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
        fn fetchRemoveByKeyGeneric(
            self: *Self,
            key: anytype,
            key_ctx: anytype,
            ctx: ByIndexContext,
            header: *IndexHeader,
            comptime I: type,
            comptime removal_type: RemovalType,
        ) ?KV {
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

        fn removeByKey(
            self: *Self,
            key: anytype,
            key_ctx: anytype,
            ctx: ByIndexContext,
            comptime removal_type: RemovalType,
        ) bool {
            const header = self.index_header orelse {
                // Linear scan.
                const key_hash = if (store_hash) key_ctx.hash(key) else {};
                const slice = self.entries.slice();
                const hashes_array = if (store_hash) slice.items(.hash) else {};
                const keys_array = slice.items(.key);
                for (keys_array, 0..) |*item_key, i| {
                    const hash_match = if (store_hash) hashes_array[i] == key_hash else true;
                    if (hash_match and key_ctx.eql(key, item_key.*, i)) {
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
            indexes[slot].entry_index = @as(I, @intCast(new_entry_index));
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
            removeSlot(slot, header, I, indexes);
        }

        fn removeFromIndexByKey(self: *Self, key: anytype, ctx: anytype, header: *IndexHeader, comptime I: type, indexes: []Index(I)) ?usize {
            const slot = self.getSlotByKey(key, ctx, header, I, indexes) orelse return null;
            const removed_entry_index = indexes[slot].entry_index;
            removeSlot(slot, header, I, indexes);
            return removed_entry_index;
        }

        fn removeSlot(removed_slot: usize, header: *IndexHeader, comptime I: type, indexes: []Index(I)) void {
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

        /// Must `ensureTotalCapacity`/`ensureUnusedCapacity` before calling this.
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
                        .entry_index = @as(I, @intCast(new_index)),
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
                // entries.ensureTotalCapacity before getOrPutInternal.
                const i = slot_data.entry_index;
                const hash_match = if (store_hash) h == hashes_array[i] else true;
                if (hash_match and checkedEql(ctx, key, keys_array[i], i)) {
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
                        .entry_index = @as(I, @intCast(new_index)),
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

                const i = slot_data.entry_index;
                const hash_match = if (store_hash) h == hashes_array[i] else true;
                if (hash_match and checkedEql(ctx, key, keys_array[i], i))
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

            entry_loop: for (items, 0..) |key, i| {
                const h = if (store_hash) key else checkedHash(ctx, key);
                const start_index = safeTruncate(usize, h);
                const end_index = start_index +% indexes.len;
                var index = start_index;
                var entry_index = @as(I, @intCast(i));
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

        fn checkedHash(ctx: anytype, key: anytype) u32 {
            // If you get a compile error on the next line, it means that your
            // generic hash function doesn't accept your key.
            return ctx.hash(key);
        }

        fn checkedEql(ctx: anytype, a: anytype, b: K, b_index: usize) bool {
            // If you get a compile error on the next line, it means that your
            // generic eql function doesn't accept (self, adapt key, K, index).
            return ctx.eql(a, b, b_index);
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
                    .u8 => dumpIndex(header, u8),
                    .u16 => dumpIndex(header, u16),
                    .u32 => dumpIndex(header, u32),
                }
            }
        }
        fn dumpIndex(header: *IndexHeader, comptime I: type) void {
            const p = std.debug.print;
            p("  index len=0x{x} type={}\n", .{ header.length(), header.capacityIndexType() });
            const indexes = header.indexes(I);
            if (indexes.len == 0) return;
            var is_empty = false;
            for (indexes, 0..) |idx, i| {
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
    return @as(T, @truncate(val));
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
const max_bit_index = @min(32, max_representable_index_len);
const min_bit_index = 5;
const max_capacity = (1 << max_bit_index) - 1;
const index_capacities = blk: {
    var caps: [max_bit_index + 1]u32 = undefined;
    for (caps[0..max_bit_index], 0..) |*item, i| {
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
        return @as(usize, @intCast(i & header.mask()));
    }

    /// Returns the attached array of indexes.  I must match the type
    /// returned by capacityIndexType.
    fn indexes(header: *IndexHeader, comptime I: type) []Index(I) {
        const start_ptr: [*]Index(I) = @alignCast(@ptrCast(@as([*]u8, @ptrCast(header)) + @sizeOf(IndexHeader)));
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
        return @as(usize, 1) << @as(math.Log2Int(usize), @intCast(self.bit_index));
    }
    fn mask(self: IndexHeader) u32 {
        return @as(u32, @intCast(self.length() - 1));
    }

    fn findBitIndex(desired_capacity: usize) Allocator.Error!u8 {
        if (desired_capacity > max_capacity) return error.OutOfMemory;
        var new_bit_index = @as(u8, @intCast(std.math.log2_int_ceil(usize, desired_capacity)));
        if (desired_capacity > index_capacities[new_bit_index]) new_bit_index += 1;
        if (new_bit_index < min_bit_index) new_bit_index = min_bit_index;
        assert(desired_capacity <= index_capacities[new_bit_index]);
        return new_bit_index;
    }

    /// Allocates an index header, and fills the entryIndexes array with empty.
    /// The distance array contents are undefined.
    fn alloc(gpa: Allocator, new_bit_index: u8) Allocator.Error!*IndexHeader {
        const len = @as(usize, 1) << @as(math.Log2Int(usize), @intCast(new_bit_index));
        const index_size = hash_map.capacityIndexSize(new_bit_index);
        const nbytes = @sizeOf(IndexHeader) + index_size * len;
        const bytes = try gpa.alignedAlloc(u8, @alignOf(IndexHeader), nbytes);
        @memset(bytes[@sizeOf(IndexHeader)..], 0xff);
        const result: *IndexHeader = @alignCast(@ptrCast(bytes.ptr));
        result.* = .{
            .bit_index = new_bit_index,
        };
        return result;
    }

    /// Releases the memory for a header and its associated arrays.
    fn free(header: *IndexHeader, gpa: Allocator) void {
        const index_size = hash_map.capacityIndexSize(header.bit_index);
        const ptr: [*]align(@alignOf(IndexHeader)) u8 = @ptrCast(header);
        const slice = ptr[0 .. @sizeOf(IndexHeader) + header.length() * index_size];
        gpa.free(slice);
    }

    /// Puts an IndexHeader into the state that it would be in after being freshly allocated.
    fn reset(header: *IndexHeader) void {
        const index_size = hash_map.capacityIndexSize(header.bit_index);
        const ptr: [*]align(@alignOf(IndexHeader)) u8 = @ptrCast(header);
        const nbytes = @sizeOf(IndexHeader) + header.length() * index_size;
        @memset(ptr[@sizeOf(IndexHeader)..nbytes], 0xff);
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

    // test ensureTotalCapacity with a 0 parameter
    try reset_map.ensureTotalCapacity(0);

    try reset_map.putNoClobber(0, 11);
    try reset_map.putNoClobber(1, 22);
    try reset_map.putNoClobber(2, 33);

    const keys = [_]i32{
        0, 2, 1,
    };

    const values = [_]i32{
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
        buffer[@as(usize, @intCast(entry.key_ptr.*))] = entry.value_ptr.*;
    }
    try testing.expect(count == 3);
    try testing.expect(it.next() == null);

    for (buffer, 0..) |_, i| {
        try testing.expect(buffer[@as(usize, @intCast(keys[i]))] == values[i]);
    }

    it.reset();
    count = 0;
    while (it.next()) |entry| {
        buffer[@as(usize, @intCast(entry.key_ptr.*))] = entry.value_ptr.*;
        count += 1;
        if (count >= 2) break;
    }

    for (buffer[0..2], 0..) |_, i| {
        try testing.expect(buffer[@as(usize, @intCast(keys[i]))] == values[i]);
    }

    it.reset();
    const entry = it.next().?;
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

test "ensure capacity leak" {
    try testing.checkAllAllocationFailures(std.testing.allocator, struct {
        pub fn f(allocator: Allocator) !void {
            var map = AutoArrayHashMap(i32, i32).init(allocator);
            defer map.deinit();

            var i: i32 = 0;
            // put more than `linear_scan_max` in so index_header gets allocated.
            while (i <= 20) : (i += 1) try map.put(i, i);
        }
    }.f, .{});
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
    const num_entries = 200;
    var i: i32 = 0;
    while (i < num_entries) : (i += 1)
        try testing.expect((try map.fetchPut(i, i * 10)) == null);

    try testing.expect(map.unmanaged.index_header != null);
    try testing.expect(map.count() == num_entries);

    // Test `shrinkRetainingCapacity`.
    map.shrinkRetainingCapacity(17);
    try testing.expect(map.count() == 17);
    try testing.expect(map.capacity() >= num_entries);
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

test "pop()" {
    var map = AutoArrayHashMap(i32, i32).init(std.testing.allocator);
    defer map.deinit();

    // Insert just enough entries so that the map expands. Afterwards,
    // pop all entries out of the map.

    var i: i32 = 0;
    while (i < 9) : (i += 1) {
        try testing.expect((try map.fetchPut(i, i)) == null);
    }

    while (map.pop()) |pop| {
        try testing.expect(pop.key == i - 1 and pop.value == i - 1);
        i -= 1;
    }

    try testing.expect(map.count() == 0);
}

test "reIndex" {
    var map = ArrayHashMap(i32, i32, AutoContext(i32), true).init(std.testing.allocator);
    defer map.deinit();

    // Populate via the API.
    const num_indexed_entries = 200;
    var i: i32 = 0;
    while (i < num_indexed_entries) : (i += 1)
        try testing.expect((try map.fetchPut(i, i * 10)) == null);

    // Make sure we allocated an index header.
    try testing.expect(map.unmanaged.index_header != null);

    // Now write to the arrays directly.
    const num_unindexed_entries = 20;
    try map.unmanaged.entries.resize(std.testing.allocator, num_indexed_entries + num_unindexed_entries);
    for (map.keys()[num_indexed_entries..], map.values()[num_indexed_entries..], num_indexed_entries..) |*key, *value, j| {
        key.* = @intCast(j);
        value.* = @intCast(j * 10);
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
    try testing.expect(std.meta.fieldInfo(HasCheapEql.Data, .hash).type == void);
    try testing.expect(std.meta.fieldInfo(HasExpensiveEql.Data, .hash).type != void);

    const HasCheapEqlUn = AutoArrayHashMapUnmanaged(i32, i32);
    const HasExpensiveEqlUn = AutoArrayHashMapUnmanaged([32]i32, i32);
    try testing.expect(std.meta.fieldInfo(HasCheapEqlUn.Data, .hash).type == void);
    try testing.expect(std.meta.fieldInfo(HasExpensiveEqlUn.Data, .hash).type != void);
}

test "sort" {
    var map = AutoArrayHashMap(i32, i32).init(std.testing.allocator);
    defer map.deinit();

    for ([_]i32{ 8, 3, 12, 10, 2, 4, 9, 5, 6, 13, 14, 15, 16, 1, 11, 17, 7 }) |x| {
        try map.put(x, x * 3);
    }

    const C = struct {
        keys: []i32,

        pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
            return ctx.keys[a_index] < ctx.keys[b_index];
        }
    };

    map.sort(C{ .keys = map.keys() });

    var x: i32 = 1;
    for (map.keys(), 0..) |key, i| {
        try testing.expect(key == x);
        try testing.expect(map.values()[i] == x * 3);
        x += 1;
    }
}

test "0 sized key" {
    var map = AutoArrayHashMap(u0, i32).init(std.testing.allocator);
    defer map.deinit();

    try testing.expectEqual(map.get(0), null);

    try map.put(0, 5);
    try testing.expectEqual(map.get(0), 5);

    try map.put(0, 10);
    try testing.expectEqual(map.get(0), 10);

    try testing.expectEqual(map.swapRemove(0), true);
    try testing.expectEqual(map.get(0), null);
}

test "0 sized key and 0 sized value" {
    var map = AutoArrayHashMap(u0, u0).init(std.testing.allocator);
    defer map.deinit();

    try testing.expectEqual(map.get(0), null);

    try map.put(0, 0);
    try testing.expectEqual(map.get(0), 0);

    try testing.expectEqual(map.swapRemove(0), true);
    try testing.expectEqual(map.get(0), null);
}

test "setKey" {
    const gpa = std.testing.allocator;

    var map: AutoArrayHashMapUnmanaged(i32, i32) = .empty;
    defer map.deinit(gpa);

    try map.put(gpa, 12, 34);
    try map.put(gpa, 56, 78);

    try map.setKey(gpa, 0, 42);
    try testing.expectEqual(2, map.count());
    try testing.expectEqual(false, map.contains(12));
    try testing.expectEqual(34, map.get(42));
    try testing.expectEqual(78, map.get(56));
}

pub fn getHashPtrAddrFn(comptime K: type, comptime Context: type) (fn (Context, K) u32) {
    return struct {
        fn hash(ctx: Context, key: K) u32 {
            _ = ctx;
            return getAutoHashFn(usize, void)({}, @intFromPtr(key));
        }
    }.hash;
}

pub fn getTrivialEqlFn(comptime K: type, comptime Context: type) (fn (Context, K, K) bool) {
    return struct {
        fn eql(ctx: Context, a: K, b: K) bool {
            _ = ctx;
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
            _ = ctx;
            if (std.meta.hasUniqueRepresentation(K)) {
                return @truncate(Wyhash.hash(0, std.mem.asBytes(&key)));
            } else {
                var hasher = Wyhash.init(0);
                autoHash(&hasher, key);
                return @truncate(hasher.final());
            }
        }
    }.hash;
}

pub fn getAutoEqlFn(comptime K: type, comptime Context: type) (fn (Context, K, K, usize) bool) {
    return struct {
        fn eql(ctx: Context, a: K, b: K, b_index: usize) bool {
            _ = b_index;
            _ = ctx;
            return std.meta.eql(a, b);
        }
    }.eql;
}

pub fn autoEqlIsCheap(comptime K: type) bool {
    return switch (@typeInfo(K)) {
        .bool,
        .int,
        .float,
        .pointer,
        .comptime_float,
        .comptime_int,
        .@"enum",
        .@"fn",
        .error_set,
        .@"anyframe",
        .enum_literal,
        => true,
        else => false,
    };
}

pub fn getAutoHashStratFn(comptime K: type, comptime Context: type, comptime strategy: std.hash.Strategy) (fn (Context, K) u32) {
    return struct {
        fn hash(ctx: Context, key: K) u32 {
            _ = ctx;
            var hasher = Wyhash.init(0);
            std.hash.autoHashStrat(&hasher, key, strategy);
            return @as(u32, @truncate(hasher.final()));
        }
    }.hash;
}
