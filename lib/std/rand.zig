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
const mem = std.mem;
const math = std.math;
const maxInt = std.math.maxInt;

/// Fast unbiased random numbers.
pub const DefaultPrng = Xoshiro256;

/// Cryptographically secure random numbers.
pub const DefaultCsprng = ChaCha;

pub const Ascon = @import("rand/Ascon.zig");
pub const ChaCha = @import("rand/ChaCha.zig");

pub const Isaac64 = @import("rand/Isaac64.zig");
pub const Pcg = @import("rand/Pcg.zig");
pub const Xoroshiro128 = @import("rand/Xoroshiro128.zig");
pub const Xoshiro256 = @import("rand/Xoshiro256.zig");
pub const Sfc64 = @import("rand/Sfc64.zig");
pub const RomuTrio = @import("rand/RomuTrio.zig");
pub const ziggurat = @import("rand/ziggurat.zig");

pub const Random = struct {
    ptr: *anyopaque,
    fillFn: *const fn (ptr: *anyopaque, buf: []u8) void,

    pub fn init(pointer: anytype, comptime fillFn: fn (ptr: @TypeOf(pointer), buf: []u8) void) Random {
        const Ptr = @TypeOf(pointer);
        assert(@typeInfo(Ptr) == .Pointer); // Must be a pointer
        assert(@typeInfo(Ptr).Pointer.size == .One); // Must be a single-item pointer
        assert(@typeInfo(@typeInfo(Ptr).Pointer.child) == .Struct); // Must point to a struct
        const gen = struct {
            fn fill(ptr: *anyopaque, buf: []u8) void {
                const self: Ptr = @ptrCast(@alignCast(ptr));
                fillFn(self, buf);
            }
        };

        return .{
            .ptr = pointer,
            .fillFn = gen.fill,
        };
    }

    /// Read random bytes into the specified buffer until full.
    pub fn bytes(r: Random, buf: []u8) void {
        r.fillFn(r.ptr, buf);
    }

    pub fn boolean(r: Random) bool {
        return r.int(u1) != 0;
    }

    /// Returns a random value from an enum, evenly distributed.
    ///
    /// Note that this will not yield consistent results across all targets
    /// due to dependence on the representation of `usize` as an index.
    /// See `enumValueWithIndex` for further commentary.
    pub inline fn enumValue(r: Random, comptime EnumType: type) EnumType {
        return r.enumValueWithIndex(EnumType, usize);
    }

    /// Returns a random value from an enum, evenly distributed.
    ///
    /// An index into an array of all named values is generated using the
    /// specified `Index` type to determine the return value.
    /// This allows for results to be independent of `usize` representation.
    ///
    /// Prefer `enumValue` if this isn't important.
    ///
    /// See `uintLessThan`, which this function uses in most cases,
    /// for commentary on the runtime of this function.
    pub fn enumValueWithIndex(r: Random, comptime EnumType: type, comptime Index: type) EnumType {
        comptime assert(@typeInfo(EnumType) == .Enum);

        // We won't use int -> enum casting because enum elements can have
        //  arbitrary values.  Instead we'll randomly pick one of the type's values.
        const values = comptime std.enums.values(EnumType);
        comptime assert(values.len > 0); // can't return anything
        comptime assert(maxInt(Index) >= values.len - 1); // can't access all values
        comptime if (values.len == 1) return values[0];

        const index = if (comptime values.len - 1 == maxInt(Index))
            r.int(Index)
        else
            r.uintLessThan(Index, values.len);

        const MinInt = MinArrayIndex(Index);
        return values[@as(MinInt, @intCast(index))];
    }

    /// Returns a random int `i` such that `minInt(T) <= i <= maxInt(T)`.
    /// `i` is evenly distributed.
    pub fn int(r: Random, comptime T: type) T {
        const bits = @typeInfo(T).Int.bits;
        const UnsignedT = std.meta.Int(.unsigned, bits);
        const ByteAlignedT = std.meta.Int(.unsigned, @divTrunc(bits + 7, 8) * 8);

        var rand_bytes: [@sizeOf(ByteAlignedT)]u8 = undefined;
        r.bytes(rand_bytes[0..]);

        // use LE instead of native endian for better portability maybe?
        // TODO: endian portability is pointless if the underlying prng isn't endian portable.
        // TODO: document the endian portability of this library.
        const byte_aligned_result = mem.readIntSliceLittle(ByteAlignedT, &rand_bytes);
        const unsigned_result = @as(UnsignedT, @truncate(byte_aligned_result));
        return @as(T, @bitCast(unsigned_result));
    }

    /// Constant-time implementation off `uintLessThan`.
    /// The results of this function may be biased.
    pub fn uintLessThanBiased(r: Random, comptime T: type, less_than: T) T {
        comptime assert(@typeInfo(T).Int.signedness == .unsigned);
        const bits = @typeInfo(T).Int.bits;
        comptime assert(bits <= 64); // TODO: workaround: LLVM ERROR: Unsupported library call operation!
        assert(0 < less_than);
        if (bits <= 32) {
            return @as(T, @intCast(limitRangeBiased(u32, r.int(u32), less_than)));
        } else {
            return @as(T, @intCast(limitRangeBiased(u64, r.int(u64), less_than)));
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
    pub fn uintLessThan(r: Random, comptime T: type, less_than: T) T {
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
        var l: Small = @as(Small, @truncate(m));
        if (l < less_than) {
            var t: Small = -%less_than;

            if (t >= less_than) {
                t -= less_than;
                if (t >= less_than) {
                    t %= less_than;
                }
            }
            while (l < t) {
                x = r.int(Small);
                m = @as(Large, x) * @as(Large, less_than);
                l = @as(Small, @truncate(m));
            }
        }
        return @as(T, @intCast(m >> small_bits));
    }

    /// Constant-time implementation off `uintAtMost`.
    /// The results of this function may be biased.
    pub fn uintAtMostBiased(r: Random, comptime T: type, at_most: T) T {
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
    pub fn uintAtMost(r: Random, comptime T: type, at_most: T) T {
        assert(@typeInfo(T).Int.signedness == .unsigned);
        if (at_most == maxInt(T)) {
            // have the full range
            return r.int(T);
        }
        return r.uintLessThan(T, at_most + 1);
    }

    /// Constant-time implementation off `intRangeLessThan`.
    /// The results of this function may be biased.
    pub fn intRangeLessThanBiased(r: Random, comptime T: type, at_least: T, less_than: T) T {
        assert(at_least < less_than);
        const info = @typeInfo(T).Int;
        if (info.signedness == .signed) {
            // Two's complement makes this math pretty easy.
            const UnsignedT = std.meta.Int(.unsigned, info.bits);
            const lo = @as(UnsignedT, @bitCast(at_least));
            const hi = @as(UnsignedT, @bitCast(less_than));
            const result = lo +% r.uintLessThanBiased(UnsignedT, hi -% lo);
            return @as(T, @bitCast(result));
        } else {
            // The signed implementation would work fine, but we can use stricter arithmetic operators here.
            return at_least + r.uintLessThanBiased(T, less_than - at_least);
        }
    }

    /// Returns an evenly distributed random integer `at_least <= i < less_than`.
    /// See `uintLessThan`, which this function uses in most cases,
    /// for commentary on the runtime of this function.
    pub fn intRangeLessThan(r: Random, comptime T: type, at_least: T, less_than: T) T {
        assert(at_least < less_than);
        const info = @typeInfo(T).Int;
        if (info.signedness == .signed) {
            // Two's complement makes this math pretty easy.
            const UnsignedT = std.meta.Int(.unsigned, info.bits);
            const lo = @as(UnsignedT, @bitCast(at_least));
            const hi = @as(UnsignedT, @bitCast(less_than));
            const result = lo +% r.uintLessThan(UnsignedT, hi -% lo);
            return @as(T, @bitCast(result));
        } else {
            // The signed implementation would work fine, but we can use stricter arithmetic operators here.
            return at_least + r.uintLessThan(T, less_than - at_least);
        }
    }

    /// Constant-time implementation off `intRangeAtMostBiased`.
    /// The results of this function may be biased.
    pub fn intRangeAtMostBiased(r: Random, comptime T: type, at_least: T, at_most: T) T {
        assert(at_least <= at_most);
        const info = @typeInfo(T).Int;
        if (info.signedness == .signed) {
            // Two's complement makes this math pretty easy.
            const UnsignedT = std.meta.Int(.unsigned, info.bits);
            const lo = @as(UnsignedT, @bitCast(at_least));
            const hi = @as(UnsignedT, @bitCast(at_most));
            const result = lo +% r.uintAtMostBiased(UnsignedT, hi -% lo);
            return @as(T, @bitCast(result));
        } else {
            // The signed implementation would work fine, but we can use stricter arithmetic operators here.
            return at_least + r.uintAtMostBiased(T, at_most - at_least);
        }
    }

    /// Returns an evenly distributed random integer `at_least <= i <= at_most`.
    /// See `uintLessThan`, which this function uses in most cases,
    /// for commentary on the runtime of this function.
    pub fn intRangeAtMost(r: Random, comptime T: type, at_least: T, at_most: T) T {
        assert(at_least <= at_most);
        const info = @typeInfo(T).Int;
        if (info.signedness == .signed) {
            // Two's complement makes this math pretty easy.
            const UnsignedT = std.meta.Int(.unsigned, info.bits);
            const lo = @as(UnsignedT, @bitCast(at_least));
            const hi = @as(UnsignedT, @bitCast(at_most));
            const result = lo +% r.uintAtMost(UnsignedT, hi -% lo);
            return @as(T, @bitCast(result));
        } else {
            // The signed implementation would work fine, but we can use stricter arithmetic operators here.
            return at_least + r.uintAtMost(T, at_most - at_least);
        }
    }

    /// Return a floating point value evenly distributed in the range [0, 1).
    pub fn float(r: Random, comptime T: type) T {
        // Generate a uniformly random value for the mantissa.
        // Then generate an exponentially biased random value for the exponent.
        // This covers every possible value in the range.
        switch (T) {
            f32 => {
                // Use 23 random bits for the mantissa, and the rest for the exponent.
                // If all 41 bits are zero, generate additional random bits, until a
                // set bit is found, or 126 bits have been generated.
                const rand = r.int(u64);
                var rand_lz = @clz(rand);
                if (rand_lz >= 41) {
                    // TODO: when #5177 or #489 is implemented,
                    // tell the compiler it is unlikely (1/2^41) to reach this point.
                    // (Same for the if branch and the f64 calculations below.)
                    rand_lz = 41 + @clz(r.int(u64));
                    if (rand_lz == 41 + 64) {
                        // It is astronomically unlikely to reach this point.
                        rand_lz += @clz(r.int(u32) | 0x7FF);
                    }
                }
                const mantissa = @as(u23, @truncate(rand));
                const exponent = @as(u32, 126 - rand_lz) << 23;
                return @as(f32, @bitCast(exponent | mantissa));
            },
            f64 => {
                // Use 52 random bits for the mantissa, and the rest for the exponent.
                // If all 12 bits are zero, generate additional random bits, until a
                // set bit is found, or 1022 bits have been generated.
                const rand = r.int(u64);
                var rand_lz: u64 = @clz(rand);
                if (rand_lz >= 12) {
                    rand_lz = 12;
                    while (true) {
                        // It is astronomically unlikely for this loop to execute more than once.
                        const addl_rand_lz = @clz(r.int(u64));
                        rand_lz += addl_rand_lz;
                        if (addl_rand_lz != 64) {
                            break;
                        }
                        if (rand_lz >= 1022) {
                            rand_lz = 1022;
                            break;
                        }
                    }
                }
                const mantissa = rand & 0xFFFFFFFFFFFFF;
                const exponent = (1022 - rand_lz) << 52;
                return @as(f64, @bitCast(exponent | mantissa));
            },
            else => @compileError("unknown floating point type"),
        }
    }

    /// Return a floating point value normally distributed with mean = 0, stddev = 1.
    ///
    /// To use different parameters, use: floatNorm(...) * desiredStddev + desiredMean.
    pub fn floatNorm(r: Random, comptime T: type) T {
        const value = ziggurat.next_f64(r, ziggurat.NormDist);
        switch (T) {
            f32 => return @as(f32, @floatCast(value)),
            f64 => return value,
            else => @compileError("unknown floating point type"),
        }
    }

    /// Return an exponentially distributed float with a rate parameter of 1.
    ///
    /// To use a different rate parameter, use: floatExp(...) / desiredRate.
    pub fn floatExp(r: Random, comptime T: type) T {
        const value = ziggurat.next_f64(r, ziggurat.ExpDist);
        switch (T) {
            f32 => return @as(f32, @floatCast(value)),
            f64 => return value,
            else => @compileError("unknown floating point type"),
        }
    }

    /// Shuffle a slice into a random order.
    ///
    /// Note that this will not yield consistent results across all targets
    /// due to dependence on the representation of `usize` as an index.
    /// See `shuffleWithIndex` for further commentary.
    pub inline fn shuffle(r: Random, comptime T: type, buf: []T) void {
        r.shuffleWithIndex(T, buf, usize);
    }

    /// Shuffle a slice into a random order, using an index of a
    /// specified type to maintain distribution across targets.
    /// Asserts the index type can represent `buf.len`.
    ///
    /// Indexes into the slice are generated using the specified `Index`
    /// type, which determines distribution properties. This allows for
    /// results to be independent of `usize` representation.
    ///
    /// Prefer `shuffle` if this isn't important.
    ///
    /// See `intRangeLessThan`, which this function uses,
    /// for commentary on the runtime of this function.
    pub fn shuffleWithIndex(r: Random, comptime T: type, buf: []T, comptime Index: type) void {
        const MinInt = MinArrayIndex(Index);
        if (buf.len < 2) {
            return;
        }

        // `i <= j < max <= maxInt(MinInt)`
        const max = @as(MinInt, @intCast(buf.len));
        var i: MinInt = 0;
        while (i < max - 1) : (i += 1) {
            const j = @as(MinInt, @intCast(r.intRangeLessThan(Index, i, max)));
            mem.swap(T, &buf[i], &buf[j]);
        }
    }

    /// Randomly selects an index into `proportions`, where the likelihood of each
    /// index is weighted by that proportion.
    /// It is more likely for the index of the last proportion to be returned
    /// than the index of the first proportion in the slice, and vice versa.
    ///
    /// This is useful for selecting an item from a slice where weights are not equal.
    /// `T` must be a numeric type capable of holding the sum of `proportions`.
    pub fn weightedIndex(r: std.rand.Random, comptime T: type, proportions: []const T) usize {
        // This implementation works by summing the proportions and picking a random
        //  point in [0, sum).  We then loop over the proportions, accumulating
        //  until our accumulator is greater than the random point.

        var sum: T = 0;
        for (proportions) |v| {
            sum += v;
        }

        const point = if (comptime std.meta.trait.isSignedInt(T))
            r.intRangeLessThan(T, 0, sum)
        else if (comptime std.meta.trait.isUnsignedInt(T))
            r.uintLessThan(T, sum)
        else if (comptime std.meta.trait.isFloat(T))
            // take care that imprecision doesn't lead to a value slightly greater than sum
            @min(r.float(T) * sum, sum - std.math.floatEps(T))
        else
            @compileError("weightedIndex does not support proportions of type " ++ @typeName(T));

        std.debug.assert(point < sum);

        var accumulator: T = 0;
        for (proportions, 0..) |p, index| {
            accumulator += p;
            if (point < accumulator) return index;
        }

        unreachable;
    }

    /// Returns the smallest of `Index` and `usize`.
    fn MinArrayIndex(comptime Index: type) type {
        const index_info = @typeInfo(Index).Int;
        assert(index_info.signedness == .unsigned);
        return if (index_info.bits >= @typeInfo(usize).Int.bits) usize else Index;
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
    return @as(T, @intCast(m >> bits));
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

test {
    std.testing.refAllDecls(@This());
    _ = @import("rand/test.zig");
}
