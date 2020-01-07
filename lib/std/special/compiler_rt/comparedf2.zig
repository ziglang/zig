// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/lib/builtins/comparedf2.c

const std = @import("std");
const builtin = @import("builtin");
const is_test = builtin.is_test;

const fp_t = f64;
const rep_t = u64;
const srep_t = i64;

const typeWidth = rep_t.bit_count;
const significandBits = std.math.floatMantissaBits(fp_t);
const exponentBits = std.math.floatExponentBits(fp_t);
const signBit = (@as(rep_t, 1) << (significandBits + exponentBits));
const absMask = signBit - 1;
const implicitBit = @as(rep_t, 1) << significandBits;
const significandMask = implicitBit - 1;
const exponentMask = absMask ^ significandMask;
const infRep = @bitCast(rep_t, std.math.inf(fp_t));

// TODO https://github.com/ziglang/zig/issues/641
// and then make the return types of some of these functions the enum instead of c_int
const LE_LESS = @as(c_int, -1);
const LE_EQUAL = @as(c_int, 0);
const LE_GREATER = @as(c_int, 1);
const LE_UNORDERED = @as(c_int, 1);

pub fn __ledf2(a: fp_t, b: fp_t) callconv(.C) c_int {
    @setRuntimeSafety(is_test);
    const aInt: srep_t = @bitCast(srep_t, a);
    const bInt: srep_t = @bitCast(srep_t, b);
    const aAbs: rep_t = @bitCast(rep_t, aInt) & absMask;
    const bAbs: rep_t = @bitCast(rep_t, bInt) & absMask;

    // If either a or b is NaN, they are unordered.
    if (aAbs > infRep or bAbs > infRep) return LE_UNORDERED;

    // If a and b are both zeros, they are equal.
    if ((aAbs | bAbs) == 0) return LE_EQUAL;

    // If at least one of a and b is positive, we get the same result comparing
    // a and b as signed integers as we would with a fp_ting-point compare.
    if ((aInt & bInt) >= 0) {
        if (aInt < bInt) {
            return LE_LESS;
        } else if (aInt == bInt) {
            return LE_EQUAL;
        } else return LE_GREATER;
    }

    // Otherwise, both are negative, so we need to flip the sense of the
    // comparison to get the correct result.  (This assumes a twos- or ones-
    // complement integer representation; if integers are represented in a
    // sign-magnitude representation, then this flip is incorrect).
    else {
        if (aInt > bInt) {
            return LE_LESS;
        } else if (aInt == bInt) {
            return LE_EQUAL;
        } else return LE_GREATER;
    }
}

// TODO https://github.com/ziglang/zig/issues/641
// and then make the return types of some of these functions the enum instead of c_int
const GE_LESS = @as(c_int, -1);
const GE_EQUAL = @as(c_int, 0);
const GE_GREATER = @as(c_int, 1);
const GE_UNORDERED = @as(c_int, -1); // Note: different from LE_UNORDERED

pub fn __gedf2(a: fp_t, b: fp_t) callconv(.C) c_int {
    @setRuntimeSafety(is_test);
    const aInt: srep_t = @bitCast(srep_t, a);
    const bInt: srep_t = @bitCast(srep_t, b);
    const aAbs: rep_t = @bitCast(rep_t, aInt) & absMask;
    const bAbs: rep_t = @bitCast(rep_t, bInt) & absMask;

    if (aAbs > infRep or bAbs > infRep) return GE_UNORDERED;
    if ((aAbs | bAbs) == 0) return GE_EQUAL;
    if ((aInt & bInt) >= 0) {
        if (aInt < bInt) {
            return GE_LESS;
        } else if (aInt == bInt) {
            return GE_EQUAL;
        } else return GE_GREATER;
    } else {
        if (aInt > bInt) {
            return GE_LESS;
        } else if (aInt == bInt) {
            return GE_EQUAL;
        } else return GE_GREATER;
    }
}

pub fn __unorddf2(a: fp_t, b: fp_t) callconv(.C) c_int {
    @setRuntimeSafety(is_test);
    const aAbs: rep_t = @bitCast(rep_t, a) & absMask;
    const bAbs: rep_t = @bitCast(rep_t, b) & absMask;
    return @boolToInt(aAbs > infRep or bAbs > infRep);
}

pub fn __eqdf2(a: fp_t, b: fp_t) callconv(.C) c_int {
    return __ledf2(a, b);
}

pub fn __ltdf2(a: fp_t, b: fp_t) callconv(.C) c_int {
    return __ledf2(a, b);
}

pub fn __nedf2(a: fp_t, b: fp_t) callconv(.C) c_int {
    return __ledf2(a, b);
}

pub fn __gtdf2(a: fp_t, b: fp_t) callconv(.C) c_int {
    return __gedf2(a, b);
}

pub fn __aeabi_dcmpun(a: fp_t, b: fp_t) callconv(.AAPCS) c_int {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __unorddf2, .{ a, b });
}

test "import comparedf2" {
    _ = @import("comparedf2_test.zig");
}
