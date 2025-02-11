const builtin = @import("builtin");
const inf = math.inf;
const math = std.math;
const fmax = math.floatMax;
const fmin = math.floatMin;
const imax = math.maxInt;
const imin = math.minInt;
const nan = math.nan;
const next = math.nextAfter;
const std = @import("std");
const tmin = math.floatTrueMin;

const Gpr = switch (builtin.cpu.arch) {
    else => unreachable,
    .x86 => u32,
    .x86_64 => u64,
};
const Sse = if (std.Target.x86.featureSetHas(builtin.cpu.features, .avx))
    @Vector(32, u8)
else
    @Vector(16, u8);

inline fn runtime(comptime Type: type, comptime value: Type) Type {
    if (@inComptime()) return value;
    return struct {
        var variable: Type = value;
    }.variable;
}

fn Scalar(comptime Type: type) type {
    return switch (@typeInfo(Type)) {
        else => Type,
        .vector => |info| info.child,
    };
}
// inline to avoid a runtime `@splat`
inline fn splat(comptime Type: type, scalar: Scalar(Type)) Type {
    return switch (@typeInfo(Type)) {
        else => scalar,
        .vector => @splat(scalar),
    };
}
// inline to avoid a runtime `@select`
inline fn select(cond: anytype, lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    return switch (@typeInfo(@TypeOf(cond))) {
        .bool => if (cond) lhs else rhs,
        .vector => @select(Scalar(@TypeOf(lhs)), cond, lhs, rhs),
        else => @compileError(@typeName(@TypeOf(cond))),
    };
}
fn sign(rhs: anytype) switch (@typeInfo(@TypeOf(rhs))) {
    else => bool,
    .vector => |vector| @Vector(vector.len, bool),
} {
    const ScalarInt = @Type(.{ .int = .{
        .signedness = .unsigned,
        .bits = @bitSizeOf(Scalar(@TypeOf(rhs))),
    } });
    const VectorInt = switch (@typeInfo(@TypeOf(rhs))) {
        else => ScalarInt,
        .vector => |vector| @Vector(vector.len, ScalarInt),
    };
    return @as(VectorInt, @bitCast(rhs)) & splat(VectorInt, @as(ScalarInt, 1) << @bitSizeOf(ScalarInt) - 1) != splat(VectorInt, 0);
}
fn boolAnd(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    switch (@typeInfo(@TypeOf(lhs))) {
        .bool => return lhs and rhs,
        .vector => |vector| switch (vector.child) {
            bool => {
                const Bits = @Type(.{ .int = .{ .signedness = .unsigned, .bits = vector.len } });
                const lhs_bits: Bits = @bitCast(lhs);
                const rhs_bits: Bits = @bitCast(rhs);
                return @bitCast(lhs_bits & rhs_bits);
            },
            else => {},
        },
        else => {},
    }
    @compileError("unsupported boolAnd type: " ++ @typeName(@TypeOf(lhs)));
}
fn boolOr(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    switch (@typeInfo(@TypeOf(lhs))) {
        .bool => return lhs or rhs,
        .vector => |vector| switch (vector.child) {
            bool => {
                const Bits = @Type(.{ .int = .{ .signedness = .unsigned, .bits = vector.len } });
                const lhs_bits: Bits = @bitCast(lhs);
                const rhs_bits: Bits = @bitCast(rhs);
                return @bitCast(lhs_bits | rhs_bits);
            },
            else => {},
        },
        else => {},
    }
    @compileError("unsupported boolOr type: " ++ @typeName(@TypeOf(lhs)));
}

const Compare = enum { strict, relaxed, approx, approx_int };
// noinline for a more helpful stack trace
noinline fn checkExpected(expected: anytype, actual: @TypeOf(expected), comptime compare: Compare) !void {
    const Expected = @TypeOf(expected);
    const unexpected = unexpected: switch (@typeInfo(Scalar(Expected))) {
        else => expected != actual,
        .float => switch (compare) {
            .strict, .relaxed => {
                const unequal = boolAnd(expected != actual, boolOr(expected == expected, actual == actual));
                break :unexpected switch (compare) {
                    .strict => boolOr(unequal, sign(expected) != sign(actual)),
                    .relaxed => unequal,
                    .approx, .approx_int => comptime unreachable,
                };
            },
            .approx, .approx_int => {
                const epsilon = math.floatEps(Scalar(Expected));
                const tolerance = @sqrt(epsilon);
                break :unexpected @abs(expected - actual) > @max(
                    @abs(expected) * splat(Expected, tolerance),
                    splat(Expected, switch (compare) {
                        .strict, .relaxed => comptime unreachable,
                        .approx => tolerance,
                        .approx_int => 1,
                    }),
                );
            },
        },
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

fn unary(comptime op: anytype, comptime opts: struct {
    libc_name: ?[]const u8 = null,
    compare: Compare = .relaxed,
}) type {
    return struct {
        // noinline so that `mem_arg` is on the stack
        noinline fn testArgKinds(
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            comptime Type: type,
            comptime imm_arg: Type,
            mem_arg: Type,
        ) !void {
            const expected = expected: {
                if (opts.libc_name) |libc_name| libc: {
                    const libc_func = @extern(*const fn (Scalar(Type)) callconv(.c) Scalar(Type), .{
                        .name = switch (Scalar(Type)) {
                            f16 => "__" ++ libc_name ++ "h",
                            f32 => libc_name ++ "f",
                            f64 => libc_name,
                            f80 => "__" ++ libc_name ++ "x",
                            f128 => libc_name ++ "q",
                            else => break :libc,
                        },
                    });
                    switch (@typeInfo(Type)) {
                        else => break :expected libc_func(imm_arg),
                        .vector => |vector| {
                            var res: Type = undefined;
                            inline for (0..vector.len) |i| res[i] = libc_func(imm_arg[i]);
                            break :expected res;
                        },
                    }
                }
                break :expected comptime op(Type, imm_arg);
            };
            var reg_arg = mem_arg;
            _ = .{&reg_arg};
            try checkExpected(expected, op(Type, reg_arg), opts.compare);
            try checkExpected(expected, op(Type, mem_arg), opts.compare);
            if (opts.libc_name == null) try checkExpected(expected, op(Type, imm_arg), opts.compare);
        }
        // noinline for a more helpful stack trace
        noinline fn testArgs(comptime Type: type, comptime imm_arg: Type) !void {
            try testArgKinds(
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                Type,
                imm_arg,
                imm_arg,
            );
        }
        fn testIntTypes() !void {
            try testArgs(i1, undefined);
            try testArgs(u1, undefined);
            try testArgs(i2, undefined);
            try testArgs(u2, undefined);
            try testArgs(i3, undefined);
            try testArgs(u3, undefined);
            try testArgs(i4, undefined);
            try testArgs(u4, undefined);
            try testArgs(i5, undefined);
            try testArgs(u5, undefined);
            try testArgs(i7, undefined);
            try testArgs(u7, undefined);
            try testArgs(i8, undefined);
            try testArgs(u8, undefined);
            try testArgs(i9, undefined);
            try testArgs(u9, undefined);
            try testArgs(i15, undefined);
            try testArgs(u15, undefined);
            try testArgs(i16, undefined);
            try testArgs(u16, undefined);
            try testArgs(i17, undefined);
            try testArgs(u17, undefined);
            try testArgs(i31, undefined);
            try testArgs(u31, undefined);
            try testArgs(i32, undefined);
            try testArgs(u32, undefined);
            try testArgs(i33, undefined);
            try testArgs(u33, undefined);
            try testArgs(i63, undefined);
            try testArgs(u63, undefined);
            try testArgs(i64, undefined);
            try testArgs(u64, undefined);
            try testArgs(i65, undefined);
            try testArgs(u65, undefined);
            try testArgs(i95, undefined);
            try testArgs(u95, undefined);
            try testArgs(i96, undefined);
            try testArgs(u96, undefined);
            try testArgs(i97, undefined);
            try testArgs(u97, undefined);
            try testArgs(i127, undefined);
            try testArgs(u127, undefined);
            try testArgs(i128, undefined);
            try testArgs(u128, undefined);
            try testArgs(i129, undefined);
            try testArgs(u129, undefined);
            try testArgs(i159, undefined);
            try testArgs(u159, undefined);
            try testArgs(i160, undefined);
            try testArgs(u160, undefined);
            try testArgs(i161, undefined);
            try testArgs(u161, undefined);
            try testArgs(i191, undefined);
            try testArgs(u191, undefined);
            try testArgs(i192, undefined);
            try testArgs(u192, undefined);
            try testArgs(i193, undefined);
            try testArgs(u193, undefined);
            try testArgs(i223, undefined);
            try testArgs(u223, undefined);
            try testArgs(i224, undefined);
            try testArgs(u224, undefined);
            try testArgs(i225, undefined);
            try testArgs(u225, undefined);
            try testArgs(i255, undefined);
            try testArgs(u255, undefined);
            try testArgs(i256, undefined);
            try testArgs(u256, undefined);
            try testArgs(i257, undefined);
            try testArgs(u257, undefined);
            try testArgs(i511, undefined);
            try testArgs(u511, undefined);
            try testArgs(i512, undefined);
            try testArgs(u512, undefined);
            try testArgs(i513, undefined);
            try testArgs(u513, undefined);
            try testArgs(i1023, undefined);
            try testArgs(u1023, undefined);
            try testArgs(i1024, undefined);
            try testArgs(u1024, undefined);
            try testArgs(i1025, undefined);
            try testArgs(u1025, undefined);
        }
        fn testInts() !void {
            try testArgs(i1, -1);
            try testArgs(i1, 0);
            try testArgs(u1, 0);
            try testArgs(u1, 1 << 0);

            try testArgs(i2, -1 << 1);
            try testArgs(i2, -1);
            try testArgs(i2, 0);
            try testArgs(u2, 0);
            try testArgs(u2, 1 << 0);
            try testArgs(u2, 1 << 1);

            try testArgs(i3, -1 << 2);
            try testArgs(i3, -1);
            try testArgs(i3, 0);
            try testArgs(u3, 0);
            try testArgs(u3, 1 << 0);
            try testArgs(u3, 1 << 1);
            try testArgs(u3, 1 << 2);

            try testArgs(i4, -1 << 3);
            try testArgs(i4, -1);
            try testArgs(i4, 0);
            try testArgs(u4, 0);
            try testArgs(u4, 1 << 0);
            try testArgs(u4, 1 << 1);
            try testArgs(u4, 1 << 2);
            try testArgs(u4, 1 << 3);

            try testArgs(i5, -1 << 4);
            try testArgs(i5, -1);
            try testArgs(i5, 0);
            try testArgs(u5, 0);
            try testArgs(u5, 1 << 0);
            try testArgs(u5, 1 << 1);
            try testArgs(u5, 1 << 3);
            try testArgs(u5, 1 << 4);

            try testArgs(i7, -1 << 6);
            try testArgs(i7, -1);
            try testArgs(i7, 0);
            try testArgs(u7, 0);
            try testArgs(u7, 1 << 0);
            try testArgs(u7, 1 << 1);
            try testArgs(u7, 1 << 5);
            try testArgs(u7, 1 << 6);

            try testArgs(i8, -1 << 7);
            try testArgs(i8, -1);
            try testArgs(i8, 0);
            try testArgs(u8, 0);
            try testArgs(u8, 1 << 0);
            try testArgs(u8, 1 << 1);
            try testArgs(u8, 1 << 6);
            try testArgs(u8, 1 << 7);

            try testArgs(i9, -1 << 8);
            try testArgs(i9, -1);
            try testArgs(i9, 0);
            try testArgs(u9, 0);
            try testArgs(u9, 1 << 0);
            try testArgs(u9, 1 << 1);
            try testArgs(u9, 1 << 7);
            try testArgs(u9, 1 << 8);

            try testArgs(i15, -1 << 14);
            try testArgs(i15, -1);
            try testArgs(i15, 0);
            try testArgs(u15, 0);
            try testArgs(u15, 1 << 0);
            try testArgs(u15, 1 << 1);
            try testArgs(u15, 1 << 13);
            try testArgs(u15, 1 << 14);

            try testArgs(i16, -1 << 15);
            try testArgs(i16, -1);
            try testArgs(i16, 0);
            try testArgs(u16, 0);
            try testArgs(u16, 1 << 0);
            try testArgs(u16, 1 << 1);
            try testArgs(u16, 1 << 14);
            try testArgs(u16, 1 << 15);

            try testArgs(i17, -1 << 16);
            try testArgs(i17, -1);
            try testArgs(i17, 0);
            try testArgs(u17, 0);
            try testArgs(u17, 1 << 0);
            try testArgs(u17, 1 << 1);
            try testArgs(u17, 1 << 15);
            try testArgs(u17, 1 << 16);

            try testArgs(i31, -1 << 30);
            try testArgs(i31, -1);
            try testArgs(i31, 0);
            try testArgs(u31, 0);
            try testArgs(u31, 1 << 0);
            try testArgs(u31, 1 << 1);
            try testArgs(u31, 1 << 29);
            try testArgs(u31, 1 << 30);

            try testArgs(i32, -1 << 31);
            try testArgs(i32, -1);
            try testArgs(i32, 0);
            try testArgs(u32, 0);
            try testArgs(u32, 1 << 0);
            try testArgs(u32, 1 << 1);
            try testArgs(u32, 1 << 30);
            try testArgs(u32, 1 << 31);

            try testArgs(i33, -1 << 32);
            try testArgs(i33, -1);
            try testArgs(i33, 0);
            try testArgs(u33, 0);
            try testArgs(u33, 1 << 0);
            try testArgs(u33, 1 << 1);
            try testArgs(u33, 1 << 31);
            try testArgs(u33, 1 << 32);

            try testArgs(i63, -1 << 62);
            try testArgs(i63, -1);
            try testArgs(i63, 0);
            try testArgs(u63, 0);
            try testArgs(u63, 1 << 0);
            try testArgs(u63, 1 << 1);
            try testArgs(u63, 1 << 61);
            try testArgs(u63, 1 << 62);

            try testArgs(i64, -1 << 63);
            try testArgs(i64, -1);
            try testArgs(i64, 0);
            try testArgs(u64, 0);
            try testArgs(u64, 1 << 0);
            try testArgs(u64, 1 << 1);
            try testArgs(u64, 1 << 62);
            try testArgs(u64, 1 << 63);

            try testArgs(i65, -1 << 64);
            try testArgs(i65, -1);
            try testArgs(i65, 0);
            try testArgs(u65, 0);
            try testArgs(u65, 1 << 0);
            try testArgs(u65, 1 << 1);
            try testArgs(u65, 1 << 63);
            try testArgs(u65, 1 << 64);

            try testArgs(i95, -1 << 94);
            try testArgs(i95, -1);
            try testArgs(i95, 0);
            try testArgs(u95, 0);
            try testArgs(u95, 1 << 0);
            try testArgs(u95, 1 << 1);
            try testArgs(u95, 1 << 93);
            try testArgs(u95, 1 << 94);

            try testArgs(i96, -1 << 95);
            try testArgs(i96, -1);
            try testArgs(i96, 0);
            try testArgs(u96, 0);
            try testArgs(u96, 1 << 0);
            try testArgs(u96, 1 << 1);
            try testArgs(u96, 1 << 94);
            try testArgs(u96, 1 << 95);

            try testArgs(i97, -1 << 96);
            try testArgs(i97, -1);
            try testArgs(i97, 0);
            try testArgs(u97, 0);
            try testArgs(u97, 1 << 0);
            try testArgs(u97, 1 << 1);
            try testArgs(u97, 1 << 95);
            try testArgs(u97, 1 << 96);

            try testArgs(i127, -1 << 126);
            try testArgs(i127, -1);
            try testArgs(i127, 0);
            try testArgs(u127, 0);
            try testArgs(u127, 1 << 0);
            try testArgs(u127, 1 << 1);
            try testArgs(u127, 1 << 125);
            try testArgs(u127, 1 << 126);

            try testArgs(i128, -1 << 127);
            try testArgs(i128, -1);
            try testArgs(i128, 0);
            try testArgs(u128, 0);
            try testArgs(u128, 1 << 0);
            try testArgs(u128, 1 << 1);
            try testArgs(u128, 1 << 126);
            try testArgs(u128, 1 << 127);

            try testArgs(i129, -1 << 128);
            try testArgs(i129, -1);
            try testArgs(i129, 0);
            try testArgs(u129, 0);
            try testArgs(u129, 1 << 0);
            try testArgs(u129, 1 << 1);
            try testArgs(u129, 1 << 127);
            try testArgs(u129, 1 << 128);

            try testArgs(i159, -1 << 158);
            try testArgs(i159, -1);
            try testArgs(i159, 0);
            try testArgs(u159, 0);
            try testArgs(u159, 1 << 0);
            try testArgs(u159, 1 << 1);
            try testArgs(u159, 1 << 157);
            try testArgs(u159, 1 << 158);

            try testArgs(i160, -1 << 159);
            try testArgs(i160, -1);
            try testArgs(i160, 0);
            try testArgs(u160, 0);
            try testArgs(u160, 1 << 0);
            try testArgs(u160, 1 << 1);
            try testArgs(u160, 1 << 158);
            try testArgs(u160, 1 << 159);

            try testArgs(i161, -1 << 160);
            try testArgs(i161, -1);
            try testArgs(i161, 0);
            try testArgs(u161, 0);
            try testArgs(u161, 1 << 0);
            try testArgs(u161, 1 << 1);
            try testArgs(u161, 1 << 159);
            try testArgs(u161, 1 << 160);

            try testArgs(i191, -1 << 190);
            try testArgs(i191, -1);
            try testArgs(i191, 0);
            try testArgs(u191, 0);
            try testArgs(u191, 1 << 0);
            try testArgs(u191, 1 << 1);
            try testArgs(u191, 1 << 189);
            try testArgs(u191, 1 << 190);

            try testArgs(i192, -1 << 191);
            try testArgs(i192, -1);
            try testArgs(i192, 0);
            try testArgs(u192, 0);
            try testArgs(u192, 1 << 0);
            try testArgs(u192, 1 << 1);
            try testArgs(u192, 1 << 190);
            try testArgs(u192, 1 << 191);

            try testArgs(i193, -1 << 192);
            try testArgs(i193, -1);
            try testArgs(i193, 0);
            try testArgs(u193, 0);
            try testArgs(u193, 1 << 0);
            try testArgs(u193, 1 << 1);
            try testArgs(u193, 1 << 191);
            try testArgs(u193, 1 << 192);

            try testArgs(i223, -1 << 222);
            try testArgs(i223, -1);
            try testArgs(i223, 0);
            try testArgs(u223, 0);
            try testArgs(u223, 1 << 0);
            try testArgs(u223, 1 << 1);
            try testArgs(u223, 1 << 221);
            try testArgs(u223, 1 << 222);

            try testArgs(i224, -1 << 223);
            try testArgs(i224, -1);
            try testArgs(i224, 0);
            try testArgs(u224, 0);
            try testArgs(u224, 1 << 0);
            try testArgs(u224, 1 << 1);
            try testArgs(u224, 1 << 222);
            try testArgs(u224, 1 << 223);

            try testArgs(i225, -1 << 224);
            try testArgs(i225, -1);
            try testArgs(i225, 0);
            try testArgs(u225, 0);
            try testArgs(u225, 1 << 0);
            try testArgs(u225, 1 << 1);
            try testArgs(u225, 1 << 223);
            try testArgs(u225, 1 << 224);

            try testArgs(i255, -1 << 254);
            try testArgs(i255, -1);
            try testArgs(i255, 0);
            try testArgs(u255, 0);
            try testArgs(u255, 1 << 0);
            try testArgs(u255, 1 << 1);
            try testArgs(u255, 1 << 253);
            try testArgs(u255, 1 << 254);

            try testArgs(i256, -1 << 255);
            try testArgs(i256, -1);
            try testArgs(i256, 0);
            try testArgs(u256, 0);
            try testArgs(u256, 1 << 0);
            try testArgs(u256, 1 << 1);
            try testArgs(u256, 1 << 254);
            try testArgs(u256, 1 << 255);

            try testArgs(i257, -1 << 256);
            try testArgs(i257, -1);
            try testArgs(i257, 0);
            try testArgs(u257, 0);
            try testArgs(u257, 1 << 0);
            try testArgs(u257, 1 << 1);
            try testArgs(u257, 1 << 255);
            try testArgs(u257, 1 << 256);

            try testArgs(i511, -1 << 510);
            try testArgs(i511, -1);
            try testArgs(i511, 0);
            try testArgs(u511, 0);
            try testArgs(u511, 1 << 0);
            try testArgs(u511, 1 << 1);
            try testArgs(u511, 1 << 509);
            try testArgs(u511, 1 << 510);

            try testArgs(i512, -1 << 511);
            try testArgs(i512, -1);
            try testArgs(i512, 0);
            try testArgs(u512, 0);
            try testArgs(u512, 1 << 0);
            try testArgs(u512, 1 << 1);
            try testArgs(u512, 1 << 510);
            try testArgs(u512, 1 << 511);

            try testArgs(i513, -1 << 512);
            try testArgs(i513, -1);
            try testArgs(i513, 0);
            try testArgs(u513, 0);
            try testArgs(u513, 1 << 0);
            try testArgs(u513, 1 << 1);
            try testArgs(u513, 1 << 511);
            try testArgs(u513, 1 << 512);

            try testArgs(i1023, -1 << 1022);
            try testArgs(i1023, -1);
            try testArgs(i1023, 0);
            try testArgs(u1023, 0);
            try testArgs(u1023, 1 << 0);
            try testArgs(u1023, 1 << 1);
            try testArgs(u1023, 1 << 1021);
            try testArgs(u1023, 1 << 1022);

            try testArgs(i1024, -1 << 1023);
            try testArgs(i1024, -1);
            try testArgs(i1024, 0);
            try testArgs(u1024, 0);
            try testArgs(u1024, 1 << 0);
            try testArgs(u1024, 1 << 1);
            try testArgs(u1024, 1 << 1022);
            try testArgs(u1024, 1 << 1023);

            try testArgs(i1025, -1 << 1024);
            try testArgs(i1025, -1);
            try testArgs(i1025, 0);
            try testArgs(u1025, 0);
            try testArgs(u1025, 1 << 0);
            try testArgs(u1025, 1 << 1);
            try testArgs(u1025, 1 << 1023);
            try testArgs(u1025, 1 << 1024);
        }
        fn testFloatTypes() !void {
            try testArgs(f16, undefined);
            try testArgs(f32, undefined);
            try testArgs(f64, undefined);
            try testArgs(f80, undefined);
            try testArgs(f128, undefined);
        }
        fn testFloats() !void {
            try testArgs(f16, -nan(f16));
            try testArgs(f16, -inf(f16));
            try testArgs(f16, -fmax(f16));
            try testArgs(f16, -1e1);
            try testArgs(f16, -1e0);
            try testArgs(f16, -1e-1);
            try testArgs(f16, -fmin(f16));
            try testArgs(f16, -tmin(f16));
            try testArgs(f16, -0.0);
            try testArgs(f16, 0.0);
            try testArgs(f16, tmin(f16));
            try testArgs(f16, fmin(f16));
            try testArgs(f16, 1e-1);
            try testArgs(f16, 1e0);
            try testArgs(f16, 1e1);
            try testArgs(f16, fmax(f16));
            try testArgs(f16, inf(f16));
            try testArgs(f16, nan(f16));

            try testArgs(f32, -nan(f32));
            try testArgs(f32, -inf(f32));
            try testArgs(f32, -fmax(f32));
            try testArgs(f32, -1e1);
            try testArgs(f32, -1e0);
            try testArgs(f32, -1e-1);
            try testArgs(f32, -fmin(f32));
            try testArgs(f32, -tmin(f32));
            try testArgs(f32, -0.0);
            try testArgs(f32, 0.0);
            try testArgs(f32, tmin(f32));
            try testArgs(f32, fmin(f32));
            try testArgs(f32, 1e-1);
            try testArgs(f32, 1e0);
            try testArgs(f32, 1e1);
            try testArgs(f32, fmax(f32));
            try testArgs(f32, inf(f32));
            try testArgs(f32, nan(f32));

            try testArgs(f64, -nan(f64));
            try testArgs(f64, -inf(f64));
            try testArgs(f64, -fmax(f64));
            try testArgs(f64, -1e1);
            try testArgs(f64, -1e0);
            try testArgs(f64, -1e-1);
            try testArgs(f64, -fmin(f64));
            try testArgs(f64, -tmin(f64));
            try testArgs(f64, -0.0);
            try testArgs(f64, 0.0);
            try testArgs(f64, tmin(f64));
            try testArgs(f64, fmin(f64));
            try testArgs(f64, 1e-1);
            try testArgs(f64, 1e0);
            try testArgs(f64, 1e1);
            try testArgs(f64, fmax(f64));
            try testArgs(f64, inf(f64));
            try testArgs(f64, nan(f64));

            try testArgs(f80, -nan(f80));
            try testArgs(f80, -inf(f80));
            try testArgs(f80, -fmax(f80));
            try testArgs(f80, -1e1);
            try testArgs(f80, -1e0);
            try testArgs(f80, -1e-1);
            try testArgs(f80, -fmin(f80));
            try testArgs(f80, -tmin(f80));
            try testArgs(f80, -0.0);
            try testArgs(f80, 0.0);
            try testArgs(f80, tmin(f80));
            try testArgs(f80, fmin(f80));
            try testArgs(f80, 1e-1);
            try testArgs(f80, 1e0);
            try testArgs(f80, 1e1);
            try testArgs(f80, fmax(f80));
            try testArgs(f80, inf(f80));
            try testArgs(f80, nan(f80));

            try testArgs(f128, -nan(f128));
            try testArgs(f128, -inf(f128));
            try testArgs(f128, -fmax(f128));
            try testArgs(f128, -1e1);
            try testArgs(f128, -1e0);
            try testArgs(f128, -1e-1);
            try testArgs(f128, -fmin(f128));
            try testArgs(f128, -tmin(f128));
            try testArgs(f128, -0.0);
            try testArgs(f128, 0.0);
            try testArgs(f128, tmin(f128));
            try testArgs(f128, fmin(f128));
            try testArgs(f128, 1e-1);
            try testArgs(f128, 1e0);
            try testArgs(f128, 1e1);
            try testArgs(f128, fmax(f128));
            try testArgs(f128, inf(f128));
            try testArgs(f128, nan(f128));
        }
        fn testIntVectorTypes() !void {
            try testArgs(@Vector(3, i1), undefined);
            try testArgs(@Vector(3, u1), undefined);
            try testArgs(@Vector(3, i2), undefined);
            try testArgs(@Vector(3, u2), undefined);
            try testArgs(@Vector(3, i3), undefined);
            try testArgs(@Vector(3, u3), undefined);
            try testArgs(@Vector(3, i4), undefined);
            try testArgs(@Vector(1, i4), undefined);
            try testArgs(@Vector(2, i4), undefined);
            try testArgs(@Vector(4, i4), undefined);
            try testArgs(@Vector(8, i4), undefined);
            try testArgs(@Vector(16, i4), undefined);
            try testArgs(@Vector(32, i4), undefined);
            try testArgs(@Vector(64, i4), undefined);
            try testArgs(@Vector(128, i4), undefined);
            try testArgs(@Vector(256, i4), undefined);
            try testArgs(@Vector(3, u4), undefined);
            try testArgs(@Vector(1, u4), undefined);
            try testArgs(@Vector(2, u4), undefined);
            try testArgs(@Vector(4, u4), undefined);
            try testArgs(@Vector(8, u4), undefined);
            try testArgs(@Vector(16, u4), undefined);
            try testArgs(@Vector(32, u4), undefined);
            try testArgs(@Vector(64, u4), undefined);
            try testArgs(@Vector(128, u4), undefined);
            try testArgs(@Vector(256, u4), undefined);
            try testArgs(@Vector(3, i5), undefined);
            try testArgs(@Vector(3, u5), undefined);
            try testArgs(@Vector(3, i7), undefined);
            try testArgs(@Vector(3, u7), undefined);
            try testArgs(@Vector(3, i8), undefined);
            try testArgs(@Vector(1, i8), undefined);
            try testArgs(@Vector(2, i8), undefined);
            try testArgs(@Vector(4, i8), undefined);
            try testArgs(@Vector(8, i8), undefined);
            try testArgs(@Vector(16, i8), undefined);
            try testArgs(@Vector(32, i8), undefined);
            try testArgs(@Vector(64, i8), undefined);
            try testArgs(@Vector(128, i8), undefined);
            try testArgs(@Vector(3, u8), undefined);
            try testArgs(@Vector(1, u8), undefined);
            try testArgs(@Vector(2, u8), undefined);
            try testArgs(@Vector(4, u8), undefined);
            try testArgs(@Vector(8, u8), undefined);
            try testArgs(@Vector(16, u8), undefined);
            try testArgs(@Vector(32, u8), undefined);
            try testArgs(@Vector(64, u8), undefined);
            try testArgs(@Vector(128, u8), undefined);
            try testArgs(@Vector(3, i9), undefined);
            try testArgs(@Vector(3, u9), undefined);
            try testArgs(@Vector(3, i15), undefined);
            try testArgs(@Vector(3, u15), undefined);
            try testArgs(@Vector(3, i16), undefined);
            try testArgs(@Vector(1, i16), undefined);
            try testArgs(@Vector(2, i16), undefined);
            try testArgs(@Vector(4, i16), undefined);
            try testArgs(@Vector(8, i16), undefined);
            try testArgs(@Vector(16, i16), undefined);
            try testArgs(@Vector(32, i16), undefined);
            try testArgs(@Vector(64, i16), undefined);
            try testArgs(@Vector(3, u16), undefined);
            try testArgs(@Vector(1, u16), undefined);
            try testArgs(@Vector(2, u16), undefined);
            try testArgs(@Vector(4, u16), undefined);
            try testArgs(@Vector(8, u16), undefined);
            try testArgs(@Vector(16, u16), undefined);
            try testArgs(@Vector(32, u16), undefined);
            try testArgs(@Vector(64, u16), undefined);
            try testArgs(@Vector(3, i17), undefined);
            try testArgs(@Vector(3, u17), undefined);
            try testArgs(@Vector(3, i31), undefined);
            try testArgs(@Vector(3, u31), undefined);
            try testArgs(@Vector(3, i32), undefined);
            try testArgs(@Vector(1, i32), undefined);
            try testArgs(@Vector(2, i32), undefined);
            try testArgs(@Vector(4, i32), undefined);
            try testArgs(@Vector(8, i32), undefined);
            try testArgs(@Vector(16, i32), undefined);
            try testArgs(@Vector(32, i32), undefined);
            try testArgs(@Vector(3, u32), undefined);
            try testArgs(@Vector(1, u32), undefined);
            try testArgs(@Vector(2, u32), undefined);
            try testArgs(@Vector(4, u32), undefined);
            try testArgs(@Vector(8, u32), undefined);
            try testArgs(@Vector(16, u32), undefined);
            try testArgs(@Vector(32, u32), undefined);
            try testArgs(@Vector(3, i33), undefined);
            try testArgs(@Vector(3, u33), undefined);
            try testArgs(@Vector(3, i63), undefined);
            try testArgs(@Vector(3, u63), undefined);
            try testArgs(@Vector(3, i64), undefined);
            try testArgs(@Vector(1, i64), undefined);
            try testArgs(@Vector(2, i64), undefined);
            try testArgs(@Vector(4, i64), undefined);
            try testArgs(@Vector(8, i64), undefined);
            try testArgs(@Vector(16, i64), undefined);
            try testArgs(@Vector(3, u64), undefined);
            try testArgs(@Vector(1, u64), undefined);
            try testArgs(@Vector(2, u64), undefined);
            try testArgs(@Vector(4, u64), undefined);
            try testArgs(@Vector(8, u64), undefined);
            try testArgs(@Vector(16, u64), undefined);
            try testArgs(@Vector(3, i65), undefined);
            try testArgs(@Vector(3, u65), undefined);
            try testArgs(@Vector(3, i127), undefined);
            try testArgs(@Vector(3, u127), undefined);
            try testArgs(@Vector(3, i128), undefined);
            try testArgs(@Vector(1, i128), undefined);
            try testArgs(@Vector(2, i128), undefined);
            try testArgs(@Vector(4, i128), undefined);
            try testArgs(@Vector(8, i128), undefined);
            try testArgs(@Vector(3, u128), undefined);
            try testArgs(@Vector(1, u128), undefined);
            try testArgs(@Vector(2, u128), undefined);
            try testArgs(@Vector(4, u128), undefined);
            try testArgs(@Vector(8, u128), undefined);
            try testArgs(@Vector(3, i129), undefined);
            try testArgs(@Vector(3, u129), undefined);
            try testArgs(@Vector(3, i191), undefined);
            try testArgs(@Vector(3, u191), undefined);
            try testArgs(@Vector(3, i192), undefined);
            try testArgs(@Vector(1, i192), undefined);
            try testArgs(@Vector(2, i192), undefined);
            try testArgs(@Vector(4, i192), undefined);
            try testArgs(@Vector(3, u192), undefined);
            try testArgs(@Vector(1, u192), undefined);
            try testArgs(@Vector(2, u192), undefined);
            try testArgs(@Vector(4, u192), undefined);
            try testArgs(@Vector(3, i193), undefined);
            try testArgs(@Vector(3, u193), undefined);
            try testArgs(@Vector(3, i255), undefined);
            try testArgs(@Vector(3, u255), undefined);
            try testArgs(@Vector(3, i256), undefined);
            try testArgs(@Vector(1, i256), undefined);
            try testArgs(@Vector(2, i256), undefined);
            try testArgs(@Vector(4, i256), undefined);
            try testArgs(@Vector(3, u256), undefined);
            try testArgs(@Vector(1, u256), undefined);
            try testArgs(@Vector(2, u256), undefined);
            try testArgs(@Vector(4, u256), undefined);
            try testArgs(@Vector(3, i257), undefined);
            try testArgs(@Vector(3, u257), undefined);
            try testArgs(@Vector(3, i511), undefined);
            try testArgs(@Vector(3, u511), undefined);
            try testArgs(@Vector(3, i512), undefined);
            try testArgs(@Vector(1, i512), undefined);
            try testArgs(@Vector(2, i512), undefined);
            try testArgs(@Vector(3, u512), undefined);
            try testArgs(@Vector(1, u512), undefined);
            try testArgs(@Vector(2, u512), undefined);
            try testArgs(@Vector(3, i513), undefined);
            try testArgs(@Vector(3, u513), undefined);
            try testArgs(@Vector(3, i1023), undefined);
            try testArgs(@Vector(3, u1023), undefined);
            try testArgs(@Vector(3, i1024), undefined);
            try testArgs(@Vector(1, i1024), undefined);
            try testArgs(@Vector(3, u1024), undefined);
            try testArgs(@Vector(1, u1024), undefined);
            try testArgs(@Vector(3, i1025), undefined);
            try testArgs(@Vector(3, u1025), undefined);
        }
        fn testIntVectors() !void {
            try testArgs(@Vector(3, i1), .{ -1 << 0, -1, 0 });
            try testArgs(@Vector(3, u1), .{ 0, 1, 1 << 0 });

            try testArgs(@Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u2), .{ 0, 1, 1 << 1 });

            try testArgs(@Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u3), .{ 0, 1, 1 << 2 });

            try testArgs(@Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(1, i4), .{
                -0x2,
            });
            try testArgs(@Vector(2, i4), .{
                -0x7, 0x4,
            });
            try testArgs(@Vector(4, i4), .{
                -0x3, 0x4, 0x2, -0x2,
            });
            try testArgs(@Vector(8, i4), .{
                -0x6, 0x3, 0x4, 0x3, 0x4, -0x8, -0x3, -0x5,
            });
            try testArgs(@Vector(16, i4), .{
                -0x3, 0x5, 0x4, -0x1, 0x2, 0x7, 0x1, 0x0, -0x2, 0x6, -0x1, -0x3, 0x5, -0x3, 0x3, -0x7,
            });
            try testArgs(@Vector(32, i4), .{
                -0x4, -0x2, 0x6, 0x6, -0x5, -0x8, -0x8, 0x7, -0x5, -0x5, 0x4, 0x5, -0x6, -0x1, 0x2, 0x0, -0x1, 0x3, 0x5, 0x1, -0x4, 0x2, -0x8, -0x6, -0x1, 0x3, 0x1, -0x8, 0x5, -0x6, 0x0, 0x2,
            });
            try testArgs(@Vector(64, i4), .{
                -0x2, 0x6,  -0x5, 0x2,  0x6, -0x5, 0x1,  -0x6, -0x6, 0x3, -0x5, 0x5, 0x0,  0x3, -0x6, -0x2, 0x0, -0x5, -0x2, -0x7, 0x6,  0x6, -0x6, 0x5, -0x1, 0x1, -0x5, 0x4,  -0x1, 0x2,  0x5,  0x0,
                0x6,  -0x1, -0x3, -0x1, 0x0, 0x0,  -0x2, -0x5, 0x7,  0x4, -0x7, 0x4, -0x8, 0x2, -0x1, -0x5, 0x4, -0x6, -0x3, 0x6,  -0x6, 0x5, 0x0,  0x6, -0x3, 0x3, -0x4, -0x4, 0x3,  -0x6, -0x5, -0x3,
            });
            try testArgs(@Vector(128, i4), .{
                -0x2, 0x7,  -0x7, 0x5,  0x4,  -0x8, -0x4, 0x2,  -0x6, 0x6,  0x3,  0x4,  -0x6, -0x3, 0x1,  -0x3, 0x4,  -0x4, 0x0, -0x5, 0x4,  -0x2, 0x4,  -0x6, 0x4,  0x7,  -0x6, 0x3,  -0x6, 0x5,  0x7,  -0x7,
                -0x8, 0x0,  0x2,  -0x6, -0x4, 0x5,  -0x2, -0x6, 0x2,  -0x3, -0x8, -0x3, -0x1, 0x4,  0x7,  -0x2, 0x7,  -0x3, 0x5, 0x3,  -0x6, 0x5,  -0x2, -0x5, -0x1, 0x5,  -0x6, -0x2, -0x5, -0x4, -0x7, -0x3,
                -0x4, -0x4, 0x6,  -0x8, -0x2, 0x3,  0x1,  0x7,  0x1,  -0x2, -0x7, -0x2, -0x8, -0x6, -0x6, 0x0,  -0x3, -0x4, 0x3, -0x5, -0x3, -0x5, 0x6,  0x5,  -0x7, -0x8, -0x5, -0x6, -0x2, -0x5, 0x5,  -0x5,
                0x0,  -0x6, -0x3, 0x0,  0x7,  0x6,  -0x6, -0x7, -0x4, -0x5, 0x3,  0x2,  0x7,  -0x3, -0x2, 0x4,  -0x4, -0x5, 0x6, 0x1,  0x7,  -0x5, -0x6, 0x0,  0x0,  -0x8, 0x4,  -0x1, -0x7, 0x0,  0x0,  0x5,
            });
            try testArgs(@Vector(256, i4), .{
                -0x7, 0x4,  0x7,  -0x5, 0x6,  -0x2, 0x6,  -0x5, 0x5,  0x5,  0x3,  -0x3, -0x5, 0x0,  0x5,  0x1,  0x4,  -0x1, 0x4,  -0x8, -0x4, -0x8, 0x2,  -0x8, 0x3,  0x1,  -0x7, -0x3, -0x1, 0x5,  -0x5, -0x8,
                -0x3, -0x3, -0x5, 0x6,  0x0,  0x4,  -0x3, -0x5, 0x0,  0x5,  -0x1, -0x3, -0x4, -0x3, 0x6,  -0x3, -0x1, 0x5,  -0x3, -0x3, 0x0,  0x3,  -0x2, -0x1, -0x5, 0x3,  0x2,  -0x8, 0x7,  -0x8, 0x6,  0x4,
                -0x5, -0x4, 0x5,  0x5,  0x6,  -0x3, 0x2,  -0x4, 0x3,  0x7,  0x6,  -0x2, -0x8, -0x1, -0x8, 0x2,  0x4,  0x1,  0x2,  -0x1, 0x5,  0x1,  0x3,  0x1,  0x3,  -0x5, 0x3,  -0x5, -0x5, 0x5,  -0x6, -0x7,
                0x0,  0x0,  -0x3, 0x6,  0x0,  0x5,  0x3,  0x0,  0x0,  -0x1, -0x6, -0x4, 0x5,  -0x8, -0x4, -0x3, -0x3, 0x2,  -0x5, -0x4, 0x4,  0x5,  -0x6, -0x3, 0x2,  0x5,  -0x7, -0x6, 0x3,  0x7,  -0x2, 0x6,
                0x2,  0x3,  0x7,  0x3,  0x2,  -0x5, 0x4,  0x5,  -0x4, -0x7, 0x2,  0x2,  -0x5, 0x7,  -0x3, -0x8, 0x2,  -0x4, 0x2,  0x4,  0x5,  -0x7, 0x7,  -0x6, 0x4,  -0x8, -0x1, 0x7,  0x0,  -0x4, 0x6,  -0x8,
                -0x5, 0x4,  -0x5, 0x1,  0x6,  -0x8, -0x1, -0x3, -0x5, 0x7,  0x1,  0x0,  -0x3, 0x4,  -0x5, -0x7, -0x5, 0x2,  0x0,  -0x1, -0x4, 0x0,  0x5,  0x6,  -0x3, -0x4, -0x2, 0x4,  -0x1, -0x8, 0x0,  0x6,
                0x7,  0x1,  0x5,  0x2,  -0x4, -0x7, -0x3, -0x3, -0x8, -0x8, -0x3, -0x4, 0x5,  -0x5, -0x2, -0x2, 0x1,  0x1,  0x1,  -0x8, 0x5,  0x4,  0x5,  0x6,  0x3,  0x0,  -0x2, -0x1, 0x4,  -0x4, -0x5, 0x0,
                -0x7, -0x8, -0x2, 0x1,  0x5,  0x4,  0x5,  -0x7, 0x3,  0x2,  0x2,  0x5,  -0x3, 0x7,  -0x4, 0x0,  -0x3, -0x2, -0x5, 0x1,  0x1,  -0x4, -0x4, 0x1,  -0x8, -0x3, 0x6,  -0x8, -0x2, 0x5,  0x7,  -0x3,
            });

            try testArgs(@Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(1, u4), .{
                0xb,
            });
            try testArgs(@Vector(2, u4), .{
                0x3, 0x4,
            });
            try testArgs(@Vector(4, u4), .{
                0x9, 0x2, 0xf, 0xe,
            });
            try testArgs(@Vector(8, u4), .{
                0x8, 0x1, 0xb, 0x1, 0xf, 0x5, 0x9, 0x6,
            });
            try testArgs(@Vector(16, u4), .{
                0xb, 0x6, 0x0, 0x7, 0x8, 0x5, 0x6, 0x9, 0xe, 0xb, 0x3, 0xa, 0xb, 0x5, 0x8, 0xc,
            });
            try testArgs(@Vector(32, u4), .{
                0xe, 0x6, 0xe, 0xa, 0xb, 0x4, 0xa, 0xb, 0x1, 0x3, 0xb, 0xc, 0x0, 0xb, 0x9, 0x4, 0xd, 0xa, 0xd, 0xd, 0x4, 0x8, 0x8, 0x6, 0xb, 0xe, 0x9, 0x6, 0xc, 0xd, 0x5, 0xd,
            });
            try testArgs(@Vector(64, u4), .{
                0x1, 0xc, 0xe, 0x9, 0x9, 0xf, 0x3, 0xf, 0x9, 0x9, 0x5, 0x3, 0xb, 0xd, 0xd, 0xf, 0x1, 0x2, 0xf, 0x9, 0x4, 0x4, 0x8, 0x9, 0x2, 0x9, 0x8, 0xe, 0x8, 0xa, 0x4, 0x3,
                0x4, 0xc, 0xb, 0x6, 0x4, 0x0, 0xa, 0x5, 0x1, 0xa, 0x4, 0xe, 0xa, 0x7, 0xd, 0x0, 0x4, 0xe, 0xe, 0x7, 0x7, 0xa, 0x4, 0x5, 0x6, 0xc, 0x6, 0x2, 0x6, 0xa, 0xe, 0xa,
            });
            try testArgs(@Vector(128, u4), .{
                0xd, 0x5, 0x6, 0xe, 0x3, 0x3, 0x3, 0xe, 0xd, 0xd, 0x9, 0x0, 0x0, 0xe, 0xa, 0x9, 0x8, 0x7, 0xb, 0x5, 0x7, 0xf, 0xb, 0x8, 0x0, 0xf, 0xb, 0x3, 0xa, 0x2, 0xb, 0xc,
                0x1, 0x1, 0xc, 0x8, 0x8, 0x6, 0x9, 0x1, 0xb, 0x0, 0x2, 0xb, 0x2, 0x2, 0x7, 0x6, 0x1, 0x1, 0xb, 0x4, 0x6, 0x4, 0x7, 0xc, 0xd, 0xc, 0xa, 0x8, 0x1, 0x7, 0x8, 0xa,
                0x9, 0xa, 0x1, 0x8, 0x1, 0x7, 0x9, 0x4, 0x5, 0x9, 0xd, 0x0, 0xa, 0xf, 0x3, 0x3, 0x9, 0x2, 0xf, 0x5, 0xb, 0x8, 0x6, 0xb, 0xf, 0x5, 0x8, 0x3, 0x9, 0xf, 0x6, 0x8,
                0xc, 0x8, 0x3, 0x4, 0xa, 0xe, 0xc, 0x1, 0xe, 0x9, 0x1, 0x8, 0xf, 0x6, 0xc, 0xc, 0x6, 0xf, 0x6, 0xd, 0xb, 0x9, 0xc, 0x3, 0xd, 0xa, 0x6, 0x8, 0x4, 0xa, 0x6, 0x9,
            });
            try testArgs(@Vector(256, u4), .{
                0x6, 0xc, 0xe, 0x3, 0x8, 0x2, 0xb, 0xd, 0x3, 0xa, 0x3, 0x8, 0xb, 0x8, 0x3, 0x0, 0xb, 0x5, 0x1, 0x3, 0x2, 0x2, 0xf, 0xc, 0x5, 0x1, 0x3, 0xb, 0x1, 0xc, 0x2, 0xd,
                0xa, 0x8, 0x1, 0xc, 0xb, 0xa, 0x3, 0x1, 0xe, 0x4, 0xf, 0xb, 0xd, 0x8, 0xf, 0xa, 0xc, 0xb, 0xb, 0x0, 0xa, 0xc, 0xf, 0xe, 0x8, 0xd, 0x9, 0x3, 0xa, 0xe, 0x8, 0x7,
                0x5, 0xa, 0x0, 0xe, 0x0, 0xd, 0x2, 0x2, 0x9, 0x4, 0x8, 0x9, 0x0, 0x4, 0x4, 0x8, 0xe, 0x1, 0xf, 0x1, 0x9, 0x3, 0xf, 0xc, 0xa, 0x0, 0x3, 0x2, 0x4, 0x1, 0x2, 0x3,
                0xf, 0x2, 0x7, 0xb, 0x5, 0x0, 0xd, 0x3, 0x4, 0xf, 0xa, 0x3, 0xc, 0x2, 0x5, 0xe, 0x7, 0x5, 0xd, 0x7, 0x9, 0x0, 0xd, 0x7, 0x9, 0xd, 0x5, 0x7, 0xf, 0xd, 0xb, 0x4,
                0x9, 0x6, 0xf, 0xb, 0x1, 0xb, 0x6, 0xb, 0xf, 0x7, 0xf, 0x0, 0x4, 0x7, 0x5, 0xa, 0x8, 0x1, 0xf, 0x9, 0x9, 0x0, 0x6, 0xb, 0x1, 0x2, 0x4, 0x3, 0x2, 0x0, 0x7, 0x0,
                0x6, 0x7, 0xf, 0x1, 0xe, 0xa, 0x8, 0x2, 0x9, 0xc, 0x1, 0x5, 0x7, 0x1, 0xb, 0x0, 0x1, 0x3, 0xd, 0x3, 0x0, 0x1, 0xa, 0x0, 0x3, 0x7, 0x1, 0x2, 0xb, 0xc, 0x2, 0x9,
                0x8, 0x8, 0x7, 0x0, 0xd, 0x5, 0x1, 0x5, 0x7, 0x7, 0x2, 0x3, 0x8, 0x7, 0xc, 0x8, 0xf, 0xa, 0xf, 0xf, 0x3, 0x2, 0x0, 0x4, 0x7, 0x5, 0x6, 0xd, 0x6, 0x3, 0xa, 0x4,
                0x1, 0x1, 0x2, 0xc, 0x3, 0xe, 0x2, 0xc, 0x7, 0x6, 0xe, 0xf, 0xb, 0x8, 0x6, 0x6, 0x9, 0x0, 0x4, 0xb, 0xe, 0x4, 0x2, 0x7, 0xf, 0xc, 0x0, 0x6, 0xd, 0xa, 0xe, 0xc,
            });

            try testArgs(@Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u5), .{ 0, 1, 1 << 4 });

            try testArgs(@Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u7), .{ 0, 1, 1 << 6 });

            try testArgs(@Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(1, i8), .{
                0x71,
            });
            try testArgs(@Vector(2, i8), .{
                -0x50, -0x43,
            });
            try testArgs(@Vector(4, i8), .{
                -0x09, -0x19, -0x15, -0x5d,
            });
            try testArgs(@Vector(8, i8), .{
                -0x4f, -0x55, -0x5b, -0x23, -0x76, 0x36, 0x6f, -0x63,
            });
            try testArgs(@Vector(16, i8), .{
                0x24, -0x03, 0x2e, 0x7b, 0x68, 0x29, 0x6c, 0x7f, -0x2f, -0x3b, -0x11, -0x3c, -0x2e, 0x27, -0x45, 0x45,
            });
            try testArgs(@Vector(32, i8), .{
                0x70, 0x33, -0x28, -0x38, -0x3b, 0x44,  -0x1d, 0x7d,  -0x48, 0x3c,  0x61, -0x09, -0x49, 0x15,  0x0a, -0x5a,
                0x78, 0x11, -0x07, -0x23, 0x4a,  -0x72, 0x25,  -0x17, -0x51, -0x04, 0x55, 0x20,  -0x80, -0x3d, 0x59, -0x39,
            });
            try testArgs(@Vector(64, i8), .{
                0x4f, 0x40,  -0x62, -0x4f, 0x37, -0x06, -0x33, 0x4d,  -0x10, 0x55,  0x24,  -0x76, 0x1d,  0x2b,  -0x54, -0x0f,
                0x21, -0x4c, -0x74, -0x07, 0x23, -0x5a, -0x21, -0x4a, -0x7c, -0x16, -0x20, -0x2e, 0x0a,  0x15,  0x03,  0x44,
                0x19, -0x27, 0x3e,  0x61,  0x6e, -0x76, 0x2a,  0x74,  -0x21, 0x34,  -0x69, -0x18, -0x21, -0x61, -0x34, -0x02,
                0x5e, -0x36, -0x79, -0x0f, 0x26, 0x6e,  0x5f,  0x52,  -0x0f, -0x64, 0x1a,  0x74,  -0x37, 0x00,  -0x47, -0x57,
            });
            try testArgs(@Vector(128, i8), .{
                -0x38, -0x19, 0x51,  0x09,  0x76,  -0x3b, -0x33, 0x39,  0x67,  0x51,  0x10,  0x77,  0x24,  0x21,  0x6f,  -0x1a,
                0x4e,  -0x69, 0x2e,  -0x78, -0x06, 0x5c,  0x17,  0x2e,  -0x0e, -0x2e, 0x09,  0x2a,  -0x5f, -0x40, -0x64, 0x3f,
                0x4a,  -0x77, -0x54, 0x38,  0x6b,  0x1f,  -0x04, 0x40,  0x27,  -0x0c, 0x65,  -0x46, 0x49,  -0x69, -0x53, 0x64,
                0x13,  -0x33, 0x3a,  -0x10, -0x15, 0x7f,  -0x1c, 0x5e,  -0x22, 0x2f,  -0x75, 0x77,  0x22,  0x6b,  -0x32, -0x55,
                0x18,  0x19,  0x2c,  -0x27, -0x03, 0x4f,  0x07,  0x0b,  0x44,  -0x21, 0x79,  0x55,  -0x65, 0x1d,  -0x29, 0x2f,
                0x4a,  0x6f,  -0x40, -0x57, -0x2f, 0x42,  0x52,  0x68,  -0x2a, -0x6b, 0x6f,  -0x49, -0x32, 0x52,  0x1e,  -0x60,
                -0x80, 0x53,  0x5e,  0x73,  -0x1e, 0x2d,  -0x46, -0x27, 0x4b,  0x57,  0x1f,  0x6a,  -0x65, 0x5f,  -0x2b, -0x03,
                -0x3a, -0x76, -0x51, 0x20,  0x04,  -0x0a, 0x2b,  -0x04, -0x1e, -0x18, -0x2d, 0x53,  -0x58, -0x69, 0x16,  0x19,
            });

            try testArgs(@Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(1, u8), .{
                0x33,
            });
            try testArgs(@Vector(2, u8), .{
                0x66, 0x87,
            });
            try testArgs(@Vector(4, u8), .{
                0x9d, 0xcb, 0x30, 0x7b,
            });
            try testArgs(@Vector(8, u8), .{
                0x4b, 0x35, 0x3f, 0x5c, 0xa5, 0x91, 0x23, 0x6d,
            });
            try testArgs(@Vector(16, u8), .{
                0xb7, 0x57, 0x27, 0x29, 0x58, 0xf8, 0xc9, 0x6c, 0xbe, 0x41, 0xf4, 0xd7, 0x4d, 0x01, 0xf0, 0x37,
            });
            try testArgs(@Vector(32, u8), .{
                0x5f, 0x61, 0x34, 0xe8, 0x37, 0x12, 0xba, 0x5a, 0x85, 0xf3, 0x3e, 0xa2, 0x0f, 0xd0, 0x65, 0xae,
                0xed, 0xf5, 0xe8, 0x65, 0x61, 0x28, 0x4a, 0x27, 0x2e, 0x01, 0x40, 0x8c, 0xe3, 0x36, 0x5d, 0xb6,
            });
            try testArgs(@Vector(64, u8), .{
                0xb0, 0x19, 0x5c, 0xc2, 0x3b, 0x16, 0x70, 0xad, 0x26, 0x45, 0xf2, 0xe1, 0x4f, 0x0f, 0x01, 0x72,
                0x7f, 0x1f, 0x07, 0x9e, 0xee, 0x9b, 0xb3, 0x38, 0x50, 0xf3, 0x56, 0x73, 0xd0, 0xd1, 0xee, 0xe3,
                0xeb, 0xf3, 0x1b, 0xe0, 0x77, 0x78, 0x75, 0xc6, 0x19, 0xe4, 0x69, 0xaa, 0x73, 0x08, 0xcd, 0x0c,
                0xf9, 0xed, 0x94, 0xf8, 0x79, 0x86, 0x63, 0x31, 0xbf, 0xd1, 0xe3, 0x17, 0x2b, 0xb9, 0xa1, 0x72,
            });
            try testArgs(@Vector(128, u8), .{
                0x2e, 0x93, 0x87, 0x09, 0x4f, 0x68, 0x14, 0xab, 0x3f, 0x04, 0x86, 0xc1, 0x95, 0xe8, 0x74, 0x11,
                0x57, 0x25, 0xe1, 0x88, 0xc0, 0x96, 0x33, 0x99, 0x15, 0x86, 0x2c, 0x84, 0x2e, 0xd7, 0x57, 0x21,
                0xd3, 0x18, 0xd5, 0x0e, 0xb4, 0x60, 0xe2, 0x08, 0xce, 0xbc, 0xd5, 0x4d, 0x8f, 0x59, 0x01, 0x67,
                0x71, 0x0a, 0x74, 0x48, 0xef, 0x39, 0x49, 0x7e, 0xa8, 0x39, 0x34, 0x75, 0x95, 0x3b, 0x38, 0xea,
                0x60, 0xd7, 0xed, 0x8f, 0xbb, 0xc0, 0x7d, 0xc2, 0x79, 0x2d, 0xbf, 0xa5, 0x64, 0xf4, 0x09, 0x86,
                0xfb, 0x29, 0xfe, 0xc7, 0xff, 0x62, 0x1a, 0x6f, 0xf8, 0xbd, 0xfe, 0xa4, 0xac, 0x24, 0xcf, 0x56,
                0x82, 0x69, 0x81, 0x0d, 0xc1, 0x51, 0x8d, 0x85, 0xf4, 0x00, 0xe7, 0x25, 0xab, 0xa5, 0x33, 0x45,
                0x66, 0x2e, 0x33, 0xc8, 0xf3, 0x35, 0x16, 0x7d, 0x1f, 0xc9, 0xf7, 0x44, 0xab, 0x66, 0x28, 0x0d,
            });

            try testArgs(@Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u9), .{ 0, 1, 1 << 8 });

            try testArgs(@Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u15), .{ 0, 1, 1 << 14 });

            try testArgs(@Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(1, i16), .{
                -0x015a,
            });
            try testArgs(@Vector(2, i16), .{
                -0x1c2f, 0x5ce8,
            });
            try testArgs(@Vector(4, i16), .{
                0x1212, 0x5bfc, -0x20ea, 0x0993,
            });
            try testArgs(@Vector(8, i16), .{
                0x4d55, -0x0dfb, -0x7921, 0x7e20, 0x74a5, -0x7371, -0x08e0, 0x7f23,
            });
            try testArgs(@Vector(16, i16), .{
                0x2354, -0x048a, -0x3ef9, 0x29d4, 0x4e5e, -0x3da9, -0x0cc4, -0x0377,
                0x4d44, 0x4384,  -0x1e46, 0x0bf1, 0x3151, -0x57c6, -0x367e, -0x7ae5,
            });
            try testArgs(@Vector(32, i16), .{
                0x5b5a, -0x54c4, -0x2089, -0x448d, 0x38e8,  -0x36a5, -0x0a8f, 0x06e0,
                0x09d9, 0x3877,  0x33c8,  0x5d3a,  0x018b,  0x29c9,  0x6f59,  -0x4078,
                0x6be4, -0x249e, 0x43b3,  -0x0389, 0x545e,  0x6ed7,  0x6636,  0x587d,
                0x55b0, -0x608b, 0x72e0,  0x4dfd,  -0x051d, 0x7433,  -0x7fc2, 0x2de3,
            });
            try testArgs(@Vector(64, i16), .{
                0x7834,  -0x43f9, -0x1cb3, -0x05f2, 0x25b5,  0x55f2,  0x4cfb,  -0x58bb,
                0x7292,  -0x082e, -0x5a6e, 0x1fc8,  -0x1f49, 0x7e3c,  0x4aa5,  -0x617e,
                0x2fab,  -0x2b96, 0x7474,  -0x6644, -0x5484, -0x278e, -0x6a0e, -0x5210,
                0x1adf,  -0x2799, 0x61e0,  -0x733c, -0x6bcc, -0x6fe2, -0x4e91, 0x5d01,
                0x3745,  0x24eb,  0x6c89,  0x4a94,  -0x7339, 0x4907,  -0x4f8f, -0x7e39,
                0x1a32,  0x65ca,  -0x6c27, -0x3269, 0x107b,  0x1c53,  -0x5529, 0x5232,
                -0x26ec, 0x4442,  -0x63f5, -0x174a, 0x3033,  -0x7363, 0x58be,  0x239f,
                0x7f7b,  -0x437d, -0x6df6, 0x0a7b,  0x3faa,  -0x1d75, -0x7426, 0x1274,
            });

            try testArgs(@Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(1, u16), .{
                0x4da6,
            });
            try testArgs(@Vector(2, u16), .{
                0x04d7, 0x50c6,
            });
            try testArgs(@Vector(4, u16), .{
                0x4c06, 0xd71f, 0x4d8f, 0xe0a4,
            });
            try testArgs(@Vector(8, u16), .{
                0xee9a, 0x881d, 0x31fb, 0xd3f7, 0x2c74, 0x6949, 0x4e04, 0x53d7,
            });
            try testArgs(@Vector(16, u16), .{
                0xeafe, 0x9a7b, 0x0d6f, 0x18cb, 0xaf8f, 0x8ee4, 0xa47e, 0xd39a,
                0x6572, 0x9c53, 0xf36e, 0x982e, 0x41c1, 0x8682, 0xf5dc, 0x7e01,
            });
            try testArgs(@Vector(32, u16), .{
                0xdfb3, 0x7de6, 0xd9ed, 0xb42e, 0x95ac, 0x9b5b, 0x0422, 0xdfcd,
                0x6196, 0x4dbe, 0x1818, 0x8816, 0x75e7, 0xc9b0, 0x92f7, 0x1f71,
                0xe584, 0x576c, 0x043a, 0x0f31, 0xfc4c, 0x2c87, 0x6b02, 0x0229,
                0x25b7, 0x53cd, 0x9bab, 0x866b, 0x9008, 0xf0f3, 0xeb21, 0x88e2,
            });
            try testArgs(@Vector(64, u16), .{
                0x084c, 0x445f, 0xce89, 0xd3ee, 0xb399, 0x315d, 0x8ef8, 0x4f6f,
                0xf9af, 0xcbc4, 0x0332, 0xcd55, 0xa4dc, 0xbc38, 0x6e33, 0x8ead,
                0xd15a, 0x5057, 0x58ef, 0x657a, 0xe9f0, 0x1418, 0x2b62, 0x3387,
                0x1c15, 0x04e1, 0x0276, 0x3783, 0xad9c, 0xea9a, 0x0e5e, 0xe803,
                0x2ee7, 0x0cf1, 0x30f1, 0xb12a, 0x381b, 0x353d, 0xf637, 0xf853,
                0x2ac1, 0x7ce8, 0x6a50, 0xcbb8, 0xc9b8, 0x9b25, 0xd1e9, 0xeff0,
                0xc0a2, 0x8e51, 0xde7a, 0x4e58, 0x5685, 0xeb3f, 0xd29b, 0x66ed,
                0x3dd5, 0xcb59, 0x6003, 0xf710, 0x943a, 0x7276, 0xe547, 0xe48f,
            });

            try testArgs(@Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u17), .{ 0, 1, 1 << 16 });

            try testArgs(@Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u31), .{ 0, 1, 1 << 30 });

            try testArgs(@Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(1, i32), .{
                -0x27f49dce,
            });
            try testArgs(@Vector(2, i32), .{
                0x24641ec7, 0x436c5bd2,
            });
            try testArgs(@Vector(4, i32), .{
                0x59e5eff1, -0x46b5b8db, -0x1029efa7, -0x1937fe73,
            });
            try testArgs(@Vector(8, i32), .{
                0x0ca01401,  -0x46b2bc0c, 0x51e5dee7, -0x74edfde8,
                -0x0ab09a6a, -0x5a51a88b, 0x18c28bc2, 0x63d79966,
            });
            try testArgs(@Vector(16, i32), .{
                0x3900e6c8, 0x2408c2bb, 0x5e01bc6e,  -0x0eb8c400,
                0x4c0dc6c2, 0x6c75e7f5, -0x66632ca8, 0x0e978daf,
                0x61ffe725, 0x720253e4, -0x6f6c38c1, -0x3302e60a,
                0x43f53c92, 0x5a3c1075, 0x7044a110,  0x18e41ad8,
            });
            try testArgs(@Vector(32, i32), .{
                0x3a5c2b01,  0x2a52d9fa,  -0x5843fc47, 0x6c493c7d,
                -0x47937cb1, -0x3ad95ec4, 0x71cf5e7b,  -0x3b6719c2,
                0x06bace17,  -0x6ccda5ed, 0x42b9ed04,  0x6be2b287,
                -0x7cf56523, -0x3c98e2e4, 0x1e7db6c0,  -0x7e668ad2,
                -0x6c245ecf, -0x09842450, -0x403a4335, -0x7a68e9b7,
                0x0036cf57,  -0x251edb4e, -0x67ec3abf, -0x183f0333,
                -0x4b46723c, -0x1e5383d6, 0x188c1de3,  0x400b3648,
                -0x4b21d9d3, 0x61635257,  0x179eb187,  0x31cd8376,
            });

            try testArgs(@Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(1, u32), .{
                0x17e2805c,
            });
            try testArgs(@Vector(2, u32), .{
                0xdb6aadc5, 0xb1ff3754,
            });
            try testArgs(@Vector(4, u32), .{
                0xf7897b31, 0x342e1af9, 0x190fd76b, 0x283b5374,
            });
            try testArgs(@Vector(8, u32), .{
                0x81a0bd16, 0xc55da94e, 0x910f7e7c, 0x078d5ef7,
                0x0bdb1e4a, 0xf1a96e99, 0xcdd729b5, 0xe6966a1c,
            });
            try testArgs(@Vector(16, u32), .{
                0xfee812db, 0x29eacbed, 0xaed48136, 0x3053de13,
                0xbbda20df, 0x6faa274a, 0xe0b5ec3a, 0x1878b0dc,
                0x98204475, 0x810d8d05, 0x1e6996b6, 0xc543826a,
                0x53b47d8c, 0xc72c3142, 0x12f7e1f9, 0xf6782e54,
            });
            try testArgs(@Vector(32, u32), .{
                0xf0cf30d3, 0xe3c587b8, 0xcee44739, 0xe4a0bd72,
                0x41d44cce, 0x6d7c4259, 0xd85580a5, 0xec4b02d7,
                0xa366483d, 0x2d7b59d4, 0xe9c0ace4, 0x82cb441c,
                0xa23958ba, 0x04a70148, 0x3f0d20a3, 0xf9e21e37,
                0x009fce8b, 0x4a34a229, 0xf09c35cf, 0xc0977d4d,
                0xcc4d4647, 0xa30f1363, 0x27a65b14, 0xe572c785,
                0x8f42e320, 0x2b2cdeca, 0x11205bd4, 0x739d26aa,
                0xcbcc2df0, 0x5f7a3649, 0xbde1b7aa, 0x180a169f,
            });

            try testArgs(@Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u33), .{ 0, 1, 1 << 32 });

            try testArgs(@Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u63), .{ 0, 1, 1 << 62 });

            try testArgs(@Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(1, i64), .{
                0x29113011488d8b65,
            });
            try testArgs(@Vector(2, i64), .{
                -0x3f865dcdfd831d03, -0x35512d15095445d6,
            });
            try testArgs(@Vector(4, i64), .{
                0x6f37a9484440251e, 0x2757e5e2b77e6ef3,
                0x4903a91bd2993d0b, 0x162244ba22371f62,
            });
            try testArgs(@Vector(8, i64), .{
                -0x46e2340c765175c1, -0x031ee2297e6cc8b3,
                -0x2627434d4b4fb796, 0x525e1ef31b6daa46,
                0x72d8eaaea07fa5ea,  0x2a8c0c36da019448,
                -0x5419ebf5cd514cde, -0x618c56a881057ac4,
            });
            try testArgs(@Vector(16, i64), .{
                0x36b4a703d084c774,  0x07a500f0d603a4d5,
                -0x27387989d2450cdd, 0x02073880984d74c8,
                -0x18d1593e36724417, -0x79df283cc6f403d8,
                0x36838a7c54da5f2b,  -0x2bf76c1666a1b768,
                -0x6ace0d64a2757edc, 0x41442e9979a0ab64,
                0x002612bfdf419826,  0x1128ba5648d22fe8,
                0x49b0f67e0abb8f3b,  0x6bf3e9ac37f73cf3,
                -0x5c89f516258c7e77, 0x6b345f04e60d2e56,
            });

            try testArgs(@Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(1, u64), .{
                0x7d2e439abb0edba7,
            });
            try testArgs(@Vector(2, u64), .{
                0x3749ee5a2d237b9f, 0x6d8f4c3e1378f389,
            });
            try testArgs(@Vector(4, u64), .{
                0x03c127040e10d52b, 0xa86fe019072e27eb,
                0x0a554a47b709cdba, 0xf4342cc597e196c3,
            });
            try testArgs(@Vector(8, u64), .{
                0xea455c104375a055, 0x5c35d9d945edb2fa,
                0xc11b73d9d9d546fc, 0x2a9d63aae838dd5b,
                0xed6603f1f5d574b3, 0x2f37b354c81c1e56,
                0xbe7f5e2476bc76bd, 0xb0c88eacfffa9a8f,
            });
            try testArgs(@Vector(16, u64), .{
                0x2258fc04b31f8dbe, 0x3a2e5483003a10d8,
                0xebf24b31c0460510, 0x15d5b4c09b53ffa5,
                0x05abf6e744b17cc6, 0x9747b483f2d159fe,
                0x4616d8b2c8673125, 0x8ae3f91d422447eb,
                0x18da2f101a9e9776, 0x77a1197fb0441007,
                0x4ba480c8ec2dd10b, 0xeb99b9c0a1725278,
                0xd9d0acc5084ecdf0, 0xa0a23317fff4f515,
                0x0901c59a9a6a408b, 0x7c77ca72e25df033,
            });

            try testArgs(@Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u65), .{ 0, 1, 1 << 64 });

            try testArgs(@Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u127), .{ 0, 1, 1 << 126 });

            try testArgs(@Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(1, i128), .{
                -0x2b0b1462b44785f39d1b7d763ec7bdb2,
            });
            try testArgs(@Vector(2, i128), .{
                -0x2faebe898a6fe60fbc6aadc3623431b7,
                0x5e596259e7b2588860d2b470ba751ace,
            });
            try testArgs(@Vector(4, i128), .{
                -0x624cb7e74cf789c06121809a3a5b51ba,
                0x23af4553d4d64672795c2b949635426f,
                -0x0b598b1f94876757fb13f2198e902b13,
                0x1daf732f50654d8211d464fda4fc030c,
            });
            try testArgs(@Vector(8, i128), .{
                -0x03c7df38daee9bc9a2c659a1a124ef10,
                0x657a590c91905c4021c28b0d6e42304a,
                -0x3f5176206dadc974d10e6fcbd67f3d29,
                0x066310ace384b1bc3549c71113b96b8a,
                -0x6c0201f66583206fcea7b7fe11889644,
                -0x5cc4d2a368002b380b25415be83f8218,
                0x11156c91b97a6a93427009efebcb2c31,
                -0x4221b5249ed0686c2ff2d5cab9f1c362,
            });

            try testArgs(@Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(1, u128), .{
                0x809f29e7fbafadc01145e1732590e7d9,
            });
            try testArgs(@Vector(2, u128), .{
                0x5150ac3438aacd0d51132cc2723b2995,
                0x151be9c47ad29cf719cf8358dd40165c,
            });
            try testArgs(@Vector(4, u128), .{
                0x4bae22df929f2f7cb9bd84deaad3e7a8,
                0x1ed46b2d6e1f3569f56b2ac33d8bc1cb,
                0xae93ea459d2ccfd5fb794e6d5c31aabb,
                0xb1177136acf099f550b70949ac202ec4,
            });
            try testArgs(@Vector(8, u128), .{
                0x7cd78db6baed6bfdf8c5265136c4e0fd,
                0xa41b8984c6bbde84640068194b7eba98,
                0xd33102778f2ae1a48d1e9bf8801bbbf0,
                0x0d59f6de003513a60055c86cbce2c200,
                0x825579d90012afddfbf04851c0748561,
                0xc2647c885e9d6f0ee1f5fac5da8ef7f5,
                0xcb4bbc1f81aa8ee68aa4dc140745687b,
                0x4ff10f914f74b46c694407f5bf7c7836,
            });

            try testArgs(@Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u129), .{ 0, 1, 1 << 128 });

            try testArgs(@Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u191), .{ 0, 1, 1 << 190 });

            try testArgs(@Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(1, i192), .{
                0x0206223e53631dfaf431066cf5ac30dd203bb8c7baa0cec7,
            });
            try testArgs(@Vector(2, i192), .{
                0x187a65fa29d1981dacf927e6a8e435481cfdcba6b63b781b,
                -0x0f53cb01d7662de0d19fa0b250e5bbc6edf7d3dd152f0dc3,
            });
            try testArgs(@Vector(4, i192), .{
                -0x3a456cd0eab663b34d5b6ad15933a31623aacb913adb8e41,
                -0x03376d57e9c495ac4ea623e1bf427ae22dcef26e4833da33,
                -0x28a90cfee819450e3000f3f2694a7dba2c02311996e01073,
                0x46c6cae4281780acd6a0322c3f4f8b63c3741da31b20a3cd,
            });

            try testArgs(@Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(1, u192), .{
                0xe7baafcb9781626a77571b0539b9471a60c97d6c02106c8b,
            });
            try testArgs(@Vector(2, u192), .{
                0xbc9510913ed09e2c2aa50ffab9f1bc7b303a87f36e232a83,
                0x1f37bee446d7712d1ad457c47a66812cb926198d052aee65,
            });
            try testArgs(@Vector(4, u192), .{
                0xdca6a7cfc19c69efc34022062a8ca36f2569ab3dce001202,
                0xd25a4529e621c9084181fdb6917c6a32eccc58b63601b35d,
                0x0a258afd6debbaf8c158f1caa61fed63b31871d13f51b43d,
                0x6b40a178674fcb82c623ac322f851623d5e993dac97a219a,
            });

            try testArgs(@Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u193), .{ 0, 1, 1 << 192 });

            try testArgs(@Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u255), .{ 0, 1, 1 << 254 });

            try testArgs(@Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(1, i256), .{
                0x59a12bff854679d9b3c6d1d195333d9f748dd1e2a7ad28f24f611a208bf91ed3,
            });
            try testArgs(@Vector(2, i256), .{
                0x6b266e98bd5e7e66ba90f2e1cb2ff555ac755efdbe0946313660c58b46c589bb,
                -0x4ab426d26f53253ae3b2fb412d9649fc8071db22605e528f918b9a3ee9d2a832,
            });
            try testArgs(@Vector(4, i256), .{
                -0x3a64f67fddd0859c0f3b063fc12b13b1865447b87d1740de51358421f50553b5,
                -0x7c364fc0218f1cab29425b1a4c9cbdbf0c676375bee8079b135ce40de3557c0b,
                0x368d25dc3eab1b00decd18679b29b7f4d95314161bd3ee687f2896e8cd525311,
                -0x6d9aacd172a363bf2d53ea497c289fd35e62c2484329c208e10a91b4cea88111,
            });

            try testArgs(@Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(1, u256), .{
                0x230413bb481fa3a997796acf282010c560d1942e7339fd584a0f15a90c83fbda,
            });
            try testArgs(@Vector(2, u256), .{
                0x3ad569f8d91fdbc9da8ec0e933565919f2feb90b996c90c352b461aa0908e62d,
                0x0f109696d64647983f1f757042515510729ad1350e862cbf38cb73b5cf99f0f7,
            });
            try testArgs(@Vector(4, u256), .{
                0x1717c6ded4ac6de282d59f75f068da47d5a47a30f2c5053d2d59e715f9d28b97,
                0x3087189ce7540e2e0028b80af571ebc6353a00b2917f243a869ed29ecca0adaa,
                0x1507c6a9d104684bf503cdb08841cf91adab4644306bd67aafff5326604833ce,
                0x857e134ff9179733c871295b25f824bd3eb562977bad30890964fa0cdc15bb07,
            });

            try testArgs(@Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u257), .{ 0, 1, 1 << 256 });

            try testArgs(@Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u511), .{ 0, 1, 1 << 510 });

            try testArgs(@Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(1, i512), .{
                -0x235b5d838cdf67b9eb6d7eeb518fb63cff402a74c687927feb363b5040556b8d32c55e565cc2fe33cb4dcc37e8fd1c92989522c11b6c186d11400d17e40d35b5,
            });
            try testArgs(@Vector(2, i512), .{
                -0x5f5ff44fec38adc4c9c8bc8de00acf01fcc62bc55d07033f4e788d4f3825382e1e39f6bd69dff328eec9a89486ebaaaffd9ab69d28eb7d952be4ef250cff6de1,
                -0x403e0fd866e1598ad928ecd234005debd527483375f5e7e79eee3a129868354acb5b74e42de9f297f81062d04ea41adc158e542ab04770dd039d527cffb81845,
            });

            try testArgs(@Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(1, u512), .{
                0xa3ff51a609f1370e5eeb96b05169bf7469e465cf76ac5b4ea8ffd166c1ba3cd94f2dedf0d647a1fe424f3a06e6d7940f03e257f28100970b00bd5528c52b9ae6,
            });
            try testArgs(@Vector(2, u512), .{
                0xc6d43cd46ae31ab71f9468a895c83bf17516c6b2f1c9b04b9aa113bf7fe1b789eb7d95fcf951f12a9a6f2124589551efdd8c00f528b366a7bfb852faf8f3da53,
                0xc9099d2bdf8d1a0d30485ec6db4a24cbc0d89a863de30e18313ee1d66f71dd2d26235caaa703286cf4a2b51e1a12ef96d2d944c66c0bd3f0d72dd4cf0fc8100e,
            });

            try testArgs(@Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u513), .{ 0, 1, 1 << 512 });

            try testArgs(@Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u1023), .{ 0, 1, 1 << 1022 });

            try testArgs(@Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(1, i1024), .{
                0x10eee350e115375812126750b24255ca76fdee619b64261c354af58bd4a29af6e2448ccda4d84e1b2fbf76d3710cf1b5e62b1360c3b63e104d0755fa264d6c171f8f7a3292d7859b08a5dff60e9ad8ba9dcdd7e6098eb70be7a27a0cbcc6480661330c21299b2960fac954ee4480f3a2cc1ca5a492e1e75084c079ba701cd7ab,
            });

            try testArgs(@Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(1, u1024), .{
                0xc6cfaa6571139552e1f067402dfc131d9b9a58aafda97198a78764b05138fb68cf26f085b7652f3d5ae0e56aa21732f296a581bb411d4a73795c213de793489fa49b173b9f5c089aa6295ff1fcdc14d491a05035b45d08fc35cd67a83d887a02b8db512f07518132e0ba56533c7d6fbe958255eddf5649bd8aba288c0dd84a25,
            });

            try testArgs(@Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u1025), .{ 0, 1, 1 << 1024 });
        }
        fn testFloatVectorTypes() !void {
            try testArgs(@Vector(1, f16), undefined);
            try testArgs(@Vector(2, f16), undefined);
            try testArgs(@Vector(4, f16), undefined);
            try testArgs(@Vector(8, f16), undefined);
            try testArgs(@Vector(16, f16), undefined);
            try testArgs(@Vector(32, f16), undefined);
            try testArgs(@Vector(64, f16), undefined);

            try testArgs(@Vector(1, f32), undefined);
            try testArgs(@Vector(2, f32), undefined);
            try testArgs(@Vector(4, f32), undefined);
            try testArgs(@Vector(8, f32), undefined);
            try testArgs(@Vector(16, f32), undefined);
            try testArgs(@Vector(32, f32), undefined);

            try testArgs(@Vector(1, f64), undefined);
            try testArgs(@Vector(2, f64), undefined);
            try testArgs(@Vector(4, f64), undefined);
            try testArgs(@Vector(8, f64), undefined);
            try testArgs(@Vector(16, f64), undefined);

            try testArgs(@Vector(1, f80), undefined);
            try testArgs(@Vector(2, f80), undefined);
            try testArgs(@Vector(4, f80), undefined);
            try testArgs(@Vector(8, f80), undefined);

            try testArgs(@Vector(1, f128), undefined);
            try testArgs(@Vector(2, f128), undefined);
            try testArgs(@Vector(4, f128), undefined);
            try testArgs(@Vector(8, f128), undefined);
        }
        fn testFloatVectors() !void {
            try testArgs(@Vector(1, f16), .{
                -0x1.17cp-12,
            });
            try testArgs(@Vector(2, f16), .{
                0x1.47cp9, 0x1.3acp9,
            });
            try testArgs(@Vector(4, f16), .{
                0x1.ab4p0, -0x1.7fcp-7, -0x1.1cp0, -0x1.f14p12,
            });
            try testArgs(@Vector(8, f16), .{
                -0x1.8d8p8, 0x1.83p10, -0x1.5ap-1, -0x1.d78p13, -0x1.608p12, 0x1.e8p-9, -0x1.688p-10, -0x1.738p9,
            });
            try testArgs(@Vector(16, f16), .{
                0x1.da8p-1, -0x1.ed4p-10, -0x1.dc8p1,  0x1.b78p-14, nan(f16),    0x1.9d8p8,   nan(f16),     0x1.d5p13,
                -0x1.2dp13, 0x1.6c4p12,   0x1.a9cp-11, -0x1.0ecp8,  0x0.4ccp-14, -0x1.0a8p-6, -0x1.5bcp-14, 0x1.6d8p-9,
            });
            try testArgs(@Vector(32, f16), .{
                0x1.d5cp-6,  -0x1.a98p5,  0x1.49cp5,   -0x1.e4p-1,  -0x1.21p-13, -0x1.c94p-1, -0x1.adcp-5, -0x1.524p-1,
                -0x1.0d8p-3, -0x1.5c4p-2, 0x1.f84p-2,  0x1.664p1,   -0x1.f64p13, -0x1.bf4p4,  -0x1.4b8p0,  -0x0.f64p-14,
                -0x1.3f8p1,  0x1.098p2,   -0x1.a44p8,  0x1.048p13,  0x1.fd4p-11, 0x1.18p-9,   -0x1.504p2,  0x1.d04p7,
                -nan(f16),   0x1.a94p2,   0x0.5e8p-14, -0x1.7acp-7, 0x1.4c8p-3,  0x1.518p-4,  nan(f16),    0x1.8f8p10,
            });
            try testArgs(@Vector(64, f16), .{
                -0x1.c2p2,   0x0.2fcp-14,  0x1.de8p0,    -0x1.714p2,   0x1.f9p-7,    -0x1.11cp-13, -0x1.558p10, -0x1.2acp-7,
                0x1.348p14,  0x1.2dcp7,    -0x1.8acp-12, -0x1.2cp2,    0x1.868p1,    -0x1.1f8p-14, 0x1.638p7,   -0x1.734p-5,
                0x0.b98p-14, -0x1.7f4p-12, -0x1.38cp15,  0x1.50cp15,   0x1.91cp8,    0x1.cb4p-1,   0x1.fc4p-13, 0x1.9a4p0,
                0x1.18p-4,   0x1.60cp10,   0x1.6fp-12,   0x1.b48p6,    0x1.37cp-11,  0x1.424p7,    0x1.44cp13,  0x1.aep5,
                0x1.968p14,  0x1.e8p13,    -0x1.bp2,     -0x1.644p5,   0x1.de4p-8,   -0x1.5b4p-14, -0x1.4ap1,   -0x1.868p9,
                -0x1.d14p0,  0x1.d7cp15,   0x1.3c8p14,   0x1.2ccp-14,  -0x1.ee4p8,   0x1.49p-3,    0x1.35cp12,  0x1.d34p6,
                0x1.7acp3,   -0x1.fa4p2,   0x1.7b4p13,   -0x1.cf4p-12, -0x1.ebcp-10, -0x1.5p-3,    0x1.4bp-6,   0x1.83p12,
                -0x1.f9cp-8, -0x1.43p-8,   -0x1.99p-1,   -0x1.dacp3,   -0x1.728p-4,  -0x1.03cp4,   0x1.604p-2,  -0x1.0ep13,
            });

            try testArgs(@Vector(1, f32), .{
                -0x1.17cp-12,
            });
            try testArgs(@Vector(2, f32), .{
                -0x1.a3123ap90, -0x1.4a2ec6p-54,
            });
            try testArgs(@Vector(4, f32), .{
                -0x1.8a41p77, -0x1.7c54e2p-61, -0x1.498556p-41, 0x1.d77c22p-20,
            });
            try testArgs(@Vector(8, f32), .{
                0x1.943da4p-86, 0x1.528792p95,  -0x1.9c9bfap-26, -0x1.8df936p-90,
                -0x1.6a70cep56, 0x1.626638p-48, 0x1.7bb2bap-57,  -0x1.ac5104p94,
            });
            try testArgs(@Vector(16, f32), .{
                0x1.157044p115, -0x1.416c04p-111, 0x1.a8f164p-104, 0x1.9b6678p84,
                -0x1.9d065cp9,  -0x1.e8c4b4p126,  -0x1.ddb968p84,  -0x1.fec8c8p74,
                0x1.64ffb2p59,  0x1.548922p20,    0x1.7270fcp22,   -0x1.abac68p33,
                0x1.faabfp33,   -0x1.8aee82p55,   0x1.1bf8fp75,    0x1.33c46ap-66,
            });
            try testArgs(@Vector(32, f32), .{
                -0x1.039b68p37,   -0x1.34de4ap-74, -0x1.05d78ap-76, -0x1.be0f5ap-47,
                0x1.032204p-38,   0x1.ef8e2ap-78,  -0x1.b013ecp-80, 0x1.71fe4cp99,
                0x1.abdadap-14,   0x1.56a9a8p-48,  -0x1.8bbd7ep9,   0x1.edd308p-72,
                -0x1.92fafcp-121, -0x1.50812p19,   0x1.f4ddc4p28,   -0x1.6f0b12p-50,
                -0x1.12ab02p127,  0x1.24df48p21,   -0x1.993c3p-14,  -0x1.4cc476p-112,
                0x1.13d9a8p-40,   0x1.a6e652p-9,   -0x1.9c730cp-21, -0x1.a75aaap-70,
                -0x1.39e632p-111, 0x1.8e8da8p-45,  0x1.b5652cp31,   0x1.258366p44,
                0x1.d473aap92,    -0x1.951b64p9,   0x1.542edp15,    -0x0.f6222ap-126,
            });

            try testArgs(@Vector(1, f64), .{
                -0x1.0114613df6f97p816,
            });
            try testArgs(@Vector(2, f64), .{
                -0x1.8404dad72003cp720, -0x1.6b14b40bcf3b7p-176,
            });
            try testArgs(@Vector(4, f64), .{
                -0x1.04e1acbfddd9cp681, -0x1.ed553cc056da7p-749,
                0x1.3d3f703a0c893p-905, 0x1.0b35633fa78fp691,
            });
            try testArgs(@Vector(8, f64), .{
                -0x1.901a2a60f0562p-301, -0x1.2516175ad61ecp-447,
                0x1.e7b12124846bfp564,   0x1.9291384bd7259p209,
                -0x1.a7bf62f803c98p900,  0x1.4e2e26257bb3p987,
                -0x1.413ca9a32d894p811,  0x1.61b1dd9432e95p479,
            });
            try testArgs(@Vector(16, f64), .{
                -0x1.8fc7286d95f54p-235,  -0x1.796a7ea8372b6p-837,
                -0x1.8c0f930539acbp-98,   -0x1.ec80dfbf0b931p-430,
                -0x1.e3d80c640652fp-1019, 0x1.8241238fb542fp161,
                -0x1.e1f1a79d50263p137,   -0x1.9ac5cb2771c28p-791,
                0x1.4d8f00fe881e7p-401,   -0x1.87fbd7bfd99d7p346,
                -0x1.a8a7cc575335ep1017,  0x1.37bb88dc3fd8bp-355,
                0x1.9d53d346c0e65p929,    -0x1.bbae3d0229c34p289,
                -0x1.cb8ef994d5ce5p25,    0x1.ba20af512616ap50,
            });

            try testArgs(@Vector(1, f80), .{
                -0x1.a2e9410a7dfedabp-2324,
            });
            try testArgs(@Vector(2, f80), .{
                -0x1.a2e9410a7dfedabp-2324,
                0x1.2b17da3b9746885p-8665,
            });
            try testArgs(@Vector(4, f80), .{
                -0x1.c488fedb7ab646cep-13007,
                0x1.e914deaccaa50016p2073,
                -0x1.d1c7ae8ec3c9df86p10642,
                -0x1.2da1658f337fa01p9893,
            });
            try testArgs(@Vector(8, f80), .{
                -0x1.bed8a74c43750656p890,
                -0x1.7bf57f38004ac976p8481,
                -0x1.9cdc10ac0657d328p7884,
                0x1.c86f61883da149fp12293,
                -0x1.528d6957df6bfdd8p14125,
                -0x1.5ebb4006d0243bfep14530,
                -0x1.94b9b18636d12402p-1845,
                -0x1.25439a6d68add188p5962,
            });

            try testArgs(@Vector(1, f128), .{
                -0x1.d1e6fc3b1e66632e7b79051a47dap14300,
            });
            try testArgs(@Vector(2, f128), .{
                0x1.84b3ac8ffe5893b2c6af8d68de9dp-83,
                -0x1.438ca2c8a0d8e3ee9062d351c46ep-10235,
            });
            try testArgs(@Vector(4, f128), .{
                0x1.04eb03882d4fd1b090e714d3e5ep806,
                -0x1.4082b29f7c26e701764c915642ffp-6182,
                -0x1.b6f1e8565e5040415110f18b519ap13383,
                0x1.1c29f8c162cead9061c5797ea15ap11957,
            });
            try testArgs(@Vector(8, f128), .{
                -0x1.53d7f00cd204d80e5ff5bb665773p11218,
                -0x1.4daa1c81cffe28e8fa5cd703c287p2362,
                -0x1.cc6a71c3ad4560871efdbd025cd7p-8116,
                -0x1.87f8553cf8772fb6b78e7df3e3bap14523,
                -0x1.14b6880f6678f86dfb543dde1c6ep2105,
                0x1.9d2d4398414da9d857e76e8fd7ccp-13668,
                0x1.a37f07af240ded458d103c022064p-1158,
                0x1.425d53e6bd6070b847e5da1ed593p1394,
            });
        }
    };
}

fn cast(comptime op: anytype, comptime opts: struct { compare: Compare = .relaxed }) type {
    return struct {
        // noinline so that `mem_arg` is on the stack
        noinline fn testArgKinds(
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            comptime Result: type,
            comptime Type: type,
            comptime imm_arg: Type,
            mem_arg: Type,
        ) !void {
            const expected = comptime op(Result, Type, imm_arg, imm_arg);
            var reg_arg = mem_arg;
            _ = .{&reg_arg};
            try checkExpected(expected, op(Result, Type, reg_arg, imm_arg), opts.compare);
            try checkExpected(expected, op(Result, Type, mem_arg, imm_arg), opts.compare);
            try checkExpected(expected, op(Result, Type, imm_arg, imm_arg), opts.compare);
        }
        // noinline for a more helpful stack trace
        noinline fn testArgs(comptime Result: type, comptime Type: type, comptime imm_arg: Type) !void {
            try testArgKinds(
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                Result,
                Type,
                imm_arg,
                imm_arg,
            );
        }
        fn testSameSignednessInts() !void {
            try testArgs(i8, i1, -1);
            try testArgs(i8, i1, 0);
            try testArgs(i16, i1, -1);
            try testArgs(i16, i1, 0);
            try testArgs(i32, i1, -1);
            try testArgs(i32, i1, 0);
            try testArgs(i64, i1, -1);
            try testArgs(i64, i1, 0);
            try testArgs(i128, i1, -1);
            try testArgs(i128, i1, 0);
            try testArgs(i256, i1, -1);
            try testArgs(i256, i1, 0);
            try testArgs(i512, i1, -1);
            try testArgs(i512, i1, 0);
            try testArgs(i1024, i1, -1);
            try testArgs(i1024, i1, 0);
            try testArgs(u8, u1, 0);
            try testArgs(u8, u1, 1 << 0);
            try testArgs(u16, u1, 0);
            try testArgs(u16, u1, 1 << 0);
            try testArgs(u32, u1, 0);
            try testArgs(u32, u1, 1 << 0);
            try testArgs(u64, u1, 0);
            try testArgs(u64, u1, 1 << 0);
            try testArgs(u128, u1, 0);
            try testArgs(u128, u1, 1 << 0);
            try testArgs(u256, u1, 0);
            try testArgs(u256, u1, 1 << 0);
            try testArgs(u512, u1, 0);
            try testArgs(u512, u1, 1 << 0);
            try testArgs(u1024, u1, 0);
            try testArgs(u1024, u1, 1 << 0);

            try testArgs(i8, i2, -1 << 1);
            try testArgs(i8, i2, -1);
            try testArgs(i8, i2, 0);
            try testArgs(i16, i2, -1 << 1);
            try testArgs(i16, i2, -1);
            try testArgs(i16, i2, 0);
            try testArgs(i32, i2, -1 << 1);
            try testArgs(i32, i2, -1);
            try testArgs(i32, i2, 0);
            try testArgs(i64, i2, -1 << 1);
            try testArgs(i64, i2, -1);
            try testArgs(i64, i2, 0);
            try testArgs(i128, i2, -1 << 1);
            try testArgs(i128, i2, -1);
            try testArgs(i128, i2, 0);
            try testArgs(i256, i2, -1 << 1);
            try testArgs(i256, i2, -1);
            try testArgs(i256, i2, 0);
            try testArgs(i512, i2, -1 << 1);
            try testArgs(i512, i2, -1);
            try testArgs(i512, i2, 0);
            try testArgs(i1024, i2, -1 << 1);
            try testArgs(i1024, i2, -1);
            try testArgs(i1024, i2, 0);
            try testArgs(u8, u2, 0);
            try testArgs(u8, u2, 1 << 0);
            try testArgs(u8, u2, 1 << 1);
            try testArgs(u16, u2, 0);
            try testArgs(u16, u2, 1 << 0);
            try testArgs(u16, u2, 1 << 1);
            try testArgs(u32, u2, 0);
            try testArgs(u32, u2, 1 << 0);
            try testArgs(u32, u2, 1 << 1);
            try testArgs(u64, u2, 0);
            try testArgs(u64, u2, 1 << 0);
            try testArgs(u64, u2, 1 << 1);
            try testArgs(u128, u2, 0);
            try testArgs(u128, u2, 1 << 0);
            try testArgs(u128, u2, 1 << 1);
            try testArgs(u256, u2, 0);
            try testArgs(u256, u2, 1 << 0);
            try testArgs(u256, u2, 1 << 1);
            try testArgs(u512, u2, 0);
            try testArgs(u512, u2, 1 << 0);
            try testArgs(u512, u2, 1 << 1);
            try testArgs(u1024, u2, 0);
            try testArgs(u1024, u2, 1 << 0);
            try testArgs(u1024, u2, 1 << 1);

            try testArgs(i8, i3, -1 << 2);
            try testArgs(i8, i3, -1);
            try testArgs(i8, i3, 0);
            try testArgs(i16, i3, -1 << 2);
            try testArgs(i16, i3, -1);
            try testArgs(i16, i3, 0);
            try testArgs(i32, i3, -1 << 2);
            try testArgs(i32, i3, -1);
            try testArgs(i32, i3, 0);
            try testArgs(i64, i3, -1 << 2);
            try testArgs(i64, i3, -1);
            try testArgs(i64, i3, 0);
            try testArgs(i128, i3, -1 << 2);
            try testArgs(i128, i3, -1);
            try testArgs(i128, i3, 0);
            try testArgs(i256, i3, -1 << 2);
            try testArgs(i256, i3, -1);
            try testArgs(i256, i3, 0);
            try testArgs(i512, i3, -1 << 2);
            try testArgs(i512, i3, -1);
            try testArgs(i512, i3, 0);
            try testArgs(i1024, i3, -1 << 2);
            try testArgs(i1024, i3, -1);
            try testArgs(i1024, i3, 0);
            try testArgs(u8, u3, 0);
            try testArgs(u8, u3, 1 << 0);
            try testArgs(u8, u3, 1 << 2);
            try testArgs(u16, u3, 0);
            try testArgs(u16, u3, 1 << 0);
            try testArgs(u16, u3, 1 << 2);
            try testArgs(u32, u3, 0);
            try testArgs(u32, u3, 1 << 0);
            try testArgs(u32, u3, 1 << 2);
            try testArgs(u64, u3, 0);
            try testArgs(u64, u3, 1 << 0);
            try testArgs(u64, u3, 1 << 2);
            try testArgs(u128, u3, 0);
            try testArgs(u128, u3, 1 << 0);
            try testArgs(u128, u3, 1 << 2);
            try testArgs(u256, u3, 0);
            try testArgs(u256, u3, 1 << 0);
            try testArgs(u256, u3, 1 << 2);
            try testArgs(u512, u3, 0);
            try testArgs(u512, u3, 1 << 0);
            try testArgs(u512, u3, 1 << 2);
            try testArgs(u1024, u3, 0);
            try testArgs(u1024, u3, 1 << 0);
            try testArgs(u1024, u3, 1 << 2);

            try testArgs(i8, i4, -1 << 3);
            try testArgs(i8, i4, -1);
            try testArgs(i8, i4, 0);
            try testArgs(i16, i4, -1 << 3);
            try testArgs(i16, i4, -1);
            try testArgs(i16, i4, 0);
            try testArgs(i32, i4, -1 << 3);
            try testArgs(i32, i4, -1);
            try testArgs(i32, i4, 0);
            try testArgs(i64, i4, -1 << 3);
            try testArgs(i64, i4, -1);
            try testArgs(i64, i4, 0);
            try testArgs(i128, i4, -1 << 3);
            try testArgs(i128, i4, -1);
            try testArgs(i128, i4, 0);
            try testArgs(i256, i4, -1 << 3);
            try testArgs(i256, i4, -1);
            try testArgs(i256, i4, 0);
            try testArgs(i512, i4, -1 << 3);
            try testArgs(i512, i4, -1);
            try testArgs(i512, i4, 0);
            try testArgs(i1024, i4, -1 << 3);
            try testArgs(i1024, i4, -1);
            try testArgs(i1024, i4, 0);
            try testArgs(u8, u4, 0);
            try testArgs(u8, u4, 1 << 0);
            try testArgs(u8, u4, 1 << 3);
            try testArgs(u16, u4, 0);
            try testArgs(u16, u4, 1 << 0);
            try testArgs(u16, u4, 1 << 3);
            try testArgs(u32, u4, 0);
            try testArgs(u32, u4, 1 << 0);
            try testArgs(u32, u4, 1 << 3);
            try testArgs(u64, u4, 0);
            try testArgs(u64, u4, 1 << 0);
            try testArgs(u64, u4, 1 << 3);
            try testArgs(u128, u4, 0);
            try testArgs(u128, u4, 1 << 0);
            try testArgs(u128, u4, 1 << 3);
            try testArgs(u256, u4, 0);
            try testArgs(u256, u4, 1 << 0);
            try testArgs(u256, u4, 1 << 3);
            try testArgs(u512, u4, 0);
            try testArgs(u512, u4, 1 << 0);
            try testArgs(u512, u4, 1 << 3);
            try testArgs(u1024, u4, 0);
            try testArgs(u1024, u4, 1 << 0);
            try testArgs(u1024, u4, 1 << 3);

            try testArgs(i8, i5, -1 << 4);
            try testArgs(i8, i5, -1);
            try testArgs(i8, i5, 0);
            try testArgs(i16, i5, -1 << 4);
            try testArgs(i16, i5, -1);
            try testArgs(i16, i5, 0);
            try testArgs(i32, i5, -1 << 4);
            try testArgs(i32, i5, -1);
            try testArgs(i32, i5, 0);
            try testArgs(i64, i5, -1 << 4);
            try testArgs(i64, i5, -1);
            try testArgs(i64, i5, 0);
            try testArgs(i128, i5, -1 << 4);
            try testArgs(i128, i5, -1);
            try testArgs(i128, i5, 0);
            try testArgs(i256, i5, -1 << 4);
            try testArgs(i256, i5, -1);
            try testArgs(i256, i5, 0);
            try testArgs(i512, i5, -1 << 4);
            try testArgs(i512, i5, -1);
            try testArgs(i512, i5, 0);
            try testArgs(i1024, i5, -1 << 4);
            try testArgs(i1024, i5, -1);
            try testArgs(i1024, i5, 0);
            try testArgs(u8, u5, 0);
            try testArgs(u8, u5, 1 << 0);
            try testArgs(u8, u5, 1 << 4);
            try testArgs(u16, u5, 0);
            try testArgs(u16, u5, 1 << 0);
            try testArgs(u16, u5, 1 << 4);
            try testArgs(u32, u5, 0);
            try testArgs(u32, u5, 1 << 0);
            try testArgs(u32, u5, 1 << 4);
            try testArgs(u64, u5, 0);
            try testArgs(u64, u5, 1 << 0);
            try testArgs(u64, u5, 1 << 4);
            try testArgs(u128, u5, 0);
            try testArgs(u128, u5, 1 << 0);
            try testArgs(u128, u5, 1 << 4);
            try testArgs(u256, u5, 0);
            try testArgs(u256, u5, 1 << 0);
            try testArgs(u256, u5, 1 << 4);
            try testArgs(u512, u5, 0);
            try testArgs(u512, u5, 1 << 0);
            try testArgs(u512, u5, 1 << 4);
            try testArgs(u1024, u5, 0);
            try testArgs(u1024, u5, 1 << 0);
            try testArgs(u1024, u5, 1 << 4);

            try testArgs(i8, i7, -1 << 6);
            try testArgs(i8, i7, -1);
            try testArgs(i8, i7, 0);
            try testArgs(i16, i7, -1 << 6);
            try testArgs(i16, i7, -1);
            try testArgs(i16, i7, 0);
            try testArgs(i32, i7, -1 << 6);
            try testArgs(i32, i7, -1);
            try testArgs(i32, i7, 0);
            try testArgs(i64, i7, -1 << 6);
            try testArgs(i64, i7, -1);
            try testArgs(i64, i7, 0);
            try testArgs(i128, i7, -1 << 6);
            try testArgs(i128, i7, -1);
            try testArgs(i128, i7, 0);
            try testArgs(i256, i7, -1 << 6);
            try testArgs(i256, i7, -1);
            try testArgs(i256, i7, 0);
            try testArgs(i512, i7, -1 << 6);
            try testArgs(i512, i7, -1);
            try testArgs(i512, i7, 0);
            try testArgs(i1024, i7, -1 << 6);
            try testArgs(i1024, i7, -1);
            try testArgs(i1024, i7, 0);
            try testArgs(u8, u7, 0);
            try testArgs(u8, u7, 1 << 0);
            try testArgs(u8, u7, 1 << 6);
            try testArgs(u16, u7, 0);
            try testArgs(u16, u7, 1 << 0);
            try testArgs(u16, u7, 1 << 6);
            try testArgs(u32, u7, 0);
            try testArgs(u32, u7, 1 << 0);
            try testArgs(u32, u7, 1 << 6);
            try testArgs(u64, u7, 0);
            try testArgs(u64, u7, 1 << 0);
            try testArgs(u64, u7, 1 << 6);
            try testArgs(u128, u7, 0);
            try testArgs(u128, u7, 1 << 0);
            try testArgs(u128, u7, 1 << 6);
            try testArgs(u256, u7, 0);
            try testArgs(u256, u7, 1 << 0);
            try testArgs(u256, u7, 1 << 6);
            try testArgs(u512, u7, 0);
            try testArgs(u512, u7, 1 << 0);
            try testArgs(u512, u7, 1 << 6);
            try testArgs(u1024, u7, 0);
            try testArgs(u1024, u7, 1 << 0);
            try testArgs(u1024, u7, 1 << 6);

            try testArgs(i8, i8, -1 << 7);
            try testArgs(i8, i8, -1);
            try testArgs(i8, i8, 0);
            try testArgs(i16, i8, -1 << 7);
            try testArgs(i16, i8, -1);
            try testArgs(i16, i8, 0);
            try testArgs(i32, i8, -1 << 7);
            try testArgs(i32, i8, -1);
            try testArgs(i32, i8, 0);
            try testArgs(i64, i8, -1 << 7);
            try testArgs(i64, i8, -1);
            try testArgs(i64, i8, 0);
            try testArgs(i128, i8, -1 << 7);
            try testArgs(i128, i8, -1);
            try testArgs(i128, i8, 0);
            try testArgs(i256, i8, -1 << 7);
            try testArgs(i256, i8, -1);
            try testArgs(i256, i8, 0);
            try testArgs(i512, i8, -1 << 7);
            try testArgs(i512, i8, -1);
            try testArgs(i512, i8, 0);
            try testArgs(i1024, i8, -1 << 7);
            try testArgs(i1024, i8, -1);
            try testArgs(i1024, i8, 0);
            try testArgs(u8, u8, 0);
            try testArgs(u8, u8, 1 << 0);
            try testArgs(u8, u8, 1 << 7);
            try testArgs(u16, u8, 0);
            try testArgs(u16, u8, 1 << 0);
            try testArgs(u16, u8, 1 << 7);
            try testArgs(u32, u8, 0);
            try testArgs(u32, u8, 1 << 0);
            try testArgs(u32, u8, 1 << 7);
            try testArgs(u64, u8, 0);
            try testArgs(u64, u8, 1 << 0);
            try testArgs(u64, u8, 1 << 7);
            try testArgs(u128, u8, 0);
            try testArgs(u128, u8, 1 << 0);
            try testArgs(u128, u8, 1 << 7);
            try testArgs(u256, u8, 0);
            try testArgs(u256, u8, 1 << 0);
            try testArgs(u256, u8, 1 << 7);
            try testArgs(u512, u8, 0);
            try testArgs(u512, u8, 1 << 0);
            try testArgs(u512, u8, 1 << 7);
            try testArgs(u1024, u8, 0);
            try testArgs(u1024, u8, 1 << 0);
            try testArgs(u1024, u8, 1 << 7);

            try testArgs(i8, i9, -1 << 8);
            try testArgs(i8, i9, -1);
            try testArgs(i8, i9, 0);
            try testArgs(i16, i9, -1 << 8);
            try testArgs(i16, i9, -1);
            try testArgs(i16, i9, 0);
            try testArgs(i32, i9, -1 << 8);
            try testArgs(i32, i9, -1);
            try testArgs(i32, i9, 0);
            try testArgs(i64, i9, -1 << 8);
            try testArgs(i64, i9, -1);
            try testArgs(i64, i9, 0);
            try testArgs(i128, i9, -1 << 8);
            try testArgs(i128, i9, -1);
            try testArgs(i128, i9, 0);
            try testArgs(i256, i9, -1 << 8);
            try testArgs(i256, i9, -1);
            try testArgs(i256, i9, 0);
            try testArgs(i512, i9, -1 << 8);
            try testArgs(i512, i9, -1);
            try testArgs(i512, i9, 0);
            try testArgs(i1024, i9, -1 << 8);
            try testArgs(i1024, i9, -1);
            try testArgs(i1024, i9, 0);
            try testArgs(u8, u9, 0);
            try testArgs(u8, u9, 1 << 0);
            try testArgs(u8, u9, 1 << 8);
            try testArgs(u16, u9, 0);
            try testArgs(u16, u9, 1 << 0);
            try testArgs(u16, u9, 1 << 8);
            try testArgs(u32, u9, 0);
            try testArgs(u32, u9, 1 << 0);
            try testArgs(u32, u9, 1 << 8);
            try testArgs(u64, u9, 0);
            try testArgs(u64, u9, 1 << 0);
            try testArgs(u64, u9, 1 << 8);
            try testArgs(u128, u9, 0);
            try testArgs(u128, u9, 1 << 0);
            try testArgs(u128, u9, 1 << 8);
            try testArgs(u256, u9, 0);
            try testArgs(u256, u9, 1 << 0);
            try testArgs(u256, u9, 1 << 8);
            try testArgs(u512, u9, 0);
            try testArgs(u512, u9, 1 << 0);
            try testArgs(u512, u9, 1 << 8);
            try testArgs(u1024, u9, 0);
            try testArgs(u1024, u9, 1 << 0);
            try testArgs(u1024, u9, 1 << 8);

            try testArgs(i8, i15, -1 << 14);
            try testArgs(i8, i15, -1);
            try testArgs(i8, i15, 0);
            try testArgs(i16, i15, -1 << 14);
            try testArgs(i16, i15, -1);
            try testArgs(i16, i15, 0);
            try testArgs(i32, i15, -1 << 14);
            try testArgs(i32, i15, -1);
            try testArgs(i32, i15, 0);
            try testArgs(i64, i15, -1 << 14);
            try testArgs(i64, i15, -1);
            try testArgs(i64, i15, 0);
            try testArgs(i128, i15, -1 << 14);
            try testArgs(i128, i15, -1);
            try testArgs(i128, i15, 0);
            try testArgs(i256, i15, -1 << 14);
            try testArgs(i256, i15, -1);
            try testArgs(i256, i15, 0);
            try testArgs(i512, i15, -1 << 14);
            try testArgs(i512, i15, -1);
            try testArgs(i512, i15, 0);
            try testArgs(i1024, i15, -1 << 14);
            try testArgs(i1024, i15, -1);
            try testArgs(i1024, i15, 0);
            try testArgs(u8, u15, 0);
            try testArgs(u8, u15, 1 << 0);
            try testArgs(u8, u15, 1 << 14);
            try testArgs(u16, u15, 0);
            try testArgs(u16, u15, 1 << 0);
            try testArgs(u16, u15, 1 << 14);
            try testArgs(u32, u15, 0);
            try testArgs(u32, u15, 1 << 0);
            try testArgs(u32, u15, 1 << 14);
            try testArgs(u64, u15, 0);
            try testArgs(u64, u15, 1 << 0);
            try testArgs(u64, u15, 1 << 14);
            try testArgs(u128, u15, 0);
            try testArgs(u128, u15, 1 << 0);
            try testArgs(u128, u15, 1 << 14);
            try testArgs(u256, u15, 0);
            try testArgs(u256, u15, 1 << 0);
            try testArgs(u256, u15, 1 << 14);
            try testArgs(u512, u15, 0);
            try testArgs(u512, u15, 1 << 0);
            try testArgs(u512, u15, 1 << 14);
            try testArgs(u1024, u15, 0);
            try testArgs(u1024, u15, 1 << 0);
            try testArgs(u1024, u15, 1 << 14);

            try testArgs(i8, i16, -1 << 15);
            try testArgs(i8, i16, -1);
            try testArgs(i8, i16, 0);
            try testArgs(i16, i16, -1 << 15);
            try testArgs(i16, i16, -1);
            try testArgs(i16, i16, 0);
            try testArgs(i32, i16, -1 << 15);
            try testArgs(i32, i16, -1);
            try testArgs(i32, i16, 0);
            try testArgs(i64, i16, -1 << 15);
            try testArgs(i64, i16, -1);
            try testArgs(i64, i16, 0);
            try testArgs(i128, i16, -1 << 15);
            try testArgs(i128, i16, -1);
            try testArgs(i128, i16, 0);
            try testArgs(i256, i16, -1 << 15);
            try testArgs(i256, i16, -1);
            try testArgs(i256, i16, 0);
            try testArgs(i512, i16, -1 << 15);
            try testArgs(i512, i16, -1);
            try testArgs(i512, i16, 0);
            try testArgs(i1024, i16, -1 << 15);
            try testArgs(i1024, i16, -1);
            try testArgs(i1024, i16, 0);
            try testArgs(u8, u16, 0);
            try testArgs(u8, u16, 1 << 0);
            try testArgs(u8, u16, 1 << 15);
            try testArgs(u16, u16, 0);
            try testArgs(u16, u16, 1 << 0);
            try testArgs(u16, u16, 1 << 15);
            try testArgs(u32, u16, 0);
            try testArgs(u32, u16, 1 << 0);
            try testArgs(u32, u16, 1 << 15);
            try testArgs(u64, u16, 0);
            try testArgs(u64, u16, 1 << 0);
            try testArgs(u64, u16, 1 << 15);
            try testArgs(u128, u16, 0);
            try testArgs(u128, u16, 1 << 0);
            try testArgs(u128, u16, 1 << 15);
            try testArgs(u256, u16, 0);
            try testArgs(u256, u16, 1 << 0);
            try testArgs(u256, u16, 1 << 15);
            try testArgs(u512, u16, 0);
            try testArgs(u512, u16, 1 << 0);
            try testArgs(u512, u16, 1 << 15);
            try testArgs(u1024, u16, 0);
            try testArgs(u1024, u16, 1 << 0);
            try testArgs(u1024, u16, 1 << 15);

            try testArgs(i8, i17, -1 << 16);
            try testArgs(i8, i17, -1);
            try testArgs(i8, i17, 0);
            try testArgs(i16, i17, -1 << 16);
            try testArgs(i16, i17, -1);
            try testArgs(i16, i17, 0);
            try testArgs(i32, i17, -1 << 16);
            try testArgs(i32, i17, -1);
            try testArgs(i32, i17, 0);
            try testArgs(i64, i17, -1 << 16);
            try testArgs(i64, i17, -1);
            try testArgs(i64, i17, 0);
            try testArgs(i128, i17, -1 << 16);
            try testArgs(i128, i17, -1);
            try testArgs(i128, i17, 0);
            try testArgs(i256, i17, -1 << 16);
            try testArgs(i256, i17, -1);
            try testArgs(i256, i17, 0);
            try testArgs(i512, i17, -1 << 16);
            try testArgs(i512, i17, -1);
            try testArgs(i512, i17, 0);
            try testArgs(i1024, i17, -1 << 16);
            try testArgs(i1024, i17, -1);
            try testArgs(i1024, i17, 0);
            try testArgs(u8, u17, 0);
            try testArgs(u8, u17, 1 << 0);
            try testArgs(u8, u17, 1 << 16);
            try testArgs(u16, u17, 0);
            try testArgs(u16, u17, 1 << 0);
            try testArgs(u16, u17, 1 << 16);
            try testArgs(u32, u17, 0);
            try testArgs(u32, u17, 1 << 0);
            try testArgs(u32, u17, 1 << 16);
            try testArgs(u64, u17, 0);
            try testArgs(u64, u17, 1 << 0);
            try testArgs(u64, u17, 1 << 16);
            try testArgs(u128, u17, 0);
            try testArgs(u128, u17, 1 << 0);
            try testArgs(u128, u17, 1 << 16);
            try testArgs(u256, u17, 0);
            try testArgs(u256, u17, 1 << 0);
            try testArgs(u256, u17, 1 << 16);
            try testArgs(u512, u17, 0);
            try testArgs(u512, u17, 1 << 0);
            try testArgs(u512, u17, 1 << 16);
            try testArgs(u1024, u17, 0);
            try testArgs(u1024, u17, 1 << 0);
            try testArgs(u1024, u17, 1 << 16);

            try testArgs(i8, i31, -1 << 30);
            try testArgs(i8, i31, -1);
            try testArgs(i8, i31, 0);
            try testArgs(i16, i31, -1 << 30);
            try testArgs(i16, i31, -1);
            try testArgs(i16, i31, 0);
            try testArgs(i32, i31, -1 << 30);
            try testArgs(i32, i31, -1);
            try testArgs(i32, i31, 0);
            try testArgs(i64, i31, -1 << 30);
            try testArgs(i64, i31, -1);
            try testArgs(i64, i31, 0);
            try testArgs(i128, i31, -1 << 30);
            try testArgs(i128, i31, -1);
            try testArgs(i128, i31, 0);
            try testArgs(i256, i31, -1 << 30);
            try testArgs(i256, i31, -1);
            try testArgs(i256, i31, 0);
            try testArgs(i512, i31, -1 << 30);
            try testArgs(i512, i31, -1);
            try testArgs(i512, i31, 0);
            try testArgs(i1024, i31, -1 << 30);
            try testArgs(i1024, i31, -1);
            try testArgs(i1024, i31, 0);
            try testArgs(u8, u31, 0);
            try testArgs(u8, u31, 1 << 0);
            try testArgs(u8, u31, 1 << 30);
            try testArgs(u16, u31, 0);
            try testArgs(u16, u31, 1 << 0);
            try testArgs(u16, u31, 1 << 30);
            try testArgs(u32, u31, 0);
            try testArgs(u32, u31, 1 << 0);
            try testArgs(u32, u31, 1 << 30);
            try testArgs(u64, u31, 0);
            try testArgs(u64, u31, 1 << 0);
            try testArgs(u64, u31, 1 << 30);
            try testArgs(u128, u31, 0);
            try testArgs(u128, u31, 1 << 0);
            try testArgs(u128, u31, 1 << 30);
            try testArgs(u256, u31, 0);
            try testArgs(u256, u31, 1 << 0);
            try testArgs(u256, u31, 1 << 30);
            try testArgs(u512, u31, 0);
            try testArgs(u512, u31, 1 << 0);
            try testArgs(u512, u31, 1 << 30);
            try testArgs(u1024, u31, 0);
            try testArgs(u1024, u31, 1 << 0);
            try testArgs(u1024, u31, 1 << 30);

            try testArgs(i8, i32, -1 << 31);
            try testArgs(i8, i32, -1);
            try testArgs(i8, i32, 0);
            try testArgs(i16, i32, -1 << 31);
            try testArgs(i16, i32, -1);
            try testArgs(i16, i32, 0);
            try testArgs(i32, i32, -1 << 31);
            try testArgs(i32, i32, -1);
            try testArgs(i32, i32, 0);
            try testArgs(i64, i32, -1 << 31);
            try testArgs(i64, i32, -1);
            try testArgs(i64, i32, 0);
            try testArgs(i128, i32, -1 << 31);
            try testArgs(i128, i32, -1);
            try testArgs(i128, i32, 0);
            try testArgs(i256, i32, -1 << 31);
            try testArgs(i256, i32, -1);
            try testArgs(i256, i32, 0);
            try testArgs(i512, i32, -1 << 31);
            try testArgs(i512, i32, -1);
            try testArgs(i512, i32, 0);
            try testArgs(i1024, i32, -1 << 31);
            try testArgs(i1024, i32, -1);
            try testArgs(i1024, i32, 0);
            try testArgs(u8, u32, 0);
            try testArgs(u8, u32, 1 << 0);
            try testArgs(u8, u32, 1 << 31);
            try testArgs(u16, u32, 0);
            try testArgs(u16, u32, 1 << 0);
            try testArgs(u16, u32, 1 << 31);
            try testArgs(u32, u32, 0);
            try testArgs(u32, u32, 1 << 0);
            try testArgs(u32, u32, 1 << 31);
            try testArgs(u64, u32, 0);
            try testArgs(u64, u32, 1 << 0);
            try testArgs(u64, u32, 1 << 31);
            try testArgs(u128, u32, 0);
            try testArgs(u128, u32, 1 << 0);
            try testArgs(u128, u32, 1 << 31);
            try testArgs(u256, u32, 0);
            try testArgs(u256, u32, 1 << 0);
            try testArgs(u256, u32, 1 << 31);
            try testArgs(u512, u32, 0);
            try testArgs(u512, u32, 1 << 0);
            try testArgs(u512, u32, 1 << 31);
            try testArgs(u1024, u32, 0);
            try testArgs(u1024, u32, 1 << 0);
            try testArgs(u1024, u32, 1 << 31);

            try testArgs(i8, i33, -1 << 32);
            try testArgs(i8, i33, -1);
            try testArgs(i8, i33, 0);
            try testArgs(i16, i33, -1 << 32);
            try testArgs(i16, i33, -1);
            try testArgs(i16, i33, 0);
            try testArgs(i32, i33, -1 << 32);
            try testArgs(i32, i33, -1);
            try testArgs(i32, i33, 0);
            try testArgs(i64, i33, -1 << 32);
            try testArgs(i64, i33, -1);
            try testArgs(i64, i33, 0);
            try testArgs(i128, i33, -1 << 32);
            try testArgs(i128, i33, -1);
            try testArgs(i128, i33, 0);
            try testArgs(i256, i33, -1 << 32);
            try testArgs(i256, i33, -1);
            try testArgs(i256, i33, 0);
            try testArgs(i512, i33, -1 << 32);
            try testArgs(i512, i33, -1);
            try testArgs(i512, i33, 0);
            try testArgs(i1024, i33, -1 << 32);
            try testArgs(i1024, i33, -1);
            try testArgs(i1024, i33, 0);
            try testArgs(u8, u33, 0);
            try testArgs(u8, u33, 1 << 0);
            try testArgs(u8, u33, 1 << 32);
            try testArgs(u16, u33, 0);
            try testArgs(u16, u33, 1 << 0);
            try testArgs(u16, u33, 1 << 32);
            try testArgs(u32, u33, 0);
            try testArgs(u32, u33, 1 << 0);
            try testArgs(u32, u33, 1 << 32);
            try testArgs(u64, u33, 0);
            try testArgs(u64, u33, 1 << 0);
            try testArgs(u64, u33, 1 << 32);
            try testArgs(u128, u33, 0);
            try testArgs(u128, u33, 1 << 0);
            try testArgs(u128, u33, 1 << 32);
            try testArgs(u256, u33, 0);
            try testArgs(u256, u33, 1 << 0);
            try testArgs(u256, u33, 1 << 32);
            try testArgs(u512, u33, 0);
            try testArgs(u512, u33, 1 << 0);
            try testArgs(u512, u33, 1 << 32);
            try testArgs(u1024, u33, 0);
            try testArgs(u1024, u33, 1 << 0);
            try testArgs(u1024, u33, 1 << 32);

            try testArgs(i8, i63, -1 << 62);
            try testArgs(i8, i63, -1);
            try testArgs(i8, i63, 0);
            try testArgs(i16, i63, -1 << 62);
            try testArgs(i16, i63, -1);
            try testArgs(i16, i63, 0);
            try testArgs(i32, i63, -1 << 62);
            try testArgs(i32, i63, -1);
            try testArgs(i32, i63, 0);
            try testArgs(i64, i63, -1 << 62);
            try testArgs(i64, i63, -1);
            try testArgs(i64, i63, 0);
            try testArgs(i128, i63, -1 << 62);
            try testArgs(i128, i63, -1);
            try testArgs(i128, i63, 0);
            try testArgs(i256, i63, -1 << 62);
            try testArgs(i256, i63, -1);
            try testArgs(i256, i63, 0);
            try testArgs(i512, i63, -1 << 62);
            try testArgs(i512, i63, -1);
            try testArgs(i512, i63, 0);
            try testArgs(i1024, i63, -1 << 62);
            try testArgs(i1024, i63, -1);
            try testArgs(i1024, i63, 0);
            try testArgs(u8, u63, 0);
            try testArgs(u8, u63, 1 << 0);
            try testArgs(u8, u63, 1 << 62);
            try testArgs(u16, u63, 0);
            try testArgs(u16, u63, 1 << 0);
            try testArgs(u16, u63, 1 << 62);
            try testArgs(u32, u63, 0);
            try testArgs(u32, u63, 1 << 0);
            try testArgs(u32, u63, 1 << 62);
            try testArgs(u64, u63, 0);
            try testArgs(u64, u63, 1 << 0);
            try testArgs(u64, u63, 1 << 62);
            try testArgs(u128, u63, 0);
            try testArgs(u128, u63, 1 << 0);
            try testArgs(u128, u63, 1 << 62);
            try testArgs(u256, u63, 0);
            try testArgs(u256, u63, 1 << 0);
            try testArgs(u256, u63, 1 << 62);
            try testArgs(u512, u63, 0);
            try testArgs(u512, u63, 1 << 0);
            try testArgs(u512, u63, 1 << 62);
            try testArgs(u1024, u63, 0);
            try testArgs(u1024, u63, 1 << 0);
            try testArgs(u1024, u63, 1 << 62);

            try testArgs(i8, i64, -1 << 63);
            try testArgs(i8, i64, -1);
            try testArgs(i8, i64, 0);
            try testArgs(i16, i64, -1 << 63);
            try testArgs(i16, i64, -1);
            try testArgs(i16, i64, 0);
            try testArgs(i32, i64, -1 << 63);
            try testArgs(i32, i64, -1);
            try testArgs(i32, i64, 0);
            try testArgs(i64, i64, -1 << 63);
            try testArgs(i64, i64, -1);
            try testArgs(i64, i64, 0);
            try testArgs(i128, i64, -1 << 63);
            try testArgs(i128, i64, -1);
            try testArgs(i128, i64, 0);
            try testArgs(i256, i64, -1 << 63);
            try testArgs(i256, i64, -1);
            try testArgs(i256, i64, 0);
            try testArgs(i512, i64, -1 << 63);
            try testArgs(i512, i64, -1);
            try testArgs(i512, i64, 0);
            try testArgs(i1024, i64, -1 << 63);
            try testArgs(i1024, i64, -1);
            try testArgs(i1024, i64, 0);
            try testArgs(u8, u64, 0);
            try testArgs(u8, u64, 1 << 0);
            try testArgs(u8, u64, 1 << 63);
            try testArgs(u16, u64, 0);
            try testArgs(u16, u64, 1 << 0);
            try testArgs(u16, u64, 1 << 63);
            try testArgs(u32, u64, 0);
            try testArgs(u32, u64, 1 << 0);
            try testArgs(u32, u64, 1 << 63);
            try testArgs(u64, u64, 0);
            try testArgs(u64, u64, 1 << 0);
            try testArgs(u64, u64, 1 << 63);
            try testArgs(u128, u64, 0);
            try testArgs(u128, u64, 1 << 0);
            try testArgs(u128, u64, 1 << 63);
            try testArgs(u256, u64, 0);
            try testArgs(u256, u64, 1 << 0);
            try testArgs(u256, u64, 1 << 63);
            try testArgs(u512, u64, 0);
            try testArgs(u512, u64, 1 << 0);
            try testArgs(u512, u64, 1 << 63);
            try testArgs(u1024, u64, 0);
            try testArgs(u1024, u64, 1 << 0);
            try testArgs(u1024, u64, 1 << 63);

            try testArgs(i8, i65, -1 << 64);
            try testArgs(i8, i65, -1);
            try testArgs(i8, i65, 0);
            try testArgs(i16, i65, -1 << 64);
            try testArgs(i16, i65, -1);
            try testArgs(i16, i65, 0);
            try testArgs(i32, i65, -1 << 64);
            try testArgs(i32, i65, -1);
            try testArgs(i32, i65, 0);
            try testArgs(i64, i65, -1 << 64);
            try testArgs(i64, i65, -1);
            try testArgs(i64, i65, 0);
            try testArgs(i128, i65, -1 << 64);
            try testArgs(i128, i65, -1);
            try testArgs(i128, i65, 0);
            try testArgs(i256, i65, -1 << 64);
            try testArgs(i256, i65, -1);
            try testArgs(i256, i65, 0);
            try testArgs(i512, i65, -1 << 64);
            try testArgs(i512, i65, -1);
            try testArgs(i512, i65, 0);
            try testArgs(i1024, i65, -1 << 64);
            try testArgs(i1024, i65, -1);
            try testArgs(i1024, i65, 0);
            try testArgs(u8, u65, 0);
            try testArgs(u8, u65, 1 << 0);
            try testArgs(u8, u65, 1 << 64);
            try testArgs(u16, u65, 0);
            try testArgs(u16, u65, 1 << 0);
            try testArgs(u16, u65, 1 << 64);
            try testArgs(u32, u65, 0);
            try testArgs(u32, u65, 1 << 0);
            try testArgs(u32, u65, 1 << 64);
            try testArgs(u64, u65, 0);
            try testArgs(u64, u65, 1 << 0);
            try testArgs(u64, u65, 1 << 64);
            try testArgs(u128, u65, 0);
            try testArgs(u128, u65, 1 << 0);
            try testArgs(u128, u65, 1 << 64);
            try testArgs(u256, u65, 0);
            try testArgs(u256, u65, 1 << 0);
            try testArgs(u256, u65, 1 << 64);
            try testArgs(u512, u65, 0);
            try testArgs(u512, u65, 1 << 0);
            try testArgs(u512, u65, 1 << 64);
            try testArgs(u1024, u65, 0);
            try testArgs(u1024, u65, 1 << 0);
            try testArgs(u1024, u65, 1 << 64);

            try testArgs(i8, i95, -1 << 94);
            try testArgs(i8, i95, -1);
            try testArgs(i8, i95, 0);
            try testArgs(i16, i95, -1 << 94);
            try testArgs(i16, i95, -1);
            try testArgs(i16, i95, 0);
            try testArgs(i32, i95, -1 << 94);
            try testArgs(i32, i95, -1);
            try testArgs(i32, i95, 0);
            try testArgs(i64, i95, -1 << 94);
            try testArgs(i64, i95, -1);
            try testArgs(i64, i95, 0);
            try testArgs(i128, i95, -1 << 94);
            try testArgs(i128, i95, -1);
            try testArgs(i128, i95, 0);
            try testArgs(i256, i95, -1 << 94);
            try testArgs(i256, i95, -1);
            try testArgs(i256, i95, 0);
            try testArgs(i512, i95, -1 << 94);
            try testArgs(i512, i95, -1);
            try testArgs(i512, i95, 0);
            try testArgs(i1024, i95, -1 << 94);
            try testArgs(i1024, i95, -1);
            try testArgs(i1024, i95, 0);
            try testArgs(u8, u95, 0);
            try testArgs(u8, u95, 1 << 0);
            try testArgs(u8, u95, 1 << 94);
            try testArgs(u16, u95, 0);
            try testArgs(u16, u95, 1 << 0);
            try testArgs(u16, u95, 1 << 94);
            try testArgs(u32, u95, 0);
            try testArgs(u32, u95, 1 << 0);
            try testArgs(u32, u95, 1 << 94);
            try testArgs(u64, u95, 0);
            try testArgs(u64, u95, 1 << 0);
            try testArgs(u64, u95, 1 << 94);
            try testArgs(u128, u95, 0);
            try testArgs(u128, u95, 1 << 0);
            try testArgs(u128, u95, 1 << 94);
            try testArgs(u256, u95, 0);
            try testArgs(u256, u95, 1 << 0);
            try testArgs(u256, u95, 1 << 94);
            try testArgs(u512, u95, 0);
            try testArgs(u512, u95, 1 << 0);
            try testArgs(u512, u95, 1 << 94);
            try testArgs(u1024, u95, 0);
            try testArgs(u1024, u95, 1 << 0);
            try testArgs(u1024, u95, 1 << 94);

            try testArgs(i8, i97, -1 << 96);
            try testArgs(i8, i97, -1);
            try testArgs(i8, i97, 0);
            try testArgs(i16, i97, -1 << 96);
            try testArgs(i16, i97, -1);
            try testArgs(i16, i97, 0);
            try testArgs(i32, i97, -1 << 96);
            try testArgs(i32, i97, -1);
            try testArgs(i32, i97, 0);
            try testArgs(i64, i97, -1 << 96);
            try testArgs(i64, i97, -1);
            try testArgs(i64, i97, 0);
            try testArgs(i128, i97, -1 << 96);
            try testArgs(i128, i97, -1);
            try testArgs(i128, i97, 0);
            try testArgs(i256, i97, -1 << 96);
            try testArgs(i256, i97, -1);
            try testArgs(i256, i97, 0);
            try testArgs(i512, i97, -1 << 96);
            try testArgs(i512, i97, -1);
            try testArgs(i512, i97, 0);
            try testArgs(i1024, i97, -1 << 96);
            try testArgs(i1024, i97, -1);
            try testArgs(i1024, i97, 0);
            try testArgs(u8, u97, 0);
            try testArgs(u8, u97, 1 << 0);
            try testArgs(u8, u97, 1 << 96);
            try testArgs(u16, u97, 0);
            try testArgs(u16, u97, 1 << 0);
            try testArgs(u16, u97, 1 << 96);
            try testArgs(u32, u97, 0);
            try testArgs(u32, u97, 1 << 0);
            try testArgs(u32, u97, 1 << 96);
            try testArgs(u64, u97, 0);
            try testArgs(u64, u97, 1 << 0);
            try testArgs(u64, u97, 1 << 96);
            try testArgs(u128, u97, 0);
            try testArgs(u128, u97, 1 << 0);
            try testArgs(u128, u97, 1 << 96);
            try testArgs(u256, u97, 0);
            try testArgs(u256, u97, 1 << 0);
            try testArgs(u256, u97, 1 << 96);
            try testArgs(u512, u97, 0);
            try testArgs(u512, u97, 1 << 0);
            try testArgs(u512, u97, 1 << 96);
            try testArgs(u1024, u97, 0);
            try testArgs(u1024, u97, 1 << 0);
            try testArgs(u1024, u97, 1 << 96);

            try testArgs(i8, i127, -1 << 126);
            try testArgs(i8, i127, -1);
            try testArgs(i8, i127, 0);
            try testArgs(i16, i127, -1 << 126);
            try testArgs(i16, i127, -1);
            try testArgs(i16, i127, 0);
            try testArgs(i32, i127, -1 << 126);
            try testArgs(i32, i127, -1);
            try testArgs(i32, i127, 0);
            try testArgs(i64, i127, -1 << 126);
            try testArgs(i64, i127, -1);
            try testArgs(i64, i127, 0);
            try testArgs(i128, i127, -1 << 126);
            try testArgs(i128, i127, -1);
            try testArgs(i128, i127, 0);
            try testArgs(i256, i127, -1 << 126);
            try testArgs(i256, i127, -1);
            try testArgs(i256, i127, 0);
            try testArgs(i512, i127, -1 << 126);
            try testArgs(i512, i127, -1);
            try testArgs(i512, i127, 0);
            try testArgs(i1024, i127, -1 << 126);
            try testArgs(i1024, i127, -1);
            try testArgs(i1024, i127, 0);
            try testArgs(u8, u127, 0);
            try testArgs(u8, u127, 1 << 0);
            try testArgs(u8, u127, 1 << 126);
            try testArgs(u16, u127, 0);
            try testArgs(u16, u127, 1 << 0);
            try testArgs(u16, u127, 1 << 126);
            try testArgs(u32, u127, 0);
            try testArgs(u32, u127, 1 << 0);
            try testArgs(u32, u127, 1 << 126);
            try testArgs(u64, u127, 0);
            try testArgs(u64, u127, 1 << 0);
            try testArgs(u64, u127, 1 << 126);
            try testArgs(u128, u127, 0);
            try testArgs(u128, u127, 1 << 0);
            try testArgs(u128, u127, 1 << 126);
            try testArgs(u256, u127, 0);
            try testArgs(u256, u127, 1 << 0);
            try testArgs(u256, u127, 1 << 126);
            try testArgs(u512, u127, 0);
            try testArgs(u512, u127, 1 << 0);
            try testArgs(u512, u127, 1 << 126);
            try testArgs(u1024, u127, 0);
            try testArgs(u1024, u127, 1 << 0);
            try testArgs(u1024, u127, 1 << 126);

            try testArgs(i8, i128, -1 << 127);
            try testArgs(i8, i128, -1);
            try testArgs(i8, i128, 0);
            try testArgs(i16, i128, -1 << 127);
            try testArgs(i16, i128, -1);
            try testArgs(i16, i128, 0);
            try testArgs(i32, i128, -1 << 127);
            try testArgs(i32, i128, -1);
            try testArgs(i32, i128, 0);
            try testArgs(i64, i128, -1 << 127);
            try testArgs(i64, i128, -1);
            try testArgs(i64, i128, 0);
            try testArgs(i128, i128, -1 << 127);
            try testArgs(i128, i128, -1);
            try testArgs(i128, i128, 0);
            try testArgs(i256, i128, -1 << 127);
            try testArgs(i256, i128, -1);
            try testArgs(i256, i128, 0);
            try testArgs(i512, i128, -1 << 127);
            try testArgs(i512, i128, -1);
            try testArgs(i512, i128, 0);
            try testArgs(i1024, i128, -1 << 127);
            try testArgs(i1024, i128, -1);
            try testArgs(i1024, i128, 0);
            try testArgs(u8, u128, 0);
            try testArgs(u8, u128, 1 << 0);
            try testArgs(u8, u128, 1 << 127);
            try testArgs(u16, u128, 0);
            try testArgs(u16, u128, 1 << 0);
            try testArgs(u16, u128, 1 << 127);
            try testArgs(u32, u128, 0);
            try testArgs(u32, u128, 1 << 0);
            try testArgs(u32, u128, 1 << 127);
            try testArgs(u64, u128, 0);
            try testArgs(u64, u128, 1 << 0);
            try testArgs(u64, u128, 1 << 127);
            try testArgs(u128, u128, 0);
            try testArgs(u128, u128, 1 << 0);
            try testArgs(u128, u128, 1 << 127);
            try testArgs(u256, u128, 0);
            try testArgs(u256, u128, 1 << 0);
            try testArgs(u256, u128, 1 << 127);
            try testArgs(u512, u128, 0);
            try testArgs(u512, u128, 1 << 0);
            try testArgs(u512, u128, 1 << 127);
            try testArgs(u1024, u128, 0);
            try testArgs(u1024, u128, 1 << 0);
            try testArgs(u1024, u128, 1 << 127);

            try testArgs(i8, i129, -1 << 128);
            try testArgs(i8, i129, -1);
            try testArgs(i8, i129, 0);
            try testArgs(i16, i129, -1 << 128);
            try testArgs(i16, i129, -1);
            try testArgs(i16, i129, 0);
            try testArgs(i32, i129, -1 << 128);
            try testArgs(i32, i129, -1);
            try testArgs(i32, i129, 0);
            try testArgs(i64, i129, -1 << 128);
            try testArgs(i64, i129, -1);
            try testArgs(i64, i129, 0);
            try testArgs(i128, i129, -1 << 128);
            try testArgs(i128, i129, -1);
            try testArgs(i128, i129, 0);
            try testArgs(i256, i129, -1 << 128);
            try testArgs(i256, i129, -1);
            try testArgs(i256, i129, 0);
            try testArgs(i512, i129, -1 << 128);
            try testArgs(i512, i129, -1);
            try testArgs(i512, i129, 0);
            try testArgs(i1024, i129, -1 << 128);
            try testArgs(i1024, i129, -1);
            try testArgs(i1024, i129, 0);
            try testArgs(u8, u129, 0);
            try testArgs(u8, u129, 1 << 0);
            try testArgs(u8, u129, 1 << 128);
            try testArgs(u16, u129, 0);
            try testArgs(u16, u129, 1 << 0);
            try testArgs(u16, u129, 1 << 128);
            try testArgs(u32, u129, 0);
            try testArgs(u32, u129, 1 << 0);
            try testArgs(u32, u129, 1 << 128);
            try testArgs(u64, u129, 0);
            try testArgs(u64, u129, 1 << 0);
            try testArgs(u64, u129, 1 << 128);
            try testArgs(u128, u129, 0);
            try testArgs(u128, u129, 1 << 0);
            try testArgs(u128, u129, 1 << 128);
            try testArgs(u256, u129, 0);
            try testArgs(u256, u129, 1 << 0);
            try testArgs(u256, u129, 1 << 128);
            try testArgs(u512, u129, 0);
            try testArgs(u512, u129, 1 << 0);
            try testArgs(u512, u129, 1 << 128);
            try testArgs(u1024, u129, 0);
            try testArgs(u1024, u129, 1 << 0);
            try testArgs(u1024, u129, 1 << 128);

            try testArgs(i8, i255, -1 << 254);
            try testArgs(i8, i255, -1);
            try testArgs(i8, i255, 0);
            try testArgs(i16, i255, -1 << 254);
            try testArgs(i16, i255, -1);
            try testArgs(i16, i255, 0);
            try testArgs(i32, i255, -1 << 254);
            try testArgs(i32, i255, -1);
            try testArgs(i32, i255, 0);
            try testArgs(i64, i255, -1 << 254);
            try testArgs(i64, i255, -1);
            try testArgs(i64, i255, 0);
            try testArgs(i128, i255, -1 << 254);
            try testArgs(i128, i255, -1);
            try testArgs(i128, i255, 0);
            try testArgs(i256, i255, -1 << 254);
            try testArgs(i256, i255, -1);
            try testArgs(i256, i255, 0);
            try testArgs(i512, i255, -1 << 254);
            try testArgs(i512, i255, -1);
            try testArgs(i512, i255, 0);
            try testArgs(i1024, i255, -1 << 254);
            try testArgs(i1024, i255, -1);
            try testArgs(i1024, i255, 0);
            try testArgs(u8, u255, 0);
            try testArgs(u8, u255, 1 << 0);
            try testArgs(u8, u255, 1 << 254);
            try testArgs(u16, u255, 0);
            try testArgs(u16, u255, 1 << 0);
            try testArgs(u16, u255, 1 << 254);
            try testArgs(u32, u255, 0);
            try testArgs(u32, u255, 1 << 0);
            try testArgs(u32, u255, 1 << 254);
            try testArgs(u64, u255, 0);
            try testArgs(u64, u255, 1 << 0);
            try testArgs(u64, u255, 1 << 254);
            try testArgs(u128, u255, 0);
            try testArgs(u128, u255, 1 << 0);
            try testArgs(u128, u255, 1 << 254);
            try testArgs(u256, u255, 0);
            try testArgs(u256, u255, 1 << 0);
            try testArgs(u256, u255, 1 << 254);
            try testArgs(u512, u255, 0);
            try testArgs(u512, u255, 1 << 0);
            try testArgs(u512, u255, 1 << 254);
            try testArgs(u1024, u255, 0);
            try testArgs(u1024, u255, 1 << 0);
            try testArgs(u1024, u255, 1 << 254);

            try testArgs(i8, i256, -1 << 255);
            try testArgs(i8, i256, -1);
            try testArgs(i8, i256, 0);
            try testArgs(i16, i256, -1 << 255);
            try testArgs(i16, i256, -1);
            try testArgs(i16, i256, 0);
            try testArgs(i32, i256, -1 << 255);
            try testArgs(i32, i256, -1);
            try testArgs(i32, i256, 0);
            try testArgs(i64, i256, -1 << 255);
            try testArgs(i64, i256, -1);
            try testArgs(i64, i256, 0);
            try testArgs(i128, i256, -1 << 255);
            try testArgs(i128, i256, -1);
            try testArgs(i128, i256, 0);
            try testArgs(i256, i256, -1 << 255);
            try testArgs(i256, i256, -1);
            try testArgs(i256, i256, 0);
            try testArgs(i512, i256, -1 << 255);
            try testArgs(i512, i256, -1);
            try testArgs(i512, i256, 0);
            try testArgs(i1024, i256, -1 << 255);
            try testArgs(i1024, i256, -1);
            try testArgs(i1024, i256, 0);
            try testArgs(u8, u256, 0);
            try testArgs(u8, u256, 1 << 0);
            try testArgs(u8, u256, 1 << 255);
            try testArgs(u16, u256, 0);
            try testArgs(u16, u256, 1 << 0);
            try testArgs(u16, u256, 1 << 255);
            try testArgs(u32, u256, 0);
            try testArgs(u32, u256, 1 << 0);
            try testArgs(u32, u256, 1 << 255);
            try testArgs(u64, u256, 0);
            try testArgs(u64, u256, 1 << 0);
            try testArgs(u64, u256, 1 << 255);
            try testArgs(u128, u256, 0);
            try testArgs(u128, u256, 1 << 0);
            try testArgs(u128, u256, 1 << 255);
            try testArgs(u256, u256, 0);
            try testArgs(u256, u256, 1 << 0);
            try testArgs(u256, u256, 1 << 255);
            try testArgs(u512, u256, 0);
            try testArgs(u512, u256, 1 << 0);
            try testArgs(u512, u256, 1 << 255);
            try testArgs(u1024, u256, 0);
            try testArgs(u1024, u256, 1 << 0);
            try testArgs(u1024, u256, 1 << 255);

            try testArgs(i8, i257, -1 << 256);
            try testArgs(i8, i257, -1);
            try testArgs(i8, i257, 0);
            try testArgs(i16, i257, -1 << 256);
            try testArgs(i16, i257, -1);
            try testArgs(i16, i257, 0);
            try testArgs(i32, i257, -1 << 256);
            try testArgs(i32, i257, -1);
            try testArgs(i32, i257, 0);
            try testArgs(i64, i257, -1 << 256);
            try testArgs(i64, i257, -1);
            try testArgs(i64, i257, 0);
            try testArgs(i128, i257, -1 << 256);
            try testArgs(i128, i257, -1);
            try testArgs(i128, i257, 0);
            try testArgs(i256, i257, -1 << 256);
            try testArgs(i256, i257, -1);
            try testArgs(i256, i257, 0);
            try testArgs(i512, i257, -1 << 256);
            try testArgs(i512, i257, -1);
            try testArgs(i512, i257, 0);
            try testArgs(i1024, i257, -1 << 256);
            try testArgs(i1024, i257, -1);
            try testArgs(i1024, i257, 0);
            try testArgs(u8, u257, 0);
            try testArgs(u8, u257, 1 << 0);
            try testArgs(u8, u257, 1 << 256);
            try testArgs(u16, u257, 0);
            try testArgs(u16, u257, 1 << 0);
            try testArgs(u16, u257, 1 << 256);
            try testArgs(u32, u257, 0);
            try testArgs(u32, u257, 1 << 0);
            try testArgs(u32, u257, 1 << 256);
            try testArgs(u64, u257, 0);
            try testArgs(u64, u257, 1 << 0);
            try testArgs(u64, u257, 1 << 256);
            try testArgs(u128, u257, 0);
            try testArgs(u128, u257, 1 << 0);
            try testArgs(u128, u257, 1 << 256);
            try testArgs(u256, u257, 0);
            try testArgs(u256, u257, 1 << 0);
            try testArgs(u256, u257, 1 << 256);
            try testArgs(u512, u257, 0);
            try testArgs(u512, u257, 1 << 0);
            try testArgs(u512, u257, 1 << 256);
            try testArgs(u1024, u257, 0);
            try testArgs(u1024, u257, 1 << 0);
            try testArgs(u1024, u257, 1 << 256);

            try testArgs(i8, i511, -1 << 510);
            try testArgs(i8, i511, -1);
            try testArgs(i8, i511, 0);
            try testArgs(i16, i511, -1 << 510);
            try testArgs(i16, i511, -1);
            try testArgs(i16, i511, 0);
            try testArgs(i32, i511, -1 << 510);
            try testArgs(i32, i511, -1);
            try testArgs(i32, i511, 0);
            try testArgs(i64, i511, -1 << 510);
            try testArgs(i64, i511, -1);
            try testArgs(i64, i511, 0);
            try testArgs(i128, i511, -1 << 510);
            try testArgs(i128, i511, -1);
            try testArgs(i128, i511, 0);
            try testArgs(i256, i511, -1 << 510);
            try testArgs(i256, i511, -1);
            try testArgs(i256, i511, 0);
            try testArgs(i512, i511, -1 << 510);
            try testArgs(i512, i511, -1);
            try testArgs(i512, i511, 0);
            try testArgs(i1024, i511, -1 << 510);
            try testArgs(i1024, i511, -1);
            try testArgs(i1024, i511, 0);
            try testArgs(u8, u511, 0);
            try testArgs(u8, u511, 1 << 0);
            try testArgs(u8, u511, 1 << 510);
            try testArgs(u16, u511, 0);
            try testArgs(u16, u511, 1 << 0);
            try testArgs(u16, u511, 1 << 510);
            try testArgs(u32, u511, 0);
            try testArgs(u32, u511, 1 << 0);
            try testArgs(u32, u511, 1 << 510);
            try testArgs(u64, u511, 0);
            try testArgs(u64, u511, 1 << 0);
            try testArgs(u64, u511, 1 << 510);
            try testArgs(u128, u511, 0);
            try testArgs(u128, u511, 1 << 0);
            try testArgs(u128, u511, 1 << 510);
            try testArgs(u256, u511, 0);
            try testArgs(u256, u511, 1 << 0);
            try testArgs(u256, u511, 1 << 510);
            try testArgs(u512, u511, 0);
            try testArgs(u512, u511, 1 << 0);
            try testArgs(u512, u511, 1 << 510);
            try testArgs(u1024, u511, 0);
            try testArgs(u1024, u511, 1 << 0);
            try testArgs(u1024, u511, 1 << 510);

            try testArgs(i8, i512, -1 << 511);
            try testArgs(i8, i512, -1);
            try testArgs(i8, i512, 0);
            try testArgs(i16, i512, -1 << 511);
            try testArgs(i16, i512, -1);
            try testArgs(i16, i512, 0);
            try testArgs(i32, i512, -1 << 511);
            try testArgs(i32, i512, -1);
            try testArgs(i32, i512, 0);
            try testArgs(i64, i512, -1 << 511);
            try testArgs(i64, i512, -1);
            try testArgs(i64, i512, 0);
            try testArgs(i128, i512, -1 << 511);
            try testArgs(i128, i512, -1);
            try testArgs(i128, i512, 0);
            try testArgs(i256, i512, -1 << 511);
            try testArgs(i256, i512, -1);
            try testArgs(i256, i512, 0);
            try testArgs(i512, i512, -1 << 511);
            try testArgs(i512, i512, -1);
            try testArgs(i512, i512, 0);
            try testArgs(i1024, i512, -1 << 511);
            try testArgs(i1024, i512, -1);
            try testArgs(i1024, i512, 0);
            try testArgs(u8, u512, 0);
            try testArgs(u8, u512, 1 << 0);
            try testArgs(u8, u512, 1 << 511);
            try testArgs(u16, u512, 0);
            try testArgs(u16, u512, 1 << 0);
            try testArgs(u16, u512, 1 << 511);
            try testArgs(u32, u512, 0);
            try testArgs(u32, u512, 1 << 0);
            try testArgs(u32, u512, 1 << 511);
            try testArgs(u64, u512, 0);
            try testArgs(u64, u512, 1 << 0);
            try testArgs(u64, u512, 1 << 511);
            try testArgs(u128, u512, 0);
            try testArgs(u128, u512, 1 << 0);
            try testArgs(u128, u512, 1 << 511);
            try testArgs(u256, u512, 0);
            try testArgs(u256, u512, 1 << 0);
            try testArgs(u256, u512, 1 << 511);
            try testArgs(u512, u512, 0);
            try testArgs(u512, u512, 1 << 0);
            try testArgs(u512, u512, 1 << 511);
            try testArgs(u1024, u512, 0);
            try testArgs(u1024, u512, 1 << 0);
            try testArgs(u1024, u512, 1 << 511);

            try testArgs(i8, i513, -1 << 512);
            try testArgs(i8, i513, -1);
            try testArgs(i8, i513, 0);
            try testArgs(i16, i513, -1 << 512);
            try testArgs(i16, i513, -1);
            try testArgs(i16, i513, 0);
            try testArgs(i32, i513, -1 << 512);
            try testArgs(i32, i513, -1);
            try testArgs(i32, i513, 0);
            try testArgs(i64, i513, -1 << 512);
            try testArgs(i64, i513, -1);
            try testArgs(i64, i513, 0);
            try testArgs(i128, i513, -1 << 512);
            try testArgs(i128, i513, -1);
            try testArgs(i128, i513, 0);
            try testArgs(i256, i513, -1 << 512);
            try testArgs(i256, i513, -1);
            try testArgs(i256, i513, 0);
            try testArgs(i512, i513, -1 << 512);
            try testArgs(i512, i513, -1);
            try testArgs(i512, i513, 0);
            try testArgs(i1024, i513, -1 << 512);
            try testArgs(i1024, i513, -1);
            try testArgs(i1024, i513, 0);
            try testArgs(u8, u513, 0);
            try testArgs(u8, u513, 1 << 0);
            try testArgs(u8, u513, 1 << 512);
            try testArgs(u16, u513, 0);
            try testArgs(u16, u513, 1 << 0);
            try testArgs(u16, u513, 1 << 512);
            try testArgs(u32, u513, 0);
            try testArgs(u32, u513, 1 << 0);
            try testArgs(u32, u513, 1 << 512);
            try testArgs(u64, u513, 0);
            try testArgs(u64, u513, 1 << 0);
            try testArgs(u64, u513, 1 << 512);
            try testArgs(u128, u513, 0);
            try testArgs(u128, u513, 1 << 0);
            try testArgs(u128, u513, 1 << 512);
            try testArgs(u256, u513, 0);
            try testArgs(u256, u513, 1 << 0);
            try testArgs(u256, u513, 1 << 512);
            try testArgs(u512, u513, 0);
            try testArgs(u512, u513, 1 << 0);
            try testArgs(u512, u513, 1 << 512);
            try testArgs(u1024, u513, 0);
            try testArgs(u1024, u513, 1 << 0);
            try testArgs(u1024, u513, 1 << 512);

            try testArgs(i8, i1023, -1 << 1022);
            try testArgs(i8, i1023, -1);
            try testArgs(i8, i1023, 0);
            try testArgs(i16, i1023, -1 << 1022);
            try testArgs(i16, i1023, -1);
            try testArgs(i16, i1023, 0);
            try testArgs(i32, i1023, -1 << 1022);
            try testArgs(i32, i1023, -1);
            try testArgs(i32, i1023, 0);
            try testArgs(i64, i1023, -1 << 1022);
            try testArgs(i64, i1023, -1);
            try testArgs(i64, i1023, 0);
            try testArgs(i128, i1023, -1 << 1022);
            try testArgs(i128, i1023, -1);
            try testArgs(i128, i1023, 0);
            try testArgs(i256, i1023, -1 << 1022);
            try testArgs(i256, i1023, -1);
            try testArgs(i256, i1023, 0);
            try testArgs(i512, i1023, -1 << 1022);
            try testArgs(i512, i1023, -1);
            try testArgs(i512, i1023, 0);
            try testArgs(i1024, i1023, -1 << 1022);
            try testArgs(i1024, i1023, -1);
            try testArgs(i1024, i1023, 0);
            try testArgs(u8, u1023, 0);
            try testArgs(u8, u1023, 1 << 0);
            try testArgs(u8, u1023, 1 << 1022);
            try testArgs(u16, u1023, 0);
            try testArgs(u16, u1023, 1 << 0);
            try testArgs(u16, u1023, 1 << 1022);
            try testArgs(u32, u1023, 0);
            try testArgs(u32, u1023, 1 << 0);
            try testArgs(u32, u1023, 1 << 1022);
            try testArgs(u64, u1023, 0);
            try testArgs(u64, u1023, 1 << 0);
            try testArgs(u64, u1023, 1 << 1022);
            try testArgs(u128, u1023, 0);
            try testArgs(u128, u1023, 1 << 0);
            try testArgs(u128, u1023, 1 << 1022);
            try testArgs(u256, u1023, 0);
            try testArgs(u256, u1023, 1 << 0);
            try testArgs(u256, u1023, 1 << 1022);
            try testArgs(u512, u1023, 0);
            try testArgs(u512, u1023, 1 << 0);
            try testArgs(u512, u1023, 1 << 1022);
            try testArgs(u1024, u1023, 0);
            try testArgs(u1024, u1023, 1 << 0);
            try testArgs(u1024, u1023, 1 << 1022);

            try testArgs(i8, i1024, -1 << 1023);
            try testArgs(i8, i1024, -1);
            try testArgs(i8, i1024, 0);
            try testArgs(i16, i1024, -1 << 1023);
            try testArgs(i16, i1024, -1);
            try testArgs(i16, i1024, 0);
            try testArgs(i32, i1024, -1 << 1023);
            try testArgs(i32, i1024, -1);
            try testArgs(i32, i1024, 0);
            try testArgs(i64, i1024, -1 << 1023);
            try testArgs(i64, i1024, -1);
            try testArgs(i64, i1024, 0);
            try testArgs(i128, i1024, -1 << 1023);
            try testArgs(i128, i1024, -1);
            try testArgs(i128, i1024, 0);
            try testArgs(i256, i1024, -1 << 1023);
            try testArgs(i256, i1024, -1);
            try testArgs(i256, i1024, 0);
            try testArgs(i512, i1024, -1 << 1023);
            try testArgs(i512, i1024, -1);
            try testArgs(i512, i1024, 0);
            try testArgs(i1024, i1024, -1 << 1023);
            try testArgs(i1024, i1024, -1);
            try testArgs(i1024, i1024, 0);
            try testArgs(u8, u1024, 0);
            try testArgs(u8, u1024, 1 << 0);
            try testArgs(u8, u1024, 1 << 1023);
            try testArgs(u16, u1024, 0);
            try testArgs(u16, u1024, 1 << 0);
            try testArgs(u16, u1024, 1 << 1023);
            try testArgs(u32, u1024, 0);
            try testArgs(u32, u1024, 1 << 0);
            try testArgs(u32, u1024, 1 << 1023);
            try testArgs(u64, u1024, 0);
            try testArgs(u64, u1024, 1 << 0);
            try testArgs(u64, u1024, 1 << 1023);
            try testArgs(u128, u1024, 0);
            try testArgs(u128, u1024, 1 << 0);
            try testArgs(u128, u1024, 1 << 1023);
            try testArgs(u256, u1024, 0);
            try testArgs(u256, u1024, 1 << 0);
            try testArgs(u256, u1024, 1 << 1023);
            try testArgs(u512, u1024, 0);
            try testArgs(u512, u1024, 1 << 0);
            try testArgs(u512, u1024, 1 << 1023);
            try testArgs(u1024, u1024, 0);
            try testArgs(u1024, u1024, 1 << 0);
            try testArgs(u1024, u1024, 1 << 1023);

            try testArgs(i8, i1025, -1 << 1024);
            try testArgs(i8, i1025, -1);
            try testArgs(i8, i1025, 0);
            try testArgs(i16, i1025, -1 << 1024);
            try testArgs(i16, i1025, -1);
            try testArgs(i16, i1025, 0);
            try testArgs(i32, i1025, -1 << 1024);
            try testArgs(i32, i1025, -1);
            try testArgs(i32, i1025, 0);
            try testArgs(i64, i1025, -1 << 1024);
            try testArgs(i64, i1025, -1);
            try testArgs(i64, i1025, 0);
            try testArgs(i128, i1025, -1 << 1024);
            try testArgs(i128, i1025, -1);
            try testArgs(i128, i1025, 0);
            try testArgs(i256, i1025, -1 << 1024);
            try testArgs(i256, i1025, -1);
            try testArgs(i256, i1025, 0);
            try testArgs(i512, i1025, -1 << 1024);
            try testArgs(i512, i1025, -1);
            try testArgs(i512, i1025, 0);
            try testArgs(i1024, i1025, -1 << 1024);
            try testArgs(i1024, i1025, -1);
            try testArgs(i1024, i1025, 0);
            try testArgs(u8, u1025, 0);
            try testArgs(u8, u1025, 1 << 0);
            try testArgs(u8, u1025, 1 << 1024);
            try testArgs(u16, u1025, 0);
            try testArgs(u16, u1025, 1 << 0);
            try testArgs(u16, u1025, 1 << 1024);
            try testArgs(u32, u1025, 0);
            try testArgs(u32, u1025, 1 << 0);
            try testArgs(u32, u1025, 1 << 1024);
            try testArgs(u64, u1025, 0);
            try testArgs(u64, u1025, 1 << 0);
            try testArgs(u64, u1025, 1 << 1024);
            try testArgs(u128, u1025, 0);
            try testArgs(u128, u1025, 1 << 0);
            try testArgs(u128, u1025, 1 << 1024);
            try testArgs(u256, u1025, 0);
            try testArgs(u256, u1025, 1 << 0);
            try testArgs(u256, u1025, 1 << 1024);
            try testArgs(u512, u1025, 0);
            try testArgs(u512, u1025, 1 << 0);
            try testArgs(u512, u1025, 1 << 1024);
            try testArgs(u1024, u1025, 0);
            try testArgs(u1024, u1025, 1 << 0);
            try testArgs(u1024, u1025, 1 << 1024);
        }
        fn testInts() !void {
            try testSameSignednessInts();

            try testArgs(u8, i1, -1);
            try testArgs(u8, i1, 0);
            try testArgs(u16, i1, -1);
            try testArgs(u16, i1, 0);
            try testArgs(u32, i1, -1);
            try testArgs(u32, i1, 0);
            try testArgs(u64, i1, -1);
            try testArgs(u64, i1, 0);
            try testArgs(u128, i1, -1);
            try testArgs(u128, i1, 0);
            try testArgs(u256, i1, -1);
            try testArgs(u256, i1, 0);
            try testArgs(u512, i1, -1);
            try testArgs(u512, i1, 0);
            try testArgs(u1024, i1, -1);
            try testArgs(u1024, i1, 0);
            try testArgs(i8, u1, 0);
            try testArgs(i8, u1, 1 << 0);
            try testArgs(i16, u1, 0);
            try testArgs(i16, u1, 1 << 0);
            try testArgs(i32, u1, 0);
            try testArgs(i32, u1, 1 << 0);
            try testArgs(i64, u1, 0);
            try testArgs(i64, u1, 1 << 0);
            try testArgs(i128, u1, 0);
            try testArgs(i128, u1, 1 << 0);
            try testArgs(i256, u1, 0);
            try testArgs(i256, u1, 1 << 0);
            try testArgs(i512, u1, 0);
            try testArgs(i512, u1, 1 << 0);
            try testArgs(i1024, u1, 0);
            try testArgs(i1024, u1, 1 << 0);

            try testArgs(u8, i2, -1 << 1);
            try testArgs(u8, i2, -1);
            try testArgs(u8, i2, 0);
            try testArgs(u16, i2, -1 << 1);
            try testArgs(u16, i2, -1);
            try testArgs(u16, i2, 0);
            try testArgs(u32, i2, -1 << 1);
            try testArgs(u32, i2, -1);
            try testArgs(u32, i2, 0);
            try testArgs(u64, i2, -1 << 1);
            try testArgs(u64, i2, -1);
            try testArgs(u64, i2, 0);
            try testArgs(u128, i2, -1 << 1);
            try testArgs(u128, i2, -1);
            try testArgs(u128, i2, 0);
            try testArgs(u256, i2, -1 << 1);
            try testArgs(u256, i2, -1);
            try testArgs(u256, i2, 0);
            try testArgs(u512, i2, -1 << 1);
            try testArgs(u512, i2, -1);
            try testArgs(u512, i2, 0);
            try testArgs(u1024, i2, -1 << 1);
            try testArgs(u1024, i2, -1);
            try testArgs(u1024, i2, 0);
            try testArgs(i8, u2, 0);
            try testArgs(i8, u2, 1 << 0);
            try testArgs(i8, u2, 1 << 1);
            try testArgs(i16, u2, 0);
            try testArgs(i16, u2, 1 << 0);
            try testArgs(i16, u2, 1 << 1);
            try testArgs(i32, u2, 0);
            try testArgs(i32, u2, 1 << 0);
            try testArgs(i32, u2, 1 << 1);
            try testArgs(i64, u2, 0);
            try testArgs(i64, u2, 1 << 0);
            try testArgs(i64, u2, 1 << 1);
            try testArgs(i128, u2, 0);
            try testArgs(i128, u2, 1 << 0);
            try testArgs(i128, u2, 1 << 1);
            try testArgs(i256, u2, 0);
            try testArgs(i256, u2, 1 << 0);
            try testArgs(i256, u2, 1 << 1);
            try testArgs(i512, u2, 0);
            try testArgs(i512, u2, 1 << 0);
            try testArgs(i512, u2, 1 << 1);
            try testArgs(i1024, u2, 0);
            try testArgs(i1024, u2, 1 << 0);
            try testArgs(i1024, u2, 1 << 1);

            try testArgs(u8, i3, -1 << 2);
            try testArgs(u8, i3, -1);
            try testArgs(u8, i3, 0);
            try testArgs(u16, i3, -1 << 2);
            try testArgs(u16, i3, -1);
            try testArgs(u16, i3, 0);
            try testArgs(u32, i3, -1 << 2);
            try testArgs(u32, i3, -1);
            try testArgs(u32, i3, 0);
            try testArgs(u64, i3, -1 << 2);
            try testArgs(u64, i3, -1);
            try testArgs(u64, i3, 0);
            try testArgs(u128, i3, -1 << 2);
            try testArgs(u128, i3, -1);
            try testArgs(u128, i3, 0);
            try testArgs(u256, i3, -1 << 2);
            try testArgs(u256, i3, -1);
            try testArgs(u256, i3, 0);
            try testArgs(u512, i3, -1 << 2);
            try testArgs(u512, i3, -1);
            try testArgs(u512, i3, 0);
            try testArgs(u1024, i3, -1 << 2);
            try testArgs(u1024, i3, -1);
            try testArgs(u1024, i3, 0);
            try testArgs(i8, u3, 0);
            try testArgs(i8, u3, 1 << 0);
            try testArgs(i8, u3, 1 << 2);
            try testArgs(i16, u3, 0);
            try testArgs(i16, u3, 1 << 0);
            try testArgs(i16, u3, 1 << 2);
            try testArgs(i32, u3, 0);
            try testArgs(i32, u3, 1 << 0);
            try testArgs(i32, u3, 1 << 2);
            try testArgs(i64, u3, 0);
            try testArgs(i64, u3, 1 << 0);
            try testArgs(i64, u3, 1 << 2);
            try testArgs(i128, u3, 0);
            try testArgs(i128, u3, 1 << 0);
            try testArgs(i128, u3, 1 << 2);
            try testArgs(i256, u3, 0);
            try testArgs(i256, u3, 1 << 0);
            try testArgs(i256, u3, 1 << 2);
            try testArgs(i512, u3, 0);
            try testArgs(i512, u3, 1 << 0);
            try testArgs(i512, u3, 1 << 2);
            try testArgs(i1024, u3, 0);
            try testArgs(i1024, u3, 1 << 0);
            try testArgs(i1024, u3, 1 << 2);

            try testArgs(u8, i4, -1 << 3);
            try testArgs(u8, i4, -1);
            try testArgs(u8, i4, 0);
            try testArgs(u16, i4, -1 << 3);
            try testArgs(u16, i4, -1);
            try testArgs(u16, i4, 0);
            try testArgs(u32, i4, -1 << 3);
            try testArgs(u32, i4, -1);
            try testArgs(u32, i4, 0);
            try testArgs(u64, i4, -1 << 3);
            try testArgs(u64, i4, -1);
            try testArgs(u64, i4, 0);
            try testArgs(u128, i4, -1 << 3);
            try testArgs(u128, i4, -1);
            try testArgs(u128, i4, 0);
            try testArgs(u256, i4, -1 << 3);
            try testArgs(u256, i4, -1);
            try testArgs(u256, i4, 0);
            try testArgs(u512, i4, -1 << 3);
            try testArgs(u512, i4, -1);
            try testArgs(u512, i4, 0);
            try testArgs(u1024, i4, -1 << 3);
            try testArgs(u1024, i4, -1);
            try testArgs(u1024, i4, 0);
            try testArgs(i8, u4, 0);
            try testArgs(i8, u4, 1 << 0);
            try testArgs(i8, u4, 1 << 3);
            try testArgs(i16, u4, 0);
            try testArgs(i16, u4, 1 << 0);
            try testArgs(i16, u4, 1 << 3);
            try testArgs(i32, u4, 0);
            try testArgs(i32, u4, 1 << 0);
            try testArgs(i32, u4, 1 << 3);
            try testArgs(i64, u4, 0);
            try testArgs(i64, u4, 1 << 0);
            try testArgs(i64, u4, 1 << 3);
            try testArgs(i128, u4, 0);
            try testArgs(i128, u4, 1 << 0);
            try testArgs(i128, u4, 1 << 3);
            try testArgs(i256, u4, 0);
            try testArgs(i256, u4, 1 << 0);
            try testArgs(i256, u4, 1 << 3);
            try testArgs(i512, u4, 0);
            try testArgs(i512, u4, 1 << 0);
            try testArgs(i512, u4, 1 << 3);
            try testArgs(i1024, u4, 0);
            try testArgs(i1024, u4, 1 << 0);
            try testArgs(i1024, u4, 1 << 3);

            try testArgs(u8, i5, -1 << 4);
            try testArgs(u8, i5, -1);
            try testArgs(u8, i5, 0);
            try testArgs(u16, i5, -1 << 4);
            try testArgs(u16, i5, -1);
            try testArgs(u16, i5, 0);
            try testArgs(u32, i5, -1 << 4);
            try testArgs(u32, i5, -1);
            try testArgs(u32, i5, 0);
            try testArgs(u64, i5, -1 << 4);
            try testArgs(u64, i5, -1);
            try testArgs(u64, i5, 0);
            try testArgs(u128, i5, -1 << 4);
            try testArgs(u128, i5, -1);
            try testArgs(u128, i5, 0);
            try testArgs(u256, i5, -1 << 4);
            try testArgs(u256, i5, -1);
            try testArgs(u256, i5, 0);
            try testArgs(u512, i5, -1 << 4);
            try testArgs(u512, i5, -1);
            try testArgs(u512, i5, 0);
            try testArgs(u1024, i5, -1 << 4);
            try testArgs(u1024, i5, -1);
            try testArgs(u1024, i5, 0);
            try testArgs(i8, u5, 0);
            try testArgs(i8, u5, 1 << 0);
            try testArgs(i8, u5, 1 << 4);
            try testArgs(i16, u5, 0);
            try testArgs(i16, u5, 1 << 0);
            try testArgs(i16, u5, 1 << 4);
            try testArgs(i32, u5, 0);
            try testArgs(i32, u5, 1 << 0);
            try testArgs(i32, u5, 1 << 4);
            try testArgs(i64, u5, 0);
            try testArgs(i64, u5, 1 << 0);
            try testArgs(i64, u5, 1 << 4);
            try testArgs(i128, u5, 0);
            try testArgs(i128, u5, 1 << 0);
            try testArgs(i128, u5, 1 << 4);
            try testArgs(i256, u5, 0);
            try testArgs(i256, u5, 1 << 0);
            try testArgs(i256, u5, 1 << 4);
            try testArgs(i512, u5, 0);
            try testArgs(i512, u5, 1 << 0);
            try testArgs(i512, u5, 1 << 4);
            try testArgs(i1024, u5, 0);
            try testArgs(i1024, u5, 1 << 0);
            try testArgs(i1024, u5, 1 << 4);

            try testArgs(u8, i7, -1 << 6);
            try testArgs(u8, i7, -1);
            try testArgs(u8, i7, 0);
            try testArgs(u16, i7, -1 << 6);
            try testArgs(u16, i7, -1);
            try testArgs(u16, i7, 0);
            try testArgs(u32, i7, -1 << 6);
            try testArgs(u32, i7, -1);
            try testArgs(u32, i7, 0);
            try testArgs(u64, i7, -1 << 6);
            try testArgs(u64, i7, -1);
            try testArgs(u64, i7, 0);
            try testArgs(u128, i7, -1 << 6);
            try testArgs(u128, i7, -1);
            try testArgs(u128, i7, 0);
            try testArgs(u256, i7, -1 << 6);
            try testArgs(u256, i7, -1);
            try testArgs(u256, i7, 0);
            try testArgs(u512, i7, -1 << 6);
            try testArgs(u512, i7, -1);
            try testArgs(u512, i7, 0);
            try testArgs(u1024, i7, -1 << 6);
            try testArgs(u1024, i7, -1);
            try testArgs(u1024, i7, 0);
            try testArgs(i8, u7, 0);
            try testArgs(i8, u7, 1 << 0);
            try testArgs(i8, u7, 1 << 6);
            try testArgs(i16, u7, 0);
            try testArgs(i16, u7, 1 << 0);
            try testArgs(i16, u7, 1 << 6);
            try testArgs(i32, u7, 0);
            try testArgs(i32, u7, 1 << 0);
            try testArgs(i32, u7, 1 << 6);
            try testArgs(i64, u7, 0);
            try testArgs(i64, u7, 1 << 0);
            try testArgs(i64, u7, 1 << 6);
            try testArgs(i128, u7, 0);
            try testArgs(i128, u7, 1 << 0);
            try testArgs(i128, u7, 1 << 6);
            try testArgs(i256, u7, 0);
            try testArgs(i256, u7, 1 << 0);
            try testArgs(i256, u7, 1 << 6);
            try testArgs(i512, u7, 0);
            try testArgs(i512, u7, 1 << 0);
            try testArgs(i512, u7, 1 << 6);
            try testArgs(i1024, u7, 0);
            try testArgs(i1024, u7, 1 << 0);
            try testArgs(i1024, u7, 1 << 6);

            try testArgs(u8, i8, -1 << 7);
            try testArgs(u8, i8, -1);
            try testArgs(u8, i8, 0);
            try testArgs(u16, i8, -1 << 7);
            try testArgs(u16, i8, -1);
            try testArgs(u16, i8, 0);
            try testArgs(u32, i8, -1 << 7);
            try testArgs(u32, i8, -1);
            try testArgs(u32, i8, 0);
            try testArgs(u64, i8, -1 << 7);
            try testArgs(u64, i8, -1);
            try testArgs(u64, i8, 0);
            try testArgs(u128, i8, -1 << 7);
            try testArgs(u128, i8, -1);
            try testArgs(u128, i8, 0);
            try testArgs(u256, i8, -1 << 7);
            try testArgs(u256, i8, -1);
            try testArgs(u256, i8, 0);
            try testArgs(u512, i8, -1 << 7);
            try testArgs(u512, i8, -1);
            try testArgs(u512, i8, 0);
            try testArgs(u1024, i8, -1 << 7);
            try testArgs(u1024, i8, -1);
            try testArgs(u1024, i8, 0);
            try testArgs(i8, u8, 0);
            try testArgs(i8, u8, 1 << 0);
            try testArgs(i8, u8, 1 << 7);
            try testArgs(i16, u8, 0);
            try testArgs(i16, u8, 1 << 0);
            try testArgs(i16, u8, 1 << 7);
            try testArgs(i32, u8, 0);
            try testArgs(i32, u8, 1 << 0);
            try testArgs(i32, u8, 1 << 7);
            try testArgs(i64, u8, 0);
            try testArgs(i64, u8, 1 << 0);
            try testArgs(i64, u8, 1 << 7);
            try testArgs(i128, u8, 0);
            try testArgs(i128, u8, 1 << 0);
            try testArgs(i128, u8, 1 << 7);
            try testArgs(i256, u8, 0);
            try testArgs(i256, u8, 1 << 0);
            try testArgs(i256, u8, 1 << 7);
            try testArgs(i512, u8, 0);
            try testArgs(i512, u8, 1 << 0);
            try testArgs(i512, u8, 1 << 7);
            try testArgs(i1024, u8, 0);
            try testArgs(i1024, u8, 1 << 0);
            try testArgs(i1024, u8, 1 << 7);

            try testArgs(u8, i9, -1 << 8);
            try testArgs(u8, i9, -1);
            try testArgs(u8, i9, 0);
            try testArgs(u16, i9, -1 << 8);
            try testArgs(u16, i9, -1);
            try testArgs(u16, i9, 0);
            try testArgs(u32, i9, -1 << 8);
            try testArgs(u32, i9, -1);
            try testArgs(u32, i9, 0);
            try testArgs(u64, i9, -1 << 8);
            try testArgs(u64, i9, -1);
            try testArgs(u64, i9, 0);
            try testArgs(u128, i9, -1 << 8);
            try testArgs(u128, i9, -1);
            try testArgs(u128, i9, 0);
            try testArgs(u256, i9, -1 << 8);
            try testArgs(u256, i9, -1);
            try testArgs(u256, i9, 0);
            try testArgs(u512, i9, -1 << 8);
            try testArgs(u512, i9, -1);
            try testArgs(u512, i9, 0);
            try testArgs(u1024, i9, -1 << 8);
            try testArgs(u1024, i9, -1);
            try testArgs(u1024, i9, 0);
            try testArgs(i8, u9, 0);
            try testArgs(i8, u9, 1 << 0);
            try testArgs(i8, u9, 1 << 8);
            try testArgs(i16, u9, 0);
            try testArgs(i16, u9, 1 << 0);
            try testArgs(i16, u9, 1 << 8);
            try testArgs(i32, u9, 0);
            try testArgs(i32, u9, 1 << 0);
            try testArgs(i32, u9, 1 << 8);
            try testArgs(i64, u9, 0);
            try testArgs(i64, u9, 1 << 0);
            try testArgs(i64, u9, 1 << 8);
            try testArgs(i128, u9, 0);
            try testArgs(i128, u9, 1 << 0);
            try testArgs(i128, u9, 1 << 8);
            try testArgs(i256, u9, 0);
            try testArgs(i256, u9, 1 << 0);
            try testArgs(i256, u9, 1 << 8);
            try testArgs(i512, u9, 0);
            try testArgs(i512, u9, 1 << 0);
            try testArgs(i512, u9, 1 << 8);
            try testArgs(i1024, u9, 0);
            try testArgs(i1024, u9, 1 << 0);
            try testArgs(i1024, u9, 1 << 8);

            try testArgs(u8, i15, -1 << 14);
            try testArgs(u8, i15, -1);
            try testArgs(u8, i15, 0);
            try testArgs(u16, i15, -1 << 14);
            try testArgs(u16, i15, -1);
            try testArgs(u16, i15, 0);
            try testArgs(u32, i15, -1 << 14);
            try testArgs(u32, i15, -1);
            try testArgs(u32, i15, 0);
            try testArgs(u64, i15, -1 << 14);
            try testArgs(u64, i15, -1);
            try testArgs(u64, i15, 0);
            try testArgs(u128, i15, -1 << 14);
            try testArgs(u128, i15, -1);
            try testArgs(u128, i15, 0);
            try testArgs(u256, i15, -1 << 14);
            try testArgs(u256, i15, -1);
            try testArgs(u256, i15, 0);
            try testArgs(u512, i15, -1 << 14);
            try testArgs(u512, i15, -1);
            try testArgs(u512, i15, 0);
            try testArgs(u1024, i15, -1 << 14);
            try testArgs(u1024, i15, -1);
            try testArgs(u1024, i15, 0);
            try testArgs(i8, u15, 0);
            try testArgs(i8, u15, 1 << 0);
            try testArgs(i8, u15, 1 << 14);
            try testArgs(i16, u15, 0);
            try testArgs(i16, u15, 1 << 0);
            try testArgs(i16, u15, 1 << 14);
            try testArgs(i32, u15, 0);
            try testArgs(i32, u15, 1 << 0);
            try testArgs(i32, u15, 1 << 14);
            try testArgs(i64, u15, 0);
            try testArgs(i64, u15, 1 << 0);
            try testArgs(i64, u15, 1 << 14);
            try testArgs(i128, u15, 0);
            try testArgs(i128, u15, 1 << 0);
            try testArgs(i128, u15, 1 << 14);
            try testArgs(i256, u15, 0);
            try testArgs(i256, u15, 1 << 0);
            try testArgs(i256, u15, 1 << 14);
            try testArgs(i512, u15, 0);
            try testArgs(i512, u15, 1 << 0);
            try testArgs(i512, u15, 1 << 14);
            try testArgs(i1024, u15, 0);
            try testArgs(i1024, u15, 1 << 0);
            try testArgs(i1024, u15, 1 << 14);

            try testArgs(u8, i16, -1 << 15);
            try testArgs(u8, i16, -1);
            try testArgs(u8, i16, 0);
            try testArgs(u16, i16, -1 << 15);
            try testArgs(u16, i16, -1);
            try testArgs(u16, i16, 0);
            try testArgs(u32, i16, -1 << 15);
            try testArgs(u32, i16, -1);
            try testArgs(u32, i16, 0);
            try testArgs(u64, i16, -1 << 15);
            try testArgs(u64, i16, -1);
            try testArgs(u64, i16, 0);
            try testArgs(u128, i16, -1 << 15);
            try testArgs(u128, i16, -1);
            try testArgs(u128, i16, 0);
            try testArgs(u256, i16, -1 << 15);
            try testArgs(u256, i16, -1);
            try testArgs(u256, i16, 0);
            try testArgs(u512, i16, -1 << 15);
            try testArgs(u512, i16, -1);
            try testArgs(u512, i16, 0);
            try testArgs(u1024, i16, -1 << 15);
            try testArgs(u1024, i16, -1);
            try testArgs(u1024, i16, 0);
            try testArgs(i8, u16, 0);
            try testArgs(i8, u16, 1 << 0);
            try testArgs(i8, u16, 1 << 15);
            try testArgs(i16, u16, 0);
            try testArgs(i16, u16, 1 << 0);
            try testArgs(i16, u16, 1 << 15);
            try testArgs(i32, u16, 0);
            try testArgs(i32, u16, 1 << 0);
            try testArgs(i32, u16, 1 << 15);
            try testArgs(i64, u16, 0);
            try testArgs(i64, u16, 1 << 0);
            try testArgs(i64, u16, 1 << 15);
            try testArgs(i128, u16, 0);
            try testArgs(i128, u16, 1 << 0);
            try testArgs(i128, u16, 1 << 15);
            try testArgs(i256, u16, 0);
            try testArgs(i256, u16, 1 << 0);
            try testArgs(i256, u16, 1 << 15);
            try testArgs(i512, u16, 0);
            try testArgs(i512, u16, 1 << 0);
            try testArgs(i512, u16, 1 << 15);
            try testArgs(i1024, u16, 0);
            try testArgs(i1024, u16, 1 << 0);
            try testArgs(i1024, u16, 1 << 15);

            try testArgs(u8, i17, -1 << 16);
            try testArgs(u8, i17, -1);
            try testArgs(u8, i17, 0);
            try testArgs(u16, i17, -1 << 16);
            try testArgs(u16, i17, -1);
            try testArgs(u16, i17, 0);
            try testArgs(u32, i17, -1 << 16);
            try testArgs(u32, i17, -1);
            try testArgs(u32, i17, 0);
            try testArgs(u64, i17, -1 << 16);
            try testArgs(u64, i17, -1);
            try testArgs(u64, i17, 0);
            try testArgs(u128, i17, -1 << 16);
            try testArgs(u128, i17, -1);
            try testArgs(u128, i17, 0);
            try testArgs(u256, i17, -1 << 16);
            try testArgs(u256, i17, -1);
            try testArgs(u256, i17, 0);
            try testArgs(u512, i17, -1 << 16);
            try testArgs(u512, i17, -1);
            try testArgs(u512, i17, 0);
            try testArgs(u1024, i17, -1 << 16);
            try testArgs(u1024, i17, -1);
            try testArgs(u1024, i17, 0);
            try testArgs(i8, u17, 0);
            try testArgs(i8, u17, 1 << 0);
            try testArgs(i8, u17, 1 << 16);
            try testArgs(i16, u17, 0);
            try testArgs(i16, u17, 1 << 0);
            try testArgs(i16, u17, 1 << 16);
            try testArgs(i32, u17, 0);
            try testArgs(i32, u17, 1 << 0);
            try testArgs(i32, u17, 1 << 16);
            try testArgs(i64, u17, 0);
            try testArgs(i64, u17, 1 << 0);
            try testArgs(i64, u17, 1 << 16);
            try testArgs(i128, u17, 0);
            try testArgs(i128, u17, 1 << 0);
            try testArgs(i128, u17, 1 << 16);
            try testArgs(i256, u17, 0);
            try testArgs(i256, u17, 1 << 0);
            try testArgs(i256, u17, 1 << 16);
            try testArgs(i512, u17, 0);
            try testArgs(i512, u17, 1 << 0);
            try testArgs(i512, u17, 1 << 16);
            try testArgs(i1024, u17, 0);
            try testArgs(i1024, u17, 1 << 0);
            try testArgs(i1024, u17, 1 << 16);

            try testArgs(u8, i31, -1 << 30);
            try testArgs(u8, i31, -1);
            try testArgs(u8, i31, 0);
            try testArgs(u16, i31, -1 << 30);
            try testArgs(u16, i31, -1);
            try testArgs(u16, i31, 0);
            try testArgs(u32, i31, -1 << 30);
            try testArgs(u32, i31, -1);
            try testArgs(u32, i31, 0);
            try testArgs(u64, i31, -1 << 30);
            try testArgs(u64, i31, -1);
            try testArgs(u64, i31, 0);
            try testArgs(u128, i31, -1 << 30);
            try testArgs(u128, i31, -1);
            try testArgs(u128, i31, 0);
            try testArgs(u256, i31, -1 << 30);
            try testArgs(u256, i31, -1);
            try testArgs(u256, i31, 0);
            try testArgs(u512, i31, -1 << 30);
            try testArgs(u512, i31, -1);
            try testArgs(u512, i31, 0);
            try testArgs(u1024, i31, -1 << 30);
            try testArgs(u1024, i31, -1);
            try testArgs(u1024, i31, 0);
            try testArgs(i8, u31, 0);
            try testArgs(i8, u31, 1 << 0);
            try testArgs(i8, u31, 1 << 30);
            try testArgs(i16, u31, 0);
            try testArgs(i16, u31, 1 << 0);
            try testArgs(i16, u31, 1 << 30);
            try testArgs(i32, u31, 0);
            try testArgs(i32, u31, 1 << 0);
            try testArgs(i32, u31, 1 << 30);
            try testArgs(i64, u31, 0);
            try testArgs(i64, u31, 1 << 0);
            try testArgs(i64, u31, 1 << 30);
            try testArgs(i128, u31, 0);
            try testArgs(i128, u31, 1 << 0);
            try testArgs(i128, u31, 1 << 30);
            try testArgs(i256, u31, 0);
            try testArgs(i256, u31, 1 << 0);
            try testArgs(i256, u31, 1 << 30);
            try testArgs(i512, u31, 0);
            try testArgs(i512, u31, 1 << 0);
            try testArgs(i512, u31, 1 << 30);
            try testArgs(i1024, u31, 0);
            try testArgs(i1024, u31, 1 << 0);
            try testArgs(i1024, u31, 1 << 30);

            try testArgs(u8, i32, -1 << 31);
            try testArgs(u8, i32, -1);
            try testArgs(u8, i32, 0);
            try testArgs(u16, i32, -1 << 31);
            try testArgs(u16, i32, -1);
            try testArgs(u16, i32, 0);
            try testArgs(u32, i32, -1 << 31);
            try testArgs(u32, i32, -1);
            try testArgs(u32, i32, 0);
            try testArgs(u64, i32, -1 << 31);
            try testArgs(u64, i32, -1);
            try testArgs(u64, i32, 0);
            try testArgs(u128, i32, -1 << 31);
            try testArgs(u128, i32, -1);
            try testArgs(u128, i32, 0);
            try testArgs(u256, i32, -1 << 31);
            try testArgs(u256, i32, -1);
            try testArgs(u256, i32, 0);
            try testArgs(u512, i32, -1 << 31);
            try testArgs(u512, i32, -1);
            try testArgs(u512, i32, 0);
            try testArgs(u1024, i32, -1 << 31);
            try testArgs(u1024, i32, -1);
            try testArgs(u1024, i32, 0);
            try testArgs(i8, u32, 0);
            try testArgs(i8, u32, 1 << 0);
            try testArgs(i8, u32, 1 << 31);
            try testArgs(i16, u32, 0);
            try testArgs(i16, u32, 1 << 0);
            try testArgs(i16, u32, 1 << 31);
            try testArgs(i32, u32, 0);
            try testArgs(i32, u32, 1 << 0);
            try testArgs(i32, u32, 1 << 31);
            try testArgs(i64, u32, 0);
            try testArgs(i64, u32, 1 << 0);
            try testArgs(i64, u32, 1 << 31);
            try testArgs(i128, u32, 0);
            try testArgs(i128, u32, 1 << 0);
            try testArgs(i128, u32, 1 << 31);
            try testArgs(i256, u32, 0);
            try testArgs(i256, u32, 1 << 0);
            try testArgs(i256, u32, 1 << 31);
            try testArgs(i512, u32, 0);
            try testArgs(i512, u32, 1 << 0);
            try testArgs(i512, u32, 1 << 31);
            try testArgs(i1024, u32, 0);
            try testArgs(i1024, u32, 1 << 0);
            try testArgs(i1024, u32, 1 << 31);

            try testArgs(u8, i33, -1 << 32);
            try testArgs(u8, i33, -1);
            try testArgs(u8, i33, 0);
            try testArgs(u16, i33, -1 << 32);
            try testArgs(u16, i33, -1);
            try testArgs(u16, i33, 0);
            try testArgs(u32, i33, -1 << 32);
            try testArgs(u32, i33, -1);
            try testArgs(u32, i33, 0);
            try testArgs(u64, i33, -1 << 32);
            try testArgs(u64, i33, -1);
            try testArgs(u64, i33, 0);
            try testArgs(u128, i33, -1 << 32);
            try testArgs(u128, i33, -1);
            try testArgs(u128, i33, 0);
            try testArgs(u256, i33, -1 << 32);
            try testArgs(u256, i33, -1);
            try testArgs(u256, i33, 0);
            try testArgs(u512, i33, -1 << 32);
            try testArgs(u512, i33, -1);
            try testArgs(u512, i33, 0);
            try testArgs(u1024, i33, -1 << 32);
            try testArgs(u1024, i33, -1);
            try testArgs(u1024, i33, 0);
            try testArgs(i8, u33, 0);
            try testArgs(i8, u33, 1 << 0);
            try testArgs(i8, u33, 1 << 32);
            try testArgs(i16, u33, 0);
            try testArgs(i16, u33, 1 << 0);
            try testArgs(i16, u33, 1 << 32);
            try testArgs(i32, u33, 0);
            try testArgs(i32, u33, 1 << 0);
            try testArgs(i32, u33, 1 << 32);
            try testArgs(i64, u33, 0);
            try testArgs(i64, u33, 1 << 0);
            try testArgs(i64, u33, 1 << 32);
            try testArgs(i128, u33, 0);
            try testArgs(i128, u33, 1 << 0);
            try testArgs(i128, u33, 1 << 32);
            try testArgs(i256, u33, 0);
            try testArgs(i256, u33, 1 << 0);
            try testArgs(i256, u33, 1 << 32);
            try testArgs(i512, u33, 0);
            try testArgs(i512, u33, 1 << 0);
            try testArgs(i512, u33, 1 << 32);
            try testArgs(i1024, u33, 0);
            try testArgs(i1024, u33, 1 << 0);
            try testArgs(i1024, u33, 1 << 32);

            try testArgs(u8, i63, -1 << 62);
            try testArgs(u8, i63, -1);
            try testArgs(u8, i63, 0);
            try testArgs(u16, i63, -1 << 62);
            try testArgs(u16, i63, -1);
            try testArgs(u16, i63, 0);
            try testArgs(u32, i63, -1 << 62);
            try testArgs(u32, i63, -1);
            try testArgs(u32, i63, 0);
            try testArgs(u64, i63, -1 << 62);
            try testArgs(u64, i63, -1);
            try testArgs(u64, i63, 0);
            try testArgs(u128, i63, -1 << 62);
            try testArgs(u128, i63, -1);
            try testArgs(u128, i63, 0);
            try testArgs(u256, i63, -1 << 62);
            try testArgs(u256, i63, -1);
            try testArgs(u256, i63, 0);
            try testArgs(u512, i63, -1 << 62);
            try testArgs(u512, i63, -1);
            try testArgs(u512, i63, 0);
            try testArgs(u1024, i63, -1 << 62);
            try testArgs(u1024, i63, -1);
            try testArgs(u1024, i63, 0);
            try testArgs(i8, u63, 0);
            try testArgs(i8, u63, 1 << 0);
            try testArgs(i8, u63, 1 << 62);
            try testArgs(i16, u63, 0);
            try testArgs(i16, u63, 1 << 0);
            try testArgs(i16, u63, 1 << 62);
            try testArgs(i32, u63, 0);
            try testArgs(i32, u63, 1 << 0);
            try testArgs(i32, u63, 1 << 62);
            try testArgs(i64, u63, 0);
            try testArgs(i64, u63, 1 << 0);
            try testArgs(i64, u63, 1 << 62);
            try testArgs(i128, u63, 0);
            try testArgs(i128, u63, 1 << 0);
            try testArgs(i128, u63, 1 << 62);
            try testArgs(i256, u63, 0);
            try testArgs(i256, u63, 1 << 0);
            try testArgs(i256, u63, 1 << 62);
            try testArgs(i512, u63, 0);
            try testArgs(i512, u63, 1 << 0);
            try testArgs(i512, u63, 1 << 62);
            try testArgs(i1024, u63, 0);
            try testArgs(i1024, u63, 1 << 0);
            try testArgs(i1024, u63, 1 << 62);

            try testArgs(u8, i64, -1 << 63);
            try testArgs(u8, i64, -1);
            try testArgs(u8, i64, 0);
            try testArgs(u16, i64, -1 << 63);
            try testArgs(u16, i64, -1);
            try testArgs(u16, i64, 0);
            try testArgs(u32, i64, -1 << 63);
            try testArgs(u32, i64, -1);
            try testArgs(u32, i64, 0);
            try testArgs(u64, i64, -1 << 63);
            try testArgs(u64, i64, -1);
            try testArgs(u64, i64, 0);
            try testArgs(u128, i64, -1 << 63);
            try testArgs(u128, i64, -1);
            try testArgs(u128, i64, 0);
            try testArgs(u256, i64, -1 << 63);
            try testArgs(u256, i64, -1);
            try testArgs(u256, i64, 0);
            try testArgs(u512, i64, -1 << 63);
            try testArgs(u512, i64, -1);
            try testArgs(u512, i64, 0);
            try testArgs(u1024, i64, -1 << 63);
            try testArgs(u1024, i64, -1);
            try testArgs(u1024, i64, 0);
            try testArgs(i8, u64, 0);
            try testArgs(i8, u64, 1 << 0);
            try testArgs(i8, u64, 1 << 63);
            try testArgs(i16, u64, 0);
            try testArgs(i16, u64, 1 << 0);
            try testArgs(i16, u64, 1 << 63);
            try testArgs(i32, u64, 0);
            try testArgs(i32, u64, 1 << 0);
            try testArgs(i32, u64, 1 << 63);
            try testArgs(i64, u64, 0);
            try testArgs(i64, u64, 1 << 0);
            try testArgs(i64, u64, 1 << 63);
            try testArgs(i128, u64, 0);
            try testArgs(i128, u64, 1 << 0);
            try testArgs(i128, u64, 1 << 63);
            try testArgs(i256, u64, 0);
            try testArgs(i256, u64, 1 << 0);
            try testArgs(i256, u64, 1 << 63);
            try testArgs(i512, u64, 0);
            try testArgs(i512, u64, 1 << 0);
            try testArgs(i512, u64, 1 << 63);
            try testArgs(i1024, u64, 0);
            try testArgs(i1024, u64, 1 << 0);
            try testArgs(i1024, u64, 1 << 63);

            try testArgs(u8, i65, -1 << 64);
            try testArgs(u8, i65, -1);
            try testArgs(u8, i65, 0);
            try testArgs(u16, i65, -1 << 64);
            try testArgs(u16, i65, -1);
            try testArgs(u16, i65, 0);
            try testArgs(u32, i65, -1 << 64);
            try testArgs(u32, i65, -1);
            try testArgs(u32, i65, 0);
            try testArgs(u64, i65, -1 << 64);
            try testArgs(u64, i65, -1);
            try testArgs(u64, i65, 0);
            try testArgs(u128, i65, -1 << 64);
            try testArgs(u128, i65, -1);
            try testArgs(u128, i65, 0);
            try testArgs(u256, i65, -1 << 64);
            try testArgs(u256, i65, -1);
            try testArgs(u256, i65, 0);
            try testArgs(u512, i65, -1 << 64);
            try testArgs(u512, i65, -1);
            try testArgs(u512, i65, 0);
            try testArgs(u1024, i65, -1 << 64);
            try testArgs(u1024, i65, -1);
            try testArgs(u1024, i65, 0);
            try testArgs(i8, u65, 0);
            try testArgs(i8, u65, 1 << 0);
            try testArgs(i8, u65, 1 << 64);
            try testArgs(i16, u65, 0);
            try testArgs(i16, u65, 1 << 0);
            try testArgs(i16, u65, 1 << 64);
            try testArgs(i32, u65, 0);
            try testArgs(i32, u65, 1 << 0);
            try testArgs(i32, u65, 1 << 64);
            try testArgs(i64, u65, 0);
            try testArgs(i64, u65, 1 << 0);
            try testArgs(i64, u65, 1 << 64);
            try testArgs(i128, u65, 0);
            try testArgs(i128, u65, 1 << 0);
            try testArgs(i128, u65, 1 << 64);
            try testArgs(i256, u65, 0);
            try testArgs(i256, u65, 1 << 0);
            try testArgs(i256, u65, 1 << 64);
            try testArgs(i512, u65, 0);
            try testArgs(i512, u65, 1 << 0);
            try testArgs(i512, u65, 1 << 64);
            try testArgs(i1024, u65, 0);
            try testArgs(i1024, u65, 1 << 0);
            try testArgs(i1024, u65, 1 << 64);

            try testArgs(u8, i95, -1 << 94);
            try testArgs(u8, i95, -1);
            try testArgs(u8, i95, 0);
            try testArgs(u16, i95, -1 << 94);
            try testArgs(u16, i95, -1);
            try testArgs(u16, i95, 0);
            try testArgs(u32, i95, -1 << 94);
            try testArgs(u32, i95, -1);
            try testArgs(u32, i95, 0);
            try testArgs(u64, i95, -1 << 94);
            try testArgs(u64, i95, -1);
            try testArgs(u64, i95, 0);
            try testArgs(u128, i95, -1 << 94);
            try testArgs(u128, i95, -1);
            try testArgs(u128, i95, 0);
            try testArgs(u256, i95, -1 << 94);
            try testArgs(u256, i95, -1);
            try testArgs(u256, i95, 0);
            try testArgs(u512, i95, -1 << 94);
            try testArgs(u512, i95, -1);
            try testArgs(u512, i95, 0);
            try testArgs(u1024, i95, -1 << 94);
            try testArgs(u1024, i95, -1);
            try testArgs(u1024, i95, 0);
            try testArgs(i8, u95, 0);
            try testArgs(i8, u95, 1 << 0);
            try testArgs(i8, u95, 1 << 94);
            try testArgs(i16, u95, 0);
            try testArgs(i16, u95, 1 << 0);
            try testArgs(i16, u95, 1 << 94);
            try testArgs(i32, u95, 0);
            try testArgs(i32, u95, 1 << 0);
            try testArgs(i32, u95, 1 << 94);
            try testArgs(i64, u95, 0);
            try testArgs(i64, u95, 1 << 0);
            try testArgs(i64, u95, 1 << 94);
            try testArgs(i128, u95, 0);
            try testArgs(i128, u95, 1 << 0);
            try testArgs(i128, u95, 1 << 94);
            try testArgs(i256, u95, 0);
            try testArgs(i256, u95, 1 << 0);
            try testArgs(i256, u95, 1 << 94);
            try testArgs(i512, u95, 0);
            try testArgs(i512, u95, 1 << 0);
            try testArgs(i512, u95, 1 << 94);
            try testArgs(i1024, u95, 0);
            try testArgs(i1024, u95, 1 << 0);
            try testArgs(i1024, u95, 1 << 94);

            try testArgs(u8, i96, -1 << 95);
            try testArgs(u8, i96, -1);
            try testArgs(u8, i96, 0);
            try testArgs(u16, i96, -1 << 95);
            try testArgs(u16, i96, -1);
            try testArgs(u16, i96, 0);
            try testArgs(u32, i96, -1 << 95);
            try testArgs(u32, i96, -1);
            try testArgs(u32, i96, 0);
            try testArgs(u64, i96, -1 << 95);
            try testArgs(u64, i96, -1);
            try testArgs(u64, i96, 0);
            try testArgs(u128, i96, -1 << 95);
            try testArgs(u128, i96, -1);
            try testArgs(u128, i96, 0);
            try testArgs(u256, i96, -1 << 95);
            try testArgs(u256, i96, -1);
            try testArgs(u256, i96, 0);
            try testArgs(u512, i96, -1 << 95);
            try testArgs(u512, i96, -1);
            try testArgs(u512, i96, 0);
            try testArgs(u1024, i96, -1 << 95);
            try testArgs(u1024, i96, -1);
            try testArgs(u1024, i96, 0);
            try testArgs(i8, u96, 0);
            try testArgs(i8, u96, 1 << 0);
            try testArgs(i8, u96, 1 << 95);
            try testArgs(i16, u96, 0);
            try testArgs(i16, u96, 1 << 0);
            try testArgs(i16, u96, 1 << 95);
            try testArgs(i32, u96, 0);
            try testArgs(i32, u96, 1 << 0);
            try testArgs(i32, u96, 1 << 95);
            try testArgs(i64, u96, 0);
            try testArgs(i64, u96, 1 << 0);
            try testArgs(i64, u96, 1 << 95);
            try testArgs(i128, u96, 0);
            try testArgs(i128, u96, 1 << 0);
            try testArgs(i128, u96, 1 << 95);
            try testArgs(i256, u96, 0);
            try testArgs(i256, u96, 1 << 0);
            try testArgs(i256, u96, 1 << 95);
            try testArgs(i512, u96, 0);
            try testArgs(i512, u96, 1 << 0);
            try testArgs(i512, u96, 1 << 95);
            try testArgs(i1024, u96, 0);
            try testArgs(i1024, u96, 1 << 0);
            try testArgs(i1024, u96, 1 << 95);

            try testArgs(u8, i97, -1 << 96);
            try testArgs(u8, i97, -1);
            try testArgs(u8, i97, 0);
            try testArgs(u16, i97, -1 << 96);
            try testArgs(u16, i97, -1);
            try testArgs(u16, i97, 0);
            try testArgs(u32, i97, -1 << 96);
            try testArgs(u32, i97, -1);
            try testArgs(u32, i97, 0);
            try testArgs(u64, i97, -1 << 96);
            try testArgs(u64, i97, -1);
            try testArgs(u64, i97, 0);
            try testArgs(u128, i97, -1 << 96);
            try testArgs(u128, i97, -1);
            try testArgs(u128, i97, 0);
            try testArgs(u256, i97, -1 << 96);
            try testArgs(u256, i97, -1);
            try testArgs(u256, i97, 0);
            try testArgs(u512, i97, -1 << 96);
            try testArgs(u512, i97, -1);
            try testArgs(u512, i97, 0);
            try testArgs(u1024, i97, -1 << 96);
            try testArgs(u1024, i97, -1);
            try testArgs(u1024, i97, 0);
            try testArgs(i8, u97, 0);
            try testArgs(i8, u97, 1 << 0);
            try testArgs(i8, u97, 1 << 96);
            try testArgs(i16, u97, 0);
            try testArgs(i16, u97, 1 << 0);
            try testArgs(i16, u97, 1 << 96);
            try testArgs(i32, u97, 0);
            try testArgs(i32, u97, 1 << 0);
            try testArgs(i32, u97, 1 << 96);
            try testArgs(i64, u97, 0);
            try testArgs(i64, u97, 1 << 0);
            try testArgs(i64, u97, 1 << 96);
            try testArgs(i128, u97, 0);
            try testArgs(i128, u97, 1 << 0);
            try testArgs(i128, u97, 1 << 96);
            try testArgs(i256, u97, 0);
            try testArgs(i256, u97, 1 << 0);
            try testArgs(i256, u97, 1 << 96);
            try testArgs(i512, u97, 0);
            try testArgs(i512, u97, 1 << 0);
            try testArgs(i512, u97, 1 << 96);
            try testArgs(i1024, u97, 0);
            try testArgs(i1024, u97, 1 << 0);
            try testArgs(i1024, u97, 1 << 96);

            try testArgs(u8, i127, -1 << 126);
            try testArgs(u8, i127, -1);
            try testArgs(u8, i127, 0);
            try testArgs(u16, i127, -1 << 126);
            try testArgs(u16, i127, -1);
            try testArgs(u16, i127, 0);
            try testArgs(u32, i127, -1 << 126);
            try testArgs(u32, i127, -1);
            try testArgs(u32, i127, 0);
            try testArgs(u64, i127, -1 << 126);
            try testArgs(u64, i127, -1);
            try testArgs(u64, i127, 0);
            try testArgs(u128, i127, -1 << 126);
            try testArgs(u128, i127, -1);
            try testArgs(u128, i127, 0);
            try testArgs(u256, i127, -1 << 126);
            try testArgs(u256, i127, -1);
            try testArgs(u256, i127, 0);
            try testArgs(u512, i127, -1 << 126);
            try testArgs(u512, i127, -1);
            try testArgs(u512, i127, 0);
            try testArgs(u1024, i127, -1 << 126);
            try testArgs(u1024, i127, -1);
            try testArgs(u1024, i127, 0);
            try testArgs(i8, u127, 0);
            try testArgs(i8, u127, 1 << 0);
            try testArgs(i8, u127, 1 << 126);
            try testArgs(i16, u127, 0);
            try testArgs(i16, u127, 1 << 0);
            try testArgs(i16, u127, 1 << 126);
            try testArgs(i32, u127, 0);
            try testArgs(i32, u127, 1 << 0);
            try testArgs(i32, u127, 1 << 126);
            try testArgs(i64, u127, 0);
            try testArgs(i64, u127, 1 << 0);
            try testArgs(i64, u127, 1 << 126);
            try testArgs(i128, u127, 0);
            try testArgs(i128, u127, 1 << 0);
            try testArgs(i128, u127, 1 << 126);
            try testArgs(i256, u127, 0);
            try testArgs(i256, u127, 1 << 0);
            try testArgs(i256, u127, 1 << 126);
            try testArgs(i512, u127, 0);
            try testArgs(i512, u127, 1 << 0);
            try testArgs(i512, u127, 1 << 126);
            try testArgs(i1024, u127, 0);
            try testArgs(i1024, u127, 1 << 0);
            try testArgs(i1024, u127, 1 << 126);

            try testArgs(u8, i128, -1 << 127);
            try testArgs(u8, i128, -1);
            try testArgs(u8, i128, 0);
            try testArgs(u16, i128, -1 << 127);
            try testArgs(u16, i128, -1);
            try testArgs(u16, i128, 0);
            try testArgs(u32, i128, -1 << 127);
            try testArgs(u32, i128, -1);
            try testArgs(u32, i128, 0);
            try testArgs(u64, i128, -1 << 127);
            try testArgs(u64, i128, -1);
            try testArgs(u64, i128, 0);
            try testArgs(u128, i128, -1 << 127);
            try testArgs(u128, i128, -1);
            try testArgs(u128, i128, 0);
            try testArgs(u256, i128, -1 << 127);
            try testArgs(u256, i128, -1);
            try testArgs(u256, i128, 0);
            try testArgs(u512, i128, -1 << 127);
            try testArgs(u512, i128, -1);
            try testArgs(u512, i128, 0);
            try testArgs(u1024, i128, -1 << 127);
            try testArgs(u1024, i128, -1);
            try testArgs(u1024, i128, 0);
            try testArgs(i8, u128, 0);
            try testArgs(i8, u128, 1 << 0);
            try testArgs(i8, u128, 1 << 127);
            try testArgs(i16, u128, 0);
            try testArgs(i16, u128, 1 << 0);
            try testArgs(i16, u128, 1 << 127);
            try testArgs(i32, u128, 0);
            try testArgs(i32, u128, 1 << 0);
            try testArgs(i32, u128, 1 << 127);
            try testArgs(i64, u128, 0);
            try testArgs(i64, u128, 1 << 0);
            try testArgs(i64, u128, 1 << 127);
            try testArgs(i128, u128, 0);
            try testArgs(i128, u128, 1 << 0);
            try testArgs(i128, u128, 1 << 127);
            try testArgs(i256, u128, 0);
            try testArgs(i256, u128, 1 << 0);
            try testArgs(i256, u128, 1 << 127);
            try testArgs(i512, u128, 0);
            try testArgs(i512, u128, 1 << 0);
            try testArgs(i512, u128, 1 << 127);
            try testArgs(i1024, u128, 0);
            try testArgs(i1024, u128, 1 << 0);
            try testArgs(i1024, u128, 1 << 127);

            try testArgs(u8, i129, -1 << 128);
            try testArgs(u8, i129, -1);
            try testArgs(u8, i129, 0);
            try testArgs(u16, i129, -1 << 128);
            try testArgs(u16, i129, -1);
            try testArgs(u16, i129, 0);
            try testArgs(u32, i129, -1 << 128);
            try testArgs(u32, i129, -1);
            try testArgs(u32, i129, 0);
            try testArgs(u64, i129, -1 << 128);
            try testArgs(u64, i129, -1);
            try testArgs(u64, i129, 0);
            try testArgs(u128, i129, -1 << 128);
            try testArgs(u128, i129, -1);
            try testArgs(u128, i129, 0);
            try testArgs(u256, i129, -1 << 128);
            try testArgs(u256, i129, -1);
            try testArgs(u256, i129, 0);
            try testArgs(u512, i129, -1 << 128);
            try testArgs(u512, i129, -1);
            try testArgs(u512, i129, 0);
            try testArgs(u1024, i129, -1 << 128);
            try testArgs(u1024, i129, -1);
            try testArgs(u1024, i129, 0);
            try testArgs(i8, u129, 0);
            try testArgs(i8, u129, 1 << 0);
            try testArgs(i8, u129, 1 << 128);
            try testArgs(i16, u129, 0);
            try testArgs(i16, u129, 1 << 0);
            try testArgs(i16, u129, 1 << 128);
            try testArgs(i32, u129, 0);
            try testArgs(i32, u129, 1 << 0);
            try testArgs(i32, u129, 1 << 128);
            try testArgs(i64, u129, 0);
            try testArgs(i64, u129, 1 << 0);
            try testArgs(i64, u129, 1 << 128);
            try testArgs(i128, u129, 0);
            try testArgs(i128, u129, 1 << 0);
            try testArgs(i128, u129, 1 << 128);
            try testArgs(i256, u129, 0);
            try testArgs(i256, u129, 1 << 0);
            try testArgs(i256, u129, 1 << 128);
            try testArgs(i512, u129, 0);
            try testArgs(i512, u129, 1 << 0);
            try testArgs(i512, u129, 1 << 128);
            try testArgs(i1024, u129, 0);
            try testArgs(i1024, u129, 1 << 0);
            try testArgs(i1024, u129, 1 << 128);

            try testArgs(u8, i255, -1 << 254);
            try testArgs(u8, i255, -1);
            try testArgs(u8, i255, 0);
            try testArgs(u16, i255, -1 << 254);
            try testArgs(u16, i255, -1);
            try testArgs(u16, i255, 0);
            try testArgs(u32, i255, -1 << 254);
            try testArgs(u32, i255, -1);
            try testArgs(u32, i255, 0);
            try testArgs(u64, i255, -1 << 254);
            try testArgs(u64, i255, -1);
            try testArgs(u64, i255, 0);
            try testArgs(u128, i255, -1 << 254);
            try testArgs(u128, i255, -1);
            try testArgs(u128, i255, 0);
            try testArgs(u256, i255, -1 << 254);
            try testArgs(u256, i255, -1);
            try testArgs(u256, i255, 0);
            try testArgs(u512, i255, -1 << 254);
            try testArgs(u512, i255, -1);
            try testArgs(u512, i255, 0);
            try testArgs(u1024, i255, -1 << 254);
            try testArgs(u1024, i255, -1);
            try testArgs(u1024, i255, 0);
            try testArgs(i8, u255, 0);
            try testArgs(i8, u255, 1 << 0);
            try testArgs(i8, u255, 1 << 254);
            try testArgs(i16, u255, 0);
            try testArgs(i16, u255, 1 << 0);
            try testArgs(i16, u255, 1 << 254);
            try testArgs(i32, u255, 0);
            try testArgs(i32, u255, 1 << 0);
            try testArgs(i32, u255, 1 << 254);
            try testArgs(i64, u255, 0);
            try testArgs(i64, u255, 1 << 0);
            try testArgs(i64, u255, 1 << 254);
            try testArgs(i128, u255, 0);
            try testArgs(i128, u255, 1 << 0);
            try testArgs(i128, u255, 1 << 254);
            try testArgs(i256, u255, 0);
            try testArgs(i256, u255, 1 << 0);
            try testArgs(i256, u255, 1 << 254);
            try testArgs(i512, u255, 0);
            try testArgs(i512, u255, 1 << 0);
            try testArgs(i512, u255, 1 << 254);
            try testArgs(i1024, u255, 0);
            try testArgs(i1024, u255, 1 << 0);
            try testArgs(i1024, u255, 1 << 254);

            try testArgs(u8, i256, -1 << 255);
            try testArgs(u8, i256, -1);
            try testArgs(u8, i256, 0);
            try testArgs(u16, i256, -1 << 255);
            try testArgs(u16, i256, -1);
            try testArgs(u16, i256, 0);
            try testArgs(u32, i256, -1 << 255);
            try testArgs(u32, i256, -1);
            try testArgs(u32, i256, 0);
            try testArgs(u64, i256, -1 << 255);
            try testArgs(u64, i256, -1);
            try testArgs(u64, i256, 0);
            try testArgs(u128, i256, -1 << 255);
            try testArgs(u128, i256, -1);
            try testArgs(u128, i256, 0);
            try testArgs(u256, i256, -1 << 255);
            try testArgs(u256, i256, -1);
            try testArgs(u256, i256, 0);
            try testArgs(u512, i256, -1 << 255);
            try testArgs(u512, i256, -1);
            try testArgs(u512, i256, 0);
            try testArgs(u1024, i256, -1 << 255);
            try testArgs(u1024, i256, -1);
            try testArgs(u1024, i256, 0);
            try testArgs(i8, u256, 0);
            try testArgs(i8, u256, 1 << 0);
            try testArgs(i8, u256, 1 << 255);
            try testArgs(i16, u256, 0);
            try testArgs(i16, u256, 1 << 0);
            try testArgs(i16, u256, 1 << 255);
            try testArgs(i32, u256, 0);
            try testArgs(i32, u256, 1 << 0);
            try testArgs(i32, u256, 1 << 255);
            try testArgs(i64, u256, 0);
            try testArgs(i64, u256, 1 << 0);
            try testArgs(i64, u256, 1 << 255);
            try testArgs(i128, u256, 0);
            try testArgs(i128, u256, 1 << 0);
            try testArgs(i128, u256, 1 << 255);
            try testArgs(i256, u256, 0);
            try testArgs(i256, u256, 1 << 0);
            try testArgs(i256, u256, 1 << 255);
            try testArgs(i512, u256, 0);
            try testArgs(i512, u256, 1 << 0);
            try testArgs(i512, u256, 1 << 255);
            try testArgs(i1024, u256, 0);
            try testArgs(i1024, u256, 1 << 0);
            try testArgs(i1024, u256, 1 << 255);

            try testArgs(u8, i257, -1 << 256);
            try testArgs(u8, i257, -1);
            try testArgs(u8, i257, 0);
            try testArgs(u16, i257, -1 << 256);
            try testArgs(u16, i257, -1);
            try testArgs(u16, i257, 0);
            try testArgs(u32, i257, -1 << 256);
            try testArgs(u32, i257, -1);
            try testArgs(u32, i257, 0);
            try testArgs(u64, i257, -1 << 256);
            try testArgs(u64, i257, -1);
            try testArgs(u64, i257, 0);
            try testArgs(u128, i257, -1 << 256);
            try testArgs(u128, i257, -1);
            try testArgs(u128, i257, 0);
            try testArgs(u256, i257, -1 << 256);
            try testArgs(u256, i257, -1);
            try testArgs(u256, i257, 0);
            try testArgs(u512, i257, -1 << 256);
            try testArgs(u512, i257, -1);
            try testArgs(u512, i257, 0);
            try testArgs(u1024, i257, -1 << 256);
            try testArgs(u1024, i257, -1);
            try testArgs(u1024, i257, 0);
            try testArgs(i8, u257, 0);
            try testArgs(i8, u257, 1 << 0);
            try testArgs(i8, u257, 1 << 256);
            try testArgs(i16, u257, 0);
            try testArgs(i16, u257, 1 << 0);
            try testArgs(i16, u257, 1 << 256);
            try testArgs(i32, u257, 0);
            try testArgs(i32, u257, 1 << 0);
            try testArgs(i32, u257, 1 << 256);
            try testArgs(i64, u257, 0);
            try testArgs(i64, u257, 1 << 0);
            try testArgs(i64, u257, 1 << 256);
            try testArgs(i128, u257, 0);
            try testArgs(i128, u257, 1 << 0);
            try testArgs(i128, u257, 1 << 256);
            try testArgs(i256, u257, 0);
            try testArgs(i256, u257, 1 << 0);
            try testArgs(i256, u257, 1 << 256);
            try testArgs(i512, u257, 0);
            try testArgs(i512, u257, 1 << 0);
            try testArgs(i512, u257, 1 << 256);
            try testArgs(i1024, u257, 0);
            try testArgs(i1024, u257, 1 << 0);
            try testArgs(i1024, u257, 1 << 256);

            try testArgs(u8, i511, -1 << 510);
            try testArgs(u8, i511, -1);
            try testArgs(u8, i511, 0);
            try testArgs(u16, i511, -1 << 510);
            try testArgs(u16, i511, -1);
            try testArgs(u16, i511, 0);
            try testArgs(u32, i511, -1 << 510);
            try testArgs(u32, i511, -1);
            try testArgs(u32, i511, 0);
            try testArgs(u64, i511, -1 << 510);
            try testArgs(u64, i511, -1);
            try testArgs(u64, i511, 0);
            try testArgs(u128, i511, -1 << 510);
            try testArgs(u128, i511, -1);
            try testArgs(u128, i511, 0);
            try testArgs(u256, i511, -1 << 510);
            try testArgs(u256, i511, -1);
            try testArgs(u256, i511, 0);
            try testArgs(u512, i511, -1 << 510);
            try testArgs(u512, i511, -1);
            try testArgs(u512, i511, 0);
            try testArgs(u1024, i511, -1 << 510);
            try testArgs(u1024, i511, -1);
            try testArgs(u1024, i511, 0);
            try testArgs(i8, u511, 0);
            try testArgs(i8, u511, 1 << 0);
            try testArgs(i8, u511, 1 << 510);
            try testArgs(i16, u511, 0);
            try testArgs(i16, u511, 1 << 0);
            try testArgs(i16, u511, 1 << 510);
            try testArgs(i32, u511, 0);
            try testArgs(i32, u511, 1 << 0);
            try testArgs(i32, u511, 1 << 510);
            try testArgs(i64, u511, 0);
            try testArgs(i64, u511, 1 << 0);
            try testArgs(i64, u511, 1 << 510);
            try testArgs(i128, u511, 0);
            try testArgs(i128, u511, 1 << 0);
            try testArgs(i128, u511, 1 << 510);
            try testArgs(i256, u511, 0);
            try testArgs(i256, u511, 1 << 0);
            try testArgs(i256, u511, 1 << 510);
            try testArgs(i512, u511, 0);
            try testArgs(i512, u511, 1 << 0);
            try testArgs(i512, u511, 1 << 510);
            try testArgs(i1024, u511, 0);
            try testArgs(i1024, u511, 1 << 0);
            try testArgs(i1024, u511, 1 << 510);

            try testArgs(u8, i512, -1 << 511);
            try testArgs(u8, i512, -1);
            try testArgs(u8, i512, 0);
            try testArgs(u16, i512, -1 << 511);
            try testArgs(u16, i512, -1);
            try testArgs(u16, i512, 0);
            try testArgs(u32, i512, -1 << 511);
            try testArgs(u32, i512, -1);
            try testArgs(u32, i512, 0);
            try testArgs(u64, i512, -1 << 511);
            try testArgs(u64, i512, -1);
            try testArgs(u64, i512, 0);
            try testArgs(u128, i512, -1 << 511);
            try testArgs(u128, i512, -1);
            try testArgs(u128, i512, 0);
            try testArgs(u256, i512, -1 << 511);
            try testArgs(u256, i512, -1);
            try testArgs(u256, i512, 0);
            try testArgs(u512, i512, -1 << 511);
            try testArgs(u512, i512, -1);
            try testArgs(u512, i512, 0);
            try testArgs(u1024, i512, -1 << 511);
            try testArgs(u1024, i512, -1);
            try testArgs(u1024, i512, 0);
            try testArgs(i8, u512, 0);
            try testArgs(i8, u512, 1 << 0);
            try testArgs(i8, u512, 1 << 511);
            try testArgs(i16, u512, 0);
            try testArgs(i16, u512, 1 << 0);
            try testArgs(i16, u512, 1 << 511);
            try testArgs(i32, u512, 0);
            try testArgs(i32, u512, 1 << 0);
            try testArgs(i32, u512, 1 << 511);
            try testArgs(i64, u512, 0);
            try testArgs(i64, u512, 1 << 0);
            try testArgs(i64, u512, 1 << 511);
            try testArgs(i128, u512, 0);
            try testArgs(i128, u512, 1 << 0);
            try testArgs(i128, u512, 1 << 511);
            try testArgs(i256, u512, 0);
            try testArgs(i256, u512, 1 << 0);
            try testArgs(i256, u512, 1 << 511);
            try testArgs(i512, u512, 0);
            try testArgs(i512, u512, 1 << 0);
            try testArgs(i512, u512, 1 << 511);
            try testArgs(i1024, u512, 0);
            try testArgs(i1024, u512, 1 << 0);
            try testArgs(i1024, u512, 1 << 511);

            try testArgs(u8, i513, -1 << 512);
            try testArgs(u8, i513, -1);
            try testArgs(u8, i513, 0);
            try testArgs(u16, i513, -1 << 512);
            try testArgs(u16, i513, -1);
            try testArgs(u16, i513, 0);
            try testArgs(u32, i513, -1 << 512);
            try testArgs(u32, i513, -1);
            try testArgs(u32, i513, 0);
            try testArgs(u64, i513, -1 << 512);
            try testArgs(u64, i513, -1);
            try testArgs(u64, i513, 0);
            try testArgs(u128, i513, -1 << 512);
            try testArgs(u128, i513, -1);
            try testArgs(u128, i513, 0);
            try testArgs(u256, i513, -1 << 512);
            try testArgs(u256, i513, -1);
            try testArgs(u256, i513, 0);
            try testArgs(u512, i513, -1 << 512);
            try testArgs(u512, i513, -1);
            try testArgs(u512, i513, 0);
            try testArgs(u1024, i513, -1 << 512);
            try testArgs(u1024, i513, -1);
            try testArgs(u1024, i513, 0);
            try testArgs(i8, u513, 0);
            try testArgs(i8, u513, 1 << 0);
            try testArgs(i8, u513, 1 << 512);
            try testArgs(i16, u513, 0);
            try testArgs(i16, u513, 1 << 0);
            try testArgs(i16, u513, 1 << 512);
            try testArgs(i32, u513, 0);
            try testArgs(i32, u513, 1 << 0);
            try testArgs(i32, u513, 1 << 512);
            try testArgs(i64, u513, 0);
            try testArgs(i64, u513, 1 << 0);
            try testArgs(i64, u513, 1 << 512);
            try testArgs(i128, u513, 0);
            try testArgs(i128, u513, 1 << 0);
            try testArgs(i128, u513, 1 << 512);
            try testArgs(i256, u513, 0);
            try testArgs(i256, u513, 1 << 0);
            try testArgs(i256, u513, 1 << 512);
            try testArgs(i512, u513, 0);
            try testArgs(i512, u513, 1 << 0);
            try testArgs(i512, u513, 1 << 512);
            try testArgs(i1024, u513, 0);
            try testArgs(i1024, u513, 1 << 0);
            try testArgs(i1024, u513, 1 << 512);

            try testArgs(u8, i1023, -1 << 1022);
            try testArgs(u8, i1023, -1);
            try testArgs(u8, i1023, 0);
            try testArgs(u16, i1023, -1 << 1022);
            try testArgs(u16, i1023, -1);
            try testArgs(u16, i1023, 0);
            try testArgs(u32, i1023, -1 << 1022);
            try testArgs(u32, i1023, -1);
            try testArgs(u32, i1023, 0);
            try testArgs(u64, i1023, -1 << 1022);
            try testArgs(u64, i1023, -1);
            try testArgs(u64, i1023, 0);
            try testArgs(u128, i1023, -1 << 1022);
            try testArgs(u128, i1023, -1);
            try testArgs(u128, i1023, 0);
            try testArgs(u256, i1023, -1 << 1022);
            try testArgs(u256, i1023, -1);
            try testArgs(u256, i1023, 0);
            try testArgs(u512, i1023, -1 << 1022);
            try testArgs(u512, i1023, -1);
            try testArgs(u512, i1023, 0);
            try testArgs(u1024, i1023, -1 << 1022);
            try testArgs(u1024, i1023, -1);
            try testArgs(u1024, i1023, 0);
            try testArgs(i8, u1023, 0);
            try testArgs(i8, u1023, 1 << 0);
            try testArgs(i8, u1023, 1 << 1022);
            try testArgs(i16, u1023, 0);
            try testArgs(i16, u1023, 1 << 0);
            try testArgs(i16, u1023, 1 << 1022);
            try testArgs(i32, u1023, 0);
            try testArgs(i32, u1023, 1 << 0);
            try testArgs(i32, u1023, 1 << 1022);
            try testArgs(i64, u1023, 0);
            try testArgs(i64, u1023, 1 << 0);
            try testArgs(i64, u1023, 1 << 1022);
            try testArgs(i128, u1023, 0);
            try testArgs(i128, u1023, 1 << 0);
            try testArgs(i128, u1023, 1 << 1022);
            try testArgs(i256, u1023, 0);
            try testArgs(i256, u1023, 1 << 0);
            try testArgs(i256, u1023, 1 << 1022);
            try testArgs(i512, u1023, 0);
            try testArgs(i512, u1023, 1 << 0);
            try testArgs(i512, u1023, 1 << 1022);
            try testArgs(i1024, u1023, 0);
            try testArgs(i1024, u1023, 1 << 0);
            try testArgs(i1024, u1023, 1 << 1022);

            try testArgs(u8, i1024, -1 << 1023);
            try testArgs(u8, i1024, -1);
            try testArgs(u8, i1024, 0);
            try testArgs(u16, i1024, -1 << 1023);
            try testArgs(u16, i1024, -1);
            try testArgs(u16, i1024, 0);
            try testArgs(u32, i1024, -1 << 1023);
            try testArgs(u32, i1024, -1);
            try testArgs(u32, i1024, 0);
            try testArgs(u64, i1024, -1 << 1023);
            try testArgs(u64, i1024, -1);
            try testArgs(u64, i1024, 0);
            try testArgs(u128, i1024, -1 << 1023);
            try testArgs(u128, i1024, -1);
            try testArgs(u128, i1024, 0);
            try testArgs(u256, i1024, -1 << 1023);
            try testArgs(u256, i1024, -1);
            try testArgs(u256, i1024, 0);
            try testArgs(u512, i1024, -1 << 1023);
            try testArgs(u512, i1024, -1);
            try testArgs(u512, i1024, 0);
            try testArgs(u1024, i1024, -1 << 1023);
            try testArgs(u1024, i1024, -1);
            try testArgs(u1024, i1024, 0);
            try testArgs(i8, u1024, 0);
            try testArgs(i8, u1024, 1 << 0);
            try testArgs(i8, u1024, 1 << 1023);
            try testArgs(i16, u1024, 0);
            try testArgs(i16, u1024, 1 << 0);
            try testArgs(i16, u1024, 1 << 1023);
            try testArgs(i32, u1024, 0);
            try testArgs(i32, u1024, 1 << 0);
            try testArgs(i32, u1024, 1 << 1023);
            try testArgs(i64, u1024, 0);
            try testArgs(i64, u1024, 1 << 0);
            try testArgs(i64, u1024, 1 << 1023);
            try testArgs(i128, u1024, 0);
            try testArgs(i128, u1024, 1 << 0);
            try testArgs(i128, u1024, 1 << 1023);
            try testArgs(i256, u1024, 0);
            try testArgs(i256, u1024, 1 << 0);
            try testArgs(i256, u1024, 1 << 1023);
            try testArgs(i512, u1024, 0);
            try testArgs(i512, u1024, 1 << 0);
            try testArgs(i512, u1024, 1 << 1023);
            try testArgs(i1024, u1024, 0);
            try testArgs(i1024, u1024, 1 << 0);
            try testArgs(i1024, u1024, 1 << 1023);

            try testArgs(u8, i1025, -1 << 1024);
            try testArgs(u8, i1025, -1);
            try testArgs(u8, i1025, 0);
            try testArgs(u16, i1025, -1 << 1024);
            try testArgs(u16, i1025, -1);
            try testArgs(u16, i1025, 0);
            try testArgs(u32, i1025, -1 << 1024);
            try testArgs(u32, i1025, -1);
            try testArgs(u32, i1025, 0);
            try testArgs(u64, i1025, -1 << 1024);
            try testArgs(u64, i1025, -1);
            try testArgs(u64, i1025, 0);
            try testArgs(u128, i1025, -1 << 1024);
            try testArgs(u128, i1025, -1);
            try testArgs(u128, i1025, 0);
            try testArgs(u256, i1025, -1 << 1024);
            try testArgs(u256, i1025, -1);
            try testArgs(u256, i1025, 0);
            try testArgs(u512, i1025, -1 << 1024);
            try testArgs(u512, i1025, -1);
            try testArgs(u512, i1025, 0);
            try testArgs(u1024, i1025, -1 << 1024);
            try testArgs(u1024, i1025, -1);
            try testArgs(u1024, i1025, 0);
            try testArgs(i8, u1025, 0);
            try testArgs(i8, u1025, 1 << 0);
            try testArgs(i8, u1025, 1 << 1024);
            try testArgs(i16, u1025, 0);
            try testArgs(i16, u1025, 1 << 0);
            try testArgs(i16, u1025, 1 << 1024);
            try testArgs(i32, u1025, 0);
            try testArgs(i32, u1025, 1 << 0);
            try testArgs(i32, u1025, 1 << 1024);
            try testArgs(i64, u1025, 0);
            try testArgs(i64, u1025, 1 << 0);
            try testArgs(i64, u1025, 1 << 1024);
            try testArgs(i128, u1025, 0);
            try testArgs(i128, u1025, 1 << 0);
            try testArgs(i128, u1025, 1 << 1024);
            try testArgs(i256, u1025, 0);
            try testArgs(i256, u1025, 1 << 0);
            try testArgs(i256, u1025, 1 << 1024);
            try testArgs(i512, u1025, 0);
            try testArgs(i512, u1025, 1 << 0);
            try testArgs(i512, u1025, 1 << 1024);
            try testArgs(i1024, u1025, 0);
            try testArgs(i1024, u1025, 1 << 0);
            try testArgs(i1024, u1025, 1 << 1024);
        }
        fn testFloats() !void {
            @setEvalBranchQuota(3_100);

            try testArgs(f16, f16, -nan(f16));
            try testArgs(f16, f16, -inf(f16));
            try testArgs(f16, f16, -fmax(f16));
            try testArgs(f16, f16, -1e1);
            try testArgs(f16, f16, -1e0);
            try testArgs(f16, f16, -1e-1);
            try testArgs(f16, f16, -fmin(f16));
            try testArgs(f16, f16, -tmin(f16));
            try testArgs(f16, f16, -0.0);
            try testArgs(f16, f16, 0.0);
            try testArgs(f16, f16, tmin(f16));
            try testArgs(f16, f16, fmin(f16));
            try testArgs(f16, f16, 1e-1);
            try testArgs(f16, f16, 1e0);
            try testArgs(f16, f16, 1e1);
            try testArgs(f16, f16, fmax(f16));
            try testArgs(f16, f16, inf(f16));
            try testArgs(f16, f16, nan(f16));

            try testArgs(f32, f16, -nan(f16));
            try testArgs(f32, f16, -inf(f16));
            try testArgs(f32, f16, -fmax(f16));
            try testArgs(f32, f16, -1e1);
            try testArgs(f32, f16, -1e0);
            try testArgs(f32, f16, -1e-1);
            try testArgs(f32, f16, -fmin(f16));
            try testArgs(f32, f16, -tmin(f16));
            try testArgs(f32, f16, -0.0);
            try testArgs(f32, f16, 0.0);
            try testArgs(f32, f16, tmin(f16));
            try testArgs(f32, f16, fmin(f16));
            try testArgs(f32, f16, 1e-1);
            try testArgs(f32, f16, 1e0);
            try testArgs(f32, f16, 1e1);
            try testArgs(f32, f16, fmax(f16));
            try testArgs(f32, f16, inf(f16));
            try testArgs(f32, f16, nan(f16));

            try testArgs(f64, f16, -nan(f16));
            try testArgs(f64, f16, -inf(f16));
            try testArgs(f64, f16, -fmax(f16));
            try testArgs(f64, f16, -1e1);
            try testArgs(f64, f16, -1e0);
            try testArgs(f64, f16, -1e-1);
            try testArgs(f64, f16, -fmin(f16));
            try testArgs(f64, f16, -tmin(f16));
            try testArgs(f64, f16, -0.0);
            try testArgs(f64, f16, 0.0);
            try testArgs(f64, f16, tmin(f16));
            try testArgs(f64, f16, fmin(f16));
            try testArgs(f64, f16, 1e-1);
            try testArgs(f64, f16, 1e0);
            try testArgs(f64, f16, 1e1);
            try testArgs(f64, f16, fmax(f16));
            try testArgs(f64, f16, inf(f16));
            try testArgs(f64, f16, nan(f16));

            try testArgs(f80, f16, -nan(f16));
            try testArgs(f80, f16, -inf(f16));
            try testArgs(f80, f16, -fmax(f16));
            try testArgs(f80, f16, -1e1);
            try testArgs(f80, f16, -1e0);
            try testArgs(f80, f16, -1e-1);
            try testArgs(f80, f16, -fmin(f16));
            try testArgs(f80, f16, -tmin(f16));
            try testArgs(f80, f16, -0.0);
            try testArgs(f80, f16, 0.0);
            try testArgs(f80, f16, tmin(f16));
            try testArgs(f80, f16, fmin(f16));
            try testArgs(f80, f16, 1e-1);
            try testArgs(f80, f16, 1e0);
            try testArgs(f80, f16, 1e1);
            try testArgs(f80, f16, fmax(f16));
            try testArgs(f80, f16, inf(f16));
            try testArgs(f80, f16, nan(f16));

            try testArgs(f128, f16, -nan(f16));
            try testArgs(f128, f16, -inf(f16));
            try testArgs(f128, f16, -fmax(f16));
            try testArgs(f128, f16, -1e1);
            try testArgs(f128, f16, -1e0);
            try testArgs(f128, f16, -1e-1);
            try testArgs(f128, f16, -fmin(f16));
            try testArgs(f128, f16, -tmin(f16));
            try testArgs(f128, f16, -0.0);
            try testArgs(f128, f16, 0.0);
            try testArgs(f128, f16, tmin(f16));
            try testArgs(f128, f16, fmin(f16));
            try testArgs(f128, f16, 1e-1);
            try testArgs(f128, f16, 1e0);
            try testArgs(f128, f16, 1e1);
            try testArgs(f128, f16, fmax(f16));
            try testArgs(f128, f16, inf(f16));
            try testArgs(f128, f16, nan(f16));

            try testArgs(f16, f32, -nan(f32));
            try testArgs(f16, f32, -inf(f32));
            try testArgs(f16, f32, -fmax(f32));
            try testArgs(f16, f32, -1e1);
            try testArgs(f16, f32, -1e0);
            try testArgs(f16, f32, -1e-1);
            try testArgs(f16, f32, -fmin(f32));
            try testArgs(f16, f32, -tmin(f32));
            try testArgs(f16, f32, -0.0);
            try testArgs(f16, f32, 0.0);
            try testArgs(f16, f32, tmin(f32));
            try testArgs(f16, f32, fmin(f32));
            try testArgs(f16, f32, 1e-1);
            try testArgs(f16, f32, 1e0);
            try testArgs(f16, f32, 1e1);
            try testArgs(f16, f32, fmax(f32));
            try testArgs(f16, f32, inf(f32));
            try testArgs(f16, f32, nan(f32));

            try testArgs(f32, f32, -nan(f32));
            try testArgs(f32, f32, -inf(f32));
            try testArgs(f32, f32, -fmax(f32));
            try testArgs(f32, f32, -1e1);
            try testArgs(f32, f32, -1e0);
            try testArgs(f32, f32, -1e-1);
            try testArgs(f32, f32, -fmin(f32));
            try testArgs(f32, f32, -tmin(f32));
            try testArgs(f32, f32, -0.0);
            try testArgs(f32, f32, 0.0);
            try testArgs(f32, f32, tmin(f32));
            try testArgs(f32, f32, fmin(f32));
            try testArgs(f32, f32, 1e-1);
            try testArgs(f32, f32, 1e0);
            try testArgs(f32, f32, 1e1);
            try testArgs(f32, f32, fmax(f32));
            try testArgs(f32, f32, inf(f32));
            try testArgs(f32, f32, nan(f32));

            try testArgs(f64, f32, -nan(f32));
            try testArgs(f64, f32, -inf(f32));
            try testArgs(f64, f32, -fmax(f32));
            try testArgs(f64, f32, -1e1);
            try testArgs(f64, f32, -1e0);
            try testArgs(f64, f32, -1e-1);
            try testArgs(f64, f32, -fmin(f32));
            try testArgs(f64, f32, -tmin(f32));
            try testArgs(f64, f32, -0.0);
            try testArgs(f64, f32, 0.0);
            try testArgs(f64, f32, tmin(f32));
            try testArgs(f64, f32, fmin(f32));
            try testArgs(f64, f32, 1e-1);
            try testArgs(f64, f32, 1e0);
            try testArgs(f64, f32, 1e1);
            try testArgs(f64, f32, fmax(f32));
            try testArgs(f64, f32, inf(f32));
            try testArgs(f64, f32, nan(f32));

            try testArgs(f80, f32, -nan(f32));
            try testArgs(f80, f32, -inf(f32));
            try testArgs(f80, f32, -fmax(f32));
            try testArgs(f80, f32, -1e1);
            try testArgs(f80, f32, -1e0);
            try testArgs(f80, f32, -1e-1);
            try testArgs(f80, f32, -fmin(f32));
            try testArgs(f80, f32, -tmin(f32));
            try testArgs(f80, f32, -0.0);
            try testArgs(f80, f32, 0.0);
            try testArgs(f80, f32, tmin(f32));
            try testArgs(f80, f32, fmin(f32));
            try testArgs(f80, f32, 1e-1);
            try testArgs(f80, f32, 1e0);
            try testArgs(f80, f32, 1e1);
            try testArgs(f80, f32, fmax(f32));
            try testArgs(f80, f32, inf(f32));
            try testArgs(f80, f32, nan(f32));

            try testArgs(f128, f32, -nan(f32));
            try testArgs(f128, f32, -inf(f32));
            try testArgs(f128, f32, -fmax(f32));
            try testArgs(f128, f32, -1e1);
            try testArgs(f128, f32, -1e0);
            try testArgs(f128, f32, -1e-1);
            try testArgs(f128, f32, -fmin(f32));
            try testArgs(f128, f32, -tmin(f32));
            try testArgs(f128, f32, -0.0);
            try testArgs(f128, f32, 0.0);
            try testArgs(f128, f32, tmin(f32));
            try testArgs(f128, f32, fmin(f32));
            try testArgs(f128, f32, 1e-1);
            try testArgs(f128, f32, 1e0);
            try testArgs(f128, f32, 1e1);
            try testArgs(f128, f32, fmax(f32));
            try testArgs(f128, f32, inf(f32));
            try testArgs(f128, f32, nan(f32));

            try testArgs(f16, f64, -nan(f64));
            try testArgs(f16, f64, -inf(f64));
            try testArgs(f16, f64, -fmax(f64));
            try testArgs(f16, f64, -1e1);
            try testArgs(f16, f64, -1e0);
            try testArgs(f16, f64, -1e-1);
            try testArgs(f16, f64, -fmin(f64));
            try testArgs(f16, f64, -tmin(f64));
            try testArgs(f16, f64, -0.0);
            try testArgs(f16, f64, 0.0);
            try testArgs(f16, f64, tmin(f64));
            try testArgs(f16, f64, fmin(f64));
            try testArgs(f16, f64, 1e-1);
            try testArgs(f16, f64, 1e0);
            try testArgs(f16, f64, 1e1);
            try testArgs(f16, f64, fmax(f64));
            try testArgs(f16, f64, inf(f64));
            try testArgs(f16, f64, nan(f64));

            try testArgs(f32, f64, -nan(f64));
            try testArgs(f32, f64, -inf(f64));
            try testArgs(f32, f64, -fmax(f64));
            try testArgs(f32, f64, -1e1);
            try testArgs(f32, f64, -1e0);
            try testArgs(f32, f64, -1e-1);
            try testArgs(f32, f64, -fmin(f64));
            try testArgs(f32, f64, -tmin(f64));
            try testArgs(f32, f64, -0.0);
            try testArgs(f32, f64, 0.0);
            try testArgs(f32, f64, tmin(f64));
            try testArgs(f32, f64, fmin(f64));
            try testArgs(f32, f64, 1e-1);
            try testArgs(f32, f64, 1e0);
            try testArgs(f32, f64, 1e1);
            try testArgs(f32, f64, fmax(f64));
            try testArgs(f32, f64, inf(f64));
            try testArgs(f32, f64, nan(f64));

            try testArgs(f64, f64, -nan(f64));
            try testArgs(f64, f64, -inf(f64));
            try testArgs(f64, f64, -fmax(f64));
            try testArgs(f64, f64, -1e1);
            try testArgs(f64, f64, -1e0);
            try testArgs(f64, f64, -1e-1);
            try testArgs(f64, f64, -fmin(f64));
            try testArgs(f64, f64, -tmin(f64));
            try testArgs(f64, f64, -0.0);
            try testArgs(f64, f64, 0.0);
            try testArgs(f64, f64, tmin(f64));
            try testArgs(f64, f64, fmin(f64));
            try testArgs(f64, f64, 1e-1);
            try testArgs(f64, f64, 1e0);
            try testArgs(f64, f64, 1e1);
            try testArgs(f64, f64, fmax(f64));
            try testArgs(f64, f64, inf(f64));
            try testArgs(f64, f64, nan(f64));

            try testArgs(f80, f64, -nan(f64));
            try testArgs(f80, f64, -inf(f64));
            try testArgs(f80, f64, -fmax(f64));
            try testArgs(f80, f64, -1e1);
            try testArgs(f80, f64, -1e0);
            try testArgs(f80, f64, -1e-1);
            try testArgs(f80, f64, -fmin(f64));
            try testArgs(f80, f64, -tmin(f64));
            try testArgs(f80, f64, -0.0);
            try testArgs(f80, f64, 0.0);
            try testArgs(f80, f64, tmin(f64));
            try testArgs(f80, f64, fmin(f64));
            try testArgs(f80, f64, 1e-1);
            try testArgs(f80, f64, 1e0);
            try testArgs(f80, f64, 1e1);
            try testArgs(f80, f64, fmax(f64));
            try testArgs(f80, f64, inf(f64));
            try testArgs(f80, f64, nan(f64));

            try testArgs(f128, f64, -nan(f64));
            try testArgs(f128, f64, -inf(f64));
            try testArgs(f128, f64, -fmax(f64));
            try testArgs(f128, f64, -1e1);
            try testArgs(f128, f64, -1e0);
            try testArgs(f128, f64, -1e-1);
            try testArgs(f128, f64, -fmin(f64));
            try testArgs(f128, f64, -tmin(f64));
            try testArgs(f128, f64, -0.0);
            try testArgs(f128, f64, 0.0);
            try testArgs(f128, f64, tmin(f64));
            try testArgs(f128, f64, fmin(f64));
            try testArgs(f128, f64, 1e-1);
            try testArgs(f128, f64, 1e0);
            try testArgs(f128, f64, 1e1);
            try testArgs(f128, f64, fmax(f64));
            try testArgs(f128, f64, inf(f64));
            try testArgs(f128, f64, nan(f64));

            try testArgs(f16, f80, -nan(f80));
            try testArgs(f16, f80, -inf(f80));
            try testArgs(f16, f80, -fmax(f80));
            try testArgs(f16, f80, -1e1);
            try testArgs(f16, f80, -1e0);
            try testArgs(f16, f80, -1e-1);
            try testArgs(f16, f80, -fmin(f80));
            try testArgs(f16, f80, -tmin(f80));
            try testArgs(f16, f80, -0.0);
            try testArgs(f16, f80, 0.0);
            try testArgs(f16, f80, tmin(f80));
            try testArgs(f16, f80, fmin(f80));
            try testArgs(f16, f80, 1e-1);
            try testArgs(f16, f80, 1e0);
            try testArgs(f16, f80, 1e1);
            try testArgs(f16, f80, fmax(f80));
            try testArgs(f16, f80, inf(f80));
            try testArgs(f16, f80, nan(f80));

            try testArgs(f32, f80, -nan(f80));
            try testArgs(f32, f80, -inf(f80));
            try testArgs(f32, f80, -fmax(f80));
            try testArgs(f32, f80, -1e1);
            try testArgs(f32, f80, -1e0);
            try testArgs(f32, f80, -1e-1);
            try testArgs(f32, f80, -fmin(f80));
            try testArgs(f32, f80, -tmin(f80));
            try testArgs(f32, f80, -0.0);
            try testArgs(f32, f80, 0.0);
            try testArgs(f32, f80, tmin(f80));
            try testArgs(f32, f80, fmin(f80));
            try testArgs(f32, f80, 1e-1);
            try testArgs(f32, f80, 1e0);
            try testArgs(f32, f80, 1e1);
            try testArgs(f32, f80, fmax(f80));
            try testArgs(f32, f80, inf(f80));
            try testArgs(f32, f80, nan(f80));

            try testArgs(f64, f80, -nan(f80));
            try testArgs(f64, f80, -inf(f80));
            try testArgs(f64, f80, -fmax(f80));
            try testArgs(f64, f80, -1e1);
            try testArgs(f64, f80, -1e0);
            try testArgs(f64, f80, -1e-1);
            try testArgs(f64, f80, -fmin(f80));
            try testArgs(f64, f80, -tmin(f80));
            try testArgs(f64, f80, -0.0);
            try testArgs(f64, f80, 0.0);
            try testArgs(f64, f80, tmin(f80));
            try testArgs(f64, f80, fmin(f80));
            try testArgs(f64, f80, 1e-1);
            try testArgs(f64, f80, 1e0);
            try testArgs(f64, f80, 1e1);
            try testArgs(f64, f80, fmax(f80));
            try testArgs(f64, f80, inf(f80));
            try testArgs(f64, f80, nan(f80));

            try testArgs(f80, f80, -nan(f80));
            try testArgs(f80, f80, -inf(f80));
            try testArgs(f80, f80, -fmax(f80));
            try testArgs(f80, f80, -1e1);
            try testArgs(f80, f80, -1e0);
            try testArgs(f80, f80, -1e-1);
            try testArgs(f80, f80, -fmin(f80));
            try testArgs(f80, f80, -tmin(f80));
            try testArgs(f80, f80, -0.0);
            try testArgs(f80, f80, 0.0);
            try testArgs(f80, f80, tmin(f80));
            try testArgs(f80, f80, fmin(f80));
            try testArgs(f80, f80, 1e-1);
            try testArgs(f80, f80, 1e0);
            try testArgs(f80, f80, 1e1);
            try testArgs(f80, f80, fmax(f80));
            try testArgs(f80, f80, inf(f80));
            try testArgs(f80, f80, nan(f80));

            try testArgs(f128, f80, -nan(f80));
            try testArgs(f128, f80, -inf(f80));
            try testArgs(f128, f80, -fmax(f80));
            try testArgs(f128, f80, -1e1);
            try testArgs(f128, f80, -1e0);
            try testArgs(f128, f80, -1e-1);
            try testArgs(f128, f80, -fmin(f80));
            try testArgs(f128, f80, -tmin(f80));
            try testArgs(f128, f80, -0.0);
            try testArgs(f128, f80, 0.0);
            try testArgs(f128, f80, tmin(f80));
            try testArgs(f128, f80, fmin(f80));
            try testArgs(f128, f80, 1e-1);
            try testArgs(f128, f80, 1e0);
            try testArgs(f128, f80, 1e1);
            try testArgs(f128, f80, fmax(f80));
            try testArgs(f128, f80, inf(f80));
            try testArgs(f128, f80, nan(f80));

            try testArgs(f16, f128, -nan(f128));
            try testArgs(f16, f128, -inf(f128));
            try testArgs(f16, f128, -fmax(f128));
            try testArgs(f16, f128, -1e1);
            try testArgs(f16, f128, -1e0);
            try testArgs(f16, f128, -1e-1);
            try testArgs(f16, f128, -fmin(f128));
            try testArgs(f16, f128, -tmin(f128));
            try testArgs(f16, f128, -0.0);
            try testArgs(f16, f128, 0.0);
            try testArgs(f16, f128, tmin(f128));
            try testArgs(f16, f128, fmin(f128));
            try testArgs(f16, f128, 1e-1);
            try testArgs(f16, f128, 1e0);
            try testArgs(f16, f128, 1e1);
            try testArgs(f16, f128, fmax(f128));
            try testArgs(f16, f128, inf(f128));
            try testArgs(f16, f128, nan(f128));

            try testArgs(f32, f128, -nan(f128));
            try testArgs(f32, f128, -inf(f128));
            try testArgs(f32, f128, -fmax(f128));
            try testArgs(f32, f128, -1e1);
            try testArgs(f32, f128, -1e0);
            try testArgs(f32, f128, -1e-1);
            try testArgs(f32, f128, -fmin(f128));
            try testArgs(f32, f128, -tmin(f128));
            try testArgs(f32, f128, -0.0);
            try testArgs(f32, f128, 0.0);
            try testArgs(f32, f128, tmin(f128));
            try testArgs(f32, f128, fmin(f128));
            try testArgs(f32, f128, 1e-1);
            try testArgs(f32, f128, 1e0);
            try testArgs(f32, f128, 1e1);
            try testArgs(f32, f128, fmax(f128));
            try testArgs(f32, f128, inf(f128));
            try testArgs(f32, f128, nan(f128));

            try testArgs(f64, f128, -nan(f128));
            try testArgs(f64, f128, -inf(f128));
            try testArgs(f64, f128, -fmax(f128));
            try testArgs(f64, f128, -1e1);
            try testArgs(f64, f128, -1e0);
            try testArgs(f64, f128, -1e-1);
            try testArgs(f64, f128, -fmin(f128));
            try testArgs(f64, f128, -tmin(f128));
            try testArgs(f64, f128, -0.0);
            try testArgs(f64, f128, 0.0);
            try testArgs(f64, f128, tmin(f128));
            try testArgs(f64, f128, fmin(f128));
            try testArgs(f64, f128, 1e-1);
            try testArgs(f64, f128, 1e0);
            try testArgs(f64, f128, 1e1);
            try testArgs(f64, f128, fmax(f128));
            try testArgs(f64, f128, inf(f128));
            try testArgs(f64, f128, nan(f128));

            try testArgs(f80, f128, -nan(f128));
            try testArgs(f80, f128, -inf(f128));
            try testArgs(f80, f128, -fmax(f128));
            try testArgs(f80, f128, -1e1);
            try testArgs(f80, f128, -1e0);
            try testArgs(f80, f128, -1e-1);
            try testArgs(f80, f128, -fmin(f128));
            try testArgs(f80, f128, -tmin(f128));
            try testArgs(f80, f128, -0.0);
            try testArgs(f80, f128, 0.0);
            try testArgs(f80, f128, tmin(f128));
            try testArgs(f80, f128, fmin(f128));
            try testArgs(f80, f128, 1e-1);
            try testArgs(f80, f128, 1e0);
            try testArgs(f80, f128, 1e1);
            try testArgs(f80, f128, fmax(f128));
            try testArgs(f80, f128, inf(f128));
            try testArgs(f80, f128, nan(f128));

            try testArgs(f128, f128, -nan(f128));
            try testArgs(f128, f128, -inf(f128));
            try testArgs(f128, f128, -fmax(f128));
            try testArgs(f128, f128, -1e1);
            try testArgs(f128, f128, -1e0);
            try testArgs(f128, f128, -1e-1);
            try testArgs(f128, f128, -fmin(f128));
            try testArgs(f128, f128, -tmin(f128));
            try testArgs(f128, f128, -0.0);
            try testArgs(f128, f128, 0.0);
            try testArgs(f128, f128, tmin(f128));
            try testArgs(f128, f128, fmin(f128));
            try testArgs(f128, f128, 1e-1);
            try testArgs(f128, f128, 1e0);
            try testArgs(f128, f128, 1e1);
            try testArgs(f128, f128, fmax(f128));
            try testArgs(f128, f128, inf(f128));
            try testArgs(f128, f128, nan(f128));
        }
        fn testSameSignednessIntVectors() !void {
            try testArgs(@Vector(1, i7), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i8), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i9), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i15), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i16), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i17), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i31), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i32), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i33), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i63), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i64), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i65), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i127), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i128), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i129), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i255), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i256), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i257), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i511), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i512), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i513), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i1023), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i1024), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i1025), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u7), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u8), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u9), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u15), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u16), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u17), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u31), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u32), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u33), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u63), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u64), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u65), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u127), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u128), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u129), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u255), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u256), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u257), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u511), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u512), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u513), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u1023), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u1024), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, u1025), @Vector(1, u1), .{1});

            try testArgs(@Vector(2, i7), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i8), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i9), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i15), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i16), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i17), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i31), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i32), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i33), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i63), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i64), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i65), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i127), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i128), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i129), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i255), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i256), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i257), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i511), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i512), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i513), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i1023), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i1024), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i1025), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u7), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u8), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u9), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u15), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u16), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u17), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u31), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u32), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u33), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u63), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u64), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u65), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u127), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u128), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u129), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u255), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u256), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u257), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u511), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u512), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u513), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u1023), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u1024), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, u1025), @Vector(2, u1), .{ 0, 1 });

            try testArgs(@Vector(3, i7), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u8), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u9), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u15), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u16), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u17), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u31), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u32), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u33), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u63), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u64), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u65), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u127), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u128), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u129), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u255), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u256), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u257), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u511), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u512), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u513), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u1023), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u1024), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, u1025), @Vector(3, u2), .{ 0, 1, 1 << 1 });

            try testArgs(@Vector(3, i7), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u8), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u9), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u15), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u16), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u17), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u31), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u32), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u33), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u63), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u64), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u65), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u127), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u128), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u129), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u255), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u256), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u257), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u511), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u512), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u513), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u1023), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u1024), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, u1025), @Vector(3, u3), .{ 0, 1, 1 << 2 });

            try testArgs(@Vector(3, i7), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u8), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u9), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u15), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u16), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u17), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u31), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u32), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u33), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u63), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u64), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u65), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u127), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u128), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u129), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u255), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u256), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u257), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u511), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u512), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u513), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u1023), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u1024), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, u1025), @Vector(3, u4), .{ 0, 1, 1 << 3 });

            try testArgs(@Vector(3, i7), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u8), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u9), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u15), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u16), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u17), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u31), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u32), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u33), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u63), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u64), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u65), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u127), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u128), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u129), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u255), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u256), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u257), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u511), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u512), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u513), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u1023), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u1024), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, u1025), @Vector(3, u5), .{ 0, 1, 1 << 4 });

            try testArgs(@Vector(3, i7), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u8), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u9), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u15), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u16), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u17), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u31), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u32), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u33), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u63), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u64), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u65), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u127), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u128), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u129), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u255), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u256), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u257), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u511), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u512), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u513), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u1023), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u1024), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, u1025), @Vector(3, u7), .{ 0, 1, 1 << 6 });

            try testArgs(@Vector(3, i7), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u8), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u9), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u15), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u16), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u17), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u31), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u32), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u33), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u63), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u64), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u65), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u127), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u128), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u129), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u255), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u256), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u257), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u511), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u512), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u513), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u1023), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u1024), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, u1025), @Vector(3, u8), .{ 0, 1, 1 << 7 });

            try testArgs(@Vector(3, i7), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u8), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u9), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u15), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u16), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u17), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u31), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u32), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u33), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u63), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u64), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u65), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u127), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u128), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u129), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u255), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u256), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u257), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u511), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u512), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u513), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u1023), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u1024), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, u1025), @Vector(3, u9), .{ 0, 1, 1 << 8 });

            try testArgs(@Vector(3, i7), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u8), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u9), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u15), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u16), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u17), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u31), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u32), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u33), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u63), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u64), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u65), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u127), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u128), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u129), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u255), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u256), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u257), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u511), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u512), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u513), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u1023), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u1024), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, u1025), @Vector(3, u15), .{ 0, 1, 1 << 14 });

            try testArgs(@Vector(3, i7), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u8), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u9), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u15), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u16), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u17), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u31), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u32), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u33), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u63), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u64), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u65), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u127), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u128), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u129), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u255), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u256), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u257), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u511), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u512), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u513), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u1023), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u1024), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, u1025), @Vector(3, u16), .{ 0, 1, 1 << 15 });

            try testArgs(@Vector(3, i7), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u8), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u9), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u15), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u16), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u17), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u31), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u32), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u33), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u63), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u64), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u65), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u127), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u128), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u129), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u255), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u256), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u257), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u511), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u512), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u513), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u1023), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u1024), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, u1025), @Vector(3, u17), .{ 0, 1, 1 << 16 });

            try testArgs(@Vector(3, i7), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u8), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u9), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u15), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u16), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u17), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u31), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u32), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u33), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u63), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u64), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u65), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u127), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u128), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u129), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u255), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u256), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u257), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u511), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u512), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u513), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u1023), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u1024), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, u1025), @Vector(3, u31), .{ 0, 1, 1 << 30 });

            try testArgs(@Vector(3, i7), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u8), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u9), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u15), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u16), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u17), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u31), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u32), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u33), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u63), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u64), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u65), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u127), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u128), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u129), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u255), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u256), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u257), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u511), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u512), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u513), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u1023), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u1024), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, u1025), @Vector(3, u32), .{ 0, 1, 1 << 31 });

            try testArgs(@Vector(3, i7), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u8), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u9), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u15), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u16), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u17), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u31), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u32), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u33), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u63), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u64), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u65), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u127), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u128), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u129), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u255), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u256), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u257), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u511), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u512), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u513), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u1023), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u1024), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, u1025), @Vector(3, u33), .{ 0, 1, 1 << 32 });

            try testArgs(@Vector(3, i7), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u8), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u9), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u15), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u16), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u17), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u31), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u32), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u33), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u63), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u64), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u65), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u127), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u128), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u129), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u255), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u256), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u257), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u511), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u512), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u513), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u1023), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u1024), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, u1025), @Vector(3, u63), .{ 0, 1, 1 << 62 });

            try testArgs(@Vector(3, i7), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u8), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u9), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u15), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u16), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u17), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u31), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u32), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u33), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u63), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u64), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u65), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u127), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u128), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u129), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u255), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u256), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u257), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u511), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u512), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u513), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u1023), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u1024), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, u1025), @Vector(3, u64), .{ 0, 1, 1 << 63 });

            try testArgs(@Vector(3, i7), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u8), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u9), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u15), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u16), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u17), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u31), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u32), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u33), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u63), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u64), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u65), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u127), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u128), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u129), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u255), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u256), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u257), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u511), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u512), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u513), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u1023), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u1024), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, u1025), @Vector(3, u65), .{ 0, 1, 1 << 64 });

            try testArgs(@Vector(3, i7), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u8), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u9), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u15), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u16), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u17), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u31), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u32), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u33), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u63), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u64), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u65), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u127), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u128), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u129), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u255), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u256), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u257), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u511), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u512), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u513), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u1023), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u1024), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, u1025), @Vector(3, u95), .{ 0, 1, 1 << 94 });

            try testArgs(@Vector(3, i7), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u8), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u9), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u15), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u16), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u17), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u31), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u32), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u33), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u63), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u64), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u65), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u127), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u128), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u129), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u255), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u256), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u257), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u511), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u512), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u513), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u1023), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u1024), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, u1025), @Vector(3, u96), .{ 0, 1, 1 << 95 });

            try testArgs(@Vector(3, i7), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u8), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u9), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u15), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u16), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u17), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u31), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u32), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u33), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u63), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u64), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u65), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u127), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u128), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u129), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u255), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u256), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u257), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u511), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u512), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u513), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u1023), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u1024), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, u1025), @Vector(3, u97), .{ 0, 1, 1 << 96 });

            try testArgs(@Vector(3, i7), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u8), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u9), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u15), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u16), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u17), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u31), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u32), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u33), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u63), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u64), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u65), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u127), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u128), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u129), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u255), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u256), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u257), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u511), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u512), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u513), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u1023), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u1024), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, u1025), @Vector(3, u127), .{ 0, 1, 1 << 126 });

            try testArgs(@Vector(3, i7), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u8), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u9), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u15), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u16), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u17), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u31), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u32), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u33), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u63), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u64), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u65), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u127), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u128), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u129), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u255), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u256), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u257), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u511), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u512), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u513), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u1023), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u1024), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, u1025), @Vector(3, u128), .{ 0, 1, 1 << 127 });

            try testArgs(@Vector(3, i7), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u8), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u9), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u15), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u16), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u17), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u31), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u32), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u33), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u63), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u64), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u65), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u127), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u128), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u129), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u255), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u256), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u257), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u511), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u512), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u513), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u1023), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u1024), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, u1025), @Vector(3, u129), .{ 0, 1, 1 << 128 });

            try testArgs(@Vector(3, i7), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u8), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u9), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u15), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u16), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u17), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u31), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u32), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u33), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u63), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u64), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u65), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u127), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u128), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u129), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u255), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u256), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u257), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u511), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u512), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u513), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u1023), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u1024), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, u1025), @Vector(3, u159), .{ 0, 1, 1 << 158 });

            try testArgs(@Vector(3, i7), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u8), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u9), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u15), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u16), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u17), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u31), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u32), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u33), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u63), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u64), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u65), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u127), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u128), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u129), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u255), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u256), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u257), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u511), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u512), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u513), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u1023), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u1024), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, u1025), @Vector(3, u160), .{ 0, 1, 1 << 159 });

            try testArgs(@Vector(3, i7), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u8), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u9), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u15), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u16), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u17), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u31), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u32), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u33), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u63), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u64), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u65), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u127), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u128), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u129), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u255), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u256), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u257), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u511), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u512), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u513), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u1023), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u1024), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, u1025), @Vector(3, u161), .{ 0, 1, 1 << 160 });

            try testArgs(@Vector(3, i7), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u8), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u9), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u15), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u16), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u17), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u31), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u32), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u33), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u63), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u64), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u65), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u127), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u128), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u129), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u255), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u256), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u257), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u511), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u512), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u513), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u1023), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u1024), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, u1025), @Vector(3, u191), .{ 0, 1, 1 << 190 });

            try testArgs(@Vector(3, i7), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u8), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u9), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u15), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u16), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u17), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u31), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u32), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u33), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u63), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u64), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u65), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u127), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u128), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u129), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u255), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u256), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u257), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u511), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u512), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u513), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u1023), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u1024), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, u1025), @Vector(3, u192), .{ 0, 1, 1 << 191 });

            try testArgs(@Vector(3, i7), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u8), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u9), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u15), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u16), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u17), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u31), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u32), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u33), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u63), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u64), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u65), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u127), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u128), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u129), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u255), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u256), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u257), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u511), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u512), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u513), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u1023), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u1024), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, u1025), @Vector(3, u193), .{ 0, 1, 1 << 192 });

            try testArgs(@Vector(3, i7), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u8), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u9), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u15), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u16), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u17), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u31), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u32), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u33), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u63), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u64), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u65), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u127), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u128), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u129), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u255), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u256), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u257), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u511), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u512), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u513), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u1023), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u1024), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, u1025), @Vector(3, u223), .{ 0, 1, 1 << 222 });

            try testArgs(@Vector(3, i7), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u8), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u9), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u15), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u16), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u17), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u31), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u32), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u33), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u63), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u64), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u65), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u127), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u128), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u129), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u255), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u256), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u257), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u511), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u512), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u513), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u1023), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u1024), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, u1025), @Vector(3, u224), .{ 0, 1, 1 << 223 });

            try testArgs(@Vector(3, i7), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u8), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u9), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u15), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u16), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u17), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u31), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u32), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u33), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u63), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u64), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u65), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u127), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u128), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u129), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u255), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u256), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u257), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u511), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u512), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u513), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u1023), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u1024), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, u1025), @Vector(3, u225), .{ 0, 1, 1 << 224 });

            try testArgs(@Vector(3, i7), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u8), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u9), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u15), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u16), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u17), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u31), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u32), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u33), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u63), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u64), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u65), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u127), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u128), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u129), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u255), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u256), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u257), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u511), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u512), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u513), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u1023), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u1024), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, u1025), @Vector(3, u255), .{ 0, 1, 1 << 254 });

            try testArgs(@Vector(3, i7), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u8), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u9), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u15), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u16), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u17), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u31), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u32), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u33), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u63), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u64), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u65), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u127), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u128), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u129), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u255), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u256), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u257), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u511), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u512), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u513), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u1023), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u1024), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, u1025), @Vector(3, u256), .{ 0, 1, 1 << 255 });

            try testArgs(@Vector(3, i7), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u8), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u9), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u15), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u16), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u17), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u31), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u32), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u33), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u63), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u64), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u65), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u127), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u128), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u129), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u255), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u256), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u257), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u511), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u512), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u513), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u1023), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u1024), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, u1025), @Vector(3, u257), .{ 0, 1, 1 << 256 });

            try testArgs(@Vector(3, i7), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u8), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u9), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u15), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u16), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u17), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u31), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u32), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u33), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u63), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u64), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u65), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u127), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u128), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u129), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u255), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u256), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u257), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u511), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u512), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u513), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u1023), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u1024), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, u1025), @Vector(3, u511), .{ 0, 1, 1 << 510 });

            try testArgs(@Vector(3, i7), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u8), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u9), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u15), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u16), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u17), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u31), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u32), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u33), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u63), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u64), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u65), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u127), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u128), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u129), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u255), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u256), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u257), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u511), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u512), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u513), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u1023), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u1024), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, u1025), @Vector(3, u512), .{ 0, 1, 1 << 511 });

            try testArgs(@Vector(3, i7), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u8), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u9), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u15), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u16), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u17), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u31), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u32), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u33), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u63), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u64), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u65), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u127), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u128), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u129), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u255), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u256), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u257), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u511), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u512), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u513), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u1023), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u1024), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, u1025), @Vector(3, u513), .{ 0, 1, 1 << 512 });

            try testArgs(@Vector(3, i7), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u8), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u9), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u15), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u16), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u17), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u31), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u32), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u33), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u63), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u64), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u65), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u127), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u128), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u129), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u255), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u256), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u257), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u511), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u512), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u513), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u1023), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u1024), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, u1025), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });

            try testArgs(@Vector(3, i7), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u8), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u9), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u15), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u16), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u17), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u31), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u32), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u33), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u63), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u64), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u65), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u127), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u128), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u129), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u255), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u256), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u257), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u511), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u512), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u513), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u1023), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u1024), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, u1025), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });

            try testArgs(@Vector(3, i7), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i9), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i15), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i16), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i17), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i31), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i32), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i33), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i63), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i64), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i65), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i127), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i128), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i129), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i255), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i256), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i257), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i511), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i512), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i513), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i1023), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i1024), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i1025), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u7), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u8), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u9), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u15), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u16), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u17), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u31), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u32), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u33), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u63), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u64), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u65), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u127), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u128), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u129), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u255), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u256), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u257), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u511), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u512), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u513), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u1023), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u1024), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, u1025), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
        }
        fn testIntVectors() !void {
            try testSameSignednessIntVectors();

            try testArgs(@Vector(1, u8), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u16), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u32), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u64), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u128), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u256), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u512), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, u1024), @Vector(1, i1), .{-1});
            try testArgs(@Vector(1, i8), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i16), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i32), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i64), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i128), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i256), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i512), @Vector(1, u1), .{1});
            try testArgs(@Vector(1, i1024), @Vector(1, u1), .{1});

            try testArgs(@Vector(2, u8), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u16), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u32), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u64), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u128), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u256), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u512), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, u1024), @Vector(2, i1), .{ -1, 0 });
            try testArgs(@Vector(2, i8), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i16), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i32), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i64), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i128), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i256), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i512), @Vector(2, u1), .{ 0, 1 });
            try testArgs(@Vector(2, i1024), @Vector(2, u1), .{ 0, 1 });

            try testArgs(@Vector(3, u8), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i2), .{ -1 << 1, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i16), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i32), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i64), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i128), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i256), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i512), @Vector(3, u2), .{ 0, 1, 1 << 1 });
            try testArgs(@Vector(3, i1024), @Vector(3, u2), .{ 0, 1, 1 << 1 });

            try testArgs(@Vector(3, u8), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i3), .{ -1 << 2, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i16), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i32), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i64), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i128), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i256), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i512), @Vector(3, u3), .{ 0, 1, 1 << 2 });
            try testArgs(@Vector(3, i1024), @Vector(3, u3), .{ 0, 1, 1 << 2 });

            try testArgs(@Vector(3, u8), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i4), .{ -1 << 3, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i16), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i32), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i64), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i128), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i256), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i512), @Vector(3, u4), .{ 0, 1, 1 << 3 });
            try testArgs(@Vector(3, i1024), @Vector(3, u4), .{ 0, 1, 1 << 3 });

            try testArgs(@Vector(3, u8), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i5), .{ -1 << 4, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i16), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i32), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i64), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i128), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i256), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i512), @Vector(3, u5), .{ 0, 1, 1 << 4 });
            try testArgs(@Vector(3, i1024), @Vector(3, u5), .{ 0, 1, 1 << 4 });

            try testArgs(@Vector(3, u8), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i7), .{ -1 << 6, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i16), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i32), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i64), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i128), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i256), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i512), @Vector(3, u7), .{ 0, 1, 1 << 6 });
            try testArgs(@Vector(3, i1024), @Vector(3, u7), .{ 0, 1, 1 << 6 });

            try testArgs(@Vector(3, u8), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i8), .{ -1 << 7, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i16), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i32), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i64), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i128), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i256), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i512), @Vector(3, u8), .{ 0, 1, 1 << 7 });
            try testArgs(@Vector(3, i1024), @Vector(3, u8), .{ 0, 1, 1 << 7 });

            try testArgs(@Vector(3, u8), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i9), .{ -1 << 8, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i16), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i32), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i64), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i128), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i256), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i512), @Vector(3, u9), .{ 0, 1, 1 << 8 });
            try testArgs(@Vector(3, i1024), @Vector(3, u9), .{ 0, 1, 1 << 8 });

            try testArgs(@Vector(3, u8), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i15), .{ -1 << 14, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i16), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i32), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i64), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i128), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i256), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i512), @Vector(3, u15), .{ 0, 1, 1 << 14 });
            try testArgs(@Vector(3, i1024), @Vector(3, u15), .{ 0, 1, 1 << 14 });

            try testArgs(@Vector(3, u8), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i16), .{ -1 << 15, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i16), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i32), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i64), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i128), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i256), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i512), @Vector(3, u16), .{ 0, 1, 1 << 15 });
            try testArgs(@Vector(3, i1024), @Vector(3, u16), .{ 0, 1, 1 << 15 });

            try testArgs(@Vector(3, u8), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i17), .{ -1 << 16, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i16), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i32), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i64), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i128), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i256), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i512), @Vector(3, u17), .{ 0, 1, 1 << 16 });
            try testArgs(@Vector(3, i1024), @Vector(3, u17), .{ 0, 1, 1 << 16 });

            try testArgs(@Vector(3, u8), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i31), .{ -1 << 30, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i16), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i32), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i64), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i128), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i256), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i512), @Vector(3, u31), .{ 0, 1, 1 << 30 });
            try testArgs(@Vector(3, i1024), @Vector(3, u31), .{ 0, 1, 1 << 30 });

            try testArgs(@Vector(3, u8), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i32), .{ -1 << 31, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i16), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i32), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i64), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i128), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i256), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i512), @Vector(3, u32), .{ 0, 1, 1 << 31 });
            try testArgs(@Vector(3, i1024), @Vector(3, u32), .{ 0, 1, 1 << 31 });

            try testArgs(@Vector(3, u8), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i33), .{ -1 << 32, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i16), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i32), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i64), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i128), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i256), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i512), @Vector(3, u33), .{ 0, 1, 1 << 32 });
            try testArgs(@Vector(3, i1024), @Vector(3, u33), .{ 0, 1, 1 << 32 });

            try testArgs(@Vector(3, u8), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i63), .{ -1 << 62, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i16), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i32), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i64), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i128), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i256), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i512), @Vector(3, u63), .{ 0, 1, 1 << 62 });
            try testArgs(@Vector(3, i1024), @Vector(3, u63), .{ 0, 1, 1 << 62 });

            try testArgs(@Vector(3, u8), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i64), .{ -1 << 63, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i16), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i32), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i64), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i128), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i256), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i512), @Vector(3, u64), .{ 0, 1, 1 << 63 });
            try testArgs(@Vector(3, i1024), @Vector(3, u64), .{ 0, 1, 1 << 63 });

            try testArgs(@Vector(3, u8), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i65), .{ -1 << 64, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i16), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i32), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i64), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i128), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i256), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i512), @Vector(3, u65), .{ 0, 1, 1 << 64 });
            try testArgs(@Vector(3, i1024), @Vector(3, u65), .{ 0, 1, 1 << 64 });

            try testArgs(@Vector(3, u8), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i95), .{ -1 << 94, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i16), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i32), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i64), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i128), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i256), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i512), @Vector(3, u95), .{ 0, 1, 1 << 94 });
            try testArgs(@Vector(3, i1024), @Vector(3, u95), .{ 0, 1, 1 << 94 });

            try testArgs(@Vector(3, u8), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i96), .{ -1 << 95, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i16), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i32), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i64), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i128), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i256), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i512), @Vector(3, u96), .{ 0, 1, 1 << 95 });
            try testArgs(@Vector(3, i1024), @Vector(3, u96), .{ 0, 1, 1 << 95 });

            try testArgs(@Vector(3, u8), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i97), .{ -1 << 96, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i16), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i32), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i64), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i128), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i256), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i512), @Vector(3, u97), .{ 0, 1, 1 << 96 });
            try testArgs(@Vector(3, i1024), @Vector(3, u97), .{ 0, 1, 1 << 96 });

            try testArgs(@Vector(3, u8), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i127), .{ -1 << 126, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i16), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i32), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i64), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i128), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i256), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i512), @Vector(3, u127), .{ 0, 1, 1 << 126 });
            try testArgs(@Vector(3, i1024), @Vector(3, u127), .{ 0, 1, 1 << 126 });

            try testArgs(@Vector(3, u8), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i128), .{ -1 << 127, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i16), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i32), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i64), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i128), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i256), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i512), @Vector(3, u128), .{ 0, 1, 1 << 127 });
            try testArgs(@Vector(3, i1024), @Vector(3, u128), .{ 0, 1, 1 << 127 });

            try testArgs(@Vector(3, u8), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i129), .{ -1 << 128, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i16), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i32), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i64), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i128), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i256), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i512), @Vector(3, u129), .{ 0, 1, 1 << 128 });
            try testArgs(@Vector(3, i1024), @Vector(3, u129), .{ 0, 1, 1 << 128 });

            try testArgs(@Vector(3, u8), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i159), .{ -1 << 158, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i16), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i32), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i64), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i128), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i256), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i512), @Vector(3, u159), .{ 0, 1, 1 << 158 });
            try testArgs(@Vector(3, i1024), @Vector(3, u159), .{ 0, 1, 1 << 158 });

            try testArgs(@Vector(3, u8), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i160), .{ -1 << 159, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i16), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i32), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i64), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i128), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i256), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i512), @Vector(3, u160), .{ 0, 1, 1 << 159 });
            try testArgs(@Vector(3, i1024), @Vector(3, u160), .{ 0, 1, 1 << 159 });

            try testArgs(@Vector(3, u8), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i161), .{ -1 << 160, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i16), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i32), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i64), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i128), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i256), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i512), @Vector(3, u161), .{ 0, 1, 1 << 160 });
            try testArgs(@Vector(3, i1024), @Vector(3, u161), .{ 0, 1, 1 << 160 });

            try testArgs(@Vector(3, u8), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i191), .{ -1 << 190, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i16), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i32), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i64), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i128), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i256), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i512), @Vector(3, u191), .{ 0, 1, 1 << 190 });
            try testArgs(@Vector(3, i1024), @Vector(3, u191), .{ 0, 1, 1 << 190 });

            try testArgs(@Vector(3, u8), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i192), .{ -1 << 191, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i16), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i32), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i64), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i128), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i256), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i512), @Vector(3, u192), .{ 0, 1, 1 << 191 });
            try testArgs(@Vector(3, i1024), @Vector(3, u192), .{ 0, 1, 1 << 191 });

            try testArgs(@Vector(3, u8), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i193), .{ -1 << 192, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i16), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i32), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i64), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i128), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i256), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i512), @Vector(3, u193), .{ 0, 1, 1 << 192 });
            try testArgs(@Vector(3, i1024), @Vector(3, u193), .{ 0, 1, 1 << 192 });

            try testArgs(@Vector(3, u8), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i223), .{ -1 << 222, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i16), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i32), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i64), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i128), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i256), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i512), @Vector(3, u223), .{ 0, 1, 1 << 222 });
            try testArgs(@Vector(3, i1024), @Vector(3, u223), .{ 0, 1, 1 << 222 });

            try testArgs(@Vector(3, u8), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i224), .{ -1 << 223, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i16), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i32), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i64), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i128), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i256), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i512), @Vector(3, u224), .{ 0, 1, 1 << 223 });
            try testArgs(@Vector(3, i1024), @Vector(3, u224), .{ 0, 1, 1 << 223 });

            try testArgs(@Vector(3, u8), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i225), .{ -1 << 224, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i16), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i32), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i64), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i128), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i256), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i512), @Vector(3, u225), .{ 0, 1, 1 << 224 });
            try testArgs(@Vector(3, i1024), @Vector(3, u225), .{ 0, 1, 1 << 224 });

            try testArgs(@Vector(3, u8), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i255), .{ -1 << 254, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i16), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i32), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i64), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i128), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i256), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i512), @Vector(3, u255), .{ 0, 1, 1 << 254 });
            try testArgs(@Vector(3, i1024), @Vector(3, u255), .{ 0, 1, 1 << 254 });

            try testArgs(@Vector(3, u8), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i256), .{ -1 << 255, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i16), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i32), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i64), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i128), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i256), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i512), @Vector(3, u256), .{ 0, 1, 1 << 255 });
            try testArgs(@Vector(3, i1024), @Vector(3, u256), .{ 0, 1, 1 << 255 });

            try testArgs(@Vector(3, u8), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i257), .{ -1 << 256, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i16), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i32), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i64), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i128), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i256), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i512), @Vector(3, u257), .{ 0, 1, 1 << 256 });
            try testArgs(@Vector(3, i1024), @Vector(3, u257), .{ 0, 1, 1 << 256 });

            try testArgs(@Vector(3, u8), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i511), .{ -1 << 510, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i16), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i32), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i64), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i128), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i256), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i512), @Vector(3, u511), .{ 0, 1, 1 << 510 });
            try testArgs(@Vector(3, i1024), @Vector(3, u511), .{ 0, 1, 1 << 510 });

            try testArgs(@Vector(3, u8), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i512), .{ -1 << 511, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i16), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i32), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i64), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i128), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i256), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i512), @Vector(3, u512), .{ 0, 1, 1 << 511 });
            try testArgs(@Vector(3, i1024), @Vector(3, u512), .{ 0, 1, 1 << 511 });

            try testArgs(@Vector(3, u8), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i513), .{ -1 << 512, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i16), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i32), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i64), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i128), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i256), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i512), @Vector(3, u513), .{ 0, 1, 1 << 512 });
            try testArgs(@Vector(3, i1024), @Vector(3, u513), .{ 0, 1, 1 << 512 });

            try testArgs(@Vector(3, u8), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i1023), .{ -1 << 1022, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i16), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i32), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i64), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i128), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i256), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i512), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });
            try testArgs(@Vector(3, i1024), @Vector(3, u1023), .{ 0, 1, 1 << 1022 });

            try testArgs(@Vector(3, u8), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i1024), .{ -1 << 1023, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i16), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i32), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i64), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i128), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i256), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i512), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });
            try testArgs(@Vector(3, i1024), @Vector(3, u1024), .{ 0, 1, 1 << 1023 });

            try testArgs(@Vector(3, u8), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u16), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u32), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u64), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u128), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u256), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u512), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, u1024), @Vector(3, i1025), .{ -1 << 1024, -1, 0 });
            try testArgs(@Vector(3, i8), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i16), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i32), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i64), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i128), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i256), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i512), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
            try testArgs(@Vector(3, i1024), @Vector(3, u1025), .{ 0, 1, 1 << 1024 });
        }
        fn testFloatVectors() !void {
            @setEvalBranchQuota(6_700);

            try testArgs(@Vector(1, f16), @Vector(1, f16), .{
                1e0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, f16), .{
                -inf(f16), -1e-2,
            });
            try testArgs(@Vector(4, f16), @Vector(4, f16), .{
                -1e2, 1e-1, fmax(f16), 1e-2,
            });
            try testArgs(@Vector(8, f16), @Vector(8, f16), .{
                -1e-1, tmin(f16), -1e3, fmin(f16), nan(f16), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f16), @Vector(16, f16), .{
                -fmax(f16), -1e0, 1e-4, 1e2, -fmin(f16), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f16), -tmin(f16), -1e-4, inf(f16), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, f16), .{
                -1e3, -tmin(f16), inf(f16),   -1e4,      -0.0, fmax(f16), 1e2,       1e4, -nan(f16), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f16), -1e0,
                1e3,  -1e-3,      -fmin(f16), -inf(f16), 1e-3, tmin(f16), fmin(f16), 1e1, 1e-4,      -fmax(f16), -1e2,  1e-2, -1e-2, 1e3,  inf(f16), -fmin(f16),
            });

            try testArgs(@Vector(1, f32), @Vector(1, f16), .{
                1e0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, f16), .{
                -inf(f16), -1e-2,
            });
            try testArgs(@Vector(4, f32), @Vector(4, f16), .{
                -1e2, 1e-1, fmax(f16), 1e-2,
            });
            try testArgs(@Vector(8, f32), @Vector(8, f16), .{
                -1e-1, tmin(f16), -1e3, fmin(f16), nan(f16), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f32), @Vector(16, f16), .{
                -fmax(f16), -1e0, 1e-4, 1e2, -fmin(f16), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f16), -tmin(f16), -1e-4, inf(f16), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, f16), .{
                -1e3, -tmin(f16), inf(f16),   -1e4,      -0.0, fmax(f16), 1e2,       1e4, -nan(f16), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f16), -1e0,
                1e3,  -1e-3,      -fmin(f16), -inf(f16), 1e-3, tmin(f16), fmin(f16), 1e1, 1e-4,      -fmax(f16), -1e2,  1e-2, -1e-2, 1e3,  inf(f16), -fmin(f16),
            });

            try testArgs(@Vector(1, f64), @Vector(1, f16), .{
                1e0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, f16), .{
                -inf(f16), -1e-2,
            });
            try testArgs(@Vector(4, f64), @Vector(4, f16), .{
                -1e2, 1e-1, fmax(f16), 1e-2,
            });
            try testArgs(@Vector(8, f64), @Vector(8, f16), .{
                -1e-1, tmin(f16), -1e3, fmin(f16), nan(f16), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f64), @Vector(16, f16), .{
                -fmax(f16), -1e0, 1e-4, 1e2, -fmin(f16), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f16), -tmin(f16), -1e-4, inf(f16), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, f16), .{
                -1e3, -tmin(f16), inf(f16),   -1e4,      -0.0, fmax(f16), 1e2,       1e4, -nan(f16), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f16), -1e0,
                1e3,  -1e-3,      -fmin(f16), -inf(f16), 1e-3, tmin(f16), fmin(f16), 1e1, 1e-4,      -fmax(f16), -1e2,  1e-2, -1e-2, 1e3,  inf(f16), -fmin(f16),
            });

            try testArgs(@Vector(1, f80), @Vector(1, f16), .{
                1e0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, f16), .{
                -inf(f16), -1e-2,
            });
            try testArgs(@Vector(4, f80), @Vector(4, f16), .{
                -1e2, 1e-1, fmax(f16), 1e-2,
            });
            try testArgs(@Vector(8, f80), @Vector(8, f16), .{
                -1e-1, tmin(f16), -1e3, fmin(f16), nan(f16), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f80), @Vector(16, f16), .{
                -fmax(f16), -1e0, 1e-4, 1e2, -fmin(f16), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f16), -tmin(f16), -1e-4, inf(f16), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, f16), .{
                -1e3, -tmin(f16), inf(f16),   -1e4,      -0.0, fmax(f16), 1e2,       1e4, -nan(f16), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f16), -1e0,
                1e3,  -1e-3,      -fmin(f16), -inf(f16), 1e-3, tmin(f16), fmin(f16), 1e1, 1e-4,      -fmax(f16), -1e2,  1e-2, -1e-2, 1e3,  inf(f16), -fmin(f16),
            });

            try testArgs(@Vector(1, f128), @Vector(1, f16), .{
                1e0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, f16), .{
                -inf(f16), -1e-2,
            });
            try testArgs(@Vector(4, f128), @Vector(4, f16), .{
                -1e2, 1e-1, fmax(f16), 1e-2,
            });
            try testArgs(@Vector(8, f128), @Vector(8, f16), .{
                -1e-1, tmin(f16), -1e3, fmin(f16), nan(f16), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f128), @Vector(16, f16), .{
                -fmax(f16), -1e0, 1e-4, 1e2, -fmin(f16), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f16), -tmin(f16), -1e-4, inf(f16), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, f16), .{
                -1e3, -tmin(f16), inf(f16),   -1e4,      -0.0, fmax(f16), 1e2,       1e4, -nan(f16), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f16), -1e0,
                1e3,  -1e-3,      -fmin(f16), -inf(f16), 1e-3, tmin(f16), fmin(f16), 1e1, 1e-4,      -fmax(f16), -1e2,  1e-2, -1e-2, 1e3,  inf(f16), -fmin(f16),
            });

            try testArgs(@Vector(1, f16), @Vector(1, f32), .{
                1e0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, f32), .{
                -inf(f32), -1e-2,
            });
            try testArgs(@Vector(4, f16), @Vector(4, f32), .{
                -1e2, 1e-1, fmax(f32), 1e-2,
            });
            try testArgs(@Vector(8, f16), @Vector(8, f32), .{
                -1e-1, tmin(f32), -1e3, fmin(f32), nan(f32), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f16), @Vector(16, f32), .{
                -fmax(f32), -1e0, 1e-4, 1e2, -fmin(f32), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f32), -tmin(f32), -1e-4, inf(f32), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, f32), .{
                -1e3, -tmin(f32), inf(f32),   -1e4,      -0.0, fmax(f32), 1e2,       1e4, -nan(f32), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f32), -1e0,
                1e3,  -1e-3,      -fmin(f32), -inf(f32), 1e-3, tmin(f32), fmin(f32), 1e1, 1e-4,      -fmax(f32), -1e2,  1e-2, -1e-2, 1e3,  inf(f32), -fmin(f32),
            });

            try testArgs(@Vector(1, f32), @Vector(1, f32), .{
                1e0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, f32), .{
                -inf(f32), -1e-2,
            });
            try testArgs(@Vector(4, f32), @Vector(4, f32), .{
                -1e2, 1e-1, fmax(f32), 1e-2,
            });
            try testArgs(@Vector(8, f32), @Vector(8, f32), .{
                -1e-1, tmin(f32), -1e3, fmin(f32), nan(f32), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f32), @Vector(16, f32), .{
                -fmax(f32), -1e0, 1e-4, 1e2, -fmin(f32), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f32), -tmin(f32), -1e-4, inf(f32), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, f32), .{
                -1e3, -tmin(f32), inf(f32),   -1e4,      -0.0, fmax(f32), 1e2,       1e4, -nan(f32), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f32), -1e0,
                1e3,  -1e-3,      -fmin(f32), -inf(f32), 1e-3, tmin(f32), fmin(f32), 1e1, 1e-4,      -fmax(f32), -1e2,  1e-2, -1e-2, 1e3,  inf(f32), -fmin(f32),
            });

            try testArgs(@Vector(1, f64), @Vector(1, f32), .{
                1e0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, f32), .{
                -inf(f32), -1e-2,
            });
            try testArgs(@Vector(4, f64), @Vector(4, f32), .{
                -1e2, 1e-1, fmax(f32), 1e-2,
            });
            try testArgs(@Vector(8, f64), @Vector(8, f32), .{
                -1e-1, tmin(f32), -1e3, fmin(f32), nan(f32), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f64), @Vector(16, f32), .{
                -fmax(f32), -1e0, 1e-4, 1e2, -fmin(f32), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f32), -tmin(f32), -1e-4, inf(f32), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, f32), .{
                -1e3, -tmin(f32), inf(f32),   -1e4,      -0.0, fmax(f32), 1e2,       1e4, -nan(f32), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f32), -1e0,
                1e3,  -1e-3,      -fmin(f32), -inf(f32), 1e-3, tmin(f32), fmin(f32), 1e1, 1e-4,      -fmax(f32), -1e2,  1e-2, -1e-2, 1e3,  inf(f32), -fmin(f32),
            });

            try testArgs(@Vector(1, f80), @Vector(1, f32), .{
                1e0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, f32), .{
                -inf(f32), -1e-2,
            });
            try testArgs(@Vector(4, f80), @Vector(4, f32), .{
                -1e2, 1e-1, fmax(f32), 1e-2,
            });
            try testArgs(@Vector(8, f80), @Vector(8, f32), .{
                -1e-1, tmin(f32), -1e3, fmin(f32), nan(f32), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f80), @Vector(16, f32), .{
                -fmax(f32), -1e0, 1e-4, 1e2, -fmin(f32), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f32), -tmin(f32), -1e-4, inf(f32), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, f32), .{
                -1e3, -tmin(f32), inf(f32),   -1e4,      -0.0, fmax(f32), 1e2,       1e4, -nan(f32), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f32), -1e0,
                1e3,  -1e-3,      -fmin(f32), -inf(f32), 1e-3, tmin(f32), fmin(f32), 1e1, 1e-4,      -fmax(f32), -1e2,  1e-2, -1e-2, 1e3,  inf(f32), -fmin(f32),
            });

            try testArgs(@Vector(1, f128), @Vector(1, f32), .{
                1e0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, f32), .{
                -inf(f32), -1e-2,
            });
            try testArgs(@Vector(4, f128), @Vector(4, f32), .{
                -1e2, 1e-1, fmax(f32), 1e-2,
            });
            try testArgs(@Vector(8, f128), @Vector(8, f32), .{
                -1e-1, tmin(f32), -1e3, fmin(f32), nan(f32), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f128), @Vector(16, f32), .{
                -fmax(f32), -1e0, 1e-4, 1e2, -fmin(f32), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f32), -tmin(f32), -1e-4, inf(f32), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, f32), .{
                -1e3, -tmin(f32), inf(f32),   -1e4,      -0.0, fmax(f32), 1e2,       1e4, -nan(f32), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f32), -1e0,
                1e3,  -1e-3,      -fmin(f32), -inf(f32), 1e-3, tmin(f32), fmin(f32), 1e1, 1e-4,      -fmax(f32), -1e2,  1e-2, -1e-2, 1e3,  inf(f32), -fmin(f32),
            });

            try testArgs(@Vector(1, f16), @Vector(1, f64), .{
                1e0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, f64), .{
                -inf(f64), -1e-2,
            });
            try testArgs(@Vector(4, f16), @Vector(4, f64), .{
                -1e2, 1e-1, fmax(f64), 1e-2,
            });
            try testArgs(@Vector(8, f16), @Vector(8, f64), .{
                -1e-1, tmin(f64), -1e3, fmin(f64), nan(f64), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f16), @Vector(16, f64), .{
                -fmax(f64), -1e0, 1e-4, 1e2, -fmin(f64), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f64), -tmin(f64), -1e-4, inf(f64), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, f64), .{
                -1e3, -tmin(f64), inf(f64),   -1e4,      -0.0, fmax(f64), 1e2,       1e4, -nan(f64), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f64), -1e0,
                1e3,  -1e-3,      -fmin(f64), -inf(f64), 1e-3, tmin(f64), fmin(f64), 1e1, 1e-4,      -fmax(f64), -1e2,  1e-2, -1e-2, 1e3,  inf(f64), -fmin(f64),
            });

            try testArgs(@Vector(1, f32), @Vector(1, f64), .{
                1e0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, f64), .{
                -inf(f64), -1e-2,
            });
            try testArgs(@Vector(4, f32), @Vector(4, f64), .{
                -1e2, 1e-1, fmax(f64), 1e-2,
            });
            try testArgs(@Vector(8, f32), @Vector(8, f64), .{
                -1e-1, tmin(f64), -1e3, fmin(f64), nan(f64), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f32), @Vector(16, f64), .{
                -fmax(f64), -1e0, 1e-4, 1e2, -fmin(f64), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f64), -tmin(f64), -1e-4, inf(f64), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, f64), .{
                -1e3, -tmin(f64), inf(f64),   -1e4,      -0.0, fmax(f64), 1e2,       1e4, -nan(f64), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f64), -1e0,
                1e3,  -1e-3,      -fmin(f64), -inf(f64), 1e-3, tmin(f64), fmin(f64), 1e1, 1e-4,      -fmax(f64), -1e2,  1e-2, -1e-2, 1e3,  inf(f64), -fmin(f64),
            });

            try testArgs(@Vector(1, f64), @Vector(1, f64), .{
                1e0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, f64), .{
                -inf(f64), -1e-2,
            });
            try testArgs(@Vector(4, f64), @Vector(4, f64), .{
                -1e2, 1e-1, fmax(f64), 1e-2,
            });
            try testArgs(@Vector(8, f64), @Vector(8, f64), .{
                -1e-1, tmin(f64), -1e3, fmin(f64), nan(f64), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f64), @Vector(16, f64), .{
                -fmax(f64), -1e0, 1e-4, 1e2, -fmin(f64), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f64), -tmin(f64), -1e-4, inf(f64), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, f64), .{
                -1e3, -tmin(f64), inf(f64),   -1e4,      -0.0, fmax(f64), 1e2,       1e4, -nan(f64), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f64), -1e0,
                1e3,  -1e-3,      -fmin(f64), -inf(f64), 1e-3, tmin(f64), fmin(f64), 1e1, 1e-4,      -fmax(f64), -1e2,  1e-2, -1e-2, 1e3,  inf(f64), -fmin(f64),
            });

            try testArgs(@Vector(1, f80), @Vector(1, f64), .{
                1e0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, f64), .{
                -inf(f64), -1e-2,
            });
            try testArgs(@Vector(4, f80), @Vector(4, f64), .{
                -1e2, 1e-1, fmax(f64), 1e-2,
            });
            try testArgs(@Vector(8, f80), @Vector(8, f64), .{
                -1e-1, tmin(f64), -1e3, fmin(f64), nan(f64), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f80), @Vector(16, f64), .{
                -fmax(f64), -1e0, 1e-4, 1e2, -fmin(f64), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f64), -tmin(f64), -1e-4, inf(f64), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, f64), .{
                -1e3, -tmin(f64), inf(f64),   -1e4,      -0.0, fmax(f64), 1e2,       1e4, -nan(f64), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f64), -1e0,
                1e3,  -1e-3,      -fmin(f64), -inf(f64), 1e-3, tmin(f64), fmin(f64), 1e1, 1e-4,      -fmax(f64), -1e2,  1e-2, -1e-2, 1e3,  inf(f64), -fmin(f64),
            });

            try testArgs(@Vector(1, f128), @Vector(1, f64), .{
                1e0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, f64), .{
                -inf(f64), -1e-2,
            });
            try testArgs(@Vector(4, f128), @Vector(4, f64), .{
                -1e2, 1e-1, fmax(f64), 1e-2,
            });
            try testArgs(@Vector(8, f128), @Vector(8, f64), .{
                -1e-1, tmin(f64), -1e3, fmin(f64), nan(f64), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f128), @Vector(16, f64), .{
                -fmax(f64), -1e0, 1e-4, 1e2, -fmin(f64), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f64), -tmin(f64), -1e-4, inf(f64), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, f64), .{
                -1e3, -tmin(f64), inf(f64),   -1e4,      -0.0, fmax(f64), 1e2,       1e4, -nan(f64), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f64), -1e0,
                1e3,  -1e-3,      -fmin(f64), -inf(f64), 1e-3, tmin(f64), fmin(f64), 1e1, 1e-4,      -fmax(f64), -1e2,  1e-2, -1e-2, 1e3,  inf(f64), -fmin(f64),
            });

            try testArgs(@Vector(1, f16), @Vector(1, f80), .{
                1e0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, f80), .{
                -inf(f80), -1e-2,
            });
            try testArgs(@Vector(4, f16), @Vector(4, f80), .{
                -1e2, 1e-1, fmax(f80), 1e-2,
            });
            try testArgs(@Vector(8, f16), @Vector(8, f80), .{
                -1e-1, tmin(f80), -1e3, fmin(f80), nan(f80), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f16), @Vector(16, f80), .{
                -fmax(f80), -1e0, 1e-4, 1e2, -fmin(f80), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f80), -tmin(f80), -1e-4, inf(f80), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, f80), .{
                -1e3, -tmin(f80), inf(f80),   -1e4,      -0.0, fmax(f80), 1e2,       1e4, -nan(f80), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f80), -1e0,
                1e3,  -1e-3,      -fmin(f80), -inf(f80), 1e-3, tmin(f80), fmin(f80), 1e1, 1e-4,      -fmax(f80), -1e2,  1e-2, -1e-2, 1e3,  inf(f80), -fmin(f80),
            });

            try testArgs(@Vector(1, f32), @Vector(1, f80), .{
                1e0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, f80), .{
                -inf(f80), -1e-2,
            });
            try testArgs(@Vector(4, f32), @Vector(4, f80), .{
                -1e2, 1e-1, fmax(f80), 1e-2,
            });
            try testArgs(@Vector(8, f32), @Vector(8, f80), .{
                -1e-1, tmin(f80), -1e3, fmin(f80), nan(f80), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f32), @Vector(16, f80), .{
                -fmax(f80), -1e0, 1e-4, 1e2, -fmin(f80), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f80), -tmin(f80), -1e-4, inf(f80), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, f80), .{
                -1e3, -tmin(f80), inf(f80),   -1e4,      -0.0, fmax(f80), 1e2,       1e4, -nan(f80), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f80), -1e0,
                1e3,  -1e-3,      -fmin(f80), -inf(f80), 1e-3, tmin(f80), fmin(f80), 1e1, 1e-4,      -fmax(f80), -1e2,  1e-2, -1e-2, 1e3,  inf(f80), -fmin(f80),
            });

            try testArgs(@Vector(1, f64), @Vector(1, f80), .{
                1e0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, f80), .{
                -inf(f80), -1e-2,
            });
            try testArgs(@Vector(4, f64), @Vector(4, f80), .{
                -1e2, 1e-1, fmax(f80), 1e-2,
            });
            try testArgs(@Vector(8, f64), @Vector(8, f80), .{
                -1e-1, tmin(f80), -1e3, fmin(f80), nan(f80), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f64), @Vector(16, f80), .{
                -fmax(f80), -1e0, 1e-4, 1e2, -fmin(f80), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f80), -tmin(f80), -1e-4, inf(f80), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, f80), .{
                -1e3, -tmin(f80), inf(f80),   -1e4,      -0.0, fmax(f80), 1e2,       1e4, -nan(f80), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f80), -1e0,
                1e3,  -1e-3,      -fmin(f80), -inf(f80), 1e-3, tmin(f80), fmin(f80), 1e1, 1e-4,      -fmax(f80), -1e2,  1e-2, -1e-2, 1e3,  inf(f80), -fmin(f80),
            });

            try testArgs(@Vector(1, f80), @Vector(1, f80), .{
                1e0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, f80), .{
                -inf(f80), -1e-2,
            });
            try testArgs(@Vector(4, f80), @Vector(4, f80), .{
                -1e2, 1e-1, fmax(f80), 1e-2,
            });
            try testArgs(@Vector(8, f80), @Vector(8, f80), .{
                -1e-1, tmin(f80), -1e3, fmin(f80), nan(f80), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f80), @Vector(16, f80), .{
                -fmax(f80), -1e0, 1e-4, 1e2, -fmin(f80), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f80), -tmin(f80), -1e-4, inf(f80), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, f80), .{
                -1e3, -tmin(f80), inf(f80),   -1e4,      -0.0, fmax(f80), 1e2,       1e4, -nan(f80), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f80), -1e0,
                1e3,  -1e-3,      -fmin(f80), -inf(f80), 1e-3, tmin(f80), fmin(f80), 1e1, 1e-4,      -fmax(f80), -1e2,  1e-2, -1e-2, 1e3,  inf(f80), -fmin(f80),
            });

            try testArgs(@Vector(1, f128), @Vector(1, f80), .{
                1e0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, f80), .{
                -inf(f80), -1e-2,
            });
            try testArgs(@Vector(4, f128), @Vector(4, f80), .{
                -1e2, 1e-1, fmax(f80), 1e-2,
            });
            try testArgs(@Vector(8, f128), @Vector(8, f80), .{
                -1e-1, tmin(f80), -1e3, fmin(f80), nan(f80), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f128), @Vector(16, f80), .{
                -fmax(f80), -1e0, 1e-4, 1e2, -fmin(f80), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f80), -tmin(f80), -1e-4, inf(f80), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, f80), .{
                -1e3, -tmin(f80), inf(f80),   -1e4,      -0.0, fmax(f80), 1e2,       1e4, -nan(f80), 0.0,        -1e-4, -1e1, 1e0,   1e-1, nan(f80), -1e0,
                1e3,  -1e-3,      -fmin(f80), -inf(f80), 1e-3, tmin(f80), fmin(f80), 1e1, 1e-4,      -fmax(f80), -1e2,  1e-2, -1e-2, 1e3,  inf(f80), -fmin(f80),
            });

            try testArgs(@Vector(1, f16), @Vector(1, f128), .{
                1e0,
            });
            try testArgs(@Vector(2, f16), @Vector(2, f128), .{
                -inf(f128), -1e-2,
            });
            try testArgs(@Vector(4, f16), @Vector(4, f128), .{
                -1e2, 1e-1, fmax(f128), 1e-2,
            });
            try testArgs(@Vector(8, f16), @Vector(8, f128), .{
                -1e-1, tmin(f128), -1e3, fmin(f128), nan(f128), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f16), @Vector(16, f128), .{
                -fmax(f128), -1e0, 1e-4, 1e2, -fmin(f128), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f128), -tmin(f128), -1e-4, inf(f128), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f16), @Vector(32, f128), .{
                -1e3, -tmin(f128), inf(f128),   -1e4,       -0.0, fmax(f128), 1e2,        1e4, -nan(f128), 0.0,         -1e-4, -1e1, 1e0,   1e-1, nan(f128), -1e0,
                1e3,  -1e-3,       -fmin(f128), -inf(f128), 1e-3, tmin(f128), fmin(f128), 1e1, 1e-4,       -fmax(f128), -1e2,  1e-2, -1e-2, 1e3,  inf(f128), -fmin(f128),
            });

            try testArgs(@Vector(1, f32), @Vector(1, f128), .{
                1e0,
            });
            try testArgs(@Vector(2, f32), @Vector(2, f128), .{
                -inf(f128), -1e-2,
            });
            try testArgs(@Vector(4, f32), @Vector(4, f128), .{
                -1e2, 1e-1, fmax(f128), 1e-2,
            });
            try testArgs(@Vector(8, f32), @Vector(8, f128), .{
                -1e-1, tmin(f128), -1e3, fmin(f128), nan(f128), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f32), @Vector(16, f128), .{
                -fmax(f128), -1e0, 1e-4, 1e2, -fmin(f128), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f128), -tmin(f128), -1e-4, inf(f128), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f32), @Vector(32, f128), .{
                -1e3, -tmin(f128), inf(f128),   -1e4,       -0.0, fmax(f128), 1e2,        1e4, -nan(f128), 0.0,         -1e-4, -1e1, 1e0,   1e-1, nan(f128), -1e0,
                1e3,  -1e-3,       -fmin(f128), -inf(f128), 1e-3, tmin(f128), fmin(f128), 1e1, 1e-4,       -fmax(f128), -1e2,  1e-2, -1e-2, 1e3,  inf(f128), -fmin(f128),
            });

            try testArgs(@Vector(1, f64), @Vector(1, f128), .{
                1e0,
            });
            try testArgs(@Vector(2, f64), @Vector(2, f128), .{
                -inf(f128), -1e-2,
            });
            try testArgs(@Vector(4, f64), @Vector(4, f128), .{
                -1e2, 1e-1, fmax(f128), 1e-2,
            });
            try testArgs(@Vector(8, f64), @Vector(8, f128), .{
                -1e-1, tmin(f128), -1e3, fmin(f128), nan(f128), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f64), @Vector(16, f128), .{
                -fmax(f128), -1e0, 1e-4, 1e2, -fmin(f128), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f128), -tmin(f128), -1e-4, inf(f128), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f64), @Vector(32, f128), .{
                -1e3, -tmin(f128), inf(f128),   -1e4,       -0.0, fmax(f128), 1e2,        1e4, -nan(f128), 0.0,         -1e-4, -1e1, 1e0,   1e-1, nan(f128), -1e0,
                1e3,  -1e-3,       -fmin(f128), -inf(f128), 1e-3, tmin(f128), fmin(f128), 1e1, 1e-4,       -fmax(f128), -1e2,  1e-2, -1e-2, 1e3,  inf(f128), -fmin(f128),
            });

            try testArgs(@Vector(1, f80), @Vector(1, f128), .{
                1e0,
            });
            try testArgs(@Vector(2, f80), @Vector(2, f128), .{
                -inf(f128), -1e-2,
            });
            try testArgs(@Vector(4, f80), @Vector(4, f128), .{
                -1e2, 1e-1, fmax(f128), 1e-2,
            });
            try testArgs(@Vector(8, f80), @Vector(8, f128), .{
                -1e-1, tmin(f128), -1e3, fmin(f128), nan(f128), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f80), @Vector(16, f128), .{
                -fmax(f128), -1e0, 1e-4, 1e2, -fmin(f128), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f128), -tmin(f128), -1e-4, inf(f128), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f80), @Vector(32, f128), .{
                -1e3, -tmin(f128), inf(f128),   -1e4,       -0.0, fmax(f128), 1e2,        1e4, -nan(f128), 0.0,         -1e-4, -1e1, 1e0,   1e-1, nan(f128), -1e0,
                1e3,  -1e-3,       -fmin(f128), -inf(f128), 1e-3, tmin(f128), fmin(f128), 1e1, 1e-4,       -fmax(f128), -1e2,  1e-2, -1e-2, 1e3,  inf(f128), -fmin(f128),
            });

            try testArgs(@Vector(1, f128), @Vector(1, f128), .{
                1e0,
            });
            try testArgs(@Vector(2, f128), @Vector(2, f128), .{
                -inf(f128), -1e-2,
            });
            try testArgs(@Vector(4, f128), @Vector(4, f128), .{
                -1e2, 1e-1, fmax(f128), 1e-2,
            });
            try testArgs(@Vector(8, f128), @Vector(8, f128), .{
                -1e-1, tmin(f128), -1e3, fmin(f128), nan(f128), -1e-3, 1e1, 1e4,
            });
            try testArgs(@Vector(16, f128), @Vector(16, f128), .{
                -fmax(f128), -1e0, 1e-4, 1e2, -fmin(f128), -1e1, 0.0, -1e4, -0.0, 1e3, -nan(f128), -tmin(f128), -1e-4, inf(f128), 1e-3, -1e-1,
            });
            try testArgs(@Vector(32, f128), @Vector(32, f128), .{
                -1e3, -tmin(f128), inf(f128),   -1e4,       -0.0, fmax(f128), 1e2,        1e4, -nan(f128), 0.0,         -1e-4, -1e1, 1e0,   1e-1, nan(f128), -1e0,
                1e3,  -1e-3,       -fmin(f128), -inf(f128), 1e-3, tmin(f128), fmin(f128), 1e1, 1e-4,       -fmax(f128), -1e2,  1e-2, -1e-2, 1e3,  inf(f128), -fmin(f128),
            });
        }
        fn testIntsFromFloats() !void {
            @setEvalBranchQuota(2_600);

            try testArgs(i8, f16, -0x0.8p8);
            try testArgs(i8, f16, next(f16, -0x0.8p8, -0.0));
            try testArgs(i8, f16, next(f16, next(f16, -0x0.8p8, -0.0), -0.0));
            try testArgs(i8, f16, -1e2);
            try testArgs(i8, f16, -1e1);
            try testArgs(i8, f16, -1e0);
            try testArgs(i8, f16, -1e-1);
            try testArgs(i8, f16, -0.0);
            try testArgs(i8, f16, 0.0);
            try testArgs(i8, f16, 1e-1);
            try testArgs(i8, f16, 1e0);
            try testArgs(i8, f16, 1e1);
            try testArgs(i8, f16, 1e2);
            try testArgs(i8, f16, next(f16, next(f16, 0x0.8p8, 0.0), 0.0));
            try testArgs(i8, f16, next(f16, 0x0.8p8, 0.0));

            try testArgs(u8, f16, -0.0);
            try testArgs(u8, f16, 0.0);
            try testArgs(u8, f16, 1e-1);
            try testArgs(u8, f16, 1e0);
            try testArgs(u8, f16, 1e1);
            try testArgs(u8, f16, 1e2);
            try testArgs(u8, f16, next(f16, next(f16, 0x1p8, 0.0), 0.0));
            try testArgs(u8, f16, next(f16, 0x1p8, 0.0));

            try testArgs(i16, f16, -1e4);
            try testArgs(i16, f16, -1e3);
            try testArgs(i16, f16, -1e2);
            try testArgs(i16, f16, -1e1);
            try testArgs(i16, f16, -1e0);
            try testArgs(i16, f16, -1e-1);
            try testArgs(i16, f16, -0.0);
            try testArgs(i16, f16, 0.0);
            try testArgs(i16, f16, 1e-1);
            try testArgs(i16, f16, 1e0);
            try testArgs(i16, f16, 1e1);
            try testArgs(i16, f16, 1e2);
            try testArgs(i16, f16, 1e3);
            try testArgs(i16, f16, 1e4);
            try testArgs(i16, f16, next(f16, next(f16, 0x0.8p16, 0.0), 0.0));
            try testArgs(i16, f16, next(f16, 0x0.8p16, 0.0));

            try testArgs(u16, f16, -0.0);
            try testArgs(u16, f16, 0.0);
            try testArgs(u16, f16, 1e-1);
            try testArgs(u16, f16, 1e0);
            try testArgs(u16, f16, 1e1);
            try testArgs(u16, f16, 1e2);
            try testArgs(u16, f16, 1e3);
            try testArgs(u16, f16, 1e4);
            try testArgs(u16, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(u16, f16, next(f16, fmax(f16), 0.0));
            try testArgs(u16, f16, fmax(f16));

            try testArgs(i32, f16, -fmax(f16));
            try testArgs(i32, f16, next(f16, -fmax(f16), -0.0));
            try testArgs(i32, f16, next(f16, next(f16, -fmax(f16), -0.0), -0.0));
            try testArgs(i32, f16, -1e4);
            try testArgs(i32, f16, -1e3);
            try testArgs(i32, f16, -1e2);
            try testArgs(i32, f16, -1e1);
            try testArgs(i32, f16, -1e0);
            try testArgs(i32, f16, -1e-1);
            try testArgs(i32, f16, -0.0);
            try testArgs(i32, f16, 0.0);
            try testArgs(i32, f16, 1e-1);
            try testArgs(i32, f16, 1e0);
            try testArgs(i32, f16, 1e1);
            try testArgs(i32, f16, 1e2);
            try testArgs(i32, f16, 1e3);
            try testArgs(i32, f16, 1e4);
            try testArgs(i32, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(i32, f16, next(f16, fmax(f16), 0.0));
            try testArgs(i32, f16, fmax(f16));

            try testArgs(u32, f16, -0.0);
            try testArgs(u32, f16, 0.0);
            try testArgs(u32, f16, 1e-1);
            try testArgs(u32, f16, 1e0);
            try testArgs(u32, f16, 1e1);
            try testArgs(u32, f16, 1e2);
            try testArgs(u32, f16, 1e3);
            try testArgs(u32, f16, 1e4);
            try testArgs(u32, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(u32, f16, next(f16, fmax(f16), 0.0));
            try testArgs(u32, f16, fmax(f16));

            try testArgs(i64, f16, -fmax(f16));
            try testArgs(i64, f16, next(f16, -fmax(f16), -0.0));
            try testArgs(i64, f16, next(f16, next(f16, -fmax(f16), -0.0), -0.0));
            try testArgs(i64, f16, -1e4);
            try testArgs(i64, f16, -1e3);
            try testArgs(i64, f16, -1e2);
            try testArgs(i64, f16, -1e1);
            try testArgs(i64, f16, -1e0);
            try testArgs(i64, f16, -1e-1);
            try testArgs(i64, f16, -0.0);
            try testArgs(i64, f16, 0.0);
            try testArgs(i64, f16, 1e-1);
            try testArgs(i64, f16, 1e0);
            try testArgs(i64, f16, 1e1);
            try testArgs(i64, f16, 1e2);
            try testArgs(i64, f16, 1e3);
            try testArgs(i64, f16, 1e4);
            try testArgs(i64, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(i64, f16, next(f16, fmax(f16), 0.0));
            try testArgs(i64, f16, fmax(f16));

            try testArgs(u64, f16, -0.0);
            try testArgs(u64, f16, 0.0);
            try testArgs(u64, f16, 1e-1);
            try testArgs(u64, f16, 1e0);
            try testArgs(u64, f16, 1e1);
            try testArgs(u64, f16, 1e2);
            try testArgs(u64, f16, 1e3);
            try testArgs(u64, f16, 1e4);
            try testArgs(u64, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(u64, f16, next(f16, fmax(f16), 0.0));
            try testArgs(u64, f16, fmax(f16));

            try testArgs(i128, f16, -fmax(f16));
            try testArgs(i128, f16, next(f16, -fmax(f16), -0.0));
            try testArgs(i128, f16, next(f16, next(f16, -fmax(f16), -0.0), -0.0));
            try testArgs(i128, f16, -1e4);
            try testArgs(i128, f16, -1e3);
            try testArgs(i128, f16, -1e2);
            try testArgs(i128, f16, -1e1);
            try testArgs(i128, f16, -1e0);
            try testArgs(i128, f16, -1e-1);
            try testArgs(i128, f16, -0.0);
            try testArgs(i128, f16, 0.0);
            try testArgs(i128, f16, 1e-1);
            try testArgs(i128, f16, 1e0);
            try testArgs(i128, f16, 1e1);
            try testArgs(i128, f16, 1e2);
            try testArgs(i128, f16, 1e3);
            try testArgs(i128, f16, 1e4);
            try testArgs(i128, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(i128, f16, next(f16, fmax(f16), 0.0));
            try testArgs(i128, f16, fmax(f16));

            try testArgs(u128, f16, -0.0);
            try testArgs(u128, f16, 0.0);
            try testArgs(u128, f16, 1e-1);
            try testArgs(u128, f16, 1e0);
            try testArgs(u128, f16, 1e1);
            try testArgs(u128, f16, 1e2);
            try testArgs(u128, f16, 1e3);
            try testArgs(u128, f16, 1e4);
            try testArgs(u128, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(u128, f16, next(f16, fmax(f16), 0.0));
            try testArgs(u128, f16, fmax(f16));

            try testArgs(i256, f16, -fmax(f16));
            try testArgs(i256, f16, next(f16, -fmax(f16), -0.0));
            try testArgs(i256, f16, next(f16, next(f16, -fmax(f16), -0.0), -0.0));
            try testArgs(i256, f16, -1e4);
            try testArgs(i256, f16, -1e3);
            try testArgs(i256, f16, -1e2);
            try testArgs(i256, f16, -1e1);
            try testArgs(i256, f16, -1e0);
            try testArgs(i256, f16, -1e-1);
            try testArgs(i256, f16, -0.0);
            try testArgs(i256, f16, 0.0);
            try testArgs(i256, f16, 1e-1);
            try testArgs(i256, f16, 1e0);
            try testArgs(i256, f16, 1e1);
            try testArgs(i256, f16, 1e2);
            try testArgs(i256, f16, 1e3);
            try testArgs(i256, f16, 1e4);
            try testArgs(i256, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(i256, f16, next(f16, fmax(f16), 0.0));
            try testArgs(i256, f16, fmax(f16));

            try testArgs(u256, f16, -0.0);
            try testArgs(u256, f16, 0.0);
            try testArgs(u256, f16, 1e-1);
            try testArgs(u256, f16, 1e0);
            try testArgs(u256, f16, 1e1);
            try testArgs(u256, f16, 1e2);
            try testArgs(u256, f16, 1e3);
            try testArgs(u256, f16, 1e4);
            try testArgs(u256, f16, next(f16, next(f16, fmax(f16), 0.0), 0.0));
            try testArgs(u256, f16, next(f16, fmax(f16), 0.0));
            try testArgs(u256, f16, fmax(f16));

            try testArgs(i8, f32, -0x0.8p8);
            try testArgs(i8, f32, next(f32, -0x0.8p8, -0.0));
            try testArgs(i8, f32, next(f32, next(f32, -0x0.8p8, -0.0), -0.0));
            try testArgs(i8, f32, -1e2);
            try testArgs(i8, f32, -1e1);
            try testArgs(i8, f32, -1e0);
            try testArgs(i8, f32, -1e-1);
            try testArgs(i8, f32, -0.0);
            try testArgs(i8, f32, 0.0);
            try testArgs(i8, f32, 1e-1);
            try testArgs(i8, f32, 1e0);
            try testArgs(i8, f32, 1e1);
            try testArgs(i8, f32, 1e2);
            try testArgs(i8, f32, next(f32, next(f32, 0x0.8p8, 0.0), 0.0));
            try testArgs(i8, f32, next(f32, 0x0.8p8, 0.0));

            try testArgs(u8, f32, -0.0);
            try testArgs(u8, f32, 0.0);
            try testArgs(u8, f32, 1e-1);
            try testArgs(u8, f32, 1e0);
            try testArgs(u8, f32, 1e1);
            try testArgs(u8, f32, 1e2);
            try testArgs(u8, f32, next(f32, next(f32, 0x1p8, 0.0), 0.0));
            try testArgs(u8, f32, next(f32, 0x1p8, 0.0));

            try testArgs(i16, f32, -0x0.8p16);
            try testArgs(i16, f32, next(f32, -0x0.8p16, -0.0));
            try testArgs(i16, f32, next(f32, next(f32, -0x0.8p16, -0.0), -0.0));
            try testArgs(i16, f32, -1e4);
            try testArgs(i16, f32, -1e3);
            try testArgs(i16, f32, -1e2);
            try testArgs(i16, f32, -1e1);
            try testArgs(i16, f32, -1e0);
            try testArgs(i16, f32, -1e-1);
            try testArgs(i16, f32, -0.0);
            try testArgs(i16, f32, 0.0);
            try testArgs(i16, f32, 1e-1);
            try testArgs(i16, f32, 1e0);
            try testArgs(i16, f32, 1e1);
            try testArgs(i16, f32, 1e2);
            try testArgs(i16, f32, 1e3);
            try testArgs(i16, f32, 1e4);
            try testArgs(i16, f32, next(f32, next(f32, 0x0.8p16, 0.0), 0.0));
            try testArgs(i16, f32, next(f32, 0x0.8p16, 0.0));

            try testArgs(u16, f32, -0.0);
            try testArgs(u16, f32, 0.0);
            try testArgs(u16, f32, 1e-1);
            try testArgs(u16, f32, 1e0);
            try testArgs(u16, f32, 1e1);
            try testArgs(u16, f32, 1e2);
            try testArgs(u16, f32, 1e3);
            try testArgs(u16, f32, 1e4);
            try testArgs(u16, f32, next(f32, next(f32, 0x1p16, 0.0), 0.0));
            try testArgs(u16, f32, next(f32, 0x1p16, 0.0));

            try testArgs(i32, f32, -0x0.8p32);
            try testArgs(i32, f32, next(f32, -0x0.8p32, -0.0));
            try testArgs(i32, f32, next(f32, next(f32, -0x0.8p32, -0.0), -0.0));
            try testArgs(i32, f32, -1e9);
            try testArgs(i32, f32, -1e8);
            try testArgs(i32, f32, -1e7);
            try testArgs(i32, f32, -1e6);
            try testArgs(i32, f32, -1e5);
            try testArgs(i32, f32, -1e4);
            try testArgs(i32, f32, -1e3);
            try testArgs(i32, f32, -1e2);
            try testArgs(i32, f32, -1e1);
            try testArgs(i32, f32, -1e0);
            try testArgs(i32, f32, -1e-1);
            try testArgs(i32, f32, -0.0);
            try testArgs(i32, f32, 0.0);
            try testArgs(i32, f32, 1e-1);
            try testArgs(i32, f32, 1e0);
            try testArgs(i32, f32, 1e1);
            try testArgs(i32, f32, 1e2);
            try testArgs(i32, f32, 1e3);
            try testArgs(i32, f32, 1e4);
            try testArgs(i32, f32, 1e5);
            try testArgs(i32, f32, 1e6);
            try testArgs(i32, f32, 1e7);
            try testArgs(i32, f32, 1e8);
            try testArgs(i32, f32, 1e9);
            try testArgs(i32, f32, next(f32, next(f32, 0x0.8p32, 0.0), 0.0));
            try testArgs(i32, f32, next(f32, 0x0.8p32, 0.0));

            try testArgs(u32, f32, -0.0);
            try testArgs(u32, f32, 0.0);
            try testArgs(u32, f32, 1e-1);
            try testArgs(u32, f32, 1e0);
            try testArgs(u32, f32, 1e1);
            try testArgs(u32, f32, 1e2);
            try testArgs(u32, f32, 1e3);
            try testArgs(u32, f32, 1e4);
            try testArgs(u32, f32, 1e5);
            try testArgs(u32, f32, 1e6);
            try testArgs(u32, f32, 1e7);
            try testArgs(u32, f32, 1e8);
            try testArgs(u32, f32, 1e9);
            try testArgs(u32, f32, next(f32, next(f32, 0x1p32, 0.0), 0.0));
            try testArgs(u32, f32, next(f32, 0x1p32, 0.0));

            try testArgs(i64, f32, -0x0.8p64);
            try testArgs(i64, f32, next(f32, -0x0.8p64, -0.0));
            try testArgs(i64, f32, next(f32, next(f32, -0x0.8p64, -0.0), -0.0));
            try testArgs(i64, f32, -1e18);
            try testArgs(i64, f32, -1e16);
            try testArgs(i64, f32, -1e14);
            try testArgs(i64, f32, -1e12);
            try testArgs(i64, f32, -1e10);
            try testArgs(i64, f32, -1e8);
            try testArgs(i64, f32, -1e6);
            try testArgs(i64, f32, -1e4);
            try testArgs(i64, f32, -1e2);
            try testArgs(i64, f32, -1e0);
            try testArgs(i64, f32, -1e-1);
            try testArgs(i64, f32, -0.0);
            try testArgs(i64, f32, 0.0);
            try testArgs(i64, f32, 1e-1);
            try testArgs(i64, f32, 1e0);
            try testArgs(i64, f32, 1e2);
            try testArgs(i64, f32, 1e4);
            try testArgs(i64, f32, 1e6);
            try testArgs(i64, f32, 1e8);
            try testArgs(i64, f32, 1e10);
            try testArgs(i64, f32, 1e12);
            try testArgs(i64, f32, 1e14);
            try testArgs(i64, f32, 1e16);
            try testArgs(i64, f32, 1e18);
            try testArgs(i64, f32, next(f32, next(f32, 0x0.8p64, 0.0), 0.0));
            try testArgs(i64, f32, next(f32, 0x0.8p64, 0.0));

            try testArgs(u64, f32, -0.0);
            try testArgs(u64, f32, 0.0);
            try testArgs(u64, f32, 1e-1);
            try testArgs(u64, f32, 1e0);
            try testArgs(u64, f32, 1e2);
            try testArgs(u64, f32, 1e4);
            try testArgs(u64, f32, 1e6);
            try testArgs(u64, f32, 1e8);
            try testArgs(u64, f32, 1e10);
            try testArgs(u64, f32, 1e12);
            try testArgs(u64, f32, 1e14);
            try testArgs(u64, f32, 1e16);
            try testArgs(u64, f32, 1e18);
            try testArgs(u64, f32, next(f32, next(f32, 0x1p64, 0.0), 0.0));
            try testArgs(u64, f32, next(f32, 0x1p64, 0.0));

            try testArgs(i128, f32, -0x0.8p128);
            try testArgs(i128, f32, next(f32, -0x0.8p128, -0.0));
            try testArgs(i128, f32, next(f32, next(f32, -0x0.8p128, -0.0), -0.0));
            try testArgs(i128, f32, -1e38);
            try testArgs(i128, f32, -1e34);
            try testArgs(i128, f32, -1e30);
            try testArgs(i128, f32, -1e26);
            try testArgs(i128, f32, -1e22);
            try testArgs(i128, f32, -1e18);
            try testArgs(i128, f32, -1e14);
            try testArgs(i128, f32, -1e10);
            try testArgs(i128, f32, -1e6);
            try testArgs(i128, f32, -1e2);
            try testArgs(i128, f32, -1e0);
            try testArgs(i128, f32, -1e-1);
            try testArgs(i128, f32, -0.0);
            try testArgs(i128, f32, 0.0);
            try testArgs(i128, f32, 1e-1);
            try testArgs(i128, f32, 1e0);
            try testArgs(i128, f32, 1e2);
            try testArgs(i128, f32, 1e6);
            try testArgs(i128, f32, 1e10);
            try testArgs(i128, f32, 1e14);
            try testArgs(i128, f32, 1e18);
            try testArgs(i128, f32, 1e22);
            try testArgs(i128, f32, 1e26);
            try testArgs(i128, f32, 1e30);
            try testArgs(i128, f32, 1e34);
            try testArgs(i128, f32, 1e38);
            try testArgs(i128, f32, next(f32, next(f32, 0x0.8p128, 0.0), 0.0));
            try testArgs(i128, f32, next(f32, 0x0.8p128, 0.0));

            try testArgs(u128, f32, -0.0);
            try testArgs(u128, f32, 0.0);
            try testArgs(u128, f32, 1e-1);
            try testArgs(u128, f32, 1e0);
            try testArgs(u128, f32, 1e2);
            try testArgs(u128, f32, 1e6);
            try testArgs(u128, f32, 1e10);
            try testArgs(u128, f32, 1e14);
            try testArgs(u128, f32, 1e18);
            try testArgs(u128, f32, 1e22);
            try testArgs(u128, f32, 1e26);
            try testArgs(u128, f32, 1e30);
            try testArgs(u128, f32, 1e34);
            try testArgs(u128, f32, 1e38);
            try testArgs(u128, f32, next(f32, next(f32, fmax(f32), 0.0), 0.0));
            try testArgs(u128, f32, next(f32, fmax(f32), 0.0));

            try testArgs(i256, f32, -fmax(f32));
            try testArgs(i256, f32, next(f32, -fmax(f32), -0.0));
            try testArgs(i256, f32, next(f32, next(f32, -fmax(f32), -0.0), -0.0));
            try testArgs(i256, f32, -1e38);
            try testArgs(i256, f32, -1e34);
            try testArgs(i256, f32, -1e30);
            try testArgs(i256, f32, -1e26);
            try testArgs(i256, f32, -1e22);
            try testArgs(i256, f32, -1e18);
            try testArgs(i256, f32, -1e14);
            try testArgs(i256, f32, -1e10);
            try testArgs(i256, f32, -1e6);
            try testArgs(i256, f32, -1e2);
            try testArgs(i256, f32, -1e0);
            try testArgs(i256, f32, -1e-1);
            try testArgs(i256, f32, -0.0);
            try testArgs(i256, f32, 0.0);
            try testArgs(i256, f32, 1e-1);
            try testArgs(i256, f32, 1e0);
            try testArgs(i256, f32, 1e2);
            try testArgs(i256, f32, 1e6);
            try testArgs(i256, f32, 1e10);
            try testArgs(i256, f32, 1e14);
            try testArgs(i256, f32, 1e18);
            try testArgs(i256, f32, 1e22);
            try testArgs(i256, f32, 1e26);
            try testArgs(i256, f32, 1e30);
            try testArgs(i256, f32, 1e34);
            try testArgs(i256, f32, 1e38);
            try testArgs(i256, f32, next(f32, next(f32, fmax(f32), 0.0), 0.0));
            try testArgs(i256, f32, next(f32, fmax(f32), 0.0));

            try testArgs(u256, f32, -0.0);
            try testArgs(u256, f32, 0.0);
            try testArgs(u256, f32, 1e-1);
            try testArgs(u256, f32, 1e0);
            try testArgs(u256, f32, 1e2);
            try testArgs(u256, f32, 1e6);
            try testArgs(u256, f32, 1e10);
            try testArgs(u256, f32, 1e14);
            try testArgs(u256, f32, 1e18);
            try testArgs(u256, f32, 1e22);
            try testArgs(u256, f32, 1e26);
            try testArgs(u256, f32, 1e30);
            try testArgs(u256, f32, 1e34);
            try testArgs(u256, f32, 1e38);
            try testArgs(u256, f32, next(f32, next(f32, fmax(f32), 0.0), 0.0));
            try testArgs(u256, f32, next(f32, fmax(f32), 0.0));

            try testArgs(i8, f64, -0x0.8p8);
            try testArgs(i8, f64, next(f64, -0x0.8p8, -0.0));
            try testArgs(i8, f64, next(f64, next(f64, -0x0.8p8, -0.0), -0.0));
            try testArgs(i8, f64, -1e2);
            try testArgs(i8, f64, -1e1);
            try testArgs(i8, f64, -1e0);
            try testArgs(i8, f64, -1e-1);
            try testArgs(i8, f64, -0.0);
            try testArgs(i8, f64, 0.0);
            try testArgs(i8, f64, 1e-1);
            try testArgs(i8, f64, 1e0);
            try testArgs(i8, f64, 1e1);
            try testArgs(i8, f64, 1e2);
            try testArgs(i8, f64, next(f64, next(f64, 0x0.8p8, 0.0), 0.0));
            try testArgs(i8, f64, next(f64, 0x0.8p8, 0.0));

            try testArgs(u8, f64, -0.0);
            try testArgs(u8, f64, 0.0);
            try testArgs(u8, f64, 1e-1);
            try testArgs(u8, f64, 1e0);
            try testArgs(u8, f64, 1e1);
            try testArgs(u8, f64, 1e2);
            try testArgs(u8, f64, next(f64, next(f64, 0x1p8, 0.0), 0.0));
            try testArgs(u8, f64, next(f64, 0x1p8, 0.0));

            try testArgs(i16, f64, -0x0.8p16);
            try testArgs(i16, f64, next(f64, -0x0.8p16, -0.0));
            try testArgs(i16, f64, next(f64, next(f64, -0x0.8p16, -0.0), -0.0));
            try testArgs(i16, f64, -1e4);
            try testArgs(i16, f64, -1e3);
            try testArgs(i16, f64, -1e2);
            try testArgs(i16, f64, -1e1);
            try testArgs(i16, f64, -1e0);
            try testArgs(i16, f64, -1e-1);
            try testArgs(i16, f64, -0.0);
            try testArgs(i16, f64, 0.0);
            try testArgs(i16, f64, 1e-1);
            try testArgs(i16, f64, 1e0);
            try testArgs(i16, f64, 1e1);
            try testArgs(i16, f64, 1e2);
            try testArgs(i16, f64, 1e3);
            try testArgs(i16, f64, 1e4);
            try testArgs(i16, f64, next(f64, next(f64, 0x0.8p16, 0.0), 0.0));
            try testArgs(i16, f64, next(f64, 0x0.8p16, 0.0));

            try testArgs(u16, f64, -0.0);
            try testArgs(u16, f64, 0.0);
            try testArgs(u16, f64, 1e-1);
            try testArgs(u16, f64, 1e0);
            try testArgs(u16, f64, 1e1);
            try testArgs(u16, f64, 1e2);
            try testArgs(u16, f64, 1e3);
            try testArgs(u16, f64, 1e4);
            try testArgs(u16, f64, next(f64, next(f64, 0x1p16, 0.0), 0.0));
            try testArgs(u16, f64, next(f64, 0x1p16, 0.0));

            try testArgs(i32, f64, -0x0.8p32);
            try testArgs(i32, f64, next(f64, -0x0.8p32, -0.0));
            try testArgs(i32, f64, next(f64, next(f64, -0x0.8p32, -0.0), -0.0));
            try testArgs(i32, f64, -1e9);
            try testArgs(i32, f64, -1e8);
            try testArgs(i32, f64, -1e7);
            try testArgs(i32, f64, -1e6);
            try testArgs(i32, f64, -1e5);
            try testArgs(i32, f64, -1e4);
            try testArgs(i32, f64, -1e3);
            try testArgs(i32, f64, -1e2);
            try testArgs(i32, f64, -1e1);
            try testArgs(i32, f64, -1e0);
            try testArgs(i32, f64, -1e-1);
            try testArgs(i32, f64, -0.0);
            try testArgs(i32, f64, 0.0);
            try testArgs(i32, f64, 1e-1);
            try testArgs(i32, f64, 1e0);
            try testArgs(i32, f64, 1e1);
            try testArgs(i32, f64, 1e2);
            try testArgs(i32, f64, 1e3);
            try testArgs(i32, f64, 1e4);
            try testArgs(i32, f64, 1e5);
            try testArgs(i32, f64, 1e6);
            try testArgs(i32, f64, 1e7);
            try testArgs(i32, f64, 1e8);
            try testArgs(i32, f64, 1e9);
            try testArgs(i32, f64, next(f64, next(f64, 0x0.8p32, 0.0), 0.0));
            try testArgs(i32, f64, next(f64, 0x0.8p32, 0.0));

            try testArgs(u32, f64, -0.0);
            try testArgs(u32, f64, 0.0);
            try testArgs(u32, f64, 1e-1);
            try testArgs(u32, f64, 1e0);
            try testArgs(u32, f64, 1e1);
            try testArgs(u32, f64, 1e2);
            try testArgs(u32, f64, 1e3);
            try testArgs(u32, f64, 1e4);
            try testArgs(u32, f64, 1e5);
            try testArgs(u32, f64, 1e6);
            try testArgs(u32, f64, 1e7);
            try testArgs(u32, f64, 1e8);
            try testArgs(u32, f64, 1e9);
            try testArgs(u32, f64, next(f64, next(f64, 0x1p32, 0.0), 0.0));
            try testArgs(u32, f64, next(f64, 0x1p32, 0.0));

            try testArgs(i64, f64, -0x0.8p64);
            try testArgs(i64, f64, next(f64, -0x0.8p64, -0.0));
            try testArgs(i64, f64, next(f64, next(f64, -0x0.8p64, -0.0), -0.0));
            try testArgs(i64, f64, -1e18);
            try testArgs(i64, f64, -1e16);
            try testArgs(i64, f64, -1e14);
            try testArgs(i64, f64, -1e12);
            try testArgs(i64, f64, -1e10);
            try testArgs(i64, f64, -1e8);
            try testArgs(i64, f64, -1e6);
            try testArgs(i64, f64, -1e4);
            try testArgs(i64, f64, -1e2);
            try testArgs(i64, f64, -1e0);
            try testArgs(i64, f64, -1e-1);
            try testArgs(i64, f64, -0.0);
            try testArgs(i64, f64, 0.0);
            try testArgs(i64, f64, 1e-1);
            try testArgs(i64, f64, 1e0);
            try testArgs(i64, f64, 1e2);
            try testArgs(i64, f64, 1e4);
            try testArgs(i64, f64, 1e6);
            try testArgs(i64, f64, 1e8);
            try testArgs(i64, f64, 1e10);
            try testArgs(i64, f64, 1e12);
            try testArgs(i64, f64, 1e14);
            try testArgs(i64, f64, 1e16);
            try testArgs(i64, f64, 1e18);
            try testArgs(i64, f64, next(f64, next(f64, 0x0.8p64, 0.0), 0.0));
            try testArgs(i64, f64, next(f64, 0x0.8p64, 0.0));

            try testArgs(u64, f64, -0.0);
            try testArgs(u64, f64, 0.0);
            try testArgs(u64, f64, 1e-1);
            try testArgs(u64, f64, 1e0);
            try testArgs(u64, f64, 1e2);
            try testArgs(u64, f64, 1e4);
            try testArgs(u64, f64, 1e6);
            try testArgs(u64, f64, 1e8);
            try testArgs(u64, f64, 1e10);
            try testArgs(u64, f64, 1e12);
            try testArgs(u64, f64, 1e14);
            try testArgs(u64, f64, 1e16);
            try testArgs(u64, f64, 1e18);
            try testArgs(u64, f64, next(f64, next(f64, 0x1p64, 0.0), 0.0));
            try testArgs(u64, f64, next(f64, 0x1p64, 0.0));

            try testArgs(i128, f64, -0x0.8p128);
            try testArgs(i128, f64, next(f64, -0x0.8p128, -0.0));
            try testArgs(i128, f64, next(f64, next(f64, -0x0.8p128, -0.0), -0.0));
            try testArgs(i128, f64, -1e38);
            try testArgs(i128, f64, -1e34);
            try testArgs(i128, f64, -1e30);
            try testArgs(i128, f64, -1e26);
            try testArgs(i128, f64, -1e22);
            try testArgs(i128, f64, -1e18);
            try testArgs(i128, f64, -1e14);
            try testArgs(i128, f64, -1e10);
            try testArgs(i128, f64, -1e6);
            try testArgs(i128, f64, -1e2);
            try testArgs(i128, f64, -1e0);
            try testArgs(i128, f64, -1e-1);
            try testArgs(i128, f64, -0.0);
            try testArgs(i128, f64, 0.0);
            try testArgs(i128, f64, 1e-1);
            try testArgs(i128, f64, 1e0);
            try testArgs(i128, f64, 1e2);
            try testArgs(i128, f64, 1e6);
            try testArgs(i128, f64, 1e10);
            try testArgs(i128, f64, 1e14);
            try testArgs(i128, f64, 1e18);
            try testArgs(i128, f64, 1e22);
            try testArgs(i128, f64, 1e26);
            try testArgs(i128, f64, 1e30);
            try testArgs(i128, f64, 1e34);
            try testArgs(i128, f64, 1e38);
            try testArgs(i128, f64, next(f64, next(f64, 0x0.8p128, 0.0), 0.0));
            try testArgs(i128, f64, next(f64, 0x0.8p128, 0.0));

            try testArgs(u128, f64, -0.0);
            try testArgs(u128, f64, 0.0);
            try testArgs(u128, f64, 1e-1);
            try testArgs(u128, f64, 1e0);
            try testArgs(u128, f64, 1e2);
            try testArgs(u128, f64, 1e6);
            try testArgs(u128, f64, 1e10);
            try testArgs(u128, f64, 1e14);
            try testArgs(u128, f64, 1e18);
            try testArgs(u128, f64, 1e22);
            try testArgs(u128, f64, 1e26);
            try testArgs(u128, f64, 1e30);
            try testArgs(u128, f64, 1e34);
            try testArgs(u128, f64, 1e38);
            try testArgs(u128, f64, next(f64, next(f64, 0x1p128, 0.0), 0.0));
            try testArgs(u128, f64, next(f64, 0x1p128, 0.0));

            try testArgs(i256, f64, -0x0.8p256);
            try testArgs(i256, f64, next(f64, -0x0.8p256, -0.0));
            try testArgs(i256, f64, next(f64, next(f64, -0x0.8p256, -0.0), -0.0));
            try testArgs(i256, f64, -1e76);
            try testArgs(i256, f64, -1e69);
            try testArgs(i256, f64, -1e62);
            try testArgs(i256, f64, -1e55);
            try testArgs(i256, f64, -1e48);
            try testArgs(i256, f64, -1e41);
            try testArgs(i256, f64, -1e34);
            try testArgs(i256, f64, -1e27);
            try testArgs(i256, f64, -1e20);
            try testArgs(i256, f64, -1e13);
            try testArgs(i256, f64, -1e6);
            try testArgs(i256, f64, -1e0);
            try testArgs(i256, f64, -1e-1);
            try testArgs(i256, f64, -0.0);
            try testArgs(i256, f64, 0.0);
            try testArgs(i256, f64, 1e-1);
            try testArgs(i256, f64, 1e0);
            try testArgs(i256, f64, 1e6);
            try testArgs(i256, f64, 1e13);
            try testArgs(i256, f64, 1e20);
            try testArgs(i256, f64, 1e27);
            try testArgs(i256, f64, 1e34);
            try testArgs(i256, f64, 1e41);
            try testArgs(i256, f64, 1e48);
            try testArgs(i256, f64, 1e55);
            try testArgs(i256, f64, 1e62);
            try testArgs(i256, f64, 1e69);
            try testArgs(i256, f64, 1e76);
            try testArgs(i256, f64, next(f64, next(f64, 0x0.8p256, 0.0), 0.0));
            try testArgs(i256, f64, next(f64, 0x0.8p256, 0.0));

            try testArgs(u256, f64, -0.0);
            try testArgs(u256, f64, 0.0);
            try testArgs(u256, f64, 1e-1);
            try testArgs(u256, f64, 1e0);
            try testArgs(u256, f64, 1e7);
            try testArgs(u256, f64, 1e14);
            try testArgs(u256, f64, 1e21);
            try testArgs(u256, f64, 1e28);
            try testArgs(u256, f64, 1e35);
            try testArgs(u256, f64, 1e42);
            try testArgs(u256, f64, 1e49);
            try testArgs(u256, f64, 1e56);
            try testArgs(u256, f64, 1e63);
            try testArgs(u256, f64, 1e70);
            try testArgs(u256, f64, 1e77);
            try testArgs(u256, f64, next(f64, next(f64, 0x1p256, 0.0), 0.0));
            try testArgs(u256, f64, next(f64, 0x1p256, 0.0));

            try testArgs(i8, f80, -0x0.8p8);
            try testArgs(i8, f80, next(f80, -0x0.8p8, -0.0));
            try testArgs(i8, f80, next(f80, next(f80, -0x0.8p8, -0.0), -0.0));
            try testArgs(i8, f80, -1e2);
            try testArgs(i8, f80, -1e1);
            try testArgs(i8, f80, -1e0);
            try testArgs(i8, f80, -1e-1);
            try testArgs(i8, f80, -0.0);
            try testArgs(i8, f80, 0.0);
            try testArgs(i8, f80, 1e-1);
            try testArgs(i8, f80, 1e0);
            try testArgs(i8, f80, 1e1);
            try testArgs(i8, f80, 1e2);
            try testArgs(i8, f80, next(f80, next(f80, 0x0.8p8, 0.0), 0.0));
            try testArgs(i8, f80, next(f80, 0x0.8p8, 0.0));

            try testArgs(u8, f80, -0.0);
            try testArgs(u8, f80, 0.0);
            try testArgs(u8, f80, 1e-1);
            try testArgs(u8, f80, 1e0);
            try testArgs(u8, f80, 1e1);
            try testArgs(u8, f80, 1e2);
            try testArgs(u8, f80, next(f80, next(f80, 0x1p8, 0.0), 0.0));
            try testArgs(u8, f80, next(f80, 0x1p8, 0.0));

            try testArgs(i16, f80, -0x0.8p16);
            try testArgs(i16, f80, next(f80, -0x0.8p16, -0.0));
            try testArgs(i16, f80, next(f80, next(f80, -0x0.8p16, -0.0), -0.0));
            try testArgs(i16, f80, -1e4);
            try testArgs(i16, f80, -1e3);
            try testArgs(i16, f80, -1e2);
            try testArgs(i16, f80, -1e1);
            try testArgs(i16, f80, -1e0);
            try testArgs(i16, f80, -1e-1);
            try testArgs(i16, f80, -0.0);
            try testArgs(i16, f80, 0.0);
            try testArgs(i16, f80, 1e-1);
            try testArgs(i16, f80, 1e0);
            try testArgs(i16, f80, 1e1);
            try testArgs(i16, f80, 1e2);
            try testArgs(i16, f80, 1e3);
            try testArgs(i16, f80, 1e4);
            try testArgs(i16, f80, next(f80, next(f80, 0x0.8p16, 0.0), 0.0));
            try testArgs(i16, f80, next(f80, 0x0.8p16, 0.0));

            try testArgs(u16, f80, -0.0);
            try testArgs(u16, f80, 0.0);
            try testArgs(u16, f80, 1e-1);
            try testArgs(u16, f80, 1e0);
            try testArgs(u16, f80, 1e1);
            try testArgs(u16, f80, 1e2);
            try testArgs(u16, f80, 1e3);
            try testArgs(u16, f80, 1e4);
            try testArgs(u16, f80, next(f80, next(f80, 0x1p16, 0.0), 0.0));
            try testArgs(u16, f80, next(f80, 0x1p16, 0.0));

            try testArgs(i32, f80, -0x0.8p32);
            try testArgs(i32, f80, next(f80, -0x0.8p32, -0.0));
            try testArgs(i32, f80, next(f80, next(f80, -0x0.8p32, -0.0), -0.0));
            try testArgs(i32, f80, -1e9);
            try testArgs(i32, f80, -1e8);
            try testArgs(i32, f80, -1e7);
            try testArgs(i32, f80, -1e6);
            try testArgs(i32, f80, -1e5);
            try testArgs(i32, f80, -1e4);
            try testArgs(i32, f80, -1e3);
            try testArgs(i32, f80, -1e2);
            try testArgs(i32, f80, -1e1);
            try testArgs(i32, f80, -1e0);
            try testArgs(i32, f80, -1e-1);
            try testArgs(i32, f80, -0.0);
            try testArgs(i32, f80, 0.0);
            try testArgs(i32, f80, 1e-1);
            try testArgs(i32, f80, 1e0);
            try testArgs(i32, f80, 1e1);
            try testArgs(i32, f80, 1e2);
            try testArgs(i32, f80, 1e3);
            try testArgs(i32, f80, 1e4);
            try testArgs(i32, f80, 1e5);
            try testArgs(i32, f80, 1e6);
            try testArgs(i32, f80, 1e7);
            try testArgs(i32, f80, 1e8);
            try testArgs(i32, f80, 1e9);
            try testArgs(i32, f80, next(f80, next(f80, 0x0.8p32, 0.0), 0.0));
            try testArgs(i32, f80, next(f80, 0x0.8p32, 0.0));

            try testArgs(u32, f80, -0.0);
            try testArgs(u32, f80, 0.0);
            try testArgs(u32, f80, 1e-1);
            try testArgs(u32, f80, 1e0);
            try testArgs(u32, f80, 1e1);
            try testArgs(u32, f80, 1e2);
            try testArgs(u32, f80, 1e3);
            try testArgs(u32, f80, 1e4);
            try testArgs(u32, f80, 1e5);
            try testArgs(u32, f80, 1e6);
            try testArgs(u32, f80, 1e7);
            try testArgs(u32, f80, 1e8);
            try testArgs(u32, f80, 1e9);
            try testArgs(u32, f80, next(f80, next(f80, 0x1p32, 0.0), 0.0));
            try testArgs(u32, f80, next(f80, 0x1p32, 0.0));

            try testArgs(i64, f80, -0x0.8p64);
            try testArgs(i64, f80, next(f80, -0x0.8p64, -0.0));
            try testArgs(i64, f80, next(f80, next(f80, -0x0.8p64, -0.0), -0.0));
            try testArgs(i64, f80, -1e18);
            try testArgs(i64, f80, -1e16);
            try testArgs(i64, f80, -1e14);
            try testArgs(i64, f80, -1e12);
            try testArgs(i64, f80, -1e10);
            try testArgs(i64, f80, -1e8);
            try testArgs(i64, f80, -1e6);
            try testArgs(i64, f80, -1e4);
            try testArgs(i64, f80, -1e2);
            try testArgs(i64, f80, -1e0);
            try testArgs(i64, f80, -1e-1);
            try testArgs(i64, f80, -0.0);
            try testArgs(i64, f80, 0.0);
            try testArgs(i64, f80, 1e-1);
            try testArgs(i64, f80, 1e0);
            try testArgs(i64, f80, 1e2);
            try testArgs(i64, f80, 1e4);
            try testArgs(i64, f80, 1e6);
            try testArgs(i64, f80, 1e8);
            try testArgs(i64, f80, 1e10);
            try testArgs(i64, f80, 1e12);
            try testArgs(i64, f80, 1e14);
            try testArgs(i64, f80, 1e16);
            try testArgs(i64, f80, 1e18);
            try testArgs(i64, f80, next(f80, next(f80, 0x0.8p64, 0.0), 0.0));
            try testArgs(i64, f80, next(f80, 0x0.8p64, 0.0));

            try testArgs(u64, f80, -0.0);
            try testArgs(u64, f80, 0.0);
            try testArgs(u64, f80, 1e-1);
            try testArgs(u64, f80, 1e0);
            try testArgs(u64, f80, 1e2);
            try testArgs(u64, f80, 1e4);
            try testArgs(u64, f80, 1e6);
            try testArgs(u64, f80, 1e8);
            try testArgs(u64, f80, 1e10);
            try testArgs(u64, f80, 1e12);
            try testArgs(u64, f80, 1e14);
            try testArgs(u64, f80, 1e16);
            try testArgs(u64, f80, 1e18);
            try testArgs(u64, f80, next(f80, next(f80, 0x1p64, 0.0), 0.0));
            try testArgs(u64, f80, next(f80, 0x1p64, 0.0));

            try testArgs(i128, f80, -0x0.8p128);
            try testArgs(i128, f80, next(f80, -0x0.8p128, -0.0));
            try testArgs(i128, f80, next(f80, next(f80, -0x0.8p128, -0.0), -0.0));
            try testArgs(i128, f80, -1e38);
            try testArgs(i128, f80, -1e34);
            try testArgs(i128, f80, -1e30);
            try testArgs(i128, f80, -1e26);
            try testArgs(i128, f80, -1e22);
            try testArgs(i128, f80, -1e18);
            try testArgs(i128, f80, -1e14);
            try testArgs(i128, f80, -1e10);
            try testArgs(i128, f80, -1e6);
            try testArgs(i128, f80, -1e2);
            try testArgs(i128, f80, -1e0);
            try testArgs(i128, f80, -1e-1);
            try testArgs(i128, f80, -0.0);
            try testArgs(i128, f80, 0.0);
            try testArgs(i128, f80, 1e-1);
            try testArgs(i128, f80, 1e0);
            try testArgs(i128, f80, 1e2);
            try testArgs(i128, f80, 1e6);
            try testArgs(i128, f80, 1e10);
            try testArgs(i128, f80, 1e14);
            try testArgs(i128, f80, 1e18);
            try testArgs(i128, f80, 1e22);
            try testArgs(i128, f80, 1e26);
            try testArgs(i128, f80, 1e30);
            try testArgs(i128, f80, 1e34);
            try testArgs(i128, f80, 1e38);
            try testArgs(i128, f80, next(f80, next(f80, 0x0.8p128, 0.0), 0.0));
            try testArgs(i128, f80, next(f80, 0x0.8p128, 0.0));

            try testArgs(u128, f80, -0.0);
            try testArgs(u128, f80, 0.0);
            try testArgs(u128, f80, 1e-1);
            try testArgs(u128, f80, 1e0);
            try testArgs(u128, f80, 1e2);
            try testArgs(u128, f80, 1e6);
            try testArgs(u128, f80, 1e10);
            try testArgs(u128, f80, 1e14);
            try testArgs(u128, f80, 1e18);
            try testArgs(u128, f80, 1e22);
            try testArgs(u128, f80, 1e26);
            try testArgs(u128, f80, 1e30);
            try testArgs(u128, f80, 1e34);
            try testArgs(u128, f80, 1e38);
            try testArgs(u128, f80, next(f80, next(f80, 0x1p128, 0.0), 0.0));
            try testArgs(u128, f80, next(f80, 0x1p128, 0.0));

            try testArgs(i256, f80, -0x0.8p256);
            try testArgs(i256, f80, next(f80, -0x0.8p256, -0.0));
            try testArgs(i256, f80, next(f80, next(f80, -0x0.8p256, -0.0), -0.0));
            try testArgs(i256, f80, -1e76);
            try testArgs(i256, f80, -1e69);
            try testArgs(i256, f80, -1e62);
            try testArgs(i256, f80, -1e55);
            try testArgs(i256, f80, -1e48);
            try testArgs(i256, f80, -1e41);
            try testArgs(i256, f80, -1e34);
            try testArgs(i256, f80, -1e27);
            try testArgs(i256, f80, -1e20);
            try testArgs(i256, f80, -1e13);
            try testArgs(i256, f80, -1e6);
            try testArgs(i256, f80, -1e0);
            try testArgs(i256, f80, -1e-1);
            try testArgs(i256, f80, -0.0);
            try testArgs(i256, f80, 0.0);
            try testArgs(i256, f80, 1e-1);
            try testArgs(i256, f80, 1e0);
            try testArgs(i256, f80, 1e6);
            try testArgs(i256, f80, 1e13);
            try testArgs(i256, f80, 1e20);
            try testArgs(i256, f80, 1e27);
            try testArgs(i256, f80, 1e34);
            try testArgs(i256, f80, 1e41);
            try testArgs(i256, f80, 1e48);
            try testArgs(i256, f80, 1e55);
            try testArgs(i256, f80, 1e62);
            try testArgs(i256, f80, 1e69);
            try testArgs(i256, f80, 1e76);
            try testArgs(i256, f80, next(f80, next(f80, 0x0.8p256, 0.0), 0.0));
            try testArgs(i256, f80, next(f80, 0x0.8p256, 0.0));

            try testArgs(u256, f80, -0.0);
            try testArgs(u256, f80, 0.0);
            try testArgs(u256, f80, 1e-1);
            try testArgs(u256, f80, 1e0);
            try testArgs(u256, f80, 1e7);
            try testArgs(u256, f80, 1e14);
            try testArgs(u256, f80, 1e21);
            try testArgs(u256, f80, 1e28);
            try testArgs(u256, f80, 1e35);
            try testArgs(u256, f80, 1e42);
            try testArgs(u256, f80, 1e49);
            try testArgs(u256, f80, 1e56);
            try testArgs(u256, f80, 1e63);
            try testArgs(u256, f80, 1e70);
            try testArgs(u256, f80, 1e77);
            try testArgs(u256, f80, next(f80, next(f80, 0x1p256, 0.0), 0.0));
            try testArgs(u256, f80, next(f80, 0x1p256, 0.0));

            try testArgs(i8, f128, -0x0.8p8);
            try testArgs(i8, f128, next(f128, -0x0.8p8, -0.0));
            try testArgs(i8, f128, next(f128, next(f128, -0x0.8p8, -0.0), -0.0));
            try testArgs(i8, f128, -1e2);
            try testArgs(i8, f128, -1e1);
            try testArgs(i8, f128, -1e0);
            try testArgs(i8, f128, -1e-1);
            try testArgs(i8, f128, -0.0);
            try testArgs(i8, f128, 0.0);
            try testArgs(i8, f128, 1e-1);
            try testArgs(i8, f128, 1e0);
            try testArgs(i8, f128, 1e1);
            try testArgs(i8, f128, 1e2);
            try testArgs(i8, f128, next(f128, next(f128, 0x0.8p8, 0.0), 0.0));
            try testArgs(i8, f128, next(f128, 0x0.8p8, 0.0));

            try testArgs(u8, f128, -0.0);
            try testArgs(u8, f128, 0.0);
            try testArgs(u8, f128, 1e-1);
            try testArgs(u8, f128, 1e0);
            try testArgs(u8, f128, 1e1);
            try testArgs(u8, f128, 1e2);
            try testArgs(u8, f128, next(f128, next(f128, 0x1p8, 0.0), 0.0));
            try testArgs(u8, f128, next(f128, 0x1p8, 0.0));

            try testArgs(i16, f128, -0x0.8p16);
            try testArgs(i16, f128, next(f128, -0x0.8p16, -0.0));
            try testArgs(i16, f128, next(f128, next(f128, -0x0.8p16, -0.0), -0.0));
            try testArgs(i16, f128, -1e4);
            try testArgs(i16, f128, -1e3);
            try testArgs(i16, f128, -1e2);
            try testArgs(i16, f128, -1e1);
            try testArgs(i16, f128, -1e0);
            try testArgs(i16, f128, -1e-1);
            try testArgs(i16, f128, -0.0);
            try testArgs(i16, f128, 0.0);
            try testArgs(i16, f128, 1e-1);
            try testArgs(i16, f128, 1e0);
            try testArgs(i16, f128, 1e1);
            try testArgs(i16, f128, 1e2);
            try testArgs(i16, f128, 1e3);
            try testArgs(i16, f128, 1e4);
            try testArgs(i16, f128, next(f128, next(f128, 0x0.8p16, 0.0), 0.0));
            try testArgs(i16, f128, next(f128, 0x0.8p16, 0.0));

            try testArgs(u16, f128, -0.0);
            try testArgs(u16, f128, 0.0);
            try testArgs(u16, f128, 1e-1);
            try testArgs(u16, f128, 1e0);
            try testArgs(u16, f128, 1e1);
            try testArgs(u16, f128, 1e2);
            try testArgs(u16, f128, 1e3);
            try testArgs(u16, f128, 1e4);
            try testArgs(u16, f128, next(f128, next(f128, 0x1p16, 0.0), 0.0));
            try testArgs(u16, f128, next(f128, 0x1p16, 0.0));

            try testArgs(i32, f128, -0x0.8p32);
            try testArgs(i32, f128, next(f128, -0x0.8p32, -0.0));
            try testArgs(i32, f128, next(f128, next(f128, -0x0.8p32, -0.0), -0.0));
            try testArgs(i32, f128, -1e9);
            try testArgs(i32, f128, -1e8);
            try testArgs(i32, f128, -1e7);
            try testArgs(i32, f128, -1e6);
            try testArgs(i32, f128, -1e5);
            try testArgs(i32, f128, -1e4);
            try testArgs(i32, f128, -1e3);
            try testArgs(i32, f128, -1e2);
            try testArgs(i32, f128, -1e1);
            try testArgs(i32, f128, -1e0);
            try testArgs(i32, f128, -1e-1);
            try testArgs(i32, f128, -0.0);
            try testArgs(i32, f128, 0.0);
            try testArgs(i32, f128, 1e-1);
            try testArgs(i32, f128, 1e0);
            try testArgs(i32, f128, 1e1);
            try testArgs(i32, f128, 1e2);
            try testArgs(i32, f128, 1e3);
            try testArgs(i32, f128, 1e4);
            try testArgs(i32, f128, 1e5);
            try testArgs(i32, f128, 1e6);
            try testArgs(i32, f128, 1e7);
            try testArgs(i32, f128, 1e8);
            try testArgs(i32, f128, 1e9);
            try testArgs(i32, f128, next(f128, next(f128, 0x0.8p32, 0.0), 0.0));
            try testArgs(i32, f128, next(f128, 0x0.8p32, 0.0));

            try testArgs(u32, f128, -0.0);
            try testArgs(u32, f128, 0.0);
            try testArgs(u32, f128, 1e-1);
            try testArgs(u32, f128, 1e0);
            try testArgs(u32, f128, 1e1);
            try testArgs(u32, f128, 1e2);
            try testArgs(u32, f128, 1e3);
            try testArgs(u32, f128, 1e4);
            try testArgs(u32, f128, 1e5);
            try testArgs(u32, f128, 1e6);
            try testArgs(u32, f128, 1e7);
            try testArgs(u32, f128, 1e8);
            try testArgs(u32, f128, 1e9);
            try testArgs(u32, f128, next(f128, next(f128, 0x1p32, 0.0), 0.0));
            try testArgs(u32, f128, next(f128, 0x1p32, 0.0));

            try testArgs(i64, f128, -0x0.8p64);
            try testArgs(i64, f128, next(f128, -0x0.8p64, -0.0));
            try testArgs(i64, f128, next(f128, next(f128, -0x0.8p64, -0.0), -0.0));
            try testArgs(i64, f128, -1e18);
            try testArgs(i64, f128, -1e16);
            try testArgs(i64, f128, -1e14);
            try testArgs(i64, f128, -1e12);
            try testArgs(i64, f128, -1e10);
            try testArgs(i64, f128, -1e8);
            try testArgs(i64, f128, -1e6);
            try testArgs(i64, f128, -1e4);
            try testArgs(i64, f128, -1e2);
            try testArgs(i64, f128, -1e0);
            try testArgs(i64, f128, -1e-1);
            try testArgs(i64, f128, -0.0);
            try testArgs(i64, f128, 0.0);
            try testArgs(i64, f128, 1e-1);
            try testArgs(i64, f128, 1e0);
            try testArgs(i64, f128, 1e2);
            try testArgs(i64, f128, 1e4);
            try testArgs(i64, f128, 1e6);
            try testArgs(i64, f128, 1e8);
            try testArgs(i64, f128, 1e10);
            try testArgs(i64, f128, 1e11);
            try testArgs(i64, f128, 1e12);
            try testArgs(i64, f128, 1e13);
            try testArgs(i64, f128, 1e14);
            try testArgs(i64, f128, 1e15);
            try testArgs(i64, f128, 1e16);
            try testArgs(i64, f128, 1e17);
            try testArgs(i64, f128, 1e18);
            try testArgs(i64, f128, next(f128, next(f128, 0x0.8p64, 0.0), 0.0));
            try testArgs(i64, f128, next(f128, 0x0.8p64, 0.0));

            try testArgs(u64, f128, -0.0);
            try testArgs(u64, f128, 0.0);
            try testArgs(u64, f128, 1e-1);
            try testArgs(u64, f128, 1e0);
            try testArgs(u64, f128, 1e2);
            try testArgs(u64, f128, 1e4);
            try testArgs(u64, f128, 1e6);
            try testArgs(u64, f128, 1e8);
            try testArgs(u64, f128, 1e10);
            try testArgs(u64, f128, 1e12);
            try testArgs(u64, f128, 1e14);
            try testArgs(u64, f128, 1e16);
            try testArgs(u64, f128, 1e18);
            try testArgs(u64, f128, next(f128, next(f128, 0x1p64, 0.0), 0.0));
            try testArgs(u64, f128, next(f128, 0x1p64, 0.0));

            try testArgs(i128, f128, -0x0.8p128);
            try testArgs(i128, f128, next(f128, -0x0.8p128, -0.0));
            try testArgs(i128, f128, next(f128, next(f128, -0x0.8p128, -0.0), -0.0));
            try testArgs(i128, f128, -1e38);
            try testArgs(i128, f128, -1e34);
            try testArgs(i128, f128, -1e30);
            try testArgs(i128, f128, -1e26);
            try testArgs(i128, f128, -1e22);
            try testArgs(i128, f128, -1e18);
            try testArgs(i128, f128, -1e14);
            try testArgs(i128, f128, -1e10);
            try testArgs(i128, f128, -1e6);
            try testArgs(i128, f128, -1e2);
            try testArgs(i128, f128, -1e0);
            try testArgs(i128, f128, -1e-1);
            try testArgs(i128, f128, -0.0);
            try testArgs(i128, f128, 0.0);
            try testArgs(i128, f128, 1e-1);
            try testArgs(i128, f128, 1e0);
            try testArgs(i128, f128, 1e2);
            try testArgs(i128, f128, 1e6);
            try testArgs(i128, f128, 1e10);
            try testArgs(i128, f128, 1e14);
            try testArgs(i128, f128, 1e18);
            try testArgs(i128, f128, 1e22);
            try testArgs(i128, f128, 1e26);
            try testArgs(i128, f128, 1e30);
            try testArgs(i128, f128, 1e34);
            try testArgs(i128, f128, 1e38);
            try testArgs(i128, f128, next(f128, next(f128, 0x0.8p128, 0.0), 0.0));
            try testArgs(i128, f128, next(f128, 0x0.8p128, 0.0));

            try testArgs(u128, f128, -0.0);
            try testArgs(u128, f128, 0.0);
            try testArgs(u128, f128, 1e-1);
            try testArgs(u128, f128, 1e0);
            try testArgs(u128, f128, 1e2);
            try testArgs(u128, f128, 1e6);
            try testArgs(u128, f128, 1e10);
            try testArgs(u128, f128, 1e14);
            try testArgs(u128, f128, 1e18);
            try testArgs(u128, f128, 1e22);
            try testArgs(u128, f128, 1e26);
            try testArgs(u128, f128, 1e30);
            try testArgs(u128, f128, 1e34);
            try testArgs(u128, f128, 1e38);
            try testArgs(u128, f128, next(f128, next(f128, 0x1p128, 0.0), 0.0));
            try testArgs(u128, f128, next(f128, 0x1p128, 0.0));

            try testArgs(i256, f128, -0x0.8p256);
            try testArgs(i256, f128, next(f128, -0x0.8p256, -0.0));
            try testArgs(i256, f128, next(f128, next(f128, -0x0.8p256, -0.0), -0.0));
            try testArgs(i256, f128, -1e76);
            try testArgs(i256, f128, -1e69);
            try testArgs(i256, f128, -1e62);
            try testArgs(i256, f128, -1e55);
            try testArgs(i256, f128, -1e48);
            try testArgs(i256, f128, -1e41);
            try testArgs(i256, f128, -1e34);
            try testArgs(i256, f128, -1e27);
            try testArgs(i256, f128, -1e20);
            try testArgs(i256, f128, -1e13);
            try testArgs(i256, f128, -1e6);
            try testArgs(i256, f128, -1e0);
            try testArgs(i256, f128, -1e-1);
            try testArgs(i256, f128, -0.0);
            try testArgs(i256, f128, 0.0);
            try testArgs(i256, f128, 1e-1);
            try testArgs(i256, f128, 1e0);
            try testArgs(i256, f128, 1e6);
            try testArgs(i256, f128, 1e13);
            try testArgs(i256, f128, 1e20);
            try testArgs(i256, f128, 1e27);
            try testArgs(i256, f128, 1e34);
            try testArgs(i256, f128, 1e41);
            try testArgs(i256, f128, 1e48);
            try testArgs(i256, f128, 1e55);
            try testArgs(i256, f128, 1e62);
            try testArgs(i256, f128, 1e69);
            try testArgs(i256, f128, 1e76);
            try testArgs(i256, f128, next(f128, next(f128, 0x0.8p256, 0.0), 0.0));
            try testArgs(i256, f128, next(f128, 0x0.8p256, 0.0));

            try testArgs(u256, f128, -0.0);
            try testArgs(u256, f128, 0.0);
            try testArgs(u256, f128, 1e-1);
            try testArgs(u256, f128, 1e0);
            try testArgs(u256, f128, 1e7);
            try testArgs(u256, f128, 1e14);
            try testArgs(u256, f128, 1e21);
            try testArgs(u256, f128, 1e28);
            try testArgs(u256, f128, 1e35);
            try testArgs(u256, f128, 1e42);
            try testArgs(u256, f128, 1e49);
            try testArgs(u256, f128, 1e56);
            try testArgs(u256, f128, 1e63);
            try testArgs(u256, f128, 1e70);
            try testArgs(u256, f128, 1e77);
            try testArgs(u256, f128, next(f128, next(f128, 0x1p256, 0.0), 0.0));
            try testArgs(u256, f128, next(f128, 0x1p256, 0.0));
        }
        fn testFloatsFromInts() !void {
            try testArgs(f16, i8, imin(i8));
            try testArgs(f16, i8, imin(i8) + 1);
            try testArgs(f16, i8, -1e2);
            try testArgs(f16, i8, -1e1);
            try testArgs(f16, i8, -1e0);
            try testArgs(f16, i8, 0);
            try testArgs(f16, i8, 1e0);
            try testArgs(f16, i8, 1e1);
            try testArgs(f16, i8, 1e2);
            try testArgs(f16, i8, imax(i8) - 1);
            try testArgs(f16, i8, imax(i8));

            try testArgs(f16, u8, 0);
            try testArgs(f16, u8, 1e0);
            try testArgs(f16, u8, 1e1);
            try testArgs(f16, u8, 1e2);
            try testArgs(f16, u8, imax(u8) - 1);
            try testArgs(f16, u8, imax(u8));

            try testArgs(f16, i16, imin(i16));
            try testArgs(f16, i16, imin(i16) + 1);
            try testArgs(f16, i16, -1e4);
            try testArgs(f16, i16, -1e3);
            try testArgs(f16, i16, -1e2);
            try testArgs(f16, i16, -1e1);
            try testArgs(f16, i16, -1e0);
            try testArgs(f16, i16, 0);
            try testArgs(f16, i16, 1e0);
            try testArgs(f16, i16, 1e1);
            try testArgs(f16, i16, 1e2);
            try testArgs(f16, i16, 1e3);
            try testArgs(f16, i16, 1e4);
            try testArgs(f16, i16, imax(i16) - 1);
            try testArgs(f16, i16, imax(i16));

            try testArgs(f16, u16, 0);
            try testArgs(f16, u16, 1e0);
            try testArgs(f16, u16, 1e1);
            try testArgs(f16, u16, 1e2);
            try testArgs(f16, u16, 1e3);
            try testArgs(f16, u16, 1e4);
            try testArgs(f16, u16, imax(u16) - 1);
            try testArgs(f16, u16, imax(u16));

            try testArgs(f16, i32, imin(i32));
            try testArgs(f16, i32, imin(i32) + 1);
            try testArgs(f16, i32, -1e9);
            try testArgs(f16, i32, -1e8);
            try testArgs(f16, i32, -1e7);
            try testArgs(f16, i32, -1e6);
            try testArgs(f16, i32, -1e5);
            try testArgs(f16, i32, -1e4);
            try testArgs(f16, i32, -1e3);
            try testArgs(f16, i32, -1e2);
            try testArgs(f16, i32, -1e1);
            try testArgs(f16, i32, -1e0);
            try testArgs(f16, i32, 0);
            try testArgs(f16, i32, 1e0);
            try testArgs(f16, i32, 1e1);
            try testArgs(f16, i32, 1e2);
            try testArgs(f16, i32, 1e3);
            try testArgs(f16, i32, 1e4);
            try testArgs(f16, i32, 1e5);
            try testArgs(f16, i32, 1e6);
            try testArgs(f16, i32, 1e7);
            try testArgs(f16, i32, 1e8);
            try testArgs(f16, i32, 1e9);
            try testArgs(f16, i32, imax(i32) - 1);
            try testArgs(f16, i32, imax(i32));

            try testArgs(f16, u32, 0);
            try testArgs(f16, u32, 1e0);
            try testArgs(f16, u32, 1e1);
            try testArgs(f16, u32, 1e2);
            try testArgs(f16, u32, 1e3);
            try testArgs(f16, u32, 1e4);
            try testArgs(f16, u32, 1e5);
            try testArgs(f16, u32, 1e6);
            try testArgs(f16, u32, 1e7);
            try testArgs(f16, u32, 1e8);
            try testArgs(f16, u32, 1e9);
            try testArgs(f16, u32, imax(u32) - 1);
            try testArgs(f16, u32, imax(u32));

            try testArgs(f16, i64, imin(i64));
            try testArgs(f16, i64, imin(i64) + 1);
            try testArgs(f16, i64, -1e18);
            try testArgs(f16, i64, -1e16);
            try testArgs(f16, i64, -1e14);
            try testArgs(f16, i64, -1e12);
            try testArgs(f16, i64, -1e10);
            try testArgs(f16, i64, -1e8);
            try testArgs(f16, i64, -1e6);
            try testArgs(f16, i64, -1e4);
            try testArgs(f16, i64, -1e2);
            try testArgs(f16, i64, -1e0);
            try testArgs(f16, i64, 0);
            try testArgs(f16, i64, 1e0);
            try testArgs(f16, i64, 1e2);
            try testArgs(f16, i64, 1e4);
            try testArgs(f16, i64, 1e6);
            try testArgs(f16, i64, 1e8);
            try testArgs(f16, i64, 1e10);
            try testArgs(f16, i64, 1e12);
            try testArgs(f16, i64, 1e14);
            try testArgs(f16, i64, 1e16);
            try testArgs(f16, i64, 1e18);
            try testArgs(f16, i64, imax(i64) - 1);
            try testArgs(f16, i64, imax(i64));

            try testArgs(f16, u64, 0);
            try testArgs(f16, u64, 1e0);
            try testArgs(f16, u64, 1e2);
            try testArgs(f16, u64, 1e4);
            try testArgs(f16, u64, 1e6);
            try testArgs(f16, u64, 1e8);
            try testArgs(f16, u64, 1e10);
            try testArgs(f16, u64, 1e12);
            try testArgs(f16, u64, 1e14);
            try testArgs(f16, u64, 1e16);
            try testArgs(f16, u64, 1e18);
            try testArgs(f16, u64, imax(u64) - 1);
            try testArgs(f16, u64, imax(u64));

            try testArgs(f16, i128, imin(i128));
            try testArgs(f16, i128, imin(i128) + 1);
            try testArgs(f16, i128, -1e38);
            try testArgs(f16, i128, -1e34);
            try testArgs(f16, i128, -1e30);
            try testArgs(f16, i128, -1e26);
            try testArgs(f16, i128, -1e22);
            try testArgs(f16, i128, -1e18);
            try testArgs(f16, i128, -1e14);
            try testArgs(f16, i128, -1e10);
            try testArgs(f16, i128, -1e6);
            try testArgs(f16, i128, -1e2);
            try testArgs(f16, i128, -1e0);
            try testArgs(f16, i128, 0);
            try testArgs(f16, i128, 1e0);
            try testArgs(f16, i128, 1e2);
            try testArgs(f16, i128, 1e6);
            try testArgs(f16, i128, 1e10);
            try testArgs(f16, i128, 1e14);
            try testArgs(f16, i128, 1e18);
            try testArgs(f16, i128, 1e22);
            try testArgs(f16, i128, 1e26);
            try testArgs(f16, i128, 1e30);
            try testArgs(f16, i128, 1e34);
            try testArgs(f16, i128, 1e38);
            try testArgs(f16, i128, imax(i128) - 1);
            try testArgs(f16, i128, imax(i128));

            try testArgs(f16, u128, 0);
            try testArgs(f16, u128, 1e0);
            try testArgs(f16, u128, 1e2);
            try testArgs(f16, u128, 1e6);
            try testArgs(f16, u128, 1e10);
            try testArgs(f16, u128, 1e14);
            try testArgs(f16, u128, 1e18);
            try testArgs(f16, u128, 1e22);
            try testArgs(f16, u128, 1e26);
            try testArgs(f16, u128, 1e30);
            try testArgs(f16, u128, 1e34);
            try testArgs(f16, u128, 1e38);
            try testArgs(f16, u128, imax(u128) - 1);
            try testArgs(f16, u128, imax(u128));

            try testArgs(f16, i256, imin(i256));
            try testArgs(f16, i256, imin(i256) + 1);
            try testArgs(f16, i256, -1e76);
            try testArgs(f16, i256, -1e69);
            try testArgs(f16, i256, -1e62);
            try testArgs(f16, i256, -1e55);
            try testArgs(f16, i256, -1e48);
            try testArgs(f16, i256, -1e41);
            try testArgs(f16, i256, -1e34);
            try testArgs(f16, i256, -1e27);
            try testArgs(f16, i256, -1e20);
            try testArgs(f16, i256, -1e13);
            try testArgs(f16, i256, -1e6);
            try testArgs(f16, i256, -1e0);
            try testArgs(f16, i256, 0);
            try testArgs(f16, i256, 1e0);
            try testArgs(f16, i256, 1e6);
            try testArgs(f16, i256, 1e13);
            try testArgs(f16, i256, 1e20);
            try testArgs(f16, i256, 1e27);
            try testArgs(f16, i256, 1e34);
            try testArgs(f16, i256, 1e41);
            try testArgs(f16, i256, 1e48);
            try testArgs(f16, i256, 1e55);
            try testArgs(f16, i256, 1e62);
            try testArgs(f16, i256, 1e69);
            try testArgs(f16, i256, 1e76);
            try testArgs(f16, i256, imax(i256) - 1);
            try testArgs(f16, i256, imax(i256));

            try testArgs(f16, u256, 0);
            try testArgs(f16, u256, 1e0);
            try testArgs(f16, u256, 1e7);
            try testArgs(f16, u256, 1e14);
            try testArgs(f16, u256, 1e21);
            try testArgs(f16, u256, 1e28);
            try testArgs(f16, u256, 1e35);
            try testArgs(f16, u256, 1e42);
            try testArgs(f16, u256, 1e49);
            try testArgs(f16, u256, 1e56);
            try testArgs(f16, u256, 1e63);
            try testArgs(f16, u256, 1e70);
            try testArgs(f16, u256, 1e77);
            try testArgs(f16, u256, imax(u256) - 1);
            try testArgs(f16, u256, imax(u256));

            try testArgs(f32, i8, imin(i8));
            try testArgs(f32, i8, imin(i8) + 1);
            try testArgs(f32, i8, -1e2);
            try testArgs(f32, i8, -1e1);
            try testArgs(f32, i8, -1e0);
            try testArgs(f32, i8, 0);
            try testArgs(f32, i8, 1e0);
            try testArgs(f32, i8, 1e1);
            try testArgs(f32, i8, 1e2);
            try testArgs(f32, i8, imax(i8) - 1);
            try testArgs(f32, i8, imax(i8));

            try testArgs(f32, u8, 0);
            try testArgs(f32, u8, 1e0);
            try testArgs(f32, u8, 1e1);
            try testArgs(f32, u8, 1e2);
            try testArgs(f32, u8, imax(u8) - 1);
            try testArgs(f32, u8, imax(u8));

            try testArgs(f32, i16, imin(i16));
            try testArgs(f32, i16, imin(i16) + 1);
            try testArgs(f32, i16, -1e4);
            try testArgs(f32, i16, -1e3);
            try testArgs(f32, i16, -1e2);
            try testArgs(f32, i16, -1e1);
            try testArgs(f32, i16, -1e0);
            try testArgs(f32, i16, 0);
            try testArgs(f32, i16, 1e0);
            try testArgs(f32, i16, 1e1);
            try testArgs(f32, i16, 1e2);
            try testArgs(f32, i16, 1e3);
            try testArgs(f32, i16, 1e4);
            try testArgs(f32, i16, imax(i16) - 1);
            try testArgs(f32, i16, imax(i16));

            try testArgs(f32, u16, 0);
            try testArgs(f32, u16, 1e0);
            try testArgs(f32, u16, 1e1);
            try testArgs(f32, u16, 1e2);
            try testArgs(f32, u16, 1e3);
            try testArgs(f32, u16, 1e4);
            try testArgs(f32, u16, imax(u16) - 1);
            try testArgs(f32, u16, imax(u16));

            try testArgs(f32, i32, imin(i32));
            try testArgs(f32, i32, imin(i32) + 1);
            try testArgs(f32, i32, -1e9);
            try testArgs(f32, i32, -1e8);
            try testArgs(f32, i32, -1e7);
            try testArgs(f32, i32, -1e6);
            try testArgs(f32, i32, -1e5);
            try testArgs(f32, i32, -1e4);
            try testArgs(f32, i32, -1e3);
            try testArgs(f32, i32, -1e2);
            try testArgs(f32, i32, -1e1);
            try testArgs(f32, i32, -1e0);
            try testArgs(f32, i32, 0);
            try testArgs(f32, i32, 1e0);
            try testArgs(f32, i32, 1e1);
            try testArgs(f32, i32, 1e2);
            try testArgs(f32, i32, 1e3);
            try testArgs(f32, i32, 1e4);
            try testArgs(f32, i32, 1e5);
            try testArgs(f32, i32, 1e6);
            try testArgs(f32, i32, 1e7);
            try testArgs(f32, i32, 1e8);
            try testArgs(f32, i32, 1e9);
            try testArgs(f32, i32, imax(i32) - 1);
            try testArgs(f32, i32, imax(i32));

            try testArgs(f32, u32, 0);
            try testArgs(f32, u32, 1e0);
            try testArgs(f32, u32, 1e1);
            try testArgs(f32, u32, 1e2);
            try testArgs(f32, u32, 1e3);
            try testArgs(f32, u32, 1e4);
            try testArgs(f32, u32, 1e5);
            try testArgs(f32, u32, 1e6);
            try testArgs(f32, u32, 1e7);
            try testArgs(f32, u32, 1e8);
            try testArgs(f32, u32, 1e9);
            try testArgs(f32, u32, imax(u32) - 1);
            try testArgs(f32, u32, imax(u32));

            try testArgs(f32, i64, imin(i64));
            try testArgs(f32, i64, imin(i64) + 1);
            try testArgs(f32, i64, -1e18);
            try testArgs(f32, i64, -1e16);
            try testArgs(f32, i64, -1e14);
            try testArgs(f32, i64, -1e12);
            try testArgs(f32, i64, -1e10);
            try testArgs(f32, i64, -1e8);
            try testArgs(f32, i64, -1e6);
            try testArgs(f32, i64, -1e4);
            try testArgs(f32, i64, -1e2);
            try testArgs(f32, i64, -1e0);
            try testArgs(f32, i64, 0);
            try testArgs(f32, i64, 1e0);
            try testArgs(f32, i64, 1e2);
            try testArgs(f32, i64, 1e4);
            try testArgs(f32, i64, 1e6);
            try testArgs(f32, i64, 1e8);
            try testArgs(f32, i64, 1e10);
            try testArgs(f32, i64, 1e12);
            try testArgs(f32, i64, 1e14);
            try testArgs(f32, i64, 1e16);
            try testArgs(f32, i64, 1e18);
            try testArgs(f32, i64, imax(i64) - 1);
            try testArgs(f32, i64, imax(i64));

            try testArgs(f32, u64, 0);
            try testArgs(f32, u64, 1e0);
            try testArgs(f32, u64, 1e2);
            try testArgs(f32, u64, 1e4);
            try testArgs(f32, u64, 1e6);
            try testArgs(f32, u64, 1e8);
            try testArgs(f32, u64, 1e10);
            try testArgs(f32, u64, 1e12);
            try testArgs(f32, u64, 1e14);
            try testArgs(f32, u64, 1e16);
            try testArgs(f32, u64, 1e18);
            try testArgs(f32, u64, imax(u64) - 1);
            try testArgs(f32, u64, imax(u64));

            try testArgs(f32, i128, imin(i128));
            try testArgs(f32, i128, imin(i128) + 1);
            try testArgs(f32, i128, -1e38);
            try testArgs(f32, i128, -1e34);
            try testArgs(f32, i128, -1e30);
            try testArgs(f32, i128, -1e26);
            try testArgs(f32, i128, -1e22);
            try testArgs(f32, i128, -1e18);
            try testArgs(f32, i128, -1e14);
            try testArgs(f32, i128, -1e10);
            try testArgs(f32, i128, -1e6);
            try testArgs(f32, i128, -1e2);
            try testArgs(f32, i128, -1e0);
            try testArgs(f32, i128, 0);
            try testArgs(f32, i128, 1e0);
            try testArgs(f32, i128, 1e2);
            try testArgs(f32, i128, 1e6);
            try testArgs(f32, i128, 1e10);
            try testArgs(f32, i128, 1e14);
            try testArgs(f32, i128, 1e18);
            try testArgs(f32, i128, 1e22);
            try testArgs(f32, i128, 1e26);
            try testArgs(f32, i128, 1e30);
            try testArgs(f32, i128, 1e34);
            try testArgs(f32, i128, 1e38);
            try testArgs(f32, i128, imax(i128) - 1);
            try testArgs(f32, i128, imax(i128));

            try testArgs(f32, u128, 0);
            try testArgs(f32, u128, 1e0);
            try testArgs(f32, u128, 1e2);
            try testArgs(f32, u128, 1e6);
            try testArgs(f32, u128, 1e10);
            try testArgs(f32, u128, 1e14);
            try testArgs(f32, u128, 1e18);
            try testArgs(f32, u128, 1e22);
            try testArgs(f32, u128, 1e26);
            try testArgs(f32, u128, 1e30);
            try testArgs(f32, u128, 1e34);
            try testArgs(f32, u128, 1e38);
            try testArgs(f32, u128, imax(u128) - 1);
            try testArgs(f32, u128, imax(u128));

            try testArgs(f32, i256, imin(i256));
            try testArgs(f32, i256, imin(i256) + 1);
            try testArgs(f32, i256, -1e76);
            try testArgs(f32, i256, -1e69);
            try testArgs(f32, i256, -1e62);
            try testArgs(f32, i256, -1e55);
            try testArgs(f32, i256, -1e48);
            try testArgs(f32, i256, -1e41);
            try testArgs(f32, i256, -1e34);
            try testArgs(f32, i256, -1e27);
            try testArgs(f32, i256, -1e20);
            try testArgs(f32, i256, -1e13);
            try testArgs(f32, i256, -1e6);
            try testArgs(f32, i256, -1e0);
            try testArgs(f32, i256, 0);
            try testArgs(f32, i256, 1e0);
            try testArgs(f32, i256, 1e6);
            try testArgs(f32, i256, 1e13);
            try testArgs(f32, i256, 1e20);
            try testArgs(f32, i256, 1e27);
            try testArgs(f32, i256, 1e34);
            try testArgs(f32, i256, 1e41);
            try testArgs(f32, i256, 1e48);
            try testArgs(f32, i256, 1e55);
            try testArgs(f32, i256, 1e62);
            try testArgs(f32, i256, 1e69);
            try testArgs(f32, i256, 1e76);
            try testArgs(f32, i256, imax(i256) - 1);
            try testArgs(f32, i256, imax(i256));

            try testArgs(f32, u256, 0);
            try testArgs(f32, u256, 1e0);
            try testArgs(f32, u256, 1e7);
            try testArgs(f32, u256, 1e14);
            try testArgs(f32, u256, 1e21);
            try testArgs(f32, u256, 1e28);
            try testArgs(f32, u256, 1e35);
            try testArgs(f32, u256, 1e42);
            try testArgs(f32, u256, 1e49);
            try testArgs(f32, u256, 1e56);
            try testArgs(f32, u256, 1e63);
            try testArgs(f32, u256, 1e70);
            try testArgs(f32, u256, 1e77);
            try testArgs(f32, u256, imax(u256) - 1);
            try testArgs(f32, u256, imax(u256));

            try testArgs(f64, i8, imin(i8));
            try testArgs(f64, i8, imin(i8) + 1);
            try testArgs(f64, i8, -1e2);
            try testArgs(f64, i8, -1e1);
            try testArgs(f64, i8, -1e0);
            try testArgs(f64, i8, 0);
            try testArgs(f64, i8, 1e0);
            try testArgs(f64, i8, 1e1);
            try testArgs(f64, i8, 1e2);
            try testArgs(f64, i8, imax(i8) - 1);
            try testArgs(f64, i8, imax(i8));

            try testArgs(f64, u8, 0);
            try testArgs(f64, u8, 1e0);
            try testArgs(f64, u8, 1e1);
            try testArgs(f64, u8, 1e2);
            try testArgs(f64, u8, imax(u8) - 1);
            try testArgs(f64, u8, imax(u8));

            try testArgs(f64, i16, imin(i16));
            try testArgs(f64, i16, imin(i16) + 1);
            try testArgs(f64, i16, -1e4);
            try testArgs(f64, i16, -1e3);
            try testArgs(f64, i16, -1e2);
            try testArgs(f64, i16, -1e1);
            try testArgs(f64, i16, -1e0);
            try testArgs(f64, i16, 0);
            try testArgs(f64, i16, 1e0);
            try testArgs(f64, i16, 1e1);
            try testArgs(f64, i16, 1e2);
            try testArgs(f64, i16, 1e3);
            try testArgs(f64, i16, 1e4);
            try testArgs(f64, i16, imax(i16) - 1);
            try testArgs(f64, i16, imax(i16));

            try testArgs(f64, u16, 0);
            try testArgs(f64, u16, 1e0);
            try testArgs(f64, u16, 1e1);
            try testArgs(f64, u16, 1e2);
            try testArgs(f64, u16, 1e3);
            try testArgs(f64, u16, 1e4);
            try testArgs(f64, u16, imax(u16) - 1);
            try testArgs(f64, u16, imax(u16));

            try testArgs(f64, i32, imin(i32));
            try testArgs(f64, i32, imin(i32) + 1);
            try testArgs(f64, i32, -1e9);
            try testArgs(f64, i32, -1e8);
            try testArgs(f64, i32, -1e7);
            try testArgs(f64, i32, -1e6);
            try testArgs(f64, i32, -1e5);
            try testArgs(f64, i32, -1e4);
            try testArgs(f64, i32, -1e3);
            try testArgs(f64, i32, -1e2);
            try testArgs(f64, i32, -1e1);
            try testArgs(f64, i32, -1e0);
            try testArgs(f64, i32, 0);
            try testArgs(f64, i32, 1e0);
            try testArgs(f64, i32, 1e1);
            try testArgs(f64, i32, 1e2);
            try testArgs(f64, i32, 1e3);
            try testArgs(f64, i32, 1e4);
            try testArgs(f64, i32, 1e5);
            try testArgs(f64, i32, 1e6);
            try testArgs(f64, i32, 1e7);
            try testArgs(f64, i32, 1e8);
            try testArgs(f64, i32, 1e9);
            try testArgs(f64, i32, imax(i32) - 1);
            try testArgs(f64, i32, imax(i32));

            try testArgs(f64, u32, 0);
            try testArgs(f64, u32, 1e0);
            try testArgs(f64, u32, 1e1);
            try testArgs(f64, u32, 1e2);
            try testArgs(f64, u32, 1e3);
            try testArgs(f64, u32, 1e4);
            try testArgs(f64, u32, 1e5);
            try testArgs(f64, u32, 1e6);
            try testArgs(f64, u32, 1e7);
            try testArgs(f64, u32, 1e8);
            try testArgs(f64, u32, 1e9);
            try testArgs(f64, u32, imax(u32) - 1);
            try testArgs(f64, u32, imax(u32));

            try testArgs(f64, i64, imin(i64));
            try testArgs(f64, i64, imin(i64) + 1);
            try testArgs(f64, i64, -1e18);
            try testArgs(f64, i64, -1e16);
            try testArgs(f64, i64, -1e14);
            try testArgs(f64, i64, -1e12);
            try testArgs(f64, i64, -1e10);
            try testArgs(f64, i64, -1e8);
            try testArgs(f64, i64, -1e6);
            try testArgs(f64, i64, -1e4);
            try testArgs(f64, i64, -1e2);
            try testArgs(f64, i64, -1e0);
            try testArgs(f64, i64, 0);
            try testArgs(f64, i64, 1e0);
            try testArgs(f64, i64, 1e2);
            try testArgs(f64, i64, 1e4);
            try testArgs(f64, i64, 1e6);
            try testArgs(f64, i64, 1e8);
            try testArgs(f64, i64, 1e10);
            try testArgs(f64, i64, 1e12);
            try testArgs(f64, i64, 1e14);
            try testArgs(f64, i64, 1e16);
            try testArgs(f64, i64, 1e18);
            try testArgs(f64, i64, imax(i64) - 1);
            try testArgs(f64, i64, imax(i64));

            try testArgs(f64, u64, 0);
            try testArgs(f64, u64, 1e0);
            try testArgs(f64, u64, 1e2);
            try testArgs(f64, u64, 1e4);
            try testArgs(f64, u64, 1e6);
            try testArgs(f64, u64, 1e8);
            try testArgs(f64, u64, 1e10);
            try testArgs(f64, u64, 1e12);
            try testArgs(f64, u64, 1e14);
            try testArgs(f64, u64, 1e16);
            try testArgs(f64, u64, 1e18);
            try testArgs(f64, u64, imax(u64) - 1);
            try testArgs(f64, u64, imax(u64));

            try testArgs(f64, i128, imin(i128));
            try testArgs(f64, i128, imin(i128) + 1);
            try testArgs(f64, i128, -1e38);
            try testArgs(f64, i128, -1e34);
            try testArgs(f64, i128, -1e30);
            try testArgs(f64, i128, -1e26);
            try testArgs(f64, i128, -1e22);
            try testArgs(f64, i128, -1e18);
            try testArgs(f64, i128, -1e14);
            try testArgs(f64, i128, -1e10);
            try testArgs(f64, i128, -1e6);
            try testArgs(f64, i128, -1e2);
            try testArgs(f64, i128, -1e0);
            try testArgs(f64, i128, 0);
            try testArgs(f64, i128, 1e0);
            try testArgs(f64, i128, 1e2);
            try testArgs(f64, i128, 1e6);
            try testArgs(f64, i128, 1e10);
            try testArgs(f64, i128, 1e14);
            try testArgs(f64, i128, 1e18);
            try testArgs(f64, i128, 1e22);
            try testArgs(f64, i128, 1e26);
            try testArgs(f64, i128, 1e30);
            try testArgs(f64, i128, 1e34);
            try testArgs(f64, i128, 1e38);
            try testArgs(f64, i128, imax(i128) - 1);
            try testArgs(f64, i128, imax(i128));

            try testArgs(f64, u128, 0);
            try testArgs(f64, u128, 1e0);
            try testArgs(f64, u128, 1e2);
            try testArgs(f64, u128, 1e6);
            try testArgs(f64, u128, 1e10);
            try testArgs(f64, u128, 1e14);
            try testArgs(f64, u128, 1e18);
            try testArgs(f64, u128, 1e22);
            try testArgs(f64, u128, 1e26);
            try testArgs(f64, u128, 1e30);
            try testArgs(f64, u128, 1e34);
            try testArgs(f64, u128, 1e38);
            try testArgs(f64, u128, imax(u128) - 1);
            try testArgs(f64, u128, imax(u128));

            try testArgs(f64, i256, imin(i256));
            try testArgs(f64, i256, imin(i256) + 1);
            try testArgs(f64, i256, -1e76);
            try testArgs(f64, i256, -1e69);
            try testArgs(f64, i256, -1e62);
            try testArgs(f64, i256, -1e55);
            try testArgs(f64, i256, -1e48);
            try testArgs(f64, i256, -1e41);
            try testArgs(f64, i256, -1e34);
            try testArgs(f64, i256, -1e27);
            try testArgs(f64, i256, -1e20);
            try testArgs(f64, i256, -1e13);
            try testArgs(f64, i256, -1e6);
            try testArgs(f64, i256, -1e0);
            try testArgs(f64, i256, 0);
            try testArgs(f64, i256, 1e0);
            try testArgs(f64, i256, 1e6);
            try testArgs(f64, i256, 1e13);
            try testArgs(f64, i256, 1e20);
            try testArgs(f64, i256, 1e27);
            try testArgs(f64, i256, 1e34);
            try testArgs(f64, i256, 1e41);
            try testArgs(f64, i256, 1e48);
            try testArgs(f64, i256, 1e55);
            try testArgs(f64, i256, 1e62);
            try testArgs(f64, i256, 1e69);
            try testArgs(f64, i256, 1e76);
            try testArgs(f64, i256, imax(i256) - 1);
            try testArgs(f64, i256, imax(i256));

            try testArgs(f64, u256, 0);
            try testArgs(f64, u256, 1e0);
            try testArgs(f64, u256, 1e7);
            try testArgs(f64, u256, 1e14);
            try testArgs(f64, u256, 1e21);
            try testArgs(f64, u256, 1e28);
            try testArgs(f64, u256, 1e35);
            try testArgs(f64, u256, 1e42);
            try testArgs(f64, u256, 1e49);
            try testArgs(f64, u256, 1e56);
            try testArgs(f64, u256, 1e63);
            try testArgs(f64, u256, 1e70);
            try testArgs(f64, u256, 1e77);
            try testArgs(f64, u256, imax(u256) - 1);
            try testArgs(f64, u256, imax(u256));

            try testArgs(f80, i8, imin(i8));
            try testArgs(f80, i8, imin(i8) + 1);
            try testArgs(f80, i8, -1e2);
            try testArgs(f80, i8, -1e1);
            try testArgs(f80, i8, -1e0);
            try testArgs(f80, i8, 0);
            try testArgs(f80, i8, 1e0);
            try testArgs(f80, i8, 1e1);
            try testArgs(f80, i8, 1e2);
            try testArgs(f80, i8, imax(i8) - 1);
            try testArgs(f80, i8, imax(i8));

            try testArgs(f80, u8, 0);
            try testArgs(f80, u8, 1e0);
            try testArgs(f80, u8, 1e1);
            try testArgs(f80, u8, 1e2);
            try testArgs(f80, u8, imax(u8) - 1);
            try testArgs(f80, u8, imax(u8));

            try testArgs(f80, i16, imin(i16));
            try testArgs(f80, i16, imin(i16) + 1);
            try testArgs(f80, i16, -1e4);
            try testArgs(f80, i16, -1e3);
            try testArgs(f80, i16, -1e2);
            try testArgs(f80, i16, -1e1);
            try testArgs(f80, i16, -1e0);
            try testArgs(f80, i16, 0);
            try testArgs(f80, i16, 1e0);
            try testArgs(f80, i16, 1e1);
            try testArgs(f80, i16, 1e2);
            try testArgs(f80, i16, 1e3);
            try testArgs(f80, i16, 1e4);
            try testArgs(f80, i16, imax(i16) - 1);
            try testArgs(f80, i16, imax(i16));

            try testArgs(f80, u16, 0);
            try testArgs(f80, u16, 1e0);
            try testArgs(f80, u16, 1e1);
            try testArgs(f80, u16, 1e2);
            try testArgs(f80, u16, 1e3);
            try testArgs(f80, u16, 1e4);
            try testArgs(f80, u16, imax(u16) - 1);
            try testArgs(f80, u16, imax(u16));

            try testArgs(f80, i32, imin(i32));
            try testArgs(f80, i32, imin(i32) + 1);
            try testArgs(f80, i32, -1e9);
            try testArgs(f80, i32, -1e8);
            try testArgs(f80, i32, -1e7);
            try testArgs(f80, i32, -1e6);
            try testArgs(f80, i32, -1e5);
            try testArgs(f80, i32, -1e4);
            try testArgs(f80, i32, -1e3);
            try testArgs(f80, i32, -1e2);
            try testArgs(f80, i32, -1e1);
            try testArgs(f80, i32, -1e0);
            try testArgs(f80, i32, 0);
            try testArgs(f80, i32, 1e0);
            try testArgs(f80, i32, 1e1);
            try testArgs(f80, i32, 1e2);
            try testArgs(f80, i32, 1e3);
            try testArgs(f80, i32, 1e4);
            try testArgs(f80, i32, 1e5);
            try testArgs(f80, i32, 1e6);
            try testArgs(f80, i32, 1e7);
            try testArgs(f80, i32, 1e8);
            try testArgs(f80, i32, 1e9);
            try testArgs(f80, i32, imax(i32) - 1);
            try testArgs(f80, i32, imax(i32));

            try testArgs(f80, u32, 0);
            try testArgs(f80, u32, 1e0);
            try testArgs(f80, u32, 1e1);
            try testArgs(f80, u32, 1e2);
            try testArgs(f80, u32, 1e3);
            try testArgs(f80, u32, 1e4);
            try testArgs(f80, u32, 1e5);
            try testArgs(f80, u32, 1e6);
            try testArgs(f80, u32, 1e7);
            try testArgs(f80, u32, 1e8);
            try testArgs(f80, u32, 1e9);
            try testArgs(f80, u32, imax(u32) - 1);
            try testArgs(f80, u32, imax(u32));

            try testArgs(f80, i64, imin(i64));
            try testArgs(f80, i64, imin(i64) + 1);
            try testArgs(f80, i64, -1e18);
            try testArgs(f80, i64, -1e16);
            try testArgs(f80, i64, -1e14);
            try testArgs(f80, i64, -1e12);
            try testArgs(f80, i64, -1e10);
            try testArgs(f80, i64, -1e8);
            try testArgs(f80, i64, -1e6);
            try testArgs(f80, i64, -1e4);
            try testArgs(f80, i64, -1e2);
            try testArgs(f80, i64, -1e0);
            try testArgs(f80, i64, 0);
            try testArgs(f80, i64, 1e0);
            try testArgs(f80, i64, 1e2);
            try testArgs(f80, i64, 1e4);
            try testArgs(f80, i64, 1e6);
            try testArgs(f80, i64, 1e8);
            try testArgs(f80, i64, 1e10);
            try testArgs(f80, i64, 1e12);
            try testArgs(f80, i64, 1e14);
            try testArgs(f80, i64, 1e16);
            try testArgs(f80, i64, 1e18);
            try testArgs(f80, i64, imax(i64) - 1);
            try testArgs(f80, i64, imax(i64));

            try testArgs(f80, u64, 0);
            try testArgs(f80, u64, 1e0);
            try testArgs(f80, u64, 1e2);
            try testArgs(f80, u64, 1e4);
            try testArgs(f80, u64, 1e6);
            try testArgs(f80, u64, 1e8);
            try testArgs(f80, u64, 1e10);
            try testArgs(f80, u64, 1e12);
            try testArgs(f80, u64, 1e14);
            try testArgs(f80, u64, 1e16);
            try testArgs(f80, u64, 1e18);
            try testArgs(f80, u64, imax(u64) - 1);
            try testArgs(f80, u64, imax(u64));

            try testArgs(f80, i128, imin(i128));
            try testArgs(f80, i128, imin(i128) + 1);
            try testArgs(f80, i128, -1e38);
            try testArgs(f80, i128, -1e34);
            try testArgs(f80, i128, -1e30);
            try testArgs(f80, i128, -1e26);
            try testArgs(f80, i128, -1e22);
            try testArgs(f80, i128, -1e18);
            try testArgs(f80, i128, -1e14);
            try testArgs(f80, i128, -1e10);
            try testArgs(f80, i128, -1e6);
            try testArgs(f80, i128, -1e2);
            try testArgs(f80, i128, -1e0);
            try testArgs(f80, i128, 0);
            try testArgs(f80, i128, 1e0);
            try testArgs(f80, i128, 1e2);
            try testArgs(f80, i128, 1e6);
            try testArgs(f80, i128, 1e10);
            try testArgs(f80, i128, 1e14);
            try testArgs(f80, i128, 1e18);
            try testArgs(f80, i128, 1e22);
            try testArgs(f80, i128, 1e26);
            try testArgs(f80, i128, 1e30);
            try testArgs(f80, i128, 1e34);
            try testArgs(f80, i128, 1e38);
            try testArgs(f80, i128, imax(i128) - 1);
            try testArgs(f80, i128, imax(i128));

            try testArgs(f80, u128, 0);
            try testArgs(f80, u128, 1e0);
            try testArgs(f80, u128, 1e2);
            try testArgs(f80, u128, 1e6);
            try testArgs(f80, u128, 1e10);
            try testArgs(f80, u128, 1e14);
            try testArgs(f80, u128, 1e18);
            try testArgs(f80, u128, 1e22);
            try testArgs(f80, u128, 1e26);
            try testArgs(f80, u128, 1e30);
            try testArgs(f80, u128, 1e34);
            try testArgs(f80, u128, 1e38);
            try testArgs(f80, u128, imax(u128) - 1);
            try testArgs(f80, u128, imax(u128));

            try testArgs(f80, i256, imin(i256));
            try testArgs(f80, i256, imin(i256) + 1);
            try testArgs(f80, i256, -1e76);
            try testArgs(f80, i256, -1e69);
            try testArgs(f80, i256, -1e62);
            try testArgs(f80, i256, -1e55);
            try testArgs(f80, i256, -1e48);
            try testArgs(f80, i256, -1e41);
            try testArgs(f80, i256, -1e34);
            try testArgs(f80, i256, -1e27);
            try testArgs(f80, i256, -1e20);
            try testArgs(f80, i256, -1e13);
            try testArgs(f80, i256, -1e6);
            try testArgs(f80, i256, -1e0);
            try testArgs(f80, i256, 0);
            try testArgs(f80, i256, 1e0);
            try testArgs(f80, i256, 1e6);
            try testArgs(f80, i256, 1e13);
            try testArgs(f80, i256, 1e20);
            try testArgs(f80, i256, 1e27);
            try testArgs(f80, i256, 1e34);
            try testArgs(f80, i256, 1e41);
            try testArgs(f80, i256, 1e48);
            try testArgs(f80, i256, 1e55);
            try testArgs(f80, i256, 1e62);
            try testArgs(f80, i256, 1e69);
            try testArgs(f80, i256, 1e76);
            try testArgs(f80, i256, imax(i256) - 1);
            try testArgs(f80, i256, imax(i256));

            try testArgs(f80, u256, 0);
            try testArgs(f80, u256, 1e0);
            try testArgs(f80, u256, 1e7);
            try testArgs(f80, u256, 1e14);
            try testArgs(f80, u256, 1e21);
            try testArgs(f80, u256, 1e28);
            try testArgs(f80, u256, 1e35);
            try testArgs(f80, u256, 1e42);
            try testArgs(f80, u256, 1e49);
            try testArgs(f80, u256, 1e56);
            try testArgs(f80, u256, 1e63);
            try testArgs(f80, u256, 1e70);
            try testArgs(f80, u256, 1e77);
            try testArgs(f80, u256, imax(u256) - 1);
            try testArgs(f80, u256, imax(u256));

            try testArgs(f128, i8, imin(i8));
            try testArgs(f128, i8, imin(i8) + 1);
            try testArgs(f128, i8, -1e2);
            try testArgs(f128, i8, -1e1);
            try testArgs(f128, i8, -1e0);
            try testArgs(f128, i8, 0);
            try testArgs(f128, i8, 1e0);
            try testArgs(f128, i8, 1e1);
            try testArgs(f128, i8, 1e2);
            try testArgs(f128, i8, imax(i8) - 1);
            try testArgs(f128, i8, imax(i8));

            try testArgs(f128, u8, 0);
            try testArgs(f128, u8, 1e0);
            try testArgs(f128, u8, 1e1);
            try testArgs(f128, u8, 1e2);
            try testArgs(f128, u8, imax(u8) - 1);
            try testArgs(f128, u8, imax(u8));

            try testArgs(f128, i16, imin(i16));
            try testArgs(f128, i16, imin(i16) + 1);
            try testArgs(f128, i16, -1e4);
            try testArgs(f128, i16, -1e3);
            try testArgs(f128, i16, -1e2);
            try testArgs(f128, i16, -1e1);
            try testArgs(f128, i16, -1e0);
            try testArgs(f128, i16, 0);
            try testArgs(f128, i16, 1e0);
            try testArgs(f128, i16, 1e1);
            try testArgs(f128, i16, 1e2);
            try testArgs(f128, i16, 1e3);
            try testArgs(f128, i16, 1e4);
            try testArgs(f128, i16, imax(i16) - 1);
            try testArgs(f128, i16, imax(i16));

            try testArgs(f128, u16, 0);
            try testArgs(f128, u16, 1e0);
            try testArgs(f128, u16, 1e1);
            try testArgs(f128, u16, 1e2);
            try testArgs(f128, u16, 1e3);
            try testArgs(f128, u16, 1e4);
            try testArgs(f128, u16, imax(u16) - 1);
            try testArgs(f128, u16, imax(u16));

            try testArgs(f128, i32, imin(i32));
            try testArgs(f128, i32, imin(i32) + 1);
            try testArgs(f128, i32, -1e9);
            try testArgs(f128, i32, -1e8);
            try testArgs(f128, i32, -1e7);
            try testArgs(f128, i32, -1e6);
            try testArgs(f128, i32, -1e5);
            try testArgs(f128, i32, -1e4);
            try testArgs(f128, i32, -1e3);
            try testArgs(f128, i32, -1e2);
            try testArgs(f128, i32, -1e1);
            try testArgs(f128, i32, -1e0);
            try testArgs(f128, i32, 0);
            try testArgs(f128, i32, 1e0);
            try testArgs(f128, i32, 1e1);
            try testArgs(f128, i32, 1e2);
            try testArgs(f128, i32, 1e3);
            try testArgs(f128, i32, 1e4);
            try testArgs(f128, i32, 1e5);
            try testArgs(f128, i32, 1e6);
            try testArgs(f128, i32, 1e7);
            try testArgs(f128, i32, 1e8);
            try testArgs(f128, i32, 1e9);
            try testArgs(f128, i32, imax(i32) - 1);
            try testArgs(f128, i32, imax(i32));

            try testArgs(f128, u32, 0);
            try testArgs(f128, u32, 1e0);
            try testArgs(f128, u32, 1e1);
            try testArgs(f128, u32, 1e2);
            try testArgs(f128, u32, 1e3);
            try testArgs(f128, u32, 1e4);
            try testArgs(f128, u32, 1e5);
            try testArgs(f128, u32, 1e6);
            try testArgs(f128, u32, 1e7);
            try testArgs(f128, u32, 1e8);
            try testArgs(f128, u32, 1e9);
            try testArgs(f128, u32, imax(u32) - 1);
            try testArgs(f128, u32, imax(u32));

            try testArgs(f128, i64, imin(i64));
            try testArgs(f128, i64, imin(i64) + 1);
            try testArgs(f128, i64, -1e18);
            try testArgs(f128, i64, -1e16);
            try testArgs(f128, i64, -1e14);
            try testArgs(f128, i64, -1e12);
            try testArgs(f128, i64, -1e10);
            try testArgs(f128, i64, -1e8);
            try testArgs(f128, i64, -1e6);
            try testArgs(f128, i64, -1e4);
            try testArgs(f128, i64, -1e2);
            try testArgs(f128, i64, -1e0);
            try testArgs(f128, i64, 0);
            try testArgs(f128, i64, 1e0);
            try testArgs(f128, i64, 1e2);
            try testArgs(f128, i64, 1e4);
            try testArgs(f128, i64, 1e6);
            try testArgs(f128, i64, 1e8);
            try testArgs(f128, i64, 1e10);
            try testArgs(f128, i64, 1e12);
            try testArgs(f128, i64, 1e14);
            try testArgs(f128, i64, 1e16);
            try testArgs(f128, i64, 1e18);
            try testArgs(f128, i64, imax(i64) - 1);
            try testArgs(f128, i64, imax(i64));

            try testArgs(f128, u64, 0);
            try testArgs(f128, u64, 1e0);
            try testArgs(f128, u64, 1e2);
            try testArgs(f128, u64, 1e4);
            try testArgs(f128, u64, 1e6);
            try testArgs(f128, u64, 1e8);
            try testArgs(f128, u64, 1e10);
            try testArgs(f128, u64, 1e12);
            try testArgs(f128, u64, 1e14);
            try testArgs(f128, u64, 1e16);
            try testArgs(f128, u64, 1e18);
            try testArgs(f128, u64, imax(u64) - 1);
            try testArgs(f128, u64, imax(u64));

            try testArgs(f128, i128, imin(i128));
            try testArgs(f128, i128, imin(i128) + 1);
            try testArgs(f128, i128, -1e38);
            try testArgs(f128, i128, -1e34);
            try testArgs(f128, i128, -1e30);
            try testArgs(f128, i128, -1e26);
            try testArgs(f128, i128, -1e22);
            try testArgs(f128, i128, -1e18);
            try testArgs(f128, i128, -1e14);
            try testArgs(f128, i128, -1e10);
            try testArgs(f128, i128, -1e6);
            try testArgs(f128, i128, -1e2);
            try testArgs(f128, i128, -1e0);
            try testArgs(f128, i128, 0);
            try testArgs(f128, i128, 1e0);
            try testArgs(f128, i128, 1e2);
            try testArgs(f128, i128, 1e6);
            try testArgs(f128, i128, 1e10);
            try testArgs(f128, i128, 1e14);
            try testArgs(f128, i128, 1e18);
            try testArgs(f128, i128, 1e22);
            try testArgs(f128, i128, 1e26);
            try testArgs(f128, i128, 1e30);
            try testArgs(f128, i128, 1e34);
            try testArgs(f128, i128, 1e38);
            try testArgs(f128, i128, imax(i128) - 1);
            try testArgs(f128, i128, imax(i128));

            try testArgs(f128, u128, 0);
            try testArgs(f128, u128, 1e0);
            try testArgs(f128, u128, 1e2);
            try testArgs(f128, u128, 1e6);
            try testArgs(f128, u128, 1e10);
            try testArgs(f128, u128, 1e14);
            try testArgs(f128, u128, 1e18);
            try testArgs(f128, u128, 1e22);
            try testArgs(f128, u128, 1e26);
            try testArgs(f128, u128, 1e30);
            try testArgs(f128, u128, 1e34);
            try testArgs(f128, u128, 1e38);
            try testArgs(f128, u128, imax(u128) - 1);
            try testArgs(f128, u128, imax(u128));

            try testArgs(f128, i256, imin(i256));
            try testArgs(f128, i256, imin(i256) + 1);
            try testArgs(f128, i256, -1e76);
            try testArgs(f128, i256, -1e69);
            try testArgs(f128, i256, -1e62);
            try testArgs(f128, i256, -1e55);
            try testArgs(f128, i256, -1e48);
            try testArgs(f128, i256, -1e41);
            try testArgs(f128, i256, -1e34);
            try testArgs(f128, i256, -1e27);
            try testArgs(f128, i256, -1e20);
            try testArgs(f128, i256, -1e13);
            try testArgs(f128, i256, -1e6);
            try testArgs(f128, i256, -1e0);
            try testArgs(f128, i256, 0);
            try testArgs(f128, i256, 1e0);
            try testArgs(f128, i256, 1e6);
            try testArgs(f128, i256, 1e13);
            try testArgs(f128, i256, 1e20);
            try testArgs(f128, i256, 1e27);
            try testArgs(f128, i256, 1e34);
            try testArgs(f128, i256, 1e41);
            try testArgs(f128, i256, 1e48);
            try testArgs(f128, i256, 1e55);
            try testArgs(f128, i256, 1e62);
            try testArgs(f128, i256, 1e69);
            try testArgs(f128, i256, 1e76);
            try testArgs(f128, i256, imax(i256) - 1);
            try testArgs(f128, i256, imax(i256));

            try testArgs(f128, u256, 0);
            try testArgs(f128, u256, 1e0);
            try testArgs(f128, u256, 1e7);
            try testArgs(f128, u256, 1e14);
            try testArgs(f128, u256, 1e21);
            try testArgs(f128, u256, 1e28);
            try testArgs(f128, u256, 1e35);
            try testArgs(f128, u256, 1e42);
            try testArgs(f128, u256, 1e49);
            try testArgs(f128, u256, 1e56);
            try testArgs(f128, u256, 1e63);
            try testArgs(f128, u256, 1e70);
            try testArgs(f128, u256, 1e77);
            try testArgs(f128, u256, imax(u256) - 1);
            try testArgs(f128, u256, imax(u256));
        }
    };
}

fn binary(comptime op: anytype, comptime opts: struct { compare: Compare = .relaxed }) type {
    return struct {
        // noinline so that `mem_lhs` and `mem_rhs` are on the stack
        noinline fn testArgKinds(
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            comptime Type: type,
            comptime imm_lhs: Type,
            mem_lhs: Type,
            comptime imm_rhs: Type,
            mem_rhs: Type,
        ) !void {
            const expected = comptime op(Type, imm_lhs, imm_rhs);
            var reg_lhs = mem_lhs;
            var reg_rhs = mem_rhs;
            _ = .{ &reg_lhs, &reg_rhs };
            try checkExpected(expected, op(Type, reg_lhs, reg_rhs), opts.compare);
            try checkExpected(expected, op(Type, reg_lhs, mem_rhs), opts.compare);
            try checkExpected(expected, op(Type, reg_lhs, imm_rhs), opts.compare);
            try checkExpected(expected, op(Type, mem_lhs, reg_rhs), opts.compare);
            try checkExpected(expected, op(Type, mem_lhs, mem_rhs), opts.compare);
            try checkExpected(expected, op(Type, mem_lhs, imm_rhs), opts.compare);
            try checkExpected(expected, op(Type, imm_lhs, reg_rhs), opts.compare);
            try checkExpected(expected, op(Type, imm_lhs, mem_rhs), opts.compare);
        }
        // noinline for a more helpful stack trace
        noinline fn testArgs(comptime Type: type, comptime imm_lhs: Type, comptime imm_rhs: Type) !void {
            try testArgKinds(
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                Type,
                imm_lhs,
                imm_lhs,
                imm_rhs,
                imm_rhs,
            );
        }
        fn testInts() !void {
            try testArgs(i8, 0x48, 0x6c);
            try testArgs(u8, 0xbb, 0x43);
            try testArgs(i16, -0x0fdf, 0x302e);
            try testArgs(u16, 0xb8bf, 0x626d);
            try testArgs(i32, -0x6280178f, 0x6802c034);
            try testArgs(u32, 0x80d7a2c6, 0xbff6a402);
            try testArgs(i64, 0x0365a53b8ee0c987, -0x1bb6d3013500a7d2);
            try testArgs(u64, 0x71138bc6b4a38898, 0x1bc4043de9438c7b);
            try testArgs(i128, 0x76d428c46cdeaa2ac43de8abffb22f6d, 0x427f7545abe434a12544fdbe2a012889);
            try testArgs(u128, 0xe05fc132ef2cd8affee00a907f0a851f, 0x29f912a72cfc6a7c6973426a9636da9a);
            try testArgs(i256, -0x53d4148cee74ea43477a65b3daa7b8fdadcbf4508e793f4af113b8d8da5a7eb6, -0x30dcbaf7b9b7a3df033694e6795444d842fb0b8f79bc18b3ea8a6b7ccad3ea91);
            try testArgs(u256, 0xb7935f5c2f3b1ae7a422c0a7c446884294b7d5370bada307d2fe5a4c4284a999, 0x310e6e196ba4f143b8d285ca6addf7f3bb3344224aff221b27607a31e148be08);
            try testArgs(i258, -0x0eee283365108dbeea0bec82f5147418d8ffe86f9eed00e414b4eccd65c21239a, -0x122c730073fc29a24cd6e3e6263566879bc5325d8566b8db31fcb4a76f7ab95eb);
            try testArgs(u258, 0x186d5ddaab8cb8cb04e5b41e36f812e039d008baf49f12894c39e29a07796d800, 0x2072daba6ffad168826163eb136f6d28ca4360c8e7e5e41e29755e19e4753a4f5);
            try testArgs(i495, 0x2fe6bc5448c55ce18252e2c9d44777505dfe63ff249a8027a6626c7d8dd9893fd5731e51474727be556f757facb586a4e04bbc0148c6c7ad692302f46fbd, -0x016a358821ef8240172f3a08e8830c06e6bcf2225f5f4d41ed42b44d249385f55cc594e1278ecac31c73faed890e5054af1a561483bb1bb6fb1f753514cf);
            try testArgs(u495, 0x6eaf4e252b3bf74b75bac59e0b43ca5326bad2a25b3fdb74a67ef132ac5e47d72eebc3316fb2351ee66c50dc5afb92a75cea9b0e35160652c7db39eeb158, 0x49fbed744a92b549d8c05bb3512c617d24dd824f3f69bdf3923bc326a75674b85f5b828d2566fab9c86f571d12c2a63c9164feb0d191d27905533d09622a);
            try testArgs(i512, -0x3a6876ca92775286c6e1504a64a9b8d56985bebf4a1b66539d404e0e96f24b226f70c4bcff295fdc2043b82513b2052dc45fd78f7e9e80e5b3e101757289f054, 0x5080c516a819bd32a0a5f0976441bbfbcf89e77684f1f10eb326aeb28e1f8d593278cff60fc99b8ffc87d8696882c64728dd3c322b7142803f4341f85a03bc10);
            try testArgs(u512, 0xe5b1fedca3c77db765e517aabd05ffc524a3a8aff1784bbf67c45b894447ede32b65b9940e78173c591e56e078932d465f235aece7ad47b7f229df7ba8f12295, 0x8b4bb7c2969e3b121cc1082c442f8b4330f0a50058438fed56447175bb10178607ecfe425cb54dacc25ef26810f3e04681de1844f1aa8d029aca75d658634806);
        }
        fn testFloats() !void {
            @setEvalBranchQuota(21_700);

            try testArgs(f16, -nan(f16), -nan(f16));
            try testArgs(f16, -nan(f16), -inf(f16));
            try testArgs(f16, -nan(f16), -fmax(f16));
            try testArgs(f16, -nan(f16), -1e1);
            try testArgs(f16, -nan(f16), -1e0);
            try testArgs(f16, -nan(f16), -1e-1);
            try testArgs(f16, -nan(f16), -fmin(f16));
            try testArgs(f16, -nan(f16), -tmin(f16));
            try testArgs(f16, -nan(f16), -0.0);
            try testArgs(f16, -nan(f16), 0.0);
            try testArgs(f16, -nan(f16), tmin(f16));
            try testArgs(f16, -nan(f16), fmin(f16));
            try testArgs(f16, -nan(f16), 1e-1);
            try testArgs(f16, -nan(f16), 1e0);
            try testArgs(f16, -nan(f16), 1e1);
            try testArgs(f16, -nan(f16), fmax(f16));
            try testArgs(f16, -nan(f16), inf(f16));
            try testArgs(f16, -nan(f16), nan(f16));

            try testArgs(f16, -inf(f16), -nan(f16));
            try testArgs(f16, -inf(f16), -inf(f16));
            try testArgs(f16, -inf(f16), -fmax(f16));
            try testArgs(f16, -inf(f16), -1e1);
            try testArgs(f16, -inf(f16), -1e0);
            try testArgs(f16, -inf(f16), -1e-1);
            try testArgs(f16, -inf(f16), -fmin(f16));
            try testArgs(f16, -inf(f16), -tmin(f16));
            try testArgs(f16, -inf(f16), -0.0);
            try testArgs(f16, -inf(f16), 0.0);
            try testArgs(f16, -inf(f16), tmin(f16));
            try testArgs(f16, -inf(f16), fmin(f16));
            try testArgs(f16, -inf(f16), 1e-1);
            try testArgs(f16, -inf(f16), 1e0);
            try testArgs(f16, -inf(f16), 1e1);
            try testArgs(f16, -inf(f16), fmax(f16));
            try testArgs(f16, -inf(f16), inf(f16));
            try testArgs(f16, -inf(f16), nan(f16));

            try testArgs(f16, -fmax(f16), -nan(f16));
            try testArgs(f16, -fmax(f16), -inf(f16));
            try testArgs(f16, -fmax(f16), -fmax(f16));
            try testArgs(f16, -fmax(f16), -1e1);
            try testArgs(f16, -fmax(f16), -1e0);
            try testArgs(f16, -fmax(f16), -1e-1);
            try testArgs(f16, -fmax(f16), -fmin(f16));
            try testArgs(f16, -fmax(f16), -tmin(f16));
            try testArgs(f16, -fmax(f16), -0.0);
            try testArgs(f16, -fmax(f16), 0.0);
            try testArgs(f16, -fmax(f16), tmin(f16));
            try testArgs(f16, -fmax(f16), fmin(f16));
            try testArgs(f16, -fmax(f16), 1e-1);
            try testArgs(f16, -fmax(f16), 1e0);
            try testArgs(f16, -fmax(f16), 1e1);
            try testArgs(f16, -fmax(f16), fmax(f16));
            try testArgs(f16, -fmax(f16), inf(f16));
            try testArgs(f16, -fmax(f16), nan(f16));

            try testArgs(f16, -1e1, -nan(f16));
            try testArgs(f16, -1e1, -inf(f16));
            try testArgs(f16, -1e1, -fmax(f16));
            try testArgs(f16, -1e1, -1e1);
            try testArgs(f16, -1e1, -1e0);
            try testArgs(f16, -1e1, -1e-1);
            try testArgs(f16, -1e1, -fmin(f16));
            try testArgs(f16, -1e1, -tmin(f16));
            try testArgs(f16, -1e1, -0.0);
            try testArgs(f16, -1e1, 0.0);
            try testArgs(f16, -1e1, tmin(f16));
            try testArgs(f16, -1e1, fmin(f16));
            try testArgs(f16, -1e1, 1e-1);
            try testArgs(f16, -1e1, 1e0);
            try testArgs(f16, -1e1, 1e1);
            try testArgs(f16, -1e1, fmax(f16));
            try testArgs(f16, -1e1, inf(f16));
            try testArgs(f16, -1e1, nan(f16));

            try testArgs(f16, -1e0, -nan(f16));
            try testArgs(f16, -1e0, -inf(f16));
            try testArgs(f16, -1e0, -fmax(f16));
            try testArgs(f16, -1e0, -1e1);
            try testArgs(f16, -1e0, -1e0);
            try testArgs(f16, -1e0, -1e-1);
            try testArgs(f16, -1e0, -fmin(f16));
            try testArgs(f16, -1e0, -tmin(f16));
            try testArgs(f16, -1e0, -0.0);
            try testArgs(f16, -1e0, 0.0);
            try testArgs(f16, -1e0, tmin(f16));
            try testArgs(f16, -1e0, fmin(f16));
            try testArgs(f16, -1e0, 1e-1);
            try testArgs(f16, -1e0, 1e0);
            try testArgs(f16, -1e0, 1e1);
            try testArgs(f16, -1e0, fmax(f16));
            try testArgs(f16, -1e0, inf(f16));
            try testArgs(f16, -1e0, nan(f16));

            try testArgs(f16, -1e-1, -nan(f16));
            try testArgs(f16, -1e-1, -inf(f16));
            try testArgs(f16, -1e-1, -fmax(f16));
            try testArgs(f16, -1e-1, -1e1);
            try testArgs(f16, -1e-1, -1e0);
            try testArgs(f16, -1e-1, -1e-1);
            try testArgs(f16, -1e-1, -fmin(f16));
            try testArgs(f16, -1e-1, -tmin(f16));
            try testArgs(f16, -1e-1, -0.0);
            try testArgs(f16, -1e-1, 0.0);
            try testArgs(f16, -1e-1, tmin(f16));
            try testArgs(f16, -1e-1, fmin(f16));
            try testArgs(f16, -1e-1, 1e-1);
            try testArgs(f16, -1e-1, 1e0);
            try testArgs(f16, -1e-1, 1e1);
            try testArgs(f16, -1e-1, fmax(f16));
            try testArgs(f16, -1e-1, inf(f16));
            try testArgs(f16, -1e-1, nan(f16));

            try testArgs(f16, -fmin(f16), -nan(f16));
            try testArgs(f16, -fmin(f16), -inf(f16));
            try testArgs(f16, -fmin(f16), -fmax(f16));
            try testArgs(f16, -fmin(f16), -1e1);
            try testArgs(f16, -fmin(f16), -1e0);
            try testArgs(f16, -fmin(f16), -1e-1);
            try testArgs(f16, -fmin(f16), -fmin(f16));
            try testArgs(f16, -fmin(f16), -tmin(f16));
            try testArgs(f16, -fmin(f16), -0.0);
            try testArgs(f16, -fmin(f16), 0.0);
            try testArgs(f16, -fmin(f16), tmin(f16));
            try testArgs(f16, -fmin(f16), fmin(f16));
            try testArgs(f16, -fmin(f16), 1e-1);
            try testArgs(f16, -fmin(f16), 1e0);
            try testArgs(f16, -fmin(f16), 1e1);
            try testArgs(f16, -fmin(f16), fmax(f16));
            try testArgs(f16, -fmin(f16), inf(f16));
            try testArgs(f16, -fmin(f16), nan(f16));

            try testArgs(f16, -tmin(f16), -nan(f16));
            try testArgs(f16, -tmin(f16), -inf(f16));
            try testArgs(f16, -tmin(f16), -fmax(f16));
            try testArgs(f16, -tmin(f16), -1e1);
            try testArgs(f16, -tmin(f16), -1e0);
            try testArgs(f16, -tmin(f16), -1e-1);
            try testArgs(f16, -tmin(f16), -fmin(f16));
            try testArgs(f16, -tmin(f16), -tmin(f16));
            try testArgs(f16, -tmin(f16), -0.0);
            try testArgs(f16, -tmin(f16), 0.0);
            try testArgs(f16, -tmin(f16), tmin(f16));
            try testArgs(f16, -tmin(f16), fmin(f16));
            try testArgs(f16, -tmin(f16), 1e-1);
            try testArgs(f16, -tmin(f16), 1e0);
            try testArgs(f16, -tmin(f16), 1e1);
            try testArgs(f16, -tmin(f16), fmax(f16));
            try testArgs(f16, -tmin(f16), inf(f16));
            try testArgs(f16, -tmin(f16), nan(f16));

            try testArgs(f16, -0.0, -nan(f16));
            try testArgs(f16, -0.0, -inf(f16));
            try testArgs(f16, -0.0, -fmax(f16));
            try testArgs(f16, -0.0, -1e1);
            try testArgs(f16, -0.0, -1e0);
            try testArgs(f16, -0.0, -1e-1);
            try testArgs(f16, -0.0, -fmin(f16));
            try testArgs(f16, -0.0, -tmin(f16));
            try testArgs(f16, -0.0, -0.0);
            try testArgs(f16, -0.0, 0.0);
            try testArgs(f16, -0.0, tmin(f16));
            try testArgs(f16, -0.0, fmin(f16));
            try testArgs(f16, -0.0, 1e-1);
            try testArgs(f16, -0.0, 1e0);
            try testArgs(f16, -0.0, 1e1);
            try testArgs(f16, -0.0, fmax(f16));
            try testArgs(f16, -0.0, inf(f16));
            try testArgs(f16, -0.0, nan(f16));

            try testArgs(f16, 0.0, -nan(f16));
            try testArgs(f16, 0.0, -inf(f16));
            try testArgs(f16, 0.0, -fmax(f16));
            try testArgs(f16, 0.0, -1e1);
            try testArgs(f16, 0.0, -1e0);
            try testArgs(f16, 0.0, -1e-1);
            try testArgs(f16, 0.0, -fmin(f16));
            try testArgs(f16, 0.0, -tmin(f16));
            try testArgs(f16, 0.0, -0.0);
            try testArgs(f16, 0.0, 0.0);
            try testArgs(f16, 0.0, tmin(f16));
            try testArgs(f16, 0.0, fmin(f16));
            try testArgs(f16, 0.0, 1e-1);
            try testArgs(f16, 0.0, 1e0);
            try testArgs(f16, 0.0, 1e1);
            try testArgs(f16, 0.0, fmax(f16));
            try testArgs(f16, 0.0, inf(f16));
            try testArgs(f16, 0.0, nan(f16));

            try testArgs(f16, tmin(f16), -nan(f16));
            try testArgs(f16, tmin(f16), -inf(f16));
            try testArgs(f16, tmin(f16), -fmax(f16));
            try testArgs(f16, tmin(f16), -1e1);
            try testArgs(f16, tmin(f16), -1e0);
            try testArgs(f16, tmin(f16), -1e-1);
            try testArgs(f16, tmin(f16), -fmin(f16));
            try testArgs(f16, tmin(f16), -tmin(f16));
            try testArgs(f16, tmin(f16), -0.0);
            try testArgs(f16, tmin(f16), 0.0);
            try testArgs(f16, tmin(f16), tmin(f16));
            try testArgs(f16, tmin(f16), fmin(f16));
            try testArgs(f16, tmin(f16), 1e-1);
            try testArgs(f16, tmin(f16), 1e0);
            try testArgs(f16, tmin(f16), 1e1);
            try testArgs(f16, tmin(f16), fmax(f16));
            try testArgs(f16, tmin(f16), inf(f16));
            try testArgs(f16, tmin(f16), nan(f16));

            try testArgs(f16, fmin(f16), -nan(f16));
            try testArgs(f16, fmin(f16), -inf(f16));
            try testArgs(f16, fmin(f16), -fmax(f16));
            try testArgs(f16, fmin(f16), -1e1);
            try testArgs(f16, fmin(f16), -1e0);
            try testArgs(f16, fmin(f16), -1e-1);
            try testArgs(f16, fmin(f16), -fmin(f16));
            try testArgs(f16, fmin(f16), -tmin(f16));
            try testArgs(f16, fmin(f16), -0.0);
            try testArgs(f16, fmin(f16), 0.0);
            try testArgs(f16, fmin(f16), tmin(f16));
            try testArgs(f16, fmin(f16), fmin(f16));
            try testArgs(f16, fmin(f16), 1e-1);
            try testArgs(f16, fmin(f16), 1e0);
            try testArgs(f16, fmin(f16), 1e1);
            try testArgs(f16, fmin(f16), fmax(f16));
            try testArgs(f16, fmin(f16), inf(f16));
            try testArgs(f16, fmin(f16), nan(f16));

            try testArgs(f16, 1e-1, -nan(f16));
            try testArgs(f16, 1e-1, -inf(f16));
            try testArgs(f16, 1e-1, -fmax(f16));
            try testArgs(f16, 1e-1, -1e1);
            try testArgs(f16, 1e-1, -1e0);
            try testArgs(f16, 1e-1, -1e-1);
            try testArgs(f16, 1e-1, -fmin(f16));
            try testArgs(f16, 1e-1, -tmin(f16));
            try testArgs(f16, 1e-1, -0.0);
            try testArgs(f16, 1e-1, 0.0);
            try testArgs(f16, 1e-1, tmin(f16));
            try testArgs(f16, 1e-1, fmin(f16));
            try testArgs(f16, 1e-1, 1e-1);
            try testArgs(f16, 1e-1, 1e0);
            try testArgs(f16, 1e-1, 1e1);
            try testArgs(f16, 1e-1, fmax(f16));
            try testArgs(f16, 1e-1, inf(f16));
            try testArgs(f16, 1e-1, nan(f16));

            try testArgs(f16, 1e0, -nan(f16));
            try testArgs(f16, 1e0, -inf(f16));
            try testArgs(f16, 1e0, -fmax(f16));
            try testArgs(f16, 1e0, -1e1);
            try testArgs(f16, 1e0, -1e0);
            try testArgs(f16, 1e0, -1e-1);
            try testArgs(f16, 1e0, -fmin(f16));
            try testArgs(f16, 1e0, -tmin(f16));
            try testArgs(f16, 1e0, -0.0);
            try testArgs(f16, 1e0, 0.0);
            try testArgs(f16, 1e0, tmin(f16));
            try testArgs(f16, 1e0, fmin(f16));
            try testArgs(f16, 1e0, 1e-1);
            try testArgs(f16, 1e0, 1e0);
            try testArgs(f16, 1e0, 1e1);
            try testArgs(f16, 1e0, fmax(f16));
            try testArgs(f16, 1e0, inf(f16));
            try testArgs(f16, 1e0, nan(f16));

            try testArgs(f16, 1e1, -nan(f16));
            try testArgs(f16, 1e1, -inf(f16));
            try testArgs(f16, 1e1, -fmax(f16));
            try testArgs(f16, 1e1, -1e1);
            try testArgs(f16, 1e1, -1e0);
            try testArgs(f16, 1e1, -1e-1);
            try testArgs(f16, 1e1, -fmin(f16));
            try testArgs(f16, 1e1, -tmin(f16));
            try testArgs(f16, 1e1, -0.0);
            try testArgs(f16, 1e1, 0.0);
            try testArgs(f16, 1e1, tmin(f16));
            try testArgs(f16, 1e1, fmin(f16));
            try testArgs(f16, 1e1, 1e-1);
            try testArgs(f16, 1e1, 1e0);
            try testArgs(f16, 1e1, 1e1);
            try testArgs(f16, 1e1, fmax(f16));
            try testArgs(f16, 1e1, inf(f16));
            try testArgs(f16, 1e1, nan(f16));

            try testArgs(f16, fmax(f16), -nan(f16));
            try testArgs(f16, fmax(f16), -inf(f16));
            try testArgs(f16, fmax(f16), -fmax(f16));
            try testArgs(f16, fmax(f16), -1e1);
            try testArgs(f16, fmax(f16), -1e0);
            try testArgs(f16, fmax(f16), -1e-1);
            try testArgs(f16, fmax(f16), -fmin(f16));
            try testArgs(f16, fmax(f16), -tmin(f16));
            try testArgs(f16, fmax(f16), -0.0);
            try testArgs(f16, fmax(f16), 0.0);
            try testArgs(f16, fmax(f16), tmin(f16));
            try testArgs(f16, fmax(f16), fmin(f16));
            try testArgs(f16, fmax(f16), 1e-1);
            try testArgs(f16, fmax(f16), 1e0);
            try testArgs(f16, fmax(f16), 1e1);
            try testArgs(f16, fmax(f16), fmax(f16));
            try testArgs(f16, fmax(f16), inf(f16));
            try testArgs(f16, fmax(f16), nan(f16));

            try testArgs(f16, inf(f16), -nan(f16));
            try testArgs(f16, inf(f16), -inf(f16));
            try testArgs(f16, inf(f16), -fmax(f16));
            try testArgs(f16, inf(f16), -1e1);
            try testArgs(f16, inf(f16), -1e0);
            try testArgs(f16, inf(f16), -1e-1);
            try testArgs(f16, inf(f16), -fmin(f16));
            try testArgs(f16, inf(f16), -tmin(f16));
            try testArgs(f16, inf(f16), -0.0);
            try testArgs(f16, inf(f16), 0.0);
            try testArgs(f16, inf(f16), tmin(f16));
            try testArgs(f16, inf(f16), fmin(f16));
            try testArgs(f16, inf(f16), 1e-1);
            try testArgs(f16, inf(f16), 1e0);
            try testArgs(f16, inf(f16), 1e1);
            try testArgs(f16, inf(f16), fmax(f16));
            try testArgs(f16, inf(f16), inf(f16));
            try testArgs(f16, inf(f16), nan(f16));

            try testArgs(f16, nan(f16), -nan(f16));
            try testArgs(f16, nan(f16), -inf(f16));
            try testArgs(f16, nan(f16), -fmax(f16));
            try testArgs(f16, nan(f16), -1e1);
            try testArgs(f16, nan(f16), -1e0);
            try testArgs(f16, nan(f16), -1e-1);
            try testArgs(f16, nan(f16), -fmin(f16));
            try testArgs(f16, nan(f16), -tmin(f16));
            try testArgs(f16, nan(f16), -0.0);
            try testArgs(f16, nan(f16), 0.0);
            try testArgs(f16, nan(f16), tmin(f16));
            try testArgs(f16, nan(f16), fmin(f16));
            try testArgs(f16, nan(f16), 1e-1);
            try testArgs(f16, nan(f16), 1e0);
            try testArgs(f16, nan(f16), 1e1);
            try testArgs(f16, nan(f16), fmax(f16));
            try testArgs(f16, nan(f16), inf(f16));
            try testArgs(f16, nan(f16), nan(f16));

            try testArgs(f32, -nan(f32), -nan(f32));
            try testArgs(f32, -nan(f32), -inf(f32));
            try testArgs(f32, -nan(f32), -fmax(f32));
            try testArgs(f32, -nan(f32), -1e1);
            try testArgs(f32, -nan(f32), -1e0);
            try testArgs(f32, -nan(f32), -1e-1);
            try testArgs(f32, -nan(f32), -fmin(f32));
            try testArgs(f32, -nan(f32), -tmin(f32));
            try testArgs(f32, -nan(f32), -0.0);
            try testArgs(f32, -nan(f32), 0.0);
            try testArgs(f32, -nan(f32), tmin(f32));
            try testArgs(f32, -nan(f32), fmin(f32));
            try testArgs(f32, -nan(f32), 1e-1);
            try testArgs(f32, -nan(f32), 1e0);
            try testArgs(f32, -nan(f32), 1e1);
            try testArgs(f32, -nan(f32), fmax(f32));
            try testArgs(f32, -nan(f32), inf(f32));
            try testArgs(f32, -nan(f32), nan(f32));

            try testArgs(f32, -inf(f32), -nan(f32));
            try testArgs(f32, -inf(f32), -inf(f32));
            try testArgs(f32, -inf(f32), -fmax(f32));
            try testArgs(f32, -inf(f32), -1e1);
            try testArgs(f32, -inf(f32), -1e0);
            try testArgs(f32, -inf(f32), -1e-1);
            try testArgs(f32, -inf(f32), -fmin(f32));
            try testArgs(f32, -inf(f32), -tmin(f32));
            try testArgs(f32, -inf(f32), -0.0);
            try testArgs(f32, -inf(f32), 0.0);
            try testArgs(f32, -inf(f32), tmin(f32));
            try testArgs(f32, -inf(f32), fmin(f32));
            try testArgs(f32, -inf(f32), 1e-1);
            try testArgs(f32, -inf(f32), 1e0);
            try testArgs(f32, -inf(f32), 1e1);
            try testArgs(f32, -inf(f32), fmax(f32));
            try testArgs(f32, -inf(f32), inf(f32));
            try testArgs(f32, -inf(f32), nan(f32));

            try testArgs(f32, -fmax(f32), -nan(f32));
            try testArgs(f32, -fmax(f32), -inf(f32));
            try testArgs(f32, -fmax(f32), -fmax(f32));
            try testArgs(f32, -fmax(f32), -1e1);
            try testArgs(f32, -fmax(f32), -1e0);
            try testArgs(f32, -fmax(f32), -1e-1);
            try testArgs(f32, -fmax(f32), -fmin(f32));
            try testArgs(f32, -fmax(f32), -tmin(f32));
            try testArgs(f32, -fmax(f32), -0.0);
            try testArgs(f32, -fmax(f32), 0.0);
            try testArgs(f32, -fmax(f32), tmin(f32));
            try testArgs(f32, -fmax(f32), fmin(f32));
            try testArgs(f32, -fmax(f32), 1e-1);
            try testArgs(f32, -fmax(f32), 1e0);
            try testArgs(f32, -fmax(f32), 1e1);
            try testArgs(f32, -fmax(f32), fmax(f32));
            try testArgs(f32, -fmax(f32), inf(f32));
            try testArgs(f32, -fmax(f32), nan(f32));

            try testArgs(f32, -1e1, -nan(f32));
            try testArgs(f32, -1e1, -inf(f32));
            try testArgs(f32, -1e1, -fmax(f32));
            try testArgs(f32, -1e1, -1e1);
            try testArgs(f32, -1e1, -1e0);
            try testArgs(f32, -1e1, -1e-1);
            try testArgs(f32, -1e1, -fmin(f32));
            try testArgs(f32, -1e1, -tmin(f32));
            try testArgs(f32, -1e1, -0.0);
            try testArgs(f32, -1e1, 0.0);
            try testArgs(f32, -1e1, tmin(f32));
            try testArgs(f32, -1e1, fmin(f32));
            try testArgs(f32, -1e1, 1e-1);
            try testArgs(f32, -1e1, 1e0);
            try testArgs(f32, -1e1, 1e1);
            try testArgs(f32, -1e1, fmax(f32));
            try testArgs(f32, -1e1, inf(f32));
            try testArgs(f32, -1e1, nan(f32));

            try testArgs(f32, -1e0, -nan(f32));
            try testArgs(f32, -1e0, -inf(f32));
            try testArgs(f32, -1e0, -fmax(f32));
            try testArgs(f32, -1e0, -1e1);
            try testArgs(f32, -1e0, -1e0);
            try testArgs(f32, -1e0, -1e-1);
            try testArgs(f32, -1e0, -fmin(f32));
            try testArgs(f32, -1e0, -tmin(f32));
            try testArgs(f32, -1e0, -0.0);
            try testArgs(f32, -1e0, 0.0);
            try testArgs(f32, -1e0, tmin(f32));
            try testArgs(f32, -1e0, fmin(f32));
            try testArgs(f32, -1e0, 1e-1);
            try testArgs(f32, -1e0, 1e0);
            try testArgs(f32, -1e0, 1e1);
            try testArgs(f32, -1e0, fmax(f32));
            try testArgs(f32, -1e0, inf(f32));
            try testArgs(f32, -1e0, nan(f32));

            try testArgs(f32, -1e-1, -nan(f32));
            try testArgs(f32, -1e-1, -inf(f32));
            try testArgs(f32, -1e-1, -fmax(f32));
            try testArgs(f32, -1e-1, -1e1);
            try testArgs(f32, -1e-1, -1e0);
            try testArgs(f32, -1e-1, -1e-1);
            try testArgs(f32, -1e-1, -fmin(f32));
            try testArgs(f32, -1e-1, -tmin(f32));
            try testArgs(f32, -1e-1, -0.0);
            try testArgs(f32, -1e-1, 0.0);
            try testArgs(f32, -1e-1, tmin(f32));
            try testArgs(f32, -1e-1, fmin(f32));
            try testArgs(f32, -1e-1, 1e-1);
            try testArgs(f32, -1e-1, 1e0);
            try testArgs(f32, -1e-1, 1e1);
            try testArgs(f32, -1e-1, fmax(f32));
            try testArgs(f32, -1e-1, inf(f32));
            try testArgs(f32, -1e-1, nan(f32));

            try testArgs(f32, -fmin(f32), -nan(f32));
            try testArgs(f32, -fmin(f32), -inf(f32));
            try testArgs(f32, -fmin(f32), -fmax(f32));
            try testArgs(f32, -fmin(f32), -1e1);
            try testArgs(f32, -fmin(f32), -1e0);
            try testArgs(f32, -fmin(f32), -1e-1);
            try testArgs(f32, -fmin(f32), -fmin(f32));
            try testArgs(f32, -fmin(f32), -tmin(f32));
            try testArgs(f32, -fmin(f32), -0.0);
            try testArgs(f32, -fmin(f32), 0.0);
            try testArgs(f32, -fmin(f32), tmin(f32));
            try testArgs(f32, -fmin(f32), fmin(f32));
            try testArgs(f32, -fmin(f32), 1e-1);
            try testArgs(f32, -fmin(f32), 1e0);
            try testArgs(f32, -fmin(f32), 1e1);
            try testArgs(f32, -fmin(f32), fmax(f32));
            try testArgs(f32, -fmin(f32), inf(f32));
            try testArgs(f32, -fmin(f32), nan(f32));

            try testArgs(f32, -tmin(f32), -nan(f32));
            try testArgs(f32, -tmin(f32), -inf(f32));
            try testArgs(f32, -tmin(f32), -fmax(f32));
            try testArgs(f32, -tmin(f32), -1e1);
            try testArgs(f32, -tmin(f32), -1e0);
            try testArgs(f32, -tmin(f32), -1e-1);
            try testArgs(f32, -tmin(f32), -fmin(f32));
            try testArgs(f32, -tmin(f32), -tmin(f32));
            try testArgs(f32, -tmin(f32), -0.0);
            try testArgs(f32, -tmin(f32), 0.0);
            try testArgs(f32, -tmin(f32), tmin(f32));
            try testArgs(f32, -tmin(f32), fmin(f32));
            try testArgs(f32, -tmin(f32), 1e-1);
            try testArgs(f32, -tmin(f32), 1e0);
            try testArgs(f32, -tmin(f32), 1e1);
            try testArgs(f32, -tmin(f32), fmax(f32));
            try testArgs(f32, -tmin(f32), inf(f32));
            try testArgs(f32, -tmin(f32), nan(f32));

            try testArgs(f32, -0.0, -nan(f32));
            try testArgs(f32, -0.0, -inf(f32));
            try testArgs(f32, -0.0, -fmax(f32));
            try testArgs(f32, -0.0, -1e1);
            try testArgs(f32, -0.0, -1e0);
            try testArgs(f32, -0.0, -1e-1);
            try testArgs(f32, -0.0, -fmin(f32));
            try testArgs(f32, -0.0, -tmin(f32));
            try testArgs(f32, -0.0, -0.0);
            try testArgs(f32, -0.0, 0.0);
            try testArgs(f32, -0.0, tmin(f32));
            try testArgs(f32, -0.0, fmin(f32));
            try testArgs(f32, -0.0, 1e-1);
            try testArgs(f32, -0.0, 1e0);
            try testArgs(f32, -0.0, 1e1);
            try testArgs(f32, -0.0, fmax(f32));
            try testArgs(f32, -0.0, inf(f32));
            try testArgs(f32, -0.0, nan(f32));

            try testArgs(f32, 0.0, -nan(f32));
            try testArgs(f32, 0.0, -inf(f32));
            try testArgs(f32, 0.0, -fmax(f32));
            try testArgs(f32, 0.0, -1e1);
            try testArgs(f32, 0.0, -1e0);
            try testArgs(f32, 0.0, -1e-1);
            try testArgs(f32, 0.0, -fmin(f32));
            try testArgs(f32, 0.0, -tmin(f32));
            try testArgs(f32, 0.0, -0.0);
            try testArgs(f32, 0.0, 0.0);
            try testArgs(f32, 0.0, tmin(f32));
            try testArgs(f32, 0.0, fmin(f32));
            try testArgs(f32, 0.0, 1e-1);
            try testArgs(f32, 0.0, 1e0);
            try testArgs(f32, 0.0, 1e1);
            try testArgs(f32, 0.0, fmax(f32));
            try testArgs(f32, 0.0, inf(f32));
            try testArgs(f32, 0.0, nan(f32));

            try testArgs(f32, tmin(f32), -nan(f32));
            try testArgs(f32, tmin(f32), -inf(f32));
            try testArgs(f32, tmin(f32), -fmax(f32));
            try testArgs(f32, tmin(f32), -1e1);
            try testArgs(f32, tmin(f32), -1e0);
            try testArgs(f32, tmin(f32), -1e-1);
            try testArgs(f32, tmin(f32), -fmin(f32));
            try testArgs(f32, tmin(f32), -tmin(f32));
            try testArgs(f32, tmin(f32), -0.0);
            try testArgs(f32, tmin(f32), 0.0);
            try testArgs(f32, tmin(f32), tmin(f32));
            try testArgs(f32, tmin(f32), fmin(f32));
            try testArgs(f32, tmin(f32), 1e-1);
            try testArgs(f32, tmin(f32), 1e0);
            try testArgs(f32, tmin(f32), 1e1);
            try testArgs(f32, tmin(f32), fmax(f32));
            try testArgs(f32, tmin(f32), inf(f32));
            try testArgs(f32, tmin(f32), nan(f32));

            try testArgs(f32, fmin(f32), -nan(f32));
            try testArgs(f32, fmin(f32), -inf(f32));
            try testArgs(f32, fmin(f32), -fmax(f32));
            try testArgs(f32, fmin(f32), -1e1);
            try testArgs(f32, fmin(f32), -1e0);
            try testArgs(f32, fmin(f32), -1e-1);
            try testArgs(f32, fmin(f32), -fmin(f32));
            try testArgs(f32, fmin(f32), -tmin(f32));
            try testArgs(f32, fmin(f32), -0.0);
            try testArgs(f32, fmin(f32), 0.0);
            try testArgs(f32, fmin(f32), tmin(f32));
            try testArgs(f32, fmin(f32), fmin(f32));
            try testArgs(f32, fmin(f32), 1e-1);
            try testArgs(f32, fmin(f32), 1e0);
            try testArgs(f32, fmin(f32), 1e1);
            try testArgs(f32, fmin(f32), fmax(f32));
            try testArgs(f32, fmin(f32), inf(f32));
            try testArgs(f32, fmin(f32), nan(f32));

            try testArgs(f32, 1e-1, -nan(f32));
            try testArgs(f32, 1e-1, -inf(f32));
            try testArgs(f32, 1e-1, -fmax(f32));
            try testArgs(f32, 1e-1, -1e1);
            try testArgs(f32, 1e-1, -1e0);
            try testArgs(f32, 1e-1, -1e-1);
            try testArgs(f32, 1e-1, -fmin(f32));
            try testArgs(f32, 1e-1, -tmin(f32));
            try testArgs(f32, 1e-1, -0.0);
            try testArgs(f32, 1e-1, 0.0);
            try testArgs(f32, 1e-1, tmin(f32));
            try testArgs(f32, 1e-1, fmin(f32));
            try testArgs(f32, 1e-1, 1e-1);
            try testArgs(f32, 1e-1, 1e0);
            try testArgs(f32, 1e-1, 1e1);
            try testArgs(f32, 1e-1, fmax(f32));
            try testArgs(f32, 1e-1, inf(f32));
            try testArgs(f32, 1e-1, nan(f32));

            try testArgs(f32, 1e0, -nan(f32));
            try testArgs(f32, 1e0, -inf(f32));
            try testArgs(f32, 1e0, -fmax(f32));
            try testArgs(f32, 1e0, -1e1);
            try testArgs(f32, 1e0, -1e0);
            try testArgs(f32, 1e0, -1e-1);
            try testArgs(f32, 1e0, -fmin(f32));
            try testArgs(f32, 1e0, -tmin(f32));
            try testArgs(f32, 1e0, -0.0);
            try testArgs(f32, 1e0, 0.0);
            try testArgs(f32, 1e0, tmin(f32));
            try testArgs(f32, 1e0, fmin(f32));
            try testArgs(f32, 1e0, 1e-1);
            try testArgs(f32, 1e0, 1e0);
            try testArgs(f32, 1e0, 1e1);
            try testArgs(f32, 1e0, fmax(f32));
            try testArgs(f32, 1e0, inf(f32));
            try testArgs(f32, 1e0, nan(f32));

            try testArgs(f32, 1e1, -nan(f32));
            try testArgs(f32, 1e1, -inf(f32));
            try testArgs(f32, 1e1, -fmax(f32));
            try testArgs(f32, 1e1, -1e1);
            try testArgs(f32, 1e1, -1e0);
            try testArgs(f32, 1e1, -1e-1);
            try testArgs(f32, 1e1, -fmin(f32));
            try testArgs(f32, 1e1, -tmin(f32));
            try testArgs(f32, 1e1, -0.0);
            try testArgs(f32, 1e1, 0.0);
            try testArgs(f32, 1e1, tmin(f32));
            try testArgs(f32, 1e1, fmin(f32));
            try testArgs(f32, 1e1, 1e-1);
            try testArgs(f32, 1e1, 1e0);
            try testArgs(f32, 1e1, 1e1);
            try testArgs(f32, 1e1, fmax(f32));
            try testArgs(f32, 1e1, inf(f32));
            try testArgs(f32, 1e1, nan(f32));

            try testArgs(f32, fmax(f32), -nan(f32));
            try testArgs(f32, fmax(f32), -inf(f32));
            try testArgs(f32, fmax(f32), -fmax(f32));
            try testArgs(f32, fmax(f32), -1e1);
            try testArgs(f32, fmax(f32), -1e0);
            try testArgs(f32, fmax(f32), -1e-1);
            try testArgs(f32, fmax(f32), -fmin(f32));
            try testArgs(f32, fmax(f32), -tmin(f32));
            try testArgs(f32, fmax(f32), -0.0);
            try testArgs(f32, fmax(f32), 0.0);
            try testArgs(f32, fmax(f32), tmin(f32));
            try testArgs(f32, fmax(f32), fmin(f32));
            try testArgs(f32, fmax(f32), 1e-1);
            try testArgs(f32, fmax(f32), 1e0);
            try testArgs(f32, fmax(f32), 1e1);
            try testArgs(f32, fmax(f32), fmax(f32));
            try testArgs(f32, fmax(f32), inf(f32));
            try testArgs(f32, fmax(f32), nan(f32));

            try testArgs(f32, inf(f32), -nan(f32));
            try testArgs(f32, inf(f32), -inf(f32));
            try testArgs(f32, inf(f32), -fmax(f32));
            try testArgs(f32, inf(f32), -1e1);
            try testArgs(f32, inf(f32), -1e0);
            try testArgs(f32, inf(f32), -1e-1);
            try testArgs(f32, inf(f32), -fmin(f32));
            try testArgs(f32, inf(f32), -tmin(f32));
            try testArgs(f32, inf(f32), -0.0);
            try testArgs(f32, inf(f32), 0.0);
            try testArgs(f32, inf(f32), tmin(f32));
            try testArgs(f32, inf(f32), fmin(f32));
            try testArgs(f32, inf(f32), 1e-1);
            try testArgs(f32, inf(f32), 1e0);
            try testArgs(f32, inf(f32), 1e1);
            try testArgs(f32, inf(f32), fmax(f32));
            try testArgs(f32, inf(f32), inf(f32));
            try testArgs(f32, inf(f32), nan(f32));

            try testArgs(f32, nan(f32), -nan(f32));
            try testArgs(f32, nan(f32), -inf(f32));
            try testArgs(f32, nan(f32), -fmax(f32));
            try testArgs(f32, nan(f32), -1e1);
            try testArgs(f32, nan(f32), -1e0);
            try testArgs(f32, nan(f32), -1e-1);
            try testArgs(f32, nan(f32), -fmin(f32));
            try testArgs(f32, nan(f32), -tmin(f32));
            try testArgs(f32, nan(f32), -0.0);
            try testArgs(f32, nan(f32), 0.0);
            try testArgs(f32, nan(f32), tmin(f32));
            try testArgs(f32, nan(f32), fmin(f32));
            try testArgs(f32, nan(f32), 1e-1);
            try testArgs(f32, nan(f32), 1e0);
            try testArgs(f32, nan(f32), 1e1);
            try testArgs(f32, nan(f32), fmax(f32));
            try testArgs(f32, nan(f32), inf(f32));
            try testArgs(f32, nan(f32), nan(f32));

            try testArgs(f64, -nan(f64), -nan(f64));
            try testArgs(f64, -nan(f64), -inf(f64));
            try testArgs(f64, -nan(f64), -fmax(f64));
            try testArgs(f64, -nan(f64), -1e1);
            try testArgs(f64, -nan(f64), -1e0);
            try testArgs(f64, -nan(f64), -1e-1);
            try testArgs(f64, -nan(f64), -fmin(f64));
            try testArgs(f64, -nan(f64), -tmin(f64));
            try testArgs(f64, -nan(f64), -0.0);
            try testArgs(f64, -nan(f64), 0.0);
            try testArgs(f64, -nan(f64), tmin(f64));
            try testArgs(f64, -nan(f64), fmin(f64));
            try testArgs(f64, -nan(f64), 1e-1);
            try testArgs(f64, -nan(f64), 1e0);
            try testArgs(f64, -nan(f64), 1e1);
            try testArgs(f64, -nan(f64), fmax(f64));
            try testArgs(f64, -nan(f64), inf(f64));
            try testArgs(f64, -nan(f64), nan(f64));

            try testArgs(f64, -inf(f64), -nan(f64));
            try testArgs(f64, -inf(f64), -inf(f64));
            try testArgs(f64, -inf(f64), -fmax(f64));
            try testArgs(f64, -inf(f64), -1e1);
            try testArgs(f64, -inf(f64), -1e0);
            try testArgs(f64, -inf(f64), -1e-1);
            try testArgs(f64, -inf(f64), -fmin(f64));
            try testArgs(f64, -inf(f64), -tmin(f64));
            try testArgs(f64, -inf(f64), -0.0);
            try testArgs(f64, -inf(f64), 0.0);
            try testArgs(f64, -inf(f64), tmin(f64));
            try testArgs(f64, -inf(f64), fmin(f64));
            try testArgs(f64, -inf(f64), 1e-1);
            try testArgs(f64, -inf(f64), 1e0);
            try testArgs(f64, -inf(f64), 1e1);
            try testArgs(f64, -inf(f64), fmax(f64));
            try testArgs(f64, -inf(f64), inf(f64));
            try testArgs(f64, -inf(f64), nan(f64));

            try testArgs(f64, -fmax(f64), -nan(f64));
            try testArgs(f64, -fmax(f64), -inf(f64));
            try testArgs(f64, -fmax(f64), -fmax(f64));
            try testArgs(f64, -fmax(f64), -1e1);
            try testArgs(f64, -fmax(f64), -1e0);
            try testArgs(f64, -fmax(f64), -1e-1);
            try testArgs(f64, -fmax(f64), -fmin(f64));
            try testArgs(f64, -fmax(f64), -tmin(f64));
            try testArgs(f64, -fmax(f64), -0.0);
            try testArgs(f64, -fmax(f64), 0.0);
            try testArgs(f64, -fmax(f64), tmin(f64));
            try testArgs(f64, -fmax(f64), fmin(f64));
            try testArgs(f64, -fmax(f64), 1e-1);
            try testArgs(f64, -fmax(f64), 1e0);
            try testArgs(f64, -fmax(f64), 1e1);
            try testArgs(f64, -fmax(f64), fmax(f64));
            try testArgs(f64, -fmax(f64), inf(f64));
            try testArgs(f64, -fmax(f64), nan(f64));

            try testArgs(f64, -1e1, -nan(f64));
            try testArgs(f64, -1e1, -inf(f64));
            try testArgs(f64, -1e1, -fmax(f64));
            try testArgs(f64, -1e1, -1e1);
            try testArgs(f64, -1e1, -1e0);
            try testArgs(f64, -1e1, -1e-1);
            try testArgs(f64, -1e1, -fmin(f64));
            try testArgs(f64, -1e1, -tmin(f64));
            try testArgs(f64, -1e1, -0.0);
            try testArgs(f64, -1e1, 0.0);
            try testArgs(f64, -1e1, tmin(f64));
            try testArgs(f64, -1e1, fmin(f64));
            try testArgs(f64, -1e1, 1e-1);
            try testArgs(f64, -1e1, 1e0);
            try testArgs(f64, -1e1, 1e1);
            try testArgs(f64, -1e1, fmax(f64));
            try testArgs(f64, -1e1, inf(f64));
            try testArgs(f64, -1e1, nan(f64));

            try testArgs(f64, -1e0, -nan(f64));
            try testArgs(f64, -1e0, -inf(f64));
            try testArgs(f64, -1e0, -fmax(f64));
            try testArgs(f64, -1e0, -1e1);
            try testArgs(f64, -1e0, -1e0);
            try testArgs(f64, -1e0, -1e-1);
            try testArgs(f64, -1e0, -fmin(f64));
            try testArgs(f64, -1e0, -tmin(f64));
            try testArgs(f64, -1e0, -0.0);
            try testArgs(f64, -1e0, 0.0);
            try testArgs(f64, -1e0, tmin(f64));
            try testArgs(f64, -1e0, fmin(f64));
            try testArgs(f64, -1e0, 1e-1);
            try testArgs(f64, -1e0, 1e0);
            try testArgs(f64, -1e0, 1e1);
            try testArgs(f64, -1e0, fmax(f64));
            try testArgs(f64, -1e0, inf(f64));
            try testArgs(f64, -1e0, nan(f64));

            try testArgs(f64, -1e-1, -nan(f64));
            try testArgs(f64, -1e-1, -inf(f64));
            try testArgs(f64, -1e-1, -fmax(f64));
            try testArgs(f64, -1e-1, -1e1);
            try testArgs(f64, -1e-1, -1e0);
            try testArgs(f64, -1e-1, -1e-1);
            try testArgs(f64, -1e-1, -fmin(f64));
            try testArgs(f64, -1e-1, -tmin(f64));
            try testArgs(f64, -1e-1, -0.0);
            try testArgs(f64, -1e-1, 0.0);
            try testArgs(f64, -1e-1, tmin(f64));
            try testArgs(f64, -1e-1, fmin(f64));
            try testArgs(f64, -1e-1, 1e-1);
            try testArgs(f64, -1e-1, 1e0);
            try testArgs(f64, -1e-1, 1e1);
            try testArgs(f64, -1e-1, fmax(f64));
            try testArgs(f64, -1e-1, inf(f64));
            try testArgs(f64, -1e-1, nan(f64));

            try testArgs(f64, -fmin(f64), -nan(f64));
            try testArgs(f64, -fmin(f64), -inf(f64));
            try testArgs(f64, -fmin(f64), -fmax(f64));
            try testArgs(f64, -fmin(f64), -1e1);
            try testArgs(f64, -fmin(f64), -1e0);
            try testArgs(f64, -fmin(f64), -1e-1);
            try testArgs(f64, -fmin(f64), -fmin(f64));
            try testArgs(f64, -fmin(f64), -tmin(f64));
            try testArgs(f64, -fmin(f64), -0.0);
            try testArgs(f64, -fmin(f64), 0.0);
            try testArgs(f64, -fmin(f64), tmin(f64));
            try testArgs(f64, -fmin(f64), fmin(f64));
            try testArgs(f64, -fmin(f64), 1e-1);
            try testArgs(f64, -fmin(f64), 1e0);
            try testArgs(f64, -fmin(f64), 1e1);
            try testArgs(f64, -fmin(f64), fmax(f64));
            try testArgs(f64, -fmin(f64), inf(f64));
            try testArgs(f64, -fmin(f64), nan(f64));

            try testArgs(f64, -tmin(f64), -nan(f64));
            try testArgs(f64, -tmin(f64), -inf(f64));
            try testArgs(f64, -tmin(f64), -fmax(f64));
            try testArgs(f64, -tmin(f64), -1e1);
            try testArgs(f64, -tmin(f64), -1e0);
            try testArgs(f64, -tmin(f64), -1e-1);
            try testArgs(f64, -tmin(f64), -fmin(f64));
            try testArgs(f64, -tmin(f64), -tmin(f64));
            try testArgs(f64, -tmin(f64), -0.0);
            try testArgs(f64, -tmin(f64), 0.0);
            try testArgs(f64, -tmin(f64), tmin(f64));
            try testArgs(f64, -tmin(f64), fmin(f64));
            try testArgs(f64, -tmin(f64), 1e-1);
            try testArgs(f64, -tmin(f64), 1e0);
            try testArgs(f64, -tmin(f64), 1e1);
            try testArgs(f64, -tmin(f64), fmax(f64));
            try testArgs(f64, -tmin(f64), inf(f64));
            try testArgs(f64, -tmin(f64), nan(f64));

            try testArgs(f64, -0.0, -nan(f64));
            try testArgs(f64, -0.0, -inf(f64));
            try testArgs(f64, -0.0, -fmax(f64));
            try testArgs(f64, -0.0, -1e1);
            try testArgs(f64, -0.0, -1e0);
            try testArgs(f64, -0.0, -1e-1);
            try testArgs(f64, -0.0, -fmin(f64));
            try testArgs(f64, -0.0, -tmin(f64));
            try testArgs(f64, -0.0, -0.0);
            try testArgs(f64, -0.0, 0.0);
            try testArgs(f64, -0.0, tmin(f64));
            try testArgs(f64, -0.0, fmin(f64));
            try testArgs(f64, -0.0, 1e-1);
            try testArgs(f64, -0.0, 1e0);
            try testArgs(f64, -0.0, 1e1);
            try testArgs(f64, -0.0, fmax(f64));
            try testArgs(f64, -0.0, inf(f64));
            try testArgs(f64, -0.0, nan(f64));

            try testArgs(f64, 0.0, -nan(f64));
            try testArgs(f64, 0.0, -inf(f64));
            try testArgs(f64, 0.0, -fmax(f64));
            try testArgs(f64, 0.0, -1e1);
            try testArgs(f64, 0.0, -1e0);
            try testArgs(f64, 0.0, -1e-1);
            try testArgs(f64, 0.0, -fmin(f64));
            try testArgs(f64, 0.0, -tmin(f64));
            try testArgs(f64, 0.0, -0.0);
            try testArgs(f64, 0.0, 0.0);
            try testArgs(f64, 0.0, tmin(f64));
            try testArgs(f64, 0.0, fmin(f64));
            try testArgs(f64, 0.0, 1e-1);
            try testArgs(f64, 0.0, 1e0);
            try testArgs(f64, 0.0, 1e1);
            try testArgs(f64, 0.0, fmax(f64));
            try testArgs(f64, 0.0, inf(f64));
            try testArgs(f64, 0.0, nan(f64));

            try testArgs(f64, tmin(f64), -nan(f64));
            try testArgs(f64, tmin(f64), -inf(f64));
            try testArgs(f64, tmin(f64), -fmax(f64));
            try testArgs(f64, tmin(f64), -1e1);
            try testArgs(f64, tmin(f64), -1e0);
            try testArgs(f64, tmin(f64), -1e-1);
            try testArgs(f64, tmin(f64), -fmin(f64));
            try testArgs(f64, tmin(f64), -tmin(f64));
            try testArgs(f64, tmin(f64), -0.0);
            try testArgs(f64, tmin(f64), 0.0);
            try testArgs(f64, tmin(f64), tmin(f64));
            try testArgs(f64, tmin(f64), fmin(f64));
            try testArgs(f64, tmin(f64), 1e-1);
            try testArgs(f64, tmin(f64), 1e0);
            try testArgs(f64, tmin(f64), 1e1);
            try testArgs(f64, tmin(f64), fmax(f64));
            try testArgs(f64, tmin(f64), inf(f64));
            try testArgs(f64, tmin(f64), nan(f64));

            try testArgs(f64, fmin(f64), -nan(f64));
            try testArgs(f64, fmin(f64), -inf(f64));
            try testArgs(f64, fmin(f64), -fmax(f64));
            try testArgs(f64, fmin(f64), -1e1);
            try testArgs(f64, fmin(f64), -1e0);
            try testArgs(f64, fmin(f64), -1e-1);
            try testArgs(f64, fmin(f64), -fmin(f64));
            try testArgs(f64, fmin(f64), -tmin(f64));
            try testArgs(f64, fmin(f64), -0.0);
            try testArgs(f64, fmin(f64), 0.0);
            try testArgs(f64, fmin(f64), tmin(f64));
            try testArgs(f64, fmin(f64), fmin(f64));
            try testArgs(f64, fmin(f64), 1e-1);
            try testArgs(f64, fmin(f64), 1e0);
            try testArgs(f64, fmin(f64), 1e1);
            try testArgs(f64, fmin(f64), fmax(f64));
            try testArgs(f64, fmin(f64), inf(f64));
            try testArgs(f64, fmin(f64), nan(f64));

            try testArgs(f64, 1e-1, -nan(f64));
            try testArgs(f64, 1e-1, -inf(f64));
            try testArgs(f64, 1e-1, -fmax(f64));
            try testArgs(f64, 1e-1, -1e1);
            try testArgs(f64, 1e-1, -1e0);
            try testArgs(f64, 1e-1, -1e-1);
            try testArgs(f64, 1e-1, -fmin(f64));
            try testArgs(f64, 1e-1, -tmin(f64));
            try testArgs(f64, 1e-1, -0.0);
            try testArgs(f64, 1e-1, 0.0);
            try testArgs(f64, 1e-1, tmin(f64));
            try testArgs(f64, 1e-1, fmin(f64));
            try testArgs(f64, 1e-1, 1e-1);
            try testArgs(f64, 1e-1, 1e0);
            try testArgs(f64, 1e-1, 1e1);
            try testArgs(f64, 1e-1, fmax(f64));
            try testArgs(f64, 1e-1, inf(f64));
            try testArgs(f64, 1e-1, nan(f64));

            try testArgs(f64, 1e0, -nan(f64));
            try testArgs(f64, 1e0, -inf(f64));
            try testArgs(f64, 1e0, -fmax(f64));
            try testArgs(f64, 1e0, -1e1);
            try testArgs(f64, 1e0, -1e0);
            try testArgs(f64, 1e0, -1e-1);
            try testArgs(f64, 1e0, -fmin(f64));
            try testArgs(f64, 1e0, -tmin(f64));
            try testArgs(f64, 1e0, -0.0);
            try testArgs(f64, 1e0, 0.0);
            try testArgs(f64, 1e0, tmin(f64));
            try testArgs(f64, 1e0, fmin(f64));
            try testArgs(f64, 1e0, 1e-1);
            try testArgs(f64, 1e0, 1e0);
            try testArgs(f64, 1e0, 1e1);
            try testArgs(f64, 1e0, fmax(f64));
            try testArgs(f64, 1e0, inf(f64));
            try testArgs(f64, 1e0, nan(f64));

            try testArgs(f64, 1e1, -nan(f64));
            try testArgs(f64, 1e1, -inf(f64));
            try testArgs(f64, 1e1, -fmax(f64));
            try testArgs(f64, 1e1, -1e1);
            try testArgs(f64, 1e1, -1e0);
            try testArgs(f64, 1e1, -1e-1);
            try testArgs(f64, 1e1, -fmin(f64));
            try testArgs(f64, 1e1, -tmin(f64));
            try testArgs(f64, 1e1, -0.0);
            try testArgs(f64, 1e1, 0.0);
            try testArgs(f64, 1e1, tmin(f64));
            try testArgs(f64, 1e1, fmin(f64));
            try testArgs(f64, 1e1, 1e-1);
            try testArgs(f64, 1e1, 1e0);
            try testArgs(f64, 1e1, 1e1);
            try testArgs(f64, 1e1, fmax(f64));
            try testArgs(f64, 1e1, inf(f64));
            try testArgs(f64, 1e1, nan(f64));

            try testArgs(f64, fmax(f64), -nan(f64));
            try testArgs(f64, fmax(f64), -inf(f64));
            try testArgs(f64, fmax(f64), -fmax(f64));
            try testArgs(f64, fmax(f64), -1e1);
            try testArgs(f64, fmax(f64), -1e0);
            try testArgs(f64, fmax(f64), -1e-1);
            try testArgs(f64, fmax(f64), -fmin(f64));
            try testArgs(f64, fmax(f64), -tmin(f64));
            try testArgs(f64, fmax(f64), -0.0);
            try testArgs(f64, fmax(f64), 0.0);
            try testArgs(f64, fmax(f64), tmin(f64));
            try testArgs(f64, fmax(f64), fmin(f64));
            try testArgs(f64, fmax(f64), 1e-1);
            try testArgs(f64, fmax(f64), 1e0);
            try testArgs(f64, fmax(f64), 1e1);
            try testArgs(f64, fmax(f64), fmax(f64));
            try testArgs(f64, fmax(f64), inf(f64));
            try testArgs(f64, fmax(f64), nan(f64));

            try testArgs(f64, inf(f64), -nan(f64));
            try testArgs(f64, inf(f64), -inf(f64));
            try testArgs(f64, inf(f64), -fmax(f64));
            try testArgs(f64, inf(f64), -1e1);
            try testArgs(f64, inf(f64), -1e0);
            try testArgs(f64, inf(f64), -1e-1);
            try testArgs(f64, inf(f64), -fmin(f64));
            try testArgs(f64, inf(f64), -tmin(f64));
            try testArgs(f64, inf(f64), -0.0);
            try testArgs(f64, inf(f64), 0.0);
            try testArgs(f64, inf(f64), tmin(f64));
            try testArgs(f64, inf(f64), fmin(f64));
            try testArgs(f64, inf(f64), 1e-1);
            try testArgs(f64, inf(f64), 1e0);
            try testArgs(f64, inf(f64), 1e1);
            try testArgs(f64, inf(f64), fmax(f64));
            try testArgs(f64, inf(f64), inf(f64));
            try testArgs(f64, inf(f64), nan(f64));

            try testArgs(f64, nan(f64), -nan(f64));
            try testArgs(f64, nan(f64), -inf(f64));
            try testArgs(f64, nan(f64), -fmax(f64));
            try testArgs(f64, nan(f64), -1e1);
            try testArgs(f64, nan(f64), -1e0);
            try testArgs(f64, nan(f64), -1e-1);
            try testArgs(f64, nan(f64), -fmin(f64));
            try testArgs(f64, nan(f64), -tmin(f64));
            try testArgs(f64, nan(f64), -0.0);
            try testArgs(f64, nan(f64), 0.0);
            try testArgs(f64, nan(f64), tmin(f64));
            try testArgs(f64, nan(f64), fmin(f64));
            try testArgs(f64, nan(f64), 1e-1);
            try testArgs(f64, nan(f64), 1e0);
            try testArgs(f64, nan(f64), 1e1);
            try testArgs(f64, nan(f64), fmax(f64));
            try testArgs(f64, nan(f64), inf(f64));
            try testArgs(f64, nan(f64), nan(f64));

            try testArgs(f80, -nan(f80), -nan(f80));
            try testArgs(f80, -nan(f80), -inf(f80));
            try testArgs(f80, -nan(f80), -fmax(f80));
            try testArgs(f80, -nan(f80), -1e1);
            try testArgs(f80, -nan(f80), -1e0);
            try testArgs(f80, -nan(f80), -1e-1);
            try testArgs(f80, -nan(f80), -fmin(f80));
            try testArgs(f80, -nan(f80), -tmin(f80));
            try testArgs(f80, -nan(f80), -0.0);
            try testArgs(f80, -nan(f80), 0.0);
            try testArgs(f80, -nan(f80), tmin(f80));
            try testArgs(f80, -nan(f80), fmin(f80));
            try testArgs(f80, -nan(f80), 1e-1);
            try testArgs(f80, -nan(f80), 1e0);
            try testArgs(f80, -nan(f80), 1e1);
            try testArgs(f80, -nan(f80), fmax(f80));
            try testArgs(f80, -nan(f80), inf(f80));
            try testArgs(f80, -nan(f80), nan(f80));

            try testArgs(f80, -inf(f80), -nan(f80));
            try testArgs(f80, -inf(f80), -inf(f80));
            try testArgs(f80, -inf(f80), -fmax(f80));
            try testArgs(f80, -inf(f80), -1e1);
            try testArgs(f80, -inf(f80), -1e0);
            try testArgs(f80, -inf(f80), -1e-1);
            try testArgs(f80, -inf(f80), -fmin(f80));
            try testArgs(f80, -inf(f80), -tmin(f80));
            try testArgs(f80, -inf(f80), -0.0);
            try testArgs(f80, -inf(f80), 0.0);
            try testArgs(f80, -inf(f80), tmin(f80));
            try testArgs(f80, -inf(f80), fmin(f80));
            try testArgs(f80, -inf(f80), 1e-1);
            try testArgs(f80, -inf(f80), 1e0);
            try testArgs(f80, -inf(f80), 1e1);
            try testArgs(f80, -inf(f80), fmax(f80));
            try testArgs(f80, -inf(f80), inf(f80));
            try testArgs(f80, -inf(f80), nan(f80));

            try testArgs(f80, -fmax(f80), -nan(f80));
            try testArgs(f80, -fmax(f80), -inf(f80));
            try testArgs(f80, -fmax(f80), -fmax(f80));
            try testArgs(f80, -fmax(f80), -1e1);
            try testArgs(f80, -fmax(f80), -1e0);
            try testArgs(f80, -fmax(f80), -1e-1);
            try testArgs(f80, -fmax(f80), -fmin(f80));
            try testArgs(f80, -fmax(f80), -tmin(f80));
            try testArgs(f80, -fmax(f80), -0.0);
            try testArgs(f80, -fmax(f80), 0.0);
            try testArgs(f80, -fmax(f80), tmin(f80));
            try testArgs(f80, -fmax(f80), fmin(f80));
            try testArgs(f80, -fmax(f80), 1e-1);
            try testArgs(f80, -fmax(f80), 1e0);
            try testArgs(f80, -fmax(f80), 1e1);
            try testArgs(f80, -fmax(f80), fmax(f80));
            try testArgs(f80, -fmax(f80), inf(f80));
            try testArgs(f80, -fmax(f80), nan(f80));

            try testArgs(f80, -1e1, -nan(f80));
            try testArgs(f80, -1e1, -inf(f80));
            try testArgs(f80, -1e1, -fmax(f80));
            try testArgs(f80, -1e1, -1e1);
            try testArgs(f80, -1e1, -1e0);
            try testArgs(f80, -1e1, -1e-1);
            try testArgs(f80, -1e1, -fmin(f80));
            try testArgs(f80, -1e1, -tmin(f80));
            try testArgs(f80, -1e1, -0.0);
            try testArgs(f80, -1e1, 0.0);
            try testArgs(f80, -1e1, tmin(f80));
            try testArgs(f80, -1e1, fmin(f80));
            try testArgs(f80, -1e1, 1e-1);
            try testArgs(f80, -1e1, 1e0);
            try testArgs(f80, -1e1, 1e1);
            try testArgs(f80, -1e1, fmax(f80));
            try testArgs(f80, -1e1, inf(f80));
            try testArgs(f80, -1e1, nan(f80));

            try testArgs(f80, -1e0, -nan(f80));
            try testArgs(f80, -1e0, -inf(f80));
            try testArgs(f80, -1e0, -fmax(f80));
            try testArgs(f80, -1e0, -1e1);
            try testArgs(f80, -1e0, -1e0);
            try testArgs(f80, -1e0, -1e-1);
            try testArgs(f80, -1e0, -fmin(f80));
            try testArgs(f80, -1e0, -tmin(f80));
            try testArgs(f80, -1e0, -0.0);
            try testArgs(f80, -1e0, 0.0);
            try testArgs(f80, -1e0, tmin(f80));
            try testArgs(f80, -1e0, fmin(f80));
            try testArgs(f80, -1e0, 1e-1);
            try testArgs(f80, -1e0, 1e0);
            try testArgs(f80, -1e0, 1e1);
            try testArgs(f80, -1e0, fmax(f80));
            try testArgs(f80, -1e0, inf(f80));
            try testArgs(f80, -1e0, nan(f80));

            try testArgs(f80, -1e-1, -nan(f80));
            try testArgs(f80, -1e-1, -inf(f80));
            try testArgs(f80, -1e-1, -fmax(f80));
            try testArgs(f80, -1e-1, -1e1);
            try testArgs(f80, -1e-1, -1e0);
            try testArgs(f80, -1e-1, -1e-1);
            try testArgs(f80, -1e-1, -fmin(f80));
            try testArgs(f80, -1e-1, -tmin(f80));
            try testArgs(f80, -1e-1, -0.0);
            try testArgs(f80, -1e-1, 0.0);
            try testArgs(f80, -1e-1, tmin(f80));
            try testArgs(f80, -1e-1, fmin(f80));
            try testArgs(f80, -1e-1, 1e-1);
            try testArgs(f80, -1e-1, 1e0);
            try testArgs(f80, -1e-1, 1e1);
            try testArgs(f80, -1e-1, fmax(f80));
            try testArgs(f80, -1e-1, inf(f80));
            try testArgs(f80, -1e-1, nan(f80));

            try testArgs(f80, -fmin(f80), -nan(f80));
            try testArgs(f80, -fmin(f80), -inf(f80));
            try testArgs(f80, -fmin(f80), -fmax(f80));
            try testArgs(f80, -fmin(f80), -1e1);
            try testArgs(f80, -fmin(f80), -1e0);
            try testArgs(f80, -fmin(f80), -1e-1);
            try testArgs(f80, -fmin(f80), -fmin(f80));
            try testArgs(f80, -fmin(f80), -tmin(f80));
            try testArgs(f80, -fmin(f80), -0.0);
            try testArgs(f80, -fmin(f80), 0.0);
            try testArgs(f80, -fmin(f80), tmin(f80));
            try testArgs(f80, -fmin(f80), fmin(f80));
            try testArgs(f80, -fmin(f80), 1e-1);
            try testArgs(f80, -fmin(f80), 1e0);
            try testArgs(f80, -fmin(f80), 1e1);
            try testArgs(f80, -fmin(f80), fmax(f80));
            try testArgs(f80, -fmin(f80), inf(f80));
            try testArgs(f80, -fmin(f80), nan(f80));

            try testArgs(f80, -tmin(f80), -nan(f80));
            try testArgs(f80, -tmin(f80), -inf(f80));
            try testArgs(f80, -tmin(f80), -fmax(f80));
            try testArgs(f80, -tmin(f80), -1e1);
            try testArgs(f80, -tmin(f80), -1e0);
            try testArgs(f80, -tmin(f80), -1e-1);
            try testArgs(f80, -tmin(f80), -fmin(f80));
            try testArgs(f80, -tmin(f80), -tmin(f80));
            try testArgs(f80, -tmin(f80), -0.0);
            try testArgs(f80, -tmin(f80), 0.0);
            try testArgs(f80, -tmin(f80), tmin(f80));
            try testArgs(f80, -tmin(f80), fmin(f80));
            try testArgs(f80, -tmin(f80), 1e-1);
            try testArgs(f80, -tmin(f80), 1e0);
            try testArgs(f80, -tmin(f80), 1e1);
            try testArgs(f80, -tmin(f80), fmax(f80));
            try testArgs(f80, -tmin(f80), inf(f80));
            try testArgs(f80, -tmin(f80), nan(f80));

            try testArgs(f80, -0.0, -nan(f80));
            try testArgs(f80, -0.0, -inf(f80));
            try testArgs(f80, -0.0, -fmax(f80));
            try testArgs(f80, -0.0, -1e1);
            try testArgs(f80, -0.0, -1e0);
            try testArgs(f80, -0.0, -1e-1);
            try testArgs(f80, -0.0, -fmin(f80));
            try testArgs(f80, -0.0, -tmin(f80));
            try testArgs(f80, -0.0, -0.0);
            try testArgs(f80, -0.0, 0.0);
            try testArgs(f80, -0.0, tmin(f80));
            try testArgs(f80, -0.0, fmin(f80));
            try testArgs(f80, -0.0, 1e-1);
            try testArgs(f80, -0.0, 1e0);
            try testArgs(f80, -0.0, 1e1);
            try testArgs(f80, -0.0, fmax(f80));
            try testArgs(f80, -0.0, inf(f80));
            try testArgs(f80, -0.0, nan(f80));

            try testArgs(f80, 0.0, -nan(f80));
            try testArgs(f80, 0.0, -inf(f80));
            try testArgs(f80, 0.0, -fmax(f80));
            try testArgs(f80, 0.0, -1e1);
            try testArgs(f80, 0.0, -1e0);
            try testArgs(f80, 0.0, -1e-1);
            try testArgs(f80, 0.0, -fmin(f80));
            try testArgs(f80, 0.0, -tmin(f80));
            try testArgs(f80, 0.0, -0.0);
            try testArgs(f80, 0.0, 0.0);
            try testArgs(f80, 0.0, tmin(f80));
            try testArgs(f80, 0.0, fmin(f80));
            try testArgs(f80, 0.0, 1e-1);
            try testArgs(f80, 0.0, 1e0);
            try testArgs(f80, 0.0, 1e1);
            try testArgs(f80, 0.0, fmax(f80));
            try testArgs(f80, 0.0, inf(f80));
            try testArgs(f80, 0.0, nan(f80));

            try testArgs(f80, tmin(f80), -nan(f80));
            try testArgs(f80, tmin(f80), -inf(f80));
            try testArgs(f80, tmin(f80), -fmax(f80));
            try testArgs(f80, tmin(f80), -1e1);
            try testArgs(f80, tmin(f80), -1e0);
            try testArgs(f80, tmin(f80), -1e-1);
            try testArgs(f80, tmin(f80), -fmin(f80));
            try testArgs(f80, tmin(f80), -tmin(f80));
            try testArgs(f80, tmin(f80), -0.0);
            try testArgs(f80, tmin(f80), 0.0);
            try testArgs(f80, tmin(f80), tmin(f80));
            try testArgs(f80, tmin(f80), fmin(f80));
            try testArgs(f80, tmin(f80), 1e-1);
            try testArgs(f80, tmin(f80), 1e0);
            try testArgs(f80, tmin(f80), 1e1);
            try testArgs(f80, tmin(f80), fmax(f80));
            try testArgs(f80, tmin(f80), inf(f80));
            try testArgs(f80, tmin(f80), nan(f80));

            try testArgs(f80, fmin(f80), -nan(f80));
            try testArgs(f80, fmin(f80), -inf(f80));
            try testArgs(f80, fmin(f80), -fmax(f80));
            try testArgs(f80, fmin(f80), -1e1);
            try testArgs(f80, fmin(f80), -1e0);
            try testArgs(f80, fmin(f80), -1e-1);
            try testArgs(f80, fmin(f80), -fmin(f80));
            try testArgs(f80, fmin(f80), -tmin(f80));
            try testArgs(f80, fmin(f80), -0.0);
            try testArgs(f80, fmin(f80), 0.0);
            try testArgs(f80, fmin(f80), tmin(f80));
            try testArgs(f80, fmin(f80), fmin(f80));
            try testArgs(f80, fmin(f80), 1e-1);
            try testArgs(f80, fmin(f80), 1e0);
            try testArgs(f80, fmin(f80), 1e1);
            try testArgs(f80, fmin(f80), fmax(f80));
            try testArgs(f80, fmin(f80), inf(f80));
            try testArgs(f80, fmin(f80), nan(f80));

            try testArgs(f80, 1e-1, -nan(f80));
            try testArgs(f80, 1e-1, -inf(f80));
            try testArgs(f80, 1e-1, -fmax(f80));
            try testArgs(f80, 1e-1, -1e1);
            try testArgs(f80, 1e-1, -1e0);
            try testArgs(f80, 1e-1, -1e-1);
            try testArgs(f80, 1e-1, -fmin(f80));
            try testArgs(f80, 1e-1, -tmin(f80));
            try testArgs(f80, 1e-1, -0.0);
            try testArgs(f80, 1e-1, 0.0);
            try testArgs(f80, 1e-1, tmin(f80));
            try testArgs(f80, 1e-1, fmin(f80));
            try testArgs(f80, 1e-1, 1e-1);
            try testArgs(f80, 1e-1, 1e0);
            try testArgs(f80, 1e-1, 1e1);
            try testArgs(f80, 1e-1, fmax(f80));
            try testArgs(f80, 1e-1, inf(f80));
            try testArgs(f80, 1e-1, nan(f80));

            try testArgs(f80, 1e0, -nan(f80));
            try testArgs(f80, 1e0, -inf(f80));
            try testArgs(f80, 1e0, -fmax(f80));
            try testArgs(f80, 1e0, -1e1);
            try testArgs(f80, 1e0, -1e0);
            try testArgs(f80, 1e0, -1e-1);
            try testArgs(f80, 1e0, -fmin(f80));
            try testArgs(f80, 1e0, -tmin(f80));
            try testArgs(f80, 1e0, -0.0);
            try testArgs(f80, 1e0, 0.0);
            try testArgs(f80, 1e0, tmin(f80));
            try testArgs(f80, 1e0, fmin(f80));
            try testArgs(f80, 1e0, 1e-1);
            try testArgs(f80, 1e0, 1e0);
            try testArgs(f80, 1e0, 1e1);
            try testArgs(f80, 1e0, fmax(f80));
            try testArgs(f80, 1e0, inf(f80));
            try testArgs(f80, 1e0, nan(f80));

            try testArgs(f80, 1e1, -nan(f80));
            try testArgs(f80, 1e1, -inf(f80));
            try testArgs(f80, 1e1, -fmax(f80));
            try testArgs(f80, 1e1, -1e1);
            try testArgs(f80, 1e1, -1e0);
            try testArgs(f80, 1e1, -1e-1);
            try testArgs(f80, 1e1, -fmin(f80));
            try testArgs(f80, 1e1, -tmin(f80));
            try testArgs(f80, 1e1, -0.0);
            try testArgs(f80, 1e1, 0.0);
            try testArgs(f80, 1e1, tmin(f80));
            try testArgs(f80, 1e1, fmin(f80));
            try testArgs(f80, 1e1, 1e-1);
            try testArgs(f80, 1e1, 1e0);
            try testArgs(f80, 1e1, 1e1);
            try testArgs(f80, 1e1, fmax(f80));
            try testArgs(f80, 1e1, inf(f80));
            try testArgs(f80, 1e1, nan(f80));

            try testArgs(f80, fmax(f80), -nan(f80));
            try testArgs(f80, fmax(f80), -inf(f80));
            try testArgs(f80, fmax(f80), -fmax(f80));
            try testArgs(f80, fmax(f80), -1e1);
            try testArgs(f80, fmax(f80), -1e0);
            try testArgs(f80, fmax(f80), -1e-1);
            try testArgs(f80, fmax(f80), -fmin(f80));
            try testArgs(f80, fmax(f80), -tmin(f80));
            try testArgs(f80, fmax(f80), -0.0);
            try testArgs(f80, fmax(f80), 0.0);
            try testArgs(f80, fmax(f80), tmin(f80));
            try testArgs(f80, fmax(f80), fmin(f80));
            try testArgs(f80, fmax(f80), 1e-1);
            try testArgs(f80, fmax(f80), 1e0);
            try testArgs(f80, fmax(f80), 1e1);
            try testArgs(f80, fmax(f80), fmax(f80));
            try testArgs(f80, fmax(f80), inf(f80));
            try testArgs(f80, fmax(f80), nan(f80));

            try testArgs(f80, inf(f80), -nan(f80));
            try testArgs(f80, inf(f80), -inf(f80));
            try testArgs(f80, inf(f80), -fmax(f80));
            try testArgs(f80, inf(f80), -1e1);
            try testArgs(f80, inf(f80), -1e0);
            try testArgs(f80, inf(f80), -1e-1);
            try testArgs(f80, inf(f80), -fmin(f80));
            try testArgs(f80, inf(f80), -tmin(f80));
            try testArgs(f80, inf(f80), -0.0);
            try testArgs(f80, inf(f80), 0.0);
            try testArgs(f80, inf(f80), tmin(f80));
            try testArgs(f80, inf(f80), fmin(f80));
            try testArgs(f80, inf(f80), 1e-1);
            try testArgs(f80, inf(f80), 1e0);
            try testArgs(f80, inf(f80), 1e1);
            try testArgs(f80, inf(f80), fmax(f80));
            try testArgs(f80, inf(f80), inf(f80));
            try testArgs(f80, inf(f80), nan(f80));

            try testArgs(f80, nan(f80), -nan(f80));
            try testArgs(f80, nan(f80), -inf(f80));
            try testArgs(f80, nan(f80), -fmax(f80));
            try testArgs(f80, nan(f80), -1e1);
            try testArgs(f80, nan(f80), -1e0);
            try testArgs(f80, nan(f80), -1e-1);
            try testArgs(f80, nan(f80), -fmin(f80));
            try testArgs(f80, nan(f80), -tmin(f80));
            try testArgs(f80, nan(f80), -0.0);
            try testArgs(f80, nan(f80), 0.0);
            try testArgs(f80, nan(f80), tmin(f80));
            try testArgs(f80, nan(f80), fmin(f80));
            try testArgs(f80, nan(f80), 1e-1);
            try testArgs(f80, nan(f80), 1e0);
            try testArgs(f80, nan(f80), 1e1);
            try testArgs(f80, nan(f80), fmax(f80));
            try testArgs(f80, nan(f80), inf(f80));
            try testArgs(f80, nan(f80), nan(f80));

            try testArgs(f128, -nan(f128), -nan(f128));
            try testArgs(f128, -nan(f128), -inf(f128));
            try testArgs(f128, -nan(f128), -fmax(f128));
            try testArgs(f128, -nan(f128), -1e1);
            try testArgs(f128, -nan(f128), -1e0);
            try testArgs(f128, -nan(f128), -1e-1);
            try testArgs(f128, -nan(f128), -fmin(f128));
            try testArgs(f128, -nan(f128), -tmin(f128));
            try testArgs(f128, -nan(f128), -0.0);
            try testArgs(f128, -nan(f128), 0.0);
            try testArgs(f128, -nan(f128), tmin(f128));
            try testArgs(f128, -nan(f128), fmin(f128));
            try testArgs(f128, -nan(f128), 1e-1);
            try testArgs(f128, -nan(f128), 1e0);
            try testArgs(f128, -nan(f128), 1e1);
            try testArgs(f128, -nan(f128), fmax(f128));
            try testArgs(f128, -nan(f128), inf(f128));
            try testArgs(f128, -nan(f128), nan(f128));

            try testArgs(f128, -inf(f128), -nan(f128));
            try testArgs(f128, -inf(f128), -inf(f128));
            try testArgs(f128, -inf(f128), -fmax(f128));
            try testArgs(f128, -inf(f128), -1e1);
            try testArgs(f128, -inf(f128), -1e0);
            try testArgs(f128, -inf(f128), -1e-1);
            try testArgs(f128, -inf(f128), -fmin(f128));
            try testArgs(f128, -inf(f128), -tmin(f128));
            try testArgs(f128, -inf(f128), -0.0);
            try testArgs(f128, -inf(f128), 0.0);
            try testArgs(f128, -inf(f128), tmin(f128));
            try testArgs(f128, -inf(f128), fmin(f128));
            try testArgs(f128, -inf(f128), 1e-1);
            try testArgs(f128, -inf(f128), 1e0);
            try testArgs(f128, -inf(f128), 1e1);
            try testArgs(f128, -inf(f128), fmax(f128));
            try testArgs(f128, -inf(f128), inf(f128));
            try testArgs(f128, -inf(f128), nan(f128));

            try testArgs(f128, -fmax(f128), -nan(f128));
            try testArgs(f128, -fmax(f128), -inf(f128));
            try testArgs(f128, -fmax(f128), -fmax(f128));
            try testArgs(f128, -fmax(f128), -1e1);
            try testArgs(f128, -fmax(f128), -1e0);
            try testArgs(f128, -fmax(f128), -1e-1);
            try testArgs(f128, -fmax(f128), -fmin(f128));
            try testArgs(f128, -fmax(f128), -tmin(f128));
            try testArgs(f128, -fmax(f128), -0.0);
            try testArgs(f128, -fmax(f128), 0.0);
            try testArgs(f128, -fmax(f128), tmin(f128));
            try testArgs(f128, -fmax(f128), fmin(f128));
            try testArgs(f128, -fmax(f128), 1e-1);
            try testArgs(f128, -fmax(f128), 1e0);
            try testArgs(f128, -fmax(f128), 1e1);
            try testArgs(f128, -fmax(f128), fmax(f128));
            try testArgs(f128, -fmax(f128), inf(f128));
            try testArgs(f128, -fmax(f128), nan(f128));

            try testArgs(f128, -1e1, -nan(f128));
            try testArgs(f128, -1e1, -inf(f128));
            try testArgs(f128, -1e1, -fmax(f128));
            try testArgs(f128, -1e1, -1e1);
            try testArgs(f128, -1e1, -1e0);
            try testArgs(f128, -1e1, -1e-1);
            try testArgs(f128, -1e1, -fmin(f128));
            try testArgs(f128, -1e1, -tmin(f128));
            try testArgs(f128, -1e1, -0.0);
            try testArgs(f128, -1e1, 0.0);
            try testArgs(f128, -1e1, tmin(f128));
            try testArgs(f128, -1e1, fmin(f128));
            try testArgs(f128, -1e1, 1e-1);
            try testArgs(f128, -1e1, 1e0);
            try testArgs(f128, -1e1, 1e1);
            try testArgs(f128, -1e1, fmax(f128));
            try testArgs(f128, -1e1, inf(f128));
            try testArgs(f128, -1e1, nan(f128));

            try testArgs(f128, -1e0, -nan(f128));
            try testArgs(f128, -1e0, -inf(f128));
            try testArgs(f128, -1e0, -fmax(f128));
            try testArgs(f128, -1e0, -1e1);
            try testArgs(f128, -1e0, -1e0);
            try testArgs(f128, -1e0, -1e-1);
            try testArgs(f128, -1e0, -fmin(f128));
            try testArgs(f128, -1e0, -tmin(f128));
            try testArgs(f128, -1e0, -0.0);
            try testArgs(f128, -1e0, 0.0);
            try testArgs(f128, -1e0, tmin(f128));
            try testArgs(f128, -1e0, fmin(f128));
            try testArgs(f128, -1e0, 1e-1);
            try testArgs(f128, -1e0, 1e0);
            try testArgs(f128, -1e0, 1e1);
            try testArgs(f128, -1e0, fmax(f128));
            try testArgs(f128, -1e0, inf(f128));
            try testArgs(f128, -1e0, nan(f128));

            try testArgs(f128, -1e-1, -nan(f128));
            try testArgs(f128, -1e-1, -inf(f128));
            try testArgs(f128, -1e-1, -fmax(f128));
            try testArgs(f128, -1e-1, -1e1);
            try testArgs(f128, -1e-1, -1e0);
            try testArgs(f128, -1e-1, -1e-1);
            try testArgs(f128, -1e-1, -fmin(f128));
            try testArgs(f128, -1e-1, -tmin(f128));
            try testArgs(f128, -1e-1, -0.0);
            try testArgs(f128, -1e-1, 0.0);
            try testArgs(f128, -1e-1, tmin(f128));
            try testArgs(f128, -1e-1, fmin(f128));
            try testArgs(f128, -1e-1, 1e-1);
            try testArgs(f128, -1e-1, 1e0);
            try testArgs(f128, -1e-1, 1e1);
            try testArgs(f128, -1e-1, fmax(f128));
            try testArgs(f128, -1e-1, inf(f128));
            try testArgs(f128, -1e-1, nan(f128));

            try testArgs(f128, -fmin(f128), -nan(f128));
            try testArgs(f128, -fmin(f128), -inf(f128));
            try testArgs(f128, -fmin(f128), -fmax(f128));
            try testArgs(f128, -fmin(f128), -1e1);
            try testArgs(f128, -fmin(f128), -1e0);
            try testArgs(f128, -fmin(f128), -1e-1);
            try testArgs(f128, -fmin(f128), -fmin(f128));
            try testArgs(f128, -fmin(f128), -tmin(f128));
            try testArgs(f128, -fmin(f128), -0.0);
            try testArgs(f128, -fmin(f128), 0.0);
            try testArgs(f128, -fmin(f128), tmin(f128));
            try testArgs(f128, -fmin(f128), fmin(f128));
            try testArgs(f128, -fmin(f128), 1e-1);
            try testArgs(f128, -fmin(f128), 1e0);
            try testArgs(f128, -fmin(f128), 1e1);
            try testArgs(f128, -fmin(f128), fmax(f128));
            try testArgs(f128, -fmin(f128), inf(f128));
            try testArgs(f128, -fmin(f128), nan(f128));

            try testArgs(f128, -tmin(f128), -nan(f128));
            try testArgs(f128, -tmin(f128), -inf(f128));
            try testArgs(f128, -tmin(f128), -fmax(f128));
            try testArgs(f128, -tmin(f128), -1e1);
            try testArgs(f128, -tmin(f128), -1e0);
            try testArgs(f128, -tmin(f128), -1e-1);
            try testArgs(f128, -tmin(f128), -fmin(f128));
            try testArgs(f128, -tmin(f128), -tmin(f128));
            try testArgs(f128, -tmin(f128), -0.0);
            try testArgs(f128, -tmin(f128), 0.0);
            try testArgs(f128, -tmin(f128), tmin(f128));
            try testArgs(f128, -tmin(f128), fmin(f128));
            try testArgs(f128, -tmin(f128), 1e-1);
            try testArgs(f128, -tmin(f128), 1e0);
            try testArgs(f128, -tmin(f128), 1e1);
            try testArgs(f128, -tmin(f128), fmax(f128));
            try testArgs(f128, -tmin(f128), inf(f128));
            try testArgs(f128, -tmin(f128), nan(f128));

            try testArgs(f128, -0.0, -nan(f128));
            try testArgs(f128, -0.0, -inf(f128));
            try testArgs(f128, -0.0, -fmax(f128));
            try testArgs(f128, -0.0, -1e1);
            try testArgs(f128, -0.0, -1e0);
            try testArgs(f128, -0.0, -1e-1);
            try testArgs(f128, -0.0, -fmin(f128));
            try testArgs(f128, -0.0, -tmin(f128));
            try testArgs(f128, -0.0, -0.0);
            try testArgs(f128, -0.0, 0.0);
            try testArgs(f128, -0.0, tmin(f128));
            try testArgs(f128, -0.0, fmin(f128));
            try testArgs(f128, -0.0, 1e-1);
            try testArgs(f128, -0.0, 1e0);
            try testArgs(f128, -0.0, 1e1);
            try testArgs(f128, -0.0, fmax(f128));
            try testArgs(f128, -0.0, inf(f128));
            try testArgs(f128, -0.0, nan(f128));

            try testArgs(f128, 0.0, -nan(f128));
            try testArgs(f128, 0.0, -inf(f128));
            try testArgs(f128, 0.0, -fmax(f128));
            try testArgs(f128, 0.0, -1e1);
            try testArgs(f128, 0.0, -1e0);
            try testArgs(f128, 0.0, -1e-1);
            try testArgs(f128, 0.0, -fmin(f128));
            try testArgs(f128, 0.0, -tmin(f128));
            try testArgs(f128, 0.0, -0.0);
            try testArgs(f128, 0.0, 0.0);
            try testArgs(f128, 0.0, tmin(f128));
            try testArgs(f128, 0.0, fmin(f128));
            try testArgs(f128, 0.0, 1e-1);
            try testArgs(f128, 0.0, 1e0);
            try testArgs(f128, 0.0, 1e1);
            try testArgs(f128, 0.0, fmax(f128));
            try testArgs(f128, 0.0, inf(f128));
            try testArgs(f128, 0.0, nan(f128));

            try testArgs(f128, tmin(f128), -nan(f128));
            try testArgs(f128, tmin(f128), -inf(f128));
            try testArgs(f128, tmin(f128), -fmax(f128));
            try testArgs(f128, tmin(f128), -1e1);
            try testArgs(f128, tmin(f128), -1e0);
            try testArgs(f128, tmin(f128), -1e-1);
            try testArgs(f128, tmin(f128), -fmin(f128));
            try testArgs(f128, tmin(f128), -tmin(f128));
            try testArgs(f128, tmin(f128), -0.0);
            try testArgs(f128, tmin(f128), 0.0);
            try testArgs(f128, tmin(f128), tmin(f128));
            try testArgs(f128, tmin(f128), fmin(f128));
            try testArgs(f128, tmin(f128), 1e-1);
            try testArgs(f128, tmin(f128), 1e0);
            try testArgs(f128, tmin(f128), 1e1);
            try testArgs(f128, tmin(f128), fmax(f128));
            try testArgs(f128, tmin(f128), inf(f128));
            try testArgs(f128, tmin(f128), nan(f128));

            try testArgs(f128, fmin(f128), -nan(f128));
            try testArgs(f128, fmin(f128), -inf(f128));
            try testArgs(f128, fmin(f128), -fmax(f128));
            try testArgs(f128, fmin(f128), -1e1);
            try testArgs(f128, fmin(f128), -1e0);
            try testArgs(f128, fmin(f128), -1e-1);
            try testArgs(f128, fmin(f128), -fmin(f128));
            try testArgs(f128, fmin(f128), -tmin(f128));
            try testArgs(f128, fmin(f128), -0.0);
            try testArgs(f128, fmin(f128), 0.0);
            try testArgs(f128, fmin(f128), tmin(f128));
            try testArgs(f128, fmin(f128), fmin(f128));
            try testArgs(f128, fmin(f128), 1e-1);
            try testArgs(f128, fmin(f128), 1e0);
            try testArgs(f128, fmin(f128), 1e1);
            try testArgs(f128, fmin(f128), fmax(f128));
            try testArgs(f128, fmin(f128), inf(f128));
            try testArgs(f128, fmin(f128), nan(f128));

            try testArgs(f128, 1e-1, -nan(f128));
            try testArgs(f128, 1e-1, -inf(f128));
            try testArgs(f128, 1e-1, -fmax(f128));
            try testArgs(f128, 1e-1, -1e1);
            try testArgs(f128, 1e-1, -1e0);
            try testArgs(f128, 1e-1, -1e-1);
            try testArgs(f128, 1e-1, -fmin(f128));
            try testArgs(f128, 1e-1, -tmin(f128));
            try testArgs(f128, 1e-1, -0.0);
            try testArgs(f128, 1e-1, 0.0);
            try testArgs(f128, 1e-1, tmin(f128));
            try testArgs(f128, 1e-1, fmin(f128));
            try testArgs(f128, 1e-1, 1e-1);
            try testArgs(f128, 1e-1, 1e0);
            try testArgs(f128, 1e-1, 1e1);
            try testArgs(f128, 1e-1, fmax(f128));
            try testArgs(f128, 1e-1, inf(f128));
            try testArgs(f128, 1e-1, nan(f128));

            try testArgs(f128, 1e0, -nan(f128));
            try testArgs(f128, 1e0, -inf(f128));
            try testArgs(f128, 1e0, -fmax(f128));
            try testArgs(f128, 1e0, -1e1);
            try testArgs(f128, 1e0, -1e0);
            try testArgs(f128, 1e0, -1e-1);
            try testArgs(f128, 1e0, -fmin(f128));
            try testArgs(f128, 1e0, -tmin(f128));
            try testArgs(f128, 1e0, -0.0);
            try testArgs(f128, 1e0, 0.0);
            try testArgs(f128, 1e0, tmin(f128));
            try testArgs(f128, 1e0, fmin(f128));
            try testArgs(f128, 1e0, 1e-1);
            try testArgs(f128, 1e0, 1e0);
            try testArgs(f128, 1e0, 1e1);
            try testArgs(f128, 1e0, fmax(f128));
            try testArgs(f128, 1e0, inf(f128));
            try testArgs(f128, 1e0, nan(f128));

            try testArgs(f128, 1e1, -nan(f128));
            try testArgs(f128, 1e1, -inf(f128));
            try testArgs(f128, 1e1, -fmax(f128));
            try testArgs(f128, 1e1, -1e1);
            try testArgs(f128, 1e1, -1e0);
            try testArgs(f128, 1e1, -1e-1);
            try testArgs(f128, 1e1, -fmin(f128));
            try testArgs(f128, 1e1, -tmin(f128));
            try testArgs(f128, 1e1, -0.0);
            try testArgs(f128, 1e1, 0.0);
            try testArgs(f128, 1e1, tmin(f128));
            try testArgs(f128, 1e1, fmin(f128));
            try testArgs(f128, 1e1, 1e-1);
            try testArgs(f128, 1e1, 1e0);
            try testArgs(f128, 1e1, 1e1);
            try testArgs(f128, 1e1, fmax(f128));
            try testArgs(f128, 1e1, inf(f128));
            try testArgs(f128, 1e1, nan(f128));

            try testArgs(f128, fmax(f128), -nan(f128));
            try testArgs(f128, fmax(f128), -inf(f128));
            try testArgs(f128, fmax(f128), -fmax(f128));
            try testArgs(f128, fmax(f128), -1e1);
            try testArgs(f128, fmax(f128), -1e0);
            try testArgs(f128, fmax(f128), -1e-1);
            try testArgs(f128, fmax(f128), -fmin(f128));
            try testArgs(f128, fmax(f128), -tmin(f128));
            try testArgs(f128, fmax(f128), -0.0);
            try testArgs(f128, fmax(f128), 0.0);
            try testArgs(f128, fmax(f128), tmin(f128));
            try testArgs(f128, fmax(f128), fmin(f128));
            try testArgs(f128, fmax(f128), 1e-1);
            try testArgs(f128, fmax(f128), 1e0);
            try testArgs(f128, fmax(f128), 1e1);
            try testArgs(f128, fmax(f128), fmax(f128));
            try testArgs(f128, fmax(f128), inf(f128));
            try testArgs(f128, fmax(f128), nan(f128));

            try testArgs(f128, inf(f128), -nan(f128));
            try testArgs(f128, inf(f128), -inf(f128));
            try testArgs(f128, inf(f128), -fmax(f128));
            try testArgs(f128, inf(f128), -1e1);
            try testArgs(f128, inf(f128), -1e0);
            try testArgs(f128, inf(f128), -1e-1);
            try testArgs(f128, inf(f128), -fmin(f128));
            try testArgs(f128, inf(f128), -tmin(f128));
            try testArgs(f128, inf(f128), -0.0);
            try testArgs(f128, inf(f128), 0.0);
            try testArgs(f128, inf(f128), tmin(f128));
            try testArgs(f128, inf(f128), fmin(f128));
            try testArgs(f128, inf(f128), 1e-1);
            try testArgs(f128, inf(f128), 1e0);
            try testArgs(f128, inf(f128), 1e1);
            try testArgs(f128, inf(f128), fmax(f128));
            try testArgs(f128, inf(f128), inf(f128));
            try testArgs(f128, inf(f128), nan(f128));

            try testArgs(f128, nan(f128), -nan(f128));
            try testArgs(f128, nan(f128), -inf(f128));
            try testArgs(f128, nan(f128), -fmax(f128));
            try testArgs(f128, nan(f128), -1e1);
            try testArgs(f128, nan(f128), -1e0);
            try testArgs(f128, nan(f128), -1e-1);
            try testArgs(f128, nan(f128), -fmin(f128));
            try testArgs(f128, nan(f128), -tmin(f128));
            try testArgs(f128, nan(f128), -0.0);
            try testArgs(f128, nan(f128), 0.0);
            try testArgs(f128, nan(f128), tmin(f128));
            try testArgs(f128, nan(f128), fmin(f128));
            try testArgs(f128, nan(f128), 1e-1);
            try testArgs(f128, nan(f128), 1e0);
            try testArgs(f128, nan(f128), 1e1);
            try testArgs(f128, nan(f128), fmax(f128));
            try testArgs(f128, nan(f128), inf(f128));
            try testArgs(f128, nan(f128), nan(f128));
        }
        fn testIntVectors() !void {
            try testArgs(@Vector(1, i8), .{
                -0x54,
            }, .{
                0x0f,
            });
            try testArgs(@Vector(2, i8), .{
                -0x4d, 0x55,
            }, .{
                0x7d, -0x5d,
            });
            try testArgs(@Vector(4, i8), .{
                0x73, 0x6f, 0x6e, -0x49,
            }, .{
                -0x66, 0x23, 0x21, -0x56,
            });
            try testArgs(@Vector(8, i8), .{
                0x44, -0x37, 0x33, -0x2b, -0x1f, 0x3e, 0x50, -0x4d,
            }, .{
                0x6a, 0x1a, -0x0e, 0x4c, -0x46, 0x03, -0x17, 0x3e,
            });
            try testArgs(@Vector(16, i8), .{
                -0x52, 0x1a, -0x4b, 0x4e, -0x75, 0x33, -0x43, 0x30, 0x71, -0x30, -0x73, -0x53, 0x64, 0x1f, -0x27, 0x36,
            }, .{
                0x65, 0x77, -0x62, 0x0f, 0x15, 0x52, 0x5c, 0x12, -0x10, 0x36, 0x6d, 0x42, -0x24, -0x79, -0x32, -0x75,
            });
            try testArgs(@Vector(32, i8), .{
                -0x12, -0x1e, 0x18, 0x6e, 0x31,  0x53,  -0x6a, -0x34, 0x13,  0x4d, 0x30, -0x7d, -0x31, 0x1e,  -0x24, 0x32,
                -0x1e, -0x01, 0x55, 0x33, -0x75, -0x44, -0x57, 0x2b,  -0x66, 0x19, 0x7f, -0x28, -0x3f, -0x7e, -0x5d, -0x06,
            }, .{
                0x05, -0x23, 0x43,  -0x54, -0x41, 0x7f,  -0x6a, -0x31, 0x04,  0x15, -0x7a, -0x37, 0x6d, 0x16,  0x00,  0x4a,
                0x15, 0x55,  -0x4a, 0x16,  -0x73, -0x0c, 0x1c,  -0x26, -0x14, 0x00, 0x55,  0x7b,  0x16, -0x2e, -0x5f, -0x67,
            });
            try testArgs(@Vector(64, i8), .{
                -0x05, 0x76,  0x4e,  -0x5c, 0x7b,  -0x1a, -0x38, -0x2e, 0x3d,  0x36,  0x01,  0x30,  -0x02, -0x71, -0x24, 0x24,
                -0x2e, -0x6e, -0x60, 0x74,  -0x80, -0x1c, -0x34, -0x08, -0x33, 0x77,  0x1c,  -0x0f, 0x45,  -0x51, -0x1d, 0x35,
                -0x45, 0x44,  0x27,  -0x3c, 0x6b,  0x58,  -0x6a, -0x26, 0x06,  -0x30, -0x21, -0x0a, 0x60,  -0x11, -0x05, 0x75,
                0x38,  0x72,  -0x6d, -0x1f, -0x7f, 0x74,  -0x6b, -0x14, -0x80, 0x35,  -0x0f, -0x1e, 0x6a,  0x17,  -0x74, -0x6c,
            }, .{
                -0x5d, 0x2d,  0x55,  0x40,  -0x7c, 0x67,  0x61,  0x5f,  0x14,  0x5b, -0x0c, -0x4d, -0x5f, 0x25,  0x36,  0x3c,
                -0x75, -0x48, -0x2b, 0x76,  -0x57, -0x4a, 0x1d,  0x65,  -0x32, 0x18, -0x2a, -0x0a, -0x6e, -0x3c, -0x62, 0x4e,
                -0x24, -0x3c, 0x7d,  -0x79, -0x1a, -0x14, -0x03, -0x56, 0x7a,  0x5f, 0x64,  -0x68, 0x5f,  -0x10, -0x63, -0x07,
                0x79,  -0x44, 0x47,  0x7d,  0x6e,  0x77,  0x03,  -0x4e, 0x67,  0x38, 0x46,  -0x44, -0x41, 0x66,  -0x16, -0x0a,
            });
            try testArgs(@Vector(128, i8), .{
                0x30,  0x70,  -0x2a, -0x29, -0x35, -0x69, -0x18, 0x2b,  0x4a,  -0x17, -0x5f, -0x36, 0x34,  -0x26, 0x03,  -0x2d,
                -0x75, -0x27, -0x07, -0x49, -0x58, 0x00,  -0x45, 0x5d,  -0x11, -0x68, 0x34,  0x73,  -0x4d, 0x7f,  -0x25, -0x6a,
                0x46,  -0x1d, -0x68, 0x04,  0x64,  -0x0d, 0x30,  0x27,  -0x24, 0x67,  0x3c,  -0x7c, -0x2e, -0x24, 0x24,  0x3e,
                -0x2c, -0x05, 0x4e,  -0x17, 0x6d,  0x57,  0x76,  0x35,  -0x3d, 0x51,  0x71,  -0x4e, 0x50,  0x26,  0x4a,  -0x42,
                0x73,  -0x36, -0x5d, 0x2a,  0x55,  0x33,  -0x2b, -0x76, 0x08,  0x43,  0x77,  -0x73, -0x0a, 0x5c,  -0x03, -0x50,
                -0x0a, -0x1c, -0x20, 0x3c,  -0x7e, 0x60,  0x11,  -0x77, 0x25,  -0x71, 0x31,  0x2d,  -0x4b, -0x26, -0x2a, 0x7f,
                -0x1f, 0x23,  -0x34, -0x1f, 0x35,  0x0d,  0x3e,  0x76,  -0x08, 0x2c,  0x12,  0x3e,  -0x09, -0x3e, 0x4b,  -0x52,
                -0x1a, -0x44, -0x53, -0x41, -0x6d, -0x5e, -0x06, -0x04, 0x3f,  -0x2e, 0x01,  0x54,  0x19,  -0x5a, -0x62, -0x3a,
            }, .{
                0x42,  -0x11, -0x08, -0x64, -0x55, 0x31,  0x27,  -0x66, 0x38,  0x5a,  0x25,  -0x68, 0x0b,  -0x41, -0x0d, 0x60,
                -0x17, -0x6d, 0x62,  -0x65, -0x5e, -0x1c, -0x35, 0x28,  0x1c,  -0x74, -0x7f, -0x1c, 0x3a,  0x4e,  0x05,  -0x08,
                0x30,  -0x77, 0x03,  0x68,  -0x2c, 0x5c,  0x74,  0x6a,  -0x21, 0x0a,  0x36,  -0x55, 0x21,  0x29,  -0x05, 0x70,
                0x23,  0x3b,  0x0a,  0x7a,  0x19,  0x14,  0x65,  -0x1d, 0x2b,  0x65,  0x33,  0x2a,  0x52,  -0x63, 0x57,  0x10,
                -0x1b, 0x26,  -0x46, -0x7e, -0x25, 0x79,  -0x01, -0x0d, -0x49, -0x4d, 0x74,  0x03,  0x77,  0x16,  0x03,  -0x3d,
                0x1c,  0x25,  0x5a,  -0x2f, -0x16, -0x5f, -0x36, -0x55, -0x44, -0x0c, -0x0f, 0x7b,  -0x15, -0x1d, 0x32,  0x31,
                0x6e,  -0x44, -0x4a, -0x64, 0x67,  0x04,  0x47,  0x00,  0x3c,  -0x0a, -0x79, 0x3d,  0x48,  0x5a,  0x61,  -0x2c,
                0x6d,  -0x68, -0x71, -0x6b, -0x11, 0x44,  -0x75, -0x55, -0x67, -0x52, 0x64,  -0x3d, -0x05, -0x76, -0x6d, -0x44,
            });

            try testArgs(@Vector(1, u8), .{
                0x1f,
            }, .{
                0x06,
            });
            try testArgs(@Vector(2, u8), .{
                0x80, 0x63,
            }, .{
                0xe4, 0x28,
            });
            try testArgs(@Vector(4, u8), .{
                0x83, 0x9e, 0x1e, 0xc1,
            }, .{
                0xf0, 0x5c, 0x46, 0x85,
            });
            try testArgs(@Vector(8, u8), .{
                0x1e, 0x4d, 0x9d, 0x2a, 0x4c, 0x74, 0x0a, 0x83,
            }, .{
                0x28, 0x60, 0xa9, 0xb5, 0xd9, 0xa6, 0xf1, 0xb6,
            });
            try testArgs(@Vector(16, u8), .{
                0xea, 0x80, 0xbb, 0xe8, 0x74, 0x81, 0xc8, 0x66, 0x7b, 0x41, 0x90, 0xcb, 0x30, 0x70, 0x4b, 0x0f,
            }, .{
                0x61, 0x26, 0xbe, 0x47, 0x00, 0x9c, 0x55, 0xa5, 0x59, 0xf0, 0xb2, 0x20, 0x30, 0xaf, 0x82, 0x3e,
            });
            try testArgs(@Vector(32, u8), .{
                0xa1, 0x88, 0xc4, 0xf4, 0x77, 0x0b, 0xf5, 0xbb, 0x09, 0x03, 0xbf, 0xf5, 0xcc, 0x7f, 0x6b, 0x2a,
                0x4c, 0x05, 0x37, 0xc9, 0x8a, 0xcb, 0x91, 0x23, 0x09, 0x5f, 0xb8, 0x99, 0x4a, 0x75, 0x26, 0xe4,
            }, .{
                0xff, 0x0f, 0x99, 0x49, 0xa6, 0x25, 0xa7, 0xd4, 0xc9, 0x2f, 0x97, 0x6a, 0x01, 0xd6, 0x6e, 0x41,
                0xa4, 0xb5, 0x3c, 0x03, 0xea, 0x82, 0x9c, 0x5f, 0xac, 0x07, 0x16, 0x15, 0x1c, 0x64, 0x25, 0x2f,
            });
            try testArgs(@Vector(64, u8), .{
                0xaa, 0x08, 0xeb, 0xb2, 0xd7, 0x89, 0x0f, 0x98, 0xda, 0x9f, 0xa6, 0x4e, 0x3c, 0xce, 0x1b, 0x1b,
                0x9e, 0x5f, 0x2b, 0xd6, 0x59, 0x26, 0x47, 0x05, 0x2a, 0xb7, 0xd1, 0x10, 0xde, 0xd9, 0x84, 0x00,
                0x07, 0xc0, 0xaa, 0x6e, 0xfa, 0x3b, 0x97, 0x85, 0xa8, 0x42, 0xd7, 0xa5, 0x90, 0xe6, 0x10, 0x1a,
                0x47, 0x84, 0xe1, 0x3e, 0xb0, 0x70, 0x26, 0x3f, 0xea, 0x24, 0xb8, 0x5f, 0xe3, 0xe3, 0x4c, 0xed,
            }, .{
                0x3b, 0xc5, 0xe0, 0x3d, 0x4f, 0x2e, 0x1d, 0xa9, 0xf7, 0x7b, 0xc7, 0xc1, 0x48, 0xc6, 0xe5, 0x9e,
                0x4d, 0xa8, 0x21, 0x37, 0xa1, 0x1a, 0x95, 0x69, 0x89, 0x2f, 0x15, 0x07, 0x3d, 0x7b, 0x69, 0x89,
                0xea, 0x87, 0xf0, 0x94, 0x67, 0xf2, 0x3d, 0x04, 0x96, 0x8a, 0xd6, 0x70, 0x7c, 0x16, 0xe7, 0x62,
                0xf0, 0x8d, 0x96, 0x65, 0xd1, 0x4a, 0x35, 0x3e, 0x7a, 0x67, 0xa6, 0x1f, 0x37, 0x66, 0xe3, 0x45,
            });
            try testArgs(@Vector(128, u8), .{
                0xa1, 0xd0, 0x7b, 0xf9, 0x7b, 0x77, 0x7b, 0x3d, 0x2d, 0x68, 0xc2, 0x7b, 0xb0, 0xb8, 0xd4, 0x7c,
                0x1a, 0x1f, 0xd2, 0x92, 0x3e, 0xcb, 0xc1, 0x6b, 0xb9, 0x4d, 0xf1, 0x67, 0x58, 0x8e, 0x77, 0xa6,
                0xb9, 0xdf, 0x10, 0x6f, 0xbe, 0xe3, 0x33, 0xb6, 0x93, 0x77, 0x80, 0xef, 0x09, 0x9d, 0x61, 0x40,
                0xa2, 0xf4, 0x52, 0x18, 0x9d, 0xe4, 0xb0, 0xaf, 0x0a, 0xa7, 0x0b, 0x09, 0x67, 0x38, 0x71, 0x04,
                0x72, 0xa1, 0xd2, 0xfd, 0xf8, 0xf0, 0xa7, 0x23, 0x24, 0x5b, 0x7d, 0xfb, 0x43, 0xba, 0x6c, 0xc4,
                0x83, 0x46, 0x0e, 0x4d, 0x6c, 0x92, 0xab, 0x4f, 0xd2, 0x70, 0x9d, 0xfe, 0xce, 0xf8, 0x05, 0x9f,
                0x98, 0x36, 0x9c, 0x90, 0x9a, 0xd0, 0xb5, 0x76, 0x16, 0xe8, 0x25, 0xc2, 0xbd, 0x91, 0xab, 0xf9,
                0x6f, 0x6c, 0xc5, 0x60, 0xe5, 0x30, 0xf2, 0xb7, 0x59, 0xc4, 0x9c, 0xdd, 0xdf, 0x04, 0x65, 0xd9,
            }, .{
                0xed, 0xe1, 0x8a, 0xf6, 0xf3, 0x8b, 0xfd, 0x1d, 0x3c, 0x87, 0xbf, 0xfe, 0x04, 0x52, 0x15, 0x82,
                0x0b, 0xb0, 0xcf, 0xcf, 0xf8, 0x03, 0x9c, 0xef, 0xc1, 0x76, 0x7e, 0xe3, 0xe9, 0xa8, 0x18, 0x90,
                0xd4, 0xc4, 0x91, 0x15, 0x68, 0x7f, 0x65, 0xd8, 0xe1, 0xb3, 0x23, 0xc2, 0x7d, 0x84, 0x3b, 0xaf,
                0x74, 0x69, 0x07, 0x2a, 0x1b, 0x5f, 0x0e, 0x44, 0x0d, 0x2b, 0x9c, 0x82, 0x41, 0xf9, 0x7f, 0xb5,
                0xc4, 0xd9, 0xcb, 0xd3, 0xc5, 0x31, 0x8b, 0x5f, 0xda, 0x09, 0x9b, 0x29, 0xa3, 0xb7, 0x13, 0x0d,
                0x55, 0x9b, 0x59, 0x33, 0x2a, 0x59, 0x3a, 0x44, 0x1f, 0xd3, 0x40, 0x4e, 0xde, 0x2c, 0xe4, 0x16,
                0xfd, 0xc3, 0x02, 0x74, 0xaa, 0x65, 0xfd, 0xc8, 0x2a, 0x8a, 0xdb, 0xae, 0x44, 0x28, 0x62, 0xa4,
                0x56, 0x4f, 0xf1, 0xaa, 0x0a, 0x0f, 0xdb, 0x1b, 0xc8, 0x45, 0x9b, 0x12, 0xb4, 0x1a, 0xe4, 0xa3,
            });

            try testArgs(@Vector(1, i16), .{
                -0x7b9c,
            }, .{
                0x600a,
            });
            try testArgs(@Vector(2, i16), .{
                0x43cc, -0x1421,
            }, .{
                -0x2b0e, 0x4d99,
            });
            try testArgs(@Vector(4, i16), .{
                0x558f, 0x6d92, 0x488f, 0x0a04,
            }, .{
                -0x01a9,
                0x2ee4,
                0x24a9,
                -0x5fee,
            });
            try testArgs(@Vector(8, i16), .{
                -0x7e5d, -0x02e4, -0x3a72, -0x2e30, 0x7c87, 0x3ea0, 0x4f02, 0x06e4,
            }, .{
                -0x417f, 0x5a13, -0x117b, 0x4c28, -0x3769, -0x56a8, 0x1656, -0x4431,
            });
            try testArgs(@Vector(16, i16), .{
                0x04be,  0x774a, 0x7395,  -0x6ca2, -0x21a0, 0x35be, 0x186c,  0x5991,
                -0x1a82, 0x4527, -0x2278, -0x3554, 0x42c1,  0x7f53, -0x670d, 0x1fad,
            }, .{
                0x7a7d,  0x47dd,  0x1975,  0x4028, 0x26ef,  -0x24f5, -0x77c9, -0x19a5,
                -0x4b04, -0x6939, -0x1b8d, 0x3718, -0x78e6, 0x0941,  -0x1208, -0x392d,
            });
            try testArgs(@Vector(32, i16), .{
                0x4cde,  0x3ab0,  0x354e,  0x0bc0,  -0x5333, 0x4857,  -0x7ccf, -0x69da,
                0x6ab8,  0x2bf3,  0x1c5a,  0x7b11,  -0x5653, 0x7bc5,  0x497e,  -0x0b55,
                0x7aa8,  -0x5a8c, -0x6d05, 0x6210,  0x1b64,  0x3f6f,  0x1a02,  0x65e4,
                -0x6795, 0x5867,  -0x6faf, -0x07cb, -0x762c, -0x7500, 0x1f1c,  -0x4348,
            }, .{
                0x72f6,  -0x5405, -0x3aac, 0x2857,  0x34cd,  -0x1dce, -0x56d8, 0x7150,
                -0x6549, 0x61bd,  -0x3a9f, -0x1e02, -0x5a5a, -0x7910, -0x166d, 0x7c8e,
                -0x5292, -0x6c6e, -0x37e3, 0x1514,  0x1787,  0x58cb,  -0x4d99, -0x6c15,
                0x592e,  -0x045f, 0x7682,  -0x1eef, 0x1fb2,  -0x7117, -0x2a17, -0x2d8e,
            });
            try testArgs(@Vector(64, i16), .{
                0x29c3,  -0x1b1f, -0x17ce, -0x50d0, -0x5de3, 0x5ffd,  0x184a,  -0x7769,
                0x445e,  0x0d8a,  0x7844,  -0x757d, 0x2b32,  0x5374,  -0x6ab2, -0x71c4,
                0x38f9,  0x347f,  0x2d4c,  0x69a4,  -0x2f92, -0x4479, 0x427b,  -0x0c5f,
                0x15ae,  0x2c86,  0x1864,  -0x0095, 0x6803,  -0x3484, 0x1001,  -0x0560,
                -0x0824, 0x7bf6,  0x7a3c,  -0x458a, -0x65cc, -0x54b1, -0x75c6, 0x782e,
                0x35a7,  -0x3188, -0x58ba, 0x40d0,  -0x4a9c, 0x6b79,  0x1ef5,  0x67a2,
                -0x3fb8, 0x1885,  -0x093d, -0x4802, 0x0379,  0x2f52,  0x7f1f,  0x256c,
                0x1052,  0x1b3b,  -0x6146, 0x7e0d,  0x79ca,  -0x79ee, 0x3d58,  0x7482,
            }, .{
                -0x0017, -0x3fdd, -0x6f93, 0x6178,  0x5c2b,  0x4eb3,  0x685b,  0x12c8,
                0x0290,  -0x34f4, -0x6572, 0x3ab6,  -0x3ed1, -0x5e5f, 0x3a90,  -0x4540,
                -0x2098, 0x6bde,  0x1246,  0x2212,  -0x4d6a, -0x2a5a, 0x5cc4,  -0x240f,
                0x51b2,  0x5ec0,  -0x5b5f, -0x1b6e, -0x57a5, -0x06bd, -0x5132, 0x7889,
                0x2817,  0x6ada,  -0x6b46, -0x6a37, -0x6475, -0x5ff4, 0x5a27,  0x1dfa,
                0x6bd6,  -0x49da, -0x09bf, -0x7c53, 0x2cd3,  -0x6be0, -0x2dca, 0x44bd,
                -0x1b95, 0x7680,  -0x5bb0, 0x7ad7,  -0x1988, 0x149f,  0x631e,  -0x1d2d,
                0x632b,  0x55c7,  -0x3433, 0x0dde,  -0x27a7, 0x560e,  -0x2063, 0x4570,
            });

            try testArgs(@Vector(1, u16), .{
                0x9d6f,
            }, .{
                0x44b1,
            });
            try testArgs(@Vector(2, u16), .{
                0xa0fa, 0xc365,
            }, .{
                0xe736, 0xc394,
            });
            try testArgs(@Vector(4, u16), .{
                0x9608, 0xa558, 0x161b, 0x206f,
            }, .{
                0x3088, 0xf25c, 0x7837, 0x9b3f,
            });
            try testArgs(@Vector(8, u16), .{
                0xcf61, 0xb121, 0x3cf1, 0x3e9f, 0x43a7, 0x8d69, 0x96f5, 0xc11e,
            }, .{
                0xee30, 0x82f0, 0x270b, 0x1498, 0x4c60, 0x6e72, 0x0b64, 0x02d4,
            });
            try testArgs(@Vector(16, u16), .{
                0x9191, 0xd23e, 0xf844, 0xd84a, 0xe907, 0xf1e8, 0x712d, 0x90af,
                0x6541, 0x3fa6, 0x92eb, 0xe35a, 0xc0c9, 0xcb47, 0xb790, 0x4453,
            }, .{
                0x21c3, 0x4039, 0x9b71, 0x60bd, 0xcd7f, 0x2ec8, 0x50ba, 0xe810,
                0xebd4, 0x06e5, 0xed18, 0x2f66, 0x7e31, 0xe282, 0xad63, 0xb25e,
            });
            try testArgs(@Vector(32, u16), .{
                0x6b6a, 0x30a9, 0xc267, 0x2231, 0xbf4c, 0x00bc, 0x9c2c, 0x2928,
                0xecad, 0x82df, 0xcfb0, 0xa4e5, 0x909b, 0x1b05, 0xaf40, 0x1fd9,
                0xcec6, 0xd8dc, 0xd4b5, 0x6d59, 0x8e3f, 0x4d8a, 0xb83a, 0x808e,
                0x47e2, 0x5782, 0x59bf, 0xcefc, 0x5179, 0x3f48, 0x93dc, 0x66d2,
            }, .{
                0x1be8, 0xe98c, 0xf9b3, 0xb008, 0x2f8d, 0xf087, 0xc9b9, 0x75aa,
                0xbd16, 0x9540, 0xc5bd, 0x2b2c, 0xd43f, 0x9394, 0x3e1d, 0xf695,
                0x167d, 0xff7a, 0xf09d, 0xdff8, 0xdfa2, 0xc779, 0x70b7, 0x01bd,
                0x46b3, 0x995a, 0xb7bc, 0xa79d, 0x5542, 0x961e, 0x37cd, 0x9c2a,
            });
            try testArgs(@Vector(64, u16), .{
                0x6b87, 0xfd84, 0x436b, 0xe345, 0xfb82, 0x81fc, 0x0992, 0x45f9,
                0x5527, 0x1f6d, 0xda46, 0x6a16, 0xf6e1, 0x8fb7, 0x3619, 0xdfe3,
                0x64ce, 0x8ac6, 0x3ae8, 0x30e3, 0xec3b, 0x4ba7, 0x02a4, 0xa694,
                0x8e68, 0x8f0c, 0x5e30, 0x0e55, 0x6538, 0x9852, 0xea35, 0x7be2,
                0xdabd, 0x57e6, 0x5b38, 0x0fb2, 0x2604, 0x85e7, 0x6595, 0x8de9,
                0x49b1, 0xe9a2, 0x3758, 0xa4d9, 0x505b, 0xc9d3, 0xddc5, 0x9a43,
                0xfd44, 0x50f5, 0x379e, 0x03b6, 0x6375, 0x692f, 0x5586, 0xc717,
                0x94dd, 0xee06, 0xb32d, 0x0bb9, 0x0e35, 0x5f8f, 0x0ba4, 0x19a8,
            }, .{
                0xbeeb, 0x3e54, 0x6486, 0x5167, 0xe432, 0x57cf, 0x9cac, 0x922e,
                0xd2f8, 0x5614, 0x2e7f, 0x19cf, 0x9a07, 0x0524, 0x168f, 0x4464,
                0x4def, 0x83ce, 0x97b4, 0xf269, 0xda5f, 0x28c1, 0x9cc3, 0xfa7c,
                0x25a0, 0x912d, 0x25b2, 0xd60d, 0xcd82, 0x0e03, 0x40cc, 0xc9dc,
                0x18eb, 0xc609, 0xb06d, 0x29e0, 0xf3c7, 0x997b, 0x8ca2, 0xa750,
                0xc9bc, 0x8f0e, 0x3916, 0xd905, 0x94f8, 0x397f, 0x98b5, 0xc61d,
                0x05db, 0x3e7a, 0xf750, 0xe8de, 0x3225, 0x81d9, 0x612e, 0x0a7e,
                0x2c02, 0xff5b, 0x19ca, 0xbbf5, 0x870e, 0xc9ca, 0x47bb, 0xcfcc,
            });

            try testArgs(@Vector(1, i32), .{
                0x7aef7b1e,
            }, .{
                0x60310858,
            });
            try testArgs(@Vector(2, i32), .{
                -0x21910ac9, 0x669f37ef,
            }, .{
                0x1a2a1681, 0x003b1fdf,
            });
            try testArgs(@Vector(4, i32), .{
                0x7906cf0d, 0x4818a45f, -0x0a2833b6, 0x51a018c9,
            }, .{
                -0x05a3e6a7, -0x47f4a500, 0x50d1141f, -0x264c85c2,
            });
            try testArgs(@Vector(8, i32), .{
                0x7566235a,  -0x7720144f, -0x7d4f5489, 0x3cd736c8,
                -0x77388801, 0x4e7f955a,  0x4cdf52bc,  0x50b0b53f,
            }, .{
                0x00ed6fc5, 0x37320361, 0x70c563c2,  -0x09acb495,
                0x0688e83f, 0x797295c4, -0x23bfbfdb, 0x38552096,
            });
            try testArgs(@Vector(16, i32), .{
                -0x0214589d, 0x74a7537f,  0x7a7dcb26, 0x3e2e4c44,
                -0x23bfc358, 0x60e8ef18,  0x5524a7bc, -0x3d88c153,
                -0x7dc8ff0f, 0x6e2698f6,  0x05641ab8, -0x45e9e405,
                -0x7c1a04d0, -0x4a8d1e91, 0x41d56723, 0x4ba924ab,
            }, .{
                -0x528dc756, -0x6bc217f4, 0x40789b06, 0x65f08d3a,
                -0x077140ea, -0x43bdaa79, 0x5d98f4e7, -0x2356a1ca,
                -0x36ef2b49, -0x7cd09b06, 0x71c8176e, 0x5b005860,
                0x6ce8cfab,  -0x49fd7609, 0x6cbb4e33, 0x6c7c121d,
            });
            try testArgs(@Vector(32, i32), .{
                0x7d22905d,  -0x354e4bbe, -0x68662618, -0x246e1858,
                -0x1c4285a9, -0x0338059c, -0x60f5bbf4, -0x04f06917,
                -0x55f837b6, -0x2fba5fe3, 0x092aabf4,  -0x5f533b31,
                0x6e81a558,  -0x7bcac358, 0x6c4d8d04,  0x3e2f9852,
                -0x78589b1a, -0x68a00fd4, -0x77d55e25, 0x7f79b51c,
                -0x66b88f45, 0x7f6dc8a5,  -0x27299a82, -0x426c8e1c,
                0x0c288f16,  0x158f8c3f,  0x26708be1,  -0x0b73626e,
                -0x32df1bee, 0x196330f4,  -0x68bb9529, -0x26376ab6,
            }, .{
                0x63bd0bd4,  0x4e507611,  -0x5e5222b8, -0x35d8e114,
                0x1feab77b,  -0x20de7dfd, -0x0ed0b09f, -0x7fc3d585,
                -0x2d3018e9, -0x261d431b, 0x54451864,  0x1415288f,
                -0x3ab89593, -0x7060e4c1, -0x54fcd501, -0x26324630,
                0x53fc8294,  0x2d4aceef,  -0x4ac8efd2, -0x2fec97b7,
                -0x4de3a2fc, 0x2269fe52,  -0x58c8b473, -0x21026285,
                -0x23438776, 0x3d5c8c41,  -0x1fc946b2, -0x161c7005,
                0x44913ff1,  -0x76e2bfaa, -0x54636350, -0x6ec53870,
            });

            try testArgs(@Vector(1, u32), .{
                0x1d0d9cc4,
            }, .{
                0xce2d0ab6,
            });
            try testArgs(@Vector(2, u32), .{
                0x5ab78c03, 0xd21bb513,
            }, .{
                0x8a6664eb, 0x79eac37d,
            });
            try testArgs(@Vector(4, u32), .{
                0x234d576e, 0x4151cc9c, 0x39f558e4, 0xba935a32,
            }, .{
                0x398f2a9d, 0x4540f093, 0x9225551c, 0x3bac865b,
            });
            try testArgs(@Vector(8, u32), .{
                0xb8336635, 0x2fc3182c, 0x27a00123, 0x71587fbe,
                0x9cbc65d2, 0x6f4bb0e6, 0x362594ce, 0x9971df38,
            }, .{
                0x5727e734, 0x972b0313, 0xff25f5dc, 0x924f8e55,
                0x04920a61, 0xa1c3b334, 0xf52df4b6, 0x5ef72ecc,
            });
            try testArgs(@Vector(16, u32), .{
                0xfb566f9e, 0x9ad4691a, 0x5b5f9ec0, 0x5a572d2a,
                0x8f2f226b, 0x2dfc7e33, 0x9fb07e32, 0x9d672a2e,
                0xbedc3cee, 0x6872428d, 0xbc73a9fd, 0xd4d5f055,
                0x69c1e9ee, 0x65038deb, 0x1449061a, 0x48412ec2,
            }, .{
                0x96cbe946, 0x3f24f60b, 0xaeacdc53, 0x7611a8b4,
                0x031a67a8, 0x52a26828, 0x75646f4b, 0xb75902c3,
                0x1f881f08, 0x834e02a4, 0x5e5b40eb, 0xc75c264d,
                0xa8251e09, 0x28e46bbd, 0x12cb1f31, 0x9a2af615,
            });
            try testArgs(@Vector(32, u32), .{
                0x131bbb7b, 0xa7311026, 0x9d5e59a0, 0x99b090d6,
                0xfe969e2e, 0x04547697, 0x357d3250, 0x43be6d7a,
                0x16ecf5c5, 0xf60febcc, 0x1d1e2602, 0x138a96d2,
                0x9117ba72, 0x9f185b32, 0xc10e23fd, 0x3e6b7fd8,
                0x4dc9be70, 0x2ee30047, 0xaffeab60, 0x7172d362,
                0x6154bfcf, 0x5388dc3e, 0xd6e5a76e, 0x8b782f2d,
                0xacbef4a2, 0x843aca71, 0x25d8ab5c, 0xe1a63a39,
                0xc26212e5, 0x0847b84b, 0xb53541e5, 0x0c8e44db,
            }, .{
                0x4ad92822, 0x715b623f, 0xa5bed8a7, 0x937447a9,
                0x7ecb38eb, 0x0a2f3dfc, 0x96f467a2, 0xec882793,
                0x41a8707f, 0xf7310656, 0x76217b80, 0x2058e5fc,
                0x26682154, 0x87313e31, 0x4bdc480a, 0x193572ff,
                0x60b03c75, 0x0fe45908, 0x56c73703, 0xdb86554c,
                0xdda2dd7d, 0x34371b27, 0xe4e6ad50, 0x422d1828,
                0x1de3801b, 0xdce268d3, 0x20af9ec8, 0x188a591f,
                0xf080e943, 0xc8718d14, 0x3f920382, 0x18d101b5,
            });

            try testArgs(@Vector(1, i64), .{
                0x4a31679b316d8b59,
            }, .{
                0x34a583368386afde,
            });
            try testArgs(@Vector(2, i64), .{
                0x3bae373f9cb990b3, -0x7e8c6c876e8fd34a,
            }, .{
                0x09dbef6f7cb9c726, 0x48dfeca879b0df51,
            });
            try testArgs(@Vector(4, i64), .{
                -0x2bd24dd5f5da94bf, -0x144113bae33082c2,
                0x51e8cb7027ba4b12,  -0x47b02168e2e22f13,
            }, .{
                0x769f113245641b91,  -0x414d0e24ea97bc53,
                -0x0d2a570e7ef9e923, -0x070513d46d3b5a4c,
            });
            try testArgs(@Vector(8, i64), .{
                0x10bb6779b6a55ca9,  0x5f6ffd567a187af4,
                -0x6ba191b1168486b4, -0x441b92ce455870a1,
                0x2b6fdefbec9386ad,  -0x6fdd3938d79217e4,
                0x6aa8fe1fb891501f,  0x20802f5bbdf6dc50,
            }, .{
                -0x7500319df437b479, 0x00ceb712d4fa62d4,
                0x67e715b9e99e660d,  -0x17ae00e1f0009ec2,
                -0x5b700b948503acdf, -0x3ff61fb5cce5a530,
                0x55a3efac2e3694a4,  0x7f951a8d842f1670,
            });
            try testArgs(@Vector(16, i64), .{
                0x37a205109a685810,  -0x50ff5d13134ccaa6,
                0x26813391c5505d5d,  -0x502cdc01603a2f21,
                -0x6b1b44b1c850c7ea, 0x1f6db974ace9dd70,
                -0x47d15da8b519e328, 0x3ac0763abbf79d8d,
                0x5f12e0dc1aed4a4f,  -0x46a973e16061e928,
                -0x3f59a3fa9699b4d5, -0x2f5012d390c78315,
                -0x40e510dea2c47e9c, 0x221c51defe0acc9a,
                -0x385fd6f1d390b84b, 0x35932fe2783fa6b9,
            }, .{
                0x0ba5202b71ad73dd,  0x65c8d2d5e2a14fe5,
                0x2e4d97cd66c41a3d,  0x14babbb47da51193,
                0x59d1d12b42ade3aa,  -0x3c3617e556dfa8fb,
                -0x5a36602ba43279c4, -0x61f1ddda13665d9f,
                -0x50cd6128589ddd04, 0x135ae0dcc85674ae,
                -0x25e80592affc038d, 0x07e184c44fbe9b12,
                -0x70ede1b90964bbaa, 0x3ec48b32e8efd98e,
                -0x5267d41d85a29f46, 0x53099805f9116b60,
            });

            try testArgs(@Vector(1, u64), .{
                0x333f593bf9d08546,
            }, .{
                0x6918bd767e730778,
            });
            try testArgs(@Vector(2, u64), .{
                0x4cd89a317b03d430, 0x28998f61842f63a9,
            }, .{
                0x6c34db64af0e217e, 0x57aa5d02cd45dceb,
            });
            try testArgs(@Vector(4, u64), .{
                0x946cf7e7484691c9, 0xf4fc5be2a762fcbf,
                0x71cc83bc25abaf14, 0xc69cef44c6f833a1,
            }, .{
                0x9f90cbd6c3ce1d4e, 0x182f65295dff4e84,
                0x4dfe62c59fed0040, 0x18402347c1db1999,
            });
            try testArgs(@Vector(8, u64), .{
                0x92c6281333943e2c, 0xa97750504668efb5,
                0x234be51057c0181f, 0xefbc1f407f3df4fb,
                0x8da6cc7c39cebb94, 0xb408f7e56feee497,
                0x2363f1f8821592ed, 0x01716e800c0619e1,
            }, .{
                0xa617426684147e7e, 0x7542da7ebe093a7b,
                0x3f21d99ac57606b7, 0x65cd36d697d22de4,
                0xed23d6bdf176c844, 0x2d4573f100ff7b58,
                0x4968f4d21b49f8ab, 0xf5d9a205d453e933,
            });
            try testArgs(@Vector(16, u64), .{
                0x2f61a4ee66177b4a, 0xf13b286b279f6a93,
                0x36b46beb63665318, 0x74294dbde0da98d2,
                0x3aa872ba60b936eb, 0xe8f698b36e62600b,
                0x9e8930c21a6a1a76, 0x876998b09b8eb03c,
                0xa0244771a2ec0adb, 0xb4c72bff3d3ac1a2,
                0xd70677210830eced, 0x6622abc1734dd72d,
                0x157e2bb0d57d6596, 0x2aac8192fb7ef973,
                0xc4a0ca92f34d7b13, 0x04300f8ad1845246,
            }, .{
                0xeaf71dcf0eb76f5d, 0x0e84b1b63dc97139,
                0x0f64cc38d23c94a1, 0x12775cf0816349b7,
                0xfdcf13387ba48d54, 0xf8d3c672cacd8779,
                0xe728c1f5eb56ab1e, 0x05931a34877f7a69,
                0x1861a763c8dafd1f, 0x4ac97573ecd5739f,
                0x3384414c9bf77b8c, 0x32c15bbd04a5ddc4,
                0xbfd88aee1d82ed32, 0x20e91c15b701059a,
                0xed533d18f8657f3f, 0x1ddd7cd7f6bab957,
            });

            try testArgs(@Vector(1, i128), .{
                -0x3bb56309fcad13fc1011dc671cf57bdc,
            }, .{
                -0x05338bb517db516ee08c45d1408e5836,
            });
            try testArgs(@Vector(2, i128), .{
                0x295f2901e3837e5592b9435f8c4df8a7,
                -0x1f246b0ff2d02a6bf30a63392fc63371,
            }, .{
                -0x31060c09e29b545670c4cbc721a4e26b,
                -0x631eb286321325d51c617aa798195392,
            });
            try testArgs(@Vector(4, i128), .{
                0x47110102c74f620f08e5b7c5dbe193c2,
                -0x61d12d2650413ad3ffeeeab3ba57e1f0,
                0x449781e64b29dc8a17a88f4b7a5b0717,
                0x0d2170e9238d12a585dc5377566e1938,
            }, .{
                0x0bf948e19bd01823dcb3887937d97079,
                -0x16f933ab12bfba3560d0d39ffe69b64a,
                0x3d0bfce3907a5cd157348f0329e2548e,
                -0x3c2d182e2e238a4bebd7defbd7f9699a,
            });
            try testArgs(@Vector(8, i128), .{
                -0x775678727c721662f02480619acbfc82,
                -0x6f504fcbff673cb91e4706af4373665f,
                -0x670f888d4186387c3106d125b856c294,
                0x0641e7efdfdd924d126b446d874154f8,
                0x57d7aef0f82d3351917f43c8f677392b,
                -0x4077e745dede8367d145c94f20ab8810,
                -0x0344a74fb60e1f1f72ba8ec288b05939,
                -0x0be3ce9be461aca1d25ad8e74dcc36e1,
            }, .{
                -0x4a873d91e5a2331def0d34c008d33d83,
                0x2744cecfd4c683bdd12f3cfc11d7f520,
                -0x0cb8e468fc1de93a7c5ad2a5a61e8f50,
                -0x1a3be9e58e918d6586cc4948a54515d3,
                -0x512ec6f88c3a34950a8aaee47130120b,
                -0x2e772e4a8812e553bcf9b2754a493709,
                0x0c7b137937dc25f9f9cbaf4d7a88ee6b,
                -0x2ecdd5eb81eb0e98ed8d0aa9516c1617,
            });

            try testArgs(@Vector(1, u128), .{
                0x5f11e16b0ca3392f907a857881455d2e,
            }, .{
                0xf9142d73b408fd6955922f9fc147f7d7,
            });
            try testArgs(@Vector(2, u128), .{
                0xee0fb41fabd805923fb21b5c658e3a87,
                0x2352e74aad6c58b3255ff0bba5aa6552,
            }, .{
                0x8d822f9fdd9cb9a5b43513b14419b224,
                0x1aef2a02704379e38ead4d53d69e4cc4,
            });
            try testArgs(@Vector(4, u128), .{
                0xc74437a4ea3bbbb193dbf0ea2f0c5281,
                0x039e4b1640868248780db1834a0027eb,
                0xb9e8bb34155b2b238da20331d08ff85b,
                0x863802d34a54c2e6aa71dd0f067c4904,
            }, .{
                0x7471bae24ff7b84ab107f86ba2b7d1e7,
                0x8f34c449d0576e682c20bda74aa6b6c9,
                0x1f34c3efa167b61c48c9d5ec01a1a93f,
                0x71c8318fcf3ddc7be058c73a52dce9e3,
            });
            try testArgs(@Vector(8, u128), .{
                0xbf2db71463037f55ee338431f902a906,
                0xb7ad317626655f38ab25ae30d8a1aa67,
                0x7d3c5a3ffaa607b5560d69ae3fcf7863,
                0x009a39a8badf8b628c686dc176aa1273,
                0x49dba3744c91304cc7bbbdab61b6c969,
                0x6ec664b624f7acf79ce69d80ed7bc85c,
                0xe02d7a303c0f00c39010f3b815547f1c,
                0xb13e1ee914616f58cffe6acd33d9b5c8,
            }, .{
                0x2f2d355a071942a7384f82ba72a945b8,
                0x61f151b3afec8cb7664f813cecf581d1,
                0x5bfbf5484f3a07f0eacc4739ff48af80,
                0x59c0abbf8d829cf525a87d5c9c41a38a,
                0xdad8b18eb680f0520ca49ebfb5842e22,
                0xa05adcaedd9057480b3ba0413d003cec,
                0x8b0b4a27fc94a0e90652d19bc755b63d,
                0xa858bce5ad0e48c13588a4e170e8667c,
            });

            try testArgs(@Vector(1, i256), .{
                0x1fe30aed39db1accf4d1b43845aec28c1094b500492555fdf59b4f2f85c6a1ce,
            }, .{
                0x6932f4faf261c45ecd701a4fe3015d4255e486b04c4ab448fe162980cead63fb,
            });
            try testArgs(@Vector(2, i256), .{
                -0x23daa9bab59dc1e685f4220c189930c3420a55784f0dec1028c2778d907ccfe2,
                0x521c992e4f46d61709d39e076ed94d5d884585f85ccbf71ca4d593da34f61bf5,
            }, .{
                0x2d880cb5aa793218a32411389db31e935932029645573a9625dd174099c9e5b2,
                0x2394a6cde7e8b2dc2995f07f22f815baa6c223d99c0b1ec4b2d8abd0094db853,
            });
            try testArgs(@Vector(4, i256), .{
                0x244e66ed932a4d970fd8735c10bfbd5f59bd4452c20fa0fcf873823b8c9e6321,
                -0x31577b747614b1ab83fd0178293cd80b3cb92e739459b2d038688a2471f6d659,
                -0x0dbdfc3d8bbd7cab6a33598cef29125aab7571fb0db9a528e42966963d6ce0e7,
                -0x72c58cce172d8a34019a44407a4baf1f8f8a4a611711bd5bb4daa2a2739dd67b,
            }, .{
                -0x2e88bc68893fc2d61af0e5ccb541f31fa6169504e8cfcbeab0b74a03b9e86c33,
                -0x7eba0783f3382b59a17ffbea57ba1dd8fa30e2d4f7eba7ed68d336d3c37b4561,
                -0x66d1463efd38e9e994e126d09b5c65c8efc932ffea9ec6cdf6042561ba05f801,
                0x2024bbacefbabbfd5b32a09be631451764a1f889a77918f9094382dc6d02aef2,
            });

            try testArgs(@Vector(1, u256), .{
                0x28df37e1f57a56133ba3f5b5b2164ce24eb6c29a8973a597fd91fbee8ab4bafb,
            }, .{
                0x63f725028cab082b5b1e6cb474428c8c3655cf438f3bb05c7a87f8270198f357,
            });
            try testArgs(@Vector(2, u256), .{
                0xcc79740b85597ef411e6d7e92049dfaa2328781ea4911540a3dcb512b71c7f3c,
                0x51ae46d2f93cbecff1578481f6ddc633dacee94ecaf81597c752c5c5db0ae766,
            }, .{
                0x257f0107305cb71cef582a9a58612a019f335e390d7998f51f5898f245874a6e,
                0x0a95a17323a4d16a715720f122b752785e9877e3dd3d3f9b72cdac3d1139a81f,
            });
            try testArgs(@Vector(4, u256), .{
                0x19667a6e269342cba437a8904c7ba42a762358d32723723ae2637b01124e63c5,
                0x14f7d3599a7edc7bcc46874f68d4291793e6ef72bd1f3763bc5e923f54f2f781,
                0x1c939de0ae980b80de773a04088ba45813441336cdfdc281ee356c98d71f653b,
                0x39f5d755965382fe13d1b1d6690b8e3827f153f8166768c4ad8a28a963b781f2,
            }, .{
                0xbe03de37cdcb8126083b4e86cd8a9803121d31b186fd5ce555ad77ce624dd6c7,
                0xa0c0730f0d7f141cc959849d09730b049f00693361539f1bc4758270554a60c1,
                0x2664bdba8de4eaa36ecee72f6bfec5b4daa6b4e00272d8116f2cc532c29490cc,
                0xe47a122bd45d5e7d69722d864a6b795ddee965a0993094f8791dd309d692de8b,
            });

            try testArgs(@Vector(1, i512), .{
                -0x439ba81b44584e0c4d7abc80d18ab9d679a4e921884e877b28d04eb15b2d3e7be8d670b0aba2c4cc25c12655e1899ab514d0a6e50a221bcf076d506e6411d5c2,
            }, .{
                0x18b1d3be5a03310d82859a4ab72f056a33d1a4b554522bcc062fb33eda3b8111045ee79e045dd1a665d250b897f6f2e12003a03313c2547698f8c1eab452eae1,
            });
            try testArgs(@Vector(2, i512), .{
                0x28e2ab84d87d5fb12be65d8650de67b992dd162fe563ca74b62f51f2f32e1084e03e32c8370930816445ac5052b4d345059c8ace582e3ef44377b160e265ec9b,
                -0x3a96548c707219326c42063997e71bc7a17b3067d402063843f84c86e747b71e09338079c28943d20601c0cde018bad57f5615fc89784bcb6232e45c54dff1db,
            }, .{
                0x64beecc90609b7156653b75a861e174c58fb42d5c7bf8d793efbb1cbe785c6b8cd52ce5f9aa859f174123c387820d40a2f93122b81396d739eb85c3ea33fcd37,
                -0x3632e347bc6d794940424ca0945dafa04328a924ec6b0ccdedcda6d296e09aa2dd5dca83b934cac752993238aa4fe826be8d62991c9347bae6f01bc0b1b4223d,
            });

            try testArgs(@Vector(1, u512), .{
                0x651058c1d89a8f34cfc5e66b6d25294eecfcc4a7e1e4a356eb51ee7d7b2db25378e4afee51b7d18d16e520772a60c50a02d7966f40ced1870b32c658e5821397,
            }, .{
                0xd726e265ec80cb99510ba4f480ca64e959de5c528a7f54c386ecad22eeeefa845f0fd44b1bd64258a5f868197ee2d8fed59df9c9f0b72e74051a7ff20230880e,
            });
            try testArgs(@Vector(2, u512), .{
                0x22c8183c95cca8b09fdf541e431b73e9e4a1a5a00dff12381937fab52681d09d38ea25727d7025a2be08942cfa01535759e1644792e347c7901ec94b343c6337,
                0x292fdf644e75927e1aea9465ae2f60fb27550cd095f1afdea2cf7855286d26fbeed1c0b9c0474b73cb6b75621f7eadaa2f94ec358179ce2aaa0766df20da1ef3,
            }, .{
                0xe1cd8c0ca244c6626d4415e10b4ac43fa69e454c529c24fec4b13e6b945684d4ea833709c16c636ca78cffa5c5bf0fe945cd714a9ad695184a6bdad31dec9e31,
                0x8fa3d86099e9e2789d72f8e792290356d659ab20ac0414ff94745984c6ae7d986082197bb849889f912e896670aa2c1a11bd7e66e3f650710b0f0a18a1533f90,
            });

            try testArgs(@Vector(1, i1024), .{
                -0x4fe568569c0531c9bfbbda1516e93a6c61a3d035c98e13fdc85225165a3bea84d5dc6b610ced008f9321453af42ea50bbf6881d40d2759b73b9b6186c0d6d243f367e292cbbf6b5c5c30d7f4e8de19701c7b0fc9e67cdf31228daa1675a4887f6c4f1588b48855d6f4730a21f27dec8a756c568727709b65cd531020d53ff394,
            }, .{
                -0x7cab2a053dfbf944cd342460350c989fd1b4469a6c7b54ddcacd54e605d29c03651b5c463495610d82269c9ac5b51bfd07816a0f7b1ab50cb598989ed64607b3faff79a190702eb285b0fedc050ec1a71537abc47ec590eb671d4f76b19567049ba4789d1a4348385607a0320fbff9b78260536a9b6030bddb0b09da689d1687,
            });

            try testArgs(@Vector(1, u1024), .{
                0x0ca1a0dfaf8bb1da714b457d23c71aef948e66c7cd45c0aa941498a796fb18502ec32f34e885d0a107d44ae81595f8b52c2f0fb38e584b7139903a0e8a823ae20d01ca0662722dd474e7efc40f32d74cc065d97d8a09d0447f1ab6107fa0a57f3f8c866ae872506627ce82f18add79cee8dc69837f4ead3ca770c4d622d7e544,
            }, .{
                0xf1e3bbe031d59351770a7a501b6e969b2c00d144f17648db3f944b69dfeb7be72e5ff933a061eba4eaa422f8ca09e5a97d0b0dd740fd4076eba8c72d7a278523f399202dc2d043c4e0eb58a2bcd4066e2146e321810b1ee4d3afdddb4f026bcc7905ce17e033a7727b4e08f33b53c63d8c9f763fc6c31d0523eb38c30d5e40bc,
            });
        }
        fn testFloatVectors() !void {
            @setEvalBranchQuota(21_700);

            try testArgs(@Vector(1, f16), .{
                -tmin(f16),
            }, .{
                fmax(f16),
            });
            try testArgs(@Vector(2, f16), .{
                1e-1, 1e0,
            }, .{
                -nan(f16), -fmin(f16),
            });
            try testArgs(@Vector(4, f16), .{
                1e-1, -fmax(f16), 0.0, 1e-1,
            }, .{
                -fmin(f16), -1e1, 1e0, -tmin(f16),
            });
            try testArgs(@Vector(8, f16), .{
                -fmax(f16), -fmin(f16), -nan(f16), -0.0, tmin(f16), -0.0, 0.0, 1e-1,
            }, .{
                -1e0, tmin(f16), nan(f16), nan(f16), -fmax(f16), -1e1, -nan(f16), 1e1,
            });
            try testArgs(@Vector(16, f16), .{
                1e-1, fmax(f16), -1e1, fmax(f16), -1e1, 1e-1, -tmin(f16), -inf(f16), -tmin(f16), -1e0, -fmin(f16), tmin(f16), 1e1, -fmax(f16), 0.0, -fmin(f16),
            }, .{
                inf(f16), -1e1, -fmax(f16), fmax(f16), -tmin(f16), 0.0, -1e0, -1e0, 1e-1, -nan(f16), -tmin(f16), 1e0, 1e-1, fmax(f16), -0.0, inf(f16),
            });
            try testArgs(@Vector(32, f16), .{
                -inf(f16), tmin(f16), fmin(f16), -nan(f16),  nan(f16),  1e-1,     0.0,        1e1,  -tmin(f16), inf(f16), 1e0,       -1e1, fmin(f16),  -0.0, 1e0,      -fmax(f16),
                1e1,       -0.0,      -1e1,      -tmin(f16), fmax(f16), nan(f16), -fmin(f16), -1e0, 0.0,        -1e1,     -nan(f16), 1e0,  -tmin(f16), -0.0, nan(f16), 1e1,
            }, .{
                0.0,      1e1,  -nan(f16), -0.0, tmin(f16),  fmax(f16), nan(f16),  tmin(f16), -1e1,       1e-1,      1e1, fmin(f16), -fmax(f16), inf(f16),   inf(f16),   -tmin(f16),
                inf(f16), -0.0, 1e-1,      0.0,  -fmin(f16), -0.0,      -nan(f16), -inf(f16), -fmin(f16), fmax(f16), 1e0, fmin(f16), -0.0,       -tmin(f16), -fmax(f16), -1e1,
            });
            try testArgs(@Vector(64, f16), .{
                -nan(f16), fmin(f16),  -inf(f16),  inf(f16),  -tmin(f16), inf(f16),   1e-1,      -1e0,      -inf(f16), nan(f16),  -fmin(f16), 1e-1,     -tmin(f16), -fmax(f16), -1e1,     inf(f16),
                0.0,       -fmin(f16), -fmax(f16), 1e1,       -fmax(f16), fmax(f16),  1e1,       fmin(f16), -inf(f16), -nan(f16), -tmin(f16), nan(f16), -0.0,       0.0,        1e-1,     -fmin(f16),
                0.0,       nan(f16),   inf(f16),   fmax(f16), nan(f16),   tmin(f16),  1e0,       tmin(f16), fmin(f16), -1e1,      0.0,        1e-1,     inf(f16),   -1e1,       inf(f16), 1e0,
                1e-1,      -inf(f16),  1e1,        -0.0,      -1e0,       -tmin(f16), -nan(f16), 1e-1,      1e-1,      -nan(f16), -0.0,       -1e1,     -0.0,       -nan(f16),  1e-1,     fmin(f16),
            }, .{
                1e1,        0.0,       fmax(f16), -inf(f16),  -fmax(f16), -fmax(f16), tmin(f16), -1e0,       -tmin(f16), -1e1, nan(f16), -nan(f16), tmin(f16),  -fmin(f16), nan(f16), -1e1,
                1e1,        fmax(f16), 1e-1,      0.0,        1e-1,       -fmax(f16), -0.0,      -fmin(f16), inf(f16),   -1e0, inf(f16), fmin(f16), -inf(f16),  -tmin(f16), 1e1,      1e1,
                1e-1,       1e-1,      1e-1,      1e1,        -fmin(f16), inf(f16),   1e-1,      fmax(f16),  inf(f16),   -0.0, -1e1,     tmin(f16), -fmin(f16), 0.0,        1e1,      0.0,
                -tmin(f16), -inf(f16), 1e0,       -fmax(f16), inf(f16),   1e1,        fmax(f16), -1e0,       0.0,        1e-1, -1e0,     -inf(f16), 1e-1,       0.0,        -1e1,     fmax(f16),
            });
            try testArgs(@Vector(128, f16), .{
                -fmin(f16), 1e0,        0.0,       1e-1,      nan(f16),   1e-1,       1e-1,      -inf(f16),  -tmin(f16), 1e0,        -fmin(f16), -fmax(f16), -1e0,      -fmin(f16), 1e1,        -nan(f16),
                inf(f16),   -inf(f16),  tmin(f16), -1e1,      -1e0,       -0.0,       -0.0,      1e0,        nan(f16),   -1e1,       fmin(f16),  -tmin(f16), tmin(f16), 1e-1,       -fmax(f16), fmax(f16),
                tmin(f16),  -fmin(f16), nan(f16),  1e1,       1e0,        -fmin(f16), 1e-1,      1e1,        fmax(f16),  fmax(f16),  fmax(f16),  -1e0,       -nan(f16), 1e1,        tmin(f16),  -nan(f16),
                -nan(f16),  -inf(f16),  -0.0,      -inf(f16), nan(f16),   -1e0,       1e-1,      -fmax(f16), -1e1,       nan(f16),   1e0,        -1e1,       tmin(f16), 1e0,        1e-1,       1e0,
                1e1,        1e-1,       tmin(f16), nan(f16),  -inf(f16),  -1e0,       -1e0,      -fmax(f16), -inf(f16),  1e-1,       1e-1,       -0.0,       1e1,       fmin(f16),  -1e0,       inf(f16),
                1e-1,       -1e1,       inf(f16),  -0.0,      1e-1,       0.0,        inf(f16),  1e0,        tmin(f16),  -tmin(f16), 1e-1,       inf(f16),   tmin(f16), -inf(f16),  1e1,        1e0,
                -inf(f16),  1e-1,       1e0,       fmax(f16), -fmin(f16), nan(f16),   -nan(f16), fmin(f16),  -1e0,       -fmax(f16), inf(f16),   -fmax(f16), 0.0,       -1e1,       fmin(f16),  -fmax(f16),
                -0.0,       -1e0,       1e-1,      1e1,       inf(f16),   fmax(f16),  inf(f16),  1e1,        fmax(f16),  -0.0,       -tmin(f16), fmin(f16),  inf(f16),  nan(f16),   -fmin(f16), -1e0,
            }, .{
                -fmax(f16), fmax(f16),  inf(f16),  1e0,        nan(f16),  1e-1,      -fmax(f16), 1e1,        -fmin(f16), 1e-1,       fmin(f16),  -0.0,      1e-1,       -0.0,      -nan(f16),  -nan(f16),
                inf(f16),   1e0,        -1e0,      1e-1,       1e-1,      1e-1,      0.0,        -tmin(f16), -1e0,       -1e1,       -tmin(f16), 1e0,       -1e1,       fmin(f16), -fmax(f16), -nan(f16),
                -tmin(f16), -inf(f16),  inf(f16),  -fmin(f16), -nan(f16), 0.0,       -inf(f16),  -fmax(f16), 1e-1,       -inf(f16),  tmin(f16),  nan(f16),  tmin(f16),  fmin(f16), -0.0,       1e-1,
                fmin(f16),  fmin(f16),  1e0,       tmin(f16),  0.0,       1e1,       1e-1,       inf(f16),   1e1,        -tmin(f16), tmin(f16),  -1e0,      -fmin(f16), 1e0,       nan(f16),   -fmax(f16),
                nan(f16),   -fmin(f16), 1e-1,      1e1,        -1e1,      1e0,       -0.0,       tmin(f16),  nan(f16),   inf(f16),   -fmax(f16), tmin(f16), -tmin(f16), 1e1,       fmin(f16),  -tmin(f16),
                -0.0,       1e0,        tmin(f16), fmax(f16),  1e0,       -inf(f16), -nan(f16),  -0.0,       1e-1,       -inf(f16),  1e-1,       fmax(f16), -inf(f16),  -nan(f16), -1e0,       -inf(f16),
                1e-1,       fmin(f16),  -1e1,      -tmin(f16), 1e0,       -nan(f16), -fmax(f16), -1e1,       -tmin(f16), 1e1,        nan(f16),   fmin(f16), fmax(f16),  tmin(f16), -inf(f16),  1e0,
                -fmin(f16), tmin(f16),  -1e0,      1e-1,       0.0,       nan(f16),  1e0,        fmax(f16),  -1e0,       1e1,        nan(f16),   1e0,       fmin(f16),  1e0,       -1e1,       -1e1,
            });
            try testArgs(@Vector(69, f16), .{
                -nan(f16), -1e0,      -fmin(f16), fmin(f16), inf(f16),  1e-1,      0.0,       fmax(f16),  tmin(f16), 1e-1,      0.0,        -tmin(f16), 0.0,        0.0,        1e0,        -inf(f16),
                tmin(f16), -inf(f16), -tmin(f16), fmin(f16), -inf(f16), -nan(f16), tmin(f16), -tmin(f16), 1e-1,      -1e0,      -tmin(f16), fmax(f16),  nan(f16),   -fmin(f16), fmin(f16),  1e1,
                fmin(f16), -1e1,      0.0,        fmin(f16), fmax(f16), -nan(f16), fmax(f16), -fmax(f16), nan(f16),  -nan(f16), fmin(f16),  -1e1,       -fmin(f16), fmin(f16),  -fmin(f16), -nan(f16),
                0.0,       -1e0,      fmax(f16),  1e-1,      inf(f16),  1e0,       -1e0,      -0.0,       1e1,       1e-1,      -fmax(f16), tmin(f16),  -inf(f16),  tmin(f16),  -fmax(f16), 1e-1,
                -1e1,      -0.0,      -fmax(f16), nan(f16),  fmax(f16),
            }, .{
                inf(f16),   -fmin(f16), 1e-1,      1e-1,      -0.0,       fmax(f16),  1e-1,      -0.0,      0.0,       -0.0,       0.0,       -tmin(f16), tmin(f16), -1e0,     nan(f16),   -fmin(f16),
                fmin(f16),  1e-1,       1e-1,      nan(f16),  -fmax(f16), -inf(f16),  -nan(f16), -nan(f16), 1e-1,      -fmax(f16), fmin(f16), 1e-1,       1e-1,      1e-1,     -0.0,       1e1,
                tmin(f16),  -nan(f16),  fmin(f16), -1e0,      1e0,        -tmin(f16), 0.0,       nan(f16),  fmax(f16), -1e1,       fmin(f16), -fmin(f16), -1e0,      1e-1,     -fmin(f16), -fmin(f16),
                -fmax(f16), 0.0,        fmin(f16), -1e1,      -1e0,       -1e0,       fmax(f16), -nan(f16), -inf(f16), -inf(f16),  0.0,       tmin(f16),  -0.0,      nan(f16), -inf(f16),  nan(f16),
                inf(f16),   fmin(f16),  -nan(f16), -inf(f16), inf(f16),
            });

            try testArgs(@Vector(1, f32), .{
                fmin(f32),
            }, .{
                -tmin(f32),
            });
            try testArgs(@Vector(2, f32), .{
                nan(f32), -1e1,
            }, .{
                -tmin(f32), fmin(f32),
            });
            try testArgs(@Vector(4, f32), .{
                fmax(f32), -fmax(f32), -1e1, 0.0,
            }, .{
                inf(f32), inf(f32), -1e1, inf(f32),
            });
            try testArgs(@Vector(8, f32), .{
                -1e1, fmax(f32), inf(f32), -0.0, -tmin(f32), -tmin(f32), 1e1, 1e-1,
            }, .{
                1e1, -1e0, -1e0, inf(f32), 1e0, -tmin(f32), nan(f32), 1e1,
            });
            try testArgs(@Vector(16, f32), .{
                1e-1, 1e-1, -nan(f32), -1e1, -nan(f32), 0.0, fmin(f32), fmin(f32), -1e1, 1e0, -fmax(f32), -0.0, inf(f32), -0.0, fmax(f32), -fmin(f32),
            }, .{
                nan(f32), 0.0, tmin(f32), -1e0, -1e1, -tmin(f32), fmin(f32), -fmax(f32), 1e-1, 1e-1, -inf(f32), tmin(f32), -0.0, 1e1, -0.0, -inf(f32),
            });
            try testArgs(@Vector(32, f32), .{
                1e-1,       tmin(f32), -1e0,       1e0,       tmin(f32), -1e1,      fmax(f32), 0.0,       tmin(f32),  1e-1,      -1e0,     fmax(f32),  -nan(f32), -0.0,      fmin(f32), 0.0,
                -fmax(f32), fmax(f32), -fmin(f32), -inf(f32), tmin(f32), -nan(f32), -1e0,      tmin(f32), -fmin(f32), -inf(f32), nan(f32), -tmin(f32), inf(f32),  -inf(f32), -nan(f32), 1e-1,
            }, .{
                -fmin(f32), -1e0,      fmax(f32), inf(f32),   -fmin(f32), fmax(f32),  0.0,       -1e1, 0.0,  1e-1,      fmin(f32), -inf(f32),  1e0, -nan(f32), -nan(f32),
                -inf(f32),  -0.0,      nan(f32),  -fmax(f32), 1e1,        -tmin(f32), fmax(f32), -1e1, 1e-1, tmin(f32), 1e-1,      -fmax(f32), 0.0, 1e-1,      -nan(f32),
                -fmin(f32), fmax(f32),
            });
            try testArgs(@Vector(64, f32), .{
                fmin(f32),  0.0,  -inf(f32), 1e-1,      -1e1,      -fmin(f32), 1e1,        nan(f32),  1e-1,       1e0,       -1e0,      1e1,        1e1,       1e-1,       -fmax(f32), -1e0,
                -fmin(f32), 1e-1, -inf(f32), -inf(f32), 1e-1,      1e-1,       0.0,        -1e0,      nan(f32),   -0.0,      -0.0,      -fmin(f32), -inf(f32), inf(f32),   tmin(f32),  -nan(f32),
                1e-1,       0.0,  1e0,       tmin(f32), 1e1,       fmin(f32),  -fmin(f32), fmax(f32), nan(f32),   1e0,       -nan(f32), -nan(f32),  1e0,       nan(f32),   1e0,        fmax(f32),
                -0.0,       0.0,  inf(f32),  nan(f32),  tmin(f32), 0.0,        fmin(f32),  -0.0,      -fmin(f32), tmin(f32), -1e0,      -1e1,       1e-1,      -tmin(f32), -inf(f32),  -1e0,
            }, .{
                nan(f32),   -nan(f32),  -tmin(f32), inf(f32),   -inf(f32), 1e-1,      1e-1,       1e-1,       -1e0,       -inf(f32),  -0.0,     fmax(f32), tmin(f32), -nan(f32),  -fmax(f32), -1e0,
                -fmin(f32), -0.0,       fmax(f32),  -fmax(f32), 1e0,       -0.0,      0.0,        1e1,        -1e0,       -fmin(f32), 0.0,      fmax(f32), 1e-1,      1e0,        1e1,        1e-1,
                1e-1,       fmin(f32),  -nan(f32),  -inf(f32),  -0.0,      -inf(f32), 1e-1,       -fmax(f32), -1e1,       -1e1,       nan(f32), 1e1,       -1e0,      -fmin(f32), 1e1,        fmin(f32),
                1e0,        -fmax(f32), nan(f32),   inf(f32),   fmax(f32), fmax(f32), -fmin(f32), -inf(f32),  -tmin(f32), -nan(f32),  nan(f32), nan(f32),  1e-1,      1e-1,       -1e0,       inf(f32),
            });
            try testArgs(@Vector(128, f32), .{
                -1e1,       -nan(f32),  inf(f32),   inf(f32),  -tmin(f32), -0.0,       0.0,        1e-1,       -0.0,       fmin(f32),  nan(f32),   -1e0,       nan(f32),   -fmax(f32), nan(f32),   0.0,
                1e0,        -tmin(f32), 0.0,        -nan(f32), 1e-1,       1e-1,       -1e0,       1e1,        -fmax(f32), -fmin(f32), 1e-1,       nan(f32),   1e-1,       -fmax(f32), -tmin(f32), -inf(f32),
                inf(f32),   tmin(f32),  -tmin(f32), nan(f32),  -inf(f32),  -1e1,       1e0,        -nan(f32),  1e-1,       nan(f32),   -1e0,       tmin(f32),  -fmin(f32), -0.0,       -0.0,       1e0,
                fmin(f32),  -fmin(f32), 1e-1,       1e-1,      1e-1,       -1e1,       -1e1,       -tmin(f32), 1e0,        -0.0,       1e1,        -fmax(f32), 1e1,        -fmax(f32), inf(f32),   -1e0,
                -fmax(f32), fmin(f32),  fmin(f32),  fmin(f32), -1e0,       -nan(f32),  fmax(f32),  -nan(f32),  1e-1,       -1e0,       -fmax(f32), -tmin(f32), -0.0,       fmax(f32),  -1e1,       inf(f32),
                1e1,        -inf(f32),  1e-1,       fmin(f32), nan(f32),   -fmax(f32), -tmin(f32), inf(f32),   tmin(f32),  -fmin(f32), fmax(f32),  1e0,        fmin(f32),  -0.0,       1e-1,       fmin(f32),
                1e-1,       inf(f32),   -1e1,       inf(f32),  1e1,        tmin(f32),  0.0,        1e0,        inf(f32),   -1e1,       -fmin(f32), tmin(f32),  1e0,        1e-1,       1e-1,       -fmin(f32),
                1e1,        1e-1,       fmax(f32),  fmin(f32), 1e0,        -1e1,       -inf(f32),  -1e1,       0.0,        -fmax(f32), -inf(f32),  -1e0,       fmax(f32),  -tmin(f32), inf(f32),   nan(f32),
            }, .{
                -tmin(f32), -fmax(f32), -fmax(f32), 1e1,        inf(f32),  1e-1,     1e0,        fmin(f32),  1e-1,       1e1,        fmin(f32),  -fmax(f32), 1e0,        fmax(f32),  1e-1,       -fmin(f32),
                0.0,        -0.0,       -0.0,       -1e0,       -nan(f32), nan(f32), -tmin(f32), 1e1,        -tmin(f32), -1e1,       inf(f32),   0.0,        tmin(f32),  0.0,        -fmax(f32), inf(f32),
                fmin(f32),  1e-1,       -1e1,       tmin(f32),  tmin(f32), 1e-1,     fmin(f32),  -tmin(f32), fmin(f32),  nan(f32),   1e-1,       -fmax(f32), -1e0,       -0.0,       fmin(f32),  -0.0,
                -1e0,       -0.0,       -inf(f32),  fmax(f32),  -1e1,      1e0,      inf(f32),   -1e0,       -tmin(f32), -tmin(f32), 1e-1,       -1e1,       -fmin(f32), 1e1,        -1e1,       -inf(f32),
                -1e0,       inf(f32),   1e-1,       1e0,        -nan(f32), 1e-1,     -1e1,       -nan(f32),  -tmin(f32), 0.0,        fmin(f32),  -nan(f32),  fmax(f32),  -tmin(f32), 0.0,        0.0,
                -fmax(f32), -inf(f32),  -1e0,       -0.0,       1e1,       nan(f32), 1e-1,       tmin(f32),  -1e1,       1e1,        tmin(f32),  -fmax(f32), 1e-1,       -1e1,       -tmin(f32), fmax(f32),
                -fmax(f32), 1e-1,       -nan(f32),  -fmin(f32), inf(f32),  inf(f32), tmin(f32),  tmin(f32),  -tmin(f32), tmin(f32),  0.0,        -0.0,       1e0,        1e1,        -1e1,       inf(f32),
                0.0,        -fmin(f32), fmax(f32),  -1e1,       fmax(f32), -0.0,     0.0,        -fmin(f32), 1e1,        -fmin(f32), -fmin(f32), -fmin(f32), 1e1,        fmin(f32),  -inf(f32),  fmax(f32),
            });
            try testArgs(@Vector(69, f32), .{
                nan(f32),   1e-1,      -tmin(f32), fmax(f32),  nan(f32),  -fmax(f32), 1e-1,       fmax(f32), 1e1,        inf(f32), -fmin(f32), -fmax(f32), inf(f32),   -nan(f32),  1e-1,       1e0,
                fmax(f32),  1e-1,      1e1,        0.0,        -1e1,      fmax(f32),  1e1,        0.0,       1e0,        1e1,      -fmax(f32), 0.0,        -tmin(f32), -fmin(f32), 1e-1,       1e0,
                fmin(f32),  tmin(f32), -fmin(f32), -tmin(f32), tmin(f32), -inf(f32),  -fmax(f32), -0.0,      -1e0,       -0.0,     -fmax(f32), fmax(f32),  fmin(f32),  -0.0,       0.0,        -inf(f32),
                -tmin(f32), inf(f32),  -nan(f32),  tmin(f32),  -1e0,      -tmin(f32), 1e1,        -inf(f32), -fmin(f32), 1e-1,     -inf(f32),  -1e0,       nan(f32),   -inf(f32),  -tmin(f32), 1e1,
                1e1,        -nan(f32), -nan(f32),  tmin(f32),  -nan(f32),
            }, .{
                -nan(f32), 1e0,       fmax(f32), 1e-1,       -0.0,       1e0,       -inf(f32), -fmin(f32), -nan(f32), inf(f32),   1e0,       -nan(f32), -nan(f32), -inf(f32), tmin(f32), -fmin(f32),
                -nan(f32), 1e-1,      fmin(f32), -1e0,       -fmax(f32), 1e-1,      -1e0,      1e-1,       1e-1,      -tmin(f32), 1e-1,      1e-1,      1e1,       fmin(f32), 0.0,       nan(f32),
                tmin(f32), 1e0,       nan(f32),  -fmin(f32), tmin(f32),  nan(f32),  1e-1,      nan(f32),   1e0,       -fmax(f32), tmin(f32), 1e0,       0.0,       -1e0,      nan(f32),  fmin(f32),
                -inf(f32), fmax(f32), -0.0,      nan(f32),   tmin(f32),  tmin(f32), -inf(f32), -1e1,       -nan(f32), -fmax(f32), -0.0,      1e-1,      -inf(f32), 1e0,       nan(f32),  1e0,
                -1e1,      fmin(f32), inf(f32),  fmin(f32),  0.0,
            });

            try testArgs(@Vector(1, f64), .{
                -0.0,
            }, .{
                1e0,
            });
            try testArgs(@Vector(2, f64), .{
                -1e0, 0.0,
            }, .{
                -inf(f64), -fmax(f64),
            });
            try testArgs(@Vector(4, f64), .{
                -inf(f64), inf(f64), 1e1, 0.0,
            }, .{
                -tmin(f64), 1e0, nan(f64), 0.0,
            });
            try testArgs(@Vector(8, f64), .{
                1e-1, -tmin(f64), -fmax(f64), 1e0, inf(f64), -1e1, -tmin(f64), -1e1,
            }, .{
                tmin(f64), fmin(f64), 1e-1, 1e1, -0.0, -0.0, fmax(f64), -1e0,
            });
            try testArgs(@Vector(16, f64), .{
                1e-1, -nan(f64), 1e0, tmin(f64), fmax(f64), -fmax(f64), -tmin(f64), -0.0, -fmin(f64), -1e0, -fmax(f64), -nan(f64), -fmax(f64), nan(f64), -0.0, 1e-1,
            }, .{
                -1e0, -tmin(f64), -fmin(f64), 1e-1, 1e-1, -0.0, -nan(f64), -inf(f64), -inf(f64), -0.0, nan(f64), tmin(f64), 1e0, 1e-1, tmin(f64), fmin(f64),
            });
            try testArgs(@Vector(32, f64), .{
                -fmax(f64), fmin(f64), 1e-1, 1e-1,      0.0,       1e0,  -0.0, -tmin(f64), tmin(f64), inf(f64),  -tmin(f64), -tmin(f64), -tmin(f64), -fmax(f64), fmin(f64), 1e0,
                -fmin(f64), -nan(f64), 1e0,  -inf(f64), -nan(f64), -1e0, 0.0,  0.0,        nan(f64),  -nan(f64), -fmin(f64), fmin(f64),  1e-1,       nan(f64),   tmin(f64), -fmax(f64),
            }, .{
                -tmin(f64), -fmax(f64), -inf(f64),  -nan(f64), fmin(f64), -inf(f64), 1e-1,     -fmax(f64), -inf(f64), fmin(f64), inf(f64), -1e0, -tmin(f64), inf(f64), 1e-1, nan(f64),
                fmin(f64),  1e1,        -tmin(f64), -nan(f64), -inf(f64), 1e0,       nan(f64), -fmin(f64), -1e0,      nan(f64),  -1e0,     0.0,  1e0,        nan(f64), -1e0, -fmin(f64),
            });
            try testArgs(@Vector(64, f64), .{
                -1e1,      fmax(f64),  -nan(f64),  tmin(f64),  1e-1,      -1e0,       1e0,      -0.0,      -fmin(f64), 1e-1,      -fmin(f64), -0.0,      -0.0,      tmin(f64), -1e1,      1e-1,
                -1e1,      -fmax(f64), -1e1,       -fmin(f64), 0.0,       -1e1,       nan(f64), 1e0,       inf(f64),   inf(f64),  -inf(f64),  tmin(f64), tmin(f64), 1e-1,      -0.0,      1e-1,
                -0.0,      1e-1,       -1e1,       1e1,        fmax(f64), -fmin(f64), 1e0,      fmax(f64), 1e0,        -1e1,      fmin(f64),  fmax(f64), -1e0,      -0.0,      -0.0,      fmax(f64),
                -inf(f64), -inf(f64),  -tmin(f64), -fmax(f64), -nan(f64), tmin(f64),  -1e0,     0.0,       -inf(f64),  fmax(f64), nan(f64),   -inf(f64), fmin(f64), -nan(f64), -nan(f64), -1e1,
            }, .{
                nan(f64),  -1e0, 0.0,       -1e1,       -fmax(f64), -fmin(f64), -nan(f64),  -tmin(f64), 1e-1,       -1e0,      -nan(f64),  -fmax(f64), 0.0,       0.0,      1e1,       inf(f64),
                fmin(f64), 0.0,  -1e1,      1e0,        -tmin(f64), -inf(f64),  -fmax(f64), 0.0,        -fmin(f64), -1e0,      -fmin(f64), tmin(f64),  1e0,       -1e1,     fmin(f64), 1e-1,
                inf(f64),  -0.0, tmin(f64), -fmax(f64), -tmin(f64), -fmax(f64), fmin(f64),  -fmax(f64), 1e-1,       1e0,       1e0,        0.0,        fmin(f64), nan(f64), -1e1,      tmin(f64),
                inf(f64),  1e-1, 1e0,       -nan(f64),  1e0,        -fmin(f64), fmax(f64),  inf(f64),   fmin(f64),  -inf(f64), -0.0,       0.0,        -1e0,      -0.0,     1e-1,      1e-1,
            });
            try testArgs(@Vector(128, f64), .{
                nan(f64),   -fmin(f64), fmax(f64),  fmin(f64), -1e1,       nan(f64),  tmin(f64), fmax(f64),  inf(f64),   -nan(f64),  tmin(f64),  -nan(f64), -0.0,       fmin(f64),  fmax(f64),
                -inf(f64),  inf(f64),   -1e0,       0.0,       1e-1,       fmin(f64), 0.0,       1e-1,       -1e0,       -inf(f64),  1e-1,       fmax(f64), fmin(f64),  fmax(f64),  -fmax(f64),
                fmin(f64),  inf(f64),   -fmin(f64), -1e1,      -0.0,       1e-1,      nan(f64),  -fmax(f64), -fmax(f64), -1e0,       1e1,        1e1,       -1e0,       -inf(f64),  inf(f64),
                -fmin(f64), 1e0,        -inf(f64),  -1e1,      1e-1,       1e0,       1e1,       1e1,        tmin(f64),  nan(f64),   inf(f64),   0.0,       -1e0,       -1e1,       1e0,
                -tmin(f64), -fmax(f64), -nan(f64),  1e1,       1e-1,       tmin(f64), 0.0,       1e1,        1e-1,       -tmin(f64), -tmin(f64), 1e0,       -fmax(f64), nan(f64),   -fmin(f64),
                nan(f64),   1e1,        -1e0,       -0.0,      -tmin(f64), nan(f64),  1e1,       1e1,        -inf(f64),  1e-1,       -nan(f64),  -1e1,      -tmin(f64), -fmax(f64), -fmax(f64),
                inf(f64),   -inf(f64),  tmin(f64),  1e0,       -inf(f64),  -1e1,      inf(f64),  1e-1,       -nan(f64),  -inf(f64),  fmax(f64),  1e-1,      -inf(f64),  1e-1,       1e0,
                1e-1,       1e-1,       1e-1,       inf(f64),  -inf(f64),  1e0,       1e1,       1e1,        nan(f64),   1e1,        -tmin(f64), 1e0,       -fmin(f64), -1e0,       -fmax(f64),
                -fmin(f64), -fmin(f64), -1e0,       inf(f64),  nan(f64),   tmin(f64), 1e-1,      -1e0,
            }, .{
                0.0,       0.0,        inf(f64),  -0.0,       1e-1,       -nan(f64),  1e1,        -nan(f64), tmin(f64),  -1e1,       -0.0,      inf(f64),   -fmin(f64), 1e-1,       fmax(f64),
                nan(f64),  -tmin(f64), tmin(f64), 1e0,        1e-1,       -1e1,       -nan(f64),  1e0,       inf(f64),   -1e1,       fmin(f64), 1e-1,       1e1,        -1e1,       1e1,
                -nan(f64), -nan(f64),  1e-1,      0.0,        1e1,        -fmax(f64), -tmin(f64), tmin(f64), -1e0,       -tmin(f64), -1e1,      1e-1,       -fmax(f64), 1e1,        nan(f64),
                fmax(f64), -1e0,       -1e0,      -tmin(f64), fmax(f64),  -1e1,       1e-1,       1e0,       fmin(f64),  inf(f64),   1e-1,      tmin(f64),  1e-1,       -fmax(f64), fmax(f64),
                -1e1,      -fmax(f64), fmax(f64), tmin(f64),  -fmin(f64), inf(f64),   1e-1,       -0.0,      fmax(f64),  tmin(f64),  1e-1,      1e0,        -inf(f64),  1e0,        1e1,
                1e-1,      0.0,        -1e1,      -nan(f64),  1e1,        -fmin(f64), -tmin(f64), 1e1,       1e0,        -tmin(f64), -1e0,      -fmin(f64), -0.0,       -1e1,       1e-1,
                inf(f64),  -fmax(f64), 1e-1,      tmin(f64),  -0.0,       fmax(f64),  0.0,        -nan(f64), -fmin(f64), fmax(f64),  -0.0,      nan(f64),   -inf(f64),  tmin(f64),  1e-1,
                inf(f64),  0.0,        1e1,       -fmax(f64), tmin(f64),  -0.0,       fmin(f64),  -nan(f64), -1e1,       -inf(f64),  nan(f64),  inf(f64),   -0.0,       1e1,        fmax(f64),
                tmin(f64), -1e1,       -nan(f64), 1e1,        -inf(f64),  -fmax(f64), -inf(f64),  -1e0,
            });
            try testArgs(@Vector(69, f64), .{
                inf(f64),   -0.0,      -fmax(f64), fmax(f64),  fmax(f64), 0.0,      fmin(f64), -nan(f64), 1e-1,      1e-1,      1e-1,       -fmin(f64), inf(f64),   1e-1,      fmax(f64),  nan(f64),
                tmin(f64),  -1e1,      1e1,        -tmin(f64), -0.0,      nan(f64), -1e1,      fmin(f64), 0.0,       -0.0,      1e-1,       inf(f64),   -tmin(f64), -nan(f64), inf(f64),   -nan(f64),
                -inf(f64),  fmax(f64), 1e-1,       -fmin(f64), 1e-1,      -1e0,     fmin(f64), fmin(f64), fmin(f64), 1e1,       -fmin(f64), nan(f64),   0.0,        0.0,       1e1,        nan(f64),
                -tmin(f64), tmin(f64), tmin(f64),  fmin(f64),  -0.0,      -1e0,     1e-1,      1e0,       fmax(f64), tmin(f64), fmin(f64),  0.0,        -fmin(f64), fmin(f64), -tmin(f64), 0.0,
                -nan(f64),  1e1,       -1e0,       1e-1,       0.0,
            }, .{
                -1e1,       -0.0,       fmin(f64), -fmin(f64), nan(f64),  1e1,      -tmin(f64), -fmax(f64), 1e1,       1e-1,     -fmin(f64), inf(f64),  -inf(f64),  -tmin(f64), 1e0,        tmin(f64),
                -tmin(f64), -nan(f64),  fmax(f64), 0.0,        -1e0,      1e1,      inf(f64),   fmin(f64),  fmax(f64), 1e-1,     1e-1,       fmax(f64), -inf(f64),  1e-1,       1e-1,       fmin(f64),
                1e-1,       fmin(f64),  -1e1,      nan(f64),   0.0,       0.0,      fmax(f64),  -inf(f64),  tmin(f64), inf(f64), -tmin(f64), fmax(f64), -inf(f64),  -1e1,       -1e0,       fmin(f64),
                1e-1,       -nan(f64),  fmax(f64), -fmin(f64), fmax(f64), nan(f64), -0.0,       -fmax(f64), 1e1,       nan(f64), inf(f64),   -1e0,      -fmin(f64), nan(f64),   -fmin(f64), -0.0,
                -nan(f64),  -fmin(f64), 1e-1,      nan(f64),   1e-1,
            });

            try testArgs(@Vector(1, f80), .{
                -nan(f80),
            }, .{
                -1e0,
            });
            try testArgs(@Vector(2, f80), .{
                -fmax(f80), -inf(f80),
            }, .{
                1e-1, 1e1,
            });
            try testArgs(@Vector(4, f80), .{
                -0.0, -inf(f80), 1e-1, 1e1,
            }, .{
                -1e0, 0.0, 1e-1, -1e1,
            });
            try testArgs(@Vector(8, f80), .{
                1e0, -0.0, -inf(f80), 1e-1, -inf(f80), fmin(f80), 0.0, 1e1,
            }, .{
                -0.0, -fmin(f80), fmin(f80), -nan(f80), nan(f80), inf(f80), fmin(f80), 1e1,
            });
            try testArgs(@Vector(16, f80), .{
                1e1, inf(f80), -fmin(f80), 1e-1, -tmin(f80), -0.0, -inf(f80), -1e0, -fmax(f80), -nan(f80), -tmin(f80), 1e1, 1e1, -inf(f80), -fmax(f80), fmax(f80),
            }, .{
                -inf(f80), nan(f80), -fmax(f80), fmin(f80), 1e0, 1e-1, -inf(f80), nan(f80), 1e-1, nan(f80), -inf(f80), nan(f80), tmin(f80), 1e-1, -tmin(f80), -1e1,
            });
            try testArgs(@Vector(32, f80), .{
                inf(f80),  -0.0, 1e-1,     -0.0, 1e-1,     -fmin(f80), -0.0,       fmax(f80), nan(f80),  -tmin(f80), nan(f80), -1e1,       0.0,       1e0,        1e1, -fmin(f80),
                fmin(f80), 1e-1, inf(f80), -0.0, nan(f80), tmin(f80),  -tmin(f80), fmin(f80), tmin(f80), -0.0,       nan(f80), -fmax(f80), tmin(f80), -fmin(f80), 1e0, tmin(f80),
            }, .{
                0.0,  -1e1,     fmax(f80), -inf(f80),  1e-1,      -inf(f80), inf(f80),   1e1,  -1e0, -1e1,      -fmin(f80), 0.0,  inf(f80),   1e0,        -nan(f80), 0.0,
                1e-1, nan(f80), 1e0,       -fmax(f80), fmin(f80), -inf(f80), -fmax(f80), 1e-1, -1e1, tmin(f80), fmax(f80),  -0.0, -fmin(f80), -fmin(f80), fmin(f80), -tmin(f80),
            });
            try testArgs(@Vector(64, f80), .{
                -fmax(f80), 1e-1,      -1e0,       1e0,        inf(f80),   1e-1,      -1e1,      1e-1,      fmin(f80), -fmin(f80), -1e1,      -fmax(f80), 0.0,        -1e1,      -1e0,       -nan(f80),
                0.0,        1e-1,      -1e0,       -tmin(f80), 1e0,        tmin(f80), fmax(f80), 0.0,       -1e1,      -tmin(f80), fmax(f80), -0.0,       1e-1,       -inf(f80), -fmax(f80), -1e0,
                -nan(f80),  tmin(f80), -tmin(f80), -0.0,       -0.0,       -1e0,      -0.0,      fmax(f80), inf(f80),  -nan(f80),  1e-1,      -inf(f80),  -tmin(f80), nan(f80),  1e-1,       1e1,
                nan(f80),   -inf(f80), 1e-1,       tmin(f80),  -fmin(f80), 1e1,       -1e1,      tmin(f80), fmin(f80), nan(f80),   1e-1,      -nan(f80),  tmin(f80),  nan(f80),  fmax(f80),  -fmax(f80),
            }, .{
                -nan(f80), -fmax(f80), tmin(f80), -inf(f80),  -tmin(f80), fmin(f80), -nan(f80), -fmin(f80), fmax(f80), inf(f80), -0.0,      -1e0, 1e-1,       -fmax(f80), 1e0,       -inf(f80),
                0.0,       -nan(f80),  -1e1,      -1e0,       -nan(f80),  inf(f80),  1e0,       -nan(f80),  1e1,       inf(f80), tmin(f80), 1e-1, tmin(f80),  -tmin(f80), -inf(f80), -fmin(f80),
                fmax(f80), fmax(f80),  1e-1,      -tmin(f80), -nan(f80),  -1e0,      fmin(f80), -nan(f80),  -nan(f80), inf(f80), -1e0,      1e-1, -fmin(f80), -tmin(f80), 0.0,       -0.0,
                1e-1,      -fmin(f80), -inf(f80), -1e0,       -tmin(f80), 1e0,       -inf(f80), -0.0,       0.0,       1e0,      tmin(f80), 0.0,  1e-1,       -nan(f80),  fmax(f80), 1e0,
            });
            try testArgs(@Vector(128, f80), .{
                1e-1,      -0.0,       1e-1,       0.0,        fmin(f80),  -1e0,      1e0,       -inf(f80),  fmax(f80),  -fmin(f80), nan(f80),   1e1,        1e-1,       1e-1,       -fmin(f80), -inf(f80),
                -1e0,      -inf(f80),  1e0,        -fmin(f80), inf(f80),   -nan(f80), 1e1,       inf(f80),   tmin(f80),  nan(f80),   -1e1,       inf(f80),   1e1,        inf(f80),   -1e1,       0.0,
                -1e1,      fmin(f80),  -tmin(f80), 1e0,        -fmax(f80), nan(f80),  0.0,       fmax(f80),  1e-1,       -1e0,       -fmin(f80), inf(f80),   -tmin(f80), nan(f80),   -tmin(f80), 1e1,
                -1e1,      -tmin(f80), -1e0,       -tmin(f80), -fmax(f80), 1e1,       -1e0,      -inf(f80),  -nan(f80),  0.0,        1e0,        fmax(f80),  -tmin(f80), -fmin(f80), fmin(f80),  fmin(f80),
                -1e1,      -fmax(f80), -tmin(f80), inf(f80),   1e0,        0.0,       tmin(f80), -nan(f80),  -fmin(f80), 1e-1,       -nan(f80),  0.0,        1e-1,       -1e1,       -0.0,       -nan(f80),
                1e0,       1e1,        -1e1,       fmin(f80),  -nan(f80),  fmax(f80), -0.0,      1e0,        inf(f80),   1e0,        -fmin(f80), -fmin(f80), 0.0,        1e-1,       inf(f80),   1e1,
                tmin(f80), -1e0,       fmax(f80),  -0.0,       fmax(f80),  fmax(f80), 1e-1,      -fmin(f80), -1e1,       1e0,        -fmin(f80), -fmax(f80), fmin(f80),  -fmax(f80), -0.0,       -1e0,
                -nan(f80), -inf(f80),  nan(f80),   -fmax(f80), inf(f80),   -inf(f80), -nan(f80), fmin(f80),  nan(f80),   -1e0,       tmin(f80),  tmin(f80),  1e-1,       1e1,        -tmin(f80), -nan(f80),
            }, .{
                -1e0,       -0.0,      0.0,        fmax(f80),  -1e0,       -0.0,       1e-1,       tmin(f80),  -inf(f80),  1e1,        -0.0,       1e-1,      -tmin(f80), -fmax(f80), tmin(f80), inf(f80),
                1e-1,       1e0,       tmin(f80),  nan(f80),   -fmax(f80), 1e1,        fmin(f80),  -1e0,       -fmax(f80), nan(f80),   -fmin(f80), 1e1,       -1e0,       tmin(f80),  inf(f80),  -0.0,
                tmin(f80),  1e0,       0.0,        -fmin(f80), 0.0,        1e1,        -fmax(f80), -0.0,       -inf(f80),  fmin(f80),  -0.0,       -0.0,      -0.0,       -fmax(f80), 1e-1,      fmax(f80),
                -tmin(f80), tmin(f80), -fmax(f80), 1e1,        -fmax(f80), 1e-1,       fmax(f80),  -1e1,       1e-1,       1e0,        -1e0,       -1e0,      nan(f80),   -nan(f80),  1e1,       -nan(f80),
                nan(f80),   -1e1,      -tmin(f80), fmin(f80),  -tmin(f80), -fmin(f80), tmin(f80),  -0.0,       1e-1,       fmax(f80),  tmin(f80),  tmin(f80), nan(f80),   1e-1,       1e1,       1e-1,
                inf(f80),   inf(f80),  1e0,        -inf(f80),  -fmax(f80), 0.0,        1e0,        -fmax(f80), fmax(f80),  nan(f80),   fmin(f80),  1e-1,      -1e0,       1e0,        1e-1,      -tmin(f80),
                1e1,        1e-1,      -fmax(f80), 0.0,        nan(f80),   -tmin(f80), 1e-1,       fmax(f80),  fmax(f80),  1e-1,       -1e0,       inf(f80),  nan(f80),   1e1,        fmax(f80), -nan(f80),
                -1e1,       -1e0,      tmin(f80),  fmin(f80),  inf(f80),   fmax(f80),  -fmin(f80), fmin(f80),  -inf(f80),  -tmin(f80), 1e0,        nan(f80),  -fmin(f80), -fmin(f80), fmax(f80), 1e0,
            });
            try testArgs(@Vector(69, f80), .{
                -1e1,       tmin(f80), 1e-1,       -nan(f80), -inf(f80), -nan(f80), fmin(f80), -0.0,       1e1,  fmax(f80), -fmin(f80), 1e-1,       -nan(f80),  inf(f80), 1e0,       -1e0,
                inf(f80),   fmin(f80), -fmax(f80), 1e-1,      nan(f80),  0.0,       0.0,       nan(f80),   -1e1, fmax(f80), fmin(f80),  -fmax(f80), 1e0,        1e-1,     0.0,       -fmin(f80),
                -tmin(f80), 0.0,       -1e1,       fmin(f80), 1e0,       1e1,       1e-1,      nan(f80),   -1e1, fmax(f80), 1e-1,       fmin(f80),  -inf(f80),  0.0,      tmin(f80), inf(f80),
                fmax(f80),  1e0,       1e-1,       nan(f80),  inf(f80),  tmin(f80), tmin(f80), -fmax(f80), 0.0,  fmin(f80), -inf(f80),  1e-1,       -tmin(f80), 1e-1,     -1e0,      1e-1,
                -fmax(f80), -1e0,      1e-1,       -1e0,      fmax(f80),
            }, .{
                -1e0,      fmin(f80),  inf(f80),   -nan(f80), -0.0,       fmin(f80),  -0.0, nan(f80),  -fmax(f80), 1e-1,       1e0,        -1e1,       -tmin(f80), -fmin(f80), 1e1,       inf(f80),
                -1e1,      -tmin(f80), -fmin(f80), 1e1,       0.0,        -tmin(f80), 1e1,  -1e1,      1e-1,       1e-1,       tmin(f80),  fmax(f80),  0.0,        1e-1,       1e-1,      -1e1,
                fmin(f80), nan(f80),   -1e1,       -1e1,      -1e1,       0.0,        -0.0, 1e-1,      fmin(f80),  fmin(f80),  -0.0,       -fmin(f80), -nan(f80),  -inf(f80),  0.0,       -inf(f80),
                inf(f80),  fmax(f80),  -tmin(f80), inf(f80),  1e-1,       -nan(f80),  1e-1, tmin(f80), -1e1,       -fmax(f80), -fmax(f80), inf(f80),   -nan(f80),  1e0,        -inf(f80), 1e1,
                nan(f80),  1e1,        -1e1,       0.0,       -fmin(f80),
            });

            try testArgs(@Vector(1, f128), .{
                -nan(f128),
            }, .{
                -0.0,
            });
            try testArgs(@Vector(2, f128), .{
                0.0, -inf(f128),
            }, .{
                1e-1, -fmin(f128),
            });
            try testArgs(@Vector(4, f128), .{
                1e-1, fmax(f128), 1e1, -fmax(f128),
            }, .{
                -tmin(f128), fmax(f128), -0.0, -0.0,
            });
            try testArgs(@Vector(8, f128), .{
                1e1, -fmin(f128), 0.0, -inf(f128), 1e1, -0.0, -1e0, -fmin(f128),
            }, .{
                fmin(f128), tmin(f128), -1e0, -1e1, 0.0, -tmin(f128), 0.0, 1e-1,
            });
            try testArgs(@Vector(16, f128), .{
                -fmin(f128), -1e1, -fmin(f128), 1e-1, -1e1, 1e0, -fmax(f128), tmin(f128), -nan(f128), -tmin(f128), 1e1, -inf(f128), -1e0, tmin(f128), -0.0, nan(f128),
            }, .{
                -fmax(f128), fmin(f128), inf(f128), tmin(f128), -1e1, 1e1, fmax(f128), 1e0, -inf(f128), -inf(f128), -fmax(f128), -nan(f128), 1e0, -inf(f128), tmin(f128), tmin(f128),
            });
            try testArgs(@Vector(32, f128), .{
                -0.0,       -1e0, 1e0,        -fmax(f128), -fmax(f128), 1e-1,        -fmin(f128), -fmin(f128), -1e0,       -tmin(f128), -0.0,       -fmax(f128), tmin(f128), inf(f128), 0.0,  fmax(f128),
                -nan(f128), -0.0, -inf(f128), -1e0,        1e-1,        -fmin(f128), tmin(f128),  -1e1,        fmax(f128), -nan(f128),  -nan(f128), -fmax(f128), 1e-1,       inf(f128), -0.0, tmin(f128),
            }, .{
                -1e0,       -1e1,       -fmin(f128), -fmin(f128), inf(f128),  tmin(f128), nan(f128), 0.0,        -fmin(f128), 1e-1, -nan(f128), 1e-1, -0.0, tmin(f128), 1e0,         0.0,
                fmin(f128), fmax(f128), -fmax(f128), -tmin(f128), fmin(f128), -0.0,       -1e0,      -nan(f128), -inf(f128),  1e0,  nan(f128),  1e0,  1e-1, -0.0,       -fmax(f128), -1e1,
            });
            try testArgs(@Vector(64, f128), .{
                -1e0,       -0.0,       nan(f128),   1e-1,        -1e1,        0.0,         1e0,         1e0,       -inf(f128), fmin(f128),  fmax(f128), nan(f128),  -nan(f128), inf(f128),   -0.0,
                1e-1,       -inf(f128), -fmax(f128), 1e1,         -tmin(f128), -tmin(f128), -fmax(f128), 1e0,       1e-1,       1e-1,        nan(f128),  1e1,        1e0,        -tmin(f128), 1e1,
                -nan(f128), fmax(f128), fmax(f128),  0.0,         fmax(f128),  inf(f128),   1e0,         -0.0,      1e-1,       -tmin(f128), fmin(f128), fmax(f128), tmin(f128), inf(f128),   -1e1,
                -1e0,       -1e0,       -1e0,        -inf(f128),  1e1,         -tmin(f128), nan(f128),   nan(f128), 1e-1,       fmin(f128),  1e-1,       tmin(f128), -1e1,       1e-1,        1e1,
                fmax(f128), fmax(f128), 1e-1,        -fmax(f128),
            }, .{
                -0.0,      1e-1,       -0.0,      -fmin(f128), 1e1,  0.0,        1e0,         -inf(f128), tmin(f128),  -1e0,      fmin(f128),  -nan(f128), -1e1,       1e-1,       -1e1,       1e-1,
                1e-1,      tmin(f128), nan(f128), -1e0,        0.0,  -1e1,       -1e1,        fmax(f128), -fmax(f128), inf(f128), -nan(f128),  1e-1,       -nan(f128), 1e0,        fmax(f128), inf(f128),
                nan(f128), fmin(f128), 1e1,       inf(f128),   0.0,  -inf(f128), 1e-1,        1e-1,       1e-1,        -1e0,      1e-1,        -1e1,       inf(f128),  -nan(f128), 1e-1,       inf(f128),
                inf(f128), inf(f128),  -1e1,      -tmin(f128), 1e-1, -inf(f128), -fmin(f128), 1e0,        -tmin(f128), 1e0,       -tmin(f128), -inf(f128), -0.0,       -nan(f128), -1e0,       -fmax(f128),
            });
            try testArgs(@Vector(128, f128), .{
                -inf(f128),  tmin(f128),  -fmax(f128), 1e0,         fmin(f128),  -fmax(f128), -1e0,        1e-1,        -fmax(f128), -fmin(f128), -1e1,        nan(f128),   1e-1,       nan(f128),
                inf(f128),   -1e0,        tmin(f128),  -inf(f128),  0.0,         fmax(f128),  tmin(f128),  -fmin(f128), fmin(f128),  -1e1,        -fmin(f128), -1e1,        1e0,        -nan(f128),
                -inf(f128),  fmin(f128),  inf(f128),   -tmin(f128), 1e-1,        0.0,         1e1,         1e0,         -tmin(f128), -tmin(f128), tmin(f128),  1e0,         fmin(f128), 1e-1,
                1e-1,        1e-1,        fmax(f128),  1e-1,        inf(f128),   0.0,         fmin(f128),  -fmin(f128), 1e1,         1e1,         -1e1,        tmin(f128),  inf(f128),  inf(f128),
                -fmin(f128), 0.0,         1e-1,        -nan(f128),  1e-1,        -inf(f128),  -nan(f128),  -1e0,        fmin(f128),  -0.0,        1e1,         -tmin(f128), 1e1,        1e0,
                1e-1,        -0.0,        -tmin(f128), 1e-1,        -1e0,        -tmin(f128), -fmin(f128), tmin(f128),  1e-1,        -tmin(f128), -nan(f128),  -1e1,        -inf(f128), 0.0,
                1e-1,        0.0,         -fmin(f128), 0.0,         1e1,         1e1,         tmin(f128),  inf(f128),   -nan(f128),  -inf(f128),  -1e0,        -fmin(f128), -1e1,       -fmin(f128),
                -inf(f128),  -fmax(f128), tmin(f128),  tmin(f128),  -fmin(f128), 1e-1,        fmin(f128),  fmin(f128),  -fmin(f128), nan(f128),   -1e0,        -0.0,        -0.0,       1e-1,
                fmax(f128),  0.0,         -fmax(f128), nan(f128),   nan(f128),   nan(f128),   nan(f128),   -nan(f128),  fmin(f128),  -inf(f128),  inf(f128),   -fmax(f128), -1e1,       fmin(f128),
                1e-1,        fmax(f128),
            }, .{
                0.0,         1e1,         1e-1,        inf(f128),   -0.0,        -1e0,        nan(f128),  -1e1,        -inf(f128),  1e-1,        -tmin(f128), 1e0,         inf(f128),   1e-1,        -1e0,
                1e1,         0.0,         1e0,         nan(f128),   tmin(f128),  fmax(f128),  1e1,        1e-1,        1e-1,        -fmin(f128), -inf(f128),  -nan(f128),  -fmin(f128), -0.0,        -inf(f128),
                -nan(f128),  fmax(f128),  -fmin(f128), -tmin(f128), -fmin(f128), -fmax(f128), nan(f128),  fmin(f128),  -fmax(f128), fmax(f128),  1e0,         1e1,         -fmax(f128), nan(f128),   -fmax(f128),
                -inf(f128),  nan(f128),   -nan(f128),  tmin(f128),  -1e0,        1e-1,        1e-1,       -1e0,        -nan(f128),  fmax(f128),  1e1,         -inf(f128),  1e1,         -0.0,        -1e0,
                -0.0,        -tmin(f128), 1e1,         -1e0,        -fmax(f128), fmin(f128),  fmax(f128), tmin(f128),  1e1,         fmin(f128),  -nan(f128),  1e0,         -tmin(f128), -1e0,        fmax(f128),
                1e0,         -tmin(f128), 1e-1,        -nan(f128),  inf(f128),   1e-1,        1e-1,       fmax(f128),  -fmin(f128), fmin(f128),  -0.0,        fmax(f128),  -fmax(f128), -tmin(f128), tmin(f128),
                nan(f128),   1e-1,        tmin(f128),  -1e0,        fmin(f128),  -nan(f128),  fmax(f128), 1e0,         nan(f128),   -nan(f128),  inf(f128),   -fmin(f128), fmin(f128),  1e-1,        1e1,
                -tmin(f128), -1e1,        0.0,         1e-1,        -fmin(f128), -0.0,        0.0,        -1e1,        fmax(f128),  nan(f128),   nan(f128),   -fmin(f128), -fmax(f128), 1e1,         0.0,
                fmin(f128),  1e1,         -tmin(f128), -tmin(f128), 0.0,         -1e1,        1e0,        -fmin(f128),
            });
            try testArgs(@Vector(69, f128), .{
                -1e0,       nan(f128),  1e-1,       1e-1,       1e-1,       -1e0, -1e1,       inf(f128), -0.0,       inf(f128),  tmin(f128),  0.0,         -fmax(f128), -tmin(f128), -1e1,        -fmax(f128),
                -0.0,       0.0,        nan(f128),  inf(f128),  1e0,        -1e0, 1e-1,       -0.0,      1e0,        fmax(f128), -fmax(f128), 0.0,         inf(f128),   -inf(f128),  -tmin(f128), -inf(f128),
                1e1,        fmin(f128), 1e1,        -1e1,       1e-1,       1e0,  -0.0,       nan(f128), tmin(f128), inf(f128),  inf(f128),   -nan(f128),  -nan(f128),  1e0,         -tmin(f128), 0.0,
                fmin(f128), fmax(f128), fmin(f128), -1e1,       nan(f128),  0.0,  -nan(f128), -0.0,      -nan(f128), 1e-1,       -1e1,        -tmin(f128), fmax(f128),  1e0,         fmin(f128),  fmax(f128),
                nan(f128),  -inf(f128), 1e0,        fmin(f128), -nan(f128),
            }, .{
                -inf(f128), fmax(f128), 0.0,        nan(f128),   -1e1,        tmin(f128),  nan(f128),  1e0,       1e1,         -fmin(f128), fmin(f128),  tmin(f128),  0.0,         -fmin(f128), -0.0,        fmin(f128),
                inf(f128),  inf(f128),  fmin(f128), fmin(f128),  -tmin(f128), -fmax(f128), 1e1,        nan(f128), -0.0,        1e0,         1e1,         -1e1,        -inf(f128),  fmin(f128),  -fmax(f128), 1e-1,
                -1e0,       -nan(f128), -1e1,       tmin(f128),  inf(f128),   nan(f128),   0.0,        -1e1,      tmin(f128),  0.0,         -fmax(f128), -tmin(f128), 1e-1,        1e-1,        1e1,         1e-1,
                fmax(f128), 1e-1,       0.0,        -fmin(f128), -inf(f128),  -inf(f128),  -nan(f128), 1e-1,      -fmax(f128), fmax(f128),  -fmax(f128), -0.0,        -tmin(f128), -1e0,        nan(f128),   1e-1,
                -1e0,       -inf(f128), tmin(f128), inf(f128),   inf(f128),
            });
        }
    };
}

inline fn add(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs + rhs) {
    return lhs + rhs;
}
test add {
    const test_add = binary(add, .{});
    try test_add.testFloats();
    try test_add.testFloatVectors();
}

inline fn subtract(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs - rhs) {
    return lhs - rhs;
}
test subtract {
    const test_subtract = binary(subtract, .{});
    try test_subtract.testFloats();
    try test_subtract.testFloatVectors();
}

inline fn multiply(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs * rhs) {
    if (@inComptime() and @typeInfo(Type) == .vector) {
        // workaround https://github.com/ziglang/zig/issues/22743
        // TODO: return @select(Scalar(Type), boolAnd(lhs == lhs, rhs == rhs), lhs * rhs, lhs + rhs);
        // workaround https://github.com/ziglang/zig/issues/22744
        var res: Type = undefined;
        for (0..@typeInfo(Type).vector.len) |i| res[i] = lhs[i] * rhs[i];
        return res;
    }
    // workaround https://github.com/ziglang/zig/issues/22745
    // TODO: return lhs * rhs;
    var rt_lhs = lhs;
    var rt_rhs = rhs;
    _ = .{ &rt_lhs, &rt_rhs };
    return rt_lhs * rt_rhs;
}
test multiply {
    const test_multiply = binary(multiply, .{});
    try test_multiply.testFloats();
    try test_multiply.testFloatVectors();
}

inline fn divide(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs / rhs) {
    return lhs / rhs;
}
test divide {
    const test_divide = binary(divide, .{ .compare = .approx });
    try test_divide.testFloats();
    try test_divide.testFloatVectors();
}

// workaround https://github.com/ziglang/zig/issues/22748
// TODO: @TypeOf(@divTrunc(lhs, rhs))
inline fn divTrunc(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs / rhs) {
    if (@inComptime()) {
        // workaround https://github.com/ziglang/zig/issues/22748
        return @trunc(lhs / rhs);
    }
    // workaround https://github.com/ziglang/zig/issues/22748
    // workaround https://github.com/ziglang/zig/issues/22749
    // TODO: return @divTrunc(lhs, rhs);
    var rt_lhs = lhs;
    var rt_rhs = rhs;
    _ = .{ &rt_lhs, &rt_rhs };
    return @divTrunc(rt_lhs, rt_rhs);
}
test divTrunc {
    const test_div_trunc = binary(divTrunc, .{ .compare = .approx_int });
    try test_div_trunc.testFloats();
    try test_div_trunc.testFloatVectors();
}

// workaround https://github.com/ziglang/zig/issues/22748
// TODO: @TypeOf(@divFloor(lhs, rhs))
inline fn divFloor(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs / rhs) {
    if (@inComptime()) {
        // workaround https://github.com/ziglang/zig/issues/22748
        return @floor(lhs / rhs);
    }
    // workaround https://github.com/ziglang/zig/issues/22748
    // workaround https://github.com/ziglang/zig/issues/22749
    // TODO: return @divFloor(lhs, rhs);
    var rt_lhs = lhs;
    var rt_rhs = rhs;
    _ = &rt_lhs;
    _ = &rt_rhs;
    return @divFloor(rt_lhs, rt_rhs);
}
test divFloor {
    const test_div_floor = binary(divFloor, .{ .compare = .approx_int });
    try test_div_floor.testFloats();
    try test_div_floor.testFloatVectors();
}

// workaround https://github.com/ziglang/zig/issues/22748
// TODO: @TypeOf(@rem(lhs, rhs))
inline fn rem(comptime Type: type, lhs: Type, rhs: Type) Type {
    if (@inComptime()) {
        // workaround https://github.com/ziglang/zig/issues/22748
        switch (@typeInfo(Type)) {
            else => return if (rhs != 0) @rem(lhs, rhs) else nan(Type),
            .vector => |info| {
                var res: Type = undefined;
                inline for (0..info.len) |i| res[i] = if (rhs[i] != 0) @rem(lhs[i], rhs[i]) else nan(Scalar(Type));
                return res;
            },
        }
    }
    // workaround https://github.com/ziglang/zig/issues/22748
    // TODO: return @rem(lhs, rhs);
    var rt_rhs = rhs;
    _ = &rt_rhs;
    return @rem(lhs, rt_rhs);
}
test rem {
    const test_rem = binary(rem, .{});
    try test_rem.testFloats();
    try test_rem.testFloatVectors();
}

inline fn mod(comptime Type: type, lhs: Type, rhs: Type) Type {
    if (@inComptime()) {
        const scalarMod = struct {
            fn scalarMod(scalar_lhs: Scalar(Type), scalar_rhs: Scalar(Type)) Scalar(Type) {
                // workaround https://github.com/ziglang/zig/issues/22748
                if (scalar_rhs == 0) return nan(Scalar(Type));
                const scalar_rem = @rem(scalar_lhs, scalar_rhs);
                return if (scalar_rem == 0 or math.signbit(scalar_rem) == math.signbit(scalar_rhs)) scalar_rem else scalar_rem + scalar_rhs;
            }
        }.scalarMod;
        // workaround https://github.com/ziglang/zig/issues/22748
        switch (@typeInfo(Type)) {
            // workaround llvm backend bugs
            // TODO: else => return if (rhs != 0) @mod(lhs, rhs) else nan(Type),
            // TODO: .vector => |info| {
            // TODO:     var res: Type = undefined;
            // TODO:     inline for (0..info.len) |i| res[i] = if (rhs[i] != 0) @mod(lhs[i], rhs[i]) else nan(Scalar(Type));
            // TODO:     return res;
            // TODO: },
            else => return scalarMod(lhs, rhs),
            .vector => |info| {
                var res: Type = undefined;
                inline for (0..info.len) |i| res[i] = scalarMod(lhs[i], rhs[i]);
                return res;
            },
        }
    }
    // workaround https://github.com/ziglang/zig/issues/22748
    // TODO: return @mod(lhs, rhs);
    var rt_rhs = rhs;
    _ = &rt_rhs;
    return @mod(lhs, rt_rhs);
}
test mod {
    const test_mod = binary(mod, .{});
    try test_mod.testFloats();
    try test_mod.testFloatVectors();
}

inline fn bitNot(comptime Type: type, rhs: Type) @TypeOf(~rhs) {
    return ~rhs;
}
test bitNot {
    const test_bit_not = unary(bitNot, .{});
    try test_bit_not.testInts();
    try test_bit_not.testIntVectors();
}

inline fn clz(comptime Type: type, rhs: Type) @TypeOf(@clz(rhs)) {
    return @clz(rhs);
}
test clz {
    const test_clz = unary(clz, .{});
    try test_clz.testInts();
    try test_clz.testIntVectors();
}

inline fn sqrt(comptime Type: type, rhs: Type) @TypeOf(@sqrt(rhs)) {
    return @sqrt(rhs);
}
test sqrt {
    const test_sqrt = unary(sqrt, .{ .libc_name = "sqrt", .compare = .approx });
    try test_sqrt.testFloats();
    try test_sqrt.testFloatVectors();
}

inline fn sin(comptime Type: type, rhs: Type) @TypeOf(@sin(rhs)) {
    return @sin(rhs);
}
test sin {
    const test_sin = unary(sin, .{ .libc_name = "sin", .compare = .strict });
    try test_sin.testFloats();
    try test_sin.testFloatVectors();
}

inline fn cos(comptime Type: type, rhs: Type) @TypeOf(@cos(rhs)) {
    return @cos(rhs);
}
test cos {
    const test_cos = unary(cos, .{ .libc_name = "cos", .compare = .strict });
    try test_cos.testFloats();
    try test_cos.testFloatVectors();
}

inline fn tan(comptime Type: type, rhs: Type) @TypeOf(@tan(rhs)) {
    return @tan(rhs);
}
test tan {
    const test_tan = unary(tan, .{ .libc_name = "tan", .compare = .strict });
    try test_tan.testFloats();
    try test_tan.testFloatVectors();
}

inline fn exp(comptime Type: type, rhs: Type) @TypeOf(@exp(rhs)) {
    return @exp(rhs);
}
test exp {
    const test_exp = unary(exp, .{ .libc_name = "exp", .compare = .strict });
    try test_exp.testFloats();
    try test_exp.testFloatVectors();
}

inline fn exp2(comptime Type: type, rhs: Type) @TypeOf(@exp2(rhs)) {
    return @exp2(rhs);
}
test exp2 {
    const test_exp2 = unary(exp2, .{ .libc_name = "exp2", .compare = .strict });
    try test_exp2.testFloats();
    try test_exp2.testFloatVectors();
}

inline fn log(comptime Type: type, rhs: Type) @TypeOf(@log(rhs)) {
    return @log(rhs);
}
test log {
    const test_log = unary(log, .{ .libc_name = "log", .compare = .strict });
    try test_log.testFloats();
    try test_log.testFloatVectors();
}

inline fn log2(comptime Type: type, rhs: Type) @TypeOf(@log2(rhs)) {
    return @log2(rhs);
}
test log2 {
    const test_log2 = unary(log2, .{ .libc_name = "log2", .compare = .strict });
    try test_log2.testFloats();
    try test_log2.testFloatVectors();
}

inline fn log10(comptime Type: type, rhs: Type) @TypeOf(@log10(rhs)) {
    return @log10(rhs);
}
test log10 {
    const test_log10 = unary(log10, .{ .libc_name = "log10", .compare = .strict });
    try test_log10.testFloats();
    try test_log10.testFloatVectors();
}

inline fn abs(comptime Type: type, rhs: Type) @TypeOf(@abs(rhs)) {
    return @abs(rhs);
}
test abs {
    const test_abs = unary(abs, .{ .compare = .strict });
    try test_abs.testInts();
    try test_abs.testIntVectors();
    try test_abs.testFloats();
    try test_abs.testFloatVectors();
}

inline fn floor(comptime Type: type, rhs: Type) @TypeOf(@floor(rhs)) {
    return @floor(rhs);
}
test floor {
    const test_floor = unary(floor, .{ .libc_name = "floor", .compare = .strict });
    try test_floor.testFloats();
    try test_floor.testFloatVectors();
}

inline fn ceil(comptime Type: type, rhs: Type) @TypeOf(@ceil(rhs)) {
    return @ceil(rhs);
}
test ceil {
    const test_ceil = unary(ceil, .{ .libc_name = "ceil", .compare = .strict });
    try test_ceil.testFloats();
    try test_ceil.testFloatVectors();
}

inline fn round(comptime Type: type, rhs: Type) @TypeOf(@round(rhs)) {
    return @round(rhs);
}
test round {
    const test_round = unary(round, .{ .libc_name = "round", .compare = .strict });
    try test_round.testFloats();
    try test_round.testFloatVectors();
}

inline fn trunc(comptime Type: type, rhs: Type) @TypeOf(@trunc(rhs)) {
    return @trunc(rhs);
}
test trunc {
    const test_trunc = unary(trunc, .{ .libc_name = "trunc", .compare = .strict });
    try test_trunc.testFloats();
    try test_trunc.testFloatVectors();
}

inline fn negate(comptime Type: type, rhs: Type) @TypeOf(-rhs) {
    return -rhs;
}
test negate {
    const test_negate = unary(negate, .{ .compare = .strict });
    try test_negate.testFloats();
    try test_negate.testFloatVectors();
}

inline fn intCast(comptime Result: type, comptime Type: type, rhs: Type, comptime ct_rhs: Type) Result {
    @setRuntimeSafety(false); // TODO
    const res_info = switch (@typeInfo(Result)) {
        .int => |info| info,
        .vector => |info| @typeInfo(info.child).int,
        else => @compileError(@typeName(Result)),
    };
    const rhs_info = @typeInfo(Scalar(Type)).int;
    const min_bits = @min(res_info.bits, rhs_info.bits);
    return @intCast(switch (@as(union(enum) {
        shift: std.math.Log2Int(Scalar(Type)),
        mask: std.math.Log2IntCeil(Scalar(Type)),
    }, switch (res_info.signedness) {
        .signed => switch (rhs_info.signedness) {
            .signed => .{ .shift = rhs_info.bits - min_bits },
            .unsigned => .{ .mask = min_bits - @intFromBool(res_info.bits <= rhs_info.bits) },
        },
        .unsigned => switch (rhs_info.signedness) {
            .signed => .{ .mask = min_bits - @intFromBool(res_info.bits >= rhs_info.bits) },
            .unsigned => .{ .mask = min_bits },
        },
    })) {
        // TODO: if (bits == 0) rhs else rhs >> bits,
        .shift => |bits| if (bits == 0) rhs else switch (@typeInfo(Type)) {
            .int => if (ct_rhs < 0)
                rhs | std.math.minInt(Type) >> bits
            else
                rhs & std.math.maxInt(Type) >> bits,
            .vector => rhs | @select(
                Scalar(Type),
                ct_rhs < splat(Type, 0),
                splat(Type, std.math.minInt(Scalar(Type)) >> bits),
                splat(Type, 0),
            ) & ~@select(
                Scalar(Type),
                ct_rhs >= splat(Type, 0),
                splat(Type, std.math.minInt(Scalar(Type)) >> bits),
                splat(Type, 0),
            ),
            else => comptime unreachable,
        },
        .mask => |bits| if (bits == rhs_info.bits) rhs else rhs & splat(Type, (1 << bits) - 1),
    });
}
test intCast {
    const test_int_cast = cast(intCast, .{});
    try test_int_cast.testInts();
    try test_int_cast.testIntVectors();
}

inline fn truncate(comptime Result: type, comptime Type: type, rhs: Type, comptime _: Type) Result {
    return if (@typeInfo(Scalar(Result)).int.bits <= @typeInfo(Scalar(Type)).int.bits) @truncate(rhs) else rhs;
}
test truncate {
    const test_truncate = cast(truncate, .{});
    try test_truncate.testSameSignednessInts();
    try test_truncate.testSameSignednessIntVectors();
}

inline fn floatCast(comptime Result: type, comptime Type: type, rhs: Type, comptime _: Type) Result {
    return @floatCast(rhs);
}
test floatCast {
    const test_float_cast = cast(floatCast, .{ .compare = .strict });
    try test_float_cast.testFloats();
    try test_float_cast.testFloatVectors();
}

inline fn intFromFloat(comptime Result: type, comptime Type: type, rhs: Type, comptime _: Type) Result {
    return @intFromFloat(rhs);
}
test intFromFloat {
    const test_int_from_float = cast(intFromFloat, .{ .compare = .strict });
    try test_int_from_float.testIntsFromFloats();
}

inline fn floatFromInt(comptime Result: type, comptime Type: type, rhs: Type, comptime _: Type) Result {
    return @floatFromInt(rhs);
}
test floatFromInt {
    const test_float_from_int = cast(floatFromInt, .{ .compare = .strict });
    try test_float_from_int.testFloatsFromInts();
}

inline fn equal(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs == rhs) {
    return lhs == rhs;
}
test equal {
    const test_equal = binary(equal, .{});
    try test_equal.testInts();
    try test_equal.testFloats();
}

inline fn notEqual(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs != rhs) {
    return lhs != rhs;
}
test notEqual {
    const test_not_equal = binary(notEqual, .{});
    try test_not_equal.testInts();
    try test_not_equal.testFloats();
}

inline fn lessThan(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs < rhs) {
    return lhs < rhs;
}
test lessThan {
    const test_less_than = binary(lessThan, .{});
    try test_less_than.testInts();
    try test_less_than.testFloats();
}

inline fn lessThanOrEqual(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs <= rhs) {
    return lhs <= rhs;
}
test lessThanOrEqual {
    const test_less_than_or_equal = binary(lessThanOrEqual, .{});
    try test_less_than_or_equal.testInts();
    try test_less_than_or_equal.testFloats();
}

inline fn greaterThan(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs > rhs) {
    return lhs > rhs;
}
test greaterThan {
    const test_greater_than = binary(greaterThan, .{});
    try test_greater_than.testInts();
    try test_greater_than.testFloats();
}

inline fn greaterThanOrEqual(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs >= rhs) {
    return lhs >= rhs;
}
test greaterThanOrEqual {
    const test_greater_than_or_equal = binary(greaterThanOrEqual, .{});
    try test_greater_than_or_equal.testInts();
    try test_greater_than_or_equal.testFloats();
}

inline fn bitAnd(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs & rhs) {
    return lhs & rhs;
}
test bitAnd {
    const test_bit_and = binary(bitAnd, .{});
    try test_bit_and.testInts();
    try test_bit_and.testIntVectors();
}

inline fn bitOr(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs | rhs) {
    return lhs | rhs;
}
test bitOr {
    const test_bit_or = binary(bitOr, .{});
    try test_bit_or.testInts();
    try test_bit_or.testIntVectors();
}

inline fn bitXor(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs ^ rhs) {
    return lhs ^ rhs;
}
test bitXor {
    const test_bit_xor = binary(bitXor, .{});
    try test_bit_xor.testInts();
    try test_bit_xor.testIntVectors();
}

inline fn min(comptime Type: type, lhs: Type, rhs: Type) Type {
    return @min(lhs, rhs);
}
test min {
    const test_min = binary(min, .{});
    try test_min.testInts();
    try test_min.testIntVectors();
    try test_min.testFloats();
    try test_min.testFloatVectors();
}

inline fn max(comptime Type: type, lhs: Type, rhs: Type) Type {
    return @max(lhs, rhs);
}
test max {
    const test_max = binary(max, .{});
    try test_max.testInts();
    try test_max.testIntVectors();
    try test_max.testFloats();
    try test_max.testFloatVectors();
}

inline fn nullIsNull(comptime Type: type, _: Type) bool {
    return runtime(?Type, null) == null;
}
test nullIsNull {
    const test_null_is_null = unary(nullIsNull, .{});
    try test_null_is_null.testIntTypes();
    try test_null_is_null.testIntVectorTypes();
    try test_null_is_null.testFloatTypes();
    try test_null_is_null.testFloatVectorTypes();
}

inline fn nullIsNotNull(comptime Type: type, _: Type) bool {
    return runtime(?Type, null) != null;
}
test nullIsNotNull {
    const test_null_is_not_null = unary(nullIsNotNull, .{});
    try test_null_is_not_null.testIntTypes();
    try test_null_is_not_null.testIntVectorTypes();
    try test_null_is_not_null.testFloatTypes();
    try test_null_is_not_null.testFloatVectorTypes();
}

inline fn optionalIsNull(comptime Type: type, lhs: Type) bool {
    return @as(?Type, lhs) == null;
}
test optionalIsNull {
    const test_optional_is_null = unary(optionalIsNull, .{});
    try test_optional_is_null.testInts();
    try test_optional_is_null.testFloats();
}

inline fn optionalIsNotNull(comptime Type: type, lhs: Type) bool {
    return @as(?Type, lhs) != null;
}
test optionalIsNotNull {
    const test_optional_is_not_null = unary(optionalIsNotNull, .{});
    try test_optional_is_not_null.testInts();
    try test_optional_is_not_null.testFloats();
}

inline fn nullEqualNull(comptime Type: type, _: Type) bool {
    return runtime(?Type, null) == runtime(?Type, null);
}
test nullEqualNull {
    const test_null_equal_null = unary(nullEqualNull, .{});
    try test_null_equal_null.testIntTypes();
    try test_null_equal_null.testFloatTypes();
}

inline fn nullNotEqualNull(comptime Type: type, _: Type) bool {
    return runtime(?Type, null) != runtime(?Type, null);
}
test nullNotEqualNull {
    const test_null_not_equal_null = unary(nullNotEqualNull, .{});
    try test_null_not_equal_null.testIntTypes();
    try test_null_not_equal_null.testFloatTypes();
}

inline fn optionalEqualNull(comptime Type: type, lhs: Type) bool {
    return lhs == runtime(?Type, null);
}
test optionalEqualNull {
    const test_optional_equal_null = unary(optionalEqualNull, .{});
    try test_optional_equal_null.testInts();
    try test_optional_equal_null.testFloats();
}

inline fn optionalNotEqualNull(comptime Type: type, lhs: Type) bool {
    return lhs != runtime(?Type, null);
}
test optionalNotEqualNull {
    const test_optional_not_equal_null = unary(optionalIsNotNull, .{});
    try test_optional_not_equal_null.testInts();
    try test_optional_not_equal_null.testFloats();
}

inline fn optionalsEqual(comptime Type: type, lhs: Type, rhs: Type) bool {
    if (@inComptime()) return lhs == rhs; // workaround https://github.com/ziglang/zig/issues/22636
    return @as(?Type, lhs) == rhs;
}
test optionalsEqual {
    const test_optionals_equal = binary(optionalsEqual, .{});
    try test_optionals_equal.testInts();
    try test_optionals_equal.testFloats();
}

inline fn optionalsNotEqual(comptime Type: type, lhs: Type, rhs: Type) bool {
    if (@inComptime()) return lhs != rhs; // workaround https://github.com/ziglang/zig/issues/22636
    return lhs != @as(?Type, rhs);
}
test optionalsNotEqual {
    const test_optionals_not_equal = binary(optionalsNotEqual, .{});
    try test_optionals_not_equal.testInts();
    try test_optionals_not_equal.testFloats();
}

inline fn mulAdd(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(@mulAdd(Type, lhs, rhs, rhs)) {
    return @mulAdd(Type, lhs, rhs, rhs);
}
test mulAdd {
    const test_mul_add = binary(mulAdd, .{ .compare = .approx });
    try test_mul_add.testFloats();
    try test_mul_add.testFloatVectors();
}
