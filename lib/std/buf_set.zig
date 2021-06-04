// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
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
    pub fn init(a: *Allocator) BufSet {
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
    pub fn allocator(self: *const BufSet) *Allocator {
        return self.hash_map.allocator;
    }

    fn free(self: *const BufSet, value: []const u8) void {
        self.hash_map.allocator.free(value);
    }

    fn copy(self: *const BufSet, value: []const u8) ![]const u8 {
        const result = try self.hash_map.allocator.alloc(u8, value.len);
        mem.copy(u8, result, value);
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
