const assert = @import("std").debug.assert;
const mem = @import("std").mem;

test "int to ptr cast" {
    const x = usize(13);
    const y = @intToPtr(&u8, x);
    const z = usize(y);
    assert(z == 13);
}

test "numLitIntToPtrCast" {
    const vga_mem = @intToPtr(&u16, 0xB8000);
    assert(usize(vga_mem) == 0xB8000);
}

test "pointerReinterpretConstFloatToInt" {
    const float: f64 = 5.99999999999994648725e-01;
    const float_ptr = &float;
    const int_ptr = @ptrcast(&i32, float_ptr);
    const int_val = *int_ptr;
    assert(int_val == 858993411);
}

test "implicitly cast a pointer to a const pointer of it" {
    var x: i32 = 1;
    const xp = &x;
    funcWithConstPtrPtr(xp);
    assert(x == 2);
}

fn funcWithConstPtrPtr(x: &const &i32) {
    **x += 1;
}

error ItBroke;
test "explicit cast from integer to error type" {
    testCastIntToErr(error.ItBroke);
    comptime testCastIntToErr(error.ItBroke);
}
fn testCastIntToErr(err: error) {
    const x = usize(err);
    const y = error(x);
    assert(error.ItBroke == y);
}

test "peer resolve arrays of different size to const slice" {
    assert(mem.eql(u8, boolToStr(true), "true"));
    assert(mem.eql(u8, boolToStr(false), "false"));
    comptime assert(mem.eql(u8, boolToStr(true), "true"));
    comptime assert(mem.eql(u8, boolToStr(false), "false"));
}
fn boolToStr(b: bool) -> []const u8 {
    if (b) "true" else "false"
}


test "peer resolve array and const slice" {
    testPeerResolveArrayConstSlice(true);
    comptime testPeerResolveArrayConstSlice(true);
}
fn testPeerResolveArrayConstSlice(b: bool) {
    const value1 = if (b) "aoeu" else ([]const u8)("zz");
    const value2 = if (b) ([]const u8)("zz") else "aoeu";
    assert(mem.eql(u8, value1, "aoeu"));
    assert(mem.eql(u8, value2, "zz"));
}

test "integer literal to &const int" {
    const x: &const i32 = 3;
    assert(*x == 3);
}

test "string literal to &const []const u8" {
    const x: &const []const u8 = "hello";
    assert(mem.eql(u8, *x, "hello"));
}

test "implicitly cast from T to %?T" {
    castToMaybeTypeError();
    comptime castToMaybeTypeError();
}
const A = struct {
    a: i32,
};
fn castToMaybeTypeError() {
    const x = i32(1);
    const y: %?i32 = x;
    assert(??%%y == 1);

    const a = A{ .a = 1 };
    const b: %?A = a;
    assert((??%%b).a == 1);
}

test "return null from fn() -> %?&T" {
    const a = returnNullFromMaybeTypeErrorRef();
    const b = returnNullLitFromMaybeTypeErrorRef();
    assert(%%a == null and %%b == null);
}
fn returnNullFromMaybeTypeErrorRef() -> %?&A {
    const a: ?&A = null;
    return a;
}
fn returnNullLitFromMaybeTypeErrorRef() -> %?&A {
    return null;
}