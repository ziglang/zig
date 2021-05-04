// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! ISAAC64 - http://www.burtleburtle.net/bob/rand/isaacafa.html
//!
//! Follows the general idea of the implementation from here with a few shortcuts.
//! https://doc.rust-lang.org/rand/src/rand/prng/isaac64.rs.html

const std = @import("std");
const Random = std.rand.Random;
const mem = std.mem;
const Isaac64 = @This();

random: Random,

r: [256]u64,
m: [256]u64,
a: u64,
b: u64,
c: u64,
i: usize,

pub fn init(init_s: u64) Isaac64 {
    var isaac = Isaac64{
        .random = Random{ .fillFn = fill },
        .r = undefined,
        .m = undefined,
        .a = undefined,
        .b = undefined,
        .c = undefined,
        .i = undefined,
    };

    // seed == 0 => same result as the unseeded reference implementation
    isaac.seed(init_s, 1);
    return isaac;
}

fn step(self: *Isaac64, mix: u64, base: usize, comptime m1: usize, comptime m2: usize) void {
    const x = self.m[base + m1];
    self.a = mix +% self.m[base + m2];

    const y = self.a +% self.b +% self.m[@intCast(usize, (x >> 3) % self.m.len)];
    self.m[base + m1] = y;

    self.b = x +% self.m[@intCast(usize, (y >> 11) % self.m.len)];
    self.r[self.r.len - 1 - base - m1] = self.b;
}

fn refill(self: *Isaac64) void {
    const midpoint = self.r.len / 2;

    self.c +%= 1;
    self.b +%= self.c;

    {
        var i: usize = 0;
        while (i < midpoint) : (i += 4) {
            self.step(~(self.a ^ (self.a << 21)), i + 0, 0, midpoint);
            self.step(self.a ^ (self.a >> 5), i + 1, 0, midpoint);
            self.step(self.a ^ (self.a << 12), i + 2, 0, midpoint);
            self.step(self.a ^ (self.a >> 33), i + 3, 0, midpoint);
        }
    }

    {
        var i: usize = 0;
        while (i < midpoint) : (i += 4) {
            self.step(~(self.a ^ (self.a << 21)), i + 0, midpoint, 0);
            self.step(self.a ^ (self.a >> 5), i + 1, midpoint, 0);
            self.step(self.a ^ (self.a << 12), i + 2, midpoint, 0);
            self.step(self.a ^ (self.a >> 33), i + 3, midpoint, 0);
        }
    }

    self.i = 0;
}

fn next(self: *Isaac64) u64 {
    if (self.i >= self.r.len) {
        self.refill();
    }

    const value = self.r[self.i];
    self.i += 1;
    return value;
}

fn seed(self: *Isaac64, init_s: u64, comptime rounds: usize) void {
    // We ignore the multi-pass requirement since we don't currently expose full access to
    // seeding the self.m array completely.
    mem.set(u64, self.m[0..], 0);
    self.m[0] = init_s;

    // prescrambled golden ratio constants
    var a = [_]u64{
        0x647c4677a2884b7c,
        0xb9f8b322c73ac862,
        0x8c0ea5053d4712a0,
        0xb29b2e824a595524,
        0x82f053db8355e0ce,
        0x48fe4a0fa5a09315,
        0xae985bf2cbfc89ed,
        0x98f5704f6c44c0ab,
    };

    comptime var i: usize = 0;
    inline while (i < rounds) : (i += 1) {
        var j: usize = 0;
        while (j < self.m.len) : (j += 8) {
            comptime var x1: usize = 0;
            inline while (x1 < 8) : (x1 += 1) {
                a[x1] +%= self.m[j + x1];
            }

            a[0] -%= a[4];
            a[5] ^= a[7] >> 9;
            a[7] +%= a[0];
            a[1] -%= a[5];
            a[6] ^= a[0] << 9;
            a[0] +%= a[1];
            a[2] -%= a[6];
            a[7] ^= a[1] >> 23;
            a[1] +%= a[2];
            a[3] -%= a[7];
            a[0] ^= a[2] << 15;
            a[2] +%= a[3];
            a[4] -%= a[0];
            a[1] ^= a[3] >> 14;
            a[3] +%= a[4];
            a[5] -%= a[1];
            a[2] ^= a[4] << 20;
            a[4] +%= a[5];
            a[6] -%= a[2];
            a[3] ^= a[5] >> 17;
            a[5] +%= a[6];
            a[7] -%= a[3];
            a[4] ^= a[6] << 14;
            a[6] +%= a[7];

            comptime var x2: usize = 0;
            inline while (x2 < 8) : (x2 += 1) {
                self.m[j + x2] = a[x2];
            }
        }
    }

    mem.set(u64, self.r[0..], 0);
    self.a = 0;
    self.b = 0;
    self.c = 0;
    self.i = self.r.len; // trigger refill on first value
}

fn fill(r: *Random, buf: []u8) void {
    const self = @fieldParentPtr(Isaac64, "random", r);

    var i: usize = 0;
    const aligned_len = buf.len - (buf.len & 7);

    // Fill complete 64-byte segments
    while (i < aligned_len) : (i += 8) {
        var n = self.next();
        comptime var j: usize = 0;
        inline while (j < 8) : (j += 1) {
            buf[i + j] = @truncate(u8, n);
            n >>= 8;
        }
    }

    // Fill trailing, ignoring excess (cut the stream).
    if (i != buf.len) {
        var n = self.next();
        while (i < buf.len) : (i += 1) {
            buf[i] = @truncate(u8, n);
            n >>= 8;
        }
    }
}

test "isaac64 sequence" {
    var r = Isaac64.init(0);

    // from reference implementation
    const seq = [_]u64{
        0xf67dfba498e4937c,
        0x84a5066a9204f380,
        0xfee34bd5f5514dbb,
        0x4d1664739b8f80d6,
        0x8607459ab52a14aa,
        0x0e78bc5a98529e49,
        0xfe5332822ad13777,
        0x556c27525e33d01a,
        0x08643ca615f3149f,
        0xd0771faf3cb04714,
        0x30e86f68a37b008d,
        0x3074ebc0488a3adf,
        0x270645ea7a2790bc,
        0x5601a0a8d3763c6a,
        0x2f83071f53f325dd,
        0xb9090f3d42d2d2ea,
    };

    for (seq) |s| {
        try std.testing.expect(s == r.next());
    }
}

test "isaac64 fill" {
    var r = Isaac64.init(0);

    // from reference implementation
    const seq = [_]u64{
        0xf67dfba498e4937c,
        0x84a5066a9204f380,
        0xfee34bd5f5514dbb,
        0x4d1664739b8f80d6,
        0x8607459ab52a14aa,
        0x0e78bc5a98529e49,
        0xfe5332822ad13777,
        0x556c27525e33d01a,
        0x08643ca615f3149f,
        0xd0771faf3cb04714,
        0x30e86f68a37b008d,
        0x3074ebc0488a3adf,
        0x270645ea7a2790bc,
        0x5601a0a8d3763c6a,
        0x2f83071f53f325dd,
        0xb9090f3d42d2d2ea,
    };

    for (seq) |s| {
        var buf0: [8]u8 = undefined;
        var buf1: [7]u8 = undefined;
        std.mem.writeIntLittle(u64, &buf0, s);
        Isaac64.fill(&r.random, &buf1);
        try std.testing.expect(std.mem.eql(u8, buf0[0..7], buf1[0..]));
    }
}
