// The engines provided here should be initialized from an external source. For now, getRandomBytes
// from the os package is the most suitable. Be sure to use a CSPRNG when required, otherwise using
// a normal PRNG will be faster and use substantially less stack space.
//
// ```
// var buf: [8]u8 = undefined;
// try std.os.getRandomBytes(buf[0..]);
// const seed = mem.readInt(buf[0..8], u64, builtin.Endian.Little);
//
// var r = DefaultPrng.init(seed);
//
// const s = r.random.scalar(u64);
// ```
//
// TODO(tiehuis): Benchmark these against other reference implementations.

const std = @import("../index.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const math = std.math;
const ziggurat = @import("ziggurat.zig");

// When you need fast unbiased random numbers
pub const DefaultPrng = Xoroshiro128;

// When you need cryptographically secure random numbers
pub const DefaultCsprng = Isaac64;

pub const Random = struct {
    fillFn: fn (r: *Random, buf: []u8) void,

    /// Read random bytes into the specified buffer until fill.
    pub fn bytes(r: *Random, buf: []u8) void {
        r.fillFn(r, buf);
    }

    /// Return a random integer/boolean type.
    pub fn scalar(r: *Random, comptime T: type) T {
        var rand_bytes: [@sizeOf(T)]u8 = undefined;
        r.bytes(rand_bytes[0..]);

        if (T == bool) {
            return rand_bytes[0] & 0b1 == 0;
        } else {
            // NOTE: Cannot @bitCast array to integer type.
            return mem.readInt(rand_bytes, T, builtin.Endian.Little);
        }
    }

    /// Get a random unsigned integer with even distribution between `start`
    /// inclusive and `end` exclusive.
    pub fn range(r: *Random, comptime T: type, start: T, end: T) T {
        assert(start <= end);
        if (T.is_signed) {
            const uint = @IntType(false, T.bit_count);
            if (start >= 0 and end >= 0) {
                return @intCast(T, r.range(uint, @intCast(uint, start), @intCast(uint, end)));
            } else if (start < 0 and end < 0) {
                // Can't overflow because the range is over signed ints
                return math.negateCast(r.range(uint, math.absCast(end), math.absCast(start)) + 1) catch unreachable;
            } else if (start < 0 and end >= 0) {
                const end_uint = @intCast(uint, end);
                const total_range = math.absCast(start) + end_uint;
                const value = r.range(uint, 0, total_range);
                const result = if (value < end_uint) x: {
                    break :x @intCast(T, value);
                } else if (value == end_uint) x: {
                    break :x start;
                } else x: {
                    // Can't overflow because the range is over signed ints
                    break :x math.negateCast(value - end_uint) catch unreachable;
                };
                return result;
            } else {
                unreachable;
            }
        } else {
            const total_range = end - start;
            const leftover = @maxValue(T) % total_range;
            const upper_bound = @maxValue(T) - leftover;
            var rand_val_array: [@sizeOf(T)]u8 = undefined;

            while (true) {
                r.bytes(rand_val_array[0..]);
                const rand_val = mem.readInt(rand_val_array, T, builtin.Endian.Little);
                if (rand_val < upper_bound) {
                    return start + (rand_val % total_range);
                }
            }
        }
    }

    /// Return a floating point value evenly distributed in the range [0, 1).
    pub fn float(r: *Random, comptime T: type) T {
        // Generate a uniform value between [1, 2) and scale down to [0, 1).
        // Note: The lowest mantissa bit is always set to 0 so we only use half the available range.
        switch (T) {
            f32 => {
                const s = r.scalar(u32);
                const repr = (0x7f << 23) | (s >> 9);
                return @bitCast(f32, repr) - 1.0;
            },
            f64 => {
                const s = r.scalar(u64);
                const repr = (0x3ff << 52) | (s >> 12);
                return @bitCast(f64, repr) - 1.0;
            },
            else => @compileError("unknown floating point type"),
        }
    }

    /// Return a floating point value normally distributed with mean = 0, stddev = 1.
    ///
    /// To use different parameters, use: floatNorm(...) * desiredStddev + desiredMean.
    pub fn floatNorm(r: *Random, comptime T: type) T {
        const value = ziggurat.next_f64(r, ziggurat.NormDist);
        switch (T) {
            f32 => return @floatCast(f32, value),
            f64 => return value,
            else => @compileError("unknown floating point type"),
        }
    }

    /// Return an exponentially distributed float with a rate parameter of 1.
    ///
    /// To use a different rate parameter, use: floatExp(...) / desiredRate.
    pub fn floatExp(r: *Random, comptime T: type) T {
        const value = ziggurat.next_f64(r, ziggurat.ExpDist);
        switch (T) {
            f32 => return @floatCast(f32, value),
            f64 => return value,
            else => @compileError("unknown floating point type"),
        }
    }

    /// Shuffle a slice into a random order.
    pub fn shuffle(r: *Random, comptime T: type, buf: []T) void {
        if (buf.len < 2) {
            return;
        }

        var i: usize = 0;
        while (i < buf.len - 1) : (i += 1) {
            const j = r.range(usize, i, buf.len);
            mem.swap(T, &buf[i], &buf[j]);
        }
    }
};

// Generator to extend 64-bit seed values into longer sequences.
//
// The number of cycles is thus limited to 64-bits regardless of the engine, but this
// is still plenty for practical purposes.
const SplitMix64 = struct {
    s: u64,

    pub fn init(seed: u64) SplitMix64 {
        return SplitMix64{ .s = seed };
    }

    pub fn next(self: *SplitMix64) u64 {
        self.s +%= 0x9e3779b97f4a7c15;

        var z = self.s;
        z = (z ^ (z >> 30)) *% 0xbf58476d1ce4e5b9;
        z = (z ^ (z >> 27)) *% 0x94d049bb133111eb;
        return z ^ (z >> 31);
    }
};

test "splitmix64 sequence" {
    var r = SplitMix64.init(0xaeecf86f7878dd75);

    const seq = []const u64{
        0x5dbd39db0178eb44,
        0xa9900fb66b397da3,
        0x5c1a28b1aeebcf5c,
        0x64a963238f776912,
        0xc6d4177b21d1c0ab,
        0xb2cbdbdb5ea35394,
    };

    for (seq) |s| {
        std.debug.assert(s == r.next());
    }
}

// PCG32 - http://www.pcg-random.org/
//
// PRNG
pub const Pcg = struct {
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
        var gen = SplitMix64.init(init_s);
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
};

test "pcg sequence" {
    var r = Pcg.init(0);
    const s0: u64 = 0x9394bf54ce5d79de;
    const s1: u64 = 0x84e9c579ef59bbf7;
    r.seedTwo(s0, s1);

    const seq = []const u32{
        2881561918,
        3063928540,
        1199791034,
        2487695858,
        1479648952,
        3247963454,
    };

    for (seq) |s| {
        std.debug.assert(s == r.next());
    }
}

// Xoroshiro128+ - http://xoroshiro.di.unimi.it/
//
// PRNG
pub const Xoroshiro128 = struct {
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
        self.s[0] = math.rotl(u64, s0, u8(55)) ^ s1 ^ (s1 << 14);
        self.s[1] = math.rotl(u64, s1, u8(36));

        return r;
    }

    // Skip 2^64 places ahead in the sequence
    fn jump(self: *Xoroshiro128) void {
        var s0: u64 = 0;
        var s1: u64 = 0;

        const table = []const u64{
            0xbeac0467eba5facb,
            0xd86b048b86aa9922,
        };

        inline for (table) |entry| {
            var b: usize = 0;
            while (b < 64) : (b += 1) {
                if ((entry & (u64(1) << @intCast(u6, b))) != 0) {
                    s0 ^= self.s[0];
                    s1 ^= self.s[1];
                }
                _ = self.next();
            }
        }

        self.s[0] = s0;
        self.s[1] = s1;
    }

    fn seed(self: *Xoroshiro128, init_s: u64) void {
        // Xoroshiro requires 128-bits of seed.
        var gen = SplitMix64.init(init_s);

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
};

test "xoroshiro sequence" {
    var r = Xoroshiro128.init(0);
    r.s[0] = 0xaeecf86f7878dd75;
    r.s[1] = 0x01cd153642e72622;

    const seq1 = []const u64{
        0xb0ba0da5bb600397,
        0x18a08afde614dccc,
        0xa2635b956a31b929,
        0xabe633c971efa045,
        0x9ac19f9706ca3cac,
        0xf62b426578c1e3fb,
    };

    for (seq1) |s| {
        std.debug.assert(s == r.next());
    }

    r.jump();

    const seq2 = []const u64{
        0x95344a13556d3e22,
        0xb4fb32dafa4d00df,
        0xb2011d9ccdcfe2dd,
        0x05679a9b2119b908,
        0xa860a1da7c9cd8a0,
        0x658a96efe3f86550,
    };

    for (seq2) |s| {
        std.debug.assert(s == r.next());
    }
}

// ISAAC64 - http://www.burtleburtle.net/bob/rand/isaacafa.html
//
// CSPRNG
//
// Follows the general idea of the implementation from here with a few shortcuts.
// https://doc.rust-lang.org/rand/src/rand/prng/isaac64.rs.html
pub const Isaac64 = struct {
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

        const y = self.a +% self.b +% self.m[(x >> 3) % self.m.len];
        self.m[base + m1] = y;

        self.b = x +% self.m[(y >> 11) % self.m.len];
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
        var a = []const u64{
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
};

test "isaac64 sequence" {
    var r = Isaac64.init(0);

    // from reference implementation
    const seq = []const u64{
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
        std.debug.assert(s == r.next());
    }
}

// Actual Random helper function tests, pcg engine is assumed correct.
test "Random float" {
    var prng = DefaultPrng.init(0);

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const val1 = prng.random.float(f32);
        std.debug.assert(val1 >= 0.0);
        std.debug.assert(val1 < 1.0);

        const val2 = prng.random.float(f64);
        std.debug.assert(val2 >= 0.0);
        std.debug.assert(val2 < 1.0);
    }
}

test "Random scalar" {
    var prng = DefaultPrng.init(0);
    const s = prng.random.scalar(u64);
}

test "Random bytes" {
    var prng = DefaultPrng.init(0);
    var buf: [2048]u8 = undefined;
    prng.random.bytes(buf[0..]);
}

test "Random shuffle" {
    var prng = DefaultPrng.init(0);

    var seq = []const u8{ 0, 1, 2, 3, 4 };
    var seen = []bool{false} ** 5;

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        prng.random.shuffle(u8, seq[0..]);
        seen[seq[0]] = true;
        std.debug.assert(sumArray(seq[0..]) == 10);
    }

    // we should see every entry at the head at least once
    for (seen) |e| {
        std.debug.assert(e == true);
    }
}

fn sumArray(s: []const u8) u32 {
    var r: u32 = 0;
    for (s) |e|
        r += e;
    return r;
}

test "Random range" {
    var prng = DefaultPrng.init(0);
    testRange(&prng.random, -4, 3);
    testRange(&prng.random, -4, -1);
    testRange(&prng.random, 10, 14);
}

fn testRange(r: *Random, start: i32, end: i32) void {
    const count = @intCast(usize, end - start);
    var values_buffer = []bool{false} ** 20;
    const values = values_buffer[0..count];
    var i: usize = 0;
    while (i < count) {
        const value = r.range(i32, start, end);
        const index = @intCast(usize, value - start);
        if (!values[index]) {
            i += 1;
            values[index] = true;
        }
    }
}
