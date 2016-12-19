fn exactDivision() {
    @setFnTest(this);

    assert(divExact(55, 11) == 5);
}
fn divExact(a: u32, b: u32) -> u32 {
    @divExact(a, b)
}

fn floatDivision() {
    @setFnTest(this);

    assert(fdiv32(12.0, 3.0) == 4.0);
}
fn fdiv32(a: f32, b: f32) -> f32 {
    a / b
}

fn overflowIntrinsics() {
    @setFnTest(this);

    var result: u8 = undefined;
    assert(@addWithOverflow(u8, 250, 100, &result));
    assert(!@addWithOverflow(u8, 100, 150, &result));
    assert(result == 250);
}

fn shlWithOverflow() {
    @setFnTest(this);

    var result: u16 = undefined;
    assert(@shlWithOverflow(u16, 0b0010111111111111, 3, &result));
    assert(!@shlWithOverflow(u16, 0b0010111111111111, 2, &result));
    assert(result == 0b1011111111111100);
}

fn countLeadingZeroes() {
    @setFnTest(this);

    assert(@clz(u8(0b00001010)) == 4);
    assert(@clz(u8(0b10001010)) == 0);
    assert(@clz(u8(0b00000000)) == 8);
}

fn countTrailingZeroes() {
    @setFnTest(this);

    assert(@ctz(u8(0b10100000)) == 5);
    assert(@ctz(u8(0b10001010)) == 1);
    assert(@ctz(u8(0b00000000)) == 8);
}

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}

