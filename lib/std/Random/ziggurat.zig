//! Implements [ZIGNOR][1] (Jurgen A. Doornik, 2005, Nuffield College, Oxford).
//!
//! [1]: https://www.doornik.com/research/ziggurat.pdf
//!
//! rust/rand used as a reference;
//!
//! NOTE: This seems interesting but reference code is a bit hard to grok:
//! https://sbarral.github.io/etf.

const std = @import("../std.zig");
const math = std.math;
const Random = std.Random;

pub fn next(comptime T: type, random: Random, comptime tables: Table(T)) T {
    const t_bits = @typeInfo(T).float.bits;
    const mantissa_bits = math.floatMantissaBits(T);
    const TAsInt = std.meta.Int(.unsigned, t_bits);

    while (true) {
        // We manually construct a float from parts as we can avoid an extra random lookup here by
        // using the unused exponent for the lookup table entry.
        const bits = random.int(std.meta.Int(.unsigned, mantissa_bits + 8)); // bits for mantissa and 8 for `i`
        const i = @as(usize, @as(u8, @truncate(bits)));

        const u = blk: {
            // If symmetric, generate value in range [2, 4) and scale into [-1, 1),
            // otherwise generate value in range [1, 2] and scale into (0, 1)
            const mantissa: TAsInt = @intCast(bits >> 8);
            const exponent: TAsInt = (math.floatExponentMax(T) + (if (tables.is_symmetric) 1 else 0)) << mantissa_bits;
            const representation: TAsInt = switch (t_bits) {
                80 => exponent | mantissa | (1 << (mantissa_bits - 1)),
                else => exponent | mantissa,
            };
            if (tables.is_symmetric) {
                break :blk @as(T, @bitCast(representation)) - 3.0;
            } else {
                break :blk @as(T, @bitCast(representation)) - (1.0 - math.floatEps(T) / 2.0);
            }
        };

        const x = u * tables.x[i];
        const test_x = if (tables.is_symmetric) @abs(x) else x;

        // equivalent to |u| < tables.x[i+1] / tables.x[i] (or u < tables.x[i+1] / tables.x[i])
        if (test_x < tables.x[i + 1]) {
            return x;
        }

        if (i == 0) {
            return tables.zeroCase(random, u);
        }

        // equivalent to f1 + DRanU() * (f0 - f1) < 1
        if (tables.f[i + 1] + (tables.f[i] - tables.f[i + 1]) * random.float(T) < tables.pdf(x)) {
            return x;
        }
    }
}

pub fn Table(comptime T: type) type {
    std.debug.assert(@typeInfo(T) == .float);
    return struct {
        x: [257]T,
        f: [257]T,

        // probability density function used as a fallback
        pdf: fn (T) T,
        // whether the distribution is symmetric
        is_symmetric: bool,
        // fallback calculation in the case we are in the 0 block
        zeroCase: fn (Random, T) T,
    };
}

// zigNorInit
pub fn tableGen(
    comptime T: type,
    comptime is_symmetric: bool,
    comptime r: T,
    comptime v: T,
    comptime f: fn (T) T,
    comptime fInv: fn (T) T,
    comptime zeroCase: fn (Random, T) T,
) Table(T) {
    var tables: Table(T) = undefined;

    tables.is_symmetric = is_symmetric;
    tables.pdf = f;
    tables.zeroCase = zeroCase;

    tables.x[0] = v / f(r);
    tables.x[1] = r;
    for (tables.x[2..256], 0..) |*entry, i| {
        const last = tables.x[2 + i - 1];
        entry.* = fInv(v / last + f(last));
    }
    tables.x[256] = 0;

    for (tables.f[0..], 0..) |*entry, i| {
        entry.* = f(tables.x[i]);
    }

    return tables;
}

/// Namespace containing distributions for a specific floating point type.
pub fn distributions(comptime T: type) type {
    std.debug.assert(@typeInfo(T) == .float);
    return struct {
        pub const norm_r = 3.6541528853610088;
        pub const norm_v = 0.00492867323399;
        pub fn normF(x: T) T {
            return @exp(-x * x / 2.0);
        }
        pub fn normFInv(y: T) T {
            return @sqrt(-2.0 * @log(y));
        }
        pub fn normZeroCase(random: Random, u: T) T {
            var x: T = 1.0;
            var y: T = 0.0;

            while (-2.0 * y < x * x) {
                x = @log(random.float(T)) / norm_r;
                y = @log(random.float(T));
            }

            if (u < 0) {
                return x - norm_r;
            } else {
                return norm_r - x;
            }
        }
        /// N(0, 1)
        pub const normal = blk: {
            @setEvalBranchQuota(30000);
            break :blk tableGen(T, true, norm_r, norm_v, normF, normFInv, normZeroCase);
        };

        pub const exp_r = 7.69711747013104972;
        pub const exp_v = 0.0039496598225815571993;
        pub fn expF(x: T) T {
            return @exp(-x);
        }
        pub fn expFInv(y: T) T {
            return -@log(y);
        }
        pub fn expZeroCase(random: Random, _: T) T {
            return exp_r - @log(random.float(T));
        }
        /// E(1)
        pub const exponential = blk: {
            @setEvalBranchQuota(30000);
            break :blk tableGen(T, false, exp_r, exp_v, expF, expFInv, expZeroCase);
        };
    };
}

/// Deprecated. Use `next` instead.
pub fn next_f64(random: Random, comptime tables: Table(f64)) f64 {
    return next(f64, random, tables);
}
/// Deprecated. Use `Table` instead.
pub const ZigTable = Table(f64);
/// Deprecated. Use `tableGen` instead.
pub fn ZigTableGen(
    comptime is_symmetric: bool,
    comptime r: f64,
    comptime v: f64,
    comptime f: fn (f64) f64,
    comptime f_inv: fn (f64) f64,
    comptime zero_case: fn (Random, f64) f64,
) Table(f64) {
    return tableGen(f64, is_symmetric, r, v, f, f_inv, zero_case);
}
/// Deprecated. Use `distributions.normal` instead.
pub const NormDist = distributions(f64).normal;
/// Deprecated. Use `distributions.exponential` instead.
pub const ExpDist = distributions(f64).exponential;

fn zigguratTests(comptime T: type) type {
    return struct {
        test "normal dist correctness" {
            const n = 10000;
            const p = 0.682689492136; // chance of `random.floatNorm` ∈ [-1.0, 1.0]
            const mu = n * p;
            const sigma = @sqrt(n * p * (1.0 - p));
            // interval that `in_range` will land in (inclusive) with 95% confidence
            const in_range_min: u32 = @intFromFloat(@ceil(mu - 1.97 * sigma));
            const in_range_max: u32 = @intFromFloat(@floor(mu + 1.97 * sigma));

            var prng = Random.DefaultPrng.init(switch (@typeInfo(T).float.bits) {
                // By random chance, this fails for `f64` on seed `0`
                // and for `f32` on seed `1`. Thus this setup.
                64 => 1,
                else => 0,
            });
            const random = prng.random();

            var in_range: u32 = 0;
            for (0..n) |_| {
                const value = random.floatNorm(T);
                if (value >= -1.0 and value <= 1.0) in_range += 1;
            }

            try std.testing.expect(in_range >= in_range_min);
            try std.testing.expect(in_range <= in_range_max);
        }
        test "exponential dist correctness" {
            const n = 10000;
            const p = 0.5; // chance of `random.floatExp` < @log(2.0)
            const mu = n * p;
            const sigma = @sqrt(n * p * (1.0 - p));
            // interval that `in_range` will land in (inclusive) with 95% confidence
            const in_range_min: u32 = @intFromFloat(@ceil(mu - 1.97 * sigma));
            const in_range_max: u32 = @intFromFloat(@floor(mu + 1.97 * sigma));

            var prng = Random.DefaultPrng.init(0);
            const random = prng.random();

            var in_range: u32 = 0;
            for (0..n) |_| {
                const value = random.floatExp(T);
                if (value < @log(2.0)) in_range += 1;
            }

            try std.testing.expect(in_range >= in_range_min);
            try std.testing.expect(in_range <= in_range_max);
        }
        test "distributions" {
            const dists = distributions(T);
            _ = dists.normal;
            _ = dists.exponential;
        }
    };
}

test {
    inline for ([_]type{ f16, f32, f64, f80, f128, c_longdouble }) |T| {
        _ = zigguratTests(T);
    }
}
