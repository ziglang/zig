const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const math = std.math;
const pi = std.math.pi;
const e = std.math.e;
const has_f80_rt = switch (builtin.cpu.arch) {
    .x86_64, .i386 => true,
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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const a: f128 = -2;
    var b = @floatToInt(i64, a);
    try expect(@as(i64, -2) == b);
}

test "@sqrt" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testSqrt();
    try testSqrt();
}

fn testSqrt() !void {
    try expect(@sqrt(@as(f16, 4)) == 2);
    try expect(@sqrt(@as(f32, 9)) == 3);
    try expect(@sqrt(@as(f64, 25)) == 5);
    try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 1.1)), 1.0488088481701516, epsilon));
    try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 2.0)), 1.4142135623730950, epsilon));

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
        var result = @sqrt(v);
        try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 1.1)), result[0], epsilon));
        try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 2.2)), result[1], epsilon));
        try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 3.3)), result[2], epsilon));
        try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 4.4)), result[3], epsilon));
    }

    if (builtin.zig_backend == .stage1) {
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

test "more @sqrt f16 tests" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

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

test "@sin" {
    if (builtin.zig_backend == .stage1) {
        // stage1 emits an incorrect compile error for `@as(ty, std.math.pi / 2)`
        return error.SkipZigTest;
    }
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testSin();
    try testSin();
}

fn testSin() !void {
    inline for ([_]type{ f16, f32, f64 }) |ty| {
        const eps = epsForType(ty);
        try expect(@sin(@as(ty, 0)) == 0);
        try expect(math.approxEqAbs(ty, @sin(@as(ty, std.math.pi)), 0, eps));
        try expect(math.approxEqAbs(ty, @sin(@as(ty, std.math.pi / 2)), 1, eps));
        try expect(math.approxEqAbs(ty, @sin(@as(ty, std.math.pi / 4)), 0.7071067811865475, eps));
    }

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
        var result = @sin(v);
        try expect(math.approxEqAbs(f32, @sin(@as(f32, 1.1)), result[0], epsilon));
        try expect(math.approxEqAbs(f32, @sin(@as(f32, 2.2)), result[1], epsilon));
        try expect(math.approxEqAbs(f32, @sin(@as(f32, 3.3)), result[2], epsilon));
        try expect(math.approxEqAbs(f32, @sin(@as(f32, 4.4)), result[3], epsilon));
    }
}

test "@cos" {
    if (builtin.zig_backend == .stage1) {
        // stage1 emits an incorrect compile error for `@as(ty, std.math.pi / 2)`
        return error.SkipZigTest;
    }
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testCos();
    try testCos();
}

fn testCos() !void {
    inline for ([_]type{ f16, f32, f64 }) |ty| {
        const eps = epsForType(ty);
        try expect(@cos(@as(ty, 0)) == 1);
        try expect(math.approxEqAbs(ty, @cos(@as(ty, std.math.pi)), -1, eps));
        try expect(math.approxEqAbs(ty, @cos(@as(ty, std.math.pi / 2)), 0, eps));
        try expect(math.approxEqAbs(ty, @cos(@as(ty, std.math.pi / 4)), 0.7071067811865475, eps));
    }

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
        var result = @cos(v);
        try expect(math.approxEqAbs(f32, @cos(@as(f32, 1.1)), result[0], epsilon));
        try expect(math.approxEqAbs(f32, @cos(@as(f32, 2.2)), result[1], epsilon));
        try expect(math.approxEqAbs(f32, @cos(@as(f32, 3.3)), result[2], epsilon));
        try expect(math.approxEqAbs(f32, @cos(@as(f32, 4.4)), result[3], epsilon));
    }
}

test "@exp" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

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

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
        var result = @exp(v);
        try expect(math.approxEqAbs(f32, @exp(@as(f32, 1.1)), result[0], epsilon));
        try expect(math.approxEqAbs(f32, @exp(@as(f32, 2.2)), result[1], epsilon));
        try expect(math.approxEqAbs(f32, @exp(@as(f32, 0.3)), result[2], epsilon));
        try expect(math.approxEqAbs(f32, @exp(@as(f32, 0.4)), result[3], epsilon));
    }
}

test "@exp2" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

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

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
        var result = @exp2(v);
        try expect(math.approxEqAbs(f32, @exp2(@as(f32, 1.1)), result[0], epsilon));
        try expect(math.approxEqAbs(f32, @exp2(@as(f32, 2.2)), result[1], epsilon));
        try expect(math.approxEqAbs(f32, @exp2(@as(f32, 0.3)), result[2], epsilon));
        try expect(math.approxEqAbs(f32, @exp2(@as(f32, 0.4)), result[3], epsilon));
    }
}

test "@log" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

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

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
        var result = @log2(v);
        try expect(@log2(@as(f32, 1.1)) == result[0]);
        try expect(@log2(@as(f32, 2.2)) == result[1]);
        try expect(@log2(@as(f32, 0.3)) == result[2]);
        try expect(@log2(@as(f32, 0.4)) == result[3]);
    }
}

test "@log10" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

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

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
        var result = @log10(v);
        try expect(@log10(@as(f32, 1.1)) == result[0]);
        try expect(@log10(@as(f32, 2.2)) == result[1]);
        try expect(@log10(@as(f32, 0.3)) == result[2]);
        try expect(@log10(@as(f32, 0.4)) == result[3]);
    }
}

test "@fabs" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

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

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
        var result = @fabs(v);
        try expect(math.approxEqAbs(f32, @fabs(@as(f32, 1.1)), result[0], epsilon));
        try expect(math.approxEqAbs(f32, @fabs(@as(f32, -2.2)), result[1], epsilon));
        try expect(math.approxEqAbs(f32, @fabs(@as(f32, 0.3)), result[2], epsilon));
        try expect(math.approxEqAbs(f32, @fabs(@as(f32, -0.4)), result[3], epsilon));
    }
}

test "@floor" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

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

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
        var result = @floor(v);
        try expect(math.approxEqAbs(f32, @floor(@as(f32, 1.1)), result[0], epsilon));
        try expect(math.approxEqAbs(f32, @floor(@as(f32, -2.2)), result[1], epsilon));
        try expect(math.approxEqAbs(f32, @floor(@as(f32, 0.3)), result[2], epsilon));
        try expect(math.approxEqAbs(f32, @floor(@as(f32, -0.4)), result[3], epsilon));
    }
}

test "@ceil" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

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

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
        var result = @ceil(v);
        try expect(math.approxEqAbs(f32, @ceil(@as(f32, 1.1)), result[0], epsilon));
        try expect(math.approxEqAbs(f32, @ceil(@as(f32, -2.2)), result[1], epsilon));
        try expect(math.approxEqAbs(f32, @ceil(@as(f32, 0.3)), result[2], epsilon));
        try expect(math.approxEqAbs(f32, @ceil(@as(f32, -0.4)), result[3], epsilon));
    }
}

test "@trunc" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

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

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
        var result = @trunc(v);
        try expect(math.approxEqAbs(f32, @trunc(@as(f32, 1.1)), result[0], epsilon));
        try expect(math.approxEqAbs(f32, @trunc(@as(f32, -2.2)), result[1], epsilon));
        try expect(math.approxEqAbs(f32, @trunc(@as(f32, 0.3)), result[2], epsilon));
        try expect(math.approxEqAbs(f32, @trunc(@as(f32, -0.4)), result[3], epsilon));
    }
}

test "negation f16" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    inline for (.{ f16, f32, f64, f80, f128 }) |F| {
        try expect(math.isNan(@as(F, 0) / @as(F, 0)));
    }
}

test "comptime fixed-width float non-zero divided by zero produces signed Inf" {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;

    try expect((0.0 / 0.0) == 0.0);
}

test "nan negation f16" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    const nan_comptime = comptime math.nan(f80);
    const neg_nan_comptime = -nan_comptime;

    var nan_runtime = math.nan(f80);
    const neg_nan_runtime = -nan_runtime;

    try expect(!math.signbit(nan_runtime));
    try expect(math.signbit(neg_nan_runtime));

    try expect(!math.signbit(nan_comptime));
    try expect(math.signbit(neg_nan_comptime));
}
