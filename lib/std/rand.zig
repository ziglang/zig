// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! The engines provided here should be initialized from an external source. For now, randomBytes
//! from the crypto package is the most suitable. Be sure to use a CSPRNG when required, otherwise using
//! a normal PRNG will be faster and use substantially less stack space.
//!
//! ```
//! var buf: [8]u8 = undefined;
//! try std.crypto.randomBytes(buf[0..]);
//! const seed = mem.readIntLittle(u64, buf[0..8]);
//!
//! var r = DefaultPrng.init(seed);
//!
//! const s = r.random.int(u64);
//! ```
//!
//! TODO(tiehuis): Benchmark these against other reference implementations.

const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;
const math = std.math;
const ziggurat = @import("rand/ziggurat.zig");
const maxInt = std.math.maxInt;

/// Fast unbiased random numbers.
pub const DefaultPrng = Xoroshiro128;

/// Cryptographically secure random numbers.
pub const DefaultCsprng = Gimli;

pub const Random = struct {
    fillFn: fn (r: *Random, buf: []u8) void,

    /// Read random bytes into the specified buffer until full.
    pub fn bytes(r: *Random, buf: []u8) void {
        r.fillFn(r, buf);
    }

    pub fn boolean(r: *Random) bool {
        return r.int(u1) != 0;
    }

    /// Returns a random int `i` such that `0 <= i <= maxInt(T)`.
    /// `i` is evenly distributed.
    pub fn int(r: *Random, comptime T: type) T {
        const bits = @typeInfo(T).Int.bits;
        const UnsignedT = std.meta.Int(.unsigned, bits);
        const ByteAlignedT = std.meta.Int(.unsigned, @divTrunc(bits + 7, 8) * 8);

        var rand_bytes: [@sizeOf(ByteAlignedT)]u8 = undefined;
        r.bytes(rand_bytes[0..]);

        // use LE instead of native endian for better portability maybe?
        // TODO: endian portability is pointless if the underlying prng isn't endian portable.
        // TODO: document the endian portability of this library.
        const byte_aligned_result = mem.readIntSliceLittle(ByteAlignedT, &rand_bytes);
        const unsigned_result = @truncate(UnsignedT, byte_aligned_result);
        return @bitCast(T, unsigned_result);
    }

    /// Constant-time implementation off `uintLessThan`.
    /// The results of this function may be biased.
    pub fn uintLessThanBiased(r: *Random, comptime T: type, less_than: T) T {
        comptime assert(@typeInfo(T).Int.is_signed == false);
        const bits = @typeInfo(T).Int.bits;
        comptime assert(bits <= 64); // TODO: workaround: LLVM ERROR: Unsupported library call operation!
        assert(0 < less_than);
        if (bits <= 32) {
            return @intCast(T, limitRangeBiased(u32, r.int(u32), less_than));
        } else {
            return @intCast(T, limitRangeBiased(u64, r.int(u64), less_than));
        }
    }

    /// Returns an evenly distributed random unsigned integer `0 <= i < less_than`.
    /// This function assumes that the underlying `fillFn` produces evenly distributed values.
    /// Within this assumption, the runtime of this function is exponentially distributed.
    /// If `fillFn` were backed by a true random generator,
    /// the runtime of this function would technically be unbounded.
    /// However, if `fillFn` is backed by any evenly distributed pseudo random number generator,
    /// this function is guaranteed to return.
    /// If you need deterministic runtime bounds, use `uintLessThanBiased`.
    pub fn uintLessThan(r: *Random, comptime T: type, less_than: T) T {
        comptime assert(@typeInfo(T).Int.is_signed == false);
        const bits = @typeInfo(T).Int.bits;
        comptime assert(bits <= 64); // TODO: workaround: LLVM ERROR: Unsupported library call operation!
        assert(0 < less_than);
        // Small is typically u32
        const small_bits = @divTrunc(bits + 31, 32) * 32;
        const Small = std.meta.Int(.unsigned, small_bits);
        // Large is typically u64
        const Large = std.meta.Int(.unsigned, small_bits * 2);

        // adapted from:
        //   http://www.pcg-random.org/posts/bounded-rands.html
        //   "Lemire's (with an extra tweak from me)"
        var x: Small = r.int(Small);
        var m: Large = @as(Large, x) * @as(Large, less_than);
        var l: Small = @truncate(Small, m);
        if (l < less_than) {
            // TODO: workaround for https://github.com/ziglang/zig/issues/1770
            // should be:
            //   var t: Small = -%less_than;
            var t: Small = @bitCast(Small, -%@bitCast(std.meta.Int(.signed, small_bits), @as(Small, less_than)));

            if (t >= less_than) {
                t -= less_than;
                if (t >= less_than) {
                    t %= less_than;
                }
            }
            while (l < t) {
                x = r.int(Small);
                m = @as(Large, x) * @as(Large, less_than);
                l = @truncate(Small, m);
            }
        }
        return @intCast(T, m >> small_bits);
    }

    /// Constant-time implementation off `uintAtMost`.
    /// The results of this function may be biased.
    pub fn uintAtMostBiased(r: *Random, comptime T: type, at_most: T) T {
        assert(@typeInfo(T).Int.is_signed == false);
        if (at_most == maxInt(T)) {
            // have the full range
            return r.int(T);
        }
        return r.uintLessThanBiased(T, at_most + 1);
    }

    /// Returns an evenly distributed random unsigned integer `0 <= i <= at_most`.
    /// See `uintLessThan`, which this function uses in most cases,
    /// for commentary on the runtime of this function.
    pub fn uintAtMost(r: *Random, comptime T: type, at_most: T) T {
        assert(@typeInfo(T).Int.is_signed == false);
        if (at_most == maxInt(T)) {
            // have the full range
            return r.int(T);
        }
        return r.uintLessThan(T, at_most + 1);
    }

    /// Constant-time implementation off `intRangeLessThan`.
    /// The results of this function may be biased.
    pub fn intRangeLessThanBiased(r: *Random, comptime T: type, at_least: T, less_than: T) T {
        assert(at_least < less_than);
        const info = @typeInfo(T).Int;
        if (info.is_signed) {
            // Two's complement makes this math pretty easy.
            const UnsignedT = std.meta.Int(.unsigned, info.bits);
            const lo = @bitCast(UnsignedT, at_least);
            const hi = @bitCast(UnsignedT, less_than);
            const result = lo +% r.uintLessThanBiased(UnsignedT, hi -% lo);
            return @bitCast(T, result);
        } else {
            // The signed implementation would work fine, but we can use stricter arithmetic operators here.
            return at_least + r.uintLessThanBiased(T, less_than - at_least);
        }
    }

    /// Returns an evenly distributed random integer `at_least <= i < less_than`.
    /// See `uintLessThan`, which this function uses in most cases,
    /// for commentary on the runtime of this function.
    pub fn intRangeLessThan(r: *Random, comptime T: type, at_least: T, less_than: T) T {
        assert(at_least < less_than);
        const info = @typeInfo(T).Int;
        if (info.is_signed) {
            // Two's complement makes this math pretty easy.
            const UnsignedT = std.meta.Int(.unsigned, info.bits);
            const lo = @bitCast(UnsignedT, at_least);
            const hi = @bitCast(UnsignedT, less_than);
            const result = lo +% r.uintLessThan(UnsignedT, hi -% lo);
            return @bitCast(T, result);
        } else {
            // The signed implementation would work fine, but we can use stricter arithmetic operators here.
            return at_least + r.uintLessThan(T, less_than - at_least);
        }
    }

    /// Constant-time implementation off `intRangeAtMostBiased`.
    /// The results of this function may be biased.
    pub fn intRangeAtMostBiased(r: *Random, comptime T: type, at_least: T, at_most: T) T {
        assert(at_least <= at_most);
        const info = @typeInfo(T).Int;
        if (info.is_signed) {
            // Two's complement makes this math pretty easy.
            const UnsignedT = std.meta.Int(.unsigned, info.bits);
            const lo = @bitCast(UnsignedT, at_least);
            const hi = @bitCast(UnsignedT, at_most);
            const result = lo +% r.uintAtMostBiased(UnsignedT, hi -% lo);
            return @bitCast(T, result);
        } else {
            // The signed implementation would work fine, but we can use stricter arithmetic operators here.
            return at_least + r.uintAtMostBiased(T, at_most - at_least);
        }
    }

    /// Returns an evenly distributed random integer `at_least <= i <= at_most`.
    /// See `uintLessThan`, which this function uses in most cases,
    /// for commentary on the runtime of this function.
    pub fn intRangeAtMost(r: *Random, comptime T: type, at_least: T, at_most: T) T {
        assert(at_least <= at_most);
        const info = @typeInfo(T).Int;
        if (info.is_signed) {
            // Two's complement makes this math pretty easy.
            const UnsignedT = std.meta.Int(.unsigned, info.bits);
            const lo = @bitCast(UnsignedT, at_least);
            const hi = @bitCast(UnsignedT, at_most);
            const result = lo +% r.uintAtMost(UnsignedT, hi -% lo);
            return @bitCast(T, result);
        } else {
            // The signed implementation would work fine, but we can use stricter arithmetic operators here.
            return at_least + r.uintAtMost(T, at_most - at_least);
        }
    }

    pub const scalar = @compileError("deprecated; use boolean() or int() instead");

    pub const range = @compileError("deprecated; use intRangeLessThan()");

    /// Return a floating point value evenly distributed in the range [0, 1).
    pub fn float(r: *Random, comptime T: type) T {
        // Generate a uniform value between [1, 2) and scale down to [0, 1).
        // Note: The lowest mantissa bit is always set to 0 so we only use half the available range.
        switch (T) {
            f32 => {
                const s = r.int(u32);
                const repr = (0x7f << 23) | (s >> 9);
                return @bitCast(f32, repr) - 1.0;
            },
            f64 => {
                const s = r.int(u64);
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
            const j = r.intRangeLessThan(usize, i, buf.len);
            mem.swap(T, &buf[i], &buf[j]);
        }
    }
};

/// Convert a random integer 0 <= random_int <= maxValue(T),
/// into an integer 0 <= result < less_than.
/// This function introduces a minor bias.
pub fn limitRangeBiased(comptime T: type, random_int: T, less_than: T) T {
    comptime assert(@typeInfo(T).Int.is_signed == false);
    const bits = @typeInfo(T).Int.bits;
    const T2 = std.meta.Int(.unsigned, bits * 2);

    // adapted from:
    //   http://www.pcg-random.org/posts/bounded-rands.html
    //   "Integer Multiplication (Biased)"
    var m: T2 = @as(T2, random_int) * @as(T2, less_than);
    return @intCast(T, m >> bits);
}

const SequentialPrng = struct {
    const Self = @This();
    random: Random,
    next_value: u8,

    pub fn init() Self {
        return Self{
            .random = Random{ .fillFn = fill },
            .next_value = 0,
        };
    }

    fn fill(r: *Random, buf: []u8) void {
        const self = @fieldParentPtr(Self, "random", r);
        for (buf) |*b| {
            b.* = self.next_value;
        }
        self.next_value +%= 1;
    }
};

test "Random int" {
    testRandomInt();
    comptime testRandomInt();
}
fn testRandomInt() void {
    var r = SequentialPrng.init();

    expect(r.random.int(u0) == 0);

    r.next_value = 0;
    expect(r.random.int(u1) == 0);
    expect(r.random.int(u1) == 1);
    expect(r.random.int(u2) == 2);
    expect(r.random.int(u2) == 3);
    expect(r.random.int(u2) == 0);

    r.next_value = 0xff;
    expect(r.random.int(u8) == 0xff);
    r.next_value = 0x11;
    expect(r.random.int(u8) == 0x11);

    r.next_value = 0xff;
    expect(r.random.int(u32) == 0xffffffff);
    r.next_value = 0x11;
    expect(r.random.int(u32) == 0x11111111);

    r.next_value = 0xff;
    expect(r.random.int(i32) == -1);
    r.next_value = 0x11;
    expect(r.random.int(i32) == 0x11111111);

    r.next_value = 0xff;
    expect(r.random.int(i8) == -1);
    r.next_value = 0x11;
    expect(r.random.int(i8) == 0x11);

    r.next_value = 0xff;
    expect(r.random.int(u33) == 0x1ffffffff);
    r.next_value = 0xff;
    expect(r.random.int(i1) == -1);
    r.next_value = 0xff;
    expect(r.random.int(i2) == -1);
    r.next_value = 0xff;
    expect(r.random.int(i33) == -1);
}

test "Random boolean" {
    testRandomBoolean();
    comptime testRandomBoolean();
}
fn testRandomBoolean() void {
    var r = SequentialPrng.init();
    expect(r.random.boolean() == false);
    expect(r.random.boolean() == true);
    expect(r.random.boolean() == false);
    expect(r.random.boolean() == true);
}

test "Random intLessThan" {
    @setEvalBranchQuota(10000);
    testRandomIntLessThan();
    comptime testRandomIntLessThan();
}
fn testRandomIntLessThan() void {
    var r = SequentialPrng.init();
    r.next_value = 0xff;
    expect(r.random.uintLessThan(u8, 4) == 3);
    expect(r.next_value == 0);
    expect(r.random.uintLessThan(u8, 4) == 0);
    expect(r.next_value == 1);

    r.next_value = 0;
    expect(r.random.uintLessThan(u64, 32) == 0);

    // trigger the bias rejection code path
    r.next_value = 0;
    expect(r.random.uintLessThan(u8, 3) == 0);
    // verify we incremented twice
    expect(r.next_value == 2);

    r.next_value = 0xff;
    expect(r.random.intRangeLessThan(u8, 0, 0x80) == 0x7f);
    r.next_value = 0xff;
    expect(r.random.intRangeLessThan(u8, 0x7f, 0xff) == 0xfe);

    r.next_value = 0xff;
    expect(r.random.intRangeLessThan(i8, 0, 0x40) == 0x3f);
    r.next_value = 0xff;
    expect(r.random.intRangeLessThan(i8, -0x40, 0x40) == 0x3f);
    r.next_value = 0xff;
    expect(r.random.intRangeLessThan(i8, -0x80, 0) == -1);

    r.next_value = 0xff;
    expect(r.random.intRangeLessThan(i3, -4, 0) == -1);
    r.next_value = 0xff;
    expect(r.random.intRangeLessThan(i3, -2, 2) == 1);
}

test "Random intAtMost" {
    @setEvalBranchQuota(10000);
    testRandomIntAtMost();
    comptime testRandomIntAtMost();
}
fn testRandomIntAtMost() void {
    var r = SequentialPrng.init();
    r.next_value = 0xff;
    expect(r.random.uintAtMost(u8, 3) == 3);
    expect(r.next_value == 0);
    expect(r.random.uintAtMost(u8, 3) == 0);

    // trigger the bias rejection code path
    r.next_value = 0;
    expect(r.random.uintAtMost(u8, 2) == 0);
    // verify we incremented twice
    expect(r.next_value == 2);

    r.next_value = 0xff;
    expect(r.random.intRangeAtMost(u8, 0, 0x7f) == 0x7f);
    r.next_value = 0xff;
    expect(r.random.intRangeAtMost(u8, 0x7f, 0xfe) == 0xfe);

    r.next_value = 0xff;
    expect(r.random.intRangeAtMost(i8, 0, 0x3f) == 0x3f);
    r.next_value = 0xff;
    expect(r.random.intRangeAtMost(i8, -0x40, 0x3f) == 0x3f);
    r.next_value = 0xff;
    expect(r.random.intRangeAtMost(i8, -0x80, -1) == -1);

    r.next_value = 0xff;
    expect(r.random.intRangeAtMost(i3, -4, -1) == -1);
    r.next_value = 0xff;
    expect(r.random.intRangeAtMost(i3, -2, 1) == 1);

    expect(r.random.uintAtMost(u0, 0) == 0);
}

test "Random Biased" {
    var r = DefaultPrng.init(0);
    // Not thoroughly checking the logic here.
    // Just want to execute all the paths with different types.

    expect(r.random.uintLessThanBiased(u1, 1) == 0);
    expect(r.random.uintLessThanBiased(u32, 10) < 10);
    expect(r.random.uintLessThanBiased(u64, 20) < 20);

    expect(r.random.uintAtMostBiased(u0, 0) == 0);
    expect(r.random.uintAtMostBiased(u1, 0) <= 0);
    expect(r.random.uintAtMostBiased(u32, 10) <= 10);
    expect(r.random.uintAtMostBiased(u64, 20) <= 20);

    expect(r.random.intRangeLessThanBiased(u1, 0, 1) == 0);
    expect(r.random.intRangeLessThanBiased(i1, -1, 0) == -1);
    expect(r.random.intRangeLessThanBiased(u32, 10, 20) >= 10);
    expect(r.random.intRangeLessThanBiased(i32, 10, 20) >= 10);
    expect(r.random.intRangeLessThanBiased(u64, 20, 40) >= 20);
    expect(r.random.intRangeLessThanBiased(i64, 20, 40) >= 20);

    // uncomment for broken module error:
    //expect(r.random.intRangeAtMostBiased(u0, 0, 0) == 0);
    expect(r.random.intRangeAtMostBiased(u1, 0, 1) >= 0);
    expect(r.random.intRangeAtMostBiased(i1, -1, 0) >= -1);
    expect(r.random.intRangeAtMostBiased(u32, 10, 20) >= 10);
    expect(r.random.intRangeAtMostBiased(i32, 10, 20) >= 10);
    expect(r.random.intRangeAtMostBiased(u64, 20, 40) >= 20);
    expect(r.random.intRangeAtMostBiased(i64, 20, 40) >= 20);
}

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

    const seq = [_]u64{
        0x5dbd39db0178eb44,
        0xa9900fb66b397da3,
        0x5c1a28b1aeebcf5c,
        0x64a963238f776912,
        0xc6d4177b21d1c0ab,
        0xb2cbdbdb5ea35394,
    };

    for (seq) |s| {
        expect(s == r.next());
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

    const seq = [_]u32{
        2881561918,
        3063928540,
        1199791034,
        2487695858,
        1479648952,
        3247963454,
    };

    for (seq) |s| {
        expect(s == r.next());
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
        self.s[0] = math.rotl(u64, s0, @as(u8, 55)) ^ s1 ^ (s1 << 14);
        self.s[1] = math.rotl(u64, s1, @as(u8, 36));

        return r;
    }

    // Skip 2^64 places ahead in the sequence
    fn jump(self: *Xoroshiro128) void {
        var s0: u64 = 0;
        var s1: u64 = 0;

        const table = [_]u64{
            0xbeac0467eba5facb,
            0xd86b048b86aa9922,
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

    const seq1 = [_]u64{
        0xb0ba0da5bb600397,
        0x18a08afde614dccc,
        0xa2635b956a31b929,
        0xabe633c971efa045,
        0x9ac19f9706ca3cac,
        0xf62b426578c1e3fb,
    };

    for (seq1) |s| {
        expect(s == r.next());
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
        expect(s == r.next());
    }
}

// Gimli
//
// CSPRNG
pub const Gimli = struct {
    random: Random,
    state: std.crypto.core.Gimli,

    pub const secret_seed_length = 32;

    /// The seed must be uniform, secret and `secret_seed_length` bytes long.
    /// It can be generated using `std.crypto.randomBytes()`.
    pub fn init(secret_seed: [secret_seed_length]u8) Gimli {
        var initial_state: [std.crypto.core.Gimli.BLOCKBYTES]u8 = undefined;
        mem.copy(u8, initial_state[0..secret_seed_length], &secret_seed);
        mem.set(u8, initial_state[secret_seed_length..], 0);
        var self = Gimli{
            .random = Random{ .fillFn = fill },
            .state = std.crypto.core.Gimli.init(initial_state),
        };
        return self;
    }

    fn fill(r: *Random, buf: []u8) void {
        const self = @fieldParentPtr(Gimli, "random", r);

        if (buf.len != 0) {
            self.state.squeeze(buf);
        } else {
            self.state.permute();
        }
        mem.set(u8, self.state.toSlice()[0..std.crypto.core.Gimli.RATE], 0);
    }
};

// ISAAC64 - http://www.burtleburtle.net/bob/rand/isaacafa.html
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
};

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
        expect(s == r.next());
    }
}

/// Sfc64 pseudo-random number generator from Practically Random.
/// Fastest engine of pracrand and smallest footprint.
/// See http://pracrand.sourceforge.net/
pub const Sfc64 = struct {
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
};

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
        expectEqual(s, r.next());
    }
}

// Actual Random helper function tests, pcg engine is assumed correct.
test "Random float" {
    var prng = DefaultPrng.init(0);

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const val1 = prng.random.float(f32);
        expect(val1 >= 0.0);
        expect(val1 < 1.0);

        const val2 = prng.random.float(f64);
        expect(val2 >= 0.0);
        expect(val2 < 1.0);
    }
}

test "Random shuffle" {
    var prng = DefaultPrng.init(0);

    var seq = [_]u8{ 0, 1, 2, 3, 4 };
    var seen = [_]bool{false} ** 5;

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        prng.random.shuffle(u8, seq[0..]);
        seen[seq[0]] = true;
        expect(sumArray(seq[0..]) == 10);
    }

    // we should see every entry at the head at least once
    for (seen) |e| {
        expect(e == true);
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
    testRange(&prng.random, -0x80, 0x7f);
}

fn testRange(r: *Random, start: i8, end: i8) void {
    testRangeBias(r, start, end, true);
    testRangeBias(r, start, end, false);
}
fn testRangeBias(r: *Random, start: i8, end: i8, biased: bool) void {
    const count = @intCast(usize, @as(i32, end) - @as(i32, start));
    var values_buffer = [_]bool{false} ** 0x100;
    const values = values_buffer[0..count];
    var i: usize = 0;
    while (i < count) {
        const value: i32 = if (biased) r.intRangeLessThanBiased(i8, start, end) else r.intRangeLessThan(i8, start, end);
        const index = @intCast(usize, value - start);
        if (!values[index]) {
            i += 1;
            values[index] = true;
        }
    }
}

test "CSPRNG" {
    var secret_seed: [DefaultCsprng.secret_seed_length]u8 = undefined;
    try std.crypto.randomBytes(&secret_seed);
    var csprng = DefaultCsprng.init(secret_seed);
    const a = csprng.random.int(u64);
    const b = csprng.random.int(u64);
    const c = csprng.random.int(u64);
    assert(a ^ b ^ c != 0);
}

test "" {
    std.testing.refAllDecls(@This());
}
