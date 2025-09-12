//! https://tools.ietf.org/html/rfc1950#section-9
//! https://github.com/madler/zlib/blob/master/adler32.c

const Adler32 = @This();
const std = @import("std");
const testing = std.testing;

adler: u32 = 1,

pub fn permute(state: u32, input: []const u8) u32 {
    const base = 65521;

    // nmax is the largest n such that 255n(n+1)/2 + (n+1)(base-1) does not overflow
    const b = 0xff.0 / 2.0 + (base - 1);
    const nmax: comptime_int = std.math.floor((-b + @sqrt(b * b - 2 * 0xff.0 * (base - 1 - std.math.maxInt(usize)))) / 0xff.0);

    var s1: usize = state & 0xffff;
    var s2: usize = (state >> 16) & 0xffff;

    const vec_len = std.simd.suggestVectorLength(u16) orelse 1;
    const Vec = @Vector(vec_len, u16);

    var i: usize = 0;

    while (i + nmax <= input.len) {
        const rounds = nmax / vec_len;
        for (0..rounds) |_| {
            const vec: Vec = input[i..][0..vec_len].*;

            s2 += vec_len * s1;
            s1 += @reduce(.Add, vec);
            s2 += @reduce(.Add, vec * std.simd.reverseOrder(std.simd.iota(u32, vec_len) + @as(Vec, @splat(1))));

            i += vec_len;
        }

        s1 %= base;
        s2 %= base;
    }

    while (i + vec_len <= input.len) : (i += vec_len) {
        const vec: Vec = input[i..][0..vec_len].*;

        s2 += vec_len * s1;
        s1 += @reduce(.Add, vec);
        s2 += @reduce(.Add, vec * std.simd.reverseOrder(std.simd.iota(u32, vec_len) + @as(Vec, @splat(1))));
    }

    for (input[i..]) |byte| {
        s1 += byte;
        s2 += s1;
    }

    s1 %= base;
    s2 %= base;

    return (@as(u32, @intCast(s2)) << 16) | @as(u32, @intCast(s1));
}

pub fn update(a: *Adler32, input: []const u8) void {
    a.adler = permute(a.adler, input);
}

pub fn hash(input: []const u8) u32 {
    return permute(1, input);
}

test "adler32 sanity" {
    try testing.expectEqual(@as(u32, 0x620062), hash("a"));
    try testing.expectEqual(@as(u32, 0xbc002ed), hash("example"));
}

test "adler32 long" {
    const long1 = [_]u8{1} ** 1024;
    try testing.expectEqual(@as(u32, 0x06780401), hash(long1[0..]));

    const long2 = [_]u8{1} ** 1025;
    try testing.expectEqual(@as(u32, 0x0a7a0402), hash(long2[0..]));
}

test "adler32 very long" {
    const long = [_]u8{1} ** 5553;
    try testing.expectEqual(@as(u32, 0x707f15b2), hash(long[0..]));
}

test "adler32 very long with variation" {
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
