//! https://tools.ietf.org/html/rfc1950#section-9
//! https://github.com/madler/zlib/blob/master/adler32.c

const Adler32 = @This();
const std = @import("std");
const testing = std.testing;

adler: u32 = 1,

pub fn permute(state: u32, input: []const u8) u32 {
    const base = 65521;
    const nmax = 5552;

    var s1 = state & 0xffff;
    var s2 = (state >> 16) & 0xffff;

    if (input.len == 1) {
        s1 +%= input[0];
        if (s1 >= base) {
            s1 -= base;
        }
        s2 +%= s1;
        if (s2 >= base) {
            s2 -= base;
        }
    } else if (input.len < 16) {
        for (input) |b| {
            s1 +%= b;
            s2 +%= s1;
        }
        if (s1 >= base) {
            s1 -= base;
        }

        s2 %= base;
    } else {
        const n = nmax / 16; // note: 16 | nmax

        var i: usize = 0;

        while (i + nmax <= input.len) {
            var rounds: usize = 0;
            while (rounds < n) : (rounds += 1) {
                comptime var j: usize = 0;
                inline while (j < 16) : (j += 1) {
                    s1 +%= input[i + j];
                    s2 +%= s1;
                }
                i += 16;
            }

            s1 %= base;
            s2 %= base;
        }

        if (i < input.len) {
            while (i + 16 <= input.len) : (i += 16) {
                comptime var j: usize = 0;
                inline while (j < 16) : (j += 1) {
                    s1 +%= input[i + j];
                    s2 +%= s1;
                }
            }
            while (i < input.len) : (i += 1) {
                s1 +%= input[i];
                s2 +%= s1;
            }

            s1 %= base;
            s2 %= base;
        }
    }

    return s1 | (s2 << 16);
}

pub fn update(a: *Adler32, input: []const u8) void {
    a.adler = permute(a.adler, input);
}

pub fn hash(input: []const u8) u32 {
    return permute(1, input);
}

test "sanity" {
    try testing.expectEqual(@as(u32, 0x620062), hash("a"));
    try testing.expectEqual(@as(u32, 0xbc002ed), hash("example"));
}

test "long" {
    const long1 = [_]u8{1} ** 1024;
    try testing.expectEqual(@as(u32, 0x06780401), hash(long1[0..]));

    const long2 = [_]u8{1} ** 1025;
    try testing.expectEqual(@as(u32, 0x0a7a0402), hash(long2[0..]));
}

test "very long" {
    const long = [_]u8{1} ** 5553;
    try testing.expectEqual(@as(u32, 0x707f15b2), hash(long[0..]));
}

test "very long with variation" {
    const long = comptime blk: {
        @setEvalBranchQuota(7000);
        var result: [6000]u8 = undefined;

        var i: usize = 0;
        while (i < result.len) : (i += 1) {
            result[i] = @as(u8, @truncate(i));
        }

        break :blk result;
    };

    try testing.expectEqual(@as(u32, 0x5af38d6e), hash(long[0..]));
}
