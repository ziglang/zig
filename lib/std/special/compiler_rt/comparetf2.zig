// TODO https://github.com/ziglang/zig/issues/641
// and then make the return types of some of these functions the enum instead of c_int
const LE_LESS = @as(c_int, -1);
const LE_EQUAL = @as(c_int, 0);
const LE_GREATER = @as(c_int, 1);
const LE_UNORDERED = @as(c_int, 1);

const rep_t = u128;
const srep_t = i128;

const typeWidth = rep_t.bit_count;
const significandBits = 112;
const exponentBits = (typeWidth - significandBits - 1);
const signBit = (@as(rep_t, 1) << (significandBits + exponentBits));
const absMask = signBit - 1;
const implicitBit = @as(rep_t, 1) << significandBits;
const significandMask = implicitBit - 1;
const exponentMask = absMask ^ significandMask;
const infRep = exponentMask;

const builtin = @import("builtin");
const is_test = builtin.is_test;

pub fn __letf2(a: f128, b: f128) callconv(.C) c_int {
    @setRuntimeSafety(is_test);

    const aInt = @bitCast(rep_t, a);
    const bInt = @bitCast(rep_t, b);

    const aAbs: rep_t = aInt & absMask;
    const bAbs: rep_t = bInt & absMask;

    // If either a or b is NaN, they are unordered.
    if (aAbs > infRep or bAbs > infRep) return LE_UNORDERED;

    // If a and b are both zeros, they are equal.
    if ((aAbs | bAbs) == 0) return LE_EQUAL;

    // If at least one of a and b is positive, we get the same result comparing
    // a and b as signed integers as we would with a floating-point compare.
    return if ((aInt & bInt) >= 0)
        if (aInt < bInt)
            LE_LESS
        else if (aInt == bInt)
            LE_EQUAL
        else
            LE_GREATER
    else
    // Otherwise, both are negative, so we need to flip the sense of the
    // comparison to get the correct result.  (This assumes a twos- or ones-
    // complement integer representation; if integers are represented in a
    // sign-magnitude representation, then this flip is incorrect).
    if (aInt > bInt)
        LE_LESS
    else if (aInt == bInt)
        LE_EQUAL
    else
        LE_GREATER;
}

// TODO https://github.com/ziglang/zig/issues/641
// and then make the return types of some of these functions the enum instead of c_int
const GE_LESS = @as(c_int, -1);
const GE_EQUAL = @as(c_int, 0);
const GE_GREATER = @as(c_int, 1);
const GE_UNORDERED = @as(c_int, -1); // Note: different from LE_UNORDERED

pub fn __getf2(a: f128, b: f128) callconv(.C) c_int {
    @setRuntimeSafety(is_test);

    const aInt = @bitCast(srep_t, a);
    const bInt = @bitCast(srep_t, b);
    const aAbs = @bitCast(rep_t, aInt) & absMask;
    const bAbs = @bitCast(rep_t, bInt) & absMask;

    if (aAbs > infRep or bAbs > infRep) return GE_UNORDERED;
    if ((aAbs | bAbs) == 0) return GE_EQUAL;
    return if ((aInt & bInt) >= 0)
        if (aInt < bInt)
            GE_LESS
        else if (aInt == bInt)
            GE_EQUAL
        else
            GE_GREATER
    else if (aInt > bInt)
        GE_LESS
    else if (aInt == bInt)
        GE_EQUAL
    else
        GE_GREATER;
}

pub fn __unordtf2(a: f128, b: f128) callconv(.C) c_int {
    @setRuntimeSafety(is_test);

    const aAbs = @bitCast(rep_t, a) & absMask;
    const bAbs = @bitCast(rep_t, b) & absMask;
    return @boolToInt(aAbs > infRep or bAbs > infRep);
}
