const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .for_len_mismatch) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

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
