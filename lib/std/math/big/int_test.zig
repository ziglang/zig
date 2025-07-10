const std = @import("../../std.zig");
const builtin = @import("builtin");
const mem = std.mem;
const testing = std.testing;
const Managed = std.math.big.int.Managed;
const Mutable = std.math.big.int.Mutable;
const Limb = std.math.big.Limb;
const SignedLimb = std.math.big.SignedLimb;
const DoubleLimb = std.math.big.DoubleLimb;
const SignedDoubleLimb = std.math.big.SignedDoubleLimb;
const calcTwosCompLimbCount = std.math.big.int.calcTwosCompLimbCount;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;

// NOTE: All the following tests assume the max machine-word will be 64-bit.
//
// They will still run on larger than this and should pass, but the multi-limb code-paths
// may be untested in some cases.

fn expectNormalized(expected: comptime_int, actual: std.math.big.int.Const) !void {
    try testing.expectEqual(expected >= 0, actual.positive);
    try testing.expectEqual(std.math.big.int.calcLimbLen(expected), actual.limbs.len);
    try testing.expect(actual.orderAgainstScalar(expected).compare(.eq));
}

test "comptime_int set" {
    comptime var s = 0xefffffff00000001eeeeeeefaaaaaaab;
    var a = try Managed.initSet(testing.allocator, s);
    defer a.deinit();

    const s_limb_count = 128 / @typeInfo(Limb).int.bits;

    comptime var i: usize = 0;
    inline while (i < s_limb_count) : (i += 1) {
        const result = @as(Limb, s & maxInt(Limb));
        s >>= @typeInfo(Limb).int.bits / 2;
        s >>= @typeInfo(Limb).int.bits / 2;
        try testing.expectEqual(result, a.limbs[i]);
    }
}

test "comptime_int set negative" {
    var a = try Managed.initSet(testing.allocator, -10);
    defer a.deinit();

    try testing.expectEqual(10, a.limbs[0]);
    try testing.expectEqual(false, a.isPositive());
}

test "int set unaligned small" {
    var a = try Managed.initSet(testing.allocator, @as(u7, 45));
    defer a.deinit();

    try testing.expectEqual(45, a.limbs[0]);
    try testing.expectEqual(true, a.isPositive());
}

test "comptime_int to" {
    var a = try Managed.initSet(testing.allocator, 0xefffffff00000001eeeeeeefaaaaaaab);
    defer a.deinit();

    try testing.expectEqual(0xefffffff00000001eeeeeeefaaaaaaab, try a.toInt(u128));
}

test "sub-limb to" {
    var a = try Managed.initSet(testing.allocator, 10);
    defer a.deinit();

    try testing.expectEqual(10, try a.toInt(u8));
}

test "set negative minimum" {
    var a = try Managed.initSet(testing.allocator, @as(i64, minInt(i64)));
    defer a.deinit();

    try testing.expectEqual(minInt(i64), try a.toInt(i64));
}

test "set double-width maximum then zero" {
    var a = try Managed.initSet(testing.allocator, maxInt(DoubleLimb));
    defer a.deinit();
    try a.set(@as(DoubleLimb, 0));

    try testing.expectEqual(@as(DoubleLimb, 0), try a.toInt(DoubleLimb));
}

test "to target too small error" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff);
    defer a.deinit();

    try testing.expectError(error.TargetTooSmall, a.toInt(u8));
}

fn setFloat(comptime Float: type) !void {
    var res_limbs: [std.math.big.int.calcNonZeroTwosCompLimbCount(11)]Limb = undefined;
    var res: Mutable = .{
        .limbs = &res_limbs,
        .len = undefined,
        .positive = undefined,
    };

    try testing.expectEqual(.exact, res.setFloat(@as(Float, -0x1p10), .nearest_even));
    try expectNormalized(-1 << 10, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -0x1p10), .away));
    try expectNormalized(-1 << 10, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -0x1p10), .trunc));
    try expectNormalized(-1 << 10, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -0x1p10), .floor));
    try expectNormalized(-1 << 10, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -0x1p10), .ceil));
    try expectNormalized(-1 << 10, res.toConst());

    try testing.expectEqual(.exact, res.setFloat(@as(Float, -2.0), .nearest_even));
    try expectNormalized(-2, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -2.0), .away));
    try expectNormalized(-2, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -2.0), .trunc));
    try expectNormalized(-2, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -2.0), .floor));
    try expectNormalized(-2, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -2.0), .ceil));
    try expectNormalized(-2, res.toConst());

    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -1.5), .nearest_even));
    try expectNormalized(-2, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -1.5), .away));
    try expectNormalized(-2, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -1.5), .trunc));
    try expectNormalized(-1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -1.5), .floor));
    try expectNormalized(-2, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -1.5), .ceil));
    try expectNormalized(-1, res.toConst());

    try testing.expectEqual(.exact, res.setFloat(@as(Float, -1.0), .nearest_even));
    try expectNormalized(-1, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -1.0), .away));
    try expectNormalized(-1, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -1.0), .trunc));
    try expectNormalized(-1, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -1.0), .floor));
    try expectNormalized(-1, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -1.0), .ceil));
    try expectNormalized(-1, res.toConst());

    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.75), .nearest_even));
    try expectNormalized(-1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.75), .away));
    try expectNormalized(-1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.75), .trunc));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.75), .floor));
    try expectNormalized(-1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.75), .ceil));
    try expectNormalized(0, res.toConst());

    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.5), .nearest_even));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.5), .away));
    try expectNormalized(-1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.5), .trunc));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.5), .floor));
    try expectNormalized(-1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.5), .ceil));
    try expectNormalized(0, res.toConst());

    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.25), .nearest_even));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.25), .away));
    try expectNormalized(-1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.25), .trunc));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.25), .floor));
    try expectNormalized(-1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, -0.25), .ceil));
    try expectNormalized(0, res.toConst());

    try testing.expectEqual(.exact, res.setFloat(@as(Float, -0.0), .nearest_even));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -0.0), .away));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -0.0), .trunc));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -0.0), .floor));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, -0.0), .ceil));
    try expectNormalized(0, res.toConst());

    try testing.expectEqual(.exact, res.setFloat(@as(Float, 0.0), .nearest_even));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 0.0), .away));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 0.0), .trunc));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 0.0), .floor));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 0.0), .ceil));
    try expectNormalized(0, res.toConst());

    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.25), .nearest_even));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.25), .away));
    try expectNormalized(1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.25), .trunc));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.25), .floor));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.25), .ceil));
    try expectNormalized(1, res.toConst());

    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.5), .nearest_even));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.5), .away));
    try expectNormalized(1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.5), .trunc));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.5), .floor));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.5), .ceil));
    try expectNormalized(1, res.toConst());

    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.75), .nearest_even));
    try expectNormalized(1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.75), .away));
    try expectNormalized(1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.75), .trunc));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.75), .floor));
    try expectNormalized(0, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 0.75), .ceil));
    try expectNormalized(1, res.toConst());

    try testing.expectEqual(.exact, res.setFloat(@as(Float, 1.0), .nearest_even));
    try expectNormalized(1, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 1.0), .away));
    try expectNormalized(1, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 1.0), .trunc));
    try expectNormalized(1, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 1.0), .floor));
    try expectNormalized(1, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 1.0), .ceil));
    try expectNormalized(1, res.toConst());

    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 1.5), .nearest_even));
    try expectNormalized(2, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 1.5), .away));
    try expectNormalized(2, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 1.5), .trunc));
    try expectNormalized(1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 1.5), .floor));
    try expectNormalized(1, res.toConst());
    try testing.expectEqual(.inexact, res.setFloat(@as(Float, 1.5), .ceil));
    try expectNormalized(2, res.toConst());

    try testing.expectEqual(.exact, res.setFloat(@as(Float, 2.0), .nearest_even));
    try expectNormalized(2, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 2.0), .away));
    try expectNormalized(2, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 2.0), .trunc));
    try expectNormalized(2, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 2.0), .floor));
    try expectNormalized(2, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 2.0), .ceil));
    try expectNormalized(2, res.toConst());

    try testing.expectEqual(.exact, res.setFloat(@as(Float, 0x1p10), .nearest_even));
    try expectNormalized(1 << 10, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 0x1p10), .away));
    try expectNormalized(1 << 10, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 0x1p10), .trunc));
    try expectNormalized(1 << 10, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 0x1p10), .floor));
    try expectNormalized(1 << 10, res.toConst());
    try testing.expectEqual(.exact, res.setFloat(@as(Float, 0x1p10), .ceil));
    try expectNormalized(1 << 10, res.toConst());
}
test setFloat {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    try setFloat(f16);
    try setFloat(f32);
    try setFloat(f64);
    try setFloat(f80);
    try setFloat(f128);
    try setFloat(c_longdouble);
    try setFloat(comptime_float);
}

fn toFloat(comptime Float: type) !void {
    const Result = struct { Float, std.math.big.int.Exactness };
    const fractional_bits = std.math.floatFractionalBits(Float);

    var int_limbs: [
        std.math.big.int.calcNonZeroTwosCompLimbCount(2 + fractional_bits)
    ]Limb = undefined;
    var int: Mutable = .{
        .limbs = &int_limbs,
        .len = undefined,
        .positive = undefined,
    };

    int.set(-(1 << (fractional_bits + 1)) - 1);
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1), .inexact },
        int.toFloat(Float, .nearest_even),
    );
    try testing.expectEqual(
        Result{ comptime std.math.nextAfter(
            Float,
            -std.math.ldexp(@as(Float, 1), fractional_bits + 1),
            -std.math.inf(Float),
        ), .inexact },
        int.toFloat(Float, .away),
    );
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1), .inexact },
        int.toFloat(Float, .trunc),
    );
    try testing.expectEqual(
        Result{ comptime std.math.nextAfter(
            Float,
            -std.math.ldexp(@as(Float, 1), fractional_bits + 1),
            -std.math.inf(Float),
        ), .inexact },
        int.toFloat(Float, .floor),
    );
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1), .inexact },
        int.toFloat(Float, .ceil),
    );

    int.set(-1 << (fractional_bits + 1));
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1), .exact },
        int.toFloat(Float, .nearest_even),
    );
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1), .exact },
        int.toFloat(Float, .away),
    );
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1), .exact },
        int.toFloat(Float, .trunc),
    );
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1), .exact },
        int.toFloat(Float, .floor),
    );
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1), .exact },
        int.toFloat(Float, .ceil),
    );

    int.set(-(1 << (fractional_bits + 1)) + 1);
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1) + 1.0, .exact },
        int.toFloat(Float, .nearest_even),
    );
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1) + 1.0, .exact },
        int.toFloat(Float, .away),
    );
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1) + 1.0, .exact },
        int.toFloat(Float, .trunc),
    );
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1) + 1.0, .exact },
        int.toFloat(Float, .floor),
    );
    try testing.expectEqual(
        Result{ comptime -std.math.ldexp(@as(Float, 1), fractional_bits + 1) + 1.0, .exact },
        int.toFloat(Float, .ceil),
    );

    int.set(-1 << 10);
    try testing.expectEqual(Result{ -0x1p10, .exact }, int.toFloat(Float, .nearest_even));
    try testing.expectEqual(Result{ -0x1p10, .exact }, int.toFloat(Float, .away));
    try testing.expectEqual(Result{ -0x1p10, .exact }, int.toFloat(Float, .trunc));
    try testing.expectEqual(Result{ -0x1p10, .exact }, int.toFloat(Float, .floor));
    try testing.expectEqual(Result{ -0x1p10, .exact }, int.toFloat(Float, .ceil));

    int.set(-1);
    try testing.expectEqual(Result{ -1.0, .exact }, int.toFloat(Float, .nearest_even));
    try testing.expectEqual(Result{ -1.0, .exact }, int.toFloat(Float, .away));
    try testing.expectEqual(Result{ -1.0, .exact }, int.toFloat(Float, .trunc));
    try testing.expectEqual(Result{ -1.0, .exact }, int.toFloat(Float, .floor));
    try testing.expectEqual(Result{ -1.0, .exact }, int.toFloat(Float, .ceil));

    int.set(0);
    try testing.expectEqual(Result{ 0.0, .exact }, int.toFloat(Float, .nearest_even));
    try testing.expectEqual(Result{ 0.0, .exact }, int.toFloat(Float, .away));
    try testing.expectEqual(Result{ 0.0, .exact }, int.toFloat(Float, .trunc));
    try testing.expectEqual(Result{ 0.0, .exact }, int.toFloat(Float, .floor));
    try testing.expectEqual(Result{ 0.0, .exact }, int.toFloat(Float, .ceil));

    int.set(1);
    try testing.expectEqual(Result{ 1.0, .exact }, int.toFloat(Float, .nearest_even));
    try testing.expectEqual(Result{ 1.0, .exact }, int.toFloat(Float, .away));
    try testing.expectEqual(Result{ 1.0, .exact }, int.toFloat(Float, .trunc));
    try testing.expectEqual(Result{ 1.0, .exact }, int.toFloat(Float, .floor));
    try testing.expectEqual(Result{ 1.0, .exact }, int.toFloat(Float, .ceil));

    int.set(1 << 10);
    try testing.expectEqual(Result{ 0x1p10, .exact }, int.toFloat(Float, .nearest_even));
    try testing.expectEqual(Result{ 0x1p10, .exact }, int.toFloat(Float, .away));
    try testing.expectEqual(Result{ 0x1p10, .exact }, int.toFloat(Float, .trunc));
    try testing.expectEqual(Result{ 0x1p10, .exact }, int.toFloat(Float, .floor));
    try testing.expectEqual(Result{ 0x1p10, .exact }, int.toFloat(Float, .ceil));

    int.set((1 << (fractional_bits + 1)) - 1);
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1) - 1.0, .exact },
        int.toFloat(Float, .nearest_even),
    );
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1) - 1.0, .exact },
        int.toFloat(Float, .away),
    );
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1) - 1.0, .exact },
        int.toFloat(Float, .trunc),
    );
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1) - 1.0, .exact },
        int.toFloat(Float, .floor),
    );
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1) - 1.0, .exact },
        int.toFloat(Float, .ceil),
    );

    int.set(1 << (fractional_bits + 1));
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1), .exact },
        int.toFloat(Float, .nearest_even),
    );
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1), .exact },
        int.toFloat(Float, .away),
    );
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1), .exact },
        int.toFloat(Float, .trunc),
    );
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1), .exact },
        int.toFloat(Float, .floor),
    );
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1), .exact },
        int.toFloat(Float, .ceil),
    );

    int.set((1 << (fractional_bits + 1)) + 1);
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1), .inexact },
        int.toFloat(Float, .nearest_even),
    );
    try testing.expectEqual(
        Result{ comptime std.math.nextAfter(
            Float,
            std.math.ldexp(@as(Float, 1), fractional_bits + 1),
            std.math.inf(Float),
        ), .inexact },
        int.toFloat(Float, .away),
    );
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1), .inexact },
        int.toFloat(Float, .trunc),
    );
    try testing.expectEqual(
        Result{ comptime std.math.ldexp(@as(Float, 1), fractional_bits + 1), .inexact },
        int.toFloat(Float, .floor),
    );
    try testing.expectEqual(
        Result{ comptime std.math.nextAfter(
            Float,
            std.math.ldexp(@as(Float, 1), fractional_bits + 1),
            std.math.inf(Float),
        ), .inexact },
        int.toFloat(Float, .ceil),
    );
}
test toFloat {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/24191
    try toFloat(f16);
    try toFloat(f32);
    try toFloat(f64);
    try toFloat(f80);
    try toFloat(f128);
    try toFloat(c_longdouble);
}

test "normalize" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();
    try a.ensureCapacity(8);

    a.limbs[0] = 1;
    a.limbs[1] = 2;
    a.limbs[2] = 3;
    a.limbs[3] = 0;
    a.normalize(4);
    try testing.expectEqual(3, a.len());

    a.limbs[0] = 1;
    a.limbs[1] = 2;
    a.limbs[2] = 3;
    a.normalize(3);
    try testing.expectEqual(3, a.len());

    a.limbs[0] = 0;
    a.limbs[1] = 0;
    a.normalize(2);
    try testing.expectEqual(1, a.len());

    a.limbs[0] = 0;
    a.normalize(1);
    try testing.expectEqual(1, a.len());
}

test "normalize multi" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();
    try a.ensureCapacity(8);

    a.limbs[0] = 1;
    a.limbs[1] = 2;
    a.limbs[2] = 0;
    a.limbs[3] = 0;
    a.normalize(4);
    try testing.expectEqual(2, a.len());

    a.limbs[0] = 1;
    a.limbs[1] = 2;
    a.limbs[2] = 3;
    a.normalize(3);
    try testing.expectEqual(3, a.len());

    a.limbs[0] = 0;
    a.limbs[1] = 0;
    a.limbs[2] = 0;
    a.limbs[3] = 0;
    a.normalize(4);
    try testing.expectEqual(1, a.len());

    a.limbs[0] = 0;
    a.normalize(1);
    try testing.expectEqual(1, a.len());
}

test "parity" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.set(0);
    try testing.expect(a.isEven());
    try testing.expect(!a.isOdd());

    try a.set(7);
    try testing.expect(!a.isEven());
    try testing.expect(a.isOdd());
}

test "bitcount + sizeInBaseUpperBound" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.set(0b100);
    try testing.expectEqual(3, a.bitCountAbs());
    try testing.expect(a.sizeInBaseUpperBound(2) >= 3);
    try testing.expect(a.sizeInBaseUpperBound(10) >= 1);

    a.negate();
    try testing.expectEqual(3, a.bitCountAbs());
    try testing.expect(a.sizeInBaseUpperBound(2) >= 4);
    try testing.expect(a.sizeInBaseUpperBound(10) >= 2);

    try a.set(0xffffffff);
    try testing.expectEqual(32, a.bitCountAbs());
    try testing.expect(a.sizeInBaseUpperBound(2) >= 32);
    try testing.expect(a.sizeInBaseUpperBound(10) >= 10);

    try a.shiftLeft(&a, 5000);
    try testing.expectEqual(5032, a.bitCountAbs());
    try testing.expect(a.sizeInBaseUpperBound(2) >= 5032);
    a.setSign(false);

    try testing.expectEqual(5032, a.bitCountAbs());
    try testing.expect(a.sizeInBaseUpperBound(2) >= 5033);
}

test "bitcount/to" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.set(0);
    try testing.expectEqual(0, a.bitCountTwosComp());

    try testing.expectEqual(0, try a.toInt(u0));
    try testing.expectEqual(0, try a.toInt(i0));

    try a.set(-1);
    try testing.expectEqual(1, a.bitCountTwosComp());
    try testing.expectEqual(-1, try a.toInt(i1));

    try a.set(-8);
    try testing.expectEqual(4, a.bitCountTwosComp());
    try testing.expectEqual(-8, try a.toInt(i4));

    try a.set(127);
    try testing.expectEqual(7, a.bitCountTwosComp());
    try testing.expectEqual(127, try a.toInt(u7));

    try a.set(-128);
    try testing.expectEqual(8, a.bitCountTwosComp());
    try testing.expectEqual(-128, try a.toInt(i8));

    try a.set(-129);
    try testing.expectEqual(9, a.bitCountTwosComp());
    try testing.expectEqual(-129, try a.toInt(i9));
}

test "fits" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.set(0);
    try testing.expect(a.fits(u0));
    try testing.expect(a.fits(i0));

    try a.set(255);
    try testing.expect(!a.fits(u0));
    try testing.expect(!a.fits(u1));
    try testing.expect(!a.fits(i8));
    try testing.expect(a.fits(u8));
    try testing.expect(a.fits(u9));
    try testing.expect(a.fits(i9));

    try a.set(-128);
    try testing.expect(!a.fits(i7));
    try testing.expect(a.fits(i8));
    try testing.expect(a.fits(i9));
    try testing.expect(!a.fits(u9));

    try a.set(0x1ffffffffeeeeeeee);
    try testing.expect(!a.fits(u32));
    try testing.expect(!a.fits(u64));
    try testing.expect(a.fits(u65));
}

test "string set" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.setString(10, "120317241209124781241290847124");
    try testing.expectEqual(120317241209124781241290847124, try a.toInt(u128));
}

test "string negative" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.setString(10, "-1023");
    try testing.expectEqual(-1023, try a.toInt(i32));
}

test "string set number with underscores" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.setString(10, "__1_2_0_3_1_7_2_4_1_2_0_____9_1__2__4_7_8_1_2_4_1_2_9_0_8_4_7_1_2_4___");
    try testing.expectEqual(120317241209124781241290847124, try a.toInt(u128));
}

test "string set case insensitive number" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.setString(16, "aB_cD_eF");
    try testing.expectEqual(0xabcdef, try a.toInt(u32));
}

test "string set base 36" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.setString(36, "fifvthrv1mzt79ez9");
    try testing.expectEqual(123456789123456789123456789, try a.to(u128));
}

test "string set bad char error" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();
    try testing.expectError(error.InvalidCharacter, a.setString(10, "x"));
}

test "string set bad base error" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();
    try testing.expectError(error.InvalidBase, a.setString(45, "10"));
}

test "twos complement limit set" {
    try testTwosComplementLimit(u64);
    try testTwosComplementLimit(i64);
    try testTwosComplementLimit(u1);
    try testTwosComplementLimit(i1);
    try testTwosComplementLimit(u0);
    try testTwosComplementLimit(i0);
    try testTwosComplementLimit(u65);
    try testTwosComplementLimit(i65);
}

fn testTwosComplementLimit(comptime T: type) !void {
    const int_info = @typeInfo(T).int;

    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.setTwosCompIntLimit(.max, int_info.signedness, int_info.bits);
    const max: T = maxInt(T);
    try testing.expectEqual(max, try a.toInt(T));

    try a.setTwosCompIntLimit(.min, int_info.signedness, int_info.bits);
    const min: T = minInt(T);
    try testing.expectEqual(min, try a.toInt(T));
}

test "string to" {
    var a = try Managed.initSet(testing.allocator, 120317241209124781241290847124);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 10, .lower);
    defer testing.allocator.free(as);
    const es = "120317241209124781241290847124";

    try testing.expect(mem.eql(u8, as, es));
}

test "string to base base error" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff);
    defer a.deinit();

    try testing.expectError(error.InvalidBase, a.toString(testing.allocator, 45, .lower));
}

test "string to base 2" {
    var a = try Managed.initSet(testing.allocator, -0b1011);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 2, .lower);
    defer testing.allocator.free(as);
    const es = "-1011";

    try testing.expect(mem.eql(u8, as, es));
}

test "string to base 16" {
    var a = try Managed.initSet(testing.allocator, 0xefffffff00000001eeeeeeefaaaaaaab);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 16, .lower);
    defer testing.allocator.free(as);
    const es = "efffffff00000001eeeeeeefaaaaaaab";

    try testing.expect(mem.eql(u8, as, es));
}

test "string to base 36" {
    var a = try Managed.initSet(testing.allocator, 123456789123456789123456789);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 36, .lower);
    defer testing.allocator.free(as);
    const es = "fifvthrv1mzt79ez9";

    try testing.expect(mem.eql(u8, as, es));
}

test "neg string to" {
    var a = try Managed.initSet(testing.allocator, -123907434);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 10, .lower);
    defer testing.allocator.free(as);
    const es = "-123907434";

    try testing.expect(mem.eql(u8, as, es));
}

test "zero string to" {
    var a = try Managed.initSet(testing.allocator, 0);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 10, .lower);
    defer testing.allocator.free(as);
    const es = "0";

    try testing.expect(mem.eql(u8, as, es));
}

test "clone" {
    var a = try Managed.initSet(testing.allocator, 1234);
    defer a.deinit();
    var b = try a.clone();
    defer b.deinit();

    try testing.expectEqual(1234, try a.toInt(u32));
    try testing.expectEqual(1234, try b.toInt(u32));

    try a.set(77);
    try testing.expectEqual(77, try a.toInt(u32));
    try testing.expectEqual(1234, try b.toInt(u32));
}

test "swap" {
    var a = try Managed.initSet(testing.allocator, 1234);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5678);
    defer b.deinit();

    try testing.expectEqual(1234, try a.toInt(u32));
    try testing.expectEqual(5678, try b.toInt(u32));

    a.swap(&b);

    try testing.expectEqual(5678, try a.toInt(u32));
    try testing.expectEqual(1234, try b.toInt(u32));
}

test "to negative" {
    var a = try Managed.initSet(testing.allocator, -10);
    defer a.deinit();

    try testing.expectEqual(-10, try a.toInt(i32));
}

test "compare" {
    var a = try Managed.initSet(testing.allocator, -11);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 10);
    defer b.deinit();

    try testing.expectEqual(.gt, a.orderAbs(b));
    try testing.expectEqual(.lt, a.order(b));
}

test "compare similar" {
    var a = try Managed.initSet(testing.allocator, 0xffffffffeeeeeeeeffffffffeeeeeeee);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xffffffffeeeeeeeeffffffffeeeeeeef);
    defer b.deinit();

    try testing.expectEqual(.lt, a.orderAbs(b));
    try testing.expectEqual(.gt, b.orderAbs(a));
}

test "compare different limb size" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 1);
    defer b.deinit();

    try testing.expectEqual(.gt, a.orderAbs(b));
    try testing.expectEqual(.lt, b.orderAbs(a));
}

test "compare multi-limb" {
    var a = try Managed.initSet(testing.allocator, -0x7777777799999999ffffeeeeffffeeeeffffeeeef);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x7777777799999999ffffeeeeffffeeeeffffeeeee);
    defer b.deinit();

    try testing.expectEqual(.gt, a.orderAbs(b));
    try testing.expectEqual(.lt, a.order(b));
}

test "equality" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -0xffffffff1);
    defer b.deinit();

    try testing.expect(a.eqlAbs(b));
    try testing.expect(!a.eql(b));
}

test "abs" {
    var a = try Managed.initSet(testing.allocator, -5);
    defer a.deinit();

    a.abs();
    try testing.expectEqual(5, try a.toInt(u32));

    a.abs();
    try testing.expectEqual(5, try a.toInt(u32));
}

test "negate" {
    var a = try Managed.initSet(testing.allocator, 5);
    defer a.deinit();

    a.negate();
    try testing.expectEqual(-5, try a.toInt(i32));

    a.negate();
    try testing.expectEqual(5, try a.toInt(i32));
}

test "add single-single" {
    var a = try Managed.initSet(testing.allocator, 50);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.add(&a, &b);

    try testing.expectEqual(55, try c.toInt(u32));
}

test "add multi-single" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 1);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();

    try c.add(&a, &b);
    try testing.expectEqual(maxInt(Limb) + 2, try c.toInt(DoubleLimb));

    try c.add(&b, &a);
    try testing.expectEqual(maxInt(Limb) + 2, try c.toInt(DoubleLimb));
}

test "add multi-multi" {
    var op1: u128 = 0xefefefef7f7f7f7f;
    var op2: u128 = 0xfefefefe9f9f9f9f;
    // These must be runtime-known to prevent this comparison being tautological, as the
    // compiler uses `std.math.big.int` internally to add these values at comptime.
    _ = .{ &op1, &op2 };
    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.add(&a, &b);

    try testing.expectEqual(op1 + op2, try c.toInt(u128));
}

test "add zero-zero" {
    var a = try Managed.initSet(testing.allocator, 0);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.add(&a, &b);

    try testing.expectEqual(0, try c.toInt(u32));
}

test "add alias multi-limb nonzero-zero" {
    const op1 = 0xffffffff777777771;
    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0);
    defer b.deinit();

    try a.add(&a, &b);

    try testing.expectEqual(op1, try a.toInt(u128));
}

test "add sign" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    var one = try Managed.initSet(testing.allocator, 1);
    defer one.deinit();
    var two = try Managed.initSet(testing.allocator, 2);
    defer two.deinit();
    var neg_one = try Managed.initSet(testing.allocator, -1);
    defer neg_one.deinit();
    var neg_two = try Managed.initSet(testing.allocator, -2);
    defer neg_two.deinit();

    try a.add(&one, &two);
    try testing.expectEqual(3, try a.toInt(i32));

    try a.add(&neg_one, &two);
    try testing.expectEqual(1, try a.toInt(i32));

    try a.add(&one, &neg_two);
    try testing.expectEqual(-1, try a.toInt(i32));

    try a.add(&neg_one, &neg_two);
    try testing.expectEqual(-3, try a.toInt(i32));
}

test "add comptime scalar" {
    var a = try Managed.initSet(testing.allocator, 50);
    defer a.deinit();

    var b = try Managed.init(testing.allocator);
    defer b.deinit();
    try b.addScalar(&a, 5);

    try testing.expectEqual(55, try b.toInt(u32));
}

test "add scalar" {
    var a = try Managed.initSet(testing.allocator, 123);
    defer a.deinit();

    var b = try Managed.init(testing.allocator);
    defer b.deinit();
    try b.addScalar(&a, @as(u32, 31));

    try testing.expectEqual(154, try b.toInt(u32));
}

test "addWrap single-single, unsigned" {
    var a = try Managed.initSet(testing.allocator, maxInt(u17));
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, 10);
    defer b.deinit();

    const wrapped = try a.addWrap(&a, &b, .unsigned, 17);

    try testing.expect(wrapped);
    try testing.expectEqual(9, try a.toInt(u17));
}

test "subWrap single-single, unsigned" {
    var a = try Managed.initSet(testing.allocator, 0);
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, maxInt(u17));
    defer b.deinit();

    const wrapped = try a.subWrap(&a, &b, .unsigned, 17);

    try testing.expect(wrapped);
    try testing.expectEqual(1, try a.toInt(u17));
}

test "addWrap multi-multi, unsigned, limb aligned" {
    var a = try Managed.initSet(testing.allocator, maxInt(DoubleLimb));
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, maxInt(DoubleLimb));
    defer b.deinit();

    const wrapped = try a.addWrap(&a, &b, .unsigned, @bitSizeOf(DoubleLimb));

    try testing.expect(wrapped);
    try testing.expectEqual(maxInt(DoubleLimb) - 1, try a.toInt(DoubleLimb));
}

test "subWrap single-multi, unsigned, limb aligned" {
    var a = try Managed.initSet(testing.allocator, 10);
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, maxInt(DoubleLimb) + 100);
    defer b.deinit();

    const wrapped = try a.subWrap(&a, &b, .unsigned, @bitSizeOf(DoubleLimb));

    try testing.expect(wrapped);
    try testing.expectEqual(maxInt(DoubleLimb) - 88, try a.toInt(DoubleLimb));
}

test "addWrap single-single, signed" {
    var a = try Managed.initSet(testing.allocator, maxInt(i21));
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, 1 + 1 + maxInt(u21));
    defer b.deinit();

    const wrapped = try a.addWrap(&a, &b, .signed, @bitSizeOf(i21));

    try testing.expect(wrapped);
    try testing.expectEqual(minInt(i21), try a.toInt(i21));
}

test "subWrap single-single, signed" {
    var a = try Managed.initSet(testing.allocator, minInt(i21));
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, 1);
    defer b.deinit();

    const wrapped = try a.subWrap(&a, &b, .signed, @bitSizeOf(i21));

    try testing.expect(wrapped);
    try testing.expectEqual(maxInt(i21), try a.toInt(i21));
}

test "addWrap multi-multi, signed, limb aligned" {
    var a = try Managed.initSet(testing.allocator, maxInt(SignedDoubleLimb));
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, maxInt(SignedDoubleLimb));
    defer b.deinit();

    const wrapped = try a.addWrap(&a, &b, .signed, @bitSizeOf(SignedDoubleLimb));

    try testing.expect(wrapped);
    try testing.expectEqual(-2, try a.toInt(SignedDoubleLimb));
}

test "subWrap single-multi, signed, limb aligned" {
    var a = try Managed.initSet(testing.allocator, minInt(SignedDoubleLimb));
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, 1);
    defer b.deinit();

    const wrapped = try a.subWrap(&a, &b, .signed, @bitSizeOf(SignedDoubleLimb));

    try testing.expect(wrapped);
    try testing.expectEqual(maxInt(SignedDoubleLimb), try a.toInt(SignedDoubleLimb));
}

test "addWrap returns normalized result" {
    var x = try Managed.initSet(testing.allocator, 0);
    defer x.deinit();
    var y = try Managed.initSet(testing.allocator, 0);
    defer y.deinit();

    // make them both non normalized "-0"
    x.setMetadata(false, 1);
    y.setMetadata(false, 1);

    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try testing.expect(!(try r.addWrap(&x, &y, .unsigned, 64)));
    try testing.expect(r.isPositive() and r.len() == 1 and r.limbs[0] == 0);
}

test "subWrap returns normalized result" {
    var x = try Managed.initSet(testing.allocator, 0);
    defer x.deinit();
    var y = try Managed.initSet(testing.allocator, 0);
    defer y.deinit();

    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try testing.expect(!(try r.subWrap(&x, &y, .unsigned, 64)));
    try testing.expect(r.isPositive() and r.len() == 1 and r.limbs[0] == 0);
}

test "addSat single-single, unsigned" {
    var a = try Managed.initSet(testing.allocator, maxInt(u17) - 5);
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, 10);
    defer b.deinit();

    try a.addSat(&a, &b, .unsigned, 17);

    try testing.expectEqual(maxInt(u17), try a.toInt(u17));
}

test "subSat single-single, unsigned" {
    var a = try Managed.initSet(testing.allocator, 123);
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, 4000);
    defer b.deinit();

    try a.subSat(&a, &b, .unsigned, 17);

    try testing.expectEqual(0, try a.toInt(u17));
}

test "addSat multi-multi, unsigned, limb aligned" {
    var a = try Managed.initSet(testing.allocator, maxInt(DoubleLimb));
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, maxInt(DoubleLimb));
    defer b.deinit();

    try a.addSat(&a, &b, .unsigned, @bitSizeOf(DoubleLimb));

    try testing.expectEqual(maxInt(DoubleLimb), try a.toInt(DoubleLimb));
}

test "subSat single-multi, unsigned, limb aligned" {
    var a = try Managed.initSet(testing.allocator, 10);
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, maxInt(DoubleLimb) + 100);
    defer b.deinit();

    try a.subSat(&a, &b, .unsigned, @bitSizeOf(DoubleLimb));

    try testing.expectEqual(0, try a.toInt(DoubleLimb));
}

test "addSat single-single, signed" {
    var a = try Managed.initSet(testing.allocator, maxInt(i14));
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, 1);
    defer b.deinit();

    try a.addSat(&a, &b, .signed, @bitSizeOf(i14));

    try testing.expectEqual(maxInt(i14), try a.toInt(i14));
}

test "subSat single-single, signed" {
    var a = try Managed.initSet(testing.allocator, minInt(i21));
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, 1);
    defer b.deinit();

    try a.subSat(&a, &b, .signed, @bitSizeOf(i21));

    try testing.expectEqual(minInt(i21), try a.toInt(i21));
}

test "addSat multi-multi, signed, limb aligned" {
    var a = try Managed.initSet(testing.allocator, maxInt(SignedDoubleLimb));
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, maxInt(SignedDoubleLimb));
    defer b.deinit();

    try a.addSat(&a, &b, .signed, @bitSizeOf(SignedDoubleLimb));

    try testing.expectEqual(maxInt(SignedDoubleLimb), try a.toInt(SignedDoubleLimb));
}

test "subSat single-multi, signed, limb aligned" {
    var a = try Managed.initSet(testing.allocator, minInt(SignedDoubleLimb));
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, 1);
    defer b.deinit();

    try a.subSat(&a, &b, .signed, @bitSizeOf(SignedDoubleLimb));

    try testing.expectEqual(minInt(SignedDoubleLimb), try a.toInt(SignedDoubleLimb));
}

test "sub single-single" {
    var a = try Managed.initSet(testing.allocator, 50);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.sub(&a, &b);

    try testing.expectEqual(45, try c.toInt(u32));
}

test "sub multi-single" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 1);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.sub(&a, &b);

    try testing.expectEqual(maxInt(Limb), try c.toInt(Limb));
}

test "sub multi-multi" {
    var op1: u128 = 0xefefefefefefefefefefefef;
    var op2: u128 = 0xabababababababababababab;
    _ = .{ &op1, &op2 };

    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.sub(&a, &b);

    try testing.expectEqual(op1 - op2, try c.toInt(u128));
}

test "sub equal" {
    var a = try Managed.initSet(testing.allocator, 0x11efefefefefefefefefefefef);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x11efefefefefefefefefefefef);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.sub(&a, &b);

    try testing.expectEqual(0, try c.toInt(u32));
}

test "sub sign" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    var one = try Managed.initSet(testing.allocator, 1);
    defer one.deinit();
    var two = try Managed.initSet(testing.allocator, 2);
    defer two.deinit();
    var neg_one = try Managed.initSet(testing.allocator, -1);
    defer neg_one.deinit();
    var neg_two = try Managed.initSet(testing.allocator, -2);
    defer neg_two.deinit();

    try a.sub(&one, &two);
    try testing.expectEqual(-1, try a.toInt(i32));

    try a.sub(&neg_one, &two);
    try testing.expectEqual(-3, try a.toInt(i32));

    try a.sub(&one, &neg_two);
    try testing.expectEqual(3, try a.toInt(i32));

    try a.sub(&neg_one, &neg_two);
    try testing.expectEqual(1, try a.toInt(i32));

    try a.sub(&neg_two, &neg_one);
    try testing.expectEqual(-1, try a.toInt(i32));
}

test "mul single-single" {
    var a = try Managed.initSet(testing.allocator, 50);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mul(&a, &b);

    try testing.expectEqual(250, try c.toInt(u64));
}

test "mul multi-single" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 2);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mul(&a, &b);

    try testing.expectEqual(2 * maxInt(Limb), try c.toInt(DoubleLimb));
}

test "mul multi-multi" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    var op1: u256 = 0x998888efefefefefefefef;
    var op2: u256 = 0x333000abababababababab;
    _ = .{ &op1, &op2 };

    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mul(&a, &b);

    try testing.expectEqual(op1 * op2, try c.toInt(u256));
}

test "mul alias r with a" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 2);
    defer b.deinit();

    try a.mul(&a, &b);

    try testing.expectEqual(2 * maxInt(Limb), try a.toInt(DoubleLimb));
}

test "mul alias r with b" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 2);
    defer b.deinit();

    try a.mul(&b, &a);

    try testing.expectEqual(2 * maxInt(Limb), try a.toInt(DoubleLimb));
}

test "mul alias r with a and b" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();

    try a.mul(&a, &a);

    try testing.expectEqual(maxInt(Limb) * maxInt(Limb), try a.toInt(DoubleLimb));
}

test "mul a*0" {
    var a = try Managed.initSet(testing.allocator, 0xefefefefefefefef);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mul(&a, &b);

    try testing.expectEqual(0, try c.toInt(u32));
}

test "mul 0*0" {
    var a = try Managed.initSet(testing.allocator, 0);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mul(&a, &b);

    try testing.expectEqual(0, try c.toInt(u32));
}

test "mul large" {
    var a = try Managed.initCapacity(testing.allocator, 50);
    defer a.deinit();
    var b = try Managed.initCapacity(testing.allocator, 100);
    defer b.deinit();
    var c = try Managed.initCapacity(testing.allocator, 100);
    defer c.deinit();

    // Generate a number that's large enough to cross the thresholds for the use
    // of subquadratic algorithms
    for (a.limbs) |*p| {
        p.* = maxInt(Limb);
    }
    a.setMetadata(true, 50);

    try b.mul(&a, &a);
    try c.sqr(&a);

    try testing.expect(b.eql(c));
}

test "mulWrap single-single unsigned" {
    var a = try Managed.initSet(testing.allocator, 1234);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5678);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mulWrap(&a, &b, .unsigned, 17);

    try testing.expectEqual(59836, try c.toInt(u17));
}

test "mulWrap single-single signed" {
    var a = try Managed.initSet(testing.allocator, 1234);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -5678);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mulWrap(&a, &b, .signed, 17);

    try testing.expectEqual(-59836, try c.toInt(i17));
}

test "mulWrap multi-multi unsigned" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    var op1: u256 = 0x998888efefefefefefefef;
    var op2: u256 = 0x333000abababababababab;
    _ = .{ &op1, &op2 };

    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mulWrap(&a, &b, .unsigned, 65);

    try testing.expectEqual((op1 * op2) & ((1 << 65) - 1), try c.toInt(u256));
}

test "mulWrap multi-multi signed" {
    switch (builtin.zig_backend) {
        .stage2_c => return error.SkipZigTest,
        else => {},
    }

    var a = try Managed.initSet(testing.allocator, maxInt(SignedDoubleLimb) - 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, maxInt(SignedDoubleLimb));
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mulWrap(&a, &b, .signed, @bitSizeOf(SignedDoubleLimb));

    try testing.expectEqual(minInt(SignedDoubleLimb) + 2, try c.toInt(SignedDoubleLimb));
}

test "mulWrap large" {
    var a = try Managed.initCapacity(testing.allocator, 50);
    defer a.deinit();
    var b = try Managed.initCapacity(testing.allocator, 100);
    defer b.deinit();
    var c = try Managed.initCapacity(testing.allocator, 100);
    defer c.deinit();

    // Generate a number that's large enough to cross the thresholds for the use
    // of subquadratic algorithms
    for (a.limbs) |*p| {
        p.* = maxInt(Limb);
    }
    a.setMetadata(true, 50);

    const testbits = @bitSizeOf(Limb) * 64 + 45;

    try b.mulWrap(&a, &a, .signed, testbits);
    try c.sqr(&a);
    try c.truncate(&c, .signed, testbits);

    try testing.expect(b.eql(c));
}

test "div single-half no rem" {
    var a = try Managed.initSet(testing.allocator, 50);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(10, try q.toInt(u32));
    try testing.expectEqual(0, try r.toInt(u32));
}

test "div single-half with rem" {
    var a = try Managed.initSet(testing.allocator, 49);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(9, try q.toInt(u32));
    try testing.expectEqual(4, try r.toInt(u32));
}

test "div single-single no rem" {
    // assumes usize is <= 64 bits.
    var a = try Managed.initSet(testing.allocator, 1 << 52);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 1 << 35);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(131072, try q.toInt(u32));
    try testing.expectEqual(0, try r.toInt(u32));
}

test "div single-single with rem" {
    var a = try Managed.initSet(testing.allocator, (1 << 52) | (1 << 33));
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, (1 << 35));
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(131072, try q.toInt(u64));
    try testing.expectEqual(8589934592, try r.toInt(u64));
}

test "div multi-single no rem" {
    var op1: u128 = 0xffffeeeeddddcccc;
    var op2: u128 = 34;
    _ = .{ &op1, &op2 };

    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(op1 / op2, try q.toInt(u64));
    try testing.expectEqual(0, try r.toInt(u64));
}

test "div multi-single with rem" {
    var op1: u128 = 0xffffeeeeddddcccf;
    var op2: u128 = 34;
    _ = .{ &op1, &op2 };

    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(op1 / op2, try q.toInt(u64));
    try testing.expectEqual(3, try r.toInt(u64));
}

test "div multi>2-single" {
    var op1: u128 = 0xfefefefefefefefefefefefefefefefe;
    var op2: u128 = 0xefab8;
    _ = .{ &op1, &op2 };

    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(op1 / op2, try q.toInt(u128));
    try testing.expectEqual(0x3e4e, try r.toInt(u32));
}

test "div single-single q < r" {
    var a = try Managed.initSet(testing.allocator, 0x0078f432);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x01000000);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(0, try q.toInt(u64));
    try testing.expectEqual(0x0078f432, try r.toInt(u64));
}

test "div single-single q == r" {
    var a = try Managed.initSet(testing.allocator, 10);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 10);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(1, try q.toInt(u64));
    try testing.expectEqual(0, try r.toInt(u64));
}

test "div q=0 alias" {
    var a = try Managed.initSet(testing.allocator, 3);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 10);
    defer b.deinit();

    try Managed.divTrunc(&a, &b, &a, &b);

    try testing.expectEqual(0, try a.toInt(u64));
    try testing.expectEqual(3, try b.toInt(u64));
}

test "div multi-multi q < r" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const op1 = 0x1ffffffff0078f432;
    const op2 = 0x1ffffffff01000000;
    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(0, try q.toInt(u128));
    try testing.expectEqual(op1, try r.toInt(u128));
}

test "div trunc single-single +/+" {
    const u: i32 = 5;
    const v: i32 = 3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    // n = q * d + r
    // 5 = 1 * 3 + 2
    const eq = @divTrunc(u, v);
    const er = @mod(u, v);

    try testing.expectEqual(eq, try q.toInt(i32));
    try testing.expectEqual(er, try r.toInt(i32));
}

test "div trunc single-single -/+" {
    const u: i32 = -5;
    const v: i32 = 3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    //  n = q *  d + r
    // -5 = 1 * -3 - 2
    const eq = -1;
    const er = -2;

    try testing.expectEqual(eq, try q.toInt(i32));
    try testing.expectEqual(er, try r.toInt(i32));
}

test "div trunc single-single +/-" {
    const u: i32 = 5;
    const v: i32 = -3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    // n =  q *  d + r
    // 5 = -1 * -3 + 2
    const eq = -1;
    const er = 2;

    try testing.expectEqual(eq, try q.toInt(i32));
    try testing.expectEqual(er, try r.toInt(i32));
}

test "div trunc single-single -/-" {
    const u: i32 = -5;
    const v: i32 = -3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    //  n = q *  d + r
    // -5 = 1 * -3 - 2
    const eq = 1;
    const er = -2;

    try testing.expectEqual(eq, try q.toInt(i32));
    try testing.expectEqual(er, try r.toInt(i32));
}

test "divTrunc #15535" {
    var one = try Managed.initSet(testing.allocator, 1);
    defer one.deinit();
    var x = try Managed.initSet(testing.allocator, std.math.pow(u128, 2, 64));
    defer x.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    try q.divTrunc(&r, &x, &x);
    try testing.expectEqual(std.math.Order.lt, r.order(one));
}

test "divFloor #10932" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    var b = try Managed.init(testing.allocator);
    defer b.deinit();

    var res = try Managed.init(testing.allocator);
    defer res.deinit();

    try a.setString(10, "40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    try b.setString(10, "8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");

    var mod = try Managed.init(testing.allocator);
    defer mod.deinit();

    try res.divFloor(&mod, &a, &b);

    const ress = try res.toString(testing.allocator, 16, .lower);
    defer testing.allocator.free(ress);
    try testing.expectEqualStrings("194bd136316c046d070b763396297bf8869a605030216b52597015902a172b2a752f62af1568dcd431602f03725bfa62b0be71ae86616210972c0126e173503011ca48c5747ff066d159c95e46b69cbb14c8fc0bd2bf0919f921be96463200000000000000000000000000000000000000000000000000000000000000000000000000000000", ress);
    try testing.expectEqual(0, try mod.toInt(i32));
}

test "divFloor #11166" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    var b = try Managed.init(testing.allocator);
    defer b.deinit();

    var res = try Managed.init(testing.allocator);
    defer res.deinit();

    try a.setString(10, "10000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000870000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    try b.setString(10, "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");

    var mod = try Managed.init(testing.allocator);
    defer mod.deinit();

    try res.divFloor(&mod, &a, &b);

    const ress = try res.toString(testing.allocator, 10, .lower);
    defer testing.allocator.free(ress);
    try testing.expectEqualStrings("1000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", ress);

    const mods = try mod.toString(testing.allocator, 10, .lower);
    defer testing.allocator.free(mods);
    try testing.expectEqualStrings("870000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", mods);
}

test "gcd #10932" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    var b = try Managed.init(testing.allocator);
    defer b.deinit();

    var res = try Managed.init(testing.allocator);
    defer res.deinit();

    try a.setString(10, "3000000000000000000000000000000000000000000000000000000000000000000000001461501637330902918203684832716283019655932542975000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    try b.setString(10, "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200001001500000000000000000100000000040000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000003000000000000000000000000000000000000000000000000000058715661000000000000000000000000000000000000023553252000000000180000000000000000000000000000000000000000000000000250000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001005000002000000000000000000000000000000000000000021000000001000000000000000000000000100000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000200000000000000000000004000000000000000000000000000000000000000000000301000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");

    try res.gcd(&a, &b);

    const ress = try res.toString(testing.allocator, 16, .lower);
    defer testing.allocator.free(ress);
    try testing.expectEqualStrings("1a974a5c9734476ff5a3604bcc678a756beacfc21b4427d1f2c1f56f5d4e411a162c56136e20000000000000000000000000000000", ress);
}

test "bitAnd #10932" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    var b = try Managed.init(testing.allocator);
    defer b.deinit();

    var res = try Managed.init(testing.allocator);
    defer res.deinit();

    try a.setString(10, "154954885951624787839743960731760616696");
    try b.setString(10, "55000000000915215865915724129619485917228346934191537590366734850266784978214506142389798064826139649163838075568111457203909393174933092857416500785632012953993352521899237655507306575657169267399324107627651067352600878339870446048204062696260567762088867991835386857942106708741836433444432529637331429212430394179472179237695833247299409249810963487516399177133175950185719220422442438098353430605822151595560743492661038899294517012784306863064670126197566982968906306814338148792888550378533207318063660581924736840687332023636827401670268933229183389040490792300121030647791095178823932734160000000000000000000000000000000000000555555550000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");

    try res.bitAnd(&a, &b);

    try testing.expectEqual(0, try res.toInt(i32));
}

test "bit And #19235" {
    var a = try Managed.initSet(testing.allocator, -0xffffffffffffffff);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x10000000000000000);
    defer b.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();

    try r.bitAnd(&a, &b);

    try testing.expectEqual(0x10000000000000000, try r.toInt(i128));
}

test "div floor single-single +/+" {
    const u: i32 = 5;
    const v: i32 = 3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divFloor(&q, &r, &a, &b);

    //  n =  q *  d + r
    //  5 =  1 *  3 + 2
    const eq = 1;
    const er = 2;

    try testing.expectEqual(eq, try q.toInt(i32));
    try testing.expectEqual(er, try r.toInt(i32));
}

test "div floor single-single -/+" {
    const u: i32 = -5;
    const v: i32 = 3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divFloor(&q, &r, &a, &b);

    //  n =  q *  d + r
    // -5 = -2 *  3 + 1
    const eq = -2;
    const er = 1;

    try testing.expectEqual(eq, try q.toInt(i32));
    try testing.expectEqual(er, try r.toInt(i32));
}

test "div floor single-single +/-" {
    const u: i32 = 5;
    const v: i32 = -3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divFloor(&q, &r, &a, &b);

    //  n =  q *  d + r
    //  5 = -2 * -3 - 1
    const eq = -2;
    const er = -1;

    try testing.expectEqual(eq, try q.toInt(i32));
    try testing.expectEqual(er, try r.toInt(i32));
}

test "div floor single-single -/-" {
    const u: i32 = -5;
    const v: i32 = -3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divFloor(&q, &r, &a, &b);

    //  n =  q *  d + r
    // -5 =  2 * -3 + 1
    const eq = 1;
    const er = -2;

    try testing.expectEqual(eq, try q.toInt(i32));
    try testing.expectEqual(er, try r.toInt(i32));
}

test "div floor no remainder negative quotient" {
    const u: i32 = -0x80000000;
    const v: i32 = 1;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divFloor(&q, &r, &a, &b);

    try testing.expectEqual(-0x80000000, try q.toInt(i32));
    try testing.expectEqual(0, try r.toInt(i32));
}

test "div floor negative close to zero" {
    const u: i32 = -2;
    const v: i32 = 12;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divFloor(&q, &r, &a, &b);

    try testing.expectEqual(-1, try q.toInt(i32));
    try testing.expectEqual(10, try r.toInt(i32));
}

test "div floor positive close to zero" {
    const u: i32 = 10;
    const v: i32 = 12;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divFloor(&q, &r, &a, &b);

    try testing.expectEqual(0, try q.toInt(i32));
    try testing.expectEqual(10, try r.toInt(i32));
}

test "div multi-multi with rem" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    var a = try Managed.initSet(testing.allocator, 0x8888999911110000ffffeeeeddddccccbbbbaaaa9999);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x99990000111122223333);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(0xe38f38e39161aaabd03f0f1b, try q.toInt(u128));
    try testing.expectEqual(0x28de0acacd806823638, try r.toInt(u128));
}

test "div multi-multi no rem" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    var a = try Managed.initSet(testing.allocator, 0x8888999911110000ffffeeeedb4fec200ee3a4286361);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x99990000111122223333);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(0xe38f38e39161aaabd03f0f1b, try q.toInt(u128));
    try testing.expectEqual(0, try r.toInt(u128));
}

test "div multi-multi (2 branch)" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    var a = try Managed.initSet(testing.allocator, 0x866666665555555588888887777777761111111111111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x86666666555555554444444433333333);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(0x10000000000000000, try q.toInt(u128));
    try testing.expectEqual(0x44444443444444431111111111111111, try r.toInt(u128));
}

test "div multi-multi (3.1/3.3 branch)" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    var a = try Managed.initSet(testing.allocator, 0x11111111111111111111111111111111111111111111111111111111111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x1111111111111111111111111111111111111111171);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(0xfffffffffffffffffff, try q.toInt(u128));
    try testing.expectEqual(0x1111111111111111111110b12222222222222222282, try r.toInt(u256));
}

test "div multi-single zero-limb trailing" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    var a = try Managed.initSet(testing.allocator, 0x60000000000000000000000000000000000000000000000000000000000000000);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x10000000000000000);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    var expected = try Managed.initSet(testing.allocator, 0x6000000000000000000000000000000000000000000000000);
    defer expected.deinit();
    try testing.expect(q.eql(expected));
    try testing.expect(r.eqlZero());
}

test "div multi-multi zero-limb trailing (with rem)" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    var a = try Managed.initSet(testing.allocator, 0x86666666555555558888888777777776111111111111111100000000000000000000000000000000);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x8666666655555555444444443333333300000000000000000000000000000000);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(0x10000000000000000, try q.toInt(u128));

    const rs = try r.toString(testing.allocator, 16, .lower);
    defer testing.allocator.free(rs);
    try testing.expectEqualStrings("4444444344444443111111111111111100000000000000000000000000000000", rs);
}

test "div multi-multi zero-limb trailing (with rem) and dividend zero-limb count > divisor zero-limb count" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    var a = try Managed.initSet(testing.allocator, 0x8666666655555555888888877777777611111111111111110000000000000000);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x8666666655555555444444443333333300000000000000000000000000000000);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    try testing.expectEqual(0x1, try q.toInt(u128));

    const rs = try r.toString(testing.allocator, 16, .lower);
    defer testing.allocator.free(rs);
    try testing.expectEqualStrings("444444434444444311111111111111110000000000000000", rs);
}

test "div multi-multi zero-limb trailing (with rem) and dividend zero-limb count < divisor zero-limb count" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    var a = try Managed.initSet(testing.allocator, 0x86666666555555558888888777777776111111111111111100000000000000000000000000000000);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x866666665555555544444444333333330000000000000000);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    const qs = try q.toString(testing.allocator, 16, .lower);
    defer testing.allocator.free(qs);
    try testing.expectEqualStrings("10000000000000000820820803105186f", qs);

    const rs = try r.toString(testing.allocator, 16, .lower);
    defer testing.allocator.free(rs);
    try testing.expectEqualStrings("4e11f2baa5896a321d463b543d0104e30000000000000000", rs);
}

test "div multi-multi fuzz case #1" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();
    var b = try Managed.init(testing.allocator);
    defer b.deinit();

    try a.setString(16, "ffffffffffffffffffffffffffffc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    try b.setString(16, "3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0000000000000000000000000000000000001ffffffffffffffffffffffffffffffffffffffffffffffffffc000000000000000000000000000000007fffffffffff");

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    const qs = try q.toString(testing.allocator, 16, .lower);
    defer testing.allocator.free(qs);
    try testing.expectEqualStrings("3ffffffffffffffffffffffffffff0000000000000000000000000000000000001ffffffffffffffffffffffffffff7fffffffe000000000000000000000000000180000000000000000000003fffffbfffffffdfffffffffffffeffff800000100101000000100000000020003fffffdfbfffffe3ffffffffffffeffff7fffc00800a100000017ffe000002000400007efbfff7fe9f00000037ffff3fff7fffa004006100000009ffe00000190038200bf7d2ff7fefe80400060000f7d7f8fbf9401fe38e0403ffc0bdffffa51102c300d7be5ef9df4e5060007b0127ad3fa69f97d0f820b6605ff617ddf7f32ad7a05c0d03f2e7bc78a6000e087a8bbcdc59e07a5a079128a7861f553ddebed7e8e56701756f9ead39b48cd1b0831889ea6ec1fddf643d0565b075ff07e6caea4e2854ec9227fd635ed60a2f5eef2893052ffd54718fa08604acbf6a15e78a467c4a3c53c0278af06c4416573f925491b195e8fd79302cb1aaf7caf4ecfc9aec1254cc969786363ac729f914c6ddcc26738d6b0facd54eba026580aba2eb6482a088b0d224a8852420b91ec1", qs);

    const rs = try r.toString(testing.allocator, 16, .lower);
    defer testing.allocator.free(rs);
    try testing.expectEqualStrings("310d1d4c414426b4836c2635bad1df3a424e50cbdd167ffccb4dfff57d36b4aae0d6ca0910698220171a0f3373c1060a046c2812f0027e321f72979daa5e7973214170d49e885de0c0ecc167837d44502430674a82522e5df6a0759548052420b91ec1", rs);
}

test "div multi-multi fuzz case #2" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();
    var b = try Managed.init(testing.allocator);
    defer b.deinit();

    try a.setString(16, "3ffffffffe00000000000000000000000000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffe000000000000000000000000000000000000000000000000000000000000001fffffffffffffffff800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffc000000000000000000000000000000000000000000000000000000000000000");
    try b.setString(16, "ffc0000000000000000000000000000000000000000000000000");

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, &a, &b);

    const qs = try q.toString(testing.allocator, 16, .lower);
    defer testing.allocator.free(qs);
    try testing.expectEqualStrings("40100400fe3f8fe3f8fe3f8fe3f8fe3f8fe4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f91e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4992649926499264991e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4792e4b92e4b92e4b92e4b92a4a92a4a92a4", qs);

    const rs = try r.toString(testing.allocator, 16, .lower);
    defer testing.allocator.free(rs);
    try testing.expectEqualStrings("a900000000000000000000000000000000000000000000000000", rs);
}

test "truncate single unsigned" {
    var a = try Managed.initSet(testing.allocator, maxInt(u47));
    defer a.deinit();

    try a.truncate(&a, .unsigned, 17);

    try testing.expectEqual(maxInt(u17), try a.toInt(u17));
}

test "truncate single signed" {
    var a = try Managed.initSet(testing.allocator, 0x1_0000);
    defer a.deinit();

    try a.truncate(&a, .signed, 17);

    try testing.expectEqual(minInt(i17), try a.toInt(i17));
}

test "truncate multi to single unsigned" {
    var a = try Managed.initSet(testing.allocator, (maxInt(Limb) + 1) | 0x1234_5678_9ABC_DEF0);
    defer a.deinit();

    try a.truncate(&a, .unsigned, 27);

    try testing.expectEqual(0x2BC_DEF0, try a.toInt(u27));
}

test "truncate multi to single signed" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) << 10);
    defer a.deinit();

    try a.truncate(&a, .signed, @bitSizeOf(i11));

    try testing.expectEqual(minInt(i11), try a.toInt(i11));
}

test "truncate multi to multi unsigned" {
    const bits = @typeInfo(SignedDoubleLimb).int.bits;
    const Int = std.meta.Int(.unsigned, bits - 1);

    var a = try Managed.initSet(testing.allocator, maxInt(SignedDoubleLimb));
    defer a.deinit();

    try a.truncate(&a, .unsigned, bits - 1);

    try testing.expectEqual(maxInt(Int), try a.toInt(Int));
}

test "truncate multi to multi signed" {
    var a = try Managed.initSet(testing.allocator, 3 << @bitSizeOf(Limb));
    defer a.deinit();

    try a.truncate(&a, .signed, @bitSizeOf(Limb) + 1);

    try testing.expectEqual(-1 << @bitSizeOf(Limb), try a.toInt(std.meta.Int(.signed, @bitSizeOf(Limb) + 1)));
}

test "truncate negative multi to single" {
    var a = try Managed.initSet(testing.allocator, -@as(SignedDoubleLimb, maxInt(Limb) + 1));
    defer a.deinit();

    try a.truncate(&a, .signed, @bitSizeOf(i17));

    try testing.expectEqual(0, try a.toInt(i17));
}

test "truncate multi unsigned many" {
    var a = try Managed.initSet(testing.allocator, 1);
    defer a.deinit();
    try a.shiftLeft(&a, 1023);

    var b = try Managed.init(testing.allocator);
    defer b.deinit();
    try b.truncate(&a, .signed, @bitSizeOf(i1));

    try testing.expectEqual(0, try b.toInt(i1));
}

test "truncate to mutable with fewer limbs" {
    var res_limbs: [1]Limb = undefined;
    var res: Mutable = .{
        .limbs = &res_limbs,
        .len = undefined,
        .positive = undefined,
    };
    res.truncate(.{ .positive = true, .limbs = &.{ 0, 1 } }, .unsigned, @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
    res.truncate(.{ .positive = true, .limbs = &.{ 0, 1 } }, .signed, @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
    res.truncate(.{ .positive = false, .limbs = &.{ 0, 1 } }, .unsigned, @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
    res.truncate(.{ .positive = false, .limbs = &.{ 0, 1 } }, .signed, @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
    res.truncate(.{ .positive = true, .limbs = &.{ maxInt(Limb), 1 } }, .unsigned, @bitSizeOf(Limb));
    try testing.expect(res.toConst().orderAgainstScalar(maxInt(Limb)).compare(.eq));
    res.truncate(.{ .positive = true, .limbs = &.{ maxInt(Limb), 1 } }, .signed, @bitSizeOf(Limb));
    try testing.expect(res.toConst().orderAgainstScalar(-1).compare(.eq));
    res.truncate(.{ .positive = false, .limbs = &.{ maxInt(Limb), 1 } }, .unsigned, @bitSizeOf(Limb));
    try testing.expect(res.toConst().orderAgainstScalar(1).compare(.eq));
    res.truncate(.{ .positive = false, .limbs = &.{ maxInt(Limb), 1 } }, .signed, @bitSizeOf(Limb));
    try testing.expect(res.toConst().orderAgainstScalar(1).compare(.eq));
}

test "truncate value that normalizes after being masked" {
    var res_limbs: [2]Limb = undefined;
    var res: Mutable = .{
        .limbs = &res_limbs,
        .len = undefined,
        .positive = undefined,
    };
    res.truncate(.{ .positive = true, .limbs = &.{ 0, 2 } }, .signed, 1 + @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
    res.truncate(.{ .positive = true, .limbs = &.{ 1, 2 } }, .signed, 1 + @bitSizeOf(Limb));
    try testing.expect(res.toConst().orderAgainstScalar(1).compare(.eq));
}

test "truncate to zero" {
    var res_limbs: [1]Limb = undefined;
    var res: Mutable = .{
        .limbs = &res_limbs,
        .len = undefined,
        .positive = undefined,
    };
    res.truncate(.{ .positive = true, .limbs = &.{0} }, .signed, @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
    res.truncate(.{ .positive = false, .limbs = &.{0} }, .signed, @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
    res.truncate(.{ .positive = true, .limbs = &.{0} }, .unsigned, @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
    res.truncate(.{ .positive = false, .limbs = &.{0} }, .unsigned, @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
    res.truncate(.{ .positive = true, .limbs = &.{ 0, 1 } }, .signed, @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
    res.truncate(.{ .positive = false, .limbs = &.{ 0, 1 } }, .signed, @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
    res.truncate(.{ .positive = true, .limbs = &.{ 0, 1 } }, .unsigned, @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
    res.truncate(.{ .positive = false, .limbs = &.{ 0, 1 } }, .unsigned, @bitSizeOf(Limb));
    try testing.expect(res.positive and res.len == 1 and res.limbs[0] == 0);
}

test "truncate to minimum signed integer" {
    var res_limbs: [1]Limb = undefined;
    var res: Mutable = .{
        .limbs = &res_limbs,
        .len = undefined,
        .positive = undefined,
    };
    res.truncate(.{ .positive = true, .limbs = &.{1 << @bitSizeOf(Limb) - 1} }, .signed, @bitSizeOf(Limb));
    try testing.expect(res.toConst().orderAgainstScalar(-1 << @bitSizeOf(Limb) - 1).compare(.eq));
    res.truncate(.{ .positive = false, .limbs = &.{1 << @bitSizeOf(Limb) - 1} }, .signed, @bitSizeOf(Limb));
    try testing.expect(res.toConst().orderAgainstScalar(-1 << @bitSizeOf(Limb) - 1).compare(.eq));
    res.truncate(.{ .positive = true, .limbs = &.{1 << @bitSizeOf(Limb) - 1} }, .unsigned, @bitSizeOf(Limb));
    try testing.expect(res.toConst().orderAgainstScalar(1 << @bitSizeOf(Limb) - 1).compare(.eq));
    res.truncate(.{ .positive = false, .limbs = &.{1 << @bitSizeOf(Limb) - 1} }, .unsigned, @bitSizeOf(Limb));
    try testing.expect(res.toConst().orderAgainstScalar(1 << @bitSizeOf(Limb) - 1).compare(.eq));
}

test "saturate single signed positive" {
    var a = try Managed.initSet(testing.allocator, 0xBBBB_BBBB);
    defer a.deinit();

    try a.saturate(&a, .signed, 17);

    try testing.expectEqual(maxInt(i17), try a.toInt(i17));
}

test "saturate single signed negative" {
    var a = try Managed.initSet(testing.allocator, -1_234_567);
    defer a.deinit();

    try a.saturate(&a, .signed, 17);

    try testing.expectEqual(minInt(i17), try a.toInt(i17));
}

test "saturate single signed" {
    var a = try Managed.initSet(testing.allocator, maxInt(i17) - 1);
    defer a.deinit();

    try a.saturate(&a, .signed, 17);

    try testing.expectEqual(maxInt(i17) - 1, try a.toInt(i17));
}

test "saturate multi signed" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) << @bitSizeOf(SignedDoubleLimb));
    defer a.deinit();

    try a.saturate(&a, .signed, @bitSizeOf(SignedDoubleLimb));

    try testing.expectEqual(maxInt(SignedDoubleLimb), try a.toInt(SignedDoubleLimb));
}

test "saturate single unsigned" {
    var a = try Managed.initSet(testing.allocator, 0xFEFE_FEFE);
    defer a.deinit();

    try a.saturate(&a, .unsigned, 23);

    try testing.expectEqual(maxInt(u23), try a.toInt(u23));
}

test "saturate multi unsigned zero" {
    var a = try Managed.initSet(testing.allocator, -1);
    defer a.deinit();

    try a.saturate(&a, .unsigned, @bitSizeOf(DoubleLimb));

    try testing.expect(a.eqlZero());
}

test "saturate multi unsigned" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) << @bitSizeOf(DoubleLimb));
    defer a.deinit();

    try a.saturate(&a, .unsigned, @bitSizeOf(DoubleLimb));

    try testing.expectEqual(maxInt(DoubleLimb), try a.toInt(DoubleLimb));
}

test "shift-right single" {
    var a = try Managed.initSet(testing.allocator, 0xffff0000);
    defer a.deinit();
    try a.shiftRight(&a, 16);

    try testing.expectEqual(0xffff, try a.toInt(u32));
}

test "shift-right multi" {
    var a = try Managed.initSet(testing.allocator, 0xffff0000eeee1111dddd2222cccc3333);
    defer a.deinit();
    try a.shiftRight(&a, 67);

    try testing.expectEqual(0x1fffe0001dddc222, try a.toInt(u64));

    try a.set(0xffff0000eeee1111dddd2222cccc3333);
    try a.shiftRight(&a, 63);
    try a.shiftRight(&a, 63);
    try a.shiftRight(&a, 2);
    try testing.expect(a.eqlZero());

    try a.set(0xffff0000eeee1111dddd2222cccc3333000000000000000000000);
    try a.shiftRight(&a, 84);
    const string = try a.toString(
        testing.allocator,
        16,
        .lower,
    );
    defer testing.allocator.free(string);
    try std.testing.expectEqualStrings(
        "ffff0000eeee1111dddd2222cccc3333",
        string,
    );
}

test "shift-left single" {
    var a = try Managed.initSet(testing.allocator, 0xffff);
    defer a.deinit();
    try a.shiftLeft(&a, 16);

    try testing.expectEqual(0xffff0000, try a.toInt(u64));
}

test "shift-left multi" {
    var a = try Managed.initSet(testing.allocator, 0x1fffe0001dddc222);
    defer a.deinit();
    try a.shiftLeft(&a, 67);

    try testing.expectEqual(0xffff0000eeee11100000000000000000, try a.toInt(u128));
}

test "shift-right negative" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    var arg = try Managed.initSet(testing.allocator, -20);
    defer arg.deinit();
    try a.shiftRight(&arg, 2);
    try testing.expectEqual(-5, try a.toInt(i32)); // -20 >> 2 == -5

    var arg2 = try Managed.initSet(testing.allocator, -5);
    defer arg2.deinit();
    try a.shiftRight(&arg2, 10);
    try testing.expectEqual(-1, try a.toInt(i32)); // -5 >> 10 == -1

    var arg3 = try Managed.initSet(testing.allocator, -10);
    defer arg3.deinit();
    try a.shiftRight(&arg3, 1232);
    try testing.expectEqual(-1, try a.toInt(i32)); // -10 >> 1232 == -1

    var arg4 = try Managed.initSet(testing.allocator, -5);
    defer arg4.deinit();
    try a.shiftRight(&arg4, 2);
    try testing.expectEqual(-2, try a.toInt(i32)); // -5 >> 2 == -2

    var arg5 = try Managed.initSet(testing.allocator, -0xffff0000eeee1111dddd2222cccc3333);
    defer arg5.deinit();
    try a.shiftRight(&arg5, 67);
    try testing.expectEqual(-0x1fffe0001dddc223, try a.toInt(i64));

    var arg6 = try Managed.initSet(testing.allocator, -0x1ffffffffffffffff);
    defer arg6.deinit();
    try a.shiftRight(&arg6, 1);
    try a.shiftRight(&a, 1);
    a.setSign(true);
    try testing.expectEqual(0x8000000000000000, try a.toInt(u64));

    var arg7 = try Managed.initSet(testing.allocator, -32767);
    defer arg7.deinit();
    a.setSign(false);
    try a.shiftRight(&arg7, 4);
    try testing.expectEqual(-2048, try a.toInt(i16));
    a.setSign(true);
    try a.shiftRight(&arg7, 4);
    try testing.expectEqual(-2048, try a.toInt(i16));

    var arg8_limbs: [1]Limb = undefined;
    var arg8: Mutable = .{
        .limbs = &arg8_limbs,
        .len = undefined,
        .positive = undefined,
    };
    arg8.shiftRight(.{ .limbs = &.{ 1, 1 }, .positive = false }, @bitSizeOf(Limb));
    try testing.expect(arg8.toConst().orderAgainstScalar(-2).compare(.eq));
}

test "sat shift-left simple unsigned" {
    var a = try Managed.initSet(testing.allocator, 0xffff);
    defer a.deinit();
    try a.shiftLeftSat(&a, 16, .unsigned, 21);

    try testing.expectEqual(0x1fffff, try a.toInt(u64));
}

test "sat shift-left simple unsigned no sat" {
    var a = try Managed.initSet(testing.allocator, 1);
    defer a.deinit();
    try a.shiftLeftSat(&a, 16, .unsigned, 21);

    try testing.expectEqual(0x10000, try a.toInt(u64));
}

test "sat shift-left multi unsigned" {
    var a = try Managed.initSet(testing.allocator, 16);
    defer a.deinit();
    try a.shiftLeftSat(&a, @bitSizeOf(DoubleLimb) - 3, .unsigned, @bitSizeOf(DoubleLimb) - 1);

    try testing.expectEqual(maxInt(DoubleLimb) >> 1, try a.toInt(DoubleLimb));
}

test "sat shift-left unsigned shift > bitcount" {
    var a = try Managed.initSet(testing.allocator, 1);
    defer a.deinit();
    try a.shiftLeftSat(&a, 10, .unsigned, 10);

    try testing.expectEqual(maxInt(u10), try a.toInt(u10));
}

test "sat shift-left unsigned zero" {
    var a = try Managed.initSet(testing.allocator, 0);
    defer a.deinit();
    try a.shiftLeftSat(&a, 1, .unsigned, 0);

    try testing.expectEqual(0, try a.toInt(u64));
}

test "sat shift-left unsigned negative" {
    var a = try Managed.initSet(testing.allocator, -100);
    defer a.deinit();
    try a.shiftLeftSat(&a, 0, .unsigned, 0);

    try testing.expectEqual(0, try a.toInt(u64));
}

test "sat shift-left signed simple negative" {
    var a = try Managed.initSet(testing.allocator, -100);
    defer a.deinit();
    try a.shiftLeftSat(&a, 3, .signed, 10);

    try testing.expectEqual(minInt(i10), try a.toInt(i10));
}

test "sat shift-left signed simple positive" {
    var a = try Managed.initSet(testing.allocator, 100);
    defer a.deinit();
    try a.shiftLeftSat(&a, 3, .signed, 10);

    try testing.expectEqual(maxInt(i10), try a.toInt(i10));
}

test "sat shift-left signed multi positive" {
    var x: SignedDoubleLimb = 1;
    _ = &x;

    const shift = @bitSizeOf(SignedDoubleLimb) - 1;

    var a = try Managed.initSet(testing.allocator, x);
    defer a.deinit();
    try a.shiftLeftSat(&a, shift, .signed, @bitSizeOf(SignedDoubleLimb));

    try testing.expectEqual(x <<| shift, try a.toInt(SignedDoubleLimb));
}

test "sat shift-left signed multi negative" {
    var x: SignedDoubleLimb = -1;
    _ = &x;

    const shift = @bitSizeOf(SignedDoubleLimb) - 1;

    var a = try Managed.initSet(testing.allocator, x);
    defer a.deinit();
    try a.shiftLeftSat(&a, shift, .signed, @bitSizeOf(SignedDoubleLimb));

    try testing.expectEqual(x <<| shift, try a.toInt(SignedDoubleLimb));
}

test "bitNotWrap unsigned simple" {
    var x: u10 = 123;
    _ = &x;

    var a = try Managed.initSet(testing.allocator, x);
    defer a.deinit();

    try a.bitNotWrap(&a, .unsigned, 10);

    try testing.expectEqual(~x, try a.toInt(u10));
}

test "bitNotWrap unsigned multi" {
    var a = try Managed.initSet(testing.allocator, 0);
    defer a.deinit();

    try a.bitNotWrap(&a, .unsigned, @bitSizeOf(DoubleLimb));

    try testing.expectEqual(maxInt(DoubleLimb), try a.toInt(DoubleLimb));
}

test "bitNotWrap signed simple" {
    var x: i11 = -456;
    _ = &x;

    var a = try Managed.initSet(testing.allocator, -456);
    defer a.deinit();

    try a.bitNotWrap(&a, .signed, 11);

    try testing.expectEqual(~x, try a.toInt(i11));
}

test "bitNotWrap signed multi" {
    var a = try Managed.initSet(testing.allocator, 0);
    defer a.deinit();

    try a.bitNotWrap(&a, .signed, @bitSizeOf(SignedDoubleLimb));

    try testing.expectEqual(-1, try a.toInt(SignedDoubleLimb));
}

test "bitNotWrap more than two limbs" {
    // This test requires int sizes greater than 128 bits.
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    // LLVM: unexpected runtime library name: __umodei4
    if (builtin.zig_backend == .stage2_llvm and comptime builtin.target.cpu.arch.isWasm()) return error.SkipZigTest; // TODO

    var a = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();

    var res = try Managed.init(testing.allocator);
    defer res.deinit();

    const bits = @bitSizeOf(Limb) * 4 + 2;

    try res.bitNotWrap(&a, .unsigned, bits);
    const Unsigned = @Type(.{ .int = .{ .signedness = .unsigned, .bits = bits } });
    try testing.expectEqual((try res.toInt(Unsigned)), ~@as(Unsigned, maxInt(Limb)));

    try res.bitNotWrap(&a, .signed, bits);
    const Signed = @Type(.{ .int = .{ .signedness = .signed, .bits = bits } });
    try testing.expectEqual((try res.toInt(Signed)), ~@as(Signed, maxInt(Limb)));
}

test "bitwise and simple" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff11111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitAnd(&a, &b);

    try testing.expectEqual(0xeeeeeeee00000000, try a.toInt(u64));
}

test "bitwise and multi-limb" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer b.deinit();

    try a.bitAnd(&a, &b);

    try testing.expectEqual(0, try a.toInt(u128));
}

test "bitwise and negative-positive simple" {
    var a = try Managed.initSet(testing.allocator, -0xffffffff11111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitAnd(&a, &b);

    try testing.expectEqual(0x22222222, try a.toInt(u64));
}

test "bitwise and negative-positive multi-limb" {
    var a = try Managed.initSet(testing.allocator, -maxInt(Limb) - 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer b.deinit();

    try a.bitAnd(&a, &b);

    try testing.expect(a.eqlZero());
}

test "bitwise and positive-negative simple" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff11111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitAnd(&a, &b);

    try testing.expectEqual(0x1111111111111110, try a.toInt(u64));
}

test "bitwise and positive-negative multi-limb" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -maxInt(Limb) - 1);
    defer b.deinit();

    try a.bitAnd(&a, &b);

    try testing.expect(a.eqlZero());
}

test "bitwise and negative-negative simple" {
    var a = try Managed.initSet(testing.allocator, -0xffffffff11111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitAnd(&a, &b);

    try testing.expectEqual(-0xffffffff33333332, try a.toInt(i128));
}

test "bitwise and negative-negative multi-limb" {
    var a = try Managed.initSet(testing.allocator, -maxInt(Limb) - 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -maxInt(Limb) - 2);
    defer b.deinit();

    try a.bitAnd(&a, &b);

    try testing.expectEqual(-maxInt(Limb) * 2 - 2, try a.toInt(i128));
}

test "bitwise and negative overflow" {
    var a = try Managed.initSet(testing.allocator, -maxInt(Limb));
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -2);
    defer b.deinit();

    try a.bitAnd(&a, &b);

    try testing.expectEqual(-maxInt(Limb) - 1, try a.toInt(SignedDoubleLimb));
}

test "bitwise xor simple" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff11111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitXor(&a, &b);

    try testing.expectEqual(0x1111111133333333, try a.toInt(u64));
}

test "bitwise xor multi-limb" {
    var x: DoubleLimb = maxInt(Limb) + 1;
    var y: DoubleLimb = maxInt(Limb);
    _ = .{ &x, &y };

    var a = try Managed.initSet(testing.allocator, x);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, y);
    defer b.deinit();

    try a.bitXor(&a, &b);

    try testing.expectEqual(x ^ y, try a.toInt(DoubleLimb));
}

test "bitwise xor single negative simple" {
    var a = try Managed.initSet(testing.allocator, 0x6b03e381328a3154);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -0x45fd3acef9191fad);
    defer b.deinit();

    try a.bitXor(&a, &b);

    try testing.expectEqual(-0x2efed94fcb932ef9, try a.toInt(i64));
}

test "bitwise xor single negative multi-limb" {
    var a = try Managed.initSet(testing.allocator, -0x9849c6e7a10d66d0e4260d4846254c32);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xf2194e7d1c855272a997fcde16f6d5a8);
    defer b.deinit();

    try a.bitXor(&a, &b);

    try testing.expectEqual(-0x6a50889abd8834a24db1f19650d3999a, try a.toInt(i128));
}

test "bitwise xor single negative overflow" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -1);
    defer b.deinit();

    try a.bitXor(&a, &b);

    try testing.expectEqual(-(maxInt(Limb) + 1), try a.toInt(SignedDoubleLimb));
}

test "bitwise xor double negative simple" {
    var a = try Managed.initSet(testing.allocator, -0x8e48bd5f755ef1f3);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -0x4dd4fa576f3046ac);
    defer b.deinit();

    try a.bitXor(&a, &b);

    try testing.expectEqual(0xc39c47081a6eb759, try a.toInt(u64));
}

test "bitwise xor double negative multi-limb" {
    var a = try Managed.initSet(testing.allocator, -0x684e5da8f500ec8ca7204c33ccc51c9c);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -0xcb07736a7b62289c78d967c3985eebeb);
    defer b.deinit();

    try a.bitXor(&a, &b);

    try testing.expectEqual(0xa3492ec28e62c410dff92bf0549bf771, try a.toInt(u128));
}

test "bitwise or simple" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff11111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitOr(&a, &b);

    try testing.expectEqual(0xffffffff33333333, try a.toInt(u64));
}

test "bitwise or multi-limb" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer b.deinit();

    try a.bitOr(&a, &b);

    try testing.expectEqual((maxInt(Limb) + 1) + maxInt(Limb), try a.toInt(DoubleLimb));
}

test "bitwise or negative-positive simple" {
    var a = try Managed.initSet(testing.allocator, -0xffffffff11111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitOr(&a, &b);

    try testing.expectEqual(-0x1111111111111111, try a.toInt(i64));
}

test "bitwise or negative-positive multi-limb" {
    var a = try Managed.initSet(testing.allocator, -maxInt(Limb) - 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 1);
    defer b.deinit();

    try a.bitOr(&a, &b);

    try testing.expectEqual(-maxInt(Limb), try a.toInt(SignedDoubleLimb));
}

test "bitwise or positive-negative simple" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff11111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitOr(&a, &b);

    try testing.expectEqual(-0x22222221, try a.toInt(i64));
}

test "bitwise or positive-negative multi-limb" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -1);
    defer b.deinit();

    try a.bitOr(&a, &b);

    try testing.expectEqual(-1, try a.toInt(SignedDoubleLimb));
}

test "bitwise or negative-negative simple" {
    var a = try Managed.initSet(testing.allocator, -0xffffffff11111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitOr(&a, &b);

    try testing.expectEqual(-0xeeeeeeee00000001, try a.toInt(i128));
}

test "bitwise or negative-negative multi-limb" {
    var a = try Managed.initSet(testing.allocator, -maxInt(Limb) - 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -maxInt(Limb));
    defer b.deinit();

    try a.bitOr(&a, &b);

    try testing.expectEqual(-maxInt(Limb), try a.toInt(SignedDoubleLimb));
}

test "var args" {
    var a = try Managed.initSet(testing.allocator, 5);
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, 6);
    defer b.deinit();
    try a.add(&a, &b);
    try testing.expectEqual(11, try a.toInt(u64));

    var c = try Managed.initSet(testing.allocator, 11);
    defer c.deinit();
    try testing.expectEqual(.eq, a.order(c));

    var d = try Managed.initSet(testing.allocator, 14);
    defer d.deinit();
    try testing.expect(a.order(d) != .gt);
}

test "gcd non-one small" {
    var a = try Managed.initSet(testing.allocator, 17);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 97);
    defer b.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();

    try r.gcd(&a, &b);

    try testing.expectEqual(1, try r.toInt(u32));
}

test "gcd non-one medium" {
    var a = try Managed.initSet(testing.allocator, 4864);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 3458);
    defer b.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();

    try r.gcd(&a, &b);

    try testing.expectEqual(38, try r.toInt(u32));
}

test "gcd non-one large" {
    var a = try Managed.initSet(testing.allocator, 0xffffffffffffffff);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xffffffffffffffff7777);
    defer b.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();

    try r.gcd(&a, &b);

    try testing.expectEqual(4369, try r.toInt(u32));
}

test "gcd large multi-limb result" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    var a = try Managed.initSet(testing.allocator, 0x12345678123456781234567812345678123456781234567812345678);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x12345671234567123456712345671234567123456712345671234567);
    defer b.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();

    try r.gcd(&a, &b);

    const answer = (try r.toInt(u256));
    try testing.expectEqual(0xf000000ff00000fff0000ffff000fffff00ffffff1, answer);
}

test "gcd one large" {
    var a = try Managed.initSet(testing.allocator, 1897056385327307);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 2251799813685248);
    defer b.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();

    try r.gcd(&a, &b);

    try testing.expectEqual(1, try r.toInt(u64));
}

test "mutable to managed" {
    const allocator = testing.allocator;
    const limbs_buf = try allocator.alloc(Limb, 8);
    defer allocator.free(limbs_buf);

    var a = Mutable.init(limbs_buf, 0xdeadbeef);
    var a_managed = a.toManaged(allocator);

    try testing.expect(a.toConst().eql(a_managed.toConst()));
}

test "const to managed" {
    var a = try Managed.initSet(testing.allocator, 123423453456);
    defer a.deinit();

    var b = try a.toConst().toManaged(testing.allocator);
    defer b.deinit();

    try testing.expect(a.toConst().eql(b.toConst()));
}

test "pow" {
    {
        var a = try Managed.initSet(testing.allocator, -3);
        defer a.deinit();

        try a.pow(&a, 3);
        try testing.expectEqual(@as(i32, -27), try a.toInt(i32));

        try a.pow(&a, 4);
        try testing.expectEqual(@as(i32, 531441), try a.toInt(i32));
    }
    {
        var a = try Managed.initSet(testing.allocator, 10);
        defer a.deinit();

        var y = try Managed.init(testing.allocator);
        defer y.deinit();

        // y and a are not aliased
        try y.pow(&a, 123);
        // y and a are aliased
        try a.pow(&a, 123);

        try testing.expect(a.eql(y));

        const ys = try y.toString(testing.allocator, 16, .lower);
        defer testing.allocator.free(ys);
        try testing.expectEqualSlices(
            u8,
            "183425a5f872f126e00a5ad62c839075cd6846c6fb0230887c7ad7a9dc530fcb" ++
                "4933f60e8000000000000000000000000000000",
            ys,
        );
    }
    // Special cases
    {
        var a = try Managed.initSet(testing.allocator, 0);
        defer a.deinit();

        try a.pow(&a, 100);
        try testing.expectEqual(@as(i32, 0), try a.toInt(i32));

        try a.set(1);
        try a.pow(&a, 0);
        try testing.expectEqual(@as(i32, 1), try a.toInt(i32));
        try a.pow(&a, 100);
        try testing.expectEqual(@as(i32, 1), try a.toInt(i32));
        try a.set(-1);
        try a.pow(&a, 15);
        try testing.expectEqual(@as(i32, -1), try a.toInt(i32));
        try a.pow(&a, 16);
        try testing.expectEqual(@as(i32, 1), try a.toInt(i32));
    }
}

test "sqrt" {
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    // not aliased
    try r.set(0);
    try a.set(25);
    try r.sqrt(&a);
    try testing.expectEqual(@as(i32, 5), try r.toInt(i32));

    // aliased
    try a.set(25);
    try a.sqrt(&a);
    try testing.expectEqual(@as(i32, 5), try a.toInt(i32));

    // bottom
    try r.set(0);
    try a.set(24);
    try r.sqrt(&a);
    try testing.expectEqual(@as(i32, 4), try r.toInt(i32));

    // large number
    try r.set(0);
    try a.set(0x1_0000_0000_0000);
    try r.sqrt(&a);
    try testing.expectEqual(@as(i32, 0x100_0000), try r.toInt(i32));
}

test "regression test for 1 limb overflow with alias" {
    // Note these happen to be two consecutive Fibonacci sequence numbers, the
    // first two whose sum exceeds 2**64.
    var a = try Managed.initSet(testing.allocator, 7540113804746346429);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 12200160415121876738);
    defer b.deinit();

    try a.ensureAddCapacity(a.toConst(), b.toConst());
    try a.add(&a, &b);

    try testing.expectEqual(.eq, a.toConst().orderAgainstScalar(19740274219868223167));
}

test "regression test for realloc with alias" {
    // Note these happen to be two consecutive Fibonacci sequence numbers, the
    // second of which is the first such number to exceed 2**192.
    var a = try Managed.initSet(testing.allocator, 5611500259351924431073312796924978741056961814867751431689);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 9079598147510263717870894449029933369491131786514446266146);
    defer b.deinit();

    try a.ensureAddCapacity(a.toConst(), b.toConst());
    try a.add(&a, &b);

    try testing.expectEqual(.eq, a.toConst().orderAgainstScalar(14691098406862188148944207245954912110548093601382197697835));
}

test "big int popcount" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.set(0);
    try popCountTest(&a, 0, 0);
    try popCountTest(&a, 567, 0);

    try a.set(1);
    try popCountTest(&a, 1, 1);
    try popCountTest(&a, 13, 1);
    try popCountTest(&a, 432, 1);

    try a.set(255);
    try popCountTest(&a, 8, 8);
    try a.set(-128);
    try popCountTest(&a, 8, 1);

    try a.set(-2);
    try popCountTest(&a, 16, 15);
    try popCountTest(&a, 15, 14);

    try a.set(-2047);
    try popCountTest(&a, 12, 2);
    try popCountTest(&a, 24, 14);

    try a.set(maxInt(u5000));
    try popCountTest(&a, 5000, 5000);
    try a.set(minInt(i5000));
    try popCountTest(&a, 5000, 1);

    // Check -1 at various bit counts that cross Limb size multiples.
    const limb_bits = @bitSizeOf(Limb);
    try a.set(-1);
    try popCountTest(&a, 1, 1); // i1
    try popCountTest(&a, 2, 2);
    try popCountTest(&a, 16, 16);
    try popCountTest(&a, 543, 543);
    try popCountTest(&a, 544, 544);
    try popCountTest(&a, limb_bits - 1, limb_bits - 1);
    try popCountTest(&a, limb_bits, limb_bits);
    try popCountTest(&a, limb_bits + 1, limb_bits + 1);
    try popCountTest(&a, limb_bits * 2 - 1, limb_bits * 2 - 1);
    try popCountTest(&a, limb_bits * 2, limb_bits * 2);
    try popCountTest(&a, limb_bits * 2 + 1, limb_bits * 2 + 1);

    // Check very large numbers.
    try a.setString(16, "ff00000100000100" ++ ("0000000000000000" ** 62));
    try popCountTest(&a, 4032, 10);
    try popCountTest(&a, 6000, 10);
    a.negate();
    try popCountTest(&a, 4033, 48);
    try popCountTest(&a, 4133, 148);

    // Check when most significant limb is full of 1s.
    const limb_size = @bitSizeOf(Limb);
    try a.set(maxInt(Limb));
    try popCountTest(&a, limb_size, limb_size);
    try popCountTest(&a, limb_size + 1, limb_size);
    try popCountTest(&a, limb_size * 10 + 2, limb_size);
    a.negate();
    try popCountTest(&a, limb_size * 2 - 2, limb_size - 1);
    try popCountTest(&a, limb_size * 2 - 1, limb_size);
    try popCountTest(&a, limb_size * 2, limb_size + 1);
    try popCountTest(&a, limb_size * 2 + 1, limb_size + 2);
    try popCountTest(&a, limb_size * 2 + 2, limb_size + 3);
    try popCountTest(&a, limb_size * 2 + 3, limb_size + 4);
    try popCountTest(&a, limb_size * 2 + 4, limb_size + 5);
    try popCountTest(&a, limb_size * 4 + 2, limb_size * 3 + 3);
}

fn popCountTest(val: *const Managed, bit_count: usize, expected: usize) !void {
    var b = try Managed.init(testing.allocator);
    defer b.deinit();
    try b.popCount(val, bit_count);

    try testing.expectEqual(std.math.Order.eq, b.toConst().orderAgainstScalar(expected));
    try testing.expectEqual(expected, val.toConst().popCount(bit_count));
}

test "big int conversion read/write twos complement" {
    var a = try Managed.initSet(testing.allocator, (1 << 493) - 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, (1 << 493) - 1);
    defer b.deinit();
    var m = b.toMutable();

    var buffer1 = try testing.allocator.alloc(u8, 64);
    defer testing.allocator.free(buffer1);

    const endians = [_]std.builtin.Endian{ .little, .big };
    const abi_size = 64;

    for (endians) |endian| {
        // Writing to buffer and back should not change anything
        a.toConst().writeTwosComplement(buffer1[0..abi_size], endian);
        m.readTwosComplement(buffer1[0..abi_size], 493, endian, .unsigned);
        try testing.expectEqual(.eq, m.toConst().order(a.toConst()));

        // Equivalent to @bitCast(i493, @as(u493, intMax(u493))
        a.toConst().writeTwosComplement(buffer1[0..abi_size], endian);
        m.readTwosComplement(buffer1[0..abi_size], 493, endian, .signed);
        try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(-1));
    }
}

test "big int conversion read twos complement with padding" {
    var a = try Managed.initSet(testing.allocator, 0x01_02030405_06070809_0a0b0c0d);
    defer a.deinit();

    var buffer1 = try testing.allocator.alloc(u8, 16);
    defer testing.allocator.free(buffer1);
    @memset(buffer1, 0xaa);

    // writeTwosComplement:
    // (1) should not write beyond buffer[0..abi_size]
    // (2) should correctly order bytes based on the provided endianness
    // (3) should sign-extend any bits from bit_count to 8 * abi_size

    var bit_count: usize = 12 * 8 + 1;
    a.toConst().writeTwosComplement(buffer1[0..13], .little);
    try testing.expect(std.mem.eql(u8, buffer1, &[_]u8{ 0xd, 0xc, 0xb, 0xa, 0x9, 0x8, 0x7, 0x6, 0x5, 0x4, 0x3, 0x2, 0x1, 0xaa, 0xaa, 0xaa }));
    a.toConst().writeTwosComplement(buffer1[0..13], .big);
    try testing.expect(std.mem.eql(u8, buffer1, &[_]u8{ 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xa, 0xb, 0xc, 0xd, 0xaa, 0xaa, 0xaa }));
    a.toConst().writeTwosComplement(buffer1[0..16], .little);
    try testing.expect(std.mem.eql(u8, buffer1, &[_]u8{ 0xd, 0xc, 0xb, 0xa, 0x9, 0x8, 0x7, 0x6, 0x5, 0x4, 0x3, 0x2, 0x1, 0x0, 0x0, 0x0 }));
    a.toConst().writeTwosComplement(buffer1[0..16], .big);
    try testing.expect(std.mem.eql(u8, buffer1, &[_]u8{ 0x0, 0x0, 0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xa, 0xb, 0xc, 0xd }));

    @memset(buffer1, 0xaa);
    try a.set(-0x01_02030405_06070809_0a0b0c0d);
    bit_count = 12 * 8 + 2;

    a.toConst().writeTwosComplement(buffer1[0..13], .little);
    try testing.expect(std.mem.eql(u8, buffer1, &[_]u8{ 0xf3, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xaa, 0xaa, 0xaa }));
    a.toConst().writeTwosComplement(buffer1[0..13], .big);
    try testing.expect(std.mem.eql(u8, buffer1, &[_]u8{ 0xfe, 0xfd, 0xfc, 0xfb, 0xfa, 0xf9, 0xf8, 0xf7, 0xf6, 0xf5, 0xf4, 0xf3, 0xf3, 0xaa, 0xaa, 0xaa }));
    a.toConst().writeTwosComplement(buffer1[0..16], .little);
    try testing.expect(std.mem.eql(u8, buffer1, &[_]u8{ 0xf3, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff, 0xff, 0xff }));
    a.toConst().writeTwosComplement(buffer1[0..16], .big);
    try testing.expect(std.mem.eql(u8, buffer1, &[_]u8{ 0xff, 0xff, 0xff, 0xfe, 0xfd, 0xfc, 0xfb, 0xfa, 0xf9, 0xf8, 0xf7, 0xf6, 0xf5, 0xf4, 0xf3, 0xf3 }));
}

test "big int write twos complement +/- zero" {
    var a = try Managed.initSet(testing.allocator, 0x0);
    defer a.deinit();
    var m = a.toMutable();

    var buffer1 = try testing.allocator.alloc(u8, 16);
    defer testing.allocator.free(buffer1);
    @memset(buffer1, 0xaa);

    // Test zero

    m.toConst().writeTwosComplement(buffer1[0..13], .little);
    try testing.expect(std.mem.eql(u8, buffer1, &(([_]u8{0} ** 13) ++ ([_]u8{0xaa} ** 3))));
    m.toConst().writeTwosComplement(buffer1[0..13], .big);
    try testing.expect(std.mem.eql(u8, buffer1, &(([_]u8{0} ** 13) ++ ([_]u8{0xaa} ** 3))));
    m.toConst().writeTwosComplement(buffer1[0..16], .little);
    try testing.expect(std.mem.eql(u8, buffer1, &(([_]u8{0} ** 16))));
    m.toConst().writeTwosComplement(buffer1[0..16], .big);
    try testing.expect(std.mem.eql(u8, buffer1, &(([_]u8{0} ** 16))));

    @memset(buffer1, 0xaa);
    m.positive = false;

    // Test negative zero

    m.toConst().writeTwosComplement(buffer1[0..13], .little);
    try testing.expect(std.mem.eql(u8, buffer1, &(([_]u8{0} ** 13) ++ ([_]u8{0xaa} ** 3))));
    m.toConst().writeTwosComplement(buffer1[0..13], .big);
    try testing.expect(std.mem.eql(u8, buffer1, &(([_]u8{0} ** 13) ++ ([_]u8{0xaa} ** 3))));
    m.toConst().writeTwosComplement(buffer1[0..16], .little);
    try testing.expect(std.mem.eql(u8, buffer1, &(([_]u8{0} ** 16))));
    m.toConst().writeTwosComplement(buffer1[0..16], .big);
    try testing.expect(std.mem.eql(u8, buffer1, &(([_]u8{0} ** 16))));
}

test "big int conversion write twos complement with padding" {
    var a = try Managed.initSet(testing.allocator, 0x01_ffffffff_ffffffff_ffffffff);
    defer a.deinit();

    var m = a.toMutable();

    // readTwosComplement:
    // (1) should not read beyond buffer[0..abi_size]
    // (2) should correctly interpret bytes based on the provided endianness
    // (3) should ignore any bits from bit_count to 8 * abi_size

    var bit_count: usize = 12 * 8 + 1;
    var buffer: []const u8 = undefined;

    // Test 0x01_02030405_06070809_0a0b0c0d

    buffer = &[_]u8{ 0xd, 0xc, 0xb, 0xa, 0x9, 0x8, 0x7, 0x6, 0x5, 0x4, 0x3, 0x2, 0xb };
    m.readTwosComplement(buffer[0..13], bit_count, .little, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x01_02030405_06070809_0a0b0c0d));

    buffer = &[_]u8{ 0xb, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xa, 0xb, 0xc, 0xd };
    m.readTwosComplement(buffer[0..13], bit_count, .big, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x01_02030405_06070809_0a0b0c0d));

    buffer = &[_]u8{ 0xd, 0xc, 0xb, 0xa, 0x9, 0x8, 0x7, 0x6, 0x5, 0x4, 0x3, 0x2, 0xab, 0xaa, 0xaa, 0xaa };
    m.readTwosComplement(buffer[0..16], bit_count, .little, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x01_02030405_06070809_0a0b0c0d));

    buffer = &[_]u8{ 0xaa, 0xaa, 0xaa, 0xab, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xa, 0xb, 0xc, 0xd };
    m.readTwosComplement(buffer[0..16], bit_count, .big, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x01_02030405_06070809_0a0b0c0d));

    bit_count = @sizeOf(Limb) * 8;

    // Test 0x0a0a0a0a_02030405_06070809_0a0b0c0d

    buffer = &[_]u8{ 0xd, 0xc, 0xb, 0xa, 0x9, 0x8, 0x7, 0x6, 0x5, 0x4, 0x3, 0x2, 0xaa };
    m.readTwosComplement(buffer[0..13], bit_count, .little, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(@as(Limb, @truncate(0xaa_02030405_06070809_0a0b0c0d))));

    buffer = &[_]u8{ 0xaa, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xa, 0xb, 0xc, 0xd };
    m.readTwosComplement(buffer[0..13], bit_count, .big, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(@as(Limb, @truncate(0xaa_02030405_06070809_0a0b0c0d))));

    buffer = &[_]u8{ 0xd, 0xc, 0xb, 0xa, 0x9, 0x8, 0x7, 0x6, 0x5, 0x4, 0x3, 0x2, 0xaa, 0xaa, 0xaa, 0xaa };
    m.readTwosComplement(buffer[0..16], bit_count, .little, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(@as(Limb, @truncate(0xaaaaaaaa_02030405_06070809_0a0b0c0d))));

    buffer = &[_]u8{ 0xaa, 0xaa, 0xaa, 0xaa, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xa, 0xb, 0xc, 0xd };
    m.readTwosComplement(buffer[0..16], bit_count, .big, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(@as(Limb, @truncate(0xaaaaaaaa_02030405_06070809_0a0b0c0d))));

    bit_count = 12 * 8 + 2;

    // Test -0x01_02030405_06070809_0a0b0c0d

    buffer = &[_]u8{ 0xf3, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0x02 };
    m.readTwosComplement(buffer[0..13], bit_count, .little, .signed);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(-0x01_02030405_06070809_0a0b0c0d));

    buffer = &[_]u8{ 0x02, 0xfd, 0xfc, 0xfb, 0xfa, 0xf9, 0xf8, 0xf7, 0xf6, 0xf5, 0xf4, 0xf3, 0xf3 };
    m.readTwosComplement(buffer[0..13], bit_count, .big, .signed);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(-0x01_02030405_06070809_0a0b0c0d));

    buffer = &[_]u8{ 0xf3, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0x02, 0xaa, 0xaa, 0xaa };
    m.readTwosComplement(buffer[0..16], bit_count, .little, .signed);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(-0x01_02030405_06070809_0a0b0c0d));

    buffer = &[_]u8{ 0xaa, 0xaa, 0xaa, 0x02, 0xfd, 0xfc, 0xfb, 0xfa, 0xf9, 0xf8, 0xf7, 0xf6, 0xf5, 0xf4, 0xf3, 0xf3 };
    m.readTwosComplement(buffer[0..16], bit_count, .big, .signed);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(-0x01_02030405_06070809_0a0b0c0d));

    // Test 0

    buffer = &([_]u8{0} ** 16);
    m.readTwosComplement(buffer[0..13], bit_count, .little, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x0));
    m.readTwosComplement(buffer[0..13], bit_count, .big, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x0));
    m.readTwosComplement(buffer[0..16], bit_count, .little, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x0));
    m.readTwosComplement(buffer[0..16], bit_count, .big, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x0));

    bit_count = 0;
    buffer = &([_]u8{0xaa} ** 16);
    m.readTwosComplement(buffer[0..13], bit_count, .little, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x0));
    m.readTwosComplement(buffer[0..13], bit_count, .big, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x0));
    m.readTwosComplement(buffer[0..16], bit_count, .little, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x0));
    m.readTwosComplement(buffer[0..16], bit_count, .big, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x0));
}

test "big int conversion write twos complement zero" {
    var a = try Managed.initSet(testing.allocator, 0x01_ffffffff_ffffffff_ffffffff);
    defer a.deinit();

    var m = a.toMutable();

    // readTwosComplement:
    // (1) should not read beyond buffer[0..abi_size]
    // (2) should correctly interpret bytes based on the provided endianness
    // (3) should ignore any bits from bit_count to 8 * abi_size

    const bit_count: usize = 12 * 8 + 1;
    var buffer: []const u8 = undefined;

    buffer = &([_]u8{0} ** 13);
    m.readTwosComplement(buffer[0..13], bit_count, .little, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x0));
    m.readTwosComplement(buffer[0..13], bit_count, .big, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x0));

    buffer = &([_]u8{0} ** 16);
    m.readTwosComplement(buffer[0..16], bit_count, .little, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x0));
    m.readTwosComplement(buffer[0..16], bit_count, .big, .unsigned);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(0x0));
}

fn bitReverseTest(comptime T: type, comptime input: comptime_int, comptime expected_output: comptime_int) !void {
    const bit_count = @typeInfo(T).int.bits;
    const signedness = @typeInfo(T).int.signedness;

    var a = try Managed.initSet(testing.allocator, input);
    defer a.deinit();

    try a.ensureCapacity(calcTwosCompLimbCount(bit_count));
    var m = a.toMutable();
    m.bitReverse(a.toConst(), signedness, bit_count);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(expected_output));
}

test "big int bit reverse" {
    var a = try Managed.initSet(testing.allocator, 0x01_ffffffff_ffffffff_ffffffff);
    defer a.deinit();

    try bitReverseTest(u0, 0, 0);
    try bitReverseTest(u5, 0x12, 0x09);
    try bitReverseTest(u8, 0x12, 0x48);
    try bitReverseTest(u16, 0x1234, 0x2c48);
    try bitReverseTest(u24, 0x123456, 0x6a2c48);
    try bitReverseTest(u32, 0x12345678, 0x1e6a2c48);
    try bitReverseTest(u40, 0x123456789a, 0x591e6a2c48);
    try bitReverseTest(u48, 0x123456789abc, 0x3d591e6a2c48);
    try bitReverseTest(u56, 0x123456789abcde, 0x7b3d591e6a2c48);
    try bitReverseTest(u64, 0x123456789abcdef1, 0x8f7b3d591e6a2c48);
    try bitReverseTest(u95, 0x123456789abcdef111213141, 0x4146424447bd9eac8f351624);
    try bitReverseTest(u96, 0x123456789abcdef111213141, 0x828c84888f7b3d591e6a2c48);
    try bitReverseTest(u128, 0x123456789abcdef11121314151617181, 0x818e868a828c84888f7b3d591e6a2c48);

    try bitReverseTest(i8, @as(i8, @bitCast(@as(u8, 0x92))), @as(i8, @bitCast(@as(u8, 0x49))));
    try bitReverseTest(i16, @as(i16, @bitCast(@as(u16, 0x1234))), @as(i16, @bitCast(@as(u16, 0x2c48))));
    try bitReverseTest(i24, @as(i24, @bitCast(@as(u24, 0x123456))), @as(i24, @bitCast(@as(u24, 0x6a2c48))));
    try bitReverseTest(i24, @as(i24, @bitCast(@as(u24, 0x12345f))), @as(i24, @bitCast(@as(u24, 0xfa2c48))));
    try bitReverseTest(i24, @as(i24, @bitCast(@as(u24, 0xf23456))), @as(i24, @bitCast(@as(u24, 0x6a2c4f))));
    try bitReverseTest(i32, @as(i32, @bitCast(@as(u32, 0x12345678))), @as(i32, @bitCast(@as(u32, 0x1e6a2c48))));
    try bitReverseTest(i32, @as(i32, @bitCast(@as(u32, 0xf2345678))), @as(i32, @bitCast(@as(u32, 0x1e6a2c4f))));
    try bitReverseTest(i32, @as(i32, @bitCast(@as(u32, 0x1234567f))), @as(i32, @bitCast(@as(u32, 0xfe6a2c48))));
    try bitReverseTest(i40, @as(i40, @bitCast(@as(u40, 0x123456789a))), @as(i40, @bitCast(@as(u40, 0x591e6a2c48))));
    try bitReverseTest(i48, @as(i48, @bitCast(@as(u48, 0x123456789abc))), @as(i48, @bitCast(@as(u48, 0x3d591e6a2c48))));
    try bitReverseTest(i56, @as(i56, @bitCast(@as(u56, 0x123456789abcde))), @as(i56, @bitCast(@as(u56, 0x7b3d591e6a2c48))));
    try bitReverseTest(i64, @as(i64, @bitCast(@as(u64, 0x123456789abcdef1))), @as(i64, @bitCast(@as(u64, 0x8f7b3d591e6a2c48))));
    try bitReverseTest(i96, @as(i96, @bitCast(@as(u96, 0x123456789abcdef111213141))), @as(i96, @bitCast(@as(u96, 0x828c84888f7b3d591e6a2c48))));
    try bitReverseTest(i128, @as(i128, @bitCast(@as(u128, 0x123456789abcdef11121314151617181))), @as(i128, @bitCast(@as(u128, 0x818e868a828c84888f7b3d591e6a2c48))));
}

fn byteSwapTest(comptime T: type, comptime input: comptime_int, comptime expected_output: comptime_int) !void {
    const byte_count = @typeInfo(T).int.bits / 8;
    const signedness = @typeInfo(T).int.signedness;

    var a = try Managed.initSet(testing.allocator, input);
    defer a.deinit();

    try a.ensureCapacity(calcTwosCompLimbCount(8 * byte_count));
    var m = a.toMutable();
    m.byteSwap(a.toConst(), signedness, byte_count);
    try testing.expectEqual(.eq, m.toConst().orderAgainstScalar(expected_output));
}

test "big int byte swap" {
    var a = try Managed.initSet(testing.allocator, 0x01_ffffffff_ffffffff_ffffffff);
    defer a.deinit();

    @setEvalBranchQuota(10_000);

    try byteSwapTest(u0, 0, 0);
    try byteSwapTest(u8, 0x12, 0x12);
    try byteSwapTest(u16, 0x1234, 0x3412);
    try byteSwapTest(u24, 0x123456, 0x563412);
    try byteSwapTest(u32, 0x12345678, 0x78563412);
    try byteSwapTest(u40, 0x123456789a, 0x9a78563412);
    try byteSwapTest(u48, 0x123456789abc, 0xbc9a78563412);
    try byteSwapTest(u56, 0x123456789abcde, 0xdebc9a78563412);
    try byteSwapTest(u64, 0x123456789abcdef1, 0xf1debc9a78563412);
    try byteSwapTest(u88, 0x123456789abcdef1112131, 0x312111f1debc9a78563412);
    try byteSwapTest(u96, 0x123456789abcdef111213141, 0x41312111f1debc9a78563412);
    try byteSwapTest(u128, 0x123456789abcdef11121314151617181, 0x8171615141312111f1debc9a78563412);

    try byteSwapTest(i8, -50, -50);
    try byteSwapTest(i16, @as(i16, @bitCast(@as(u16, 0x1234))), @as(i16, @bitCast(@as(u16, 0x3412))));
    try byteSwapTest(i24, @as(i24, @bitCast(@as(u24, 0x123456))), @as(i24, @bitCast(@as(u24, 0x563412))));
    try byteSwapTest(i32, @as(i32, @bitCast(@as(u32, 0x12345678))), @as(i32, @bitCast(@as(u32, 0x78563412))));
    try byteSwapTest(i40, @as(i40, @bitCast(@as(u40, 0x123456789a))), @as(i40, @bitCast(@as(u40, 0x9a78563412))));
    try byteSwapTest(i48, @as(i48, @bitCast(@as(u48, 0x123456789abc))), @as(i48, @bitCast(@as(u48, 0xbc9a78563412))));
    try byteSwapTest(i56, @as(i56, @bitCast(@as(u56, 0x123456789abcde))), @as(i56, @bitCast(@as(u56, 0xdebc9a78563412))));
    try byteSwapTest(i64, @as(i64, @bitCast(@as(u64, 0x123456789abcdef1))), @as(i64, @bitCast(@as(u64, 0xf1debc9a78563412))));
    try byteSwapTest(i88, @as(i88, @bitCast(@as(u88, 0x123456789abcdef1112131))), @as(i88, @bitCast(@as(u88, 0x312111f1debc9a78563412))));
    try byteSwapTest(i96, @as(i96, @bitCast(@as(u96, 0x123456789abcdef111213141))), @as(i96, @bitCast(@as(u96, 0x41312111f1debc9a78563412))));
    try byteSwapTest(i128, @as(i128, @bitCast(@as(u128, 0x123456789abcdef11121314151617181))), @as(i128, @bitCast(@as(u128, 0x8171615141312111f1debc9a78563412))));

    try byteSwapTest(u512, 0x80, 1 << 511);
    try byteSwapTest(i512, 0x80, minInt(i512));
    try byteSwapTest(i512, 0x40, 1 << 510);
    try byteSwapTest(i512, -0x100, (1 << 504) - 1);
    try byteSwapTest(i400, -0x100, (1 << 392) - 1);
    try byteSwapTest(i400, -0x2, -(1 << 392) - 1);
    try byteSwapTest(i24, @as(i24, @bitCast(@as(u24, 0xf23456))), 0x5634f2);
    try byteSwapTest(i24, 0x1234f6, @as(i24, @bitCast(@as(u24, 0xf63412))));
    try byteSwapTest(i32, @as(i32, @bitCast(@as(u32, 0xf2345678))), 0x785634f2);
    try byteSwapTest(i32, 0x123456f8, @as(i32, @bitCast(@as(u32, 0xf8563412))));
    try byteSwapTest(i48, 0x123456789abc, @as(i48, @bitCast(@as(u48, 0xbc9a78563412))));
}

test "mul multi-multi alias r with a and b" {
    var a = try Managed.initSet(testing.allocator, 2 * maxInt(Limb));
    defer a.deinit();

    try a.mul(&a, &a);

    var want = try Managed.initSet(testing.allocator, 4 * maxInt(Limb) * maxInt(Limb));
    defer want.deinit();

    try testing.expect(a.eql(want));

    if (@typeInfo(Limb).int.bits == 64) {
        try testing.expectEqual(@as(usize, 5), a.limbs.len);
    }
}

test "sqr multi alias r with a" {
    var a = try Managed.initSet(testing.allocator, 2 * maxInt(Limb));
    defer a.deinit();

    try a.sqr(&a);

    var want = try Managed.initSet(testing.allocator, 4 * maxInt(Limb) * maxInt(Limb));
    defer want.deinit();

    try testing.expect(a.eql(want));

    if (@typeInfo(Limb).int.bits == 64) {
        try testing.expectEqual(@as(usize, 5), a.limbs.len);
    }
}

test "eql zeroes #17296" {
    var zero = try Managed.init(testing.allocator);
    defer zero.deinit();
    try zero.setString(10, "0");
    try std.testing.expect(zero.eql(zero));

    {
        var sum = try Managed.init(testing.allocator);
        defer sum.deinit();
        try sum.add(&zero, &zero);
        try std.testing.expect(zero.eql(sum));
    }

    {
        var diff = try Managed.init(testing.allocator);
        defer diff.deinit();
        try diff.sub(&zero, &zero);
        try std.testing.expect(zero.eql(diff));
    }
}

test "Const.order 0 == -0" {
    const a = std.math.big.int.Const{
        .limbs = &.{0},
        .positive = true,
    };
    const b = std.math.big.int.Const{
        .limbs = &.{0},
        .positive = false,
    };
    try std.testing.expectEqual(std.math.Order.eq, a.order(b));
}

test "Managed sqrt(0) = 0" {
    const allocator = testing.allocator;
    var a = try Managed.initSet(allocator, 1);
    defer a.deinit();

    var res = try Managed.initSet(allocator, 1);
    defer res.deinit();

    try a.setString(10, "0");

    try res.sqrt(&a);
    try testing.expectEqual(@as(i32, 0), try res.toInt(i32));
}

test "Managed sqrt(-1) = error" {
    const allocator = testing.allocator;
    var a = try Managed.initSet(allocator, 1);
    defer a.deinit();

    var res = try Managed.initSet(allocator, 1);
    defer res.deinit();

    try a.setString(10, "-1");

    try testing.expectError(error.SqrtOfNegativeNumber, res.sqrt(&a));
}

test "Managed sqrt(n) succeed with res.bitCountAbs() >= usize bits" {
    const allocator = testing.allocator;
    var a = try Managed.initSet(allocator, 1);
    defer a.deinit();

    var res = try Managed.initSet(allocator, 1);
    defer res.deinit();

    // a.bitCountAbs() = 127 so the first attempt has 64 bits >= usize bits
    try a.setString(10, "136036462105870278006290938611834481486");
    try res.sqrt(&a);

    var expected = try Managed.initSet(allocator, 1);
    defer expected.deinit();
    try expected.setString(10, "11663466984815033033");
    try std.testing.expectEqual(std.math.Order.eq, expected.order(res));
}

test "(BigInt) positive" {
    var a = try Managed.initSet(testing.allocator, 2);
    defer a.deinit();

    var b = try Managed.init(testing.allocator);
    defer b.deinit();

    var c = try Managed.initSet(testing.allocator, 1);
    defer c.deinit();

    // a = pow(2, 64 * @sizeOf(usize) * 8), b = a - 1
    try a.pow(&a, 64 * @sizeOf(Limb) * 8);
    try b.sub(&a, &c);

    try testing.expectFmt("(BigInt)", "{d}", .{a});

    const b_fmt = try std.fmt.allocPrint(testing.allocator, "{d}", .{b});
    defer testing.allocator.free(b_fmt);
    try testing.expect(!mem.eql(u8, b_fmt, "(BigInt)"));
}

test "(BigInt) negative" {
    var a = try Managed.initSet(testing.allocator, 2);
    defer a.deinit();

    var b = try Managed.init(testing.allocator);
    defer b.deinit();

    var c = try Managed.initSet(testing.allocator, 1);
    defer c.deinit();

    // a = -pow(2, 64 * @sizeOf(usize) * 8), b = a + 1
    try a.pow(&a, 64 * @sizeOf(Limb) * 8);
    a.negate();
    try b.add(&a, &c);

    const a_fmt = try std.fmt.allocPrint(testing.allocator, "{d}", .{a});
    defer testing.allocator.free(a_fmt);

    const b_fmt = try std.fmt.allocPrint(testing.allocator, "{d}", .{b});
    defer testing.allocator.free(b_fmt);

    try testing.expect(mem.eql(u8, a_fmt, "(BigInt)"));
    try testing.expect(!mem.eql(u8, b_fmt, "(BigInt)"));
}

test "clz" {
    const neg_limb_max_squared: std.math.big.int.Const = .{
        .limbs = &.{ 1, maxInt(Limb) - 1 },
        .positive = false,
    };
    try testing.expectEqual(0, neg_limb_max_squared.clz(@bitSizeOf(Limb) * 2 + 1));

    const neg_limb_max_squared_plus_one: std.math.big.int.Const = .{
        .limbs = &.{ 0, maxInt(Limb) - 1 },
        .positive = false,
    };
    try testing.expectEqual(0, neg_limb_max_squared_plus_one.clz(@bitSizeOf(Limb) * 2 + 1));

    const neg_limb_msb_squared: std.math.big.int.Const = .{
        .limbs = &.{ 0, 1 << @bitSizeOf(Limb) - 2 },
        .positive = false,
    };
    try testing.expectEqual(0, neg_limb_msb_squared.clz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(0, neg_limb_msb_squared.clz(@bitSizeOf(Limb) * 2 + 1));

    const neg_limb_max: std.math.big.int.Const = .{
        .limbs = &.{maxInt(Limb)},
        .positive = false,
    };
    try testing.expectEqual(0, neg_limb_max.clz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(0, neg_limb_max.clz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(0, neg_limb_max.clz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(0, neg_limb_max.clz(@bitSizeOf(Limb) * 2 + 1));

    const neg_limb_msb: std.math.big.int.Const = .{
        .limbs = &.{1 << @bitSizeOf(Limb) - 1},
        .positive = false,
    };
    try testing.expectEqual(0, neg_limb_msb.clz(@bitSizeOf(Limb)));
    try testing.expectEqual(0, neg_limb_msb.clz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(0, neg_limb_msb.clz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(0, neg_limb_msb.clz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(0, neg_limb_msb.clz(@bitSizeOf(Limb) * 2 + 1));

    const neg_one: std.math.big.int.Const = .{
        .limbs = &.{1},
        .positive = false,
    };
    try testing.expectEqual(0, neg_one.clz(@bitSizeOf(Limb)));
    try testing.expectEqual(0, neg_one.clz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(0, neg_one.clz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(0, neg_one.clz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(0, neg_one.clz(@bitSizeOf(Limb) * 2 + 1));

    const zero: std.math.big.int.Const = .{
        .limbs = &.{0},
        .positive = true,
    };
    try testing.expectEqual(@bitSizeOf(Limb), zero.clz(@bitSizeOf(Limb)));
    try testing.expectEqual(@bitSizeOf(Limb) + 1, zero.clz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(@bitSizeOf(Limb) * 2 - 1, zero.clz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(@bitSizeOf(Limb) * 2, zero.clz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(@bitSizeOf(Limb) * 2 + 1, zero.clz(@bitSizeOf(Limb) * 2 + 1));

    const one: std.math.big.int.Const = .{
        .limbs = &.{1},
        .positive = true,
    };
    try testing.expectEqual(@bitSizeOf(Limb) - 1, one.clz(@bitSizeOf(Limb)));
    try testing.expectEqual(@bitSizeOf(Limb), one.clz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(@bitSizeOf(Limb) * 2 - 2, one.clz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(@bitSizeOf(Limb) * 2 - 1, one.clz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(@bitSizeOf(Limb) * 2, one.clz(@bitSizeOf(Limb) * 2 + 1));

    const limb_msb: std.math.big.int.Const = .{
        .limbs = &.{1 << @bitSizeOf(Limb) - 1},
        .positive = true,
    };
    try testing.expectEqual(0, limb_msb.clz(@bitSizeOf(Limb)));
    try testing.expectEqual(1, limb_msb.clz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(@bitSizeOf(Limb) - 1, limb_msb.clz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(@bitSizeOf(Limb), limb_msb.clz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(@bitSizeOf(Limb) + 1, limb_msb.clz(@bitSizeOf(Limb) * 2 + 1));

    const limb_max: std.math.big.int.Const = .{
        .limbs = &.{maxInt(Limb)},
        .positive = true,
    };
    try testing.expectEqual(0, limb_max.clz(@bitSizeOf(Limb)));
    try testing.expectEqual(1, limb_max.clz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(@bitSizeOf(Limb) - 1, limb_max.clz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(@bitSizeOf(Limb), limb_max.clz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(@bitSizeOf(Limb) + 1, limb_max.clz(@bitSizeOf(Limb) * 2 + 1));

    const limb_msb_squared: std.math.big.int.Const = .{
        .limbs = &.{ 0, 1 << @bitSizeOf(Limb) - 2 },
        .positive = true,
    };
    try testing.expectEqual(0, limb_msb_squared.clz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(1, limb_msb_squared.clz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(2, limb_msb_squared.clz(@bitSizeOf(Limb) * 2 + 1));

    const limb_max_squared_minus_one: std.math.big.int.Const = .{
        .limbs = &.{ 0, maxInt(Limb) - 1 },
        .positive = true,
    };
    try testing.expectEqual(0, limb_max_squared_minus_one.clz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(1, limb_max_squared_minus_one.clz(@bitSizeOf(Limb) * 2 + 1));

    const limb_max_squared: std.math.big.int.Const = .{
        .limbs = &.{ 1, maxInt(Limb) - 1 },
        .positive = true,
    };
    try testing.expectEqual(0, limb_max_squared.clz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(1, limb_max_squared.clz(@bitSizeOf(Limb) * 2 + 1));
}

test "ctz" {
    const neg_limb_max_squared: std.math.big.int.Const = .{
        .limbs = &.{ 1, maxInt(Limb) - 1 },
        .positive = false,
    };
    try testing.expectEqual(0, neg_limb_max_squared.ctz(@bitSizeOf(Limb) * 2 + 1));

    const neg_limb_max_squared_plus_one: std.math.big.int.Const = .{
        .limbs = &.{ 0, maxInt(Limb) - 1 },
        .positive = false,
    };
    try testing.expectEqual(@bitSizeOf(Limb) + 1, neg_limb_max_squared_plus_one.ctz(@bitSizeOf(Limb) * 2 + 1));

    const neg_limb_msb_squared: std.math.big.int.Const = .{
        .limbs = &.{ 0, 1 << @bitSizeOf(Limb) - 2 },
        .positive = false,
    };
    try testing.expectEqual(@bitSizeOf(Limb) * 2 - 2, neg_limb_msb_squared.ctz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(@bitSizeOf(Limb) * 2 - 2, neg_limb_msb_squared.ctz(@bitSizeOf(Limb) * 2 + 1));

    const neg_limb_max: std.math.big.int.Const = .{
        .limbs = &.{maxInt(Limb)},
        .positive = false,
    };
    try testing.expectEqual(0, neg_limb_max.ctz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(0, neg_limb_max.ctz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(0, neg_limb_max.ctz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(0, neg_limb_max.ctz(@bitSizeOf(Limb) * 2 + 1));

    const neg_limb_msb: std.math.big.int.Const = .{
        .limbs = &.{1 << @bitSizeOf(Limb) - 1},
        .positive = false,
    };
    try testing.expectEqual(@bitSizeOf(Limb) - 1, neg_limb_msb.ctz(@bitSizeOf(Limb)));
    try testing.expectEqual(@bitSizeOf(Limb) - 1, neg_limb_msb.ctz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(@bitSizeOf(Limb) - 1, neg_limb_msb.ctz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(@bitSizeOf(Limb) - 1, neg_limb_msb.ctz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(@bitSizeOf(Limb) - 1, neg_limb_msb.ctz(@bitSizeOf(Limb) * 2 + 1));

    const neg_one: std.math.big.int.Const = .{
        .limbs = &.{1},
        .positive = false,
    };
    try testing.expectEqual(0, neg_one.ctz(@bitSizeOf(Limb)));
    try testing.expectEqual(0, neg_one.ctz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(0, neg_one.ctz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(0, neg_one.ctz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(0, neg_one.ctz(@bitSizeOf(Limb) * 2 + 1));

    const zero: std.math.big.int.Const = .{
        .limbs = &.{0},
        .positive = true,
    };
    try testing.expectEqual(@bitSizeOf(Limb), zero.ctz(@bitSizeOf(Limb)));
    try testing.expectEqual(@bitSizeOf(Limb) + 1, zero.ctz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(@bitSizeOf(Limb) * 2 - 1, zero.ctz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(@bitSizeOf(Limb) * 2, zero.ctz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(@bitSizeOf(Limb) * 2 + 1, zero.ctz(@bitSizeOf(Limb) * 2 + 1));

    const one: std.math.big.int.Const = .{
        .limbs = &.{1},
        .positive = true,
    };
    try testing.expectEqual(0, one.ctz(@bitSizeOf(Limb)));
    try testing.expectEqual(0, one.ctz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(0, one.ctz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(0, one.ctz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(0, one.ctz(@bitSizeOf(Limb) * 2 + 1));

    const limb_msb: std.math.big.int.Const = .{
        .limbs = &.{1 << @bitSizeOf(Limb) - 1},
        .positive = true,
    };
    try testing.expectEqual(@bitSizeOf(Limb) - 1, limb_msb.ctz(@bitSizeOf(Limb)));
    try testing.expectEqual(@bitSizeOf(Limb) - 1, limb_msb.ctz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(@bitSizeOf(Limb) - 1, limb_msb.ctz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(@bitSizeOf(Limb) - 1, limb_msb.ctz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(@bitSizeOf(Limb) - 1, limb_msb.ctz(@bitSizeOf(Limb) * 2 + 1));

    const limb_max: std.math.big.int.Const = .{
        .limbs = &.{maxInt(Limb)},
        .positive = true,
    };
    try testing.expectEqual(0, limb_max.ctz(@bitSizeOf(Limb)));
    try testing.expectEqual(0, limb_max.ctz(@bitSizeOf(Limb) + 1));
    try testing.expectEqual(0, limb_max.ctz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(0, limb_max.ctz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(0, limb_max.ctz(@bitSizeOf(Limb) * 2 + 1));

    const limb_msb_squared: std.math.big.int.Const = .{
        .limbs = &.{ 0, 1 << @bitSizeOf(Limb) - 2 },
        .positive = true,
    };
    try testing.expectEqual(@bitSizeOf(Limb) * 2 - 2, limb_msb_squared.ctz(@bitSizeOf(Limb) * 2 - 1));
    try testing.expectEqual(@bitSizeOf(Limb) * 2 - 2, limb_msb_squared.ctz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(@bitSizeOf(Limb) * 2 - 2, limb_msb_squared.ctz(@bitSizeOf(Limb) * 2 + 1));

    const limb_max_squared_minus_one: std.math.big.int.Const = .{
        .limbs = &.{ 0, maxInt(Limb) - 1 },
        .positive = true,
    };
    try testing.expectEqual(@bitSizeOf(Limb) + 1, limb_max_squared_minus_one.ctz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(@bitSizeOf(Limb) + 1, limb_max_squared_minus_one.ctz(@bitSizeOf(Limb) * 2 + 1));

    const limb_max_squared: std.math.big.int.Const = .{
        .limbs = &.{ 1, maxInt(Limb) - 1 },
        .positive = true,
    };
    try testing.expectEqual(0, limb_max_squared.ctz(@bitSizeOf(Limb) * 2));
    try testing.expectEqual(0, limb_max_squared.ctz(@bitSizeOf(Limb) * 2 + 1));
}
