const std = @import("std");

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    if (std.mem.eql(u8, message, "invalid enum value")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() void {
    const E = enum(u4) { _ };
    var invalid: u16 = 16;
    _ = &invalid;
    _ = @as(E, @enumFromInt(invalid));
    std.process.exit(1);
}

// run
// backend=stage2,llvm
// target=native
