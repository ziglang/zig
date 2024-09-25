const std = @import("std.zig");
const assert = std.debug.assert;

/// 'comptime' optimized mapping between string keys and associated values.
pub fn StaticStringMap(comptime V: type) type {
    return StaticStringMapAdvanced(V, u8, defaultEql);
}

/// Same as StaticStringMap, except keys are compared case-insensitively.
pub fn StaticStringMapIgnoreCase(comptime V: type) type {
    return StaticStringMapAdvanced(V, u8, ignoreCaseEql);
}

pub fn defaultEql(comptime len: usize, comptime expected: anytype, actual: anytype) bool {
    comptime assert(std.meta.hasUniqueRepresentation(@TypeOf(expected, actual)));
    const T = @typeInfo(@TypeOf(expected)).array.child;
    const child_bytes = std.mem.byte_size_in_bits * @sizeOf(T);
    const Compare = std.meta.Int(.unsigned, len * child_bytes);
    const a: Compare = @bitCast(expected);
    const b: Compare = @bitCast(actual);
    return a == b;
}

fn ignoreCaseEql(comptime len: usize, comptime expected: [len]u8, actual: [len]u8) bool {
    const lower_expected = comptime toLowerSimd(len, expected);

    // TODO: x86_64 self hosted backend hasn't implemented genBinOp for cmp_gte
    const lower_actual = blk: {
        if (@import("builtin").zig_backend == .stage2_x86_64) {
            break :blk toLowerSimple(len, actual);
        } else {
            break :blk toLowerSimd(len, actual);
        }
    };

    return defaultEql(len, lower_expected, lower_actual);
}

fn toLowerSimple(comptime len: usize, input: [len]u8) [len]u8 {
    var output: [len]u8 = undefined;
    for (input, &output) |in_byte, *out_byte| {
        out_byte.* = std.ascii.toLower(in_byte);
    }
    return output;
}

fn toLowerSimd(comptime len: usize, input: [len]u8) [len]u8 {
    const SVec = @Vector(len, u8);
    const BVec = @Vector(len, bool);

    const at_min: BVec = input >= @as(SVec, @splat('A'));
    const at_max: BVec = input <= @as(SVec, @splat('Z'));
    const true_vec: BVec = @splat(true);
    const is_upper: BVec = @select(bool, at_min, at_max, true_vec);

    const lowered: SVec = input + @as(SVec, @splat('a' - 'A'));
    return @select(u8, is_upper, lowered, input);
}

/// Static string map constructed at compile time for additional optimizations.
/// First branches on the key length, then compares the possible matching keys.
pub fn StaticStringMapAdvanced(
    /// The type of the value
    comptime V: type,
    /// The type of the element in the array, eg. []const T - would be u8 for a string
    comptime T: type,
    /// The equal function that is used to compare the keys
    comptime eql: fn (comptime usize, comptime anytype, anytype) bool,
) type {
    return struct {
        const Self = @This();

        pub const Kv = struct {
            key: []const T,
            value: V,
        };

        kvs: []const Kv,

        /// Initializes the map at comptime
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

        /// Returns the value for the key if any, else null.
        pub fn has(comptime self: Self, key: []const T) bool {
            return self.get(key) != null;
        }

        /// Checks if the map has a value for the key.
        pub fn get(comptime self: Self, key: []const T) ?V {
            return switch (self.kvs.len) {
                0 => null,
                1 => blk: {
                    const equal = std.mem.eql(T, self.kvs[0].key, key);
                    break :blk if (equal) self.kvs[0].value else null;
                },
                else => self.filterLength(key),
            };
        }

        /// The list of all the keys in the map.
        pub fn keys(comptime self: Self) []const []const T {
            const list = comptime blk: {
                var list: [self.kvs.len][]const T = undefined;
                for (&list, self.kvs) |*key, kv| {
                    key.* = kv.key;
                }
                break :blk list;
            };
            return &list;
        }

        /// The list of all the values in the map.
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
        fn filterLength(comptime self: Self, key: []const T) ?V {
            // Provide 2000 branches per key/value pair to compile.
            @setEvalBranchQuota(2000 * self.kvs.len);
            const kvs_by_lengths = comptime self.separateLength();
            inline for (kvs_by_lengths) |kvs_by_len| {
                const len = kvs_by_len.length;
                if (key.len == len) {
                    inline for (kvs_by_len.kvs) |kv| {
                        if (eql(len, kv.key[0..len].*, key[0..len].*)) {
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

                var added_kvs: []const Kv = &.{};
                for (self.kvs[index..]) |add_kv| {
                    if (add_kv.key.len == length) {
                        added_kvs = added_kvs ++ .{add_kv};
                    }
                }
                length_sets = length_sets ++ .{.{ .length = length, .kvs = added_kvs }};
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
    const slice = [_]TestKV{
        .{ "these", .D },
        .{ "have", .A },
        .{ "nothing", .B },
        .{ "incommon", .C },
        .{ "samelen", .E },
    };

    try testMap(TestMap.initComptime(slice));
}

test "slice of structs" {
    const slice = [_]TestKV{
        .{ "these", .D },
        .{ "have", .A },
        .{ "nothing", .B },
        .{ "incommon", .C },
        .{ "samelen", .E },
    };

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

test "redundant entries" {
    const slice = [_]TestKV{
        .{ "redundant", .D },
        .{ "theNeedle", .A },
        .{ "redundant", .B },
        .{ "re" ++ "dundant", .C },
        .{ "redun" ++ "dant", .E },
    };
    const map = TestMap.initComptime(slice);

    // No promises about which one you get:
    try testing.expect(null != map.get("redundant"));

    // Default map is not case sensitive:
    try testing.expect(null == map.get("REDUNDANT"));

    try testing.expectEqual(TestEnum.A, map.get("theNeedle").?);
}

test "redundant insensitive" {
    const slice = [_]TestKV{
        .{ "redundant", .D },
        .{ "theNeedle", .A },
        .{ "redundanT", .B },
        .{ "RE" ++ "dundant", .C },
        .{ "redun" ++ "DANT", .E },
    };

    const map = TestMapIgnoreCase.initComptime(slice);

    // No promises about which result you'll get ...
    try testing.expect(null != map.get("REDUNDANT"));
    try testing.expect(null != map.get("ReDuNdAnT"));
    try testing.expectEqual(TestEnum.A, map.get("theNeedle").?);
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
    const TypeToByteSizeLUT = std.StaticStringMap(u32).initComptime(.{
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
