const std = @import("../std.zig");
const math = std.math;
const expectEqual = std.testing.expectEqual;
const TypeId = std.builtin.TypeId;
const maxInt = std.math.maxInt;

/// Returns the square root of x.
///
/// Special Cases:
///  - sqrt(+inf)  = +inf
///  - sqrt(+-0)   = +-0
///  - sqrt(x)     = nan if x < 0
///  - sqrt(nan)   = nan
/// TODO Decide if all this logic should be implemented directly in the @sqrt builtin function.
pub fn sqrt(x: anytype) Sqrt(@TypeOf(x)) {
    const T = @TypeOf(x);
    switch (@typeInfo(T)) {
        .float, .comptime_float => return @sqrt(x),
        .comptime_int => comptime {
            if (x > maxInt(u128)) {
                @compileError("sqrt not implemented for comptime_int greater than 128 bits");
            }
            if (x < 0) {
                @compileError("sqrt on negative number");
            }
            return @as(T, sqrt_int(u128, x));
        },
        .int => |IntType| switch (IntType.signedness) {
            .signed => @compileError("sqrt not implemented for signed integers"),
            .unsigned => return sqrt_int(T, x),
        },
        else => @compileError("sqrt not implemented for " ++ @typeName(T)),
    }
}

fn sqrt_int(comptime T: type, value: T) Sqrt(T) {
    if (@typeInfo(T).int.bits <= 2) {
        return if (value == 0) 0 else 1; // shortcut for small number of bits to simplify general case
    } else {
        const bits = @typeInfo(T).int.bits;
        const max = math.maxInt(T);
        const minustwo = (@as(T, 2) ^ max) + 1; // unsigned int cannot represent -2
        var op = value;
        var res: T = 0;
        var one: T = 1 << ((bits - 1) & minustwo); // highest power of four that fits into T

        // "one" starts at the highest power of four <= than the argument.
        while (one > op) {
            one >>= 2;
        }

        while (one != 0) {
            const c = op >= res + one;
            if (c) op -= res + one;
            res >>= 1;
            if (c) res += one;
            one >>= 2;
        }

        return @as(Sqrt(T), @intCast(res));
    }
}

fn fullEqual(expected: anytype, actual: anytype) !void {
    try expectEqual(@TypeOf(expected), @TypeOf(actual));
    try expectEqual(expected, actual);
}

test sqrt_int {
    try fullEqual(@as(u16, 1), sqrt_int(u32, 3));
    try fullEqual(@as(u16, 2), sqrt_int(u32, 4));
    try fullEqual(@as(u16, 2), sqrt_int(u32, 5));
    try fullEqual(@as(u16, 2), sqrt_int(u32, 8));
    try fullEqual(@as(u16, 3), sqrt_int(u32, 9));
    try fullEqual(@as(u16, 3), sqrt_int(u32, 10));

    try fullEqual(@as(u0, 0), sqrt_int(u0, 0));
    try fullEqual(@as(u1, 1), sqrt_int(u1, 1));
    try fullEqual(@as(u1, 1), sqrt_int(u2, 3));
    try fullEqual(@as(u2, 2), sqrt_int(u3, 4));
    try fullEqual(@as(u2, 2), sqrt_int(u4, 8));
    try fullEqual(@as(u2, 3), sqrt_int(u4, 9));
}

/// Returns the return type `sqrt` will return given an operand of type `T`.
pub fn Sqrt(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .int => |int| @Type(.{ .int = .{ .signedness = .unsigned, .bits = (int.bits + 1) / 2 } }),
        else => T,
    };
}
