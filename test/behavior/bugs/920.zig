const builtin = @import("builtin");
const std = @import("std");
const Random = std.rand.Random;

const ZigTable = struct {
    r: f64,
    x: [257]f64,
    f: [257]f64,

    pdf: *const fn (f64) f64,
    is_symmetric: bool,
    zero_case: *const fn (*Random, f64) f64,
};

fn ZigTableGen(comptime is_symmetric: bool, comptime r: f64, comptime v: f64, comptime f: fn (f64) f64, comptime f_inv: fn (f64) f64, comptime zero_case: fn (*Random, f64) f64) ZigTable {
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

const norm_r = 3.6541528853610088;
const norm_v = 0.00492867323399;

fn norm_f(x: f64) f64 {
    return @exp(-x * x / 2.0);
}
fn norm_f_inv(y: f64) f64 {
    return @sqrt(-2.0 * @log(y));
}
fn norm_zero_case(random: *Random, u: f64) f64 {
    _ = random;
    _ = u;
    return 0.0;
}

const NormalDist = blk: {
    @setEvalBranchQuota(30000);
    break :blk ZigTableGen(true, norm_r, norm_v, norm_f, norm_f_inv, norm_zero_case);
};

test "bug 920 fixed" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const NormalDist1 = blk: {
        break :blk ZigTableGen(true, norm_r, norm_v, norm_f, norm_f_inv, norm_zero_case);
    };

    for (NormalDist1.f, 0..) |_, i| {
        // Here we use `expectApproxEqAbs` instead of `expectEqual` to account for the small
        // differences in math functions of different libcs. For example, if the compiler
        // links against glibc, but the target is musl libc, then these values might be
        // slightly different.
        // Arguably, this is a bug in the compiler because comptime should emulate the target,
        // including rounding errors in libc math functions. However that behavior is not
        // what this particular test is intended to cover.
        try std.testing.expectApproxEqAbs(NormalDist1.f[i], NormalDist.f[i], @sqrt(std.math.floatEps(f64)));
    }
}
