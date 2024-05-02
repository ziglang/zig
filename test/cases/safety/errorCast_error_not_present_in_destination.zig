pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .cast_to_error_from_invalid) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_to_error_from_invalid', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
const Set1 = error{ A, B };
const Set2 = error{ A, C };
pub fn main() !void {
    foo(Set1.B) catch {};
    return error.TestFailed;
}
fn foo(set1: Set1) Set2 {
    return @errorCast(set1);
}
// run
// backend=llvm
// target=native
