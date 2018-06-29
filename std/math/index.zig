const builtin = @import("builtin");
const std = @import("../index.zig");
const TypeId = builtin.TypeId;
const assert = std.debug.assert;

pub const e = 2.71828182845904523536028747135266249775724709369995;
pub const pi = 3.14159265358979323846264338327950288419716939937510;

// float.h details
pub const f64_true_min = 4.94065645841246544177e-324;
pub const f64_min = 2.22507385850720138309e-308;
pub const f64_max = 1.79769313486231570815e+308;
pub const f64_epsilon = 2.22044604925031308085e-16;
pub const f64_toint = 1.0 / f64_epsilon;

pub const f32_true_min = 1.40129846432481707092e-45;
pub const f32_min = 1.17549435082228750797e-38;
pub const f32_max = 3.40282346638528859812e+38;
pub const f32_epsilon = 1.1920928955078125e-07;
pub const f32_toint = 1.0 / f32_epsilon;

pub const f16_true_min = 0.000000059604644775390625; // 2**-24
pub const f16_min = 0.00006103515625; // 2**-14
pub const f16_max = 65504;
pub const f16_epsilon = 0.0009765625; // 2**-10
pub const f16_toint = 1.0 / f16_epsilon;

pub const nan_u16 = u16(0x7C01);
pub const nan_f16 = @bitCast(f16, nan_u16);

pub const inf_u16 = u16(0x7C00);
pub const inf_f16 = @bitCast(f16, inf_u16);

pub const nan_u32 = u32(0x7F800001);
pub const nan_f32 = @bitCast(f32, nan_u32);

pub const inf_u32 = u32(0x7F800000);
pub const inf_f32 = @bitCast(f32, inf_u32);

pub const nan_u64 = u64(0x7FF << 52) | 1;
pub const nan_f64 = @bitCast(f64, nan_u64);

pub const inf_u64 = u64(0x7FF << 52);
pub const inf_f64 = @bitCast(f64, inf_u64);

pub const nan = @import("nan.zig").nan;
pub const snan = @import("nan.zig").snan;
pub const inf = @import("inf.zig").inf;

pub fn approxEq(comptime T: type, x: T, y: T, epsilon: T) bool {
    assert(@typeId(T) == TypeId.Float);
    return fabs(x - y) < epsilon;
}

// TODO: Hide the following in an internal module.
pub fn forceEval(value: var) void {
    const T = @typeOf(value);
    switch (T) {
        f16 => {
            var x: f16 = undefined;
            const p = @ptrCast(*volatile f16, &x);
            p.* = x;
        },
        f32 => {
            var x: f32 = undefined;
            const p = @ptrCast(*volatile f32, &x);
            p.* = x;
        },
        f64 => {
            var x: f64 = undefined;
            const p = @ptrCast(*volatile f64, &x);
            p.* = x;
        },
        else => {
            @compileError("forceEval not implemented for " ++ @typeName(T));
        },
    }
}

pub fn raiseInvalid() void {
    // Raise INVALID fpu exception
}

pub fn raiseUnderflow() void {
    // Raise UNDERFLOW fpu exception
}

pub fn raiseOverflow() void {
    // Raise OVERFLOW fpu exception
}

pub fn raiseInexact() void {
    // Raise INEXACT fpu exception
}

pub fn raiseDivByZero() void {
    // Raise INEXACT fpu exception
}

pub const isNan = @import("isnan.zig").isNan;
pub const isSignalNan = @import("isnan.zig").isSignalNan;
pub const fabs = @import("fabs.zig").fabs;
pub const ceil = @import("ceil.zig").ceil;
pub const floor = @import("floor.zig").floor;
pub const trunc = @import("trunc.zig").trunc;
pub const round = @import("round.zig").round;
pub const frexp = @import("frexp.zig").frexp;
pub const frexp32_result = @import("frexp.zig").frexp32_result;
pub const frexp64_result = @import("frexp.zig").frexp64_result;
pub const modf = @import("modf.zig").modf;
pub const modf32_result = @import("modf.zig").modf32_result;
pub const modf64_result = @import("modf.zig").modf64_result;
pub const copysign = @import("copysign.zig").copysign;
pub const isFinite = @import("isfinite.zig").isFinite;
pub const isInf = @import("isinf.zig").isInf;
pub const isPositiveInf = @import("isinf.zig").isPositiveInf;
pub const isNegativeInf = @import("isinf.zig").isNegativeInf;
pub const isNormal = @import("isnormal.zig").isNormal;
pub const signbit = @import("signbit.zig").signbit;
pub const scalbn = @import("scalbn.zig").scalbn;
pub const pow = @import("pow.zig").pow;
pub const sqrt = @import("sqrt.zig").sqrt;
pub const cbrt = @import("cbrt.zig").cbrt;
pub const acos = @import("acos.zig").acos;
pub const asin = @import("asin.zig").asin;
pub const atan = @import("atan.zig").atan;
pub const atan2 = @import("atan2.zig").atan2;
pub const hypot = @import("hypot.zig").hypot;
pub const exp = @import("exp.zig").exp;
pub const exp2 = @import("exp2.zig").exp2;
pub const expm1 = @import("expm1.zig").expm1;
pub const ilogb = @import("ilogb.zig").ilogb;
pub const ln = @import("ln.zig").ln;
pub const log = @import("log.zig").log;
pub const log2 = @import("log2.zig").log2;
pub const log10 = @import("log10.zig").log10;
pub const log1p = @import("log1p.zig").log1p;
pub const fma = @import("fma.zig").fma;
pub const asinh = @import("asinh.zig").asinh;
pub const acosh = @import("acosh.zig").acosh;
pub const atanh = @import("atanh.zig").atanh;
pub const sinh = @import("sinh.zig").sinh;
pub const cosh = @import("cosh.zig").cosh;
pub const tanh = @import("tanh.zig").tanh;
pub const cos = @import("cos.zig").cos;
pub const sin = @import("sin.zig").sin;
pub const tan = @import("tan.zig").tan;

pub const complex = @import("complex/index.zig");
pub const Complex = complex.Complex;

pub const big = @import("big/index.zig");

test "math" {
    _ = @import("nan.zig");
    _ = @import("isnan.zig");
    _ = @import("fabs.zig");
    _ = @import("ceil.zig");
    _ = @import("floor.zig");
    _ = @import("trunc.zig");
    _ = @import("round.zig");
    _ = @import("frexp.zig");
    _ = @import("modf.zig");
    _ = @import("copysign.zig");
    _ = @import("isfinite.zig");
    _ = @import("isinf.zig");
    _ = @import("isnormal.zig");
    _ = @import("signbit.zig");
    _ = @import("scalbn.zig");
    _ = @import("pow.zig");
    _ = @import("sqrt.zig");
    _ = @import("cbrt.zig");
    _ = @import("acos.zig");
    _ = @import("asin.zig");
    _ = @import("atan.zig");
    _ = @import("atan2.zig");
    _ = @import("hypot.zig");
    _ = @import("exp.zig");
    _ = @import("exp2.zig");
    _ = @import("expm1.zig");
    _ = @import("ilogb.zig");
    _ = @import("ln.zig");
    _ = @import("log.zig");
    _ = @import("log2.zig");
    _ = @import("log10.zig");
    _ = @import("log1p.zig");
    _ = @import("fma.zig");
    _ = @import("asinh.zig");
    _ = @import("acosh.zig");
    _ = @import("atanh.zig");
    _ = @import("sinh.zig");
    _ = @import("cosh.zig");
    _ = @import("tanh.zig");
    _ = @import("sin.zig");
    _ = @import("cos.zig");
    _ = @import("tan.zig");

    _ = @import("complex/index.zig");

    _ = @import("big/index.zig");
}

pub fn floatMantissaBits(comptime T: type) comptime_int {
    assert(@typeId(T) == builtin.TypeId.Float);

    return switch (T.bit_count) {
        16 => 10,
        32 => 23,
        64 => 52,
        80 => 64,
        128 => 112,
        else => @compileError("unknown floating point type " ++ @typeName(T)),
    };
}

pub fn floatExponentBits(comptime T: type) comptime_int {
    assert(@typeId(T) == builtin.TypeId.Float);

    return switch (T.bit_count) {
        16 => 5,
        32 => 8,
        64 => 11,
        80 => 15,
        128 => 15,
        else => @compileError("unknown floating point type " ++ @typeName(T)),
    };
}

pub fn min(x: var, y: var) @typeOf(x + y) {
    return if (x < y) x else y;
}

test "math.min" {
    assert(min(i32(-1), i32(2)) == -1);
}

pub fn max(x: var, y: var) @typeOf(x + y) {
    return if (x > y) x else y;
}

test "math.max" {
    assert(max(i32(-1), i32(2)) == 2);
}

pub fn mul(comptime T: type, a: T, b: T) (error{Overflow}!T) {
    var answer: T = undefined;
    return if (@mulWithOverflow(T, a, b, &answer)) error.Overflow else answer;
}

pub fn add(comptime T: type, a: T, b: T) (error{Overflow}!T) {
    var answer: T = undefined;
    return if (@addWithOverflow(T, a, b, &answer)) error.Overflow else answer;
}

pub fn sub(comptime T: type, a: T, b: T) (error{Overflow}!T) {
    var answer: T = undefined;
    return if (@subWithOverflow(T, a, b, &answer)) error.Overflow else answer;
}

pub fn negate(x: var) !@typeOf(x) {
    return sub(@typeOf(x), 0, x);
}

pub fn shlExact(comptime T: type, a: T, shift_amt: Log2Int(T)) !T {
    var answer: T = undefined;
    return if (@shlWithOverflow(T, a, shift_amt, &answer)) error.Overflow else answer;
}

/// Shifts left. Overflowed bits are truncated.
/// A negative shift amount results in a right shift.
pub fn shl(comptime T: type, a: T, shift_amt: var) T {
    const abs_shift_amt = absCast(shift_amt);
    const casted_shift_amt = if (abs_shift_amt >= T.bit_count) return 0 else @intCast(Log2Int(T), abs_shift_amt);

    if (@typeOf(shift_amt).is_signed) {
        if (shift_amt >= 0) {
            return a << casted_shift_amt;
        } else {
            return a >> casted_shift_amt;
        }
    }

    return a << casted_shift_amt;
}

test "math.shl" {
    assert(shl(u8, 0b11111111, usize(3)) == 0b11111000);
    assert(shl(u8, 0b11111111, usize(8)) == 0);
    assert(shl(u8, 0b11111111, usize(9)) == 0);
    assert(shl(u8, 0b11111111, isize(-2)) == 0b00111111);
}

/// Shifts right. Overflowed bits are truncated.
/// A negative shift amount results in a lefft shift.
pub fn shr(comptime T: type, a: T, shift_amt: var) T {
    const abs_shift_amt = absCast(shift_amt);
    const casted_shift_amt = if (abs_shift_amt >= T.bit_count) return 0 else @intCast(Log2Int(T), abs_shift_amt);

    if (@typeOf(shift_amt).is_signed) {
        if (shift_amt >= 0) {
            return a >> casted_shift_amt;
        } else {
            return a << casted_shift_amt;
        }
    }

    return a >> casted_shift_amt;
}

test "math.shr" {
    assert(shr(u8, 0b11111111, usize(3)) == 0b00011111);
    assert(shr(u8, 0b11111111, usize(8)) == 0);
    assert(shr(u8, 0b11111111, usize(9)) == 0);
    assert(shr(u8, 0b11111111, isize(-2)) == 0b11111100);
}

/// Rotates right. Only unsigned values can be rotated.
/// Negative shift values results in shift modulo the bit count.
pub fn rotr(comptime T: type, x: T, r: var) T {
    if (T.is_signed) {
        @compileError("cannot rotate signed integer");
    } else {
        const ar = @mod(r, T.bit_count);
        return shr(T, x, ar) | shl(T, x, T.bit_count - ar);
    }
}

test "math.rotr" {
    assert(rotr(u8, 0b00000001, usize(0)) == 0b00000001);
    assert(rotr(u8, 0b00000001, usize(9)) == 0b10000000);
    assert(rotr(u8, 0b00000001, usize(8)) == 0b00000001);
    assert(rotr(u8, 0b00000001, usize(4)) == 0b00010000);
    assert(rotr(u8, 0b00000001, isize(-1)) == 0b00000010);
}

/// Rotates left. Only unsigned values can be rotated.
/// Negative shift values results in shift modulo the bit count.
pub fn rotl(comptime T: type, x: T, r: var) T {
    if (T.is_signed) {
        @compileError("cannot rotate signed integer");
    } else {
        const ar = @mod(r, T.bit_count);
        return shl(T, x, ar) | shr(T, x, T.bit_count - ar);
    }
}

test "math.rotl" {
    assert(rotl(u8, 0b00000001, usize(0)) == 0b00000001);
    assert(rotl(u8, 0b00000001, usize(9)) == 0b00000010);
    assert(rotl(u8, 0b00000001, usize(8)) == 0b00000001);
    assert(rotl(u8, 0b00000001, usize(4)) == 0b00010000);
    assert(rotl(u8, 0b00000001, isize(-1)) == 0b10000000);
}

pub fn Log2Int(comptime T: type) type {
    // comptime ceil log2
    comptime var count: usize = 0;
    comptime var s = T.bit_count - 1;
    inline while (s != 0) : (s >>= 1) {
        count += 1;
    }

    return @IntType(false, count);
}

test "math overflow functions" {
    testOverflow();
    comptime testOverflow();
}

fn testOverflow() void {
    assert((mul(i32, 3, 4) catch unreachable) == 12);
    assert((add(i32, 3, 4) catch unreachable) == 7);
    assert((sub(i32, 3, 4) catch unreachable) == -1);
    assert((shlExact(i32, 0b11, 4) catch unreachable) == 0b110000);
}

pub fn absInt(x: var) !@typeOf(x) {
    const T = @typeOf(x);
    comptime assert(@typeId(T) == builtin.TypeId.Int); // must pass an integer to absInt
    comptime assert(T.is_signed); // must pass a signed integer to absInt

    if (x == @minValue(@typeOf(x))) {
        return error.Overflow;
    } else {
        @setRuntimeSafety(false);
        return if (x < 0) -x else x;
    }
}

test "math.absInt" {
    testAbsInt();
    comptime testAbsInt();
}
fn testAbsInt() void {
    assert((absInt(i32(-10)) catch unreachable) == 10);
    assert((absInt(i32(10)) catch unreachable) == 10);
}

pub const absFloat = @import("fabs.zig").fabs;

pub fn divTrunc(comptime T: type, numerator: T, denominator: T) !T {
    @setRuntimeSafety(false);
    if (denominator == 0) return error.DivisionByZero;
    if (@typeId(T) == builtin.TypeId.Int and T.is_signed and numerator == @minValue(T) and denominator == -1) return error.Overflow;
    return @divTrunc(numerator, denominator);
}

test "math.divTrunc" {
    testDivTrunc();
    comptime testDivTrunc();
}
fn testDivTrunc() void {
    assert((divTrunc(i32, 5, 3) catch unreachable) == 1);
    assert((divTrunc(i32, -5, 3) catch unreachable) == -1);
    if (divTrunc(i8, -5, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);
    if (divTrunc(i8, -128, -1)) |_| unreachable else |err| assert(err == error.Overflow);

    assert((divTrunc(f32, 5.0, 3.0) catch unreachable) == 1.0);
    assert((divTrunc(f32, -5.0, 3.0) catch unreachable) == -1.0);
}

pub fn divFloor(comptime T: type, numerator: T, denominator: T) !T {
    @setRuntimeSafety(false);
    if (denominator == 0) return error.DivisionByZero;
    if (@typeId(T) == builtin.TypeId.Int and T.is_signed and numerator == @minValue(T) and denominator == -1) return error.Overflow;
    return @divFloor(numerator, denominator);
}

test "math.divFloor" {
    testDivFloor();
    comptime testDivFloor();
}
fn testDivFloor() void {
    assert((divFloor(i32, 5, 3) catch unreachable) == 1);
    assert((divFloor(i32, -5, 3) catch unreachable) == -2);
    if (divFloor(i8, -5, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);
    if (divFloor(i8, -128, -1)) |_| unreachable else |err| assert(err == error.Overflow);

    assert((divFloor(f32, 5.0, 3.0) catch unreachable) == 1.0);
    assert((divFloor(f32, -5.0, 3.0) catch unreachable) == -2.0);
}

pub fn divExact(comptime T: type, numerator: T, denominator: T) !T {
    @setRuntimeSafety(false);
    if (denominator == 0) return error.DivisionByZero;
    if (@typeId(T) == builtin.TypeId.Int and T.is_signed and numerator == @minValue(T) and denominator == -1) return error.Overflow;
    const result = @divTrunc(numerator, denominator);
    if (result * denominator != numerator) return error.UnexpectedRemainder;
    return result;
}

test "math.divExact" {
    testDivExact();
    comptime testDivExact();
}
fn testDivExact() void {
    assert((divExact(i32, 10, 5) catch unreachable) == 2);
    assert((divExact(i32, -10, 5) catch unreachable) == -2);
    if (divExact(i8, -5, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);
    if (divExact(i8, -128, -1)) |_| unreachable else |err| assert(err == error.Overflow);
    if (divExact(i32, 5, 2)) |_| unreachable else |err| assert(err == error.UnexpectedRemainder);

    assert((divExact(f32, 10.0, 5.0) catch unreachable) == 2.0);
    assert((divExact(f32, -10.0, 5.0) catch unreachable) == -2.0);
    if (divExact(f32, 5.0, 2.0)) |_| unreachable else |err| assert(err == error.UnexpectedRemainder);
}

pub fn mod(comptime T: type, numerator: T, denominator: T) !T {
    @setRuntimeSafety(false);
    if (denominator == 0) return error.DivisionByZero;
    if (denominator < 0) return error.NegativeDenominator;
    return @mod(numerator, denominator);
}

test "math.mod" {
    testMod();
    comptime testMod();
}
fn testMod() void {
    assert((mod(i32, -5, 3) catch unreachable) == 1);
    assert((mod(i32, 5, 3) catch unreachable) == 2);
    if (mod(i32, 10, -1)) |_| unreachable else |err| assert(err == error.NegativeDenominator);
    if (mod(i32, 10, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);

    assert((mod(f32, -5, 3) catch unreachable) == 1);
    assert((mod(f32, 5, 3) catch unreachable) == 2);
    if (mod(f32, 10, -1)) |_| unreachable else |err| assert(err == error.NegativeDenominator);
    if (mod(f32, 10, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);
}

pub fn rem(comptime T: type, numerator: T, denominator: T) !T {
    @setRuntimeSafety(false);
    if (denominator == 0) return error.DivisionByZero;
    if (denominator < 0) return error.NegativeDenominator;
    return @rem(numerator, denominator);
}

test "math.rem" {
    testRem();
    comptime testRem();
}
fn testRem() void {
    assert((rem(i32, -5, 3) catch unreachable) == -2);
    assert((rem(i32, 5, 3) catch unreachable) == 2);
    if (rem(i32, 10, -1)) |_| unreachable else |err| assert(err == error.NegativeDenominator);
    if (rem(i32, 10, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);

    assert((rem(f32, -5, 3) catch unreachable) == -2);
    assert((rem(f32, 5, 3) catch unreachable) == 2);
    if (rem(f32, 10, -1)) |_| unreachable else |err| assert(err == error.NegativeDenominator);
    if (rem(f32, 10, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);
}

/// Returns the absolute value of the integer parameter.
/// Result is an unsigned integer.
pub fn absCast(x: var) @IntType(false, @typeOf(x).bit_count) {
    const uint = @IntType(false, @typeOf(x).bit_count);
    if (x >= 0) return @intCast(uint, x);

    return @intCast(uint, -(x + 1)) + 1;
}

test "math.absCast" {
    assert(absCast(i32(-999)) == 999);
    assert(@typeOf(absCast(i32(-999))) == u32);

    assert(absCast(i32(999)) == 999);
    assert(@typeOf(absCast(i32(999))) == u32);

    assert(absCast(i32(@minValue(i32))) == -@minValue(i32));
    assert(@typeOf(absCast(i32(@minValue(i32)))) == u32);
}

/// Returns the negation of the integer parameter.
/// Result is a signed integer.
pub fn negateCast(x: var) !@IntType(true, @typeOf(x).bit_count) {
    if (@typeOf(x).is_signed) return negate(x);

    const int = @IntType(true, @typeOf(x).bit_count);
    if (x > -@minValue(int)) return error.Overflow;

    if (x == -@minValue(int)) return @minValue(int);

    return -@intCast(int, x);
}

test "math.negateCast" {
    assert((negateCast(u32(999)) catch unreachable) == -999);
    assert(@typeOf(negateCast(u32(999)) catch unreachable) == i32);

    assert((negateCast(u32(-@minValue(i32))) catch unreachable) == @minValue(i32));
    assert(@typeOf(negateCast(u32(-@minValue(i32))) catch unreachable) == i32);

    if (negateCast(u32(@maxValue(i32) + 10))) |_| unreachable else |err| assert(err == error.Overflow);
}

/// Cast an integer to a different integer type. If the value doesn't fit,
/// return an error.
pub fn cast(comptime T: type, x: var) (error{Overflow}!T) {
    comptime assert(@typeId(T) == builtin.TypeId.Int); // must pass an integer
    comptime assert(@typeId(@typeOf(x)) == builtin.TypeId.Int); // must pass an integer
    if (@maxValue(@typeOf(x)) > @maxValue(T) and x > @maxValue(T)) {
        return error.Overflow;
    } else if (@minValue(@typeOf(x)) < @minValue(T) and x < @minValue(T)) {
        return error.Overflow;
    } else {
        return @intCast(T, x);
    }
}

test "math.cast" {
    if (cast(u8, u32(300))) |_| @panic("fail") else |err| assert(err == error.Overflow);
    if (cast(i8, i32(-200))) |_| @panic("fail") else |err| assert(err == error.Overflow);
    if (cast(u8, i8(-1))) |_| @panic("fail") else |err| assert(err == error.Overflow);
    if (cast(u64, i8(-1))) |_| @panic("fail") else |err| assert(err == error.Overflow);

    assert((try cast(u8, u32(255))) == u8(255));
    assert(@typeOf(try cast(u8, u32(255))) == u8);
}

pub const AlignCastError = error{UnalignedMemory};

/// Align cast a pointer but return an error if it's the wrong alignment
pub fn alignCast(comptime alignment: u29, ptr: var) AlignCastError!@typeOf(@alignCast(alignment, ptr)) {
    const addr = @ptrToInt(ptr);
    if (addr % alignment != 0) {
        return error.UnalignedMemory;
    }
    return @alignCast(alignment, ptr);
}

pub fn floorPowerOfTwo(comptime T: type, value: T) T {
    var x = value;

    comptime var i = 1;
    inline while (T.bit_count > i) : (i *= 2) {
        x |= (x >> i);
    }

    return x - (x >> 1);
}

test "math.floorPowerOfTwo" {
    testFloorPowerOfTwo();
    comptime testFloorPowerOfTwo();
}

pub fn log2_int(comptime T: type, x: T) Log2Int(T) {
    assert(x != 0);
    return @intCast(Log2Int(T), T.bit_count - 1 - @clz(x));
}

pub fn log2_int_ceil(comptime T: type, x: T) Log2Int(T) {
    assert(x != 0);
    const log2_val = log2_int(T, x);
    if (T(1) << log2_val == x)
        return log2_val;
    return log2_val + 1;
}

test "std.math.log2_int_ceil" {
    assert(log2_int_ceil(u32, 1) == 0);
    assert(log2_int_ceil(u32, 2) == 1);
    assert(log2_int_ceil(u32, 3) == 2);
    assert(log2_int_ceil(u32, 4) == 2);
    assert(log2_int_ceil(u32, 5) == 3);
    assert(log2_int_ceil(u32, 6) == 3);
    assert(log2_int_ceil(u32, 7) == 3);
    assert(log2_int_ceil(u32, 8) == 3);
    assert(log2_int_ceil(u32, 9) == 4);
    assert(log2_int_ceil(u32, 10) == 4);
}

fn testFloorPowerOfTwo() void {
    assert(floorPowerOfTwo(u32, 63) == 32);
    assert(floorPowerOfTwo(u32, 64) == 64);
    assert(floorPowerOfTwo(u32, 65) == 64);
    assert(floorPowerOfTwo(u4, 7) == 4);
    assert(floorPowerOfTwo(u4, 8) == 8);
    assert(floorPowerOfTwo(u4, 9) == 8);
}

pub fn lossyCast(comptime T: type, value: var) T {
    switch (@typeInfo(@typeOf(value))) {
        builtin.TypeId.Int => return @intToFloat(T, value),
        builtin.TypeId.Float => return @floatCast(T, value),
        builtin.TypeId.ComptimeInt => return T(value),
        builtin.TypeId.ComptimeFloat => return T(value),
        else => @compileError("bad type"),
    }
}
