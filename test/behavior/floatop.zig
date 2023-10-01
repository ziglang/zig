const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const math = std.math;
const has_f80_rt = switch (builtin.cpu.arch) {
    .x86_64, .x86 => true,
    else => false,
};
const no_x86_64_hardware_f16_support = builtin.zig_backend == .stage2_x86_64 and
    !std.Target.x86.featureSetHas(builtin.cpu.features, .f16c);

const epsilon_16 = 0.002;
const epsilon = 0.000001;

fn epsForType(comptime T: type) T {
    return switch (T) {
        f16 => @as(f16, epsilon_16),
        else => @as(T, epsilon),
    };
}

test "cmp f16" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testCmp(f16);
    try comptime testCmp(f16);
}

test "cmp f32/f64" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testCmp(f32);
    try comptime testCmp(f32);
    try testCmp(f64);
    try comptime testCmp(f64);
}

test "cmp f128" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c and builtin.cpu.arch.isArmOrThumb()) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testCmp(f128);
    try comptime testCmp(f128);
}

test "cmp f80/c_longdouble" {
    if (true) return error.SkipZigTest;

    try testCmp(f80);
    try comptime testCmp(f80);
    try testCmp(c_longdouble);
    try comptime testCmp(c_longdouble);
}

fn testCmp(comptime T: type) !void {
    {
        // No decimal part
        var x: T = 1.0;
        try expect(x == 1.0);
        try expect(x != 0.0);
        try expect(x > 0.0);
        try expect(x < 2.0);
        try expect(x >= 1.0);
        try expect(x <= 1.0);
    }
    {
        // Non-zero decimal part
        var x: T = 1.5;
        try expect(x != 1.0);
        try expect(x != 2.0);
        try expect(x > 1.0);
        try expect(x < 2.0);
        try expect(x >= 1.0);
        try expect(x <= 2.0);
    }

    @setEvalBranchQuota(2_000);
    var edges = [_]T{
        -math.inf(T),
        -math.floatMax(T),
        -math.floatMin(T),
        -math.floatTrueMin(T),
        -0.0,
        math.nan(T),
        0.0,
        math.floatTrueMin(T),
        math.floatMin(T),
        math.floatMax(T),
        math.inf(T),
    };
    for (edges, 0..) |rhs, rhs_i| {
        for (edges, 0..) |lhs, lhs_i| {
            const no_nan = lhs_i != 5 and rhs_i != 5;
            const lhs_order = if (lhs_i < 5) lhs_i else lhs_i - 2;
            const rhs_order = if (rhs_i < 5) rhs_i else rhs_i - 2;
            try expect((lhs == rhs) == (no_nan and lhs_order == rhs_order));
            try expect((lhs != rhs) == !(no_nan and lhs_order == rhs_order));
            try expect((lhs < rhs) == (no_nan and lhs_order < rhs_order));
            try expect((lhs > rhs) == (no_nan and lhs_order > rhs_order));
            try expect((lhs <= rhs) == (no_nan and lhs_order <= rhs_order));
            try expect((lhs >= rhs) == (no_nan and lhs_order >= rhs_order));
        }
    }
}

test "different sized float comparisons" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testDifferentSizedFloatComparisons();
    try comptime testDifferentSizedFloatComparisons();
}

fn testDifferentSizedFloatComparisons() !void {
    var a: f16 = 1;
    var b: f64 = 2;
    try expect(a < b);
}

// TODO This is waiting on library support for the Windows build (not sure why the other's don't need it)
//test "@nearbyint" {
//    comptime testNearbyInt();
//    testNearbyInt();
//}

//fn testNearbyInt() void {
//    // TODO test f16, f128, and c_longdouble
//    // https://github.com/ziglang/zig/issues/4026
//    {
//        var a: f32 = 2.1;
//    try expect(@nearbyint(a) == 2);
//    }
//    {
//        var a: f64 = -3.75;
//    try expect(@nearbyint(a) == -4);
//    }
//}

test "negative f128 intFromFloat at compile-time" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const a: f128 = -2;
    var b = @as(i64, @intFromFloat(a));
    try expect(@as(i64, -2) == b);
}

test "@sqrt" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testSqrt();
    try comptime testSqrt();
}

fn testSqrt() !void {
    try expect(@sqrt(@as(f16, 4)) == 2);
    try expect(@sqrt(@as(f32, 9)) == 3);
    try expect(@sqrt(@as(f64, 25)) == 5);
    try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 1.1)), 1.0488088481701516, epsilon));
    try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 2.0)), 1.4142135623730950, epsilon));

    if (false) {
        if (has_f80_rt) {
            // TODO https://github.com/ziglang/zig/issues/10875
            if (builtin.os.tag != .freebsd) {
                var a: f80 = 25;
                try expect(@sqrt(a) == 5);
            }
        }
        {
            const a: comptime_float = 25.0;
            try expect(@sqrt(a) == 5.0);
        }
        // TODO test f128, and c_longdouble
        // https://github.com/ziglang/zig/issues/4026
        //{
        //    var a: f128 = 49;
        //try expect(@sqrt(a) == 7);
        //}
    }
}

test "@sqrt with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testSqrtWithVectors();
    try comptime testSqrtWithVectors();
}

fn testSqrtWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
    var result = @sqrt(v);
    try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 3.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 4.4)), result[3], epsilon));
}

test "more @sqrt f16 tests" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (no_x86_64_hardware_f16_support) return error.SkipZigTest;

    // TODO these are not all passing at comptime
    try expect(@sqrt(@as(f16, 0.0)) == 0.0);
    try expect(math.approxEqAbs(f16, @sqrt(@as(f16, 2.0)), 1.414214, epsilon));
    try expect(math.approxEqAbs(f16, @sqrt(@as(f16, 3.6)), 1.897367, epsilon));
    try expect(@sqrt(@as(f16, 4.0)) == 2.0);
    try expect(math.approxEqAbs(f16, @sqrt(@as(f16, 7.539840)), 2.745877, epsilon));
    try expect(math.approxEqAbs(f16, @sqrt(@as(f16, 19.230934)), 4.385309, epsilon));
    try expect(@sqrt(@as(f16, 64.0)) == 8.0);
    try expect(math.approxEqAbs(f16, @sqrt(@as(f16, 64.1)), 8.006248, epsilon));
    try expect(math.approxEqAbs(f16, @sqrt(@as(f16, 8942.230469)), 94.563370, epsilon));

    // special cases
    try expect(math.isPositiveInf(@sqrt(@as(f16, math.inf(f16)))));
    try expect(@sqrt(@as(f16, 0.0)) == 0.0);
    try expect(@sqrt(@as(f16, -0.0)) == -0.0);
    try expect(math.isNan(@sqrt(@as(f16, -1.0))));
    try expect(math.isNan(@sqrt(@as(f16, math.nan(f16)))));
}

test "another, possibly redundant @sqrt test" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (no_x86_64_hardware_f16_support) return error.SkipZigTest;

    try testSqrtLegacy(f64, 12.0);
    try comptime testSqrtLegacy(f64, 12.0);
    try testSqrtLegacy(f32, 13.0);
    try comptime testSqrtLegacy(f32, 13.0);
    try testSqrtLegacy(f16, 13.0);
    try comptime testSqrtLegacy(f16, 13.0);

    // TODO: make this pass
    if (false) {
        const x = 14.0;
        const y = x * x;
        const z = @sqrt(y);
        try comptime expect(z == x);
    }
}

fn testSqrtLegacy(comptime T: type, x: T) !void {
    try expect(@sqrt(x * x) == x);
}

test "@sin f16" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;
    if (no_x86_64_hardware_f16_support) return error.SkipZigTest;

    try testSin(f16);
    try comptime testSin(f16);
}

test "@sin f32/f64" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testSin(f32);
    comptime try testSin(f32);
    try testSin(f64);
    comptime try testSin(f64);
}

test "@sin f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testSin(f80);
    comptime try testSin(f80);
    try testSin(f128);
    comptime try testSin(f128);
    try testSin(c_longdouble);
    comptime try testSin(c_longdouble);
}

fn testSin(comptime T: type) !void {
    const eps = epsForType(T);
    var zero: T = 0;
    try expect(@sin(zero) == 0);
    var pi: T = math.pi;
    try expect(math.approxEqAbs(T, @sin(pi), 0, eps));
    try expect(math.approxEqAbs(T, @sin(pi / 2.0), 1, eps));
    try expect(math.approxEqAbs(T, @sin(pi / 4.0), 0.7071067811865475, eps));
}

test "@sin with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testSinWithVectors();
    try comptime testSinWithVectors();
}

fn testSinWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
    var result = @sin(v);
    try expect(math.approxEqAbs(f32, @sin(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @sin(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @sin(@as(f32, 3.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @sin(@as(f32, 4.4)), result[3], epsilon));
}

test "@cos f16" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;
    if (no_x86_64_hardware_f16_support) return error.SkipZigTest;

    try testCos(f16);
    try comptime testCos(f16);
}

test "@cos f32/f64" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testCos(f32);
    try comptime testCos(f32);
    try testCos(f64);
    try comptime testCos(f64);
}

test "@cos f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testCos(f80);
    try comptime testCos(f80);
    try testCos(f128);
    try comptime testCos(f128);
    try testCos(c_longdouble);
    try comptime testCos(c_longdouble);
}

fn testCos(comptime T: type) !void {
    const eps = epsForType(T);
    var zero: T = 0;
    try expect(@cos(zero) == 1);
    var pi: T = math.pi;
    try expect(math.approxEqAbs(T, @cos(pi), -1, eps));
    try expect(math.approxEqAbs(T, @cos(pi / 2.0), 0, eps));
    try expect(math.approxEqAbs(T, @cos(pi / 4.0), 0.7071067811865475, eps));
}

test "@cos with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testCosWithVectors();
    try comptime testCosWithVectors();
}

fn testCosWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
    var result = @cos(v);
    try expect(math.approxEqAbs(f32, @cos(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @cos(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @cos(@as(f32, 3.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @cos(@as(f32, 4.4)), result[3], epsilon));
}

test "@tan f16" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;
    if (no_x86_64_hardware_f16_support) return error.SkipZigTest;

    try testTan(f16);
    try comptime testTan(f16);
}

test "@tan f32/f64" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testTan(f32);
    try comptime testTan(f32);
    try testTan(f64);
    try comptime testTan(f64);
}

test "@tan f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testTan(f80);
    try comptime testTan(f80);
    try testTan(f128);
    try comptime testTan(f128);
    try testTan(c_longdouble);
    try comptime testTan(c_longdouble);
}

fn testTan(comptime T: type) !void {
    const eps = epsForType(T);
    var zero: T = 0;
    try expect(@tan(zero) == 0);
    var pi: T = math.pi;
    try expect(math.approxEqAbs(T, @tan(pi), 0, eps));
    try expect(math.approxEqAbs(T, @tan(pi / 3.0), 1.732050807568878, eps));
    try expect(math.approxEqAbs(T, @tan(pi / 4.0), 1, eps));
}

test "@tan with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testTanWithVectors();
    try comptime testTanWithVectors();
}

fn testTanWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
    var result = @tan(v);
    try expect(math.approxEqAbs(f32, @tan(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @tan(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @tan(@as(f32, 3.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @tan(@as(f32, 4.4)), result[3], epsilon));
}

test "@exp f16" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;
    if (no_x86_64_hardware_f16_support) return error.SkipZigTest;

    try testExp(f16);
    try comptime testExp(f16);
}

test "@exp f32/f64" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testExp(f32);
    try comptime testExp(f32);
    try testExp(f64);
    try comptime testExp(f64);
}

test "@exp f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testExp(f80);
    try comptime testExp(f80);
    try testExp(f128);
    try comptime testExp(f128);
    try testExp(c_longdouble);
    try comptime testExp(c_longdouble);
}

fn testExp(comptime T: type) !void {
    const eps = epsForType(T);
    var zero: T = 0;
    try expect(@exp(zero) == 1);
    var two: T = 2;
    try expect(math.approxEqAbs(T, @exp(two), 7.389056098930650, eps));
    var five: T = 5;
    try expect(math.approxEqAbs(T, @exp(five), 148.4131591025766, eps));
}

test "@exp with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testExpWithVectors();
    try comptime testExpWithVectors();
}

fn testExpWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
    var result = @exp(v);
    try expect(math.approxEqAbs(f32, @exp(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @exp(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @exp(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @exp(@as(f32, 0.4)), result[3], epsilon));
}

test "@exp2 f16" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;
    if (no_x86_64_hardware_f16_support) return error.SkipZigTest;

    try testExp2(f16);
    try comptime testExp2(f16);
}

test "@exp2 f32/f64" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testExp2(f32);
    try comptime testExp2(f32);
    try testExp2(f64);
    try comptime testExp2(f64);
}

test "@exp2 f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testExp2(f80);
    try comptime testExp2(f80);
    try testExp2(f128);
    try comptime testExp2(f128);
    try testExp2(c_longdouble);
    try comptime testExp2(c_longdouble);
}

fn testExp2(comptime T: type) !void {
    const eps = epsForType(T);
    var two: T = 2;
    try expect(@exp2(two) == 4);
    var one_point_five: T = 1.5;
    try expect(math.approxEqAbs(T, @exp2(one_point_five), 2.8284271247462, eps));
    var four_point_five: T = 4.5;
    try expect(math.approxEqAbs(T, @exp2(four_point_five), 22.627416997969, eps));
}

test "@exp2 with @vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testExp2WithVectors();
    try comptime testExp2WithVectors();
}

fn testExp2WithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
    var result = @exp2(v);
    try expect(math.approxEqAbs(f32, @exp2(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @exp2(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @exp2(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @exp2(@as(f32, 0.4)), result[3], epsilon));
}

test "@log f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;
    if (no_x86_64_hardware_f16_support) return error.SkipZigTest;

    try testLog(f16);
    try comptime testLog(f16);
}

test "@log f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testLog(f32);
    try comptime testLog(f32);
    try testLog(f64);
    try comptime testLog(f64);
}

test "@log f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testLog(f80);
    try comptime testLog(f80);
    try testLog(f128);
    try comptime testLog(f128);
    try testLog(c_longdouble);
    try comptime testLog(c_longdouble);
}

fn testLog(comptime T: type) !void {
    const eps = epsForType(T);
    var e: T = math.e;
    try expect(math.approxEqAbs(T, @log(e), 1, eps));
    var two: T = 2;
    try expect(math.approxEqAbs(T, @log(two), 0.6931471805599, eps));
    var five: T = 5;
    try expect(math.approxEqAbs(T, @log(five), 1.6094379124341, eps));
}

test "@log with @vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
        var result = @log(v);
        try expect(@log(@as(f32, 1.1)) == result[0]);
        try expect(@log(@as(f32, 2.2)) == result[1]);
        try expect(@log(@as(f32, 0.3)) == result[2]);
        try expect(@log(@as(f32, 0.4)) == result[3]);
    }
}

test "@log2 f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;
    if (no_x86_64_hardware_f16_support) return error.SkipZigTest;

    try testLog2(f16);
    try comptime testLog2(f16);
}

test "@log2 f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testLog2(f32);
    try comptime testLog2(f32);
    try testLog2(f64);
    try comptime testLog2(f64);
}

test "@log2 f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testLog2(f80);
    try comptime testLog2(f80);
    try testLog2(f128);
    try comptime testLog2(f128);
    try testLog2(c_longdouble);
    try comptime testLog2(c_longdouble);
}

fn testLog2(comptime T: type) !void {
    const eps = epsForType(T);
    var four: T = 4;
    try expect(@log2(four) == 2);
    var six: T = 6;
    try expect(math.approxEqAbs(T, @log2(six), 2.5849625007212, eps));
    var ten: T = 10;
    try expect(math.approxEqAbs(T, @log2(ten), 3.3219280948874, eps));
}

test "@log2 with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    // https://github.com/ziglang/zig/issues/13681
    if (builtin.zig_backend == .stage2_llvm and
        builtin.cpu.arch == .aarch64 and
        builtin.os.tag == .windows) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testLog2WithVectors();
    try comptime testLog2WithVectors();
}

fn testLog2WithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
    var result = @log2(v);
    try expect(@log2(@as(f32, 1.1)) == result[0]);
    try expect(@log2(@as(f32, 2.2)) == result[1]);
    try expect(@log2(@as(f32, 0.3)) == result[2]);
    try expect(@log2(@as(f32, 0.4)) == result[3]);
}

test "@log10 f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;
    if (no_x86_64_hardware_f16_support) return error.SkipZigTest;

    try testLog10(f16);
    try comptime testLog10(f16);
}

test "@log10 f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testLog10(f32);
    try comptime testLog10(f32);
    try testLog10(f64);
    try comptime testLog10(f64);
}

test "@log10 f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testLog10(f80);
    try comptime testLog10(f80);
    try testLog10(f128);
    try comptime testLog10(f128);
    try testLog10(c_longdouble);
    try comptime testLog10(c_longdouble);
}

fn testLog10(comptime T: type) !void {
    const eps = epsForType(T);
    var hundred: T = 100;
    try expect(@log10(hundred) == 2);
    var fifteen: T = 15;
    try expect(math.approxEqAbs(T, @log10(fifteen), 1.176091259056, eps));
    var fifty: T = 50;
    try expect(math.approxEqAbs(T, @log10(fifty), 1.698970004336, eps));
}

test "@log10 with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testLog10WithVectors();
    try comptime testLog10WithVectors();
}

fn testLog10WithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
    var result = @log10(v);
    try expect(@log10(@as(f32, 1.1)) == result[0]);
    try expect(@log10(@as(f32, 2.2)) == result[1]);
    try expect(@log10(@as(f32, 0.3)) == result[2]);
    try expect(@log10(@as(f32, 0.4)) == result[3]);
}

test "@abs f16" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (no_x86_64_hardware_f16_support) return error.SkipZigTest;

    try testFabs(f16);
    try comptime testFabs(f16);
}

test "@abs f32/f64" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testFabs(f32);
    try comptime testFabs(f32);
    try testFabs(f64);
    try comptime testFabs(f64);
}

test "@abs f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c and builtin.cpu.arch.isArmOrThumb()) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testFabs(f80);
    try comptime testFabs(f80);
    try testFabs(f128);
    try comptime testFabs(f128);
    try testFabs(c_longdouble);
    try comptime testFabs(c_longdouble);
}

fn testFabs(comptime T: type) !void {
    var two_point_five: T = 2.5;
    try expect(@abs(two_point_five) == 2.5);
    var neg_two_point_five: T = -2.5;
    try expect(@abs(neg_two_point_five) == 2.5);

    var twelve: T = 12.0;
    try expect(@abs(twelve) == 12.0);
    var neg_fourteen: T = -14.0;
    try expect(@abs(neg_fourteen) == 14.0);

    // normals
    var one: T = 1.0;
    try expect(@abs(one) == 1.0);
    var neg_one: T = -1.0;
    try expect(@abs(neg_one) == 1.0);
    var min: T = math.floatMin(T);
    try expect(@abs(min) == math.floatMin(T));
    var neg_min: T = -math.floatMin(T);
    try expect(@abs(neg_min) == math.floatMin(T));
    var max: T = math.floatMax(T);
    try expect(@abs(max) == math.floatMax(T));
    var neg_max: T = -math.floatMax(T);
    try expect(@abs(neg_max) == math.floatMax(T));

    // subnormals
    var zero: T = 0.0;
    try expect(@abs(zero) == 0.0);
    var neg_zero: T = -0.0;
    try expect(@abs(neg_zero) == 0.0);
    var true_min: T = math.floatTrueMin(T);
    try expect(@abs(true_min) == math.floatTrueMin(T));
    var neg_true_min: T = -math.floatTrueMin(T);
    try expect(@abs(neg_true_min) == math.floatTrueMin(T));

    // non-finite numbers
    var inf: T = math.inf(T);
    try expect(math.isPositiveInf(@abs(inf)));
    var neg_inf: T = -math.inf(T);
    try expect(math.isPositiveInf(@abs(neg_inf)));
    var nan: T = math.nan(T);
    try expect(math.isNan(@abs(nan)));
}

test "@abs with vectors" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    try testFabsWithVectors();
    try comptime testFabsWithVectors();
}

fn testFabsWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
    var result = @abs(v);
    try expect(math.approxEqAbs(f32, @abs(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @abs(@as(f32, -2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @abs(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @abs(@as(f32, -0.4)), result[3], epsilon));
}

test "@floor f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testFloor(f16);
    try comptime testFloor(f16);
}

test "@floor f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testFloor(f32);
    try comptime testFloor(f32);
    try testFloor(f64);
    try comptime testFloor(f64);
}

test "@floor f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c and builtin.cpu.arch.isArmOrThumb()) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/12602
        return error.SkipZigTest;
    }

    try testFloor(f80);
    try comptime testFloor(f80);
    try testFloor(f128);
    try comptime testFloor(f128);
    try testFloor(c_longdouble);
    try comptime testFloor(c_longdouble);
}

fn testFloor(comptime T: type) !void {
    var two_point_one: T = 2.1;
    try expect(@floor(two_point_one) == 2.0);
    var neg_two_point_one: T = -2.1;
    try expect(@floor(neg_two_point_one) == -3.0);
    var three_point_five: T = 3.5;
    try expect(@floor(three_point_five) == 3.0);
    var neg_three_point_five: T = -3.5;
    try expect(@floor(neg_three_point_five) == -4.0);
    var twelve: T = 12.0;
    try expect(@floor(twelve) == 12.0);
    var neg_twelve: T = -12.0;
    try expect(@floor(neg_twelve) == -12.0);
    var fourteen_point_seven: T = 14.7;
    try expect(@floor(fourteen_point_seven) == 14.0);
    var neg_fourteen_point_seven: T = -14.7;
    try expect(@floor(neg_fourteen_point_seven) == -15.0);
}

test "@floor with vectors" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .sse4_1)) return error.SkipZigTest;

    try testFloorWithVectors();
    try comptime testFloorWithVectors();
}

fn testFloorWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
    var result = @floor(v);
    try expect(math.approxEqAbs(f32, @floor(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @floor(@as(f32, -2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @floor(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @floor(@as(f32, -0.4)), result[3], epsilon));
}

test "@ceil f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testCeil(f16);
    try comptime testCeil(f16);
}

test "@ceil f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    try testCeil(f32);
    try comptime testCeil(f32);
    try testCeil(f64);
    try comptime testCeil(f64);
}

test "@ceil f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c and builtin.cpu.arch.isArmOrThumb()) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/12602
        return error.SkipZigTest;
    }

    try testCeil(f80);
    try comptime testCeil(f80);
    try testCeil(f128);
    try comptime testCeil(f128);
    try testCeil(c_longdouble);
    try comptime testCeil(c_longdouble);
}

fn testCeil(comptime T: type) !void {
    var two_point_one: T = 2.1;
    try expect(@ceil(two_point_one) == 3.0);
    var neg_two_point_one: T = -2.1;
    try expect(@ceil(neg_two_point_one) == -2.0);
    var three_point_five: T = 3.5;
    try expect(@ceil(three_point_five) == 4.0);
    var neg_three_point_five: T = -3.5;
    try expect(@ceil(neg_three_point_five) == -3.0);
    var twelve: T = 12.0;
    try expect(@ceil(twelve) == 12.0);
    var neg_twelve: T = -12.0;
    try expect(@ceil(neg_twelve) == -12.0);
    var fourteen_point_seven: T = 14.7;
    try expect(@ceil(fourteen_point_seven) == 15.0);
    var neg_fourteen_point_seven: T = -14.7;
    try expect(@ceil(neg_fourteen_point_seven) == -14.0);
}

test "@ceil with vectors" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .sse4_1)) return error.SkipZigTest;

    try testCeilWithVectors();
    try comptime testCeilWithVectors();
}

fn testCeilWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
    var result = @ceil(v);
    try expect(math.approxEqAbs(f32, @ceil(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @ceil(@as(f32, -2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @ceil(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @ceil(@as(f32, -0.4)), result[3], epsilon));
}

test "@trunc f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch.isMIPS()) {
        // https://github.com/ziglang/zig/issues/16846
        return error.SkipZigTest;
    }

    try testTrunc(f16);
    try comptime testTrunc(f16);
}

test "@trunc f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch.isMIPS()) {
        // https://github.com/ziglang/zig/issues/16846
        return error.SkipZigTest;
    }

    try testTrunc(f32);
    try comptime testTrunc(f32);
    try testTrunc(f64);
    try comptime testTrunc(f64);
}

test "@trunc f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c and builtin.cpu.arch.isArmOrThumb()) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/12602
        return error.SkipZigTest;
    }

    try testTrunc(f80);
    try comptime testTrunc(f80);
    try testTrunc(f128);
    try comptime testTrunc(f128);
    try testTrunc(c_longdouble);
    try comptime testTrunc(c_longdouble);
}

fn testTrunc(comptime T: type) !void {
    var two_point_one: T = 2.1;
    try expect(@trunc(two_point_one) == 2.0);
    var neg_two_point_one: T = -2.1;
    try expect(@trunc(neg_two_point_one) == -2.0);
    var three_point_five: T = 3.5;
    try expect(@trunc(three_point_five) == 3.0);
    var neg_three_point_five: T = -3.5;
    try expect(@trunc(neg_three_point_five) == -3.0);
    var twelve: T = 12.0;
    try expect(@trunc(twelve) == 12.0);
    var neg_twelve: T = -12.0;
    try expect(@trunc(neg_twelve) == -12.0);
    var fourteen_point_seven: T = 14.7;
    try expect(@trunc(fourteen_point_seven) == 14.0);
    var neg_fourteen_point_seven: T = -14.7;
    try expect(@trunc(neg_fourteen_point_seven) == -14.0);
}

test "@trunc with vectors" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .sse4_1)) return error.SkipZigTest;

    try testTruncWithVectors();
    try comptime testTruncWithVectors();
}

fn testTruncWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
    var result = @trunc(v);
    try expect(math.approxEqAbs(f32, @trunc(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @trunc(@as(f32, -2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @trunc(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @trunc(@as(f32, -0.4)), result[3], epsilon));
}

test "neg f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (no_x86_64_hardware_f16_support) return error.SkipZigTest;

    if (builtin.os.tag == .freebsd) {
        // TODO file issue to track this failure
        return error.SkipZigTest;
    }

    try testNeg(f16);
    try comptime testNeg(f16);
}

test "neg f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;

    try testNeg(f32);
    try comptime testNeg(f32);
    try testNeg(f64);
    try comptime testNeg(f64);
}

test "neg f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try testNeg(f80);
    try comptime testNeg(f80);
    try testNeg(f128);
    try comptime testNeg(f128);
    try testNeg(c_longdouble);
    try comptime testNeg(c_longdouble);
}

fn testNeg(comptime T: type) !void {
    var two_point_five: T = 2.5;
    try expect(-two_point_five == -2.5);
    var neg_two_point_five: T = -2.5;
    try expect(-neg_two_point_five == 2.5);

    var twelve: T = 12.0;
    try expect(-twelve == -12.0);
    var neg_fourteen: T = -14.0;
    try expect(-neg_fourteen == 14.0);

    // normals
    var one: T = 1.0;
    try expect(-one == -1.0);
    var neg_one: T = -1.0;
    try expect(-neg_one == 1.0);
    var min: T = math.floatMin(T);
    try expect(-min == -math.floatMin(T));
    var neg_min: T = -math.floatMin(T);
    try expect(-neg_min == math.floatMin(T));
    var max: T = math.floatMax(T);
    try expect(-max == -math.floatMax(T));
    var neg_max: T = -math.floatMax(T);
    try expect(-neg_max == math.floatMax(T));

    // subnormals
    var zero: T = 0.0;
    try expect(-zero == -0.0);
    var neg_zero: T = -0.0;
    try expect(-neg_zero == 0.0);
    var true_min: T = math.floatTrueMin(T);
    try expect(-true_min == -math.floatTrueMin(T));
    var neg_true_min: T = -math.floatTrueMin(T);
    try expect(-neg_true_min == math.floatTrueMin(T));

    // non-finite numbers
    var inf: T = math.inf(T);
    try expect(math.isNegativeInf(-inf));
    var neg_inf: T = -math.inf(T);
    try expect(math.isPositiveInf(-neg_inf));
    var nan: T = math.nan(T);
    try expect(math.isNan(-nan));
    try expect(math.signbit(-nan));
    var neg_nan: T = -math.nan(T);
    try expect(math.isNan(-neg_nan));
    try expect(!math.signbit(-neg_nan));
}

test "eval @setFloatMode at compile-time" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const result = comptime fnWithFloatMode();
    try expect(result == 1234.0);
}

fn fnWithFloatMode() f32 {
    @setFloatMode(std.builtin.FloatMode.Strict);
    return 1234.0;
}

test "float literal at compile time not lossy" {
    try expect(16777216.0 + 1.0 == 16777217.0);
    try expect(9007199254740992.0 + 1.0 == 9007199254740993.0);
}

test "f128 at compile time is lossy" {
    try expect(@as(f128, 10384593717069655257060992658440192.0) + 1 == 10384593717069655257060992658440192.0);
}

test "comptime fixed-width float zero divided by zero produces NaN" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    inline for (.{ f16, f32, f64, f80, f128 }) |F| {
        try expect(math.isNan(@as(F, 0) / @as(F, 0)));
    }
}

test "comptime fixed-width float non-zero divided by zero produces signed Inf" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    inline for (.{ f16, f32, f64, f80, f128 }) |F| {
        const pos = @as(F, 1) / @as(F, 0);
        const neg = @as(F, -1) / @as(F, 0);
        try expect(math.isInf(pos));
        try expect(math.isInf(neg));
        try expect(pos > 0);
        try expect(neg < 0);
    }
}

test "comptime_float zero divided by zero produces zero" {
    try expect((0.0 / 0.0) == 0.0);
}
