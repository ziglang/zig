const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "invalid enum value")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

const U = union(enum(u32)) {
    X: u8,
    Y: i8,
};

pub fn main() !void {
    var u: U = undefined;
    @memset(@ptrCast([*]u8, &u), 0x55, @sizeOf(U));
    var t: @typeInfo(U).Union.tag_type.? = u;
    var n = @tagName(t);
    _ = n;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native
