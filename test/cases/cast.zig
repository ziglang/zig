const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;

test "int to ptr cast" {
    const x = usize(13);
    const y = @intToPtr(*u8, x);
    const z = @ptrToInt(y);
    assert(z == 13);
}

test "integer literal to pointer cast" {
    const vga_mem = @intToPtr(*u16, 0xB8000);
    assert(@ptrToInt(vga_mem) == 0xB8000);
}

test "pointer reinterpret const float to int" {
    const float: f64 = 5.99999999999994648725e-01;
    const float_ptr = &float;
    const int_ptr = @ptrCast(*const i32, float_ptr);
    const int_val = int_ptr.*;
    assert(int_val == 858993411);
}

test "implicitly cast a pointer to a const pointer of it" {
    var x: i32 = 1;
    const xp = &x;
    funcWithConstPtrPtr(xp);
    assert(x == 2);
}

fn funcWithConstPtrPtr(x: *const *i32) void {
    x.*.* += 1;
}

test "implicitly cast a container to a const pointer of it" {
    const z = Struct(void){ .x = void{} };
    assert(0 == @sizeOf(@typeOf(z)));
    assert(void{} == Struct(void).pointer(z).x);
    assert(void{} == Struct(void).pointer(&z).x);
    assert(void{} == Struct(void).maybePointer(z).x);
    assert(void{} == Struct(void).maybePointer(&z).x);
    assert(void{} == Struct(void).maybePointer(null).x);
    const s = Struct(u8){ .x = 42 };
    assert(0 != @sizeOf(@typeOf(s)));
    assert(42 == Struct(u8).pointer(s).x);
    assert(42 == Struct(u8).pointer(&s).x);
    assert(42 == Struct(u8).maybePointer(s).x);
    assert(42 == Struct(u8).maybePointer(&s).x);
    assert(0 == Struct(u8).maybePointer(null).x);
    const u = Union{ .x = 42 };
    assert(42 == Union.pointer(u).x);
    assert(42 == Union.pointer(&u).x);
    assert(42 == Union.maybePointer(u).x);
    assert(42 == Union.maybePointer(&u).x);
    assert(0 == Union.maybePointer(null).x);
    const e = Enum.Some;
    assert(Enum.Some == Enum.pointer(e));
    assert(Enum.Some == Enum.pointer(&e));
    assert(Enum.Some == Enum.maybePointer(e));
    assert(Enum.Some == Enum.maybePointer(&e));
    assert(Enum.None == Enum.maybePointer(null));
}

fn Struct(comptime T: type) type {
    return struct {
        const Self = this;
        x: T,

        fn pointer(self: *const Self) Self {
            return self.*;
        }

        fn maybePointer(self: ?*const Self) Self {
            const none = Self{ .x = if (T == void) void{} else 0 };
            return (self orelse &none).*;
        }
    };
}

const Union = union {
    x: u8,

    fn pointer(self: *const Union) Union {
        return self.*;
    }

    fn maybePointer(self: ?*const Union) Union {
        const none = Union{ .x = 0 };
        return (self orelse &none).*;
    }
};

const Enum = enum {
    None,
    Some,

    fn pointer(self: *const Enum) Enum {
        return self.*;
    }

    fn maybePointer(self: ?*const Enum) Enum {
        return (self orelse &Enum.None).*;
    }
};

test "implicitly cast indirect pointer to maybe-indirect pointer" {
    const S = struct {
        const Self = this;
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
    assert(42 == S.constConst(p));
    assert(42 == S.constConst(q));
    assert(42 == S.maybeConstConst(p));
    assert(42 == S.maybeConstConst(q));
    assert(42 == S.constConstConst(q));
    assert(42 == S.constConstConst(r));
    assert(42 == S.maybeConstConstConst(q));
    assert(42 == S.maybeConstConstConst(r));
}

test "explicit cast from integer to error type" {
    testCastIntToErr(error.ItBroke);
    comptime testCastIntToErr(error.ItBroke);
}
fn testCastIntToErr(err: error) void {
    const x = @errorToInt(err);
    const y = @intToError(x);
    assert(error.ItBroke == y);
}

test "peer resolve arrays of different size to const slice" {
    assert(mem.eql(u8, boolToStr(true), "true"));
    assert(mem.eql(u8, boolToStr(false), "false"));
    comptime assert(mem.eql(u8, boolToStr(true), "true"));
    comptime assert(mem.eql(u8, boolToStr(false), "false"));
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
    assert(mem.eql(u8, value1, "aoeu"));
    assert(mem.eql(u8, value2, "zz"));
}

test "integer literal to &const int" {
    const x: *const i32 = 3;
    assert(x.* == 3);
}

test "string literal to &const []const u8" {
    const x: *const []const u8 = "hello";
    assert(mem.eql(u8, x.*, "hello"));
}

test "implicitly cast from T to error!?T" {
    castToOptionalTypeError(1);
    comptime castToOptionalTypeError(1);
}
const A = struct {
    a: i32,
};
fn castToOptionalTypeError(z: i32) void {
    const x = i32(1);
    const y: error!?i32 = x;
    assert((try y).? == 1);

    const f = z;
    const g: error!?i32 = f;

    const a = A{ .a = z };
    const b: error!?A = a;
    assert((b catch unreachable).?.a == 1);
}

test "implicitly cast from int to error!?T" {
    implicitIntLitToOptional();
    comptime implicitIntLitToOptional();
}
fn implicitIntLitToOptional() void {
    const f: ?i32 = 1;
    const g: error!?i32 = 1;
}

test "return null from fn() error!?&T" {
    const a = returnNullFromOptionalTypeErrorRef();
    const b = returnNullLitFromOptionalTypeErrorRef();
    assert((try a) == null and (try b) == null);
}
fn returnNullFromOptionalTypeErrorRef() error!?*A {
    const a: ?*A = null;
    return a;
}
fn returnNullLitFromOptionalTypeErrorRef() error!?*A {
    return null;
}

test "peer type resolution: ?T and T" {
    assert(peerTypeTAndOptionalT(true, false).? == 0);
    assert(peerTypeTAndOptionalT(false, false).? == 3);
    comptime {
        assert(peerTypeTAndOptionalT(true, false).? == 0);
        assert(peerTypeTAndOptionalT(false, false).? == 3);
    }
}
fn peerTypeTAndOptionalT(c: bool, b: bool) ?usize {
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
fn peerTypeEmptyArrayAndSlice(a: bool, slice: []const u8) []const u8 {
    if (a) {
        return []const u8{};
    }

    return slice[0..1];
}

test "implicitly cast from [N]T to ?[]const T" {
    assert(mem.eql(u8, castToOptionalSlice().?, "hi"));
    comptime assert(mem.eql(u8, castToOptionalSlice().?, "hi"));
}

fn castToOptionalSlice() ?[]const u8 {
    return "hi";
}

test "implicitly cast from [0]T to error![]T" {
    testCastZeroArrayToErrSliceMut();
    comptime testCastZeroArrayToErrSliceMut();
}

fn testCastZeroArrayToErrSliceMut() void {
    assert((gimmeErrOrSlice() catch unreachable).len == 0);
}

fn gimmeErrOrSlice() error![]u8 {
    return []u8{};
}

test "peer type resolution: [0]u8, []const u8, and error![]u8" {
    {
        var data = "hi";
        const slice = data[0..];
        assert((try peerTypeEmptyArrayAndSliceAndError(true, slice)).len == 0);
        assert((try peerTypeEmptyArrayAndSliceAndError(false, slice)).len == 1);
    }
    comptime {
        var data = "hi";
        const slice = data[0..];
        assert((try peerTypeEmptyArrayAndSliceAndError(true, slice)).len == 0);
        assert((try peerTypeEmptyArrayAndSliceAndError(false, slice)).len == 1);
    }
}
fn peerTypeEmptyArrayAndSliceAndError(a: bool, slice: []u8) error![]u8 {
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
        assert(value == x);
    }
}

test "implicit cast from &const [N]T to []const T" {
    testCastConstArrayRefToConstSlice();
    comptime testCastConstArrayRefToConstSlice();
}

fn testCastConstArrayRefToConstSlice() void {
    const blah = "aoeu";
    const const_array_ref = &blah;
    assert(@typeOf(const_array_ref) == *const [4]u8);
    const slice: []const u8 = const_array_ref;
    assert(mem.eql(u8, slice, "aoeu"));
}

test "peer type resolution: error and [N]T" {
    // TODO: implicit error!T to error!U where T can implicitly cast to U
    //assert(mem.eql(u8, try testPeerErrorAndArray(0), "OK"));
    //comptime assert(mem.eql(u8, try testPeerErrorAndArray(0), "OK"));
    assert(mem.eql(u8, try testPeerErrorAndArray2(1), "OKK"));
    comptime assert(mem.eql(u8, try testPeerErrorAndArray2(1), "OKK"));
}

//fn testPeerErrorAndArray(x: u8) error![]const u8 {
//    return switch (x) {
//        0x00 => "OK",
//        else => error.BadValue,
//    };
//}
fn testPeerErrorAndArray2(x: u8) error![]const u8 {
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
    assert(x == 10000);
    const y = @floatToInt(i32, f32(1e4));
    assert(y == 10000);
    expectFloatToInt(f16, 255.1, u8, 255);
    expectFloatToInt(f16, 127.2, i8, 127);
    expectFloatToInt(f16, -128.2, i8, -128);
    expectFloatToInt(f32, 255.1, u8, 255);
    expectFloatToInt(f32, 127.2, i8, 127);
    expectFloatToInt(f32, -128.2, i8, -128);
}

fn expectFloatToInt(comptime F: type, f: F, comptime I: type, i: I) void {
    assert(@floatToInt(I, f) == i);
}

test "cast u128 to f128 and back" {
    comptime testCast128();
    testCast128();
}

fn testCast128() void {
    assert(cast128Int(cast128Float(0x7fff0000000000000000000000000000)) == 0x7fff0000000000000000000000000000);
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
    assert(u32_value == 0x12121212);

    assert(@bitCast(u32, bytes) == 0x12121212);
}

test "single-item pointer of array to slice and to unknown length pointer" {
    testCastPtrOfArrayToSliceAndPtr();
    comptime testCastPtrOfArrayToSliceAndPtr();
}

fn testCastPtrOfArrayToSliceAndPtr() void {
    var array = "ao" ++ "eu"; // TODO https://github.com/ziglang/zig/issues/1076
    const x: [*]u8 = &array;
    x[0] += 1;
    assert(mem.eql(u8, array[0..], "boeu"));
    const y: []u8 = &array;
    y[0] += 1;
    assert(mem.eql(u8, array[0..], "coeu"));
}

test "cast *[1][*]const u8 to [*]const ?[*]const u8" {
    const window_name = [1][*]const u8{c"window name"};
    const x: [*]const ?[*]const u8 = &window_name;
    assert(mem.eql(u8, std.cstr.toSliceConst(x[0].?), "window name"));
}

test "@intCast comptime_int" {
    const result = @intCast(i32, 1234);
    assert(@typeOf(result) == i32);
    assert(result == 1234);
}

test "@floatCast comptime_int and comptime_float" {
    {
        const result = @floatCast(f16, 1234);
        assert(@typeOf(result) == f16);
        assert(result == 1234.0);
    }
    {
        const result = @floatCast(f16, 1234.0);
        assert(@typeOf(result) == f16);
        assert(result == 1234.0);
    }
    {
        const result = @floatCast(f32, 1234);
        assert(@typeOf(result) == f32);
        assert(result == 1234.0);
    }
    {
        const result = @floatCast(f32, 1234.0);
        assert(@typeOf(result) == f32);
        assert(result == 1234.0);
    }
}

test "comptime_int @intToFloat" {
    {
        const result = @intToFloat(f16, 1234);
        assert(@typeOf(result) == f16);
        assert(result == 1234.0);
    }
    {
        const result = @intToFloat(f32, 1234);
        assert(@typeOf(result) == f32);
        assert(result == 1234.0);
    }
}

test "@bytesToSlice keeps pointer alignment" {
    var bytes = []u8{ 0x01, 0x02, 0x03, 0x04 };
    const numbers = @bytesToSlice(u32, bytes[0..]);
    comptime assert(@typeOf(numbers) == []align(@alignOf(@typeOf(bytes))) u32);
}

test "@intCast i32 to u7" {
    var x: u128 = @maxValue(u128);
    var y: i32 = 120;
    var z = x >> @intCast(u7, y);
    assert(z == 0xff);
}
