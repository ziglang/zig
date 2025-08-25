const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns whether x is negative or negative 0.
pub fn signbit(x: anytype) bool {
    return switch (@typeInfo(@TypeOf(x))) {
        .int, .comptime_int => x,
        .float => |float| @as(@Type(.{ .int = .{
            .signedness = .signed,
            .bits = float.bits,
        } }), @bitCast(x)),
        .comptime_float => @as(i128, @bitCast(@as(f128, x))), // any float type will do
        else => @compileError("std.math.signbit does not support " ++ @typeName(@TypeOf(x))),
    } < 0;
}

test signbit {
    try testInts(i0);
    try testInts(u0);
    try testInts(i1);
    try testInts(u1);
    try testInts(i2);
    try testInts(u2);

    try testFloats(f16);
    try testFloats(f32);
    try testFloats(f64);
    try testFloats(f80);
    try testFloats(f128);
    try testFloats(c_longdouble);
    try testFloats(comptime_float);
}

fn testInts(comptime Type: type) !void {
    try expect((std.math.minInt(Type) < 0) == signbit(@as(Type, std.math.minInt(Type))));
    try expect(!signbit(@as(Type, 0)));
    try expect(!signbit(@as(Type, std.math.maxInt(Type))));
}

fn testFloats(comptime Type: type) !void {
    try expect(!signbit(@as(Type, 0.0)));
    try expect(!signbit(@as(Type, 1.0)));
    try expect(signbit(@as(Type, -2.0)));
    try expect(signbit(@as(Type, -0.0)));
    try expect(!signbit(math.inf(Type)));
    try expect(signbit(-math.inf(Type)));
    try expect(!signbit(math.nan(Type)));
    try expect(signbit(-math.nan(Type)));
}
