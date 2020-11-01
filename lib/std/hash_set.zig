// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const HashMapUnmanaged = std.HashMapUnmanaged;
const hash_map = std.hash_map;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;
const testing = std.testing;

pub fn AutoHashSet(comptime T: type) type {
    return HashSet(
        T,
        hash_map.getAutoHashFn(T),
        hash_map.getAutoEqlFn(T),
        hash_map.DefaultMaxLoadPercentage,
    );
}

pub fn AutoHashSetUnmanaged(comptime T: type) type {
    return HashSetUnmanaged(
        T,
        hash_map.getAutoHashFn(T),
        hash_map.getAutoEqlFn(T),
        hash_map.DefaultMaxLoadPercentage,
    );
}

pub const StringHashSet = HashSet(
    []const u8,
    hash_map.hashString,
    hash_map.eqlString,
    hash_map.DefaultMaxLoadPercentage,
);

pub const StringHashSetUnmanaged = HashSetUnmanaged(
    []const u8,
    hash_map.hashString,
    hash_map.eqlString,
    hash_map.DefaultMaxLoadPercentage,
);

pub fn HashSet(
    comptime T: type,
    comptime hashFn: fn (key: T) u64,
    comptime eqlFn: fn (a: T, b: T) bool,
    comptime MaxLoadPercentage: u64,
) type {
    return struct {
        const Self = @This();

        unmanaged: Unmanaged,
        allocator: *Allocator,

        const Unmanaged = HashSetUnmanaged(T, hashFn, eqlFn, MaxLoadPercentage);
        pub const Iterator = Unmanaged.Iterator;

        pub fn init(allocator: *Allocator) Self {
            return .{ .unmanaged = Unmanaged.init(allocator), .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.unmanaged.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn put(self: *Self, value: T) !void {
            _ = try self.unmanaged.put(self.allocator, value);
        }

        pub fn exists(self: Self, value: T) bool {
            return self.unmanaged.exists(value);
        }

        pub fn delete(self: *Self, value: T) ?T {
            return self.unmanaged.delete(value);
        }

        pub fn count(self: *const Self) usize {
            return self.unmanaged.count();
        }

        pub fn iterator(self: *const Self) Iterator {
            return self.unmanaged.iterator();
        }
    };
}

pub fn HashSetUnmanaged(
    comptime T: type,
    comptime hashFn: fn (key: T) u64,
    comptime eqlFn: fn (a: T, b: T) bool,
    comptime MaxLoadPercentage: u64,
) type {
    return struct {
        const Self = @This();

        hash_map: SetHashMap,

        const SetHashMap = HashMapUnmanaged(T, void, hashFn, eqlFn, MaxLoadPercentage);

        pub fn init(allocator: *Allocator) Self {
            return .{ .hash_map = .{} };
        }

        pub fn deinit(self: *Self, allocator: *Allocator) void {
            self.hash_map.deinit(allocator);
            self.* = undefined;
        }

        pub fn put(self: *Self, allocator: *Allocator, value: T) !void {
            _ = try self.hash_map.put(allocator, value, {});
        }

        pub fn exists(self: Self, value: T) bool {
            return self.hash_map.get(value) != null;
        }

        pub fn delete(self: *Self, value: T) ?T {
            if (self.hash_map.remove(value)) |entry| return entry.key;
            return null;
        }

        pub fn count(self: *const Self) usize {
            return self.hash_map.count();
        }

        pub fn iterator(self: *const Self) Iterator {
            return .{ .iterator = self.hash_map.iterator() };
        }

        const Iterator = struct {
            iterator: SetHashMap.Iterator,

            pub fn next(it: *Iterator) ?T {
                if (it.iterator.next()) |entry| return entry.key;
                return null;
            }
        };
    };
}

test "HashSet" {
    var str_hash_set = StringHashSet.init(std.testing.allocator);
    defer str_hash_set.deinit();

    try str_hash_set.put("x");
    testing.expectEqual(@as(usize, 1), str_hash_set.count());
    _ = str_hash_set.delete("x");
    testing.expectEqual(@as(usize, 0), str_hash_set.count());

    try str_hash_set.put("x");
    try str_hash_set.put("y");
    try str_hash_set.put("z");
    try str_hash_set.put("x");

    testing.expectEqual(@as(usize, 3), str_hash_set.count());
    testing.expect(str_hash_set.exists("x"));
    testing.expect(str_hash_set.exists("y"));
    testing.expect(str_hash_set.exists("z"));
    testing.expect(!str_hash_set.exists("a"));

    var int_hash_set = AutoHashSet(u8).init(std.testing.allocator);
    defer int_hash_set.deinit();

    try int_hash_set.put(1);
    testing.expectEqual(@as(usize, 1), int_hash_set.count());
    _ = int_hash_set.delete(1);
    testing.expectEqual(@as(usize, 0), int_hash_set.count());

    try int_hash_set.put(1);
    try int_hash_set.put(2);
    try int_hash_set.put(3);
    try int_hash_set.put(1);

    testing.expectEqual(@as(usize, 3), int_hash_set.count());
    testing.expect(int_hash_set.exists(1));
    testing.expect(int_hash_set.exists(2));
    testing.expect(int_hash_set.exists(3));
    testing.expect(!int_hash_set.exists(4));

    var i: usize = 0;
    var iterator = int_hash_set.iterator();
    while (iterator.next()) |v| {
        testing.expect(v == 1 or v == 2 or v == 3);
        i += 1;
    }
    testing.expectEqual(@as(usize, 3), i);
}
