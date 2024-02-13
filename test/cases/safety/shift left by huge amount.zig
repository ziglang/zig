const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "shift amount is greater than the type size")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var x: u24 = 42;
    var y: u5 = 24;
    _ = .{ &x, &y };
    const z = x >> y;
    _ = z;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native
