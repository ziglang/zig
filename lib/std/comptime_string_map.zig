const std = @import("std.zig");
const mem = std.mem;

/// Comptime string map optimized for small sets of disparate string keys.
/// Works by separating the keys by length at comptime and only checking strings of
/// equal length at runtime.
///
/// `kvs_list` expects a list of `struct { []const u8, V }` (key-value pair) tuples.
/// You can pass `struct { []const u8 }` (only keys) tuples if `V` is `void`.
pub fn ComptimeStringMap(
    comptime V: type,
    comptime kvs_list: anytype,
) type {
    return ComptimeStringMapWithEql(V, kvs_list, defaultEql);
}

/// Like `std.mem.eql`, but takes advantage of the fact that the lengths
/// of `a` and `b` are known to be equal.
pub fn defaultEql(a: []const u8, b: []const u8) bool {
    if (a.ptr == b.ptr) return true;
    for (a, b) |a_elem, b_elem| {
        if (a_elem != b_elem) return false;
    }
    return true;
}

/// Like `std.ascii.eqlIgnoreCase` but takes advantage of the fact that
/// the lengths of `a` and `b` are known to be equal.
pub fn eqlAsciiIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.ptr == b.ptr) return true;
    for (a, b) |a_c, b_c| {
        if (std.ascii.toLower(a_c) != std.ascii.toLower(b_c)) return false;
    }
    return true;
}

/// ComptimeStringMap, but accepts an equality function (`eql`).
/// The `eql` function is only called to determine the equality
/// of equal length strings. Any strings that are not equal length
/// are never compared using the `eql` function.
pub fn ComptimeStringMapWithEql(
    comptime V: type,
    comptime kvs_list: anytype,
    comptime eql: fn (a: []const u8, b: []const u8) bool,
) type {
    const empty_list = kvs_list.len == 0;
    const precomputed = blk: {
        @setEvalBranchQuota(1500);
        const KV = struct {
            key: []const u8,
            value: V,
        };
        if (empty_list)
            break :blk .{};
        var sorted_kvs: [kvs_list.len]KV = undefined;
        for (kvs_list, 0..) |kv, i| {
            if (V != void) {
                sorted_kvs[i] = .{ .key = kv.@"0", .value = kv.@"1" };
            } else {
                sorted_kvs[i] = .{ .key = kv.@"0", .value = {} };
            }
        }

        const SortContext = struct {
            kvs: []KV,

            pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
                return ctx.kvs[a].key.len < ctx.kvs[b].key.len;
            }

            pub fn swap(ctx: @This(), a: usize, b: usize) void {
                return std.mem.swap(KV, &ctx.kvs[a], &ctx.kvs[b]);
            }
        };
        mem.sortUnstableContext(0, sorted_kvs.len, SortContext{ .kvs = &sorted_kvs });

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
        /// Array of `struct { key: []const u8, value: V }` where `value` is `void{}` if `V` is `void`.
        /// Sorted by `key` length.
        pub const kvs = precomputed.sorted_kvs;

        /// Checks if the map has a value for the key.
        pub fn has(str: []const u8) bool {
            return get(str) != null;
        }

        /// Returns the value for the key if any, else null.
        pub fn get(str: []const u8) ?V {
            if (empty_list)
                return null;

            return precomputed.sorted_kvs[getIndex(str) orelse return null].value;
        }

        pub fn getIndex(str: []const u8) ?usize {
            if (empty_list)
                return null;

            if (str.len < precomputed.min_len or str.len > precomputed.max_len)
                return null;

            var i = precomputed.len_indexes[str.len];
            while (true) {
                const kv = precomputed.sorted_kvs[i];
                if (kv.key.len != str.len)
                    return null;
                if (eql(kv.key, str))
                    return i;
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

    // Default comparison is case sensitive
    try std.testing.expect(null == map.get("NOTHING"));
}

test "ComptimeStringMap array of structs" {
    const KV = struct { []const u8, TestEnum };
    const map = ComptimeStringMap(TestEnum, [_]KV{
        .{ "these", .D },
        .{ "have", .A },
        .{ "nothing", .B },
        .{ "incommon", .C },
        .{ "samelen", .E },
    });

    try testMap(map);
}

test "ComptimeStringMap slice of structs" {
    const KV = struct { []const u8, TestEnum };
    const slice: []const KV = &[_]KV{
        .{ "these", .D },
        .{ "have", .A },
        .{ "nothing", .B },
        .{ "incommon", .C },
        .{ "samelen", .E },
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

    try std.testing.expect(null == map.get(""));
    try std.testing.expect(null == map.get("averylongstringthathasnomatches"));
}

test "ComptimeStringMap void value type, slice of structs" {
    const KV = struct { []const u8 };
    const slice: []const KV = &[_]KV{
        .{"these"},
        .{"have"},
        .{"nothing"},
        .{"incommon"},
        .{"samelen"},
    };
    const map = ComptimeStringMap(void, slice);

    try testSet(map);

    // Default comparison is case sensitive
    try std.testing.expect(null == map.get("NOTHING"));
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

    try std.testing.expect(null == map.get(""));
    try std.testing.expect(null == map.get("averylongstringthathasnomatches"));
}

test "ComptimeStringMapWithEql" {
    const map = ComptimeStringMapWithEql(TestEnum, .{
        .{ "these", .D },
        .{ "have", .A },
        .{ "nothing", .B },
        .{ "incommon", .C },
        .{ "samelen", .E },
    }, eqlAsciiIgnoreCase);

    try testMap(map);
    try std.testing.expectEqual(TestEnum.A, map.get("HAVE").?);
    try std.testing.expectEqual(TestEnum.E, map.get("SameLen").?);
    try std.testing.expect(null == map.get("SameLength"));

    try std.testing.expect(map.has("ThESe"));
}

test "ComptimeStringMap empty" {
    const m1 = ComptimeStringMap(usize, .{});
    try std.testing.expect(null == m1.get("anything"));

    const m2 = ComptimeStringMapWithEql(usize, .{}, eqlAsciiIgnoreCase);
    try std.testing.expect(null == m2.get("anything"));
}

test "ComptimeStringMap redundant entries" {
    const map = ComptimeStringMap(TestEnum, .{
        .{ "redundant", .D },
        .{ "theNeedle", .A },
        .{ "redundant", .B },
        .{ "re" ++ "dundant", .C },
        .{ "redun" ++ "dant", .E },
    });

    // No promises about which one you get:
    try std.testing.expect(null != map.get("redundant"));

    // Default map is not case sensitive:
    try std.testing.expect(null == map.get("REDUNDANT"));

    try std.testing.expectEqual(TestEnum.A, map.get("theNeedle").?);
}

test "ComptimeStringMap redundant insensitive" {
    const map = ComptimeStringMapWithEql(TestEnum, .{
        .{ "redundant", .D },
        .{ "theNeedle", .A },
        .{ "redundanT", .B },
        .{ "RE" ++ "dundant", .C },
        .{ "redun" ++ "DANT", .E },
    }, eqlAsciiIgnoreCase);

    // No promises about which result you'll get ...
    try std.testing.expect(null != map.get("REDUNDANT"));
    try std.testing.expect(null != map.get("ReDuNdAnT"));

    try std.testing.expectEqual(TestEnum.A, map.get("theNeedle").?);
}

test "ComptimeStringMap comptime-only value" {
    const map = std.ComptimeStringMap(type, .{
        .{ "a", struct {
            pub const foo = 1;
        } },
        .{ "b", struct {
            pub const foo = 2;
        } },
        .{ "c", struct {
            pub const foo = 3;
        } },
    });

    try std.testing.expect(map.get("a").?.foo == 1);
    try std.testing.expect(map.get("b").?.foo == 2);
    try std.testing.expect(map.get("c").?.foo == 3);
    try std.testing.expect(map.get("d") == null);
}
