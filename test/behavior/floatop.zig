const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const math = std.math;
const pi = std.math.pi;
const e = std.math.e;
const has_f80_rt = switch (builtin.cpu.arch) {
    .x86_64, .x86 => true,
    else => false,
};

const epsilon_16 = 0.001;
const epsilon = 0.000001;

fn epsForType(comptime T: type) T {
    return switch (T) {
        f16 => @as(f16, epsilon_16),
        else => @as(T, epsilon),
    };
}

test "floating point comparisons" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testFloatComparisons();
    comptime try testFloatComparisons();
}

fn testFloatComparisons() !void {
    inline for ([_]type{ f16, f32, f64, f128 }) |ty| {
        // No decimal part
        {
            const x: ty = 1.0;
            try expect(x == 1);
            try expect(x != 0);
            try expect(x > 0);
            try expect(x < 2);
            try expect(x >= 1);
            try expect(x <= 1);
        }
        // Non-zero decimal part
        {
            const x: ty = 1.5;
            try expect(x != 1);
            try expect(x != 2);
            try expect(x > 1);
            try expect(x < 2);
            try expect(x >= 1);
            try expect(x <= 2);
        }
    }
}

test "different sized float comparisons" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testDifferentSizedFloatComparisons();
    comptime try testDifferentSizedFloatComparisons();
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

test "negative f128 floatToInt at compile-time" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const a: f128 = -2;
    var b = @floatToInt(i64, a);
    try expect(@as(i64, -2) == b);
}

test "@sqrt" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testSqrt();
    try testSqrt();
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
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testSqrtWithVectors();
    try testSqrtWithVectors();
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
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    try testSqrtLegacy(f64, 12.0);
    comptime try testSqrtLegacy(f64, 12.0);
    try testSqrtLegacy(f32, 13.0);
    comptime try testSqrtLegacy(f32, 13.0);
    try testSqrtLegacy(f16, 13.0);
    comptime try testSqrtLegacy(f16, 13.0);

    // TODO: make this pass
    if (false) {
        const x = 14.0;
        const y = x * x;
        const z = @sqrt(y);
        comptime try expect(z == x);
    }
}

fn testSqrtLegacy(comptime T: type, x: T) !void {
    try expect(@sqrt(x * x) == x);
}

test "@sin" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testSin();
    try testSin();
}

fn testSin() !void {
    inline for ([_]type{ f16, f32, f64 }) |ty| {
        const eps = epsForType(ty);
        try expect(@sin(@as(ty, 0)) == 0);
        try expect(math.approxEqAbs(ty, @sin(@as(ty, std.math.pi)), 0, eps));
        try expect(math.approxEqAbs(ty, @sin(@as(ty, std.math.pi / 2.0)), 1, eps));
        try expect(math.approxEqAbs(ty, @sin(@as(ty, std.math.pi / 4.0)), 0.7071067811865475, eps));
    }
}

test "@sin with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testSinWithVectors();
    try testSinWithVectors();
}

fn testSinWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
    var result = @sin(v);
    try expect(math.approxEqAbs(f32, @sin(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @sin(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @sin(@as(f32, 3.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @sin(@as(f32, 4.4)), result[3], epsilon));
}

test "@cos" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testCos();
    try testCos();
}

fn testCos() !void {
    inline for ([_]type{ f16, f32, f64 }) |ty| {
        const eps = epsForType(ty);
        try expect(@cos(@as(ty, 0)) == 1);
        try expect(math.approxEqAbs(ty, @cos(@as(ty, std.math.pi)), -1, eps));
        try expect(math.approxEqAbs(ty, @cos(@as(ty, std.math.pi / 2.0)), 0, eps));
        try expect(math.approxEqAbs(ty, @cos(@as(ty, std.math.pi / 4.0)), 0.7071067811865475, eps));
    }
}

test "@cos with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testCosWithVectors();
    try testCosWithVectors();
}

fn testCosWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
    var result = @cos(v);
    try expect(math.approxEqAbs(f32, @cos(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @cos(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @cos(@as(f32, 3.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @cos(@as(f32, 4.4)), result[3], epsilon));
}

test "@exp" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testExp();
    try testExp();
}

fn testExp() !void {
    inline for ([_]type{ f16, f32, f64 }) |ty| {
        const eps = epsForType(ty);
        try expect(@exp(@as(ty, 0)) == 1);
        try expect(math.approxEqAbs(ty, @exp(@as(ty, 2)), 7.389056098930650, eps));
        try expect(math.approxEqAbs(ty, @exp(@as(ty, 5)), 148.4131591025766, eps));
    }
}

test "@exp with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testExpWithVectors();
    try testExpWithVectors();
}

fn testExpWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
    var result = @exp(v);
    try expect(math.approxEqAbs(f32, @exp(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @exp(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @exp(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @exp(@as(f32, 0.4)), result[3], epsilon));
}

test "@exp2" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testExp2();
    try testExp2();
}

fn testExp2() !void {
    inline for ([_]type{ f16, f32, f64 }) |ty| {
        const eps = epsForType(ty);
        try expect(@exp2(@as(ty, 2)) == 4);
        try expect(math.approxEqAbs(ty, @exp2(@as(ty, 1.5)), 2.8284271247462, eps));
        try expect(math.approxEqAbs(ty, @exp2(@as(ty, 4.5)), 22.627416997969, eps));
    }
}

test "@exp2" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testExp2WithVectors();
    try testExp2WithVectors();
}

fn testExp2WithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
    var result = @exp2(v);
    try expect(math.approxEqAbs(f32, @exp2(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @exp2(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @exp2(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @exp2(@as(f32, 0.4)), result[3], epsilon));
}

test "@log" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testLog();
    try testLog();
}

fn testLog() !void {
    {
        var a: f16 = e;
        try expect(math.approxEqAbs(f16, @log(a), 1, epsilon));
    }
    {
        var a: f32 = e;
        try expect(@log(a) == 1 or @log(a) == @bitCast(f32, @as(u32, 0x3f7fffff)));
    }
    {
        var a: f64 = e;
        try expect(@log(a) == 1 or @log(a) == @bitCast(f64, @as(u64, 0x3ff0000000000000)));
    }
    inline for ([_]type{ f16, f32, f64 }) |ty| {
        const eps = epsForType(ty);
        try expect(math.approxEqAbs(ty, @log(@as(ty, 2)), 0.6931471805599, eps));
        try expect(math.approxEqAbs(ty, @log(@as(ty, 5)), 1.6094379124341, eps));
    }
}

test "@log with @vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
        var result = @log(v);
        try expect(@log(@as(f32, 1.1)) == result[0]);
        try expect(@log(@as(f32, 2.2)) == result[1]);
        try expect(@log(@as(f32, 0.3)) == result[2]);
        try expect(@log(@as(f32, 0.4)) == result[3]);
    }
}

test "@log2" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testLog2();
    try testLog2();
}

fn testLog2() !void {
    inline for ([_]type{ f16, f32, f64 }) |ty| {
        const eps = epsForType(ty);
        try expect(@log2(@as(ty, 4)) == 2);
        try expect(math.approxEqAbs(ty, @log2(@as(ty, 6)), 2.5849625007212, eps));
        try expect(math.approxEqAbs(ty, @log2(@as(ty, 10)), 3.3219280948874, eps));
    }
}

test "@log2 with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    // https://github.com/ziglang/zig/issues/13681
    if (builtin.zig_backend == .stage2_llvm and
        builtin.cpu.arch == .aarch64 and
        builtin.os.tag == .windows) return error.SkipZigTest;

    comptime try testLog2WithVectors();
    try testLog2WithVectors();
}

fn testLog2WithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
    var result = @log2(v);
    try expect(@log2(@as(f32, 1.1)) == result[0]);
    try expect(@log2(@as(f32, 2.2)) == result[1]);
    try expect(@log2(@as(f32, 0.3)) == result[2]);
    try expect(@log2(@as(f32, 0.4)) == result[3]);
}

test "@log10" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testLog10();
    try testLog10();
}

fn testLog10() !void {
    inline for ([_]type{ f16, f32, f64 }) |ty| {
        const eps = epsForType(ty);
        try expect(@log10(@as(ty, 100)) == 2);
        try expect(math.approxEqAbs(ty, @log10(@as(ty, 15)), 1.176091259056, eps));
        try expect(math.approxEqAbs(ty, @log10(@as(ty, 50)), 1.698970004336, eps));
    }
}

test "@log10 with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    comptime try testLog10WithVectors();
    try testLog10WithVectors();
}

fn testLog10WithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
    var result = @log10(v);
    try expect(@log10(@as(f32, 1.1)) == result[0]);
    try expect(@log10(@as(f32, 2.2)) == result[1]);
    try expect(@log10(@as(f32, 0.3)) == result[2]);
    try expect(@log10(@as(f32, 0.4)) == result[3]);
}

test "@fabs" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testFabs();
    try testFabs();
}

fn testFabs() !void {
    try expect(@fabs(@as(f16, -2.5)) == 2.5);
    try expect(@fabs(@as(f16, 2.5)) == 2.5);
    try expect(@fabs(@as(f32, -2.5)) == 2.5);
    try expect(@fabs(@as(f32, 2.5)) == 2.5);
    try expect(@fabs(@as(f64, -2.5)) == 2.5);
    try expect(@fabs(@as(f64, 2.5)) == 2.5);

    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    // {
    //     var a: f80 = -2.5;
    //     var b: f80 = 2.5;
    //     try expect(@fabs(a) == 2.5);
    //     try expect(@fabs(b) == 2.5);
    // }
}

test "@fabs with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testFabsWithVectors();
    try testFabsWithVectors();
}

fn testFabsWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
    var result = @fabs(v);
    try expect(math.approxEqAbs(f32, @fabs(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @fabs(@as(f32, -2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @fabs(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @fabs(@as(f32, -0.4)), result[3], epsilon));
}

test "another, possibly redundant, @fabs test" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    if (builtin.os.tag == .windows and builtin.cpu.arch == .aarch64 and
        builtin.zig_backend == .stage2_c)
    {
        // https://github.com/ziglang/zig/issues/13876
        return error.SkipZigTest;
    }

    try testFabsLegacy(f128, 12.0);
    comptime try testFabsLegacy(f128, 12.0);
    try testFabsLegacy(f64, 12.0);
    comptime try testFabsLegacy(f64, 12.0);
    try testFabsLegacy(f32, 12.0);
    comptime try testFabsLegacy(f32, 12.0);
    try testFabsLegacy(f16, 12.0);
    comptime try testFabsLegacy(f16, 12.0);

    const x = 14.0;
    const y = -x;
    const z = @fabs(y);
    comptime try std.testing.expectEqual(x, z);
}

test "@fabs f80" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    try testFabsLegacy(f80, 12.0);
    comptime try testFabsLegacy(f80, 12.0);
}

fn testFabsLegacy(comptime T: type, x: T) !void {
    const y = -x;
    const z = @fabs(y);
    try expect(x == z);
}

test "a third @fabs test, surely there should not be three fabs tests" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    if (builtin.os.tag == .windows and builtin.cpu.arch == .aarch64 and
        builtin.zig_backend == .stage2_c)
    {
        // https://github.com/ziglang/zig/issues/13876
        return error.SkipZigTest;
    }

    inline for ([_]type{ f16, f32, f64, f80, f128, c_longdouble }) |T| {
        // normals
        try expect(@fabs(@as(T, 1.0)) == 1.0);
        try expect(@fabs(@as(T, -1.0)) == 1.0);
        try expect(@fabs(math.floatMin(T)) == math.floatMin(T));
        try expect(@fabs(-math.floatMin(T)) == math.floatMin(T));
        try expect(@fabs(math.floatMax(T)) == math.floatMax(T));
        try expect(@fabs(-math.floatMax(T)) == math.floatMax(T));

        // subnormals
        try expect(@fabs(@as(T, 0.0)) == 0.0);
        try expect(@fabs(@as(T, -0.0)) == 0.0);
        try expect(@fabs(math.floatTrueMin(T)) == math.floatTrueMin(T));
        try expect(@fabs(-math.floatTrueMin(T)) == math.floatTrueMin(T));

        // non-finite numbers
        try expect(math.isPositiveInf(@fabs(math.inf(T))));
        try expect(math.isPositiveInf(@fabs(-math.inf(T))));
        try expect(math.isNan(@fabs(math.nan(T))));
    }
}

test "@floor" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testFloor();
    try testFloor();
}

fn testFloor() !void {
    try expect(@floor(@as(f16, 2.1)) == 2);
    try expect(@floor(@as(f32, 2.1)) == 2);
    try expect(@floor(@as(f64, 3.5)) == 3);

    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    // {
    //     var a: f80 = 3.5;
    //     try expect(@floor(a) == 3);
    // }
}

test "@floor with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testFloorWithVectors();
    try testFloorWithVectors();
}

fn testFloorWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
    var result = @floor(v);
    try expect(math.approxEqAbs(f32, @floor(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @floor(@as(f32, -2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @floor(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @floor(@as(f32, -0.4)), result[3], epsilon));
}

test "another, possibly redundant, @floor test" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    try testFloorLegacy(f64, 12.0);
    comptime try testFloorLegacy(f64, 12.0);
    try testFloorLegacy(f32, 12.0);
    comptime try testFloorLegacy(f32, 12.0);
    try testFloorLegacy(f16, 12.0);
    comptime try testFloorLegacy(f16, 12.0);

    const x = 14.0;
    const y = x + 0.7;
    const z = @floor(y);
    comptime try expect(x == z);
}

test "@floor f80" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    if (builtin.zig_backend == .stage2_llvm and builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/12602
        return error.SkipZigTest;
    }

    try testFloorLegacy(f80, 12.0);
    comptime try testFloorLegacy(f80, 12.0);
}

test "@floor f128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    try testFloorLegacy(f128, 12.0);
    comptime try testFloorLegacy(f128, 12.0);
}

fn testFloorLegacy(comptime T: type, x: T) !void {
    const y = x + 0.6;
    const z = @floor(y);
    try expect(x == z);
}

test "@ceil" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testCeil();
    try testCeil();
}

fn testCeil() !void {
    try expect(@ceil(@as(f16, 2.1)) == 3);
    try expect(@ceil(@as(f32, 2.1)) == 3);
    try expect(@ceil(@as(f64, 3.5)) == 4);

    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    // {
    //     var a: f80 = 3.5;
    //     try expect(@ceil(a) == 4);
    // }
}

test "@ceil with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testCeilWithVectors();
    try testCeilWithVectors();
}

fn testCeilWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
    var result = @ceil(v);
    try expect(math.approxEqAbs(f32, @ceil(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @ceil(@as(f32, -2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @ceil(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @ceil(@as(f32, -0.4)), result[3], epsilon));
}

test "another, possibly redundant, @ceil test" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    try testCeilLegacy(f64, 12.0);
    comptime try testCeilLegacy(f64, 12.0);
    try testCeilLegacy(f32, 12.0);
    comptime try testCeilLegacy(f32, 12.0);
    try testCeilLegacy(f16, 12.0);
    comptime try testCeilLegacy(f16, 12.0);

    const x = 14.0;
    const y = x - 0.7;
    const z = @ceil(y);
    comptime try expect(x == z);
}

test "@ceil f80" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    if (builtin.zig_backend == .stage2_llvm and builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/12602
        return error.SkipZigTest;
    }

    try testCeilLegacy(f80, 12.0);
    comptime try testCeilLegacy(f80, 12.0);
}

test "@ceil f128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    try testCeilLegacy(f128, 12.0);
    comptime try testCeilLegacy(f128, 12.0);
}

fn testCeilLegacy(comptime T: type, x: T) !void {
    const y = x - 0.8;
    const z = @ceil(y);
    try expect(x == z);
}

test "@trunc" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testTrunc();
    try testTrunc();
}

fn testTrunc() !void {
    try expect(@trunc(@as(f16, 2.1)) == 2);
    try expect(@trunc(@as(f32, 2.1)) == 2);
    try expect(@trunc(@as(f64, -3.5)) == -3);

    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    // {
    //     var a: f80 = -3.5;
    //     try expect(@trunc(a) == -3);
    // }
}

test "@trunc with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testTruncWithVectors();
    try testTruncWithVectors();
}

fn testTruncWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
    var result = @trunc(v);
    try expect(math.approxEqAbs(f32, @trunc(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @trunc(@as(f32, -2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @trunc(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @trunc(@as(f32, -0.4)), result[3], epsilon));
}

test "another, possibly redundant, @trunc test" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    try testTruncLegacy(f64, 12.0);
    comptime try testTruncLegacy(f64, 12.0);
    try testTruncLegacy(f32, 12.0);
    comptime try testTruncLegacy(f32, 12.0);
    try testTruncLegacy(f16, 12.0);
    comptime try testTruncLegacy(f16, 12.0);

    const x = 14.0;
    const y = x + 0.7;
    const z = @trunc(y);
    comptime try expect(x == z);
}

test "@trunc f80" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    if (builtin.zig_backend == .stage2_llvm and builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/12602
        return error.SkipZigTest;
    }

    try testTruncLegacy(f80, 12.0);
    comptime try testTruncLegacy(f80, 12.0);
    comptime {
        const x: f80 = 12.0;
        const y = x + 0.8;
        const z = @trunc(y);
        try expect(x == z);
    }
}

test "@trunc f128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    try testTruncLegacy(f128, 12.0);
    comptime try testTruncLegacy(f128, 12.0);
}

fn testTruncLegacy(comptime T: type, x: T) !void {
    {
        const y = x + 0.8;
        const z = @trunc(y);
        try expect(x == z);
    }

    {
        const y = -x - 0.8;
        const z = @trunc(y);
        try expect(-x == z);
    }
}

test "negation f16" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    if (builtin.os.tag == .freebsd) {
        // TODO file issue to track this failure
        return error.SkipZigTest;
    }

    const S = struct {
        fn doTheTest() !void {
            var a: f16 = 1;
            a = -a;
            try expect(a == -1);
            a = -a;
            try expect(a == 1);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "negation f32" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var a: f32 = 1;
            a = -a;
            try expect(a == -1);
            a = -a;
            try expect(a == 1);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "negation f64" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var a: f64 = 1;
            a = -a;
            try expect(a == -1);
            a = -a;
            try expect(a == 1);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "negation f80" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var a: f80 = 1;
            a = -a;
            try expect(a == -1);
            a = -a;
            try expect(a == 1);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "negation f128" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    if (builtin.os.tag == .windows and builtin.cpu.arch == .aarch64 and
        builtin.zig_backend == .stage2_c)
    {
        // https://github.com/ziglang/zig/issues/13876
        return error.SkipZigTest;
    }

    const S = struct {
        fn doTheTest() !void {
            var a: f128 = 1;
            a = -a;
            try expect(a == -1);
            a = -a;
            try expect(a == 1);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
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
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    inline for (.{ f16, f32, f64, f80, f128 }) |F| {
        try expect(math.isNan(@as(F, 0) / @as(F, 0)));
    }
}

test "comptime fixed-width float non-zero divided by zero produces signed Inf" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
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

test "nan negation f16" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const nan_comptime = comptime math.nan(f16);
    const neg_nan_comptime = -nan_comptime;

    var nan_runtime = math.nan(f16);
    const neg_nan_runtime = -nan_runtime;

    try expect(!math.signbit(nan_runtime));
    try expect(math.signbit(neg_nan_runtime));

    try expect(!math.signbit(nan_comptime));
    try expect(math.signbit(neg_nan_comptime));
}

test "nan negation f32" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const nan_comptime = comptime math.nan(f32);
    const neg_nan_comptime = -nan_comptime;

    var nan_runtime = math.nan(f32);
    const neg_nan_runtime = -nan_runtime;

    try expect(!math.signbit(nan_runtime));
    try expect(math.signbit(neg_nan_runtime));

    try expect(!math.signbit(nan_comptime));
    try expect(math.signbit(neg_nan_comptime));
}

test "nan negation f64" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const nan_comptime = comptime math.nan(f64);
    const neg_nan_comptime = -nan_comptime;

    var nan_runtime = math.nan(f64);
    const neg_nan_runtime = -nan_runtime;

    try expect(!math.signbit(nan_runtime));
    try expect(math.signbit(neg_nan_runtime));

    try expect(!math.signbit(nan_comptime));
    try expect(math.signbit(neg_nan_comptime));
}

test "nan negation f128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const nan_comptime = comptime math.nan(f128);
    const neg_nan_comptime = -nan_comptime;

    var nan_runtime = math.nan(f128);
    const neg_nan_runtime = -nan_runtime;

    try expect(!math.signbit(nan_runtime));
    try expect(math.signbit(neg_nan_runtime));

    try expect(!math.signbit(nan_comptime));
    try expect(math.signbit(neg_nan_comptime));
}

test "nan negation f80" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const nan_comptime = comptime math.nan(f80);
    const neg_nan_comptime = -nan_comptime;

    var nan_runtime = math.nan(f80);
    const neg_nan_runtime = -nan_runtime;

    try expect(!math.signbit(nan_runtime));
    try expect(math.signbit(neg_nan_runtime));

    try expect(!math.signbit(nan_comptime));
    try expect(math.signbit(neg_nan_comptime));
}
