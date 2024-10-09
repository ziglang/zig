const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const math = std.math;

const epsilon_16 = 0.002;
const epsilon = 0.000001;

fn epsForType(comptime T: type) T {
    return switch (T) {
        f16 => @as(f16, epsilon_16),
        else => @as(T, epsilon),
    };
}

test "add f16" {
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testAdd(f16);
    try comptime testAdd(f16);
}

test "add f32/f64" {
    try testAdd(f32);
    try comptime testAdd(f32);
    try testAdd(f64);
    try comptime testAdd(f64);
}

test "add f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testAdd(f80);
    try comptime testAdd(f80);
    try testAdd(f128);
    try comptime testAdd(f128);
    try testAdd(c_longdouble);
    try comptime testAdd(c_longdouble);
}

fn testAdd(comptime T: type) !void {
    var one_point_two_five: T = 1.25;
    var two_point_seven_five: T = 2.75;
    _ = &one_point_two_five;
    _ = &two_point_seven_five;
    try expect(one_point_two_five + two_point_seven_five == 4);
}

test "sub f16" {
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testSub(f16);
    try comptime testSub(f16);
}

test "sub f32/f64" {
    try testSub(f32);
    try comptime testSub(f32);
    try testSub(f64);
    try comptime testSub(f64);
}

test "sub f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testSub(f80);
    try comptime testSub(f80);
    try testSub(f128);
    try comptime testSub(f128);
    try testSub(c_longdouble);
    try comptime testSub(c_longdouble);
}

fn testSub(comptime T: type) !void {
    var one_point_two_five: T = 1.25;
    var two_point_seven_five: T = 2.75;
    _ = &one_point_two_five;
    _ = &two_point_seven_five;
    try expect(one_point_two_five - two_point_seven_five == -1.5);
}

test "mul f16" {
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testMul(f16);
    try comptime testMul(f16);
}

test "mul f32/f64" {
    try testMul(f32);
    try comptime testMul(f32);
    try testMul(f64);
    try comptime testMul(f64);
}

test "mul f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testMul(f80);
    try comptime testMul(f80);
    try testMul(f128);
    try comptime testMul(f128);
    try testMul(c_longdouble);
    try comptime testMul(c_longdouble);
}

fn testMul(comptime T: type) !void {
    var one_point_two_five: T = 1.25;
    var two_point_seven_five: T = 2.75;
    _ = &one_point_two_five;
    _ = &two_point_seven_five;
    try expect(one_point_two_five * two_point_seven_five == 3.4375);
}

test "cmp f16" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.cpu.arch.isArmOrThumb() and builtin.target.floatAbi() == .soft) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/21234

    try testCmp(f16);
    try comptime testCmp(f16);
}

test "cmp f32/f64" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.cpu.arch.isArmOrThumb() and builtin.target.floatAbi() == .soft) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/21234

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
        _ = &x;
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
        _ = &x;
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
    _ = &edges;
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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testDifferentSizedFloatComparisons();
    try comptime testDifferentSizedFloatComparisons();
}

fn testDifferentSizedFloatComparisons() !void {
    var a: f16 = 1;
    var b: f64 = 2;
    _ = .{ &a, &b };
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
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const a: f128 = -2;
    var b: i64 = @intFromFloat(a);
    _ = &b;
    try expect(@as(i64, -2) == b);
}

test "@sqrt f16" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testSqrt(f16);
    try comptime testSqrt(f16);
}

test "@sqrt f32/f64" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;

    try testSqrt(f32);
    try comptime testSqrt(f32);
    try testSqrt(f64);
    try comptime testSqrt(f64);
}

test "@sqrt f80/f128/c_longdouble" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    if (builtin.os.tag == .freebsd) {
        // TODO https://github.com/ziglang/zig/issues/10875
        return error.SkipZigTest;
    }

    try testSqrt(f80);
    try comptime testSqrt(f80);
    try testSqrt(f128);
    try comptime testSqrt(f128);
    try testSqrt(c_longdouble);
    try comptime testSqrt(c_longdouble);
}

fn testSqrt(comptime T: type) !void {
    const eps = epsForType(T);
    var four: T = 4.0;
    try expect(@sqrt(four) == 2.0);
    var nine: T = 9.0;
    try expect(@sqrt(nine) == 3.0);
    var twenty_five: T = 25.0;
    try expect(@sqrt(twenty_five) == 5.0);
    var sixty_four: T = 64.0;
    try expect(@sqrt(sixty_four) == 8.0);
    var one_point_one: T = 1.1;

    try expect(math.approxEqAbs(T, @sqrt(one_point_one), 1.0488088481701516, eps));
    var two: T = 2.0;
    try expect(math.approxEqAbs(T, @sqrt(two), 1.4142135623730950, eps));
    var three_point_six: T = 3.6;
    try expect(math.approxEqAbs(T, @sqrt(three_point_six), 1.8973665961010276, eps));
    var sixty_four_point_one: T = 64.1;
    try expect(math.approxEqAbs(T, @sqrt(sixty_four_point_one), 8.00624756049923802, eps));
    var twelve: T = 12.0;
    try expect(math.approxEqAbs(T, @sqrt(twelve), 3.46410161513775459, eps));
    var thirteen: T = 13.0;
    try expect(math.approxEqAbs(T, @sqrt(thirteen), 3.60555127546398929, eps));
    var fourteen: T = 14.0;
    try expect(math.approxEqAbs(T, @sqrt(fourteen), 3.74165738677394139, eps));
    var a: T = 7.539840;
    try expect(math.approxEqAbs(T, @sqrt(a), 2.74587690911300684, eps));
    var b: T = 19.230934;
    try expect(math.approxEqAbs(T, @sqrt(b), 4.38530888307767894, eps));
    var c: T = 8942.230469;
    try expect(math.approxEqAbs(T, @sqrt(c), 94.5633674791671111, eps));

    // special cases
    var inf: T = math.inf(T);
    try expect(math.isPositiveInf(@sqrt(inf)));
    var zero: T = 0.0;
    try expect(@sqrt(zero) == 0.0);
    var neg_zero: T = -0.0;
    try expect(@sqrt(neg_zero) == 0.0);
    var neg_one: T = -1.0;
    try expect(math.isNan(@sqrt(neg_one)));
    var nan: T = math.nan(T);
    try expect(math.isNan(@sqrt(nan)));

    _ = .{
        &four,
        &nine,
        &twenty_five,
        &sixty_four,
        &one_point_one,
        &two,
        &three_point_six,
        &sixty_four_point_one,
        &twelve,
        &thirteen,
        &fourteen,
        &a,
        &b,
        &c,
        &inf,
        &zero,
        &neg_zero,
        &neg_one,
        &nan,
    };
}

test "@sqrt with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testSqrtWithVectors();
    try comptime testSqrtWithVectors();
}

fn testSqrtWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
    _ = &v;
    const result = @sqrt(v);
    try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 3.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @sqrt(@as(f32, 4.4)), result[3], epsilon));
}

test "@sin f16" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testSin(f16);
    try comptime testSin(f16);
}

test "@sin f32/f64" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    _ = &zero;
    try expect(@sin(zero) == 0);
    var pi: T = math.pi;
    _ = &pi;
    try expect(math.approxEqAbs(T, @sin(pi), 0, eps));
    try expect(math.approxEqAbs(T, @sin(pi / 2.0), 1, eps));
    try expect(math.approxEqAbs(T, @sin(pi / 4.0), 0.7071067811865475, eps));
}

test "@sin with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testSinWithVectors();
    try comptime testSinWithVectors();
}

fn testSinWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
    _ = &v;
    const result = @sin(v);
    try expect(math.approxEqAbs(f32, @sin(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @sin(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @sin(@as(f32, 3.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @sin(@as(f32, 4.4)), result[3], epsilon));
}

test "@cos f16" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testCos(f16);
    try comptime testCos(f16);
}

test "@cos f32/f64" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    _ = &zero;
    try expect(@cos(zero) == 1);
    var pi: T = math.pi;
    _ = &pi;
    try expect(math.approxEqAbs(T, @cos(pi), -1, eps));
    try expect(math.approxEqAbs(T, @cos(pi / 2.0), 0, eps));
    try expect(math.approxEqAbs(T, @cos(pi / 4.0), 0.7071067811865475, eps));
}

test "@cos with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testCosWithVectors();
    try comptime testCosWithVectors();
}

fn testCosWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
    _ = &v;
    const result = @cos(v);
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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testTan(f16);
    try comptime testTan(f16);
}

test "@tan f32/f64" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    _ = &zero;
    try expect(@tan(zero) == 0);
    var pi: T = math.pi;
    _ = &pi;
    try expect(math.approxEqAbs(T, @tan(pi), 0, eps));
    try expect(math.approxEqAbs(T, @tan(pi / 3.0), 1.732050807568878, eps));
    try expect(math.approxEqAbs(T, @tan(pi / 4.0), 1, eps));
}

test "@tan with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testTanWithVectors();
    try comptime testTanWithVectors();
}

fn testTanWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
    _ = &v;
    const result = @tan(v);
    try expect(math.approxEqAbs(f32, @tan(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @tan(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @tan(@as(f32, 3.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @tan(@as(f32, 4.4)), result[3], epsilon));
}

test "@exp f16" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testExp(f16);
    try comptime testExp(f16);
}

test "@exp f32/f64" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    _ = &zero;
    try expect(@exp(zero) == 1);

    var two: T = 2;
    _ = &two;
    try expect(math.approxEqAbs(T, @exp(two), 7.389056098930650, eps));

    var five: T = 5;
    _ = &five;
    try expect(math.approxEqAbs(T, @exp(five), 148.4131591025766, eps));
}

test "@exp with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testExpWithVectors();
    try comptime testExpWithVectors();
}

fn testExpWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
    _ = &v;
    const result = @exp(v);
    try expect(math.approxEqAbs(f32, @exp(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @exp(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @exp(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @exp(@as(f32, 0.4)), result[3], epsilon));
}

test "@exp2 f16" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testExp2(f16);
    try comptime testExp2(f16);
}

test "@exp2 f32/f64" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    _ = .{ &two, &one_point_five, &four_point_five };
}

test "@exp2 with @vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testExp2WithVectors();
    try comptime testExp2WithVectors();
}

fn testExp2WithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
    _ = &v;
    const result = @exp2(v);
    try expect(math.approxEqAbs(f32, @exp2(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @exp2(@as(f32, 2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @exp2(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @exp2(@as(f32, 0.4)), result[3], epsilon));
}

test "@log f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testLog(f16);
    try comptime testLog(f16);
}

test "@log f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    _ = .{ &e, &two, &five };
}

test "@log with @vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    {
        var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
        _ = &v;
        const result = @log(v);
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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testLog2(f16);
    try comptime testLog2(f16);
}

test "@log2 f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    _ = .{ &four, &six, &ten };
}

test "@log2 with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
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
    _ = &v;
    const result = @log2(v);
    try expect(@log2(@as(f32, 1.1)) == result[0]);
    try expect(@log2(@as(f32, 2.2)) == result[1]);
    try expect(@log2(@as(f32, 0.3)) == result[2]);
    try expect(@log2(@as(f32, 0.4)) == result[3]);
}

test "@log10 f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testLog10(f16);
    try comptime testLog10(f16);
}

test "@log10 f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    _ = .{ &hundred, &fifteen, &fifty };
}

test "@log10 with vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testLog10WithVectors();
    try comptime testLog10WithVectors();
}

fn testLog10WithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
    _ = &v;
    const result = @log10(v);
    try expect(@log10(@as(f32, 1.1)) == result[0]);
    try expect(@log10(@as(f32, 2.2)) == result[1]);
    try expect(@log10(@as(f32, 0.3)) == result[2]);
    try expect(@log10(@as(f32, 0.4)) == result[3]);
}

test "@abs f16" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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

    _ = .{
        &two_point_five,
        &neg_two_point_five,
        &twelve,
        &neg_fourteen,
        &one,
        &neg_one,
        &min,
        &neg_min,
        &max,
        &neg_max,
        &zero,
        &neg_zero,
        &true_min,
        &neg_true_min,
        &inf,
        &neg_inf,
        &nan,
    };
}

test "@abs with vectors" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testFabsWithVectors();
    try comptime testFabsWithVectors();
}

fn testFabsWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
    _ = &v;
    const result = @abs(v);
    try expect(math.approxEqAbs(f32, @abs(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @abs(@as(f32, -2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @abs(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @abs(@as(f32, -0.4)), result[3], epsilon));
}

test "@floor f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testFloor(f16);
    try comptime testFloor(f16);
}

test "@floor f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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

    _ = .{
        &two_point_one,
        &neg_two_point_one,
        &three_point_five,
        &neg_three_point_five,
        &twelve,
        &neg_twelve,
        &fourteen_point_seven,
        &neg_fourteen_point_seven,
    };
}

test "@floor with vectors" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .sse4_1)) return error.SkipZigTest;

    try testFloorWithVectors();
    try comptime testFloorWithVectors();
}

fn testFloorWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
    _ = &v;
    const result = @floor(v);
    try expect(math.approxEqAbs(f32, @floor(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @floor(@as(f32, -2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @floor(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @floor(@as(f32, -0.4)), result[3], epsilon));
}

test "@ceil f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testCeil(f16);
    try comptime testCeil(f16);
}

test "@ceil f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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

    _ = .{
        &two_point_one,
        &neg_two_point_one,
        &three_point_five,
        &neg_three_point_five,
        &twelve,
        &neg_twelve,
        &fourteen_point_seven,
        &neg_fourteen_point_seven,
    };
}

test "@ceil with vectors" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .sse4_1)) return error.SkipZigTest;

    try testCeilWithVectors();
    try comptime testCeilWithVectors();
}

fn testCeilWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
    _ = &v;
    const result = @ceil(v);
    try expect(math.approxEqAbs(f32, @ceil(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @ceil(@as(f32, -2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @ceil(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @ceil(@as(f32, -0.4)), result[3], epsilon));
}

test "@trunc f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testTrunc(f16);
    try comptime testTrunc(f16);
}

test "@trunc f32/f64" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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

    _ = .{
        &two_point_one,
        &neg_two_point_one,
        &three_point_five,
        &neg_three_point_five,
        &twelve,
        &neg_twelve,
        &fourteen_point_seven,
        &neg_fourteen_point_seven,
    };
}

test "@trunc with vectors" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .sse4_1)) return error.SkipZigTest;

    try testTruncWithVectors();
    try comptime testTruncWithVectors();
}

fn testTruncWithVectors() !void {
    var v: @Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
    _ = &v;
    const result = @trunc(v);
    try expect(math.approxEqAbs(f32, @trunc(@as(f32, 1.1)), result[0], epsilon));
    try expect(math.approxEqAbs(f32, @trunc(@as(f32, -2.2)), result[1], epsilon));
    try expect(math.approxEqAbs(f32, @trunc(@as(f32, 0.3)), result[2], epsilon));
    try expect(math.approxEqAbs(f32, @trunc(@as(f32, -0.4)), result[3], epsilon));
}

test "neg f16" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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

    _ = .{
        &two_point_five,
        &neg_two_point_five,
        &twelve,
        &neg_fourteen,
        &one,
        &neg_one,
        &min,
        &neg_min,
        &max,
        &neg_max,
        &zero,
        &neg_zero,
        &true_min,
        &neg_true_min,
        &inf,
        &neg_inf,
        &nan,
        &neg_nan,
    };
}

test "eval @setFloatMode at compile-time" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const result = comptime fnWithFloatMode();
    try expect(result == 1234.0);
}

fn fnWithFloatMode() f32 {
    @setFloatMode(std.builtin.FloatMode.strict);
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
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    inline for (.{ f16, f32, f64, f80, f128 }) |F| {
        try expect(math.isNan(@as(F, 0) / @as(F, 0)));
    }
}

test "comptime fixed-width float non-zero divided by zero produces signed Inf" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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

test "comptime float compared with runtime int" {
    const f = 10.0;
    var i: usize = 0;
    _ = &i;
    try std.testing.expect(i < f);
}
test "comptime nan < runtime 0" {
    const f = comptime std.math.nan(f64);
    var i: usize = 0;
    _ = &i;
    try std.testing.expect(!(f < i));
}
test "comptime inf > runtime 0" {
    const f = comptime std.math.inf(f64);
    var i: usize = 0;
    _ = &i;
    try std.testing.expect(f > i);
}
test "comptime -inf < runtime 0" {
    const f = comptime -std.math.inf(f64);
    var i: usize = 0;
    _ = &i;
    try std.testing.expect(f < i);
}
test "comptime inf >= runtime 1" {
    const f = comptime std.math.inf(f64);
    var i: usize = 1;
    _ = &i;
    try std.testing.expect(f >= i);
}
test "comptime isNan(nan * 1)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const nan_times_one = comptime std.math.nan(f64) * 1;
    try std.testing.expect(std.math.isNan(nan_times_one));
}
test "runtime isNan(nan * 1)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const nan_times_one = std.math.nan(f64) * 1;
    try std.testing.expect(std.math.isNan(nan_times_one));
}
test "comptime isNan(nan * 0)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const nan_times_zero = comptime std.math.nan(f64) * 0;
    try std.testing.expect(std.math.isNan(nan_times_zero));
    const zero_times_nan = 0 * comptime std.math.nan(f64);
    try std.testing.expect(std.math.isNan(zero_times_nan));
}
test "runtime isNan(nan * 0)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const nan_times_zero = std.math.nan(f64) * 0;
    try std.testing.expect(std.math.isNan(nan_times_zero));
    const zero_times_nan = 0 * std.math.nan(f64);
    try std.testing.expect(std.math.isNan(zero_times_nan));
}
test "comptime isNan(inf * 0)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const inf_times_zero = comptime std.math.inf(f64) * 0;
    try std.testing.expect(std.math.isNan(inf_times_zero));
    const zero_times_inf = 0 * comptime std.math.inf(f64);
    try std.testing.expect(std.math.isNan(zero_times_inf));
}
test "runtime isNan(inf * 0)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const inf_times_zero = std.math.inf(f64) * 0;
    try std.testing.expect(std.math.isNan(inf_times_zero));
    const zero_times_inf = 0 * std.math.inf(f64);
    try std.testing.expect(std.math.isNan(zero_times_inf));
}

test "optimized float mode" {
    if (builtin.mode == .Debug) return error.SkipZigTest;

    const big = 0x1p40;
    const small = 0.001;
    const tiny = 0x1p-10;

    const S = struct {
        fn strict(x: f64) f64 {
            @setFloatMode(.strict);
            return x + big - big;
        }
        fn optimized(x: f64) f64 {
            @setFloatMode(.optimized);
            return x + big - big;
        }
    };
    try expect(S.optimized(small) == small);
    try expect(S.strict(small) == tiny);
}
