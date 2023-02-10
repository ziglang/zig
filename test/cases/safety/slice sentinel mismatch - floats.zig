const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "sentinel mismatch: expected 1.20000004e+00, found 4.0e+00")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var buf: [4]f32 = .{ 1, 2, 3, 4 };
    const slice = buf[0..3 :1.2];
    _ = slice;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native
