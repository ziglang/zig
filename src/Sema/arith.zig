//! This file encapsules all arithmetic operations on comptime-known integers, floats, and vectors.
//!
//! It is only used in cases where both operands are comptime-known; a single comptime-known operand
//! is handled directly by `Sema.zig`.
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
            const result_val = try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_elems },
            } });
            return .fromInterned(result_val);
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
                .overflow_bit = .fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = (try pt.vectorType(.{ .len = len, .child = .u1_type })).toIntern(),
                    .storage = .{ .elems = overflow_bits },
                } })),
                .wrapped_result = .fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = wrapped_results },
                } })),
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
                .overflow_bit = .fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = (try pt.vectorType(.{ .len = len, .child = .u1_type })).toIntern(),
                    .storage = .{ .elems = overflow_bits },
                } })),
                .wrapped_result = .fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = wrapped_results },
                } })),
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
                .overflow_bit = .fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = (try pt.vectorType(.{ .len = len, .child = .u1_type })).toIntern(),
                    .storage = .{ .elems = overflow_bits },
                } })),
                .wrapped_result = .fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = wrapped_results },
                } })),
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
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try addScalar(sema, block, elem_ty, lhs_elem, rhs_elem, src, lhs_src, rhs_src, elem_idx)).toIntern();
            }

            const result_val = try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elem_vals },
            } });
            return .fromInterned(result_val);
        },
        else => return addScalar(sema, block, ty, lhs_val, rhs_val, src, lhs_src, rhs_src, null),
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
    vec_idx: ?usize,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const is_int = switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => true,
        .float, .comptime_float => false,
        else => unreachable,
    };

    if (is_int) {
        if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src);
        if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src);
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

            const result_val = try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elem_vals },
            } });
            return .fromInterned(result_val);
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

            const result_val = try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elem_vals },
            } });
            return .fromInterned(result_val);
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
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try subScalar(sema, block, elem_ty, lhs_elem, rhs_elem, src, lhs_src, rhs_src, elem_idx)).toIntern();
            }

            const result_val = try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elem_vals },
            } });
            return .fromInterned(result_val);
        },
        else => return subScalar(sema, block, ty, lhs_val, rhs_val, src, lhs_src, rhs_src, null),
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
    vec_idx: ?usize,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const is_int = switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => true,
        .float, .comptime_float => false,
        else => unreachable,
    };

    if (is_int) {
        if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src);
        if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src);
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

            const result_val = try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elem_vals },
            } });
            return .fromInterned(result_val);
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

            const result_val = try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elem_vals },
            } });
            return .fromInterned(result_val);
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
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try mulScalar(sema, block, elem_ty, lhs_elem, rhs_elem, src, lhs_src, rhs_src, elem_idx)).toIntern();
            }

            const result_val = try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elem_vals },
            } });
            return .fromInterned(result_val);
        },
        else => return mulScalar(sema, block, ty, lhs_val, rhs_val, src, lhs_src, rhs_src, null),
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
    vec_idx: ?usize,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const is_int = switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => true,
        .float, .comptime_float => false,
        else => unreachable,
    };

    if (is_int) {
        if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src);
        if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src);
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

            const result_val = try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elem_vals },
            } });
            return .fromInterned(result_val);
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

            const result_val = try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elem_vals },
            } });
            return .fromInterned(result_val);
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
        .vector => {
            const elem_ty = ty.childType(zcu);
            const len = ty.vectorLen(zcu);

            const elem_vals = try sema.arena.alloc(InternPool.Index, len);
            for (elem_vals, 0..) |*result_elem, elem_idx| {
                const lhs_elem = try lhs_val.elemValue(pt, elem_idx);
                const rhs_elem = try rhs_val.elemValue(pt, elem_idx);
                result_elem.* = (try divScalar(sema, block, elem_ty, lhs_elem, rhs_elem, src, lhs_src, rhs_src, op, elem_idx)).toIntern();
            }

            const result_val = try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elem_vals },
            } });
            return .fromInterned(result_val);
        },
        else => return divScalar(sema, block, ty, lhs_val, rhs_val, src, lhs_src, rhs_src, op, null),
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
    vec_idx: ?usize,
) CompileError!Value {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const is_int = switch (ty.zigTypeTag(zcu)) {
        .int, .comptime_int => true,
        .float, .comptime_float => false,
        else => unreachable,
    };

    if (is_int) {
        if (rhs_val.eqlScalarNum(.zero_comptime_int, zcu)) return sema.failWithDivideByZero(block, rhs_src);

        if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src);
        if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src);

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
            if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src);
            if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src);
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

            const result_val = try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elem_vals },
            } });
            return .fromInterned(result_val);
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

    _ = vec_idx; // TODO: use this in the "use of undefined" error

    const allow_div_zero = !is_int and block.float_mode == .strict;
    if (allow_div_zero) {
        if (lhs_val.isUndef(zcu)) return lhs_val;
        if (rhs_val.isUndef(zcu)) return rhs_val;
    } else {
        if (lhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, lhs_src);
        if (rhs_val.isUndef(zcu)) return sema.failWithUseOfUndef(block, rhs_src);
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
