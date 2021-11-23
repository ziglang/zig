const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;
const maxInt = std.math.maxInt;
const native_endian = @import("builtin").target.cpu.arch.endian();

test "pointer reinterpret const float to int" {
    // The hex representation is 0x3fe3333333333303.
    const float: f64 = 5.99999999999994648725e-01;
    const float_ptr = &float;
    const int_ptr = @ptrCast(*const i32, float_ptr);
    const int_val = int_ptr.*;
    if (native_endian == .Little)
        try expect(int_val == 0x33333303)
    else
        try expect(int_val == 0x3fe33333);
}

test "@floatToInt" {
    try testFloatToInts();
    comptime try testFloatToInts();
}

fn testFloatToInts() !void {
    try expectFloatToInt(f16, 255.1, u8, 255);
    try expectFloatToInt(f16, 127.2, i8, 127);
    try expectFloatToInt(f16, -128.2, i8, -128);
}

fn expectFloatToInt(comptime F: type, f: F, comptime I: type, i: I) !void {
    try expect(@floatToInt(I, f) == i);
}

test "implicit cast from [*]T to ?*c_void" {
    var a = [_]u8{ 3, 2, 1 };
    var runtime_zero: usize = 0;
    incrementVoidPtrArray(a[runtime_zero..].ptr, 3);
    try expect(std.mem.eql(u8, &a, &[_]u8{ 4, 3, 2 }));
}

fn incrementVoidPtrArray(array: ?*c_void, len: usize) void {
    var n: usize = 0;
    while (n < len) : (n += 1) {
        @ptrCast([*]u8, array.?)[n] += 1;
    }
}

test "compile time int to ptr of function" {
    try foobar(FUNCTION_CONSTANT);
}

pub const FUNCTION_CONSTANT = @intToPtr(PFN_void, maxInt(usize));
pub const PFN_void = fn (*c_void) callconv(.C) void;

fn foobar(func: PFN_void) !void {
    try std.testing.expect(@ptrToInt(func) == maxInt(usize));
}

test "implicit ptr to *c_void" {
    var a: u32 = 1;
    var ptr: *align(@alignOf(u32)) c_void = &a;
    var b: *u32 = @ptrCast(*u32, ptr);
    try expect(b.* == 1);
    var ptr2: ?*align(@alignOf(u32)) c_void = &a;
    var c: *u32 = @ptrCast(*u32, ptr2.?);
    try expect(c.* == 1);
}

const A = struct {
    a: i32,
};
test "return null from fn() anyerror!?&T" {
    const a = returnNullFromOptionalTypeErrorRef();
    const b = returnNullLitFromOptionalTypeErrorRef();
    try expect((try a) == null and (try b) == null);
}
fn returnNullFromOptionalTypeErrorRef() anyerror!?*A {
    const a: ?*A = null;
    return a;
}
fn returnNullLitFromOptionalTypeErrorRef() anyerror!?*A {
    return null;
}

test "peer type resolution: [0]u8 and []const u8" {
    try expect(peerTypeEmptyArrayAndSlice(true, "hi").len == 0);
    try expect(peerTypeEmptyArrayAndSlice(false, "hi").len == 1);
    comptime {
        try expect(peerTypeEmptyArrayAndSlice(true, "hi").len == 0);
        try expect(peerTypeEmptyArrayAndSlice(false, "hi").len == 1);
    }
}
fn peerTypeEmptyArrayAndSlice(a: bool, slice: []const u8) []const u8 {
    if (a) {
        return &[_]u8{};
    }

    return slice[0..1];
}

test "implicitly cast from [N]T to ?[]const T" {
    try expect(mem.eql(u8, castToOptionalSlice().?, "hi"));
    comptime try expect(mem.eql(u8, castToOptionalSlice().?, "hi"));
}

fn castToOptionalSlice() ?[]const u8 {
    return "hi";
}

test "cast u128 to f128 and back" {
    comptime try testCast128();
    try testCast128();
}

fn testCast128() !void {
    try expect(cast128Int(cast128Float(0x7fff0000000000000000000000000000)) == 0x7fff0000000000000000000000000000);
}

fn cast128Int(x: f128) u128 {
    return @bitCast(u128, x);
}

fn cast128Float(x: u128) f128 {
    return @bitCast(f128, x);
}

test "implicit cast from *[N]T to ?[*]T" {
    var x: ?[*]u16 = null;
    var y: [4]u16 = [4]u16{ 0, 1, 2, 3 };

    x = &y;
    try expect(std.mem.eql(u16, x.?[0..4], y[0..4]));
    x.?[0] = 8;
    y[3] = 6;
    try expect(std.mem.eql(u16, x.?[0..4], y[0..4]));
}

test "implicit cast from *T to ?*c_void" {
    var a: u8 = 1;
    incrementVoidPtrValue(&a);
    try std.testing.expect(a == 2);
}

fn incrementVoidPtrValue(value: ?*c_void) void {
    @ptrCast(*u8, value.?).* += 1;
}

test "implicit cast *[0]T to E![]const u8" {
    var x = @as(anyerror![]const u8, &[0]u8{});
    try expect((x catch unreachable).len == 0);
}

var global_array: [4]u8 = undefined;
test "cast from array reference to fn" {
    const f = @ptrCast(fn () callconv(.C) void, &global_array);
    try expect(@ptrToInt(f) == @ptrToInt(&global_array));
}

test "*const [N]null u8 to ?[]const u8" {
    const S = struct {
        fn doTheTest() !void {
            var a = "Hello";
            var b: ?[]const u8 = a;
            try expect(mem.eql(u8, b.?, "Hello"));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "cast between [*c]T and ?[*:0]T on fn parameter" {
    const S = struct {
        const Handler = ?fn ([*c]const u8) callconv(.C) void;
        fn addCallback(handler: Handler) void {
            _ = handler;
        }

        fn myCallback(cstr: ?[*:0]const u8) callconv(.C) void {
            _ = cstr;
        }

        fn doTheTest() void {
            addCallback(myCallback);
        }
    };
    S.doTheTest();
}

var global_struct: struct { f0: usize } = undefined;
test "assignment to optional pointer result loc" {
    var foo: struct { ptr: ?*c_void } = .{ .ptr = &global_struct };
    try expect(foo.ptr.? == @ptrCast(*c_void, &global_struct));
}

test "cast between *[N]void and []void" {
    var a: [4]void = undefined;
    var b: []void = &a;
    try expect(b.len == 4);
}
