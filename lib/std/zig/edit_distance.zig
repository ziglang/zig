//! [Edit distance](https://en.wikipedia.org/wiki/Edit_distance) algorithms.

const std = @import("std");
const testing = std.testing;

// MIT licensed. Adapted from https://github.com/wooorm/levenshtein-rs.
// Copyright (c) 2016 Titus Wormer <tituswormer@gmail.com>

/// Calculates the [Levenshtein distance](https://en.wikipedia.org/wiki/Levenshtein_distance)
/// between two slices.
///
/// `cache.len` must be `a.len`
pub fn levenshtein(cache: []usize, a: []const u8, b: []const u8) usize {
    std.debug.assert(cache.len == a.len);

    if (a.len == 0 or b.len == 0) {
        return a.len + b.len;
    }

    for (cache, 1..) |*cache_value, i| {
        cache_value.* = i;
    }

    var result: usize = 0;
    for (b, 0..) |b_value, b_idx| {
        result = b_idx;
        var dist_a = b_idx;

        for (a, 0..) |a_value, a_idx| {
            const dist_b = dist_a + @intFromBool(a_value != b_value);
            dist_a = cache[a_idx];
            result = if (dist_a > result)
                if (dist_b > result)
                    result + 1
                else
                    dist_b
            else if (dist_b > dist_a)
                dist_a + 1
            else
                dist_b;
            cache[a_idx] = result;
        }
    }
    return result;
}

test levenshtein {
    var buffer: [256]usize = undefined;

    const test_cases: []const struct { []const u8, []const u8, usize } = &.{
        .{ "", "a", 1 },
        .{ "a", "", 1 },
        .{ "", "", 0 },
        .{ "levenshtein", "levenshtein", 0 },
        .{ "DwAyNE", "DUANE", 2 },
        .{ "dwayne", "DuAnE", 5 },
        .{ "aarrgh", "aargh", 1 },
        .{ "aargh", "aarrgh", 1 },
        .{ "sitting", "kitten", 3 },
        .{ "gumbo", "gambol", 2 },
        .{ "saturday", "sunday", 3 },
        .{ "ab", "ac", 1 },
        .{ "ac", "bc", 1 },
        .{ "abc", "axc", 1 },
        .{ "xabxcdxxefxgx", "1ab2cd34ef5g6", 6 },
        .{ "xabxcdxxefxgx", "abcdefg", 6 },
        .{ "javawasneat", "scalaisgreat", 7 },
        .{ "example", "samples", 3 },
        .{ "sturgeon", "urgently", 6 },
        .{ "levenshtein", "frankenstein", 6 },
        .{ "distance", "difference", 5 },
        .{ "kitten", "sitting", 3 },
        .{ "Tier", "Tor", 2 },
        .{ "hel", "hello world", 8 },
        .{ "hello world", "hel", 8 },
    };

    for (test_cases) |data| {
        const s1, const s2, const expected = data;
        const matrix = buffer[0..s1.len];
        try testing.expectEqual(expected, levenshtein(matrix, s1, s2));
    }
}
