const assert = @import("std").debug.assert;
const mem = @import("std").mem;

test "int to ptr cast" {
    const x = usize(13);
    const y = @intToPtr(&u8, x);
    const z = @ptrToInt(y);
    assert(z == 13);
}

test "integer literal to pointer cast" {
    const vga_mem = @intToPtr(&u16, 0xB8000);
    assert(@ptrToInt(vga_mem) == 0xB8000);
}

test "pointer reinterpret const float to int" {
    const float: f64 = 5.99999999999994648725e-01;
    const float_ptr = &float;
    const int_ptr = @ptrCast(&i32, float_ptr);
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
    return if (b) "true" else "false";
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
    castToMaybeTypeError(1);
    comptime castToMaybeTypeError(1);
}
const A = struct {
    a: i32,
};
fn castToMaybeTypeError(z: i32) {
    const x = i32(1);
    const y: %?i32 = x;
    assert(??%%y == 1);

    const f = z;
    const g: %?i32 = f;

    const a = A{ .a = z };
    const b: %?A = a;
    assert((??%%b).a == 1);
}

test "implicitly cast from int to %?T" {
    implicitIntLitToMaybe();
    comptime implicitIntLitToMaybe();
}
fn implicitIntLitToMaybe() {
    const f: ?i32 = 1;
    const g: %?i32 = 1;
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

test "peer type resolution: ?T and T" {
    assert(??peerTypeTAndMaybeT(true, false) == 0);
    assert(??peerTypeTAndMaybeT(false, false) == 3);
    comptime {
        assert(??peerTypeTAndMaybeT(true, false) == 0);
        assert(??peerTypeTAndMaybeT(false, false) == 3);
    }
}
fn peerTypeTAndMaybeT(c: bool, b: bool) -> ?usize {
    if (c) {
        return if (b) null else usize(0);
    }

    return usize(3);
}


test "peer type resolution: [0]u8 and []const u8" {
    assert(peerTypeEmptyArrayAndSlice(true, "hi").len == 0);
    assert(peerTypeEmptyArrayAndSlice(false, "hi").len == 1);
    comptime {
        assert(peerTypeEmptyArrayAndSlice(true, "hi").len == 0);
        assert(peerTypeEmptyArrayAndSlice(false, "hi").len == 1);
    }
}
fn peerTypeEmptyArrayAndSlice(a: bool, slice: []const u8) -> []const u8 {
    if (a) {
        return []const u8 {};
    }

    return slice[0..1];
}

test "implicitly cast from [N]T to ?[]const T" {
    assert(mem.eql(u8, ??castToMaybeSlice(), "hi"));
    comptime assert(mem.eql(u8, ??castToMaybeSlice(), "hi"));
}

fn castToMaybeSlice() -> ?[]const u8 {
    return "hi";
}


test "implicitly cast from [0]T to %[]T" {
    testCastZeroArrayToErrSliceMut();
    comptime testCastZeroArrayToErrSliceMut();
}

fn testCastZeroArrayToErrSliceMut() {
    assert((%%gimmeErrOrSlice()).len == 0);
}

fn gimmeErrOrSlice() -> %[]u8 {
    return []u8{};
}

test "peer type resolution: [0]u8, []const u8, and %[]u8" {
    {
        var data = "hi";
        const slice = data[0..];
        assert((%%peerTypeEmptyArrayAndSliceAndError(true, slice)).len == 0);
        assert((%%peerTypeEmptyArrayAndSliceAndError(false, slice)).len == 1);
    }
    comptime {
        var data = "hi";
        const slice = data[0..];
        assert((%%peerTypeEmptyArrayAndSliceAndError(true, slice)).len == 0);
        assert((%%peerTypeEmptyArrayAndSliceAndError(false, slice)).len == 1);
    }
}
fn peerTypeEmptyArrayAndSliceAndError(a: bool, slice: []u8) -> %[]u8 {
    if (a) {
        return []u8{};
    }

    return slice[0..1];
}

test "resolve undefined with integer" {
    testResolveUndefWithInt(true, 1234);
    comptime testResolveUndefWithInt(true, 1234);
}
fn testResolveUndefWithInt(b: bool, x: i32) {
    const value = if (b) x else undefined;
    if (b) {
        assert(value == x);
    }
}

test "implicit cast from &const [N]T to []const T" {
    testCastConstArrayRefToConstSlice();
    comptime testCastConstArrayRefToConstSlice();
}

fn testCastConstArrayRefToConstSlice() {
    const blah = "aoeu";
    const const_array_ref = &blah;
    assert(@typeOf(const_array_ref) == &const [4]u8);
    const slice: []const u8 = const_array_ref;
    assert(mem.eql(u8, slice, "aoeu"));
}

test "var args implicitly casts by value arg to const ref" {
    foo("hello");
}

fn foo(args: ...) {
    assert(@typeOf(args[0]) == &const [5]u8);
}


test "peer type resolution: error and [N]T" {
    assert(mem.eql(u8, %%testPeerErrorAndArray(0), "OK"));
    comptime assert(mem.eql(u8, %%testPeerErrorAndArray(0), "OK"));

    assert(mem.eql(u8, %%testPeerErrorAndArray2(1), "OKK"));
    comptime assert(mem.eql(u8, %%testPeerErrorAndArray2(1), "OKK"));
}

error BadValue;
fn testPeerErrorAndArray(x: u8) -> %[]const u8 {
    return switch (x) {
        0x00 => "OK",
        else => error.BadValue,
    };
}
fn testPeerErrorAndArray2(x: u8) -> %[]const u8 {
    return switch (x) {
        0x00 => "OK",
        0x01 => "OKK",
        else => error.BadValue,
    };
}

test "explicit cast float number literal to integer if no fraction component" {
    const x = i32(1e4);
    assert(x == 10000);
    const y = i32(f32(1e4));
    assert(y == 10000);
}

test "cast u128 to f128 and back" {
    comptime testCast128();
    testCast128();
}

fn testCast128() {
    assert(cast128Int(cast128Float(0x7fff0000000000000000000000000000)) == 0x7fff0000000000000000000000000000);
}

fn cast128Int(x: f128) -> u128 {
    return @bitCast(u128, x);
}

fn cast128Float(x: u128) -> f128 {
    return @bitCast(f128, x);
}

test "const slice widen cast" {
    const bytes align(4) = []u8{0x12, 0x12, 0x12, 0x12};

    const u32_value = ([]const u32)(bytes[0..])[0];
    assert(u32_value == 0x12121212);

    assert(@bitCast(u32, bytes) == 0x12121212);
}
