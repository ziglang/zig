const std = @import("std.zig");

pub fn ComptimeStringMap(comptime V: type, comptime kvs_list: anytype) type {
    return ComptimeStringMapWithEql(V, u8, kvs_list, defaultEql);
}

pub fn ComptimeStringMapIgnoreCase(comptime V: type, comptime kvs_list: anytype) type {
    return ComptimeStringMapWithEql(V, u8, kvs_list, ignoreCaseEql);
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
    return defaultEql(len, lower_expected, lower_actual);
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
pub fn ComptimeStringMapWithEql(
    /// The type of the value
    comptime V: type,
    /// The type of the element in the array, eg. []const T - would be u8 for a string
    comptime T: type,
    /// An array/slice of key/value pairs: eg. .{ .{ "a", .a }, .{ "ab", .b }, .{ "abc", .c }, ...}
    comptime kvs_list: anytype,
    /// The equal function that is used to compare the keys
    comptime eql: fn (comptime T: type, comptime usize, comptime anytype, anytype) bool,
) type {
    return struct {
        pub const Kv = struct {
            key: []const T,
            value: V,
        };

        /// Returns the value for the key if any, else null.
        pub fn has(key: []const T) bool {
            return get(key) != null;
        }

        /// Checks if the map has a value for the key.
        pub fn get(key: []const T) ?V {
            return switch (kvs.len) {
                0 => null,
                1 => blk: {
                    const equal = std.mem.eql(T, kvs[0].key, key);
                    break :blk if (equal) kvs[0].value else null;
                },
                else => filterLength(key),
            };
        }

        /// The list of all the keys in the map.
        pub const keys: []const []const T = blk: {
            var key_list: []const []const T = &.{};
            for (kvs_list) |kv| {
                key_list = key_list ++ .{kv[0]};
            }
            break :blk key_list;
        };

        /// The list of all the values in the map.
        pub const values: []const V = blk: {
            var value_list: []const V = &.{};
            for (kvs_list) |kv| {
                value_list = value_list ++ .{kv[1]};
            }
            break :blk value_list;
        };

        /// The list of all the key/value pairs in the map.
        pub const kvs: []const Kv = blk: {
            var kv_list: []const Kv = &.{};
            for (kvs_list) |kv| {
                kv_list = kv_list ++ .{.{ .key = kv[0], .value = kv[1] }};
            }
            break :blk kv_list;
        };

        /// Filters the input key by length, then compares it to the possible matches.
        /// Because we know the length at comptime, we can compare the strings faster.
        fn filterLength(key: []const T) ?V {
            // Provide 2000 branches per key/value pair to compile.
            @setEvalBranchQuota(2000 * kvs_list.len);
            const kvs_by_lengths = comptime separateLength();
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
        fn separateLength() []const LengthKvs {
            var length_sets: []const LengthKvs = &.{};
            add_length: for (kvs, 0..) |check_kv, index| {
                const length = check_kv.key.len;

                // Skip the current length if it has already been inserted.
                for (length_sets) |set| {
                    if (set.length == length) {
                        continue :add_length;
                    }
                }

                var added_kvs: []const Kv = &.{};
                for (kvs[index..]) |add_kv| {
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
    const Map = ComptimeStringMap(type, .{
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

    try testing.expect(Map.get("a").?.foo == 1);
    try testing.expect(Map.get("b").?.foo == 2);
    try testing.expect(Map.get("c").?.foo == 3);
    try testing.expect(Map.get("d") == null);
}

test "get/has with edge cases" {
    const Map = ComptimeStringMap(u32, &.{
        .{ "a", 0 },
        .{ "ab", 3 },
        .{ "abc", 0 },
        .{ "abcd", 1 },
        .{ "abcde", 1 },
    });

    try testing.expectEqual(false, Map.has("abcdef"));
    try testing.expectEqual(true, Map.has("abcde"));
    try testing.expectEqual(3, Map.get("ab"));
    try testing.expectEqual(0, Map.get("a"));
    try testing.expectEqual(null, Map.get(""));
}
