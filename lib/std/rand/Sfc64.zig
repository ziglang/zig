// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! Sfc64 pseudo-random number generator from Practically Random.
//! Fastest engine of pracrand and smallest footprint.
//! See http://pracrand.sourceforge.net/

const std = @import("std");
const Random = std.rand.Random;
const math = std.math;
const Sfc64 = @This();

random: Random,

a: u64 = undefined,
b: u64 = undefined,
c: u64 = undefined,
counter: u64 = undefined,

const Rotation = 24;
const RightShift = 11;
const LeftShift = 3;

pub fn init(init_s: u64) Sfc64 {
    var x = Sfc64{
        .random = Random{ .fillFn = fill },
    };

    x.seed(init_s);
    return x;
}

fn next(self: *Sfc64) u64 {
    const tmp = self.a +% self.b +% self.counter;
    self.counter += 1;
    self.a = self.b ^ (self.b >> RightShift);
    self.b = self.c +% (self.c << LeftShift);
    self.c = math.rotl(u64, self.c, Rotation) +% tmp;
    return tmp;
}

fn seed(self: *Sfc64, init_s: u64) void {
    self.a = init_s;
    self.b = init_s;
    self.c = init_s;
    self.counter = 1;
    var i: u32 = 0;
    while (i < 12) : (i += 1) {
        _ = self.next();
    }
}

fn fill(r: *Random, buf: []u8) void {
    const self = @fieldParentPtr(Sfc64, "random", r);

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

test "Sfc64 sequence" {
    // Unfortunately there does not seem to be an official test sequence.
    var r = Sfc64.init(0);

    const seq = [_]u64{
        0x3acfa029e3cc6041,
        0xf5b6515bf2ee419c,
        0x1259635894a29b61,
        0xb6ae75395f8ebd6,
        0x225622285ce302e2,
        0x520d28611395cb21,
        0xdb909c818901599d,
        0x8ffd195365216f57,
        0xe8c4ad5e258ac04a,
        0x8f8ef2c89fdb63ca,
        0xf9865b01d98d8e2f,
        0x46555871a65d08ba,
        0x66868677c6298fcd,
        0x2ce15a7e6329f57d,
        0xb2f1833ca91ca79,
        0x4b0890ac9bf453ca,
    };

    for (seq) |s| {
        std.testing.expectEqual(s, r.next());
    }
}
