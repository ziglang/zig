// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const StringHashMap = std.StringHashMap;
const mem = std.mem;
const Allocator = mem.Allocator;
const testing = std.testing;

/// BufMap copies keys and values before they go into the map, and
/// frees them when they get removed.
pub const BufMap = struct {
    hash_map: BufMapHashMap,

    const BufMapHashMap = StringHashMap([]const u8);

    /// Create a BufMap backed by a specific allocator.
    /// That allocator will be used for both backing allocations
    /// and string deduplication.
    pub fn init(allocator: *Allocator) BufMap {
        var self = BufMap{ .hash_map = BufMapHashMap.init(allocator) };
        return self;
    }

    /// Free the backing storage of the map, as well as all
    /// of the stored keys and values.
    pub fn deinit(self: *BufMap) void {
        var it = self.hash_map.iterator();
        while (it.next()) |entry| {
            self.free(entry.key_ptr.*);
            self.free(entry.value_ptr.*);
        }

        self.hash_map.deinit();
    }

    /// Same as `put` but the key and value become owned by the BufMap rather
    /// than being copied.
    /// If `putMove` fails, the ownership of key and value does not transfer.
    pub fn putMove(self: *BufMap, key: []u8, value: []u8) !void {
        const get_or_put = try self.hash_map.getOrPut(key);
        if (get_or_put.found_existing) {
            self.free(get_or_put.key_ptr.*);
            self.free(get_or_put.value_ptr.*);
            get_or_put.key_ptr.* = key;
        }
        get_or_put.value_ptr.* = value;
    }

    /// `key` and `value` are copied into the BufMap.
    pub fn put(self: *BufMap, key: []const u8, value: []const u8) !void {
        const value_copy = try self.copy(value);
        errdefer self.free(value_copy);
        const get_or_put = try self.hash_map.getOrPut(key);
        if (get_or_put.found_existing) {
            self.free(get_or_put.value_ptr.*);
        } else {
            get_or_put.key_ptr.* = self.copy(key) catch |err| {
                _ = self.hash_map.remove(key);
                return err;
            };
        }
        get_or_put.value_ptr.* = value_copy;
    }

    /// Find the address of the value associated with a key.
    /// The returned pointer is invalidated if the map resizes.
    pub fn getPtr(self: BufMap, key: []const u8) ?*[]const u8 {
        return self.hash_map.getPtr(key);
    }

    /// Return the map's copy of the value associated with
    /// a key.  The returned string is invalidated if this
    /// key is removed from the map.
    pub fn get(self: BufMap, key: []const u8) ?[]const u8 {
        return self.hash_map.get(key);
    }

    /// Removes the item from the map and frees its value.
    /// This invalidates the value returned by get() for this key.
    pub fn remove(self: *BufMap, key: []const u8) void {
        const kv = self.hash_map.fetchRemove(key) orelse return;
        self.free(kv.key);
        self.free(kv.value);
    }

    /// Returns the number of KV pairs stored in the map.
    pub fn count(self: BufMap) usize {
        return self.hash_map.count();
    }

    /// Returns an iterator over entries in the map.
    pub fn iterator(self: *const BufMap) BufMapHashMap.Iterator {
        return self.hash_map.iterator();
    }

    fn free(self: BufMap, value: []const u8) void {
        self.hash_map.allocator.free(value);
    }

    fn copy(self: BufMap, value: []const u8) ![]u8 {
        return self.hash_map.allocator.dupe(u8, value);
    }
};

test "BufMap" {
    const allocator = std.testing.allocator;
    var bufmap = BufMap.init(allocator);
    defer bufmap.deinit();

    try bufmap.put("x", "1");
    try testing.expect(mem.eql(u8, bufmap.get("x").?, "1"));
    try testing.expect(1 == bufmap.count());

    try bufmap.put("x", "2");
    try testing.expect(mem.eql(u8, bufmap.get("x").?, "2"));
    try testing.expect(1 == bufmap.count());

    try bufmap.put("x", "3");
    try testing.expect(mem.eql(u8, bufmap.get("x").?, "3"));
    try testing.expect(1 == bufmap.count());

    bufmap.remove("x");
    try testing.expect(0 == bufmap.count());

    try bufmap.putMove(try allocator.dupe(u8, "k"), try allocator.dupe(u8, "v1"));
    try bufmap.putMove(try allocator.dupe(u8, "k"), try allocator.dupe(u8, "v2"));
}
