const std = @import("std.zig");
const StringHashMap = std.StringHashMap;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;
const testing = std.testing;

/// A BufSet is a set of strings.  The BufSet duplicates
/// strings internally, and never takes ownership of strings
/// which are passed to it.
pub const BufSet = struct {
    hash_map: BufSetHashMap,

    const BufSetHashMap = StringHashMap(void);
    pub const Iterator = BufSetHashMap.KeyIterator;

    /// Create a BufSet using an allocator.  The allocator will
    /// be used internally for both backing allocations and
    /// string duplication.
    pub fn init(a: Allocator) BufSet {
        var self = BufSet{ .hash_map = BufSetHashMap.init(a) };
        return self;
    }

    /// Free a BufSet along with all stored keys.
    pub fn deinit(self: *BufSet) void {
        var it = self.hash_map.keyIterator();
        while (it.next()) |key_ptr| {
            self.free(key_ptr.*);
        }
        self.hash_map.deinit();
        self.* = undefined;
    }

    /// Insert an item into the BufSet.  The item will be
    /// copied, so the caller may delete or reuse the
    /// passed string immediately.
    pub fn insert(self: *BufSet, value: []const u8) !void {
        const gop = try self.hash_map.getOrPut(value);
        if (!gop.found_existing) {
            gop.key_ptr.* = self.copy(value) catch |err| {
                _ = self.hash_map.remove(value);
                return err;
            };
        }
    }

    /// Check if the set contains an item matching the passed string
    pub fn contains(self: BufSet, value: []const u8) bool {
        return self.hash_map.contains(value);
    }

    /// Remove an item from the set.
    pub fn remove(self: *BufSet, value: []const u8) void {
        const kv = self.hash_map.fetchRemove(value) orelse return;
        self.free(kv.key);
    }

    /// Returns the number of items stored in the set
    pub fn count(self: *const BufSet) usize {
        return self.hash_map.count();
    }

    /// Returns an iterator over the items stored in the set.
    /// Iteration order is arbitrary.
    pub fn iterator(self: *const BufSet) Iterator {
        return self.hash_map.keyIterator();
    }

    /// Get the allocator used by this set
    pub fn allocator(self: *const BufSet) Allocator {
        return self.hash_map.allocator;
    }

    /// Creates a copy of this BufSet, using a specified allocator.
    pub fn cloneWithAllocator(
        self: *const BufSet,
        new_allocator: Allocator,
    ) Allocator.Error!BufSet {
        var cloned_hashmap = try self.hash_map.cloneWithAllocator(new_allocator);
        var cloned = BufSet{ .hash_map = cloned_hashmap };
        var it = cloned.hash_map.keyIterator();
        while (it.next()) |key_ptr| {
            key_ptr.* = try cloned.copy(key_ptr.*);
        }

        return cloned;
    }

    /// Creates a copy of this BufSet, using the same allocator.
    pub fn clone(self: *const BufSet) Allocator.Error!BufSet {
        return self.cloneWithAllocator(self.allocator());
    }

    fn free(self: *const BufSet, value: []const u8) void {
        self.hash_map.allocator.free(value);
    }

    fn copy(self: *const BufSet, value: []const u8) ![]const u8 {
        const result = try self.hash_map.allocator.alloc(u8, value.len);
        @memcpy(result, value);
        return result;
    }
};

test "BufSet" {
    var bufset = BufSet.init(std.testing.allocator);
    defer bufset.deinit();

    try bufset.insert("x");
    try testing.expect(bufset.count() == 1);
    bufset.remove("x");
    try testing.expect(bufset.count() == 0);

    try bufset.insert("x");
    try bufset.insert("y");
    try bufset.insert("z");
}

test "BufSet clone" {
    var original = BufSet.init(testing.allocator);
    defer original.deinit();
    try original.insert("x");

    var cloned = try original.clone();
    defer cloned.deinit();
    cloned.remove("x");
    try testing.expect(original.count() == 1);
    try testing.expect(cloned.count() == 0);

    try testing.expectError(
        error.OutOfMemory,
        original.cloneWithAllocator(testing.failing_allocator),
    );
}

test "BufSet.clone with arena" {
    var allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var buf = BufSet.init(allocator);
    defer buf.deinit();
    try buf.insert("member1");
    try buf.insert("member2");

    _ = try buf.cloneWithAllocator(arena.allocator());
}
