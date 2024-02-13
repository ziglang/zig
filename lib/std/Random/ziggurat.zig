//! Implements [ZIGNOR][1] (Jurgen A. Doornik, 2005, Nuffield College, Oxford).
//!
//! [1]: https://www.doornik.com/research/ziggurat.pdf
//!
//! rust/rand used as a reference;
//!
//! NOTE: This seems interesting but reference code is a bit hard to grok:
//! https://sbarral.github.io/etf.

const std = @import("../std.zig");
const builtin = @import("builtin");
const math = std.math;
const Random = std.Random;

pub fn next_f64(random: Random, comptime tables: ZigTable) f64 {
    while (true) {
        // We manually construct a float from parts as we can avoid an extra random lookup here by
        // using the unused exponent for the lookup table entry.
        const bits = random.int(u64);
        const i = @as(usize, @as(u8, @truncate(bits)));

        const u = blk: {
            if (tables.is_symmetric) {
                // Generate a value in the range [2, 4) and scale into [-1, 1)
                const repr = ((0x3ff + 1) << 52) | (bits >> 12);
                break :blk @as(f64, @bitCast(repr)) - 3.0;
            } else {
                // Generate a value in the range [1, 2) and scale into (0, 1)
                const repr = (0x3ff << 52) | (bits >> 12);
                break :blk @as(f64, @bitCast(repr)) - (1.0 - math.floatEps(f64) / 2.0);
            }
        };

        const x = u * tables.x[i];
        const test_x = if (tables.is_symmetric) @abs(x) else x;

        // equivalent to |u| < tables.x[i+1] / tables.x[i] (or u < tables.x[i+1] / tables.x[i])
        if (test_x < tables.x[i + 1]) {
            return x;
        }

        if (i == 0) {
            return tables.zero_case(random, u);
        }

        // equivalent to f1 + DRanU() * (f0 - f1) < 1
        if (tables.f[i + 1] + (tables.f[i] - tables.f[i + 1]) * random.float(f64) < tables.pdf(x)) {
            return x;
        }
    }
}

pub const ZigTable = struct {
    r: f64,
    x: [257]f64,
    f: [257]f64,

    // probability density function used as a fallback
    pdf: fn (f64) f64,
    // whether the distribution is symmetric
    is_symmetric: bool,
    // fallback calculation in the case we are in the 0 block
    zero_case: fn (Random, f64) f64,
};

// zigNorInit
pub fn ZigTableGen(
    comptime is_symmetric: bool,
    comptime r: f64,
    comptime v: f64,
    comptime f: fn (f64) f64,
    comptime f_inv: fn (f64) f64,
    comptime zero_case: fn (Random, f64) f64,
) ZigTable {
    var tables: ZigTable = undefined;

    tables.is_symmetric = is_symmetric;
    tables.r = r;
    tables.pdf = f;
    tables.zero_case = zero_case;

    tables.x[0] = v / f(r);
    tables.x[1] = r;

    for (tables.x[2..256], 0..) |*entry, i| {
        const last = tables.x[2 + i - 1];
        entry.* = f_inv(v / last + f(last));
    }
    tables.x[256] = 0;

    for (tables.f[0..], 0..) |*entry, i| {
        entry.* = f(tables.x[i]);
    }

    return tables;
}

// N(0, 1)
pub const NormDist = blk: {
    @setEvalBranchQuota(30000);
    break :blk ZigTableGen(true, norm_r, norm_v, norm_f, norm_f_inv, norm_zero_case);
};

pub const norm_r = 3.6541528853610088;
pub const norm_v = 0.00492867323399;

pub fn norm_f(x: f64) f64 {
    return @exp(-x * x / 2.0);
}
pub fn norm_f_inv(y: f64) f64 {
    return @sqrt(-2.0 * @log(y));
}
pub fn norm_zero_case(random: Random, u: f64) f64 {
    var x: f64 = 1;
    var y: f64 = 0;

    while (-2.0 * y < x * x) {
        x = @log(random.float(f64)) / norm_r;
        y = @log(random.float(f64));
    }

    if (u < 0) {
        return x - norm_r;
    } else {
        return norm_r - x;
    }
}

test "normal dist sanity" {
    var prng = Random.DefaultPrng.init(0);
    const random = prng.random();

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        _ = random.floatNorm(f64);
    }
}

// Exp(1)
pub const ExpDist = blk: {
    @setEvalBranchQuota(30000);
    break :blk ZigTableGen(false, exp_r, exp_v, exp_f, exp_f_inv, exp_zero_case);
};

pub const exp_r = 7.69711747013104972;
pub const exp_v = 0.0039496598225815571993;

pub fn exp_f(x: f64) f64 {
    return @exp(-x);
}
pub fn exp_f_inv(y: f64) f64 {
    return -@log(y);
}
pub fn exp_zero_case(random: Random, _: f64) f64 {
    return exp_r - @log(random.float(f64));
}

test "exp dist smoke test" {
    var prng = Random.DefaultPrng.init(0);
    const random = prng.random();

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        _ = random.floatExp(f64);
    }
}

test {
    _ = NormDist;
}
