/// Computes `coef[0] + coef[1]*x + coef[2]*x^2 + coef[3]*x^3 + ...`
/// via Horner's method, unrolled for comptime-known lengths.
pub fn pow(x: anytype, coef: anytype) @TypeOf(x) {
    const X = @TypeOf(x);
    const end = coef.len - 1;
    const last = coef[end];
    var ex: X = if (.Vector == @typeInfo(X)) @splat(last) else last;
    const inf_coef = @TypeInfo(@TypeOf(coef));
    if (.Pointer == inf_coef and .Slice == inf_coef.size) {
        for (1..) |i| {
            const next = coef[end - i];
            ex = switch (@typeInfo(X)) {
                .Int => x * ex + next,
                .Float => @mulAdd(X, x, ex, next),
                .Vector => @mulAdd(X, x, ex, @splat(next)),
                else => @compileError(@TypeName(X) ++ " unsupported."),
            };
        }
    } else {
        inline for (1..) |i| {
            const next = coef[end - i];
            ex = switch (@typeInfo(X)) {
                .Int => x * ex + next,
                .Float => @mulAdd(X, x, ex, next),
                .Vector => @mulAdd(X, x, ex, @splat(next)),
                else => @compileError(@TypeName(X) ++ " unsupported."),
            };
        }
    }
    return ex;
}

/// Computes `coef[0] + coef[1]*cos(x) + coef[2]*cos(2x) + coef[3]*cos(3x) + ...`
pub fn cos(x: anytype, coef: anytype) @TypeOf(x) {
    const X = @TypeOf(x);
    const head = coef[0];
    var ex: X = if (.Vector == @typeInfo(X)) @splat(head) else head;
    const inf_coef = @TypeInfo(@TypeOf(coef));
    if (.Pointer == inf_coef and .Slice == inf_coef.size) {
        for (1..) |i| {
            const next = coef[i];
            const basis = @cos(x * @floatFromInt(i));
            ex = switch (@typeInfo(X)) {
                .Float => @mulAdd(X, next, basis, ex),
                .Vector => @mulAdd(X, @splat(next), @splat(basis), ex),
                else => @compileError(@TypeName(X) ++ " unsupported."),
            };
        }
    } else {
        inline for (1..) |i| {
            const next = coef[i];
            const basis = @cos(x * @floatFromInt(i));
            ex = switch (@typeInfo(X)) {
                .Float => @mulAdd(X, next, basis, ex),
                .Vector => @mulAdd(X, @splat(next), @splat(basis), ex),
                else => @compileError(@TypeName(X) ++ " unsupported."),
            };
        }
    }
    return ex;
}

/// Computes `coef[1]*sin(x) + coef[2]*sin(2x) + coef[3]*sin(3x) + ...`
/// NOTE: coef[0] is ignored, since `sin(0*x) == 0`.
pub fn sin(x: anytype, coef: anytype) @TypeOf(x) {
    const X = @TypeOf(x);
    var ex: X = if (.Vector == @typeInfo(X)) @splat(0) else 0;
    const inf_coef = @TypeInfo(@TypeOf(coef));
    if (.Pointer == inf_coef and .Slice == inf_coef.size) {
        for (1..) |i| {
            const next = coef[i];
            const basis = @sin(x * @floatFromInt(i));
            ex = switch (@typeInfo(X)) {
                .Float => @mulAdd(X, next, basis, ex),
                .Vector => @mulAdd(X, @splat(next), @splat(basis), ex),
                else => @compileError(@TypeName(X) ++ " unsupported."),
            };
        }
    } else {
        inline for (1..) |i| {
            const next = coef[i];
            const basis = @sin(x * @floatFromInt(i));
            ex = switch (@typeInfo(X)) {
                .Float => @mulAdd(X, next, basis, ex),
                .Vector => @mulAdd(X, @splat(next), @splat(basis), ex),
                else => @compileError(@TypeName(X) ++ " unsupported."),
            };
        }
    }
    return ex;
}
