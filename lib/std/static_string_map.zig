const std = @import("std.zig");
const assert = std.debug.assert;

/// 'comptime' optimized mapping between string keys and associated `V` values.
pub fn StaticStringMap(comptime V: type) type {
    return StaticStringMapWithEql(V, defaultEql);
}

/// Same as StaticStringMap, except keys are compared case-insensitively.
pub fn StaticStringMapIgnoreCase(comptime V: type) type {
    return StaticStringMapWithEql(V, ignoreCaseEql);
}

fn defaultEql(comptime expected: anytype, actual: anytype) bool {
    comptime assert(expected.len == actual.len);
    const child_bits = expected.len * std.mem.byte_size_in_bits;

    // Integers are limited to 65535 bits; default to a for loop
    // if the strings to compare are too long
    const too_many_bits = child_bits > 65535;

    // TODO: riscv64 backend can't airBitCast [7]u8 to u56
    const limited_backend = @import("builtin").zig_backend == .stage2_riscv64;

    if (too_many_bits or limited_backend) {
        var match: bool = true;
        for (expected, actual) |a, b| {
            match = match and a == b;
        }
        return match;
    }

    const Compare = std.meta.Int(.unsigned, child_bits);
    const a: Compare = @bitCast(expected);
    const b: Compare = @bitCast(actual);
    return a == b;
}

fn ignoreCaseEql(comptime expected: anytype, actual: anytype) bool {
    const lower_expected = comptime toLowerSimd(expected);

    // TODO: x86_64 self hosted backend hasn't implemented genBinOp for cmp_gte
    const lower_actual = blk: {
        if (@import("builtin").zig_backend == .stage2_x86_64) {
            break :blk toLowerSimple(actual.len, actual);
        } else {
            break :blk toLowerSimd(actual);
        }
    };

    return defaultEql(lower_expected, lower_actual);
}

// For backends that cannot handle integer vectors
fn toLowerSimple(comptime len: usize, input: anytype) [len]u8 {
    var output: [len]u8 = undefined;
    for (input, &output) |in_byte, *out_byte| {
        out_byte.* = std.ascii.toLower(in_byte);
    }
    return output;
}

fn toLowerSimd(input: anytype) [@typeInfo(@TypeOf(input)).array.len]u8 {
    const array_info = @typeInfo(@TypeOf(input)).array;
    comptime assert(array_info.child == u8);

    const SVec = @Vector(array_info.len, u8);
    const BVec = @Vector(array_info.len, bool);

    const at_min: BVec = input >= @as(SVec, @splat('A'));
    const at_max: BVec = input <= @as(SVec, @splat('Z'));
    const false_vec: BVec = @splat(false);
    const is_upper: BVec = @select(bool, at_min, at_max, false_vec);

    const lowered: SVec = input +% @as(SVec, @splat('a' - 'A'));
    return @select(u8, is_upper, lowered, input);
}

/// Static string map constructed at compile time for additional optimizations.
/// First branches on the key length, then compares the possible matching keys.
fn StaticStringMapWithEql(
    /// The type of the value
    comptime V: type,
    /// The equal function that is used to compare the keys
    comptime eql: fn (comptime anytype, anytype) bool,
) type {
    return struct {
        const Self = @This();

        pub const Kv = struct {
            key: []const u8,
            value: V,
        };

        kvs: []const Kv,

        /// Initializes the map at comptime with a list of key / value pairs
        pub inline fn initComptime(comptime kvs_list: anytype) Self {
            const list = comptime blk: {
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

        /// Checks if the map contains the key.
        pub fn has(comptime self: Self, key: []const u8) bool {
            return self.get(key) != null;
        }

        /// Returns the value for the key if any.
        pub fn get(comptime self: Self, key: []const u8) ?V {
            switch (self.kvs.len) {
                0 => return null,
                else => return self.filterLength(key),
            }
        }

        /// Returns the list of all the keys in the map.
        pub fn keys(comptime self: Self) []const []const u8 {
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
        pub fn values(comptime self: Self) []const V {
            const list = comptime blk: {
                var list: [self.kvs.len]V = undefined;
                for (&list, self.kvs) |*value, kv| {
                    value.* = kv.value;
                }
                break :blk list;
            };
            return &list;
        }

        /// Filters the input key by length, then compares it to the possible matches.
        /// Because we know the length at comptime, we can compare the strings faster.
        fn filterLength(comptime self: Self, key: []const u8) ?V {
            // separateLength is hungry - provide 2000 branches per key/value pair
            @setEvalBranchQuota(2000 * self.kvs.len);
            const kvs_by_lengths = comptime self.separateLength();

            inline for (kvs_by_lengths) |kvs_by_len| {
                const len = kvs_by_len.length;
                if (key.len == len) {
                    inline for (kvs_by_len.kvs, 0..) |kv, idx| {

                        // Out of keys with the same length, check for duplicates
                        @setEvalBranchQuota(10 * len * idx);
                        comptime for (kvs_by_len.kvs[0..idx]) |prev_kv| {
                            if (eql(kv.key[0..len].*, prev_kv.key[0..len].*)) {
                                @compileError("redundant key \"" ++ kv.key ++ "\"");
                            }
                        };

                        if (eql(kv.key[0..len].*, key[0..len].*)) {
                            return kv.value;
                        }
                    }
                }
            }
            return null;
        }

        const LengthKvs = struct {
            length: usize,
            kvs: []const Kv,
        };

        /// Creates a list of kv sets grouped by different key lengths.
        fn separateLength(comptime self: Self) []const LengthKvs {
            var length_sets: []const LengthKvs = &.{};
            add_length: for (self.kvs, 0..) |check_kv, index| {
                const length = check_kv.key.len;

                // Skip the current length if it has already been inserted.
                for (length_sets) |set| {
                    if (set.length == length) {
                        continue :add_length;
                    }
                }

                // Add keys with the same length to the set.
                var added_kvs: []const Kv = &.{};
                for (self.kvs[index..]) |add_kv| {
                    if (add_kv.key.len == length) {
                        added_kvs = added_kvs ++ .{add_kv};
                    }
                }
                const added_kvs_set: LengthKvs = .{ .length = length, .kvs = added_kvs };
                length_sets = length_sets ++ .{added_kvs_set};
            }
            return length_sets;
        }
    };
}

const TestEnum = enum { A, B, C, D, E };
const TestMap = StaticStringMap(TestEnum);
const TestKV = struct { []const u8, TestEnum };
const TestMapVoid = StaticStringMap(void);
const TestKVVoid = struct { []const u8 };
const TestMapIgnoreCase = StaticStringMapIgnoreCase(TestEnum);
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

test "StaticStringMapIgnoreCase" {
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

    const m2 = StaticStringMapIgnoreCase(usize).initComptime(.{});
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
