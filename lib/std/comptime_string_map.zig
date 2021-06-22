// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const mem = std.mem;

/// Comptime string map optimized for small sets of disparate string keys.
/// Works by separating the keys by length at comptime and only checking strings of
/// equal length at runtime.
///
/// `kvs` expects a list literal containing list literals or an array/slice of structs
/// where `.@"0"` is the `[]const u8` key and `.@"1"` is the associated value of type `V`.
/// TODO: https://github.com/ziglang/zig/issues/4335
pub fn ComptimeStringMap(comptime V: type, comptime kvs: anytype) type {
    const precomputed = comptime blk: {
        @setEvalBranchQuota(2000);
        const KV = struct {
            key: []const u8,
            value: V,
        };
        var sorted_kvs: [kvs.len]KV = undefined;
        const lenAsc = (struct {
            fn lenAsc(context: void, a: KV, b: KV) bool {
                _ = context;
                return a.key.len < b.key.len;
            }
        }).lenAsc;
        for (kvs) |kv, i| {
            if (V != void) {
                sorted_kvs[i] = .{ .key = kv.@"0", .value = kv.@"1" };
            } else {
                sorted_kvs[i] = .{ .key = kv.@"0", .value = {} };
            }
        }
        std.sort.sort(KV, &sorted_kvs, {}, lenAsc);
        const min_len = sorted_kvs[0].key.len;
        const max_len = sorted_kvs[sorted_kvs.len - 1].key.len;
        var len_indexes: [max_len + 1]usize = undefined;
        var len: usize = 0;
        var i: usize = 0;
        while (len <= max_len) : (len += 1) {
            // find the first keyword len == len
            while (len > sorted_kvs[i].key.len) {
                i += 1;
            }
            len_indexes[len] = i;
        }
        break :blk .{
            .min_len = min_len,
            .max_len = max_len,
            .sorted_kvs = sorted_kvs,
            .len_indexes = len_indexes,
        };
    };

    return struct {
        pub fn has(str: []const u8) bool {
            return get(str) != null;
        }

        pub fn get(str: []const u8) ?V {
            if (str.len < precomputed.min_len or str.len > precomputed.max_len)
                return null;

            var i = precomputed.len_indexes[str.len];
            while (true) {
                const kv = precomputed.sorted_kvs[i];
                if (kv.key.len != str.len)
                    return null;
                if (mem.eql(u8, kv.key, str))
                    return kv.value;
                i += 1;
                if (i >= precomputed.sorted_kvs.len)
                    return null;
            }
        }
    };
}

const TestEnum = enum {
    A,
    B,
    C,
    D,
    E,
};

test "ComptimeStringMap list literal of list literals" {
    const map = ComptimeStringMap(TestEnum, .{
        .{ "these", .D },
        .{ "have", .A },
        .{ "nothing", .B },
        .{ "incommon", .C },
        .{ "samelen", .E },
    });

    try testMap(map);
}

test "ComptimeStringMap array of structs" {
    const KV = struct {
        @"0": []const u8,
        @"1": TestEnum,
    };
    const map = ComptimeStringMap(TestEnum, [_]KV{
        .{ .@"0" = "these", .@"1" = .D },
        .{ .@"0" = "have", .@"1" = .A },
        .{ .@"0" = "nothing", .@"1" = .B },
        .{ .@"0" = "incommon", .@"1" = .C },
        .{ .@"0" = "samelen", .@"1" = .E },
    });

    try testMap(map);
}

test "ComptimeStringMap slice of structs" {
    const KV = struct {
        @"0": []const u8,
        @"1": TestEnum,
    };
    const slice: []const KV = &[_]KV{
        .{ .@"0" = "these", .@"1" = .D },
        .{ .@"0" = "have", .@"1" = .A },
        .{ .@"0" = "nothing", .@"1" = .B },
        .{ .@"0" = "incommon", .@"1" = .C },
        .{ .@"0" = "samelen", .@"1" = .E },
    };
    const map = ComptimeStringMap(TestEnum, slice);

    try testMap(map);
}

fn testMap(comptime map: anytype) !void {
    try std.testing.expectEqual(TestEnum.A, map.get("have").?);
    try std.testing.expectEqual(TestEnum.B, map.get("nothing").?);
    try std.testing.expect(null == map.get("missing"));
    try std.testing.expectEqual(TestEnum.D, map.get("these").?);
    try std.testing.expectEqual(TestEnum.E, map.get("samelen").?);

    try std.testing.expect(!map.has("missing"));
    try std.testing.expect(map.has("these"));
}

test "ComptimeStringMap void value type, slice of structs" {
    const KV = struct {
        @"0": []const u8,
    };
    const slice: []const KV = &[_]KV{
        .{ .@"0" = "these" },
        .{ .@"0" = "have" },
        .{ .@"0" = "nothing" },
        .{ .@"0" = "incommon" },
        .{ .@"0" = "samelen" },
    };
    const map = ComptimeStringMap(void, slice);

    try testSet(map);
}

test "ComptimeStringMap void value type, list literal of list literals" {
    const map = ComptimeStringMap(void, .{
        .{"these"},
        .{"have"},
        .{"nothing"},
        .{"incommon"},
        .{"samelen"},
    });

    try testSet(map);
}

fn testSet(comptime map: anytype) !void {
    try std.testing.expectEqual({}, map.get("have").?);
    try std.testing.expectEqual({}, map.get("nothing").?);
    try std.testing.expect(null == map.get("missing"));
    try std.testing.expectEqual({}, map.get("these").?);
    try std.testing.expectEqual({}, map.get("samelen").?);

    try std.testing.expect(!map.has("missing"));
    try std.testing.expect(map.has("these"));
}
