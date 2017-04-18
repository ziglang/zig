const assert = @import("std").debug.assert;

test "exactDivision" {
    assert(divExact(55, 11) == 5);
}
fn divExact(a: u32, b: u32) -> u32 {
    @divExact(a, b)
}

test "floatDivision" {
    assert(fdiv32(12.0, 3.0) == 4.0);
}
fn fdiv32(a: f32, b: f32) -> f32 {
    a / b
}

test "overflowIntrinsics" {
    var result: u8 = undefined;
    assert(@addWithOverflow(u8, 250, 100, &result));
    assert(!@addWithOverflow(u8, 100, 150, &result));
    assert(result == 250);
}

test "shlWithOverflow" {
    var result: u16 = undefined;
    assert(@shlWithOverflow(u16, 0b0010111111111111, 3, &result));
    assert(!@shlWithOverflow(u16, 0b0010111111111111, 2, &result));
    assert(result == 0b1011111111111100);
}

test "countLeadingZeroes" {
    assert(@clz(u8(0b00001010)) == 4);
    assert(@clz(u8(0b10001010)) == 0);
    assert(@clz(u8(0b00000000)) == 8);
}

test "countTrailingZeroes" {
    assert(@ctz(u8(0b10100000)) == 5);
    assert(@ctz(u8(0b10001010)) == 1);
    assert(@ctz(u8(0b00000000)) == 8);
}

test "modifyOperators" {
    var i : i32 = 0;
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

test "threeExprInARow" {
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


test "constNumberLiteral" {
    const one = 1;
    const eleven = ten + one;

    assert(eleven == 11);
}
const ten = 10;



test "unsignedWrapping" {
    testUnsignedWrappingEval(@maxValue(u32));
}
fn testUnsignedWrappingEval(x: u32) {
    const zero = x +% 1;
    assert(zero == 0);
    const orig = zero -% 1;
    assert(orig == @maxValue(u32));
}

test "signedWrapping" {
    testSignedWrappingEval(@maxValue(i32));
}
fn testSignedWrappingEval(x: i32) {
    const min_val = x +% 1;
    assert(min_val == @minValue(i32));
    const max_val = min_val -% 1;
    assert(max_val == @maxValue(i32));
}

test "negationWrapping" {
    testNegationWrappingEval(@minValue(i16));
}
fn testNegationWrappingEval(x: i16) {
    assert(x == -32768);
    const neg = -%x;
    assert(neg == -32768);
}

test "shlWrapping" {
    testShlWrappingEval(@maxValue(u16));
}
fn testShlWrappingEval(x: u16) {
    const shifted = x <<% 1;
    assert(shifted == 65534);
}

test "unsigned64BitDivision" {
    const result = div(1152921504606846976, 34359738365);
    assert(result.quotient == 33554432);
    assert(result.remainder == 100663296);
}
fn div(a: u64, b: u64) -> DivResult {
    DivResult {
        .quotient = a / b,
        .remainder = a % b,
    }
}
const DivResult = struct {
    quotient: u64,
    remainder: u64,
};

test "binaryNot" {
    assert(comptime {~u16(0b1010101010101010) == 0b0101010101010101});
    assert(comptime {~u64(2147483647) == 18446744071562067968});
    testBinaryNot(0b1010101010101010);
}

fn testBinaryNot(x: u16) {
    assert(~x == 0b0101010101010101);
}

test "smallIntAddition" {
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

test "testFloatEquality" {
    const x: f64 = 0.012;
    const y: f64 = x + 1.0;

    testFloatEqualityImpl(x, y);
    comptime testFloatEqualityImpl(x, y);
}

fn testFloatEqualityImpl(x: f64, y: f64) {
    const y2 = x + 1.0;
    assert(y == y2);
}
