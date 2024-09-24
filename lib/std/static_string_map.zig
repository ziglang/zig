const std = @import("std.zig");

/// 'comptime' optimized mapping between string keys and associated values.
pub fn StaticStringMap(comptime V: type) type {
    return StaticStringMapAdvanced(V, u8, defaultEql);
}

/// Same as StaticStringMap, except keys are compared case-insensitively.
pub fn StaticStringMapIgnoreCase(comptime V: type) type {
    return StaticStringMapAdvanced(V, u8, ignoreCaseEql);
}

fn defaultEql(comptime T: type, comptime len: usize, comptime expected: [len]u8, actual: [len]u8) bool {
    const Compare = std.meta.Int(.unsigned, len * @sizeOf(T) * std.mem.byte_size_in_bits);
    const a: Compare = @bitCast(expected);
    const b: Compare = @bitCast(actual);
    return a == b;
}

fn ignoreCaseEql(comptime T: type, comptime len: usize, comptime expected: [len]u8, actual: [len]u8) bool {
    if (T != u8) @compileError("ignoreCaseEql only works with ASCII or UTF-8");
    const lower_expected = comptime toLowerSimd(len, expected);
    const lower_actual = toLowerSimd(len, actual);
    return defaultEql(T, len, lower_expected, lower_actual);
}

fn toLowerSimd(comptime len: usize, input: [len]u8) [len]u8 {
    const SVec = @Vector(len, u8);
    const BVec = @Vector(len, bool);

    const at_min: BVec = input >= @as(SVec, @splat('A'));
    const at_max: BVec = input >= @as(SVec, @splat('Z'));
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
    comptime eql: fn (comptime T: type, comptime usize, comptime anytype, anytype) bool,
) type {
    if (!std.meta.hasUniqueRepresentation(T)) {
        @compileError("T must have a unique in-memory representation.");
    }
    return struct {
        const Self = @This();

        pub const Kv = struct {
            key: []const T,
            value: V,
        };

        kvs: []const Kv,

        /// Initializes the map at comptime
        pub fn initComptime(comptime kvs_list: anytype) Self {
            const kvs: []const Kv = comptime blk: {
                var kv_list: []const Kv = &.{};
                for (kvs_list) |kv| {
                    kv_list = kv_list ++ .{.{ .key = kv[0], .value = kv[1] }};
                }
                break :blk kv_list;
            };
            return .{ .kvs = kvs };
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
            return comptime blk: {
                var key_list: []const []const T = &.{};
                for (self.kvs) |kv| {
                    key_list = key_list ++ .{kv.key};
                }
                break :blk key_list;
            };
        }

        /// The list of all the values in the map.
        pub fn values(comptime self: Self) []const V {
            return comptime blk: {
                var value_list: []const V = &.{};
                for (self.kvs) |kv| {
                    value_list = value_list ++ .{kv.value};
                }
                break :blk value_list;
            };
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
                        if (eql(T, len, kv.key[0..len].*, key[0..len].*)) {
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

const testing = std.testing;

test "comptime only value" {
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
