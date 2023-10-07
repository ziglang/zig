const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "cast causes pointer to be null")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

fn getNullPtr() ?*const anyopaque {
    return null;
}
pub fn main() !void {
    const null_ptr: ?*const anyopaque = getNullPtr();
    const required_ptr: *align(1) const fn () void = @ptrCast(null_ptr);
    _ = required_ptr;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native
