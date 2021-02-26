// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! The engines provided here should be initialized from an external source.
//! For a thread-local cryptographically secure pseudo random number generator,
//! use `std.crypto.random`.
//! Be sure to use a CSPRNG when required, otherwise using a normal PRNG will
//! be faster and use substantially less stack space.
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

pub const Isaac64 = @import("rand/Isaac64.zig");
pub const Gimli = @import("rand/Gimli.zig");
pub const Pcg = @import("rand/Pcg.zig");
pub const Xoroshiro128 = @import("rand/Xoroshiro128.zig");
pub const Sfc64 = @import("rand/Sfc64.zig");

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
        comptime assert(@typeInfo(T).Int.signedness == .unsigned);
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
        comptime assert(@typeInfo(T).Int.signedness == .unsigned);
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
        assert(@typeInfo(T).Int.signedness == .unsigned);
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
        assert(@typeInfo(T).Int.signedness == .unsigned);
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
        if (info.signedness == .signed) {
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
        if (info.signedness == .signed) {
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
        if (info.signedness == .signed) {
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
        if (info.signedness == .signed) {
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
    comptime assert(@typeInfo(T).Int.signedness == .unsigned);
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
pub const SplitMix64 = struct {
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
    std.crypto.random.bytes(&secret_seed);
    var csprng = DefaultCsprng.init(secret_seed);
    const a = csprng.random.int(u64);
    const b = csprng.random.int(u64);
    const c = csprng.random.int(u64);
    expect(a ^ b ^ c != 0);
}

test {
    std.testing.refAllDecls(@This());
}
