const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .cast_to_null) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var c_ptr: [*c]u8 = 0;
    _ = &c_ptr;
    const zig_ptr: *u8 = c_ptr;
    _ = zig_ptr;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native
