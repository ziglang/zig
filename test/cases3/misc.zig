// normal comment
/// this is a documentation comment
/// doc comment line 2
fn emptyFunctionWithComments() {
    @setFnTest(this);
}

export fn disabledExternFn() {
    @setFnVisible(this, false);
}

fn callDisabledExternFn() {
    @setFnTest(this);

    disabledExternFn();
}

fn intTypeBuiltin() {
    @setFnTest(this);

    assert(@intType(true, 8) == i8);
    assert(@intType(true, 16) == i16);
    assert(@intType(true, 32) == i32);
    assert(@intType(true, 64) == i64);

    assert(@intType(false, 8) == u8);
    assert(@intType(false, 16) == u16);
    assert(@intType(false, 32) == u32);
    assert(@intType(false, 64) == u64);

    assert(i8.bit_count == 8);
    assert(i16.bit_count == 16);
    assert(i32.bit_count == 32);
    assert(i64.bit_count == 64);

    assert(i8.is_signed);
    assert(i16.is_signed);
    assert(i32.is_signed);
    assert(i64.is_signed);
    assert(isize.is_signed);

    assert(!u8.is_signed);
    assert(!u16.is_signed);
    assert(!u32.is_signed);
    assert(!u64.is_signed);
    assert(!usize.is_signed);
}

fn minValueAndMaxValue() {
    @setFnTest(this);

    assert(@maxValue(u8) == 255);
    assert(@maxValue(u16) == 65535);
    assert(@maxValue(u32) == 4294967295);
    assert(@maxValue(u64) == 18446744073709551615);

    assert(@maxValue(i8) == 127);
    assert(@maxValue(i16) == 32767);
    assert(@maxValue(i32) == 2147483647);
    assert(@maxValue(i64) == 9223372036854775807);

    assert(@minValue(u8) == 0);
    assert(@minValue(u16) == 0);
    assert(@minValue(u32) == 0);
    assert(@minValue(u64) == 0);

    assert(@minValue(i8) == -128);
    assert(@minValue(i16) == -32768);
    assert(@minValue(i32) == -2147483648);
    assert(@minValue(i64) == -9223372036854775808);
}

fn maxValueType() {
    @setFnTest(this);

    // If the type of @maxValue(i32) was i32 then this implicit cast to
    // u32 would not work. But since the value is a number literal,
    // it works fine.
    const x: u32 = @maxValue(i32);
    assert(x == 2147483647);
}

fn shortCircuit() {
    @setFnTest(this);

    var hit_1 = false;
    var hit_2 = false;
    var hit_3 = false;
    var hit_4 = false;

    if (true || {assert(false); false}) {
        hit_1 = true;
    }
    if (false || { hit_2 = true; false }) {
        assert(false);
    }

    if (true && { hit_3 = true; false }) {
        assert(false);
    }
    if (false && {assert(false); false}) {
        assert(false);
    } else {
        hit_4 = true;
    }
    assert(hit_1);
    assert(hit_2);
    assert(hit_3);
    assert(hit_4);
}

fn truncate() {
    @setFnTest(this);

    assert(testTruncate(0x10fd) == 0xfd);
}
fn testTruncate(x: u32) -> u8 {
    @truncate(u8, x)
}

fn assignToIfVarPtr() {
    @setFnTest(this);

    var maybe_bool: ?bool = true;

    if (const *b ?= maybe_bool) {
        *b = false;
    }

    assert(??maybe_bool == false);
}

fn first4KeysOfHomeRow() -> []const u8 {
    "aoeu"
}

fn ReturnStringFromFunction() {
    @setFnTest(this);

    assert(memeql(first4KeysOfHomeRow(), "aoeu"));
}

const g1 : i32 = 1233 + 1;
var g2 : i32 = 0;

fn globalVariables() {
    @setFnTest(this);

    assert(g2 == 0);
    g2 = g1;
    assert(g2 == 1234);
}




// TODO import from std.str
pub fn memeql(a: []const u8, b: []const u8) -> bool {
    sliceEql(u8, a, b)
}

// TODO import from std.str
pub fn sliceEql(inline T: type, a: []const T, b: []const T) -> bool {
    if (a.len != b.len) return false;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}


// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
