const std = @import("../std.zig");
const math = std.math;
const testing = std.testing;
const CompareOperator = math.CompareOperator;
const expectEqual = testing.expectEqual;

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
        const neg: i32 = -1;
        const zero: i32 = 0;
        const pos: i32 = 1;
        try expectEqual(.eq, order(zero, zero).invert());
        try expectEqual(.lt, order(pos, zero).invert());
        try expectEqual(.gt, order(neg, zero).invert());
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
                order(pos, neg) orelse
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
        return switch (self) {
            .lt => switch (op) {
                .lt => true,
                .lte => true,
                .eq => false,
                .gte => false,
                .gt => false,
                .neq => true,
            },
            .eq => switch (op) {
                .lt => false,
                .lte => true,
                .eq => true,
                .gte => true,
                .gt => false,
                .neq => false,
            },
            .gt => switch (op) {
                .lt => false,
                .lte => false,
                .eq => false,
                .gte => true,
                .gt => true,
                .neq => true,
            },
        };
    }

    test compare {
        try testing.expect(order(-1, 0).compare(.lt));
        try testing.expect(order(-1, 0).compare(.lte));
        try testing.expect(order(0, 0).compare(.lte));
        try testing.expect(order(0, 0).compare(.eq));
        try testing.expect(order(0, 0).compare(.gte));
        try testing.expect(order(1, 0).compare(.gte));
        try testing.expect(order(1, 0).compare(.gt));
        try testing.expect(order(1, 0).compare(.neq));
    }
};

/// Given two numbers, this function returns the order they are with respect to each other.
pub fn order(a: anytype, b: anytype) Order {
    if (a == b) {
        return .eq;
    } else if (a < b) {
        return .lt;
    } else if (a > b) {
        return .gt;
    } else {
        unreachable;
    }
}
