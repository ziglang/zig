const assert = @import("std").debug.assert;

test "division" {
    testDivision();
    comptime testDivision();
}
fn testDivision() {
    assert(div(u32, 13, 3) == 4);
    assert(div(f32, 1.0, 2.0) == 0.5);

    assert(divExact(u32, 55, 11) == 5);
    assert(divExact(i32, -55, 11) == -5);
    assert(divExact(f32, 55.0, 11.0) == 5.0);
    assert(divExact(f32, -55.0, 11.0) == -5.0);

    assert(divFloor(i32, 5, 3) == 1);
    assert(divFloor(i32, -5, 3) == -2);
    assert(divFloor(f32, 5.0, 3.0) == 1.0);
    assert(divFloor(f32, -5.0, 3.0) == -2.0);
    assert(divFloor(i32, -0x80000000, -2) == 0x40000000);
    assert(divFloor(i32, 0, -0x80000000) == 0);
    assert(divFloor(i32, -0x40000001, 0x40000000) == -2);
    assert(divFloor(i32, -0x80000000, 1) == -0x80000000);

    assert(divTrunc(i32, 5, 3) == 1);
    assert(divTrunc(i32, -5, 3) == -1);
    assert(divTrunc(f32, 5.0, 3.0) == 1.0);
    assert(divTrunc(f32, -5.0, 3.0) == -1.0);
}
fn div(comptime T: type, a: T, b: T) -> T {
    a / b
}
fn divExact(comptime T: type, a: T, b: T) -> T {
    @divExact(a, b)
}
fn divFloor(comptime T: type, a: T, b: T) -> T {
    @divFloor(a, b)
}
fn divTrunc(comptime T: type, a: T, b: T) -> T {
    @divTrunc(a, b)
}

test "@addWithOverflow" {
    var result: u8 = undefined;
    assert(@addWithOverflow(u8, 250, 100, &result));
    assert(!@addWithOverflow(u8, 100, 150, &result));
    assert(result == 250);
}

// TODO test mulWithOverflow
// TODO test subWithOverflow

test "@shlWithOverflow" {
    var result: u16 = undefined;
    assert(@shlWithOverflow(u16, 0b0010111111111111, 3, &result));
    assert(!@shlWithOverflow(u16, 0b0010111111111111, 2, &result));
    assert(result == 0b1011111111111100);
}

test "@clz" {
    testClz();
    comptime testClz();
}

fn testClz() {
    assert(clz(u8(0b00001010)) == 4);
    assert(clz(u8(0b10001010)) == 0);
    assert(clz(u8(0b00000000)) == 8);
}

fn clz(x: var) -> usize {
    @clz(x)
}

test "@ctz" {
    testCtz();
    comptime testCtz();
}

fn testCtz() {
    assert(ctz(u8(0b10100000)) == 5);
    assert(ctz(u8(0b10001010)) == 1);
    assert(ctz(u8(0b00000000)) == 8);
}

fn ctz(x: var) -> usize {
    @ctz(x)
}

test "assignment operators" {
    var i: u32 = 0;
    i += 5;  assert(i == 5);
    i -= 2;  assert(i == 3);
    i *= 20; assert(i == 60);
    i /= 3;  assert(i == 20);
    i %= 11; assert(i == 9);
    i <<= 1; assert(i == 18);
    i >>= 2; assert(i == 4);
    i = 6;
    i &= 5;  assert(i == 4);
    i ^= 6;  assert(i == 2);
    i = 6;
    i |= 3;  assert(i == 7);
}

test "three expr in a row" {
    testThreeExprInARow(false, true);
    comptime testThreeExprInARow(false, true);
}
fn testThreeExprInARow(f: bool, t: bool) {
    assertFalse(f or f or f);
    assertFalse(t and t and f);
    assertFalse(1 | 2 | 4 != 7);
    assertFalse(3 ^ 6 ^ 8 != 13);
    assertFalse(7 & 14 & 28 != 4);
    assertFalse(9  << 1 << 2 != 9  << 3);
    assertFalse(90 >> 1 >> 2 != 90 >> 3);
    assertFalse(100 - 1 + 1000 != 1099);
    assertFalse(5 * 4 / 2 % 3 != 1);
    assertFalse(i32(i32(5)) != 5);
    assertFalse(!!false);
    assertFalse(i32(7) != --(i32(7)));
}
fn assertFalse(b: bool) {
    assert(!b);
}


test "const number literal" {
    const one = 1;
    const eleven = ten + one;

    assert(eleven == 11);
}
const ten = 10;



test "unsigned wrapping" {
    testUnsignedWrappingEval(@maxValue(u32));
    comptime testUnsignedWrappingEval(@maxValue(u32));
}
fn testUnsignedWrappingEval(x: u32) {
    const zero = x +% 1;
    assert(zero == 0);
    const orig = zero -% 1;
    assert(orig == @maxValue(u32));
}

test "signed wrapping" {
    testSignedWrappingEval(@maxValue(i32));
    comptime testSignedWrappingEval(@maxValue(i32));
}
fn testSignedWrappingEval(x: i32) {
    const min_val = x +% 1;
    assert(min_val == @minValue(i32));
    const max_val = min_val -% 1;
    assert(max_val == @maxValue(i32));
}

test "negation wrapping" {
    testNegationWrappingEval(@minValue(i16));
    comptime testNegationWrappingEval(@minValue(i16));
}
fn testNegationWrappingEval(x: i16) {
    assert(x == -32768);
    const neg = -%x;
    assert(neg == -32768);
}

test "shift left wrapping" {
    testShlWrappingEval(@maxValue(u16));
    comptime testShlWrappingEval(@maxValue(u16));
}
fn testShlWrappingEval(x: u16) {
    const shifted = x <<% 1;
    assert(shifted == 65534);
}

test "unsigned 64-bit division" {
    test_u64_div();
    comptime test_u64_div();
}
fn test_u64_div() {
    const result = divWithResult(1152921504606846976, 34359738365);
    assert(result.quotient == 33554432);
    assert(result.remainder == 100663296);
}
fn divWithResult(a: u64, b: u64) -> DivResult {
    DivResult {
        .quotient = a / b,
        .remainder = a % b,
    }
}
const DivResult = struct {
    quotient: u64,
    remainder: u64,
};

test "binary not" {
    assert(comptime {~u16(0b1010101010101010) == 0b0101010101010101});
    assert(comptime {~u64(2147483647) == 18446744071562067968});
    testBinaryNot(0b1010101010101010);
}

fn testBinaryNot(x: u16) {
    assert(~x == 0b0101010101010101);
}

test "small int addition" {
    var x: @IntType(false, 2) = 0;
    assert(x == 0);

    x += 1;
    assert(x == 1);

    x += 1;
    assert(x == 2);

    x += 1;
    assert(x == 3);

    var result: @typeOf(x) = 3;
    assert(@addWithOverflow(@typeOf(x), x, 1, &result));

    assert(result == 0);
}

test "float equality" {
    const x: f64 = 0.012;
    const y: f64 = x + 1.0;

    testFloatEqualityImpl(x, y);
    comptime testFloatEqualityImpl(x, y);
}

fn testFloatEqualityImpl(x: f64, y: f64) {
    const y2 = x + 1.0;
    assert(y == y2);
}

test "allow signed integer division/remainder when values are comptime known and positive or exact" {
    assert(5 / 3 == 1);
    assert(-5 / -3 == 1);
    assert(-6 / 3 == -2);

    assert(5 % 3 == 2);
    assert(-6 % 3 == 0);
}

test "float literal parsing" {
    comptime assert(0x1.0 == 1.0);
}
