const std = @import("std");
const testing = std.testing;

/// Computes `coef[0] + coef[1]*x + coef[2]*x^2 + coef[3]*x^3 + ...`
/// via Horner's method, unrolled for comptime-known lengths.
pub fn pow(x: anytype, coef: anytype) @TypeOf(x) {
    const X = @TypeOf(x);
    const end = coef.len - 1;
    const last = coef[end];
    var ex: X = if (.Vector == @typeInfo(X)) @splat(last) else last;
    const inf_coef = @typeInfo(@TypeOf(coef));
    if (.Pointer == inf_coef and .Slice == inf_coef.size) {
        for (1..coef.len) |i| {
            const next = coef[end - i];
            ex = switch (@typeInfo(X)) {
                .Int => x * ex + next,
                .Float => @mulAdd(X, x, ex, next),
                .Vector => @mulAdd(X, x, ex, @splat(next)),
                else => @compileError(@typeName(X) ++ " unsupported."),
            };
        }
    } else {
        inline for (1..coef.len) |i| {
            const next = coef[end - i];
            ex = switch (@typeInfo(X)) {
                .Int => x * ex + next,
                .Float => @mulAdd(X, x, ex, next),
                .Vector => @mulAdd(X, x, ex, @splat(next)),
                else => @compileError(@typeName(X) ++ " unsupported."),
            };
        }
    }
    return ex;
}

/// Computes `coef[0]*cos(0x) + coef[1]*cos(1x) + coef[2]*cos(2x) + coef[3]*cos(3x) + ...`
pub fn cos(x: anytype, coef: anytype) @TypeOf(x) {
    const X = @TypeOf(x);
    const S = if (.Vector == @typeInfo(X)) @TypeOf(x[0]) else X;
    const head = coef[0];
    var ex: X = if (S == X) head else @splat(head);
    const inf_coef = @typeInfo(@TypeOf(coef));
    if (.Pointer == inf_coef and .Slice == inf_coef.size) {
        for (1..coef.len) |i| {
            const next = coef[i];
            const step: S = @floatFromInt(i);
            const base: X = if (S == X) step else @splat(step);
            ex = switch (@typeInfo(X)) {
                .Float => @mulAdd(X, @cos(x * base), next, ex),
                .Vector => @mulAdd(X, @cos(x * base), @splat(next), ex),
                else => @compileError(@typeName(X) ++ " unsupported."),
            };
        }
    } else {
        inline for (1..coef.len) |i| {
            const next = coef[i];
            const step: S = @floatFromInt(i);
            const base: X = if (S == X) step else @splat(step);
            ex = switch (@typeInfo(X)) {
                .Float => @mulAdd(X, @cos(x * base), next, ex),
                .Vector => @mulAdd(X, @cos(x * base), @splat(next), ex),
                else => @compileError(@typeName(X) ++ " unsupported."),
            };
        }
    }
    return ex;
}

/// Computes `coef[0]*sin(0x) + coef[1]*sin(1x) + coef[2]*sin(2x) + coef[3]*sin(3x) + ...`
pub fn sin(x: anytype, coef: anytype) @TypeOf(x) {
    const X = @TypeOf(x);
    const S = if (.Vector == @typeInfo(X)) @TypeOf(x[0]) else X;
    var ex: X = if (S == X) 0 else @splat(0);
    const inf_coef = @typeInfo(@TypeOf(coef));
    if (.Pointer == inf_coef and .Slice == inf_coef.size) {
        for (1..coef.len) |i| {
            const next = coef[i];
            const step: S = @floatFromInt(i);
            const base: X = if (S == X) step else @splat(step);
            ex = switch (@typeInfo(X)) {
                .Float => @mulAdd(X, @sin(x * base), next, ex),
                .Vector => @mulAdd(X, @sin(x * base), @splat(next), ex),
                else => @compileError(@typeName(X) ++ " unsupported."),
            };
        }
    } else {
        inline for (1..coef.len) |i| {
            const next = coef[i];
            const step: S = @floatFromInt(i);
            const base: X = if (S == X) step else @splat(step);
            ex = switch (@typeInfo(X)) {
                .Float => @mulAdd(X, @sin(x * base), next, ex),
                .Vector => @mulAdd(X, @sin(x * base), @splat(next), ex),
                else => @compileError(@typeName(X) ++ " unsupported."),
            };
        }
    }
    return ex;
}

const rtol = 1.0 / 65536.0;
const chk = testing.expectApproxEqRel;

test pow {
    const y = pow(@as(u32, 5), .{ 1, 2, 3, 420, 69 });
    try testing.expect(y == 1 + 2 * 5 + 3 * 5 * 5 + 420 * 5 * 5 * 5 + 69 * 5 * 5 * 5 * 5);

    const xs: @Vector(4, f32) = .{ 1, 2, 3, 4 };
    const ys = pow(xs, .{ 1, 2, 3, 420, 69 });
    try chk(ys[0], 1 + 2 * 1 + 3 * 1 * 1 + 420 * 1 * 1 * 1 + 69 * 1 * 1 * 1 * 1, rtol);
    try chk(ys[1], 1 + 2 * 2 + 3 * 2 * 2 + 420 * 2 * 2 * 2 + 69 * 2 * 2 * 2 * 2, rtol);
    try chk(ys[2], 1 + 2 * 3 + 3 * 3 * 3 + 420 * 3 * 3 * 3 + 69 * 3 * 3 * 3 * 3, rtol);
    try chk(ys[3], 1 + 2 * 4 + 3 * 4 * 4 + 420 * 4 * 4 * 4 + 69 * 4 * 4 * 4 * 4, rtol);
}

test cos {
    const y = cos(@as(f32, 5), .{ 1, 2, 3, 420, 69 });
    const ans = 1 + 2 * @cos(5.0) + 3 * @cos(2 * 5.0) + 420 * @cos(3 * 5.0) + 69 * @cos(4 * 5.0);
    try testing.expectApproxEqRel(y, ans, rtol);

    const xs: @Vector(4, f32) = .{ 1, 2, 3, 4 };
    const ys = cos(xs, .{ 1, 2, 3, 420, 69 });
    try chk(ys[0], 1 + 2 * @cos(1.0) + 3 * @cos(2 * 1.0) + 420 * @cos(3 * 1.0) + 69 * @cos(4 * 1.0), rtol);
    try chk(ys[1], 1 + 2 * @cos(2.0) + 3 * @cos(2 * 2.0) + 420 * @cos(3 * 2.0) + 69 * @cos(4 * 2.0), rtol);
    try chk(ys[2], 1 + 2 * @cos(3.0) + 3 * @cos(2 * 3.0) + 420 * @cos(3 * 3.0) + 69 * @cos(4 * 3.0), rtol);
    try chk(ys[3], 1 + 2 * @cos(4.0) + 3 * @cos(2 * 4.0) + 420 * @cos(3 * 4.0) + 69 * @cos(4 * 4.0), rtol);
}

test sin {
    const y = sin(@as(f32, 5), .{ 1, 2, 3, 420, 69 });
    const ans = 2 * @sin(5.0) + 3 * @sin(2 * 5.0) + 420 * @sin(3 * 5.0) + 69 * @sin(4 * 5.0);
    try testing.expectApproxEqRel(y, ans, rtol);

    const xs: @Vector(4, f32) = .{ 1, 2, 3, 4 };
    const ys = sin(xs, .{ 1, 2, 3, 420, 69 });
    try chk(ys[0], 2 * @sin(1.0) + 3 * @sin(2 * 1.0) + 420 * @sin(3 * 1.0) + 69 * @sin(4 * 1.0), rtol);
    try chk(ys[1], 2 * @sin(2.0) + 3 * @sin(2 * 2.0) + 420 * @sin(3 * 2.0) + 69 * @sin(4 * 2.0), rtol);
    try chk(ys[2], 2 * @sin(3.0) + 3 * @sin(2 * 3.0) + 420 * @sin(3 * 3.0) + 69 * @sin(4 * 3.0), rtol);
    try chk(ys[3], 2 * @sin(4.0) + 3 * @sin(2 * 4.0) + 420 * @sin(3 * 4.0) + 69 * @sin(4 * 4.0), rtol);
}
