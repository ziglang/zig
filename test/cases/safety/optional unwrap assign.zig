const std = @import("std");

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    if (std.mem.eql(u8, message, "attempt to use null value")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    var foo: ?u8 = null;
    foo.? = 10; // should fail, since foo is null.
    return error.TestFailed;
}
// run
// backend=selfhosted,llvm
// target=x86_64-linux
