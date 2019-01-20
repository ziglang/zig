const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const mem = std.mem;
const maxInt = std.math.maxInt;

test "implicit ptr to *c_void" {
    var a: u32 = 1;
    var ptr: *c_void = &a;
    var b: *u32 = @ptrCast(*u32, ptr);
    assertOrPanic(b.* == 1);
    var ptr2: ?*c_void = &a;
    var c: *u32 = @ptrCast(*u32, ptr2.?);
    assertOrPanic(c.* == 1);
}

