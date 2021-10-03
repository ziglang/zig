const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;
const maxInt = std.math.maxInt;
const Vector = std.meta.Vector;
const native_endian = @import("builtin").target.cpu.arch.endian();

test "int to ptr cast" {
    const x = @as(usize, 13);
    const y = @intToPtr(*u8, x);
    const z = @ptrToInt(y);
    try expect(z == 13);
}

test "integer literal to pointer cast" {
    const vga_mem = @intToPtr(*u16, 0xB8000);
    try expect(@ptrToInt(vga_mem) == 0xB8000);
}

test "peer type resolution: ?T and T" {
    try expect(peerTypeTAndOptionalT(true, false).? == 0);
    try expect(peerTypeTAndOptionalT(false, false).? == 3);
    comptime {
        try expect(peerTypeTAndOptionalT(true, false).? == 0);
        try expect(peerTypeTAndOptionalT(false, false).? == 3);
    }
}
fn peerTypeTAndOptionalT(c: bool, b: bool) ?usize {
    if (c) {
        return if (b) null else @as(usize, 0);
    }

    return @as(usize, 3);
}

test "resolve undefined with integer" {
    try testResolveUndefWithInt(true, 1234);
    comptime try testResolveUndefWithInt(true, 1234);
}
fn testResolveUndefWithInt(b: bool, x: i32) !void {
    const value = if (b) x else undefined;
    if (b) {
        try expect(value == x);
    }
}

test "@intCast i32 to u7" {
    var x: u128 = maxInt(u128);
    var y: i32 = 120;
    var z = x >> @intCast(u7, y);
    try expect(z == 0xff);
}

test "@intCast to comptime_int" {
    try expect(@intCast(comptime_int, 0) == 0);
}

test "implicit cast comptime numbers to any type when the value fits" {
    const a: u64 = 255;
    var b: u8 = a;
    try expect(b == 255);
}

test "implicit cast comptime_int to comptime_float" {
    comptime try expect(@as(comptime_float, 10) == @as(f32, 10));
    try expect(2 == 2.0);
}
