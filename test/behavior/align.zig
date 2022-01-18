const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");
const native_arch = builtin.target.cpu.arch;

var foo: u8 align(4) = 100;

test "global variable alignment" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    comptime try expect(@typeInfo(@TypeOf(&foo)).Pointer.alignment == 4);
    comptime try expect(@TypeOf(&foo) == *align(4) u8);
    {
        const slice = @as(*[1]u8, &foo)[0..];
        comptime try expect(@TypeOf(slice) == *align(4) [1]u8);
    }
    {
        var runtime_zero: usize = 0;
        const slice = @as(*[1]u8, &foo)[runtime_zero..];
        comptime try expect(@TypeOf(slice) == []align(4) u8);
    }
}

test "default alignment allows unspecified in type syntax" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try expect(*u32 == *align(@alignOf(u32)) u32);
}

test "implicitly decreasing pointer alignment" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const a: u32 align(4) = 3;
    const b: u32 align(8) = 4;
    try expect(addUnaligned(&a, &b) == 7);
}

fn addUnaligned(a: *align(1) const u32, b: *align(1) const u32) u32 {
    return a.* + b.*;
}

test "@alignCast pointers" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var x: u32 align(4) = 1;
    expectsOnly1(&x);
    try expect(x == 2);
}
fn expectsOnly1(x: *align(1) u32) void {
    expects4(@alignCast(4, x));
}
fn expects4(x: *align(4) u32) void {
    x.* += 1;
}

test "alignment of structs" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try expect(@alignOf(struct {
        a: i32,
        b: *i32,
    }) == @alignOf(usize));
}

test "alignment of >= 128-bit integer type" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try expect(@alignOf(u128) == 16);
    try expect(@alignOf(u129) == 16);
}

test "alignment of struct with 128-bit field" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try expect(@alignOf(struct {
        x: u128,
    }) == 16);

    comptime {
        try expect(@alignOf(struct {
            x: u128,
        }) == 16);
    }
}

test "size of extern struct with 128-bit field" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try expect(@sizeOf(extern struct {
        x: u128,
        y: u8,
    }) == 32);

    comptime {
        try expect(@sizeOf(extern struct {
            x: u128,
            y: u8,
        }) == 32);
    }
}

test "@ptrCast preserves alignment of bigger source" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var x: u32 align(16) = 1234;
    const ptr = @ptrCast(*u8, &x);
    try expect(@TypeOf(ptr) == *align(16) u8);
}

test "alignstack" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try expect(fnWithAlignedStack() == 1234);
}

fn fnWithAlignedStack() i32 {
    @setAlignStack(256);
    return 1234;
}

test "implicitly decreasing slice alignment" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const a: u32 align(4) = 3;
    const b: u32 align(8) = 4;
    try expect(addUnalignedSlice(@as(*const [1]u32, &a)[0..], @as(*const [1]u32, &b)[0..]) == 7);
}
fn addUnalignedSlice(a: []align(1) const u32, b: []align(1) const u32) u32 {
    return a[0] + b[0];
}

test "specifying alignment allows pointer cast" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try testBytesAlign(0x33);
}
fn testBytesAlign(b: u8) !void {
    var bytes align(4) = [_]u8{ b, b, b, b };
    const ptr = @ptrCast(*u32, &bytes[0]);
    try expect(ptr.* == 0x33333333);
}

test "@alignCast slices" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var array align(4) = [_]u32{ 1, 1 };
    const slice = array[0..];
    sliceExpectsOnly1(slice);
    try expect(slice[0] == 2);
}
fn sliceExpectsOnly1(slice: []align(1) u32) void {
    sliceExpects4(@alignCast(4, slice));
}
fn sliceExpects4(slice: []align(4) u32) void {
    slice[0] += 1;
}

test "return error union with 128-bit integer" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try expect(3 == try give());
}
fn give() anyerror!u128 {
    return 3;
}
