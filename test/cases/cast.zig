const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const mem = std.mem;
const maxInt = std.math.maxInt;

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

test "@bytesToSlice keeps pointer alignment" {
    var bytes = []u8{ 0x01, 0x02, 0x03, 0x04 };
    const numbers = @bytesToSlice(u32, bytes[0..]);
    comptime assertOrPanic(@typeOf(numbers) == []align(@alignOf(@typeOf(bytes))) u32);
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

