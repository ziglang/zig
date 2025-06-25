const builtin = @import("builtin");
const math = std.math;
const std = @import("std");

pub const cast = math.cast;
pub const fmax = math.floatMax;
pub const fmin = math.floatMin;
pub const imax = math.maxInt;
pub const imin = math.minInt;
pub const inf = math.inf;
pub const nan = math.nan;
pub const next = math.nextAfter;
pub const tmin = math.floatTrueMin;

pub const Gpr = switch (builtin.cpu.arch) {
    else => unreachable,
    .x86 => u32,
    .x86_64 => u64,
};
pub const Sse = if (builtin.cpu.has(.x86, .avx))
    @Vector(32, u8)
else
    @Vector(16, u8);

pub fn Scalar(comptime Type: type) type {
    return switch (@typeInfo(Type)) {
        else => Type,
        .vector => |info| info.child,
    };
}
pub fn ChangeScalar(comptime Type: type, comptime NewScalar: type) type {
    return switch (@typeInfo(Type)) {
        else => NewScalar,
        .vector => |vector| @Vector(vector.len, NewScalar),
    };
}
pub fn AsSignedness(comptime Type: type, comptime signedness: std.builtin.Signedness) type {
    return switch (@typeInfo(Scalar(Type))) {
        .int => |int| ChangeScalar(Type, @Type(.{ .int = .{
            .signedness = signedness,
            .bits = int.bits,
        } })),
        .float => Type,
        else => @compileError(@typeName(Type)),
    };
}
pub fn AddOneBit(comptime Type: type) type {
    return ChangeScalar(Type, switch (@typeInfo(Scalar(Type))) {
        .int => |int| @Type(.{ .int = .{ .signedness = int.signedness, .bits = 1 + int.bits } }),
        .float => Scalar(Type),
        else => @compileError(@typeName(Type)),
    });
}
pub fn DoubleBits(comptime Type: type) type {
    return ChangeScalar(Type, switch (@typeInfo(Scalar(Type))) {
        .int => |int| @Type(.{ .int = .{ .signedness = int.signedness, .bits = int.bits * 2 } }),
        .float => Scalar(Type),
        else => @compileError(@typeName(Type)),
    });
}
pub fn RoundBitsUp(comptime Type: type, comptime multiple: u16) type {
    return ChangeScalar(Type, switch (@typeInfo(Scalar(Type))) {
        .int => |int| @Type(.{ .int = .{
            .signedness = int.signedness,
            .bits = std.mem.alignForward(u16, int.bits, multiple),
        } }),
        .float => Scalar(Type),
        else => @compileError(@typeName(Type)),
    });
}
pub fn Log2Int(comptime Type: type) type {
    return ChangeScalar(Type, math.Log2Int(Scalar(Type)));
}
pub fn Log2IntCeil(comptime Type: type) type {
    return ChangeScalar(Type, math.Log2IntCeil(Scalar(Type)));
}
pub fn splat(comptime Type: type, scalar: Scalar(Type)) Type {
    return switch (@typeInfo(Type)) {
        else => scalar,
        .vector => @splat(scalar),
    };
}
pub fn sign(rhs: anytype) ChangeScalar(@TypeOf(rhs), bool) {
    const Int = ChangeScalar(@TypeOf(rhs), switch (@typeInfo(Scalar(@TypeOf(rhs)))) {
        .int, .comptime_int => Scalar(@TypeOf(rhs)),
        .float => |float| @Type(.{ .int = .{
            .signedness = .signed,
            .bits = float.bits,
        } }),
        else => @compileError(@typeName(@TypeOf(rhs))),
    });
    return @as(Int, @bitCast(rhs)) < splat(Int, 0);
}
pub fn select(cond: anytype, lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    return switch (@typeInfo(@TypeOf(cond))) {
        .bool => if (cond) lhs else rhs,
        .vector => @select(Scalar(@TypeOf(lhs)), cond, lhs, rhs),
        else => @compileError(@typeName(@TypeOf(cond))),
    };
}

pub const Compare = enum { strict, relaxed, approx, approx_int, approx_or_overflow };
// noinline for a more helpful stack trace
pub noinline fn checkExpected(expected: anytype, actual: @TypeOf(expected), comptime compare: Compare) !void {
    const Expected = @TypeOf(expected);
    const unexpected = unexpected: switch (@typeInfo(Scalar(Expected))) {
        else => expected != actual,
        .float => switch (compare) {
            .strict, .relaxed => {
                const unequal = (expected != actual) & ((expected == expected) | (actual == actual));
                break :unexpected switch (compare) {
                    .strict => unequal | (sign(expected) != sign(actual)),
                    .relaxed => unequal,
                    .approx, .approx_int, .approx_or_overflow => comptime unreachable,
                };
            },
            .approx, .approx_int, .approx_or_overflow => {
                const epsilon = math.floatEps(Scalar(Expected));
                const tolerance = switch (compare) {
                    .strict, .relaxed => comptime unreachable,
                    .approx, .approx_int => @sqrt(epsilon),
                    .approx_or_overflow => @exp2(@log2(epsilon) * 0.4),
                };
                const approx_unequal = @abs(expected - actual) > @max(
                    @abs(expected) * splat(Expected, tolerance),
                    splat(Expected, switch (compare) {
                        .strict, .relaxed => comptime unreachable,
                        .approx, .approx_or_overflow => tolerance,
                        .approx_int => 1,
                    }),
                );
                break :unexpected switch (compare) {
                    .strict, .relaxed => comptime unreachable,
                    .approx, .approx_int => approx_unequal,
                    .approx_or_overflow => approx_unequal &
                        (((@abs(expected) != splat(Expected, inf(Expected))) &
                            (@abs(actual) != splat(Expected, inf(Expected)))) |
                            (sign(expected) != sign(actual))),
                };
            },
        },
        .@"struct" => |@"struct"| inline for (@"struct".fields) |field| {
            try checkExpected(@field(expected, field.name), @field(actual, field.name), compare);
        } else return,
    };
    if (switch (@typeInfo(Expected)) {
        else => unexpected,
        .vector => @reduce(.Or, unexpected),
    }) return error.Unexpected;
}
test checkExpected {
    if (checkExpected(nan(f16), nan(f16), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(nan(f16), -nan(f16), .strict) != error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f16, 0.0), @as(f16, 0.0), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f16, -0.0), @as(f16, -0.0), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f16, -0.0), @as(f16, 0.0), .strict) != error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f16, 0.0), @as(f16, -0.0), .strict) != error.Unexpected) return error.Unexpected;

    if (checkExpected(nan(f32), nan(f32), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(nan(f32), -nan(f32), .strict) != error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f32, 0.0), @as(f32, 0.0), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f32, -0.0), @as(f32, -0.0), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f32, -0.0), @as(f32, 0.0), .strict) != error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f32, 0.0), @as(f32, -0.0), .strict) != error.Unexpected) return error.Unexpected;

    if (checkExpected(nan(f64), nan(f64), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(nan(f64), -nan(f64), .strict) != error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f64, 0.0), @as(f64, 0.0), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f64, -0.0), @as(f64, -0.0), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f64, -0.0), @as(f64, 0.0), .strict) != error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f64, 0.0), @as(f64, -0.0), .strict) != error.Unexpected) return error.Unexpected;

    if (checkExpected(nan(f80), nan(f80), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(nan(f80), -nan(f80), .strict) != error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f80, 0.0), @as(f80, 0.0), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f80, -0.0), @as(f80, -0.0), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f80, -0.0), @as(f80, 0.0), .strict) != error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f80, 0.0), @as(f80, -0.0), .strict) != error.Unexpected) return error.Unexpected;

    if (checkExpected(nan(f128), nan(f128), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(nan(f128), -nan(f128), .strict) != error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f128, 0.0), @as(f128, 0.0), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f128, -0.0), @as(f128, -0.0), .strict) == error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f128, -0.0), @as(f128, 0.0), .strict) != error.Unexpected) return error.Unexpected;
    if (checkExpected(@as(f128, 0.0), @as(f128, -0.0), .strict) != error.Unexpected) return error.Unexpected;
}
