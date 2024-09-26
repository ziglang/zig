const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    switch (cause) {
        .unwrap_error => |err| {
            if (err == error.Whatever) {
                std.process.exit(0);
            }
        },
        else => {},
    }
    std.process.exit(1);
}
pub fn main() !void {
    bar() catch |err| switch (err) {
        error.Whatever => unreachable,
    };
    return error.TestFailed;
}
fn bar() !void {
    return error.Whatever;
}
// run
// backend=llvm
// target=native
