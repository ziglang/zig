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
                if (lhs < rhs) {
                    return .lt;
                } else if (lhs > rhs) {
                    return .gt;
                } else if (lhs == rhs) {
                    return .eq;
                } else {
                    unreachable;
                }
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
}

test "total ordering" {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |Float| {
        const inf = math.inf(Float);
        const nan = math.nan(Float);
        const snan = math.snan(Float);
        const one: Float = 1.0;
        const zero: Float = 0.0;
        try expectEqual(.eq, order(zero, zero));
        try expectEqual(.eq, order(nan, nan));
        try expectEqual(.lt, order(zero, one));
        try expectEqual(.gt, order(one, zero));
        try expectEqual(.lt, order(-one, zero));
        try expectEqual(.lt, order(-zero, zero));
        try expectEqual(.lt, order(one, inf));
        try expectEqual(.lt, order(-inf, inf));
        try expectEqual(.eq, order(nan, nan));
        try expectEqual(.gt, order(-inf, -nan));
        try expectEqual(.gt, order(-inf, -snan));
        try expectEqual(.lt, order(inf, nan));
        try expectEqual(.lt, order(inf, snan));
    }
}
