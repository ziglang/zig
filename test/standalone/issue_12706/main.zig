const std = @import("std");
extern fn testFnPtr(n: c_int, ...) void;

const val: c_int = 123;

fn func(a: c_int) callconv(.C) void {
    std.debug.assert(a == val);
}

pub fn main() void {
    testFnPtr(2, func, val);
}
