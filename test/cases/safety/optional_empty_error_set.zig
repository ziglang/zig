const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    _ = stack_trace;
    _ = ra;
    if (std.mem.eql(u8, message, "attempt to use null value")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    foo() catch |err| switch (err) {};
    return error.TestFailed;
}
var x: ?error{} = null;
fn foo() !void {
    return x.?;
}
// run
// backend=selfhosted,llvm
// target=x86_64-linux,aarch64-linux
