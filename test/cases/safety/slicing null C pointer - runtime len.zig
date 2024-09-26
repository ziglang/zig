const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .unwrap_null) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var ptr: [*c]const u32 = null;
    var len: usize = 3;
    _ = &len;
    const slice = ptr[0..len];
    _ = slice;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native
