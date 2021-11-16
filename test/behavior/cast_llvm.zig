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
