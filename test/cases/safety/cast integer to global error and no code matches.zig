const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .invalid_error_code) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    bar(9999) catch {};
    return error.TestFailed;
}
fn bar(x: u16) anyerror {
    return @errorFromInt(x);
}
// run
// backend=llvm
// target=native
