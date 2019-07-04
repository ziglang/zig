const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;
const maxInt = std.math.maxInt;

test "int to ptr cast" {
    const x = usize(13);
    const y = @intToPtr(*u8, x);
    const z = @ptrToInt(y);
    expect(z == 13);
}

test "integer literal to pointer cast" {
    const vga_mem = @intToPtr(*u16, 0xB8000);
    expect(@ptrToInt(vga_mem) == 0xB8000);
}

test "pointer reinterpret const float to int" {
    const float: f64 = 5.99999999999994648725e-01;
    const float_ptr = &float;
    const int_ptr = @ptrCast(*const i32, float_ptr);
    const int_val = int_ptr.*;
    expect(int_val == 858993411);
}

test "implicitly cast indirect pointer to maybe-indirect pointer" {
    const S = struct {
        const Self = @This();
        x: u8,
        fn constConst(p: *const *const Self) u8 {
            return p.*.x;
        }
        fn maybeConstConst(p: ?*const *const Self) u8 {
            return p.?.*.x;
        }
        fn constConstConst(p: *const *const *const Self) u8 {
            return p.*.*.x;
        }
        fn maybeConstConstConst(p: ?*const *const *const Self) u8 {
            return p.?.*.*.x;
        }
    };
    const s = S{ .x = 42 };
    const p = &s;
    const q = &p;
    const r = &q;
    expect(42 == S.constConst(q));
    expect(42 == S.maybeConstConst(q));
    expect(42 == S.constConstConst(r));
    expect(42 == S.maybeConstConstConst(r));
}

test "explicit cast from integer to error type" {
    testCastIntToErr(error.ItBroke);
    comptime testCastIntToErr(error.ItBroke);
}
fn testCastIntToErr(err: anyerror) void {
    const x = @errorToInt(err);
    const y = @intToError(x);
    expect(error.ItBroke == y);
}

test "peer resolve arrays of different size to const slice" {
    expect(mem.eql(u8, boolToStr(true), "true"));
    expect(mem.eql(u8, boolToStr(false), "false"));
    comptime expect(mem.eql(u8, boolToStr(true), "true"));
    comptime expect(mem.eql(u8, boolToStr(false), "false"));
}
fn boolToStr(b: bool) []const u8 {
    return if (b) "true" else "false";
}

test "peer resolve array and const slice" {
    testPeerResolveArrayConstSlice(true);
    comptime testPeerResolveArrayConstSlice(true);
}
fn testPeerResolveArrayConstSlice(b: bool) void {
    const value1 = if (b) "aoeu" else ([]const u8)("zz");
    const value2 = if (b) ([]const u8)("zz") else "aoeu";
    expect(mem.eql(u8, value1, "aoeu"));
    expect(mem.eql(u8, value2, "zz"));
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
    expect((try y).? == 1);

    const f = z;
    const g: anyerror!?i32 = f;

    const a = A{ .a = z };
    const b: anyerror!?A = a;
    expect((b catch unreachable).?.a == 1);
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
    expect((try a) == null and (try b) == null);
}
fn returnNullFromOptionalTypeErrorRef() anyerror!?*A {
    const a: ?*A = null;
    return a;
}
fn returnNullLitFromOptionalTypeErrorRef() anyerror!?*A {
    return null;
}

test "peer type resolution: ?T and T" {
    expect(peerTypeTAndOptionalT(true, false).? == 0);
    expect(peerTypeTAndOptionalT(false, false).? == 3);
    comptime {
        expect(peerTypeTAndOptionalT(true, false).? == 0);
        expect(peerTypeTAndOptionalT(false, false).? == 3);
    }
}
fn peerTypeTAndOptionalT(c: bool, b: bool) ?usize {
    if (c) {
        return if (b) null else usize(0);
    }

    return usize(3);
}

test "peer type resolution: [0]u8 and []const u8" {
    expect(peerTypeEmptyArrayAndSlice(true, "hi").len == 0);
    expect(peerTypeEmptyArrayAndSlice(false, "hi").len == 1);
    comptime {
        expect(peerTypeEmptyArrayAndSlice(true, "hi").len == 0);
        expect(peerTypeEmptyArrayAndSlice(false, "hi").len == 1);
    }
}
fn peerTypeEmptyArrayAndSlice(a: bool, slice: []const u8) []const u8 {
    if (a) {
        return [_]u8{};
    }

    return slice[0..1];
}

test "implicitly cast from [N]T to ?[]const T" {
    expect(mem.eql(u8, castToOptionalSlice().?, "hi"));
    comptime expect(mem.eql(u8, castToOptionalSlice().?, "hi"));
}

fn castToOptionalSlice() ?[]const u8 {
    return "hi";
}

test "implicitly cast from [0]T to anyerror![]T" {
    testCastZeroArrayToErrSliceMut();
    comptime testCastZeroArrayToErrSliceMut();
}

fn testCastZeroArrayToErrSliceMut() void {
    expect((gimmeErrOrSlice() catch unreachable).len == 0);
}

fn gimmeErrOrSlice() anyerror![]u8 {
    return [_]u8{};
}

test "peer type resolution: [0]u8, []const u8, and anyerror![]u8" {
    {
        var data = "hi";
        const slice = data[0..];
        expect((try peerTypeEmptyArrayAndSliceAndError(true, slice)).len == 0);
        expect((try peerTypeEmptyArrayAndSliceAndError(false, slice)).len == 1);
    }
    comptime {
        var data = "hi";
        const slice = data[0..];
        expect((try peerTypeEmptyArrayAndSliceAndError(true, slice)).len == 0);
        expect((try peerTypeEmptyArrayAndSliceAndError(false, slice)).len == 1);
    }
}
fn peerTypeEmptyArrayAndSliceAndError(a: bool, slice: []u8) anyerror![]u8 {
    if (a) {
        return [_]u8{};
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
        expect(value == x);
    }
}

test "implicit cast from &const [N]T to []const T" {
    testCastConstArrayRefToConstSlice();
    comptime testCastConstArrayRefToConstSlice();
}

fn testCastConstArrayRefToConstSlice() void {
    const blah = "aoeu";
    const const_array_ref = &blah;
    expect(@typeOf(const_array_ref) == *const [4]u8);
    const slice: []const u8 = const_array_ref;
    expect(mem.eql(u8, slice, "aoeu"));
}

test "peer type resolution: error and [N]T" {
    // TODO: implicit error!T to error!U where T can implicitly cast to U
    //expect(mem.eql(u8, try testPeerErrorAndArray(0), "OK"));
    //comptime expect(mem.eql(u8, try testPeerErrorAndArray(0), "OK"));
    expect(mem.eql(u8, try testPeerErrorAndArray2(1), "OKK"));
    comptime expect(mem.eql(u8, try testPeerErrorAndArray2(1), "OKK"));
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
    expect(x == 10000);
    const y = @floatToInt(i32, f32(1e4));
    expect(y == 10000);
    expectFloatToInt(f16, 255.1, u8, 255);
    expectFloatToInt(f16, 127.2, i8, 127);
    expectFloatToInt(f16, -128.2, i8, -128);
    expectFloatToInt(f32, 255.1, u8, 255);
    expectFloatToInt(f32, 127.2, i8, 127);
    expectFloatToInt(f32, -128.2, i8, -128);
    expectFloatToInt(comptime_int, 1234, i16, 1234);
}

fn expectFloatToInt(comptime F: type, f: F, comptime I: type, i: I) void {
    expect(@floatToInt(I, f) == i);
}

test "cast u128 to f128 and back" {
    comptime testCast128();
    testCast128();
}

fn testCast128() void {
    expect(cast128Int(cast128Float(0x7fff0000000000000000000000000000)) == 0x7fff0000000000000000000000000000);
}

fn cast128Int(x: f128) u128 {
    return @bitCast(u128, x);
}

fn cast128Float(x: u128) f128 {
    return @bitCast(f128, x);
}

test "const slice widen cast" {
    const bytes align(4) = [_]u8{
        0x12,
        0x12,
        0x12,
        0x12,
    };

    const u32_value = @bytesToSlice(u32, bytes[0..])[0];
    expect(u32_value == 0x12121212);

    expect(@bitCast(u32, bytes) == 0x12121212);
}

test "single-item pointer of array to slice and to unknown length pointer" {
    testCastPtrOfArrayToSliceAndPtr();
    comptime testCastPtrOfArrayToSliceAndPtr();
}

fn testCastPtrOfArrayToSliceAndPtr() void {
    var array = "aoeu";
    const x: [*]u8 = &array;
    x[0] += 1;
    expect(mem.eql(u8, array[0..], "boeu"));
    const y: []u8 = &array;
    y[0] += 1;
    expect(mem.eql(u8, array[0..], "coeu"));
}

test "cast *[1][*]const u8 to [*]const ?[*]const u8" {
    const window_name = [1][*]const u8{c"window name"};
    const x: [*]const ?[*]const u8 = &window_name;
    expect(mem.eql(u8, std.mem.toSliceConst(u8, x[0].?), "window name"));
}

test "@intCast comptime_int" {
    const result = @intCast(i32, 1234);
    expect(@typeOf(result) == i32);
    expect(result == 1234);
}

test "@floatCast comptime_int and comptime_float" {
    {
        const result = @floatCast(f16, 1234);
        expect(@typeOf(result) == f16);
        expect(result == 1234.0);
    }
    {
        const result = @floatCast(f16, 1234.0);
        expect(@typeOf(result) == f16);
        expect(result == 1234.0);
    }
    {
        const result = @floatCast(f32, 1234);
        expect(@typeOf(result) == f32);
        expect(result == 1234.0);
    }
    {
        const result = @floatCast(f32, 1234.0);
        expect(@typeOf(result) == f32);
        expect(result == 1234.0);
    }
}

test "comptime_int @intToFloat" {
    {
        const result = @intToFloat(f16, 1234);
        expect(@typeOf(result) == f16);
        expect(result == 1234.0);
    }
    {
        const result = @intToFloat(f32, 1234);
        expect(@typeOf(result) == f32);
        expect(result == 1234.0);
    }
}

test "@bytesToSlice keeps pointer alignment" {
    var bytes = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
    const numbers = @bytesToSlice(u32, bytes[0..]);
    comptime expect(@typeOf(numbers) == []align(@alignOf(@typeOf(bytes))) u32);
}

test "@intCast i32 to u7" {
    var x: u128 = maxInt(u128);
    var y: i32 = 120;
    var z = x >> @intCast(u7, y);
    expect(z == 0xff);
}

test "implicit cast undefined to optional" {
    expect(MakeType(void).getNull() == null);
    expect(MakeType(void).getNonNull() != null);
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
    expect(std.mem.eql(u16, x.?[0..4], y[0..4]));
    x.?[0] = 8;
    y[3] = 6;
    expect(std.mem.eql(u16, x.?[0..4], y[0..4]));
}

test "implicit cast from *[N]T to [*c]T" {
    var x: [4]u16 = [4]u16{ 0, 1, 2, 3 };
    var y: [*c]u16 = &x;

    expect(std.mem.eql(u16, x[0..4], y[0..4]));
    x[0] = 8;
    y[3] = 6;
    expect(std.mem.eql(u16, x[0..4], y[0..4]));
}

test "implicit cast from *T to ?*c_void" {
    var a: u8 = 1;
    incrementVoidPtrValue(&a);
    std.testing.expect(a == 2);
}

fn incrementVoidPtrValue(value: ?*c_void) void {
    @ptrCast(*u8, value.?).* += 1;
}

test "implicit cast from [*]T to ?*c_void" {
    var a = [_]u8{ 3, 2, 1 };
    incrementVoidPtrArray(a[0..].ptr, 3);
    expect(std.mem.eql(u8, a, [_]u8{ 4, 3, 2 }));
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
    std.testing.expect(@ptrToInt(func) == maxInt(usize));
}

test "implicit ptr to *c_void" {
    var a: u32 = 1;
    var ptr: *c_void = &a;
    var b: *u32 = @ptrCast(*u32, ptr);
    expect(b.* == 1);
    var ptr2: ?*c_void = &a;
    var c: *u32 = @ptrCast(*u32, ptr2.?);
    expect(c.* == 1);
}

test "@intCast to comptime_int" {
    expect(@intCast(comptime_int, 0) == 0);
}

test "implicit cast comptime numbers to any type when the value fits" {
    const a: u64 = 255;
    var b: u8 = a;
    expect(b == 255);
}

test "@intToEnum passed a comptime_int to an enum with one item" {
    const E = enum {
        A,
    };
    const x = @intToEnum(E, 0);
    expect(x == E.A);
}

test "@intCast to u0 and use the result" {
    const S = struct {
        fn doTheTest(zero: u1, one: u1, bigzero: i32) void {
            expect((one << @intCast(u0, bigzero)) == 1);
            expect((zero << @intCast(u0, bigzero)) == 0);
        }
    };
    S.doTheTest(0, 1, 0);
    comptime S.doTheTest(0, 1, 0);
}

test "peer type resolution: unreachable, null, slice" {
    const S = struct {
        fn doTheTest(num: usize, word: []const u8) void {
            const result = switch (num) {
                0 => null,
                1 => word,
                else => unreachable,
            };
            expect(mem.eql(u8, result.?, "hi"));
        }
    };
    S.doTheTest(1, "hi");
}

test "peer type resolution: unreachable, error set, unreachable" {
    const Error = error {
        FileDescriptorAlreadyPresentInSet,
        OperationCausesCircularLoop,
        FileDescriptorNotRegistered,
        SystemResources,
        UserResourceLimitReached,
        FileDescriptorIncompatibleWithEpoll,
        Unexpected,
    };
    var err = Error.SystemResources;
    const transformed_err = switch (err) {
        error.FileDescriptorAlreadyPresentInSet => unreachable,
        error.OperationCausesCircularLoop => unreachable,
        error.FileDescriptorNotRegistered => unreachable,
        error.SystemResources => error.SystemResources,
        error.UserResourceLimitReached => error.UserResourceLimitReached,
        error.FileDescriptorIncompatibleWithEpoll => unreachable,
        error.Unexpected => unreachable,
    };
    expect(transformed_err == error.SystemResources);
}
