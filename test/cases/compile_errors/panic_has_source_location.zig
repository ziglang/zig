const std = @import("std");

export fn foo() void {
    // This should appear in the reference trace
    // (and definitely shouldn't crash due to an unneeded source location!)
    @panic("oh no");
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @compileError("panic");
}

// error
// backend=stage2
// target=native
//
// :10:5: error: panic
