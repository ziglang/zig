const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .noreturn_returned) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
const T = struct {
    export fn bar() void {
        // ...
    }
};

extern fn bar() noreturn;
pub fn main() void {
    _ = T.bar;
    bar();
}
// run
// backend=llvm
// target=native
