const std = @import("std.zig");
const assert = std.debug.assert;

/// Static mapping between strings and values (of type V)
/// All key/value pairs must be known at compile-time
pub fn StaticStringMap(comptime V: type) type {
    return StaticStringMapWithEql(V, staticEql);
}

/// Same as StaticStringMap, except keys are compared case-insensitively.
pub fn StaticStringMapIgnoreCaseAscii(comptime V: type) type {
    return StaticStringMapWithEql(V, ignoreCaseStaticEql);
}

/// String to V mapping for comptime-known key/value pairs
/// Branches on the key length, then compares each string
fn StaticStringMapWithEql(comptime V: type, comptime eql: anytype) type {
    return struct {
        const Kv = struct { key: []const u8, value: V };
        kvs: []const Kv,

        /// Initializes the map at comptime with a list of key/value pairs
        /// The "value" in a key/value pair is optional if type V is void
        pub inline fn initComptime(comptime kvs_list: anytype) @This() {
            const list: [kvs_list.len]Kv = comptime blk: {
                var list: [kvs_list.len]Kv = undefined;
                for (&list, kvs_list) |*kv, item| {
                    kv.* = .{
                        .key = item[0],
                        .value = if (V == void) {} else item[1],
                    };
                }
                break :blk list;
            };
            return comptime .{ .kvs = &list };
        }

        /// Returns the list of all the keys in the map.
        pub fn keys(comptime self: @This()) []const []const u8 {
            const list = comptime blk: {
                var list: [self.kvs.len][]const u8 = undefined;
                for (&list, self.kvs) |*key, kv| {
                    key.* = kv.key;
                }
                break :blk list;
            };
            return &list;
        }

        /// Returns the list of all the values in the map.
        pub fn values(comptime self: @This()) []const V {
            const list = comptime blk: {
                var list: [self.kvs.len]V = undefined;
                for (&list, self.kvs) |*value, kv| {
                    value.* = kv.value;
                }
                break :blk list;
            };
            return &list;
        }

        /// Checks if the map contains the key.
        pub fn has(comptime self: @This(), key: []const u8) bool {
            return self.get(key) != null;
        }

        /// Returns the value for the key if any.
        pub fn get(comptime self: @This(), key: []const u8) ?V {
            @setEvalBranchQuota(200 * self.kvs.len * self.kvs.len);
            const kvs_by_len = comptime self.separateLength();

            inline for (kvs_by_len) |kvs| {
                const len = kvs.len;
                if (key.len == len) {
                    inline for (kvs.kvs) |kv| {
                        if (eql(kv.key, key[0..len])) {
                            return kv.value;
                        }
                    }
                }
            }
            return null;
        }

        /// Key / value pairs where the keys have the same length
        const LengthKvs = struct { len: usize, kvs: []const Kv };

        /// Creates a list of kv sets grouped by different key lengths.
        fn separateLength(comptime self: @This()) []const LengthKvs {
            var length_sets: []const LengthKvs = &.{};
            add_length: for (self.kvs, 0..) |check_kv, index| {
                // The key/value pairs with this length will be grouped
                const len = check_kv.key.len;

                // Skip this key/value pair if it has already been grouped
                for (length_sets) |set| {
                    if (set.len == len) {
                        continue :add_length;
                    }
                }

                // Add keys with the same length to the set
                var added_kvs: []const Kv = &.{};
                for (self.kvs[index..]) |add_kv| {
                    if (add_kv.key.len == len) {

                        // Check for redundant keys
                        for (added_kvs) |kv| {
                            if (eql(kv.key, add_kv.key[0..len])) {
                                @compileError(
                                    "redundant key \"" ++ add_kv.key ++ "\"",
                                );
                            }
                        }

                        added_kvs = added_kvs ++ .{add_kv};
                    }
                }

                // Add `added_kvs` to the set of length grouped sets
                const added_set: LengthKvs = .{ .len = len, .kvs = added_kvs };
                length_sets = length_sets ++ .{added_set};
            }
            return length_sets;
        }
    };
}

/// Equality check for a compile-time known string and a runtime-known string.
/// An optimizer can generate similar code, but this code is explicit to ensure
/// we get optimal codegen - specific to each static string's length and value.
fn staticEql(comptime a: []const u8, b: *const [a.len]u8) bool {
    const block_len = std.simd.suggestVectorLength(u8) orelse @sizeOf(usize);
    const Chunk = std.meta.Int(.unsigned, block_len * 8);

    // Compare `block_count` chunks of `block_len` bytes at a time
    const block_count = a.len / block_len;
    for (0..block_count) |idx| {
        const chunk_a: Chunk = @bitCast(a[idx * block_len ..][0..block_len].*);
        const chunk_b: Chunk = @bitCast(b[idx * block_len ..][0..block_len].*);
        if (chunk_a != chunk_b) return false;
    }

    // Compare the remainder `rem_count` bytes of both strings
    const rem_count = a.len % block_len;
    const Rem = std.meta.Int(.unsigned, rem_count * 8);

    const rem_a: Rem = @bitCast(a[block_count * block_len ..][0..rem_count].*);
    const rem_b: Rem = @bitCast(b[block_count * block_len ..][0..rem_count].*);
    return rem_a == rem_b;
}

/// Case-insensitive equality check for equal length comptime & runtime string.
fn ignoreCaseStaticEql(comptime a: []const u8, b: *const [a.len]u8) bool {
    const upper_a = comptime toUpperSimd(a.len, a[0..a.len]);
    const upper_b = toUpperSimd(a.len, b);
    return staticEql(&upper_a, &upper_b);
}

/// Vectorized uppercase transform for a string with a comptime-known length
fn toUpperSimd(comptime len: usize, str: *const [len]u8) [len]u8 {
    const block_len = std.simd.suggestVectorLength(u8) orelse @sizeOf(usize);
    const ChunkBytes = @Vector(block_len, u8);
    const ChunkBools = @Vector(block_len, bool);

    var result: [len]u8 = undefined;

    // Convert `block_count` chunks of `block_len` bytes at a time
    const block_count = len / block_len;
    for (0..block_count) |idx| {
        const offset = idx * block_len;

        // Determine if the chunk is in the range of 'a'...'z'
        const chunk: ChunkBytes = str[offset..][0..block_len].*;
        const min: ChunkBools = chunk >= @as(ChunkBytes, @splat('a'));
        const max: ChunkBools = chunk <= @as(ChunkBytes, @splat('z'));
        const false_chunk: ChunkBools = @splat(false);
        const is_lower = @select(bool, min, max, false_chunk);

        // Mask the lowercase bytes so they are in the range 'A'...'Z'
        const mask: ChunkBytes = @splat(0b1101_1111);
        const uppercased = @select(u8, is_lower, chunk & mask, chunk);
        result[offset..][0..block_len].* = uppercased;
    }

    // Convert the remainder `rem_count` bytes
    const rem_count = len % block_len;
    const RemBytes = @Vector(rem_count, u8);
    const RemBools = @Vector(rem_count, bool);
    const offset = block_count * block_len;

    // Determine if the remainder is in the range of 'a'...'z'
    const remainder: RemBytes = str[offset..][0..rem_count].*;
    const min: RemBools = remainder >= @as(RemBytes, @splat('a'));
    const max: RemBools = remainder <= @as(RemBytes, @splat('z'));
    const false_remainder: RemBools = @splat(false);
    const is_lower = @select(bool, min, max, false_remainder);

    // Mask the lowercase bytes so they are in the range 'A'...'Z'
    const mask: RemBytes = @splat(0b1101_1111);
    const uppercased = @select(u8, is_lower, remainder & mask, remainder);
    result[offset..][0..rem_count].* = uppercased;

    return result;
}

test staticEql {
    const corpus: []const *const [5]u8 = &.{
        "aback", "abase", "abate", "abbey", "abbot", "abhor", "abide", "abled",
        "abode", "abort", "about", "above", "abuse", "abyss", "acorn", "acrid",
    };

    // strings are equal to themselves
    inline for (corpus) |str| {
        try std.testing.expect(staticEql(str, str));
    }

    // unequal strings are just that - not equal
    inline for (corpus, 0..) |str_a, idx| {
        for (corpus[0..idx]) |str_b| {
            try std.testing.expect(!staticEql(str_a, str_b));
        }
    }
}

test ignoreCaseStaticEql {
    const corpus_a: []const *const [5]u8 = &.{
        "wRING", "WRIst", "WRiTe", "wronG", "WROte", "WruNg", "wryly", "yacht",
        "yeaRN", "yeAST", "YIEld", "young", "youth", "zeBRa", "zESTy", "zONal",
    };
    const corpus_b: []const *const [5]u8 = &.{
        "wrIng", "wRISt", "WritE", "WRONG", "wROTE", "wRUnG", "wrYlY", "yAcHt",
        "yEARn", "yeAst", "yiEld", "yoUng", "youTh", "zeBra", "zEsTY", "zonaL",
    };

    // strings are equal to themselves
    inline for (corpus_a, corpus_b) |str_a, str_b| {
        try std.testing.expect(ignoreCaseStaticEql(str_a, str_a));
        try std.testing.expect(ignoreCaseStaticEql(str_b, str_b));
    }

    // strings are equal regardless of alphabetic case
    inline for (corpus_a, corpus_b) |str_a, str_b| {
        try std.testing.expect(ignoreCaseStaticEql(str_a, str_b));
    }

    // unequal strings are just that - not equal
    inline for (corpus_a, corpus_b, 0..) |str_a0, str_b0, idx| {
        for (corpus_a[0..idx], corpus_b[0..idx]) |str_a1, str_b1| {
            try std.testing.expect(!ignoreCaseStaticEql(str_a0, str_a1));
            try std.testing.expect(!ignoreCaseStaticEql(str_a0, str_b1));
            try std.testing.expect(!ignoreCaseStaticEql(str_b0, str_a1));
            try std.testing.expect(!ignoreCaseStaticEql(str_b0, str_b1));
        }
    }
}

test toUpperSimd {
    const input_list: []const []const u8 = &.{
        "0",
        "abc",
        "123abc!!!",
        "0xdEaDBeeF",
        "this is a test string, I don't know.",
        "this is the\xFFspiciest test\x00string to ever exist in zig",
    };
    const expected_list: []const []const u8 = &.{
        "0",
        "ABC",
        "123ABC!!!",
        "0XDEADBEEF",
        "THIS IS A TEST STRING, I DON'T KNOW.",
        "THIS IS THE\xFFSPICIEST TEST\x00STRING TO EVER EXIST IN ZIG",
    };

    inline for (input_list, expected_list) |input, expected| {
        const actual = toUpperSimd(input.len, input[0..input.len]);
        try std.testing.expectEqualSlices(u8, expected, &actual);
    }
}

const TestEnum = enum { A, B, C, D, E };
const TestMap = StaticStringMap(TestEnum);
const TestKV = struct { []const u8, TestEnum };
const TestMapVoid = StaticStringMap(void);
const TestKVVoid = struct { []const u8 };
const TestMapIgnoreCase = StaticStringMapIgnoreCaseAscii(TestEnum);
const testing = std.testing;
const test_alloc = testing.allocator;

test "list literal of list literals" {
    const slice: []const TestKV = &.{
        .{ "these", .D },
        .{ "have", .A },
        .{ "nothing", .B },
        .{ "incommon", .C },
        .{ "samelen", .E },
    };

    const map = TestMap.initComptime(slice);
    try testMap(map);
    // Default comparison is case sensitive
    try testing.expect(null == map.get("NOTHING"));
}

test "get/has with edge cases" {
    const map = StaticStringMap(u32).initComptime(&.{
        .{ "a", 0 },
        .{ "ab", 3 },
        .{ "abc", 0 },
        .{ "abcd", 1 },
        .{ "abcde", 1 },
    });

    try testing.expectEqual(false, map.has("abcdef"));
    try testing.expectEqual(true, map.has("abcde"));
    try testing.expectEqual(3, map.get("ab"));
    try testing.expectEqual(0, map.get("a"));
    try testing.expectEqual(null, map.get(""));
}

test "array of structs" {
    const array = [_]TestKV{
        .{ "these", .D },
        .{ "have", .A },
        .{ "nothing", .B },
        .{ "incommon", .C },
        .{ "samelen", .E },
    };

    try testMap(TestMap.initComptime(array));
}

test "slice of structs" {
    const array = [_]TestKV{
        .{ "these", .D },
        .{ "have", .A },
        .{ "nothing", .B },
        .{ "incommon", .C },
        .{ "samelen", .E },
    };

    const slice: []const TestKV = array[0..array.len];
    try testMap(TestMap.initComptime(slice));
}

fn testMap(comptime map: anytype) !void {
    try testing.expectEqual(TestEnum.A, map.get("have").?);
    try testing.expectEqual(TestEnum.B, map.get("nothing").?);
    try testing.expect(null == map.get("missing"));
    try testing.expectEqual(TestEnum.D, map.get("these").?);
    try testing.expectEqual(TestEnum.E, map.get("samelen").?);

    try testing.expect(!map.has("missing"));
    try testing.expect(map.has("these"));

    try testing.expect(null == map.get(""));
    try testing.expect(null == map.get("averylongstringthathasnomatches"));
}

test "void value type, slice of structs" {
    const slice = [_]TestKVVoid{
        .{"these"},
        .{"have"},
        .{"nothing"},
        .{"incommon"},
        .{"samelen"},
    };
    const map = TestMapVoid.initComptime(slice);
    try testSet(map);
    // Default comparison is case sensitive
    try testing.expect(null == map.get("NOTHING"));
}

test "void value type, list literal of list literals" {
    const slice = [_]TestKVVoid{
        .{"these"},
        .{"have"},
        .{"nothing"},
        .{"incommon"},
        .{"samelen"},
    };

    try testSet(TestMapVoid.initComptime(slice));
}

fn testSet(comptime map: TestMapVoid) !void {
    try testing.expectEqual({}, map.get("have").?);
    try testing.expectEqual({}, map.get("nothing").?);
    try testing.expect(null == map.get("missing"));
    try testing.expectEqual({}, map.get("these").?);
    try testing.expectEqual({}, map.get("samelen").?);

    try testing.expect(!map.has("missing"));
    try testing.expect(map.has("these"));

    try testing.expect(null == map.get(""));
    try testing.expect(null == map.get("averylongstringthathasnomatches"));
}

fn testStaticStringMapIgnoreCase(comptime map: TestMapIgnoreCase) !void {
    try testMap(map);
    try testing.expectEqual(TestEnum.A, map.get("HAVE").?);
    try testing.expectEqual(TestEnum.E, map.get("SameLen").?);
    try testing.expect(null == map.get("SameLength"));
    try testing.expect(map.has("ThESe"));
}

test "StaticStringMapIgnoreCaseAscii" {
    const slice = [_]TestKV{
        .{ "these", .D },
        .{ "have", .A },
        .{ "nothing", .B },
        .{ "incommon", .C },
        .{ "samelen", .E },
    };

    try testStaticStringMapIgnoreCase(TestMapIgnoreCase.initComptime(slice));
}

test "empty" {
    const m1 = StaticStringMap(usize).initComptime(.{});
    try testing.expect(null == m1.get("anything"));

    const m2 = StaticStringMapIgnoreCaseAscii(usize).initComptime(.{});
    try testing.expect(null == m2.get("anything"));
}

test "comptime-only value" {
    const map = StaticStringMap(type).initComptime(.{
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

    try testing.expect(map.get("a").?.foo == 1);
    try testing.expect(map.get("b").?.foo == 2);
    try testing.expect(map.get("c").?.foo == 3);
    try testing.expect(map.get("d") == null);
}

test "sorting kvs doesn't exceed eval branch quota" {
    // from https://github.com/ziglang/zig/issues/19803
    const TypeToByteSizeLUT = StaticStringMap(u32).initComptime(.{
        .{ "bool", 0 },
        .{ "c_int", 0 },
        .{ "c_long", 0 },
        .{ "c_longdouble", 0 },
        .{ "t20", 0 },
        .{ "t19", 0 },
        .{ "t18", 0 },
        .{ "t17", 0 },
        .{ "t16", 0 },
        .{ "t15", 0 },
        .{ "t14", 0 },
        .{ "t13", 0 },
        .{ "t12", 0 },
        .{ "t11", 0 },
        .{ "t10", 0 },
        .{ "t9", 0 },
        .{ "t8", 0 },
        .{ "t7", 0 },
        .{ "t6", 0 },
        .{ "t5", 0 },
        .{ "t4", 0 },
        .{ "t3", 0 },
        .{ "t2", 0 },
        .{ "t1", 1 },
    });
    try testing.expectEqual(1, TypeToByteSizeLUT.get("t1"));
}

test "single string StaticStringMap" {
    const map = StaticStringMap(void).initComptime(.{.{"Hello, World!"}});
    try testing.expectEqual(true, map.has("Hello, World!"));
    try testing.expectEqual(false, map.has("Same len str!"));
    try testing.expectEqual(false, map.has("Hello, World! (not the same)"));
}

test "empty StaticStringMap" {
    const map = StaticStringMap(void).initComptime(.{});
    try testing.expectEqual(false, map.has(&.{}));
    try testing.expectEqual(null, map.get(&.{}));
    try testing.expectEqual(false, map.has("anything really"));
}
