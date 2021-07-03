// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! Xoroshiro128+ - http://xoroshiro.di.unimi.it/
//!
//! PRNG

const std = @import("std");
const Random = std.rand.Random;
const math = std.math;
const Xoroshiro128 = @This();

random: Random,

s: [2]u64,

pub fn init(init_s: u64) Xoroshiro128 {
    var x = Xoroshiro128{
        .random = Random{ .fillFn = fill },
        .s = undefined,
    };

    x.seed(init_s);
    return x;
}

fn next(self: *Xoroshiro128) u64 {
    const s0 = self.s[0];
    var s1 = self.s[1];
    const r = s0 +% s1;

    s1 ^= s0;
    self.s[0] = math.rotl(u64, s0, @as(u8, 24)) ^ s1 ^ (s1 << 16);
    self.s[1] = math.rotl(u64, s1, @as(u8, 37));

    return r;
}

// Skip 2^64 places ahead in the sequence
fn jump(self: *Xoroshiro128) void {
    var s0: u64 = 0;
    var s1: u64 = 0;

    const table = [_]u64{
        0xdf900294d8f554a5,
        0x170865df4b3201fc,
    };

    inline for (table) |entry| {
        var b: usize = 0;
        while (b < 64) : (b += 1) {
            if ((entry & (@as(u64, 1) << @intCast(u6, b))) != 0) {
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

fn fill(r: *Random, buf: []u8) void {
    const self = @fieldParentPtr(Xoroshiro128, "random", r);

    var i: usize = 0;
    const aligned_len = buf.len - (buf.len & 7);

    // Complete 8 byte segments.
    while (i < aligned_len) : (i += 8) {
        var n = self.next();
        comptime var j: usize = 0;
        inline while (j < 8) : (j += 1) {
            buf[i + j] = @truncate(u8, n);
            n >>= 8;
        }
    }

    // Remaining. (cuts the stream)
    if (i != buf.len) {
        var n = self.next();
        while (i < buf.len) : (i += 1) {
            buf[i] = @truncate(u8, n);
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
        0x81001a1198a3c2d6,
        0xac1d84b223f779f1,
        0xebfc3dcd3497f9d1,
        0xc2e2ebbeaf498205,
        0x4c5850efa7c314cd,
    };

    for (seq1) |s| {
        try std.testing.expect(s == r.next());
    }

    r.jump();

    const seq2 = [_]u64{
        0x2c172522b78cc43c,
        0x4911df6309f1fb47,
        0xfaf678fd1b4e4317,
        0xfdb1577c26c1aa96,
        0x7ed7faeb0d2abf2a,
        0x8144aa8853fb6013,
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
        0x81001a1198a3c2d6,
        0xac1d84b223f779f1,
        0xebfc3dcd3497f9d1,
        0xc2e2ebbeaf498205,
        0x4c5850efa7c314cd,
    };

    for (seq) |s| {
        var buf0: [8]u8 = undefined;
        var buf1: [7]u8 = undefined;
        std.mem.writeIntLittle(u64, &buf0, s);
        Xoroshiro128.fill(&r.random, &buf1);
        try std.testing.expect(std.mem.eql(u8, buf0[0..7], buf1[0..]));
    }
}
