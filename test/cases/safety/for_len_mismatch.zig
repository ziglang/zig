pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .mismatched_for_loop_capture_lengths) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.mismatched_for_loop_capture_lengths', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var runtime_i: usize = 1;
    var j: usize = 3;
    var slice = "too long";
    _ = .{ &runtime_i, &j, &slice };
    for (runtime_i..j, slice) |a, b| {
        _ = a;
        _ = b;
        return error.TestFailed;
    }
    return error.TestFailed;
}
// run
// backend=llvm
// target=native
