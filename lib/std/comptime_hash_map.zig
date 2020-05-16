const std = @import("std.zig");
const hash_map = std.hash_map;
const testing = std.testing;
const math = std.math;

/// A comptime hashmap constructed with automatically selected hash and eql functions.
pub fn AutoComptimeHashMap(comptime K: type, comptime V: type, comptime values: var) type {
    return ComptimeHashMap(K, V, hash_map.getAutoHashFn(K), hash_map.getAutoEqlFn(K), values);
}

/// Builtin hashmap for strings as keys.
pub fn ComptimeStringHashMap(comptime V: type, comptime values: var) type {
    return ComptimeHashMap([]const u8, V, hash_map.hashString, hash_map.eqlString, values);
}

/// A hashmap which is constructed at compile time from constant values.
/// Intended to be used as a faster lookup table.
pub fn ComptimeHashMap(comptime K: type, comptime V: type, comptime hash: fn (key: K) u32, comptime eql: fn (a: K, b: K) bool, comptime values: var) type {
    std.debug.assert(values.len != 0);
    @setEvalBranchQuota(1000 * values.len);

    const Entry = struct {
        distance_from_start_index: usize = 0,
        key: K = undefined,
        val: V = undefined,
        used: bool = false,
    };

    // ensure that the hash map will be at most 60% full
    const size = math.ceilPowerOfTwo(usize, values.len * 5 / 3) catch unreachable;
    var slots = [1]Entry{.{}} ** size;

    var max_distance_from_start_index = 0;

    slot_loop: for (values) |kv| {
        var key: K = kv[0];
        var value: V = kv[1];

        const start_index = @as(usize, hash(key)) & (size - 1);

        var roll_over = 0;
        var distance_from_start_index = 0;
        while (roll_over < size) : ({
            roll_over += 1;
            distance_from_start_index += 1;
        }) {
            const index = (start_index + roll_over) & (size - 1);
            const entry = &slots[index];

            if (entry.used and !eql(entry.key, key)) {
                if (entry.distance_from_start_index < distance_from_start_index) {
                    // robin hood to the rescue
                    const tmp = slots[index];
                    max_distance_from_start_index = math.max(max_distance_from_start_index, distance_from_start_index);
                    entry.* = .{
                        .used = true,
                        .distance_from_start_index = distance_from_start_index,
                        .key = key,
                        .val = value,
                    };
                    key = tmp.key;
                    value = tmp.val;
                    distance_from_start_index = tmp.distance_from_start_index;
                }
                continue;
            }

            max_distance_from_start_index = math.max(distance_from_start_index, max_distance_from_start_index);
            entry.* = .{
                .used = true,
                .distance_from_start_index = distance_from_start_index,
                .key = key,
                .val = value,
            };
            continue :slot_loop;
        }
        unreachable; // put into a full map
    }

    return struct {
        const entries = slots;

        pub fn has(key: K) bool {
            return get(key) != null;
        }

        pub fn get(key: K) ?*const V {
            const start_index = @as(usize, hash(key)) & (size - 1);
            {
                var roll_over: usize = 0;
                while (roll_over <= max_distance_from_start_index) : (roll_over += 1) {
                    const index = (start_index + roll_over) & (size - 1);
                    const entry = &entries[index];

                    if (!entry.used) return null;
                    if (eql(entry.key, key)) return &entry.val;
                }
            }
            return null;
        }
    };
}

test "basic usage" {
    const map = ComptimeStringHashMap(usize, .{
        .{ "foo", 1 },
        .{ "bar", 2 },
        .{ "baz", 3 },
        .{ "quux", 4 },
    });

    testing.expect(map.has("foo"));
    testing.expect(map.has("bar"));
    testing.expect(!map.has("zig"));
    testing.expect(!map.has("ziguana"));

    testing.expect(map.get("baz").?.* == 3);
    testing.expect(map.get("quux").?.* == 4);
    testing.expect(map.get("nah") == null);
    testing.expect(map.get("...") == null);
}

test "auto comptime hash map" {
    const map = AutoComptimeHashMap(usize, []const u8, .{
        .{ 1, "foo" },
        .{ 2, "bar" },
        .{ 3, "baz" },
        .{ 45, "quux" },
    });

    testing.expect(map.has(1));
    testing.expect(map.has(2));
    testing.expect(!map.has(4));
    testing.expect(!map.has(1_000_000));

    testing.expectEqualStrings("foo", map.get(1).?.*);
    testing.expectEqualStrings("bar", map.get(2).?.*);
    testing.expect(map.get(4) == null);
    testing.expect(map.get(4_000_000) == null);
}
