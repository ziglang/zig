//! Xoroshiro128+ - http://xoroshiro.di.unimi.it/
//!
//! PRNG

const std = @import("std");
const Random = std.rand.Random;
const math = std.math;
const Xoroshiro128 = @This();

s: [2]u64,

pub fn init(init_s: u64) Xoroshiro128 {
    var x = Xoroshiro128{ .s = undefined };

    x.seed(init_s);
    return x;
}

pub fn random(self: *Xoroshiro128) Random {
    return Random.init(self, fill);
}

pub fn next(self: *Xoroshiro128) u64 {
    const s0 = self.s[0];
    var s1 = self.s[1];
    const r = s0 +% s1;

    s1 ^= s0;
    self.s[0] = math.rotl(u64, s0, @as(u8, 55)) ^ s1 ^ (s1 << 14);
    self.s[1] = math.rotl(u64, s1, @as(u8, 36));

    return r;
}

// Skip 2^64 places ahead in the sequence
pub fn jump(self: *Xoroshiro128) void {
    var s0: u64 = 0;
    var s1: u64 = 0;

    const table = [_]u64{
        0xbeac0467eba5facb,
        0xd86b048b86aa9922,
    };

    inline for (table) |entry| {
        var b: usize = 0;
        while (b < 64) : (b += 1) {
            if ((entry & (@as(u64, 1) << @as(u6, @intCast(b)))) != 0) {
                s0 ^= self.s[0];
                s1 ^= self.s[1];
            }
            _ = self.next();
        }
    }

    self.s[0] = s0;
    self.s[1] = s1;
}

pub fn seed(self: *Xoroshiro128, init_s: u64) void {
    // Xoroshiro requires 128-bits of seed.
    var gen = std.rand.SplitMix64.init(init_s);

    self.s[0] = gen.next();
    self.s[1] = gen.next();
}

pub fn fill(self: *Xoroshiro128, buf: []u8) void {
    var i: usize = 0;
    const aligned_len = buf.len - (buf.len & 7);

    // Complete 8 byte segments.
    while (i < aligned_len) : (i += 8) {
        var n = self.next();
        comptime var j: usize = 0;
        inline while (j < 8) : (j += 1) {
            buf[i + j] = @as(u8, @truncate(n));
            n >>= 8;
        }
    }

    // Remaining. (cuts the stream)
    if (i != buf.len) {
        var n = self.next();
        while (i < buf.len) : (i += 1) {
            buf[i] = @as(u8, @truncate(n));
            n >>= 8;
        }
    }
}

test "xoroshiro sequence" {
    var r = Xoroshiro128.init(0);
    r.s[0] = 0xaeecf86f7878dd75;
    r.s[1] = 0x01cd153642e72622;

    const seq1 = [_]u64{
        0xb0ba0da5bb600397,
        0x18a08afde614dccc,
        0xa2635b956a31b929,
        0xabe633c971efa045,
        0x9ac19f9706ca3cac,
        0xf62b426578c1e3fb,
    };

    for (seq1) |s| {
        try std.testing.expect(s == r.next());
    }

    r.jump();

    const seq2 = [_]u64{
        0x95344a13556d3e22,
        0xb4fb32dafa4d00df,
        0xb2011d9ccdcfe2dd,
        0x05679a9b2119b908,
        0xa860a1da7c9cd8a0,
        0x658a96efe3f86550,
    };

    for (seq2) |s| {
        try std.testing.expect(s == r.next());
    }
}

test "xoroshiro fill" {
    var r = Xoroshiro128.init(0);
    r.s[0] = 0xaeecf86f7878dd75;
    r.s[1] = 0x01cd153642e72622;

    const seq = [_]u64{
        0xb0ba0da5bb600397,
        0x18a08afde614dccc,
        0xa2635b956a31b929,
        0xabe633c971efa045,
        0x9ac19f9706ca3cac,
        0xf62b426578c1e3fb,
    };

    for (seq) |s| {
        var buf0: [8]u8 = undefined;
        var buf1: [7]u8 = undefined;
        std.mem.writeIntLittle(u64, &buf0, s);
        r.fill(&buf1);
        try std.testing.expect(std.mem.eql(u8, buf0[0..7], buf1[0..]));
    }
}
