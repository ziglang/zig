//! PCG32 - http://www.pcg-random.org/
//!
//! PRNG

const std = @import("std");
const Pcg = @This();

const default_multiplier = 6364136223846793005;

s: u64,
i: u64,

pub fn init(init_s: u64) Pcg {
    var pcg = Pcg{
        .s = undefined,
        .i = undefined,
    };

    pcg.seed(init_s);
    return pcg;
}

pub fn random(self: *Pcg) std.Random {
    return std.Random.init(self, fill);
}

fn next(self: *Pcg) u32 {
    const l = self.s;
    self.s = l *% default_multiplier +% (self.i | 1);

    const xor_s: u32 = @truncate(((l >> 18) ^ l) >> 27);
    const rot: u32 = @intCast(l >> 59);

    return (xor_s >> @as(u5, @intCast(rot))) | (xor_s << @as(u5, @intCast((0 -% rot) & 31)));
}

fn seed(self: *Pcg, init_s: u64) void {
    // Pcg requires 128-bits of seed.
    var gen = std.Random.SplitMix64.init(init_s);
    self.seedTwo(gen.next(), gen.next());
}

fn seedTwo(self: *Pcg, init_s: u64, init_i: u64) void {
    self.s = 0;
    self.i = (init_s << 1) | 1;
    self.s = self.s *% default_multiplier +% self.i;
    self.s +%= init_i;
    self.s = self.s *% default_multiplier +% self.i;
}

pub fn fill(self: *Pcg, buf: []u8) void {
    var i: usize = 0;
    const aligned_len = buf.len - (buf.len & 3);

    // Complete 4 byte segments.
    while (i < aligned_len) : (i += 4) {
        var n = self.next();
        comptime var j: usize = 0;
        inline while (j < 4) : (j += 1) {
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
        try std.testing.expect(s == r.next());
    }
}

test fill {
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

    var i: u32 = 0;
    while (i < seq.len) : (i += 2) {
        var buf0: [8]u8 = undefined;
        std.mem.writeInt(u32, buf0[0..4], seq[i], .little);
        std.mem.writeInt(u32, buf0[4..8], seq[i + 1], .little);

        var buf1: [7]u8 = undefined;
        r.fill(&buf1);

        try std.testing.expect(std.mem.eql(u8, buf0[0..7], buf1[0..]));
    }
}
