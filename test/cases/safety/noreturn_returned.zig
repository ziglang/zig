pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .returned_noreturn) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.returned_noreturn', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
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
