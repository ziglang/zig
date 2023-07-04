const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "@log2 received zero integer argument")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var x: u32 = undefined;
    x = 0;
    _ = @log2(x);
    return error.TestFailed;
}

// run
// backend=llvm
// target=native
