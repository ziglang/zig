const std = @import("../std.zig");
const builtin = @import("builtin");
const math = std.math;
const testing = std.testing;
const CompareOperator = math.CompareOperator;
const expectEqual = testing.expectEqual;
const expect = testing.expect;

/// See also `CompareOperator`.
pub const Order = enum(i2) {
    /// Less than (`<`)
    lt = -1,

    /// Equal (`==`)
    eq = 0,

    /// Greater than (`>`)
    gt = 1,

    pub fn invert(self: Order) Order {
        return @enumFromInt(-@intFromEnum(self));
    }

    test invert {
        try expectEqual(.eq, order(0, 0).invert());
        try expectEqual(.lt, order(1, 0).invert());
        try expectEqual(.gt, order(-1, 0).invert());
    }

    pub fn differ(self: Order) ?Order {
        return if (self != .eq) self else null;
    }

    test differ {
        const neg: i32 = -1;
        const zero: i32 = 0;
        const pos: i32 = 1;
        try expectEqual(.gt, order(zero, neg).differ() orelse order(pos, zero));
        try expectEqual(.eq, order(zero, zero).differ() orelse order(zero, zero));
        try expectEqual(.lt, order(pos, pos).differ() orelse order(neg, zero));
        try expectEqual(
            .gt,
            order(zero, zero).differ() orelse
                order(pos, neg).differ() orelse
                order(neg, zero),
        );
        try expectEqual(
            .eq,
            order(pos, pos).differ() orelse
                order(pos, pos).differ() orelse
                order(neg, neg),
        );
        try expectEqual(
            .lt,
            order(zero, pos).differ() orelse
                order(neg, pos).differ() orelse
                order(pos, neg),
        );
    }

    pub fn compare(self: Order, op: CompareOperator) bool {
        return math.compare(@intFromEnum(self), op, 0);
    }

    test compare {
        try expect(order(-1, 0).compare(.lt));
        try expect(order(-1, 0).compare(.lte));
        try expect(order(0, 0).compare(.lte));
        try expect(order(0, 0).compare(.eq));
        try expect(order(0, 0).compare(.gte));
        try expect(order(1, 0).compare(.gte));
        try expect(order(1, 0).compare(.gt));
        try expect(order(1, 0).compare(.neq));
    }
};

/// Given two numbers, this function returns the order they are with respect to each other.
/// For IEEE-754 floats, this uses total ordering.
pub fn order(lhs: anytype, rhs: anytype) Order {
    const T = @TypeOf(lhs, rhs);
    switch (@typeInfo(T)) {
        .int, .comptime_int => switch (builtin.zig_backend) {
            else => {
                const gt: i2 = @intFromBool(lhs > rhs);
                const lt: u1 = @intFromBool(lhs < rhs);
                return @enumFromInt(gt - lt);
            },
            .stage2_riscv64 => {
                // TODO: airSubWithOverflow non-power of 2 and less than 8 bits
                const gt: i8 = @intFromBool(lhs > rhs);
                const lt: i8 = @intFromBool(lhs < rhs);
                return @enumFromInt(gt - lt);
            },
        },
        .comptime_float => {
            return comptime order(@as(f128, lhs), @as(f128, rhs));
        },
        .float => |float| {
            // Implementation of IEEE total ordering
            const IBits = @Type(.{ .int = .{
                .bits = float.bits,
                .signedness = .signed,
            } });
            const UMask = @Type(.{ .int = .{
                .bits = float.bits - 1,
                .signedness = .unsigned,
            } });

            const lhs_bits: IBits = @bitCast(@as(T, lhs));
            const rhs_bits: IBits = @bitCast(@as(T, rhs));
            const lhs_operand = lhs_bits ^ math.boolMask(UMask, lhs_bits < 0);
            const rhs_operand = rhs_bits ^ math.boolMask(UMask, rhs_bits < 0);
            return order(lhs_operand, rhs_operand);
        },
        else => @compileError("cannot order values of type " ++ @typeName(T)),
    }
}

test order {
    // 0 == 0
    try expectEqual(.eq, order(0, 0));

    // -1 < 1
    try expectEqual(.lt, order(-1, 1));

    // 1 > -1
    try expectEqual(.gt, order(1, -1));

    // Floats use IEEE total ordering.
    // With the exception of NaN values and negative zeros,
    // this behaves identically to regular float comparisons.

    // Below is a rough "number line" of how floats are arranged with total ordering.
    const ordered_floats = [_]f32{
        -math.nan(f32), -math.inf(f32), -1.0, -0.0, 0.0, 1.0, math.inf(f32), math.nan(f32),
    };

    // We can check here that our "number line" is sorted
    for (ordered_floats[0 .. ordered_floats.len - 1], ordered_floats[1..]) |lhs, rhs| {
        try expectEqual(.lt, order(lhs, rhs));
        try expectEqual(.gt, order(rhs, lhs));
    }

    // Equality is reflexive with total ordering, even when operating on NaN values.
    // Keep in mind that while a NaN equals itself,
    // it does not equal a NaN with a different payload or sign.
    try expectEqual(.eq, order(math.nan(f32), math.nan(f32)));
    try expectEqual(.lt, order(-math.nan(f32), math.nan(f32)));

    // With total ordering, `-0.0 != 0.0`.
    // This differentiates the two values,
    // but is in contrast to the usual behavior of float comparisons.
    try expectEqual(.lt, order(-0.0, 0.0));
}

test "total ordering" {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |Float| {
        const ordered_floats = [_]Float{
            -math.nan(Float),
            -math.inf(Float),
            -math.floatMax(Float),
            -100.0,
            -1.0,
            -0.5,
            -math.floatMin(Float),
            -math.floatTrueMin(Float),
            -0.0,
            0.0,
            math.floatTrueMin(Float),
            math.floatMin(Float),
            0.5,
            1.0,
            100.0,
            math.floatMax(Float),
            math.inf(Float),
            math.nan(Float),
        };

        for (ordered_floats) |value| {
            try expectEqual(.eq, order(value, value));
            const neg_actual: Order = order(-value, value);
            const neg_expected: Order = if (std.math.signbit(value)) .gt else .lt;
            try expectEqual(neg_expected, neg_actual);
        }

        for (ordered_floats[0 .. ordered_floats.len - 1], ordered_floats[1..]) |lhs, rhs| {
            try expectEqual(.lt, order(lhs, rhs));
            try expectEqual(.gt, order(rhs, lhs));
        }
    }
}

test "distinct nans" {
    // Total ordering differentiates NaN values with different payloads

    // TODO: https://github.com/ziglang/zig/issues/14366
    if (builtin.cpu.arch.isArm() or
        builtin.cpu.arch.isAARCH64() or
        builtin.cpu.arch.isMIPS32() or
        builtin.cpu.arch.isPowerPC() or
        builtin.zig_backend == .stage2_c)
    {
        return error.SkipZigTest;
    }

    inline for ([_]type{ f16, f32, f64, f80, f128 }) |Float| {
        const U = @Type(.{ .int = .{
            .bits = @bitSizeOf(Float),
            .signedness = .unsigned,
        } });
        const extra_payload: U = 1;

        const quiet_nan: Float = math.nan(Float);
        const signal_nan: Float = math.snan(Float);

        // nan with all payload bits set
        const max_nan: Float = @bitCast(~@as(U, 1 << @bitSizeOf(Float) - 1));

        // inf < a < snan
        const nan_a: Float = make_payload: {
            const inf_bits: U = @bitCast(math.inf(Float));
            break :make_payload @bitCast(inf_bits | extra_payload);
        };

        // snan < b < qnan
        const nan_b: Float = make_payload: {
            const snan_bits: U = @bitCast(signal_nan);
            break :make_payload @bitCast(snan_bits | extra_payload);
        };

        // qnan < c < max_nan
        const nan_c: Float = make_payload: {
            const qnan_bits: U = @bitCast(quiet_nan);
            break :make_payload @bitCast(qnan_bits | extra_payload);
        };

        const ordered_nans = [_]Float{
            nan_a,
            signal_nan,
            nan_b,
            quiet_nan,
            nan_c,
            max_nan,
        };

        for (ordered_nans) |nan| {
            try expect(math.isNan(nan));
            try expectEqual(.eq, order(nan, nan));
            try expectEqual(.eq, order(-nan, -nan));
            try expectEqual(.lt, order(-nan, nan));
            try expectEqual(.gt, order(nan, -nan));
        }

        for (ordered_nans[0 .. ordered_nans.len - 1], ordered_nans[1..]) |lhs, rhs| {
            try expectEqual(.lt, order(lhs, rhs));
            try expectEqual(.gt, order(rhs, lhs));

            try expectEqual(.gt, order(-lhs, -rhs));
            try expectEqual(.lt, order(-rhs, -lhs));

            try expectEqual(.lt, order(-lhs, rhs));
            try expectEqual(.gt, order(rhs, -lhs));

            try expectEqual(.gt, order(lhs, -rhs));
            try expectEqual(.lt, order(-rhs, lhs));
        }
    }
}
