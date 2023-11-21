const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "for loop over objects with non-equal lengths")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var slice: []const u8 = "hello";
    _ = &slice;
    for (10..20, slice, 20..30) |a, b, c| {
        _ = a;
        _ = b;
        _ = c;
        return error.TestFailed;
    }
    return error.TestFailed;
}
// run
// backend=llvm
// target=native
