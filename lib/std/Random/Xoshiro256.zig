//! Xoshiro256++ - http://xoroshiro.di.unimi.it/
//!
//! PRNG

const std = @import("std");
const math = std.math;
const Xoshiro256 = @This();

s: [4]u64,

pub fn init(init_s: u64) Xoshiro256 {
    var x = Xoshiro256{
        .s = undefined,
    };

    x.seed(init_s);
    return x;
}

pub fn random(self: *Xoshiro256) std.Random {
    return std.Random.init(self, fill);
}

pub fn next(self: *Xoshiro256) u64 {
    const r = math.rotl(u64, self.s[0] +% self.s[3], 23) +% self.s[0];

    const t = self.s[1] << 17;

    self.s[2] ^= self.s[0];
    self.s[3] ^= self.s[1];
    self.s[1] ^= self.s[2];
    self.s[0] ^= self.s[3];

    self.s[2] ^= t;

    self.s[3] = math.rotl(u64, self.s[3], 45);

    return r;
}

// Skip 2^128 places ahead in the sequence
pub fn jump(self: *Xoshiro256) void {
    var s: u256 = 0;

    var table: u256 = 0x39abdc4529b1661ca9582618e03fc9aad5a61266f0c9392c180ec6d33cfd0aba;

    while (table != 0) : (table >>= 1) {
        if (@as(u1, @truncate(table)) != 0) {
            s ^= @as(u256, @bitCast(self.s));
        }
        _ = self.next();
    }

    self.s = @as([4]u64, @bitCast(s));
}

pub fn seed(self: *Xoshiro256, init_s: u64) void {
    // Xoshiro requires 256-bits of seed.
    var gen = std.Random.SplitMix64.init(init_s);

    self.s[0] = gen.next();
    self.s[1] = gen.next();
    self.s[2] = gen.next();
    self.s[3] = gen.next();
}

pub fn fill(self: *Xoshiro256, buf: []u8) void {
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

test "sequence" {
    if (@import("builtin").zig_backend == .stage2_c) return error.SkipZigTest;

    var r = Xoshiro256.init(0);

    const seq1 = [_]u64{
        0x53175d61490b23df,
        0x61da6f3dc380d507,
        0x5c0fdf91ec9a7bfc,
        0x02eebf8c3bbe5e1a,
        0x7eca04ebaf4a5eea,
        0x0543c37757f08d9a,
    };

    for (seq1) |s| {
        try std.testing.expect(s == r.next());
    }

    r.jump();

    const seq2 = [_]u64{
        0xae1db5c5e27807be,
        0xb584c6a7fd8709fe,
        0xc46a0ee9330fb6e,
        0xdc0c9606f49ed76e,
        0x1f5bb6540f6651fb,
        0x72fa2ca734601488,
    };

    for (seq2) |s| {
        try std.testing.expect(s == r.next());
    }
}

test fill {
    var r = Xoshiro256.init(0);

    const seq = [_]u64{
        0x53175d61490b23df,
        0x61da6f3dc380d507,
        0x5c0fdf91ec9a7bfc,
        0x02eebf8c3bbe5e1a,
        0x7eca04ebaf4a5eea,
        0x0543c37757f08d9a,
    };

    for (seq) |s| {
        var buf0: [8]u8 = undefined;
        var buf1: [7]u8 = undefined;
        std.mem.writeInt(u64, &buf0, s, .little);
        r.fill(&buf1);
        try std.testing.expect(std.mem.eql(u8, buf0[0..7], buf1[0..]));
    }
}
