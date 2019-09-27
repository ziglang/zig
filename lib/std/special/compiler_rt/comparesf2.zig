// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/lib/builtins/comparesf2.c

const std = @import("std");
const builtin = @import("builtin");
const is_test = builtin.is_test;

const fp_t = f32;
const rep_t = u32;
const srep_t = i32;

const typeWidth = rep_t.bit_count;
const significandBits = std.math.floatMantissaBits(fp_t);
const exponentBits = std.math.floatExponentBits(fp_t);
const signBit = (rep_t(1) << (significandBits + exponentBits));
const absMask = signBit - 1;
const implicitBit = rep_t(1) << significandBits;
const significandMask = implicitBit - 1;
const exponentMask = absMask ^ significandMask;
const infRep = @bitCast(rep_t, std.math.inf(fp_t));

// TODO https://github.com/ziglang/zig/issues/641
// and then make the return types of some of these functions the enum instead of c_int
const LE_LESS = c_int(-1);
const LE_EQUAL = c_int(0);
const LE_GREATER = c_int(1);
const LE_UNORDERED = c_int(1);

pub extern fn __lesf2(a: fp_t, b: fp_t) c_int {
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
const GE_LESS = c_int(-1);
const GE_EQUAL = c_int(0);
const GE_GREATER = c_int(1);
const GE_UNORDERED = c_int(-1); // Note: different from LE_UNORDERED

pub extern fn __gesf2(a: fp_t, b: fp_t) c_int {
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

pub extern fn __unordsf2(a: fp_t, b: fp_t) c_int {
    @setRuntimeSafety(is_test);
    const aAbs: rep_t = @bitCast(rep_t, a) & absMask;
    const bAbs: rep_t = @bitCast(rep_t, b) & absMask;
    return @boolToInt(aAbs > infRep or bAbs > infRep);
}

pub extern fn __eqsf2(a: fp_t, b: fp_t) c_int {
    return __lesf2(a, b);
}

pub extern fn __ltsf2(a: fp_t, b: fp_t) c_int {
    return __lesf2(a, b);
}

pub extern fn __nesf2(a: fp_t, b: fp_t) c_int {
    return __lesf2(a, b);
}

pub extern fn __gtsf2(a: fp_t, b: fp_t) c_int {
    return __gesf2(a, b);
}

test "import comparesf2" {
    _ = @import("comparesf2_test.zig");
}
