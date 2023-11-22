const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "cast causes pointer to be null")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    var zero: usize = 0;
    _ = &zero;
    const b: *u8 = @ptrFromInt(zero);
    _ = b;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native
