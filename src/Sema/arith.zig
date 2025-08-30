//! This file encapsules all arithmetic operations on comptime-known integers, floats, and vectors.
//!
//! It is only used in cases where both operands are comptime-known; a single comptime-known operand
//! is handled directly by `Sema.zig`.
//!
//! All public functions sanitize their inputs to the best of their knowledge.
//!
//! Functions starting with `int`, `comptimeInt`, or `float` are low-level primitives which operate
//! on defined scalar values; generally speaking, they are at the bottom of this file and non-`pub`.

/// Asserts that `ty` is a scalar integer type, and that `prev_val` is of type `ty`.
/// Returns a value one greater than `prev_val`. If this would overflow `ty,` then the
/// return value has `overflow` set, and `val` is instead a `comptime_int`.
pub fn incrementDefinedInt(
    sema: *Sema,
    ty: Type,
    prev_val: Value,
) CompileError!struct { overflow: bool, val: Value } {
    const pt = sema.pt;
    const zcu = pt.zcu;
    assert(prev_val.typeOf(zcu).toIntern() == ty.toIntern());
    assert(!prev_val.isUndef(zcu));
    const res = try intAdd(sema, prev_val, try pt.intValue(ty, 1), ty);
    return .{ .overflow = res.overflow, .val = res.val };
}

/// `val` is of type `ty`.
/// `ty` is a float, comptime_float, or vector thereof.
pub fn negateFloat(
    sema: *Sema,
    ty: Type,
    val: Value,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    if (val.isUndef(zcu)) return val;
    switch (ty.zigTypeTag(zcu)) {
        .vector => {
            const scalar_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);
            const result_elems = try sema.arena.alloc(InternPool.Index, len);
            for (result_elems, 0..) |*result_elem, elem_idx| {
                const elem = try val.elemValue(pt, elem_idx);
                if (elem.isUndef(zcu)) {
                    result_elem.* = elem.toIntern();
                } else {
                    result_elem.* = (try floatNeg(sema, elem, scalar_ty)).toIntern();
                }
            }
            return pt.aggregateValue(ty, result_elems);
        },
        .float, .comptime_float => return floatNeg(sema, val, ty),
        else => unreachable,
    }
}

/// Wraps on integers, but accepts floats.
/// `lhs_val` and `rhs_val` are both of type `ty`.
/// `ty` is an int, float, comptime_int, or comptime_float; *not* a vector.
pub fn addMaybeWrap(
    sema: *Sema,
    ty: Type,
    lhs: Value,
    rhs: Value,
) CompileError!Value {
    const zcu = sema.pt.zcu;
    if (lhs.isUndef(zcu)) return lhs;
    if (rhs.isUndef(zcu)) return rhs;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return (try intAddWithOverflow(sema, lhs, rhs, ty)).wrapped_result,
        .float, .comptime_float => return floatAdd(sema, lhs, rhs, ty),
        else => unreachable,
    }
}

/// Wraps on integers, but accepts floats.
/// `lhs_val` and `rhs_val` are both of type `ty`.
/// `ty` is an int, float, comptime_int, or comptime_float; *not* a vector.
pub fn subMaybeWrap(
    sema: *Sema,
    ty: Type,
    lhs: Value,
    rhs: Value,
) CompileError!Value {
    const zcu = sema.pt.zcu;
    if (lhs.isUndef(zcu)) return lhs;
    if (rhs.isUndef(zcu)) return rhs;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return (try intSubWithOverflow(sema, lhs, rhs, ty)).wrapped_result,
        .float, .comptime_float => return floatSub(sema, lhs, rhs, ty),
        else => unreachable,
    }
}

/// Wraps on integers, but accepts floats.
/// `lhs_val` and `rhs_val` are both of type `ty`.
/// `ty` is an int, float, comptime_int, or comptime_float; *not* a vector.
pub fn mulMaybeWrap(
    sema: *Sema,
    ty: Type,
    lhs: Value,
    rhs: Value,
) CompileError!Value {
    const zcu = sema.pt.zcu;
    if (lhs.isUndef(zcu)) return lhs;
    if (rhs.isUndef(zcu)) return rhs;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return (try intMulWithOverflow(sema, lhs, rhs, ty)).wrapped_result,
        .float, .comptime_float => return floatMul(sema, lhs, rhs, ty),
        else => unreachable,
    }
}

/// `lhs` and `rhs` are of type `ty`.
/// `ty` is an int, comptime_int, or vector thereof.
pub fn addWithOverflow(
    sema: *Sema,
    ty: Type,
    lhs: Value,
    rhs: Value,
) CompileError!Value.OverflowArithmeticResult {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return addWithOverflowScalar(sema, ty, lhs, rhs),
        .vector => {
            const scalar_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);
            switch (scalar_ty.zigTypeTag(zcu)) {
                .int, .comptime_int => {},
                else => unreachable,
            }
            const overflow_bits = try sema.arena.alloc(InternPool.Index, len);
            const wrapped_results = try sema.arena.alloc(InternPool.Index, len);
            for (overflow_bits, wrapped_results, 0..) |*ob, *wr, elem_idx| {
                const lhs_elem = try lhs.elemValue(pt, elem_idx);
                const rhs_elem = try rhs.elemValue(pt, elem_idx);
                const elem_result = try addWithOverflowScalar(sema, scalar_ty, lhs_elem, rhs_elem);
                ob.* = elem_result.overflow_bit.toIntern();
                wr.* = elem_result.wrapped_result.toIntern();
            }
            return .{
                .overflow_bit = try pt.aggregateValue(
                    try pt.vectorType(.{ .len = @intCast(overflow_bits.len), .child = .u1_type }),
                    overflow_bits,
                ),
                .wrapped_result = try pt.aggregateValue(ty, wrapped_results),
            };
        },
        else => unreachable,
    }
}
fn addWithOverflowScalar(
    sema: *Sema,
    ty: Type,
    lhs: Value,
    rhs: Value,
) CompileError!Value.OverflowArithmeticResult {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => {},
        else => unreachable,
    }
    if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return .{
        .overflow_bit = .undef_u1,
        .wrapped_result = try pt.undefValue(ty),
    };
    return intAddWithOverflow(sema, lhs, rhs, ty);
}

/// `lhs` and `rhs` are of type `ty`.
/// `ty` is an int, comptime_int, or vector thereof.
pub fn subWithOverflow(
    sema: *Sema,
    ty: Type,
    lhs: Value,
    rhs: Value,
) CompileError!Value.OverflowArithmeticResult {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return subWithOverflowScalar(sema, ty, lhs, rhs),
        .vector => {
            const scalar_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);
            switch (scalar_ty.zigTypeTag(zcu)) {
                .int, .comptime_int => {},
                else => unreachable,
            }
            const overflow_bits = try sema.arena.alloc(InternPool.Index, len);
            const wrapped_results = try sema.arena.alloc(InternPool.Index, len);
            for (overflow_bits, wrapped_results, 0..) |*ob, *wr, elem_idx| {
                const lhs_elem = try lhs.elemValue(pt, elem_idx);
                const rhs_elem = try rhs.elemValue(pt, elem_idx);
                const elem_result = try subWithOverflowScalar(sema, scalar_ty, lhs_elem, rhs_elem);
                ob.* = elem_result.overflow_bit.toIntern();
                wr.* = elem_result.wrapped_result.toIntern();
            }
            return .{
                .overflow_bit = try pt.aggregateValue(
                    try pt.vectorType(.{ .len = @intCast(overflow_bits.len), .child = .u1_type }),
                    overflow_bits,
                ),
                .wrapped_result = try pt.aggregateValue(ty, wrapped_results),
            };
        },
        else => unreachable,
    }
}
fn subWithOverflowScalar(
    sema: *Sema,
    ty: Type,
    lhs: Value,
    rhs: Value,
) CompileError!Value.OverflowArithmeticResult {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => {},
        else => unreachable,
    }
    if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return .{
        .overflow_bit = .undef_u1,
        .wrapped_result = try pt.undefValue(ty),
    };
    return intSubWithOverflow(sema, lhs, rhs, ty);
}

/// `lhs` and `rhs` are of type `ty`.
/// `ty` is an int, comptime_int, or vector thereof.
pub fn mulWithOverflow(
    sema: *Sema,
    ty: Type,
    lhs: Value,
    rhs: Value,
) CompileError!Value.OverflowArithmeticResult {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return mulWithOverflowScalar(sema, ty, lhs, rhs),
        .vector => {
            const scalar_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);
            switch (scalar_ty.zigTypeTag(zcu)) {
                .int, .comptime_int => {},
                else => unreachable,
            }
            const overflow_bits = try sema.arena.alloc(InternPool.Index, len);
            const wrapped_results = try sema.arena.alloc(InternPool.Index, len);
            for (overflow_bits, wrapped_results, 0..) |*ob, *wr, elem_idx| {
                const lhs_elem = try lhs.elemValue(pt, elem_idx);
                const rhs_elem = try rhs.elemValue(pt, elem_idx);
                const elem_result = try mulWithOverflowScalar(sema, scalar_ty, lhs_elem, rhs_elem);
                ob.* = elem_result.overflow_bit.toIntern();
                wr.* = elem_result.wrapped_result.toIntern();
            }
            return .{
                .overflow_bit = try pt.aggregateValue(
                    try pt.vectorType(.{ .len = @intCast(overflow_bits.len), .child = .u1_type }),
                    overflow_bits,
                ),
                .wrapped_result = try pt.aggregateValue(ty, wrapped_results),
            };
        },
        else => unreachable,
    }
}
fn mulWithOverflowScalar(
    sema: *Sema,
    ty: Type,
    lhs: Value,
    rhs: Value,
) CompileError!Value.OverflowArithmeticResult {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => {},
        else => unreachable,
    }
    if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return .{
        .overflow_bit = .undef_u1,
        .wrapped_result = try pt.undefValue(ty),
    };
    return intMulWithOverflow(sema, lhs, rhs, ty);
}

/// Applies the `+` operator to comptime-known values.
/// `lhs_val` and `rhs_val` are both of type `ty`.
/// `ty` is an int, float, comptime_int, comptime_float, or vector.
pub fn add(
    sema: *Sema,
    block: *Block,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return addScalar(sema, block, ty, lhs_val, rhs_val, src, lhs_src, rhs_src, true, null),
        .float, .comptime_float => return addScalar(sema, block, ty, lhs_val, rhs_val, src, lhs_src, rhs_src, false, null),
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const is_int = switch (elem_ty.zigTypeTag(zcu)) {
                .int, .comptime_int => true,
                .float, .comptime_float => false,
                else => unreachable,
            };

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try addScalar(sema, block, elem_ty, lhs_elem, rhs_elem, src, lhs_src, rhs_src, is_int, elem_idx)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => unreachable,
    }
}
fn addScalar(
    sema: *Sema,
    block: *Block,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    is_int: bool,
    vec_idx: ?usize,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    if (is_int) {
        if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src, vec_idx);
        if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src, vec_idx);
        const res = try intAdd(sema, lhs_val, rhs_val, ty);
        if (res.overflow) return sema.failWithIntegerOverflow(block, src, ty, res.val, vec_idx);
        return res.val;
    } else {
        if (lhs_val.isUndef(zcu)) return lhs_val;
        if (rhs_val.isUndef(zcu)) return rhs_val;
        return floatAdd(sema, lhs_val, rhs_val, ty);
    }
}

/// Applies the `+%` operator to comptime-known values.
/// `lhs_val` and `rhs_val` are both of type `ty`.
/// `ty` is an int, comptime_int, or vector thereof.
pub fn addWrap(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try addWrapScalar(sema, elem_ty, lhs_elem, rhs_elem)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => return addWrapScalar(sema, ty, lhs_val, rhs_val),
    }
}
fn addWrapScalar(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
) CompileError!Value {
    return (try addWithOverflowScalar(sema, ty, lhs_val, rhs_val)).wrapped_result;
}

/// Applies the `+|` operator to comptime-known values.
/// `lhs_val` and `rhs_val` are both of type `ty`.
/// `ty` is an int, comptime_int, or vector thereof.
pub fn addSat(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try addSatScalar(sema, elem_ty, lhs_elem, rhs_elem)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => return addSatScalar(sema, ty, lhs_val, rhs_val),
    }
}
fn addSatScalar(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const is_comptime_int = switch (ty.zigTypeTag(zcu)) {
        .int => false,
        .comptime_int => true,
        else => unreachable,
    };
    if (lhs_val.isUndef(zcu)) return lhs_val;
    if (rhs_val.isUndef(zcu)) return rhs_val;
    if (is_comptime_int) {
        const res = try intAdd(sema, lhs_val, rhs_val, ty);
        assert(!res.overflow);
        return res.val;
    } else {
        return intAddSat(sema, lhs_val, rhs_val, ty);
    }
}

/// Applies the `-` operator to comptime-known values.
/// `lhs_val` and `rhs_val` are both of type `ty`.
/// `ty` is an int, float, comptime_int, comptime_float, or vector.
pub fn sub(
    sema: *Sema,
    block: *Block,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return subScalar(sema, block, ty, lhs_val, rhs_val, src, lhs_src, rhs_src, true, null),
        .float, .comptime_float => return subScalar(sema, block, ty, lhs_val, rhs_val, src, lhs_src, rhs_src, false, null),
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const is_int = switch (elem_ty.zigTypeTag(zcu)) {
                .int, .comptime_int => true,
                .float, .comptime_float => false,
                else => unreachable,
            };

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try subScalar(sema, block, elem_ty, lhs_elem, rhs_elem, src, lhs_src, rhs_src, is_int, elem_idx)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => unreachable,
    }
}
fn subScalar(
    sema: *Sema,
    block: *Block,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    is_int: bool,
    vec_idx: ?usize,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    if (is_int) {
        if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src, vec_idx);
        if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src, vec_idx);
        const res = try intSub(sema, lhs_val, rhs_val, ty);
        if (res.overflow) return sema.failWithIntegerOverflow(block, src, ty, res.val, vec_idx);
        return res.val;
    } else {
        if (lhs_val.isUndef(zcu)) return lhs_val;
        if (rhs_val.isUndef(zcu)) return rhs_val;
        return floatSub(sema, lhs_val, rhs_val, ty);
    }
}

/// Applies the `-%` operator to comptime-known values.
/// `lhs_val` and `rhs_val` are both of type `ty`.
/// `ty` is an int, comptime_int, or vector thereof.
pub fn subWrap(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try subWrapScalar(sema, elem_ty, lhs_elem, rhs_elem)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => return subWrapScalar(sema, ty, lhs_val, rhs_val),
    }
}
fn subWrapScalar(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => {},
        else => unreachable,
    }
    if (lhs_val.isUndef(zcu)) return lhs_val;
    if (rhs_val.isUndef(zcu)) return rhs_val;
    const result = try intSubWithOverflow(sema, lhs_val, rhs_val, ty);
    return result.wrapped_result;
}

/// Applies the `-|` operator to comptime-known values.
/// `lhs_val` and `rhs_val` are both of type `ty`.
/// `ty` is an int, comptime_int, or vector thereof.
pub fn subSat(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try subSatScalar(sema, elem_ty, lhs_elem, rhs_elem)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => return subSatScalar(sema, ty, lhs_val, rhs_val),
    }
}
fn subSatScalar(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const is_comptime_int = switch (ty.zigTypeTag(zcu)) {
        .int => false,
        .comptime_int => true,
        else => unreachable,
    };
    if (lhs_val.isUndef(zcu)) return lhs_val;
    if (rhs_val.isUndef(zcu)) return rhs_val;
    if (is_comptime_int) {
        const res = try intSub(sema, lhs_val, rhs_val, ty);
        assert(!res.overflow);
        return res.val;
    } else {
        return intSubSat(sema, lhs_val, rhs_val, ty);
    }
}

/// Applies the `*` operator to comptime-known values.
/// `lhs_val` and `rhs_val` are fully-resolved values of type `ty`.
/// `ty` is an int, float, comptime_int, comptime_float, or vector.
pub fn mul(
    sema: *Sema,
    block: *Block,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return mulScalar(sema, block, ty, lhs_val, rhs_val, src, lhs_src, rhs_src, true, null),
        .float, .comptime_float => return mulScalar(sema, block, ty, lhs_val, rhs_val, src, lhs_src, rhs_src, false, null),
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const is_int = switch (elem_ty.zigTypeTag(zcu)) {
                .int, .comptime_int => true,
                .float, .comptime_float => false,
                else => unreachable,
            };

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try mulScalar(sema, block, elem_ty, lhs_elem, rhs_elem, src, lhs_src, rhs_src, is_int, elem_idx)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => unreachable,
    }
}
fn mulScalar(
    sema: *Sema,
    block: *Block,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    is_int: bool,
    vec_idx: ?usize,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    if (is_int) {
        if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src, vec_idx);
        if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src, vec_idx);
        const res = try intMul(sema, lhs_val, rhs_val, ty);
        if (res.overflow) return sema.failWithIntegerOverflow(block, src, ty, res.val, vec_idx);
        return res.val;
    } else {
        if (lhs_val.isUndef(zcu)) return lhs_val;
        if (rhs_val.isUndef(zcu)) return rhs_val;
        return floatMul(sema, lhs_val, rhs_val, ty);
    }
}

/// Applies the `*%` operator to comptime-known values.
/// `lhs_val` and `rhs_val` are both of type `ty`.
/// `ty` is an int, comptime_int, or vector thereof.
pub fn mulWrap(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try mulWrapScalar(sema, elem_ty, lhs_elem, rhs_elem)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => return mulWrapScalar(sema, ty, lhs_val, rhs_val),
    }
}
fn mulWrapScalar(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => {},
        else => unreachable,
    }
    if (lhs_val.isUndef(zcu)) return lhs_val;
    if (rhs_val.isUndef(zcu)) return rhs_val;
    const result = try intMulWithOverflow(sema, lhs_val, rhs_val, ty);
    return result.wrapped_result;
}

/// Applies the `*|` operator to comptime-known values.
/// `lhs_val` and `rhs_val` are both of type `ty`.
/// `ty` is an int, comptime_int, or vector thereof.
pub fn mulSat(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try mulSatScalar(sema, elem_ty, lhs_elem, rhs_elem)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => return mulSatScalar(sema, ty, lhs_val, rhs_val),
    }
}
fn mulSatScalar(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const is_comptime_int = switch (ty.zigTypeTag(zcu)) {
        .int => false,
        .comptime_int => true,
        else => unreachable,
    };
    if (lhs_val.isUndef(zcu)) return lhs_val;
    if (rhs_val.isUndef(zcu)) return rhs_val;
    if (is_comptime_int) {
        const res = try intMul(sema, lhs_val, rhs_val, ty);
        assert(!res.overflow);
        return res.val;
    } else {
        return intMulSat(sema, lhs_val, rhs_val, ty);
    }
}

pub const DivOp = enum { div, div_trunc, div_floor, div_exact };

/// Applies the `/` operator to comptime-known values.
/// `lhs_val` and `rhs_val` are fully-resolved values of type `ty`.
/// `ty` is an int, float, comptime_int, comptime_float, or vector.
pub fn div(
    sema: *Sema,
    block: *Block,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    op: DivOp,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return divScalar(sema, block, ty, lhs_val, rhs_val, src, lhs_src, rhs_src, op, true, null),
        .float, .comptime_float => return divScalar(sema, block, ty, lhs_val, rhs_val, src, lhs_src, rhs_src, op, false, null),
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const is_int = switch (elem_ty.zigTypeTag(zcu)) {
                .int, .comptime_int => true,
                .float, .comptime_float => false,
                else => unreachable,
            };

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try divScalar(sema, block, elem_ty, lhs_elem, rhs_elem, src, lhs_src, rhs_src, op, is_int, elem_idx)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => unreachable,
    }
}
fn divScalar(
    sema: *Sema,
    block: *Block,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    op: DivOp,
    is_int: bool,
    vec_idx: ?usize,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    if (is_int) {
        if (rhs_val.eqlScalarNum(.zero_comptime_int, zcu)) return sema.failWithDivideByZero(block, rhs_src);

        if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src, vec_idx);
        if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src, vec_idx);

        switch (op) {
            .div, .div_trunc => {
                const res = try intDivTrunc(sema, lhs_val, rhs_val, ty);
                if (res.overflow) return sema.failWithIntegerOverflow(block, src, ty, res.val, vec_idx);
                return res.val;
            },
            .div_floor => {
                const res = try intDivFloor(sema, lhs_val, rhs_val, ty);
                if (res.overflow) return sema.failWithIntegerOverflow(block, src, ty, res.val, vec_idx);
                return res.val;
            },
            .div_exact => switch (try intDivExact(sema, lhs_val, rhs_val, ty)) {
                .remainder => return sema.fail(block, src, "exact division produced remainder", .{}),
                .overflow => |val| return sema.failWithIntegerOverflow(block, src, ty, val, vec_idx),
                .success => |val| return val,
            },
        }
    } else {
        const allow_div_zero = switch (op) {
            .div, .div_trunc, .div_floor => ty.toIntern() != .comptime_float_type and block.float_mode == .strict,
            .div_exact => false,
        };
        if (!allow_div_zero) {
            if (rhs_val.eqlScalarNum(.zero_comptime_int, zcu)) return sema.failWithDivideByZero(block, rhs_src);
        }

        const can_exhibit_ib = !allow_div_zero or op == .div_exact;
        if (can_exhibit_ib) {
            if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src, vec_idx);
            if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src, vec_idx);
        } else {
            if (lhs_val.isUndef(zcu)) return lhs_val;
            if (rhs_val.isUndef(zcu)) return rhs_val;
        }

        switch (op) {
            .div => return floatDiv(sema, lhs_val, rhs_val, ty),
            .div_trunc => return floatDivTrunc(sema, lhs_val, rhs_val, ty),
            .div_floor => return floatDivFloor(sema, lhs_val, rhs_val, ty),
            .div_exact => {
                if (!floatDivIsExact(sema, lhs_val, rhs_val, ty)) {
                    return sema.fail(block, src, "exact division produced remainder", .{});
                }
                return floatDivTrunc(sema, lhs_val, rhs_val, ty);
            },
        }
    }
}

pub const ModRemOp = enum { mod, rem };

/// Applies `@mod` or `@rem` to comptime-known values.
/// `lhs_val` and `rhs_val` are fully-resolved values of type `ty`.
/// `ty` is an int, float, comptime_int, comptime_float, or vector.
pub fn modRem(
    sema: *Sema,
    block: *Block,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    op: ModRemOp,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try modRemScalar(sema, block, elem_ty, lhs_elem, rhs_elem, lhs_src, rhs_src, op, elem_idx)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => return modRemScalar(sema, block, ty, lhs_val, rhs_val, lhs_src, rhs_src, op, null),
    }
}
fn modRemScalar(
    sema: *Sema,
    block: *Block,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    op: ModRemOp,
    vec_idx: ?usize,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const is_int = switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => true,
        .float, .comptime_float => false,
        else => unreachable,
    };

    const allow_div_zero = !is_int and block.float_mode == .strict;
    if (allow_div_zero) {
        if (lhs_val.isUndef(zcu)) return lhs_val;
        if (rhs_val.isUndef(zcu)) return rhs_val;
    } else {
        if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src, vec_idx);
        if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src, vec_idx);
        if (rhs_val.eqlScalarNum(.zero_comptime_int, zcu)) return sema.failWithDivideByZero(block, rhs_src);
    }

    if (is_int) {
        switch (op) {
            .mod => return intMod(sema, lhs_val, rhs_val, ty),
            .rem => return intRem(sema, lhs_val, rhs_val, ty),
        }
    } else {
        switch (op) {
            .mod => return floatMod(sema, lhs_val, rhs_val, ty),
            .rem => return floatRem(sema, lhs_val, rhs_val, ty),
        }
    }
}

pub const ShlOp = enum { shl, shl_sat, shl_exact };

/// Applies the `<<` operator to comptime-known values.
/// `lhs_ty` is an int, comptime_int, or vector thereof.
/// If it is a vector, the type of `rhs` has to also be a vector of the same length.
pub fn shl(
    sema: *Sema,
    block: *Block,
    lhs_ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    op: ShlOp,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (lhs_ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return shlScalar(sema, block, lhs_ty, lhs_val, rhs_val, src, lhs_src, rhs_src, op, null),
        .vector => {
            const lhs_elem_ty = lhs_ty.childType(zcu);
            const len = lhs_ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try shlScalar(sema, block, lhs_elem_ty, lhs_elem, rhs_elem, src, lhs_src, rhs_src, op, elem_idx)).toIntern();
            }
            return pt.aggregateValue(lhs_ty, elem_vals);
        },
        else => unreachable,
    }
}
/// `lhs_ty` is an int, comptime_int, or vector thereof.
/// If it is a vector, the type of `rhs` has to also be a vector of the same length.
pub fn shlWithOverflow(
    sema: *Sema,
    block: *Block,
    lhs_ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
) CompileError!Value.OverflowArithmeticResult {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (lhs_ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return shlWithOverflowScalar(sema, block, lhs_ty, lhs_val, rhs_val, lhs_src, rhs_src, null),
        .vector => {
            const lhs_elem_ty = lhs_ty.childType(zcu);
            const len = lhs_ty.vectorLen(zcu);

            const overflow_bits = try sema.arena.alloc(InternPool.Index, len);
            const wrapped_results = try sema.arena.alloc(InternPool.Index, len);
            for (overflow_bits, wrapped_results, 0..) |*ob, *wr, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                const elem_result = try shlWithOverflowScalar(sema, block, lhs_elem_ty, lhs_elem, rhs_elem, lhs_src, rhs_src, elem_idx);
                ob.* = elem_result.overflow_bit.toIntern();
                wr.* = elem_result.wrapped_result.toIntern();
            }
            return .{
                .overflow_bit = try pt.aggregateValue(try pt.vectorType(.{
                    .len = @intCast(overflow_bits.len),
                    .child = .u1_type,
                }), overflow_bits),
                .wrapped_result = try pt.aggregateValue(lhs_ty, wrapped_results),
            };
        },
        else => unreachable,
    }
}

fn shlScalar(
    sema: *Sema,
    block: *Block,
    lhs_ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    op: ShlOp,
    vec_idx: ?usize,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    switch (op) {
        .shl, .shl_exact => {
            if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src, vec_idx);
            if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src, vec_idx);
        },
        .shl_sat => {
            if (lhs_val.isUndef(zcu)) return lhs_val;
            if (rhs_val.isUndef(zcu)) return rhs_val;
        },
    }
    switch (try rhs_val.orderAgainstZeroSema(pt)) {
        .gt => {},
        .eq => return lhs_val,
        .lt => return sema.failWithNegativeShiftAmount(block, rhs_src, rhs_val, vec_idx),
    }
    switch (lhs_ty.zigTypeTag(zcu)) {
        .int => switch (op) {
            .shl => return intShl(sema, block, lhs_ty, lhs_val, rhs_val, rhs_src, vec_idx),
            .shl_sat => return intShlSat(sema, lhs_ty, lhs_val, rhs_val),
            .shl_exact => {
                const shifted = try intShlWithOverflow(sema, block, lhs_ty, lhs_val, rhs_val, rhs_src, false, vec_idx);
                if (shifted.overflow) {
                    return sema.failWithIntegerOverflow(block, src, lhs_ty, shifted.val, vec_idx);
                }
                return shifted.val;
            },
        },
        .comptime_int => return comptimeIntShl(sema, block, lhs_val, rhs_val, rhs_src, vec_idx),
        else => unreachable,
    }
}
fn shlWithOverflowScalar(
    sema: *Sema,
    block: *Block,
    lhs_ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    vec_idx: ?usize,
) CompileError!Value.OverflowArithmeticResult {
    const pt = sema.pt;
    const zcu = pt.zcu;

    if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src, vec_idx);
    if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src, vec_idx);

    switch (try rhs_val.orderAgainstZeroSema(pt)) {
        .gt => {},
        .eq => return .{ .overflow_bit = .zero_u1, .wrapped_result = lhs_val },
        .lt => return sema.failWithNegativeShiftAmount(block, rhs_src, rhs_val, vec_idx),
    }
    switch (lhs_ty.zigTypeTag(zcu)) {
        .int => {
            const result = try intShlWithOverflow(sema, block, lhs_ty, lhs_val, rhs_val, rhs_src, true, vec_idx);
            return .{
                .overflow_bit = try pt.intValue(.u1, @intFromBool(result.overflow)),
                .wrapped_result = result.val,
            };
        },
        .comptime_int => return .{
            .overflow_bit = .zero_u1,
            .wrapped_result = try comptimeIntShl(sema, block, lhs_val, rhs_val, rhs_src, vec_idx),
        },
        else => unreachable,
    }
}

pub const ShrOp = enum { shr, shr_exact };

/// Applies the `>>` operator to comptime-known values.
/// `lhs_ty` is an int, comptime_int, or vector thereof.
/// If it is a vector, the type of `rhs` has to also be a vector of the same length.
pub fn shr(
    sema: *Sema,
    block: *Block,
    lhs_ty: Type,
    rhs_ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    op: ShrOp,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    switch (lhs_ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return shrScalar(sema, block, lhs_ty, rhs_ty, lhs_val, rhs_val, src, lhs_src, rhs_src, op, null),
        .vector => {
            const lhs_elem_ty = lhs_ty.childType(zcu);
            const rhs_elem_ty = rhs_ty.childType(zcu);
            const len = lhs_ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try shrScalar(sema, block, lhs_elem_ty, rhs_elem_ty, lhs_elem, rhs_elem, src, lhs_src, rhs_src, op, elem_idx)).toIntern();
            }
            return pt.aggregateValue(lhs_ty, elem_vals);
        },
        else => unreachable,
    }
}

fn shrScalar(
    sema: *Sema,
    block: *Block,
    lhs_ty: Type,
    rhs_ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    op: ShrOp,
    vec_idx: ?usize,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src, vec_idx);
    if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src, vec_idx);

    switch (try rhs_val.orderAgainstZeroSema(pt)) {
        .gt => {},
        .eq => return lhs_val,
        .lt => return sema.failWithNegativeShiftAmount(block, rhs_src, rhs_val, vec_idx),
    }
    return intShr(sema, block, lhs_ty, rhs_ty, lhs_val, rhs_val, src, rhs_src, op, vec_idx);
}

/// Applies `@truncate` to comptime-known values.
/// `ty` is an int, comptime_int, or vector thereof.
/// `val` is of type `ty`.
/// The returned value is of type `dest_ty`. The caller guarantees that the
/// truncated value fits into `dest_ty`.
/// If `ty` is a vector, `dest_ty` has to also be a vector of the same length.
pub fn truncate(
    sema: *Sema,
    val: Value,
    ty: Type,
    dest_ty: Type,
    dest_signedness: std.builtin.Signedness,
    dest_bits: u16,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    if (val.isUndef(zcu)) return pt.undefValue(dest_ty);
    switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => return intTruncate(sema, val, dest_ty, dest_signedness, dest_bits),
        .vector => {
            const dest_elem_ty = dest_ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const elem_val = try val.elemValue(pt, elem_idx);
                result_elem.* = if (elem_val.isUndef(zcu))
                    (try pt.undefValue(dest_elem_ty)).toIntern()
                else
                    (try intTruncate(
                        sema,
                        elem_val,
                        dest_elem_ty,
                        dest_signedness,
                        dest_bits,
                    )).toIntern();
            }
            return pt.aggregateValue(dest_ty, elem_vals);
        },
        else => unreachable,
    }
}

/// Applies the `~` operator to a comptime-known value.
/// `val` is of type `ty`.
/// `ty` is a bool, int, comptime_int, or vector thereof.
pub fn bitwiseNot(sema: *Sema, ty: Type, val: Value) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    if (val.isUndef(zcu)) return val;
    switch (ty.zigTypeTag(zcu)) {
        .bool, .int, .comptime_int => return intBitwiseNot(sema, val, ty),
        .vector => {
            const elem_ty = ty.childType(zcu);
            switch (elem_ty.zigTypeTag(zcu)) {
                .bool, .int, .comptime_int => {},
                else => unreachable,
            }
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const elem_val = try val.elemValue(pt, elem_idx);
                result_elem.* = if (elem_val.isUndef(zcu))
                    elem_val.toIntern()
                else
                    (try intBitwiseNot(sema, elem_val, elem_ty)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => unreachable,
    }
}

pub const BitwiseBinOp = enum { @"and", nand, @"or", xor };

/// Applies a binary bitwise operator to comptime-known values.
/// `lhs_val` and `rhs_val` are both of type `ty`.
/// `ty` is a bool, int, comptime_int, or vector thereof.
pub fn bitwiseBin(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    op: BitwiseBinOp,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .vector => {
            const elem_ty = ty.childType(zcu);
            switch (elem_ty.zigTypeTag(zcu)) {
                .bool, .int, .comptime_int => {},
                else => unreachable,
            }
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try bitwiseBinScalar(sema, elem_ty, lhs_elem, rhs_elem, op)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        .bool, .int, .comptime_int => return bitwiseBinScalar(sema, ty, lhs_val, rhs_val, op),
        else => unreachable,
    }
}
fn bitwiseBinScalar(
    sema: *Sema,
    ty: Type,
    lhs_val: Value,
    rhs_val: Value,
    op: BitwiseBinOp,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    // Special case: the method used below doesn't make sense for xor.
    if (op == .xor and (lhs_val.isUndef(zcu) or rhs_val.isUndef(zcu))) return pt.undefValue(ty);
    // If one operand is defined, we turn the other into `0xAA` so the bitwise op can
    // still zero out some bits.
    // TODO: ideally we'd still like tracking for the undef bits. Related: #19634.
    const def_lhs: Value, const def_rhs: Value = make_defined: {
        const lhs_undef = lhs_val.isUndef(zcu);
        const rhs_undef = rhs_val.isUndef(zcu);
        break :make_defined switch ((@as(u2, @intFromBool(lhs_undef)) << 1) | @intFromBool(rhs_undef)) {
            0b00 => .{ lhs_val, rhs_val },
            0b01 => .{ lhs_val, try intValueAa(sema, ty) },
            0b10 => .{ try intValueAa(sema, ty), rhs_val },
            0b11 => return pt.undefValue(ty),
        };
    };
    if (ty.toIntern() == .u0_type or ty.toIntern() == .i0_type) return pt.intValue(ty, 0);
    // zig fmt: off
    switch (op) {
        .@"and" => return intBitwiseAnd(sema, def_lhs, def_rhs, ty),
        .nand   => return intBitwiseNand(sema, def_lhs, def_rhs, ty),
        .@"or"  => return intBitwiseOr(sema, def_lhs, def_rhs, ty),
        .xor    => return intBitwiseXor(sema, def_lhs, def_rhs, ty),
    }
    // zig fmt: on
}

/// Applies `@bitReverse` to a comptime-known value.
/// `val` is of type `ty`.
/// `ty` is an int or a vector thereof.
pub fn bitReverse(sema: *Sema, val: Value, ty: Type) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    if (val.isUndef(zcu)) return val;
    switch (ty.zigTypeTag(zcu)) {
        .int => return intBitReverse(sema, val, ty),
        .vector => {
            const elem_ty = ty.childType(zcu);
            assert(elem_ty.isInt(zcu));
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const elem_val = try val.elemValue(pt, elem_idx);
                result_elem.* = if (elem_val.isUndef(zcu))
                    elem_val.toIntern()
                else
                    (try intBitReverse(sema, elem_val, elem_ty)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => unreachable,
    }
}

/// Applies `@byteSwap` to a comptime-known value.
/// `val` is of type `ty`.
/// `ty` is an int or a vector thereof.
/// The bit width of the scalar int type of `ty` has to be a multiple of 8.
pub fn byteSwap(sema: *Sema, val: Value, ty: Type) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    if (val.isUndef(zcu)) return val;
    switch (ty.zigTypeTag(zcu)) {
        .int => return intByteSwap(sema, val, ty),
        .vector => {
            const elem_ty = ty.childType(zcu);
            assert(elem_ty.isInt(zcu));
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const elem_val = try val.elemValue(pt, elem_idx);
                result_elem.* = if (elem_val.isUndef(zcu))
                    elem_val.toIntern()
                else
                    (try intByteSwap(sema, elem_val, elem_ty)).toIntern();
            }
            return pt.aggregateValue(ty, elem_vals);
        },
        else => unreachable,
    }
}

/// If the value overflowed the type, returns a comptime_int instead.
/// Only supports scalars.
fn intAdd(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !struct { overflow: bool, val: Value } {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.toIntern()) {
        .comptime_int_type => return .{ .overflow = false, .val = try comptimeIntAdd(sema, lhs, rhs) },
        else => {
            const res = try intAddWithOverflowInner(sema, lhs, rhs, ty);
            return switch (res.overflow_bit.toUnsignedInt(zcu)) {
                0 => .{ .overflow = false, .val = res.wrapped_result },
                1 => .{ .overflow = true, .val = try comptimeIntAdd(sema, lhs, rhs) },
                else => unreachable,
            };
        },
    }
}
/// Add two integers, returning a `comptime_int` regardless of the input types.
fn comptimeIntAdd(sema: *Sema, lhs: Value, rhs: Value) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.add(lhs_bigint, rhs_bigint);
    return pt.intValue_big(.comptime_int, result_bigint.toConst());
}
fn intAddWithOverflow(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value.OverflowArithmeticResult {
    switch (ty.toIntern()) {
        .comptime_int_type => return .{
            .overflow_bit = .zero_u1,
            .wrapped_result = try comptimeIntAdd(sema, lhs, rhs),
        },
        else => return intAddWithOverflowInner(sema, lhs, rhs, ty),
    }
}
/// Like `intAddWithOverflow`, but asserts that `ty` is not `Type.comptime_int`.
fn intAddWithOverflowInner(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value.OverflowArithmeticResult {
    assert(ty.toIntern() != .comptime_int_type);
    const pt = sema.pt;
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = try lhs.toBigIntSema(&lhs_space, pt);
    const rhs_bigint = try rhs.toBigIntSema(&rhs_space, pt);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    const overflowed = result_bigint.addWrap(lhs_bigint, rhs_bigint, info.signedness, info.bits);
    return .{
        .overflow_bit = try pt.intValue(.u1, @intFromBool(overflowed)),
        .wrapped_result = try pt.intValue_big(ty, result_bigint.toConst()),
    };
}
fn intAddSat(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.addSat(lhs_bigint, rhs_bigint, info.signedness, info.bits);
    return pt.intValue_big(ty, result_bigint.toConst());
}

/// If the value overflowed the type, returns a comptime_int instead.
/// Only supports scalars.
fn intSub(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !struct { overflow: bool, val: Value } {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.toIntern()) {
        .comptime_int_type => return .{ .overflow = false, .val = try comptimeIntSub(sema, lhs, rhs) },
        else => {
            const res = try intSubWithOverflowInner(sema, lhs, rhs, ty);
            return switch (res.overflow_bit.toUnsignedInt(zcu)) {
                0 => .{ .overflow = false, .val = res.wrapped_result },
                1 => .{ .overflow = true, .val = try comptimeIntSub(sema, lhs, rhs) },
                else => unreachable,
            };
        },
    }
}
/// Subtract two integers, returning a `comptime_int` regardless of the input types.
fn comptimeIntSub(sema: *Sema, lhs: Value, rhs: Value) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.sub(lhs_bigint, rhs_bigint);
    return pt.intValue_big(.comptime_int, result_bigint.toConst());
}
fn intSubWithOverflow(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value.OverflowArithmeticResult {
    switch (ty.toIntern()) {
        .comptime_int_type => return .{
            .overflow_bit = .zero_u1,
            .wrapped_result = try comptimeIntSub(sema, lhs, rhs),
        },
        else => return intSubWithOverflowInner(sema, lhs, rhs, ty),
    }
}
/// Like `intSubWithOverflow`, but asserts that `ty` is not `Type.comptime_int`.
fn intSubWithOverflowInner(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value.OverflowArithmeticResult {
    assert(ty.toIntern() != .comptime_int_type);
    const pt = sema.pt;
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = try lhs.toBigIntSema(&lhs_space, pt);
    const rhs_bigint = try rhs.toBigIntSema(&rhs_space, pt);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    const overflowed = result_bigint.subWrap(lhs_bigint, rhs_bigint, info.signedness, info.bits);
    return .{
        .overflow_bit = try pt.intValue(.u1, @intFromBool(overflowed)),
        .wrapped_result = try pt.intValue_big(ty, result_bigint.toConst()),
    };
}
fn intSubSat(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.subSat(lhs_bigint, rhs_bigint, info.signedness, info.bits);
    return pt.intValue_big(ty, result_bigint.toConst());
}

/// If the value overflowed the type, returns a comptime_int instead.
/// Only supports scalars.
fn intMul(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !struct { overflow: bool, val: Value } {
    const pt = sema.pt;
    const zcu = pt.zcu;
    switch (ty.toIntern()) {
        .comptime_int_type => return .{ .overflow = false, .val = try comptimeIntMul(sema, lhs, rhs) },
        else => {
            const res = try intMulWithOverflowInner(sema, lhs, rhs, ty);
            return switch (res.overflow_bit.toUnsignedInt(zcu)) {
                0 => .{ .overflow = false, .val = res.wrapped_result },
                1 => .{ .overflow = true, .val = try comptimeIntMul(sema, lhs, rhs) },
                else => unreachable,
            };
        },
    }
}
/// Multiply two integers, returning a `comptime_int` regardless of the input types.
fn comptimeIntMul(sema: *Sema, lhs: Value, rhs: Value) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len + rhs_bigint.limbs.len,
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    const limbs_buffer = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcMulLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len, 1),
    );
    result_bigint.mul(lhs_bigint, rhs_bigint, limbs_buffer, sema.arena);
    return pt.intValue_big(.comptime_int, result_bigint.toConst());
}
fn intMulWithOverflow(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value.OverflowArithmeticResult {
    switch (ty.toIntern()) {
        .comptime_int_type => return .{
            .overflow_bit = .zero_u1,
            .wrapped_result = try comptimeIntMul(sema, lhs, rhs),
        },
        else => return intMulWithOverflowInner(sema, lhs, rhs, ty),
    }
}
/// Like `intMulWithOverflow`, but asserts that `ty` is not `Type.comptime_int`.
fn intMulWithOverflowInner(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value.OverflowArithmeticResult {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = try lhs.toBigIntSema(&lhs_space, pt);
    const rhs_bigint = try rhs.toBigIntSema(&rhs_space, pt);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len + rhs_bigint.limbs.len,
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.mulNoAlias(lhs_bigint, rhs_bigint, sema.arena);
    const overflowed = !result_bigint.toConst().fitsInTwosComp(info.signedness, info.bits);
    if (overflowed) result_bigint.truncate(result_bigint.toConst(), info.signedness, info.bits);
    return .{
        .overflow_bit = try pt.intValue(.u1, @intFromBool(overflowed)),
        .wrapped_result = try pt.intValue_big(ty, result_bigint.toConst()),
    };
}
fn intMulSat(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len + rhs_bigint.limbs.len,
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.mulNoAlias(lhs_bigint, rhs_bigint, sema.arena);
    result_bigint.saturate(result_bigint.toConst(), info.signedness, info.bits);
    return pt.intValue_big(ty, result_bigint.toConst());
}
fn intDivTrunc(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !struct { overflow: bool, val: Value } {
    const result = intDivTruncInner(sema, lhs, rhs, ty) catch |err| switch (err) {
        error.Overflow => {
            const result = intDivTruncInner(sema, lhs, rhs, .comptime_int) catch |err1| switch (err1) {
                error.Overflow => unreachable,
                else => |e| return e,
            };
            return .{ .overflow = true, .val = result };
        },
        else => |e| return e,
    };
    return .{ .overflow = false, .val = result };
}
fn intDivTruncInner(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs_q = try sema.arena.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len,
    );
    const limbs_r = try sema.arena.alloc(
        std.math.big.Limb,
        rhs_bigint.limbs.len,
    );
    const limbs_buf = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    var result_q: BigIntMutable = .{ .limbs = limbs_q, .positive = undefined, .len = undefined };
    var result_r: BigIntMutable = .{ .limbs = limbs_r, .positive = undefined, .len = undefined };
    result_q.divTrunc(&result_r, lhs_bigint, rhs_bigint, limbs_buf);
    if (ty.toIntern() != .comptime_int_type) {
        const info = ty.intInfo(zcu);
        if (!result_q.toConst().fitsInTwosComp(info.signedness, info.bits)) {
            return error.Overflow;
        }
    }
    return pt.intValue_big(ty, result_q.toConst());
}
fn intDivExact(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !union(enum) {
    remainder,
    overflow: Value,
    success: Value,
} {
    const pt = sema.pt;
    const zcu = pt.zcu;
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs_q = try sema.arena.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len,
    );
    const limbs_r = try sema.arena.alloc(
        std.math.big.Limb,
        rhs_bigint.limbs.len,
    );
    const limbs_buf = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    var result_q: BigIntMutable = .{ .limbs = limbs_q, .positive = undefined, .len = undefined };
    var result_r: BigIntMutable = .{ .limbs = limbs_r, .positive = undefined, .len = undefined };
    result_q.divTrunc(&result_r, lhs_bigint, rhs_bigint, limbs_buf);
    if (!result_r.toConst().eqlZero()) {
        return .remainder;
    }
    if (ty.toIntern() != .comptime_int_type) {
        const info = ty.intInfo(zcu);
        if (!result_q.toConst().fitsInTwosComp(info.signedness, info.bits)) {
            return .{ .overflow = try pt.intValue_big(.comptime_int, result_q.toConst()) };
        }
    }
    return .{ .success = try pt.intValue_big(ty, result_q.toConst()) };
}
fn intDivFloor(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !struct { overflow: bool, val: Value } {
    const result = intDivFloorInner(sema, lhs, rhs, ty) catch |err| switch (err) {
        error.Overflow => {
            const result = intDivFloorInner(sema, lhs, rhs, .comptime_int) catch |err1| switch (err1) {
                error.Overflow => unreachable,
                else => |e| return e,
            };
            return .{ .overflow = true, .val = result };
        },
        else => |e| return e,
    };
    return .{ .overflow = false, .val = result };
}
fn intDivFloorInner(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs_q = try sema.arena.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len,
    );
    const limbs_r = try sema.arena.alloc(
        std.math.big.Limb,
        rhs_bigint.limbs.len,
    );
    const limbs_buf = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    var result_q: BigIntMutable = .{ .limbs = limbs_q, .positive = undefined, .len = undefined };
    var result_r: BigIntMutable = .{ .limbs = limbs_r, .positive = undefined, .len = undefined };
    result_q.divFloor(&result_r, lhs_bigint, rhs_bigint, limbs_buf);
    if (ty.toIntern() != .comptime_int_type) {
        const info = ty.intInfo(zcu);
        if (!result_q.toConst().fitsInTwosComp(info.signedness, info.bits)) {
            return error.Overflow;
        }
    }
    return pt.intValue_big(ty, result_q.toConst());
}
fn intMod(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs_q = try sema.arena.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len,
    );
    const limbs_r = try sema.arena.alloc(
        std.math.big.Limb,
        rhs_bigint.limbs.len,
    );
    const limbs_buf = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    var result_q: BigIntMutable = .{ .limbs = limbs_q, .positive = undefined, .len = undefined };
    var result_r: BigIntMutable = .{ .limbs = limbs_r, .positive = undefined, .len = undefined };
    result_q.divFloor(&result_r, lhs_bigint, rhs_bigint, limbs_buf);
    return pt.intValue_big(ty, result_r.toConst());
}
fn intRem(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs_q = try sema.arena.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len,
    );
    const limbs_r = try sema.arena.alloc(
        std.math.big.Limb,
        rhs_bigint.limbs.len,
    );
    const limbs_buf = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    var result_q: BigIntMutable = .{ .limbs = limbs_q, .positive = undefined, .len = undefined };
    var result_r: BigIntMutable = .{ .limbs = limbs_r, .positive = undefined, .len = undefined };
    result_q.divTrunc(&result_r, lhs_bigint, rhs_bigint, limbs_buf);
    return pt.intValue_big(ty, result_r.toConst());
}

fn intTruncate(
    sema: *Sema,
    val: Value,
    dest_ty: Type,
    dest_signedness: std.builtin.Signedness,
    dest_bits: u16,
) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    var val_space: Value.BigIntSpace = undefined;
    const val_bigint = val.toBigInt(&val_space, zcu);

    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(dest_bits),
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.truncate(val_bigint, dest_signedness, dest_bits);
    return pt.intValue_big(dest_ty, result_bigint.toConst());
}

fn intShl(
    sema: *Sema,
    block: *Block,
    lhs_ty: Type,
    lhs: Value,
    rhs: Value,
    rhs_src: LazySrcLoc,
    vec_idx: ?usize,
) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const info = lhs_ty.intInfo(zcu);

    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);

    const shift_amt: usize = @intCast(try rhs.toUnsignedIntSema(pt));
    if (shift_amt >= info.bits) {
        return sema.failWithTooLargeShiftAmount(block, lhs_ty, rhs, rhs_src, vec_idx);
    }
    var result_bigint = try intShlInner(sema, lhs_bigint, shift_amt);
    result_bigint.truncate(result_bigint.toConst(), info.signedness, info.bits);
    return pt.intValue_big(lhs_ty, result_bigint.toConst());
}
fn intShlSat(
    sema: *Sema,
    lhs_ty: Type,
    lhs: Value,
    rhs: Value,
) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const info = lhs_ty.intInfo(zcu);

    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);

    const shift_amt: usize = amt: {
        if (try rhs.getUnsignedIntSema(pt)) |shift_amt_u64| {
            if (std.math.cast(usize, shift_amt_u64)) |shift_amt| break :amt shift_amt;
        }
        // We only support ints with up to 2^16 - 1 bits, so this
        // shift will fully saturate every non-zero int (assuming
        // that `usize` is at least 16 bits wide).
        return if (lhs_bigint.eqlZero()) lhs else lhs_ty.maxIntScalar(pt, lhs_ty);
    };

    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.shiftLeftSat(lhs_bigint, shift_amt, info.signedness, info.bits);
    return pt.intValue_big(lhs_ty, result_bigint.toConst());
}
/// If the value overflowed the type and `truncate_result` is `false`, returns a `comptime_int` instead.
fn intShlWithOverflow(
    sema: *Sema,
    block: *Block,
    lhs_ty: Type,
    lhs: Value,
    rhs: Value,
    rhs_src: LazySrcLoc,
    truncate_result: bool,
    vec_idx: ?usize,
) !struct { overflow: bool, val: Value } {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const info = lhs_ty.intInfo(zcu);

    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = try lhs.toBigIntSema(&lhs_space, pt);

    const shift_amt: usize = @intCast(try rhs.toUnsignedIntSema(pt));
    if (shift_amt >= info.bits) {
        return sema.failWithTooLargeShiftAmount(block, lhs_ty, rhs, rhs_src, vec_idx);
    }
    var result_bigint = try intShlInner(sema, lhs_bigint, shift_amt);
    const overflow = !result_bigint.toConst().fitsInTwosComp(info.signedness, info.bits);
    const result = result: {
        if (overflow) {
            if (truncate_result) {
                result_bigint.truncate(result_bigint.toConst(), info.signedness, info.bits);
            } else {
                break :result try pt.intValue_big(.comptime_int, result_bigint.toConst());
            }
        }
        break :result try pt.intValue_big(lhs_ty, result_bigint.toConst());
    };
    return .{ .overflow = overflow, .val = result };
}
fn comptimeIntShl(
    sema: *Sema,
    block: *Block,
    lhs: Value,
    rhs: Value,
    rhs_src: LazySrcLoc,
    vec_idx: ?usize,
) !Value {
    const pt = sema.pt;
    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = try lhs.toBigIntSema(&lhs_space, pt);
    if (try rhs.getUnsignedIntSema(pt)) |shift_amt_u64| {
        if (std.math.cast(usize, shift_amt_u64)) |shift_amt| {
            const result_bigint = try intShlInner(sema, lhs_bigint, shift_amt);
            return pt.intValue_big(.comptime_int, result_bigint.toConst());
        }
    }
    return sema.failWithUnsupportedComptimeShiftAmount(block, rhs_src, vec_idx);
}
fn intShlInner(sema: *Sema, operand: std.math.big.int.Const, shift_amt: usize) !BigIntMutable {
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        operand.limbs.len + (shift_amt / (@sizeOf(std.math.big.Limb) * 8)) + 1,
    );
    var result: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result.shiftLeft(operand, shift_amt);
    return result;
}

fn intShr(
    sema: *Sema,
    block: *Block,
    lhs_ty: Type,
    rhs_ty: Type,
    lhs: Value,
    rhs: Value,
    src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    op: ShrOp,
    vec_idx: ?usize,
) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);

    const shift_amt: usize = if (rhs_ty.toIntern() == .comptime_int_type) amt: {
        if (try rhs.getUnsignedIntSema(pt)) |shift_amt_u64| {
            if (std.math.cast(usize, shift_amt_u64)) |shift_amt| break :amt shift_amt;
        }
        if (try rhs.compareAllWithZeroSema(.lt, pt)) {
            return sema.failWithNegativeShiftAmount(block, rhs_src, rhs, vec_idx);
        } else {
            return sema.failWithUnsupportedComptimeShiftAmount(block, rhs_src, vec_idx);
        }
    } else @intCast(try rhs.toUnsignedIntSema(pt));

    if (lhs_ty.toIntern() != .comptime_int_type and shift_amt >= lhs_ty.intInfo(zcu).bits) {
        return sema.failWithTooLargeShiftAmount(block, lhs_ty, rhs, rhs_src, vec_idx);
    }
    if (op == .shr_exact and lhs_bigint.ctz(shift_amt) < shift_amt) {
        return sema.failWithOwnedErrorMsg(block, msg: {
            const msg = try sema.errMsg(src, "exact shift shifted out 1 bits", .{});
            errdefer msg.destroy(sema.gpa);
            if (vec_idx) |i| try sema.errNote(rhs_src, msg, "when computing vector element at index '{d}'", .{i});
            break :msg msg;
        });
    }
    const result_limbs = lhs_bigint.limbs.len -| (shift_amt / (@sizeOf(std.math.big.Limb) * 8));
    if (result_limbs == 0) {
        // The shift is enough to remove all the bits from the number, which
        // means the result is 0 or -1 depending on the sign.
        if (lhs_bigint.positive) {
            return pt.intValue(lhs_ty, 0);
        } else {
            return pt.intValue(lhs_ty, -1);
        }
    }
    const limbs = try sema.arena.alloc(std.math.big.Limb, result_limbs);
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.shiftRight(lhs_bigint, shift_amt);
    return pt.intValue_big(lhs_ty, result_bigint.toConst());
}

fn intBitReverse(sema: *Sema, val: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);

    var val_space: Value.BigIntSpace = undefined;
    const val_bigint = try val.toBigIntSema(&val_space, pt);

    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitReverse(val_bigint, info.signedness, info.bits);
    return pt.intValue_big(ty, result_bigint.toConst());
}

fn intByteSwap(sema: *Sema, val: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);

    var val_space: Value.BigIntSpace = undefined;
    const val_bigint = val.toBigInt(&val_space, zcu);

    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.byteSwap(val_bigint, info.signedness, @divExact(info.bits, 8));
    return pt.intValue_big(ty, result_bigint.toConst());
}

fn floatAdd(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(target)) {
        16 => .{ .f16 = lhs.toFloat(f16, zcu) + rhs.toFloat(f16, zcu) },
        32 => .{ .f32 = lhs.toFloat(f32, zcu) + rhs.toFloat(f32, zcu) },
        64 => .{ .f64 = lhs.toFloat(f64, zcu) + rhs.toFloat(f64, zcu) },
        80 => .{ .f80 = lhs.toFloat(f80, zcu) + rhs.toFloat(f80, zcu) },
        128 => .{ .f128 = lhs.toFloat(f128, zcu) + rhs.toFloat(f128, zcu) },
        else => unreachable,
    };
    return .fromInterned(try pt.intern(.{ .float = .{
        .ty = ty.toIntern(),
        .storage = storage,
    } }));
}
fn floatSub(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(target)) {
        16 => .{ .f16 = lhs.toFloat(f16, zcu) - rhs.toFloat(f16, zcu) },
        32 => .{ .f32 = lhs.toFloat(f32, zcu) - rhs.toFloat(f32, zcu) },
        64 => .{ .f64 = lhs.toFloat(f64, zcu) - rhs.toFloat(f64, zcu) },
        80 => .{ .f80 = lhs.toFloat(f80, zcu) - rhs.toFloat(f80, zcu) },
        128 => .{ .f128 = lhs.toFloat(f128, zcu) - rhs.toFloat(f128, zcu) },
        else => unreachable,
    };
    return .fromInterned(try pt.intern(.{ .float = .{
        .ty = ty.toIntern(),
        .storage = storage,
    } }));
}
fn floatMul(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(target)) {
        16 => .{ .f16 = lhs.toFloat(f16, zcu) * rhs.toFloat(f16, zcu) },
        32 => .{ .f32 = lhs.toFloat(f32, zcu) * rhs.toFloat(f32, zcu) },
        64 => .{ .f64 = lhs.toFloat(f64, zcu) * rhs.toFloat(f64, zcu) },
        80 => .{ .f80 = lhs.toFloat(f80, zcu) * rhs.toFloat(f80, zcu) },
        128 => .{ .f128 = lhs.toFloat(f128, zcu) * rhs.toFloat(f128, zcu) },
        else => unreachable,
    };
    return .fromInterned(try pt.intern(.{ .float = .{
        .ty = ty.toIntern(),
        .storage = storage,
    } }));
}
fn floatDiv(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(target)) {
        16 => .{ .f16 = lhs.toFloat(f16, zcu) / rhs.toFloat(f16, zcu) },
        32 => .{ .f32 = lhs.toFloat(f32, zcu) / rhs.toFloat(f32, zcu) },
        64 => .{ .f64 = lhs.toFloat(f64, zcu) / rhs.toFloat(f64, zcu) },
        80 => .{ .f80 = lhs.toFloat(f80, zcu) / rhs.toFloat(f80, zcu) },
        128 => .{ .f128 = lhs.toFloat(f128, zcu) / rhs.toFloat(f128, zcu) },
        else => unreachable,
    };
    return .fromInterned(try pt.intern(.{ .float = .{
        .ty = ty.toIntern(),
        .storage = storage,
    } }));
}
fn floatDivTrunc(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(target)) {
        16 => .{ .f16 = @divTrunc(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) },
        32 => .{ .f32 = @divTrunc(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) },
        64 => .{ .f64 = @divTrunc(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) },
        80 => .{ .f80 = @divTrunc(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) },
        128 => .{ .f128 = @divTrunc(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return .fromInterned(try pt.intern(.{ .float = .{
        .ty = ty.toIntern(),
        .storage = storage,
    } }));
}
fn floatDivFloor(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(target)) {
        16 => .{ .f16 = @divFloor(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) },
        32 => .{ .f32 = @divFloor(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) },
        64 => .{ .f64 = @divFloor(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) },
        80 => .{ .f80 = @divFloor(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) },
        128 => .{ .f128 = @divFloor(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return .fromInterned(try pt.intern(.{ .float = .{
        .ty = ty.toIntern(),
        .storage = storage,
    } }));
}
fn floatDivIsExact(sema: *Sema, lhs: Value, rhs: Value, ty: Type) bool {
    const zcu = sema.pt.zcu;
    const target = zcu.getTarget();
    return switch (ty.floatBits(target)) {
        16 => @mod(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) == 0,
        32 => @mod(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) == 0,
        64 => @mod(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) == 0,
        80 => @mod(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) == 0,
        128 => @mod(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) == 0,
        else => unreachable,
    };
}
fn floatNeg(sema: *Sema, val: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(target)) {
        16 => .{ .f16 = -val.toFloat(f16, zcu) },
        32 => .{ .f32 = -val.toFloat(f32, zcu) },
        64 => .{ .f64 = -val.toFloat(f64, zcu) },
        80 => .{ .f80 = -val.toFloat(f80, zcu) },
        128 => .{ .f128 = -val.toFloat(f128, zcu) },
        else => unreachable,
    };
    return .fromInterned(try pt.intern(.{ .float = .{
        .ty = ty.toIntern(),
        .storage = storage,
    } }));
}
fn floatMod(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(target)) {
        16 => .{ .f16 = @mod(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) },
        32 => .{ .f32 = @mod(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) },
        64 => .{ .f64 = @mod(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) },
        80 => .{ .f80 = @mod(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) },
        128 => .{ .f128 = @mod(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return .fromInterned(try pt.intern(.{ .float = .{
        .ty = ty.toIntern(),
        .storage = storage,
    } }));
}
fn floatRem(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(target)) {
        16 => .{ .f16 = @rem(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) },
        32 => .{ .f32 = @rem(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) },
        64 => .{ .f64 = @rem(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) },
        80 => .{ .f80 = @rem(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) },
        128 => .{ .f128 = @rem(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return .fromInterned(try pt.intern(.{ .float = .{
        .ty = ty.toIntern(),
        .storage = storage,
    } }));
}

fn intBitwiseNot(sema: *Sema, val: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    if (val.isUndef(zcu)) return pt.undefValue(ty);
    if (ty.toIntern() == .bool_type) return .makeBool(!val.toBool());
    const info = ty.intInfo(zcu);
    if (info.bits == 0) return val;

    var val_space: Value.BigIntSpace = undefined;
    const val_bigint = val.toBigInt(&val_space, zcu);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitNotWrap(val_bigint, info.signedness, info.bits);
    return pt.intValue_big(ty, result_bigint.toConst());
}
/// Given an integer or boolean type, creates an value of that with the bit pattern 0xAA.
/// This is used to convert undef values into 0xAA when performing e.g. bitwise operations.
/// TODO: Eliminate this function and everything it stands for (related: #19634).
fn intValueAa(sema: *Sema, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    if (ty.toIntern() == .bool_type) return .true;
    if (ty.toIntern() == .u0_type or ty.toIntern() == .i0_type) return pt.intValue(ty, 0);
    const info = ty.intInfo(zcu);

    const buf = try sema.arena.alloc(u8, (info.bits + 7) / 8);
    @memset(buf, 0xAA);

    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.readTwosComplement(buf, info.bits, zcu.getTarget().cpu.arch.endian(), info.signedness);
    return pt.intValue_big(ty, result_bigint.toConst());
}
fn intBitwiseAnd(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    if (ty.toIntern() == .bool_type) return .makeBool(lhs.toBool() and rhs.toBool());

    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        // + 1 for negatives
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitAnd(lhs_bigint, rhs_bigint);
    return pt.intValue_big(ty, result_bigint.toConst());
}
fn intBitwiseNand(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    if (ty.toIntern() == .bool_type) return .makeBool(!(lhs.toBool() and rhs.toBool()));
    const info = ty.intInfo(zcu);

    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        @max(
            // + 1 for negatives
            @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
            std.math.big.int.calcTwosCompLimbCount(info.bits),
        ),
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitAnd(lhs_bigint, rhs_bigint);
    result_bigint.bitNotWrap(result_bigint.toConst(), info.signedness, info.bits);
    return pt.intValue_big(ty, result_bigint.toConst());
}
fn intBitwiseOr(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    if (ty.toIntern() == .bool_type) return .makeBool(lhs.toBool() or rhs.toBool());

    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitOr(lhs_bigint, rhs_bigint);
    return pt.intValue_big(ty, result_bigint.toConst());
}
fn intBitwiseXor(sema: *Sema, lhs: Value, rhs: Value, ty: Type) !Value {
    const pt = sema.pt;
    const zcu = pt.zcu;

    if (ty.toIntern() == .bool_type) return .makeBool(lhs.toBool() != rhs.toBool());

    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try sema.arena.alloc(
        std.math.big.Limb,
        // + 1 for negatives
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
    );
    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitXor(lhs_bigint, rhs_bigint);
    return pt.intValue_big(ty, result_bigint.toConst());
}

const Sema = @import("../Sema.zig");
const Block = Sema.Block;
const InternPool = @import("../InternPool.zig");
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
const Zcu = @import("../Zcu.zig");
const CompileError = Zcu.CompileError;
const LazySrcLoc = Zcu.LazySrcLoc;

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const BigIntMutable = std.math.big.int.Mutable;
