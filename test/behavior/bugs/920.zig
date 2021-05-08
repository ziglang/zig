const std = @import("std");
const math = std.math;
const Random = std.rand.Random;

const ZigTable = struct {
    r: f64,
    x: [257]f64,
    f: [257]f64,

    pdf: fn (f64) f64,
    is_symmetric: bool,
    zero_case: fn (*Random, f64) f64,
};

fn ZigTableGen(comptime is_symmetric: bool, comptime r: f64, comptime v: f64, comptime f: fn (f64) f64, comptime f_inv: fn (f64) f64, comptime zero_case: fn (*Random, f64) f64) ZigTable {
    var tables: ZigTable = undefined;

    tables.is_symmetric = is_symmetric;
    tables.r = r;
    tables.pdf = f;
    tables.zero_case = zero_case;

    tables.x[0] = v / f(r);
    tables.x[1] = r;

    for (tables.x[2..256]) |*entry, i| {
        const last = tables.x[2 + i - 1];
        entry.* = f_inv(v / last + f(last));
    }
    tables.x[256] = 0;

    for (tables.f[0..]) |*entry, i| {
        entry.* = f(tables.x[i]);
    }

    return tables;
}

const norm_r = 3.6541528853610088;
const norm_v = 0.00492867323399;

fn norm_f(x: f64) f64 {
    return math.exp(-x * x / 2.0);
}
fn norm_f_inv(y: f64) f64 {
    return math.sqrt(-2.0 * math.ln(y));
}
fn norm_zero_case(random: *Random, u: f64) f64 {
    return 0.0;
}

const NormalDist = blk: {
    @setEvalBranchQuota(30000);
    break :blk ZigTableGen(true, norm_r, norm_v, norm_f, norm_f_inv, norm_zero_case);
};

test "bug 920 fixed" {
    const NormalDist1 = blk: {
        break :blk ZigTableGen(true, norm_r, norm_v, norm_f, norm_f_inv, norm_zero_case);
    };

    for (NormalDist1.f) |_, i| {
        try std.testing.expectEqual(NormalDist1.f[i], NormalDist.f[i]);
    }
}
