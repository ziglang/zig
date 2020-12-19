// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! PCG32 - http://www.pcg-random.org/
//!
//! PRNG

const std = @import("std");
const Random = std.rand.Random;
const Pcg = @This();

const default_multiplier = 6364136223846793005;

random: Random,

s: u64,
i: u64,

pub fn init(init_s: u64) Pcg {
    var pcg = Pcg{
        .random = Random{ .fillFn = fill },
        .s = undefined,
        .i = undefined,
    };

    pcg.seed(init_s);
    return pcg;
}

fn next(self: *Pcg) u32 {
    const l = self.s;
    self.s = l *% default_multiplier +% (self.i | 1);

    const xor_s = @truncate(u32, ((l >> 18) ^ l) >> 27);
    const rot = @intCast(u32, l >> 59);

    return (xor_s >> @intCast(u5, rot)) | (xor_s << @intCast(u5, (0 -% rot) & 31));
}

fn seed(self: *Pcg, init_s: u64) void {
    // Pcg requires 128-bits of seed.
    var gen = std.rand.SplitMix64.init(init_s);
    self.seedTwo(gen.next(), gen.next());
}

fn seedTwo(self: *Pcg, init_s: u64, init_i: u64) void {
    self.s = 0;
    self.i = (init_s << 1) | 1;
    self.s = self.s *% default_multiplier +% self.i;
    self.s +%= init_i;
    self.s = self.s *% default_multiplier +% self.i;
}

fn fill(r: *Random, buf: []u8) void {
    const self = @fieldParentPtr(Pcg, "random", r);

    var i: usize = 0;
    const aligned_len = buf.len - (buf.len & 7);

    // Complete 4 byte segments.
    while (i < aligned_len) : (i += 4) {
        var n = self.next();
        comptime var j: usize = 0;
        inline while (j < 4) : (j += 1) {
            buf[i + j] = @truncate(u8, n);
            n >>= 8;
        }
    }

    // Remaining. (cuts the stream)
    if (i != buf.len) {
        var n = self.next();
        while (i < buf.len) : (i += 1) {
            buf[i] = @truncate(u8, n);
            n >>= 4;
        }
    }
}

test "pcg sequence" {
    var r = Pcg.init(0);
    const s0: u64 = 0x9394bf54ce5d79de;
    const s1: u64 = 0x84e9c579ef59bbf7;
    r.seedTwo(s0, s1);

    const seq = [_]u32{
        2881561918,
        3063928540,
        1199791034,
        2487695858,
        1479648952,
        3247963454,
    };

    for (seq) |s| {
        std.testing.expect(s == r.next());
    }
}
