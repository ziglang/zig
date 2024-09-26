const std = @import("std");

export fn foo() void {
    // This should appear in the reference trace
    // (and definitely shouldn't crash due to an unneeded source location!)
    @panic("oh no");
}

pub fn panic(cause: std.builtin.PanicCause, ert: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    _ = cause;
    _ = ert;
    _ = ra;
    @compileError("panic");
}

// error
// backend=stage2
// target=native
//
// :13:5: error: panic
