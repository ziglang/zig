const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const mem = std.mem;
const maxInt = std.math.maxInt;

test "peer resolve array and const slice" {
    testPeerResolveArrayConstSlice(true);
    comptime testPeerResolveArrayConstSlice(true);
}
fn testPeerResolveArrayConstSlice(b: bool) void {
    const value1 = if (b) "aoeu" else ([]const u8)("zz");
    const value2 = if (b) ([]const u8)("zz") else "aoeu";
    assertOrPanic(mem.eql(u8, value1, "aoeu"));
    assertOrPanic(mem.eql(u8, value2, "zz"));
}

test "implicitly cast from T to anyerror!?T" {
    castToOptionalTypeError(1);
    comptime castToOptionalTypeError(1);
}
const A = struct {
    a: i32,
};
fn castToOptionalTypeError(z: i32) void {
    const x = i32(1);
    const y: anyerror!?i32 = x;
    assertOrPanic((try y).? == 1);

    const f = z;
    const g: anyerror!?i32 = f;

    const a = A{ .a = z };
    const b: anyerror!?A = a;
    assertOrPanic((b catch unreachable).?.a == 1);
}

test "implicitly cast from int to anyerror!?T" {
    implicitIntLitToOptional();
    comptime implicitIntLitToOptional();
}
fn implicitIntLitToOptional() void {
    const f: ?i32 = 1;
    const g: anyerror!?i32 = 1;
}

test "return null from fn() anyerror!?&T" {
    const a = returnNullFromOptionalTypeErrorRef();
    const b = returnNullLitFromOptionalTypeErrorRef();
    assertOrPanic((try a) == null and (try b) == null);
}
fn returnNullFromOptionalTypeErrorRef() anyerror!?*A {
    const a: ?*A = null;
    return a;
}
fn returnNullLitFromOptionalTypeErrorRef() anyerror!?*A {
    return null;
}

test "peer type resolution: ?T and T" {
    assertOrPanic(peerTypeTAndOptionalT(true, false).? == 0);
    assertOrPanic(peerTypeTAndOptionalT(false, false).? == 3);
    comptime {
        assertOrPanic(peerTypeTAndOptionalT(true, false).? == 0);
        assertOrPanic(peerTypeTAndOptionalT(false, false).? == 3);
    }
}
fn peerTypeTAndOptionalT(c: bool, b: bool) ?usize {
    if (c) {
        return if (b) null else usize(0);
    }

    return usize(3);
}

test "peer type resolution: [0]u8 and []const u8" {
    assertOrPanic(peerTypeEmptyArrayAndSlice(true, "hi").len == 0);
    assertOrPanic(peerTypeEmptyArrayAndSlice(false, "hi").len == 1);
    comptime {
        assertOrPanic(peerTypeEmptyArrayAndSlice(true, "hi").len == 0);
        assertOrPanic(peerTypeEmptyArrayAndSlice(false, "hi").len == 1);
    }
}
fn peerTypeEmptyArrayAndSlice(a: bool, slice: []const u8) []const u8 {
    if (a) {
        return []const u8{};
    }

    return slice[0..1];
}

test "implicitly cast from [N]T to ?[]const T" {
    assertOrPanic(mem.eql(u8, castToOptionalSlice().?, "hi"));
    comptime assertOrPanic(mem.eql(u8, castToOptionalSlice().?, "hi"));
}

fn castToOptionalSlice() ?[]const u8 {
    return "hi";
}

test "implicitly cast from [0]T to anyerror![]T" {
    testCastZeroArrayToErrSliceMut();
    comptime testCastZeroArrayToErrSliceMut();
}

fn testCastZeroArrayToErrSliceMut() void {
    assertOrPanic((gimmeErrOrSlice() catch unreachable).len == 0);
}

fn gimmeErrOrSlice() anyerror![]u8 {
    return []u8{};
}

test "peer type resolution: [0]u8, []const u8, and anyerror![]u8" {
    {
        var data = "hi";
        const slice = data[0..];
        assertOrPanic((try peerTypeEmptyArrayAndSliceAndError(true, slice)).len == 0);
        assertOrPanic((try peerTypeEmptyArrayAndSliceAndError(false, slice)).len == 1);
    }
    comptime {
        var data = "hi";
        const slice = data[0..];
        assertOrPanic((try peerTypeEmptyArrayAndSliceAndError(true, slice)).len == 0);
        assertOrPanic((try peerTypeEmptyArrayAndSliceAndError(false, slice)).len == 1);
    }
}
fn peerTypeEmptyArrayAndSliceAndError(a: bool, slice: []u8) anyerror![]u8 {
    if (a) {
        return []u8{};
    }

    return slice[0..1];
}

test "resolve undefined with integer" {
    testResolveUndefWithInt(true, 1234);
    comptime testResolveUndefWithInt(true, 1234);
}
fn testResolveUndefWithInt(b: bool, x: i32) void {
    const value = if (b) x else undefined;
    if (b) {
        assertOrPanic(value == x);
    }
}

test "implicit cast from &const [N]T to []const T" {
    testCastConstArrayRefToConstSlice();
    comptime testCastConstArrayRefToConstSlice();
}

fn testCastConstArrayRefToConstSlice() void {
    const blah = "aoeu";
    const const_array_ref = &blah;
    assertOrPanic(@typeOf(const_array_ref) == *const [4]u8);
    const slice: []const u8 = const_array_ref;
    assertOrPanic(mem.eql(u8, slice, "aoeu"));
}

test "peer type resolution: error and [N]T" {
    // TODO: implicit error!T to error!U where T can implicitly cast to U
    //assertOrPanic(mem.eql(u8, try testPeerErrorAndArray(0), "OK"));
    //comptime assertOrPanic(mem.eql(u8, try testPeerErrorAndArray(0), "OK"));
    assertOrPanic(mem.eql(u8, try testPeerErrorAndArray2(1), "OKK"));
    comptime assertOrPanic(mem.eql(u8, try testPeerErrorAndArray2(1), "OKK"));
}

//fn testPeerErrorAndArray(x: u8) error![]const u8 {
//    return switch (x) {
//        0x00 => "OK",
//        else => error.BadValue,
//    };
//}
fn testPeerErrorAndArray2(x: u8) anyerror![]const u8 {
    return switch (x) {
        0x00 => "OK",
        0x01 => "OKK",
        else => error.BadValue,
    };
}

test "@floatToInt" {
    testFloatToInts();
    comptime testFloatToInts();
}

fn testFloatToInts() void {
    const x = i32(1e4);
    assertOrPanic(x == 10000);
    const y = @floatToInt(i32, f32(1e4));
    assertOrPanic(y == 10000);
    expectFloatToInt(f16, 255.1, u8, 255);
    expectFloatToInt(f16, 127.2, i8, 127);
    expectFloatToInt(f16, -128.2, i8, -128);
    expectFloatToInt(f32, 255.1, u8, 255);
    expectFloatToInt(f32, 127.2, i8, 127);
    expectFloatToInt(f32, -128.2, i8, -128);
    expectFloatToInt(comptime_int, 1234, i16, 1234);
}

fn expectFloatToInt(comptime F: type, f: F, comptime I: type, i: I) void {
    assertOrPanic(@floatToInt(I, f) == i);
}

test "cast u128 to f128 and back" {
    comptime testCast128();
    testCast128();
}

fn testCast128() void {
    assertOrPanic(cast128Int(cast128Float(0x7fff0000000000000000000000000000)) == 0x7fff0000000000000000000000000000);
}

fn cast128Int(x: f128) u128 {
    return @bitCast(u128, x);
}

fn cast128Float(x: u128) f128 {
    return @bitCast(f128, x);
}

test "const slice widen cast" {
    const bytes align(4) = []u8{
        0x12,
        0x12,
        0x12,
        0x12,
    };

    const u32_value = @bytesToSlice(u32, bytes[0..])[0];
    assertOrPanic(u32_value == 0x12121212);

    assertOrPanic(@bitCast(u32, bytes) == 0x12121212);
}

test "single-item pointer of array to slice and to unknown length pointer" {
    testCastPtrOfArrayToSliceAndPtr();
    comptime testCastPtrOfArrayToSliceAndPtr();
}

fn testCastPtrOfArrayToSliceAndPtr() void {
    var array = "aoeu";
    const x: [*]u8 = &array;
    x[0] += 1;
    assertOrPanic(mem.eql(u8, array[0..], "boeu"));
    const y: []u8 = &array;
    y[0] += 1;
    assertOrPanic(mem.eql(u8, array[0..], "coeu"));
}

test "cast *[1][*]const u8 to [*]const ?[*]const u8" {
    const window_name = [1][*]const u8{c"window name"};
    const x: [*]const ?[*]const u8 = &window_name;
    assertOrPanic(mem.eql(u8, std.cstr.toSliceConst(x[0].?), "window name"));
}

test "@intCast comptime_int" {
    const result = @intCast(i32, 1234);
    assertOrPanic(@typeOf(result) == i32);
    assertOrPanic(result == 1234);
}

test "@floatCast comptime_int and comptime_float" {
    {
        const result = @floatCast(f16, 1234);
        assertOrPanic(@typeOf(result) == f16);
        assertOrPanic(result == 1234.0);
    }
    {
        const result = @floatCast(f16, 1234.0);
        assertOrPanic(@typeOf(result) == f16);
        assertOrPanic(result == 1234.0);
    }
    {
        const result = @floatCast(f32, 1234);
        assertOrPanic(@typeOf(result) == f32);
        assertOrPanic(result == 1234.0);
    }
    {
        const result = @floatCast(f32, 1234.0);
        assertOrPanic(@typeOf(result) == f32);
        assertOrPanic(result == 1234.0);
    }
}

test "comptime_int @intToFloat" {
    {
        const result = @intToFloat(f16, 1234);
        assertOrPanic(@typeOf(result) == f16);
        assertOrPanic(result == 1234.0);
    }
    {
        const result = @intToFloat(f32, 1234);
        assertOrPanic(@typeOf(result) == f32);
        assertOrPanic(result == 1234.0);
    }
}

test "@bytesToSlice keeps pointer alignment" {
    var bytes = []u8{ 0x01, 0x02, 0x03, 0x04 };
    const numbers = @bytesToSlice(u32, bytes[0..]);
    comptime assertOrPanic(@typeOf(numbers) == []align(@alignOf(@typeOf(bytes))) u32);
}

test "@intCast i32 to u7" {
    var x: u128 = maxInt(u128);
    var y: i32 = 120;
    var z = x >> @intCast(u7, y);
    assertOrPanic(z == 0xff);
}

test "implicit cast undefined to optional" {
    assertOrPanic(MakeType(void).getNull() == null);
    assertOrPanic(MakeType(void).getNonNull() != null);
}

fn MakeType(comptime T: type) type {
    return struct {
        fn getNull() ?T {
            return null;
        }

        fn getNonNull() ?T {
            return T(undefined);
        }
    };
}

test "implicit cast from *[N]T to ?[*]T" {
    var x: ?[*]u16 = null;
    var y: [4]u16 = [4]u16{ 0, 1, 2, 3 };

    x = &y;
    assertOrPanic(std.mem.eql(u16, x.?[0..4], y[0..4]));
    x.?[0] = 8;
    y[3] = 6;
    assertOrPanic(std.mem.eql(u16, x.?[0..4], y[0..4]));
}

test "implicit cast from *T to ?*c_void" {
    var a: u8 = 1;
    incrementVoidPtrValue(&a);
    std.debug.assertOrPanic(a == 2);
}

fn incrementVoidPtrValue(value: ?*c_void) void {
    @ptrCast(*u8, value.?).* += 1;
}

test "implicit cast from [*]T to ?*c_void" {
    var a = []u8{ 3, 2, 1 };
    incrementVoidPtrArray(a[0..].ptr, 3);
    assertOrPanic(std.mem.eql(u8, a, []u8{ 4, 3, 2 }));
}

fn incrementVoidPtrArray(array: ?*c_void, len: usize) void {
    var n: usize = 0;
    while (n < len) : (n += 1) {
        @ptrCast([*]u8, array.?)[n] += 1;
    }
}

test "*usize to *void" {
    var i = usize(0);
    var v = @ptrCast(*void, &i);
    v.* = {};
}

test "compile time int to ptr of function" {
    foobar(FUNCTION_CONSTANT);
}

pub const FUNCTION_CONSTANT = @intToPtr(PFN_void, maxInt(usize));
pub const PFN_void = extern fn (*c_void) void;

fn foobar(func: PFN_void) void {
    std.debug.assertOrPanic(@ptrToInt(func) == maxInt(usize));
}

test "implicit ptr to *c_void" {
    var a: u32 = 1;
    var ptr: *c_void = &a;
    var b: *u32 = @ptrCast(*u32, ptr);
    assertOrPanic(b.* == 1);
    var ptr2: ?*c_void = &a;
    var c: *u32 = @ptrCast(*u32, ptr2.?);
    assertOrPanic(c.* == 1);
}

test "@intCast to comptime_int" {
    assertOrPanic(@intCast(comptime_int, 0) == 0);
}

test "implicit cast comptime numbers to any type when the value fits" {
    const a: u64 = 255;
    var b: u8 = a;
    assertOrPanic(b == 255);
}

test "@intToEnum passed a comptime_int to an enum with one item" {
    const E = enum {
        A,
    };
    const x = @intToEnum(E, 0);
    assertOrPanic(x == E.A);
}
