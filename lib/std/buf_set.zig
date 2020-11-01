// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const StringHashSet = std.StringHashSet;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;
const testing = std.testing;

pub const BufSet = struct {
    hash_set: StringHashSet,

    pub fn init(a: *Allocator) BufSet {
        var self = BufSet{ .hash_set = StringHashSet.init(a) };
        return self;
    }

    pub fn deinit(self: *BufSet) void {
        var it = self.hash_set.iterator();
        while (it.next()) |value| {
            self.free(value);
        }
        self.hash_set.deinit();
        self.* = undefined;
    }

    pub fn put(self: *BufSet, value: []const u8) !void {
        if (!self.hash_set.exists(value)) {
            const value_copy = try self.copy(value);
            errdefer self.free(value_copy);
            _ = try self.hash_set.put(value_copy);
        }
    }

    pub fn exists(self: BufSet, value: []const u8) bool {
        return self.hash_set.exists(value);
    }

    pub fn delete(self: *BufSet, value: []const u8) void {
        const entry = self.hash_set.delete(value) orelse return;
        self.free(entry);
    }

    pub fn count(self: *const BufSet) usize {
        return self.hash_set.count();
    }

    pub fn iterator(self: *const BufSet) StringHashSet.Iterator {
        return self.hash_set.iterator();
    }

    pub fn allocator(self: *const BufSet) *Allocator {
        return self.hash_set.allocator;
    }

    fn free(self: *const BufSet, value: []const u8) void {
        self.hash_set.allocator.free(value);
    }

    fn copy(self: *const BufSet, value: []const u8) ![]const u8 {
        const result = try self.hash_set.allocator.alloc(u8, value.len);
        mem.copy(u8, result, value);
        return result;
    }
};

test "BufSet" {
    var bufset = BufSet.init(std.testing.allocator);
    defer bufset.deinit();

    try bufset.put("x");
    testing.expect(bufset.count() == 1);
    bufset.delete("x");
    testing.expect(bufset.count() == 0);

    try bufset.put("x");
    try bufset.put("y");
    try bufset.put("z");
}
