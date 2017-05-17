const assert = @import("debug.zig").assert;
const builtin = @import("builtin");

pub const Cmp = enum {
    Less,
    Equal,
    Greater,
};

pub fn min(x: var, y: var) -> @typeOf(x + y) {
    if (x < y) x else y
}

test "math.min" {
    assert(min(i32(-1), i32(2)) == -1);
}

pub fn max(x: var, y: var) -> @typeOf(x + y) {
    if (x > y) x else y
}

test "math.max" {
    assert(max(i32(-1), i32(2)) == 2);
}

error Overflow;
pub fn mul(comptime T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@mulWithOverflow(T, a, b, &answer)) error.Overflow else answer
}

error Overflow;
pub fn add(comptime T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@addWithOverflow(T, a, b, &answer)) error.Overflow else answer
}

error Overflow;
pub fn sub(comptime T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@subWithOverflow(T, a, b, &answer)) error.Overflow else answer
}

error Overflow;
pub fn shl(comptime T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@shlWithOverflow(T, a, b, &answer)) error.Overflow else answer
}

test "math overflow functions" {
    testOverflow();
    comptime testOverflow();
}

fn testOverflow() {
    assert(%%mul(i32, 3, 4) == 12);
    assert(%%add(i32, 3, 4) == 7);
    assert(%%sub(i32, 3, 4) == -1);
    assert(%%shl(i32, 0b11, 4) == 0b110000);
}


pub fn log(comptime base: usize, value: var) -> @typeOf(value) {
    const T = @typeOf(value);
    switch (@typeId(T)) {
        builtin.TypeId.Int => {
            if (base == 2) {
                return T.bit_count - 1 - @clz(value);
            } else {
                @compileError("TODO implement log for non base 2 integers");
            }
        },
        builtin.TypeId.Float => {
            @compileError("TODO implement log for floats");
        },
        else => {
            @compileError("log expects integer or float, found '" ++ @typeName(T) ++ "'");
        },
    }
}

error Overflow;
pub fn absInt(x: var) -> %@typeOf(x) {
    const T = @typeOf(x);
    comptime assert(@typeId(T) == builtin.TypeId.Int); // must pass an integer to absInt
    comptime assert(T.is_signed); // must pass a signed integer to absInt
    if (x == @minValue(@typeOf(x)))
        return error.Overflow;
    {
        @setDebugSafety(this, false);
        return if (x < 0) -x else x;
    }
}

test "math.absInt" {
    testAbsInt();
    comptime testAbsInt();
}
fn testAbsInt() {
    assert(%%absInt(i32(-10)) == 10);
    assert(%%absInt(i32(10)) == 10);
}

pub fn absFloat(x: var) -> @typeOf(x) {
    comptime assert(@typeId(@typeOf(x)) == builtin.TypeId.Float);
    return if (x < 0) -x else x;
}

test "math.absFloat" {
    testAbsFloat();
    comptime testAbsFloat();
}
fn testAbsFloat() {
    assert(absFloat(f32(-10.0)) == 10.0);
    assert(absFloat(f32(10.0)) == 10.0);
}

error DivisionByZero;
error Overflow;
pub fn divTrunc(comptime T: type, numerator: T, denominator: T) -> %T {
    @setDebugSafety(this, false);
    if (denominator == 0)
        return error.DivisionByZero;
    if (@typeId(T) == builtin.TypeId.Int and T.is_signed and numerator == @minValue(T) and denominator == -1)
        return error.Overflow;
    return @divTrunc(numerator, denominator);
}

test "math.divTrunc" {
    testDivTrunc();
    comptime testDivTrunc();
}
fn testDivTrunc() {
    assert(%%divTrunc(i32, 5, 3) == 1);
    assert(%%divTrunc(i32, -5, 3) == -1);
    if (divTrunc(i8, -5, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);
    if (divTrunc(i8, -128, -1)) |_| unreachable else |err| assert(err == error.Overflow);

    assert(%%divTrunc(f32, 5.0, 3.0) == 1.0);
    assert(%%divTrunc(f32, -5.0, 3.0) == -1.0);
}

error DivisionByZero;
error Overflow;
pub fn divFloor(comptime T: type, numerator: T, denominator: T) -> %T {
    @setDebugSafety(this, false);
    if (denominator == 0)
        return error.DivisionByZero;
    if (@typeId(T) == builtin.TypeId.Int and T.is_signed and numerator == @minValue(T) and denominator == -1)
        return error.Overflow;
    return @divFloor(numerator, denominator);
}

test "math.divFloor" {
    testDivFloor();
    comptime testDivFloor();
}
fn testDivFloor() {
    assert(%%divFloor(i32, 5, 3) == 1);
    assert(%%divFloor(i32, -5, 3) == -2);
    if (divFloor(i8, -5, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);
    if (divFloor(i8, -128, -1)) |_| unreachable else |err| assert(err == error.Overflow);

    assert(%%divFloor(f32, 5.0, 3.0) == 1.0);
    assert(%%divFloor(f32, -5.0, 3.0) == -2.0);
}

error DivisionByZero;
error Overflow;
error UnexpectedRemainder;
pub fn divExact(comptime T: type, numerator: T, denominator: T) -> %T {
    @setDebugSafety(this, false);
    if (denominator == 0)
        return error.DivisionByZero;
    if (@typeId(T) == builtin.TypeId.Int and T.is_signed and numerator == @minValue(T) and denominator == -1)
        return error.Overflow;
    const result = @divTrunc(numerator, denominator);
    if (result * denominator != numerator)
        return error.UnexpectedRemainder;
    return result;
}

test "math.divExact" {
    testDivExact();
    comptime testDivExact();
}
fn testDivExact() {
    assert(%%divExact(i32, 10, 5) == 2);
    assert(%%divExact(i32, -10, 5) == -2);
    if (divExact(i8, -5, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);
    if (divExact(i8, -128, -1)) |_| unreachable else |err| assert(err == error.Overflow);
    if (divExact(i32, 5, 2)) |_| unreachable else |err| assert(err == error.UnexpectedRemainder);

    assert(%%divExact(f32, 10.0, 5.0) == 2.0);
    assert(%%divExact(f32, -10.0, 5.0) == -2.0);
    if (divExact(f32, 5.0, 2.0)) |_| unreachable else |err| assert(err == error.UnexpectedRemainder);
}

error DivisionByZero;
error NegativeDenominator;
pub fn mod(comptime T: type, numerator: T, denominator: T) -> %T {
    @setDebugSafety(this, false);
    if (denominator == 0)
        return error.DivisionByZero;
    if (denominator < 0)
        return error.NegativeDenominator;
    return @mod(numerator, denominator);
}

test "math.mod" {
    testMod();
    comptime testMod();
}
fn testMod() {
    assert(%%mod(i32, -5, 3) == 1);
    assert(%%mod(i32, 5, 3) == 2);
    if (mod(i32, 10, -1)) |_| unreachable else |err| assert(err == error.NegativeDenominator);
    if (mod(i32, 10, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);

    assert(%%mod(f32, -5, 3) == 1);
    assert(%%mod(f32, 5, 3) == 2);
    if (mod(f32, 10, -1)) |_| unreachable else |err| assert(err == error.NegativeDenominator);
    if (mod(f32, 10, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);
}

error DivisionByZero;
error NegativeDenominator;
pub fn rem(comptime T: type, numerator: T, denominator: T) -> %T {
    @setDebugSafety(this, false);
    if (denominator == 0)
        return error.DivisionByZero;
    if (denominator < 0)
        return error.NegativeDenominator;
    return @rem(numerator, denominator);
}

test "math.rem" {
    testRem();
    comptime testRem();
}
fn testRem() {
    assert(%%rem(i32, -5, 3) == -2);
    assert(%%rem(i32, 5, 3) == 2);
    if (rem(i32, 10, -1)) |_| unreachable else |err| assert(err == error.NegativeDenominator);
    if (rem(i32, 10, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);

    assert(%%rem(f32, -5, 3) == -2);
    assert(%%rem(f32, 5, 3) == 2);
    if (rem(f32, 10, -1)) |_| unreachable else |err| assert(err == error.NegativeDenominator);
    if (rem(f32, 10, 0)) |_| unreachable else |err| assert(err == error.DivisionByZero);
}

fn isNan(comptime T: type, x: T) -> bool {
    assert(@typeId(T) == builtin.TypeId.Float);
    const bits = floatBits(x);
    if (T == f32) {
        return (bits & 0x7fffffff) > 0x7f800000;
    } else if (T == f64) {
        return (bits & (@maxValue(u64) >> 1)) > (u64(0x7ff) << 52);
    } else {
        unreachable;
    }
}

fn floatBits(comptime T: type, x: T) -> @IntType(false, T.bit_count) {
    assert(@typeId(T) == builtin.TypeId.Float);
    const uint = @IntType(false, T.bit_count);
    return *@intToPtr(&const uint, &x);
}
