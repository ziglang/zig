const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");
const native_arch = builtin.target.cpu.arch;

var foo: u8 align(4) = 100;

test "global variable alignment" {
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
    try expect(*u32 == *align(@alignOf(u32)) u32);
}

test "implicitly decreasing pointer alignment" {
    const a: u32 align(4) = 3;
    const b: u32 align(8) = 4;
    try expect(addUnaligned(&a, &b) == 7);
}

fn addUnaligned(a: *align(1) const u32, b: *align(1) const u32) u32 {
    return a.* + b.*;
}

test "implicitly decreasing slice alignment" {
    const a: u32 align(4) = 3;
    const b: u32 align(8) = 4;
    try expect(addUnalignedSlice(@as(*const [1]u32, &a)[0..], @as(*const [1]u32, &b)[0..]) == 7);
}
fn addUnalignedSlice(a: []align(1) const u32, b: []align(1) const u32) u32 {
    return a[0] + b[0];
}
