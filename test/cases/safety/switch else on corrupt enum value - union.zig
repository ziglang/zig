const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "switch on corrupt value")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
const E = enum(u16) {
    one = 1,
    two = 2,
    _,
};
const U = union(E) {
    one: u16,
    two: u16,
};
pub fn main() !void {
    var a: U = undefined;
    @as(*align(@alignOf(U)) u32, @ptrCast(&a)).* = 0xFFFF_FFFF;
    switch (a) {
        .one => @panic("one"),
        else => @panic("else"),
    }
}
// run
// backend=llvm
// target=native
