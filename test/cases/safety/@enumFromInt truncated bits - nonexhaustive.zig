const std = @import("std");

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    if (std.mem.eql(u8, message, "invalid enum value")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() u8 {
    var num: u8 = undefined;
    num = 250;

    const E = enum(u6) { _ };
    const invalid: E = @enumFromInt(num);
    _ = invalid;

    return 1;
}

// run
// backend=llvm
// target=native
