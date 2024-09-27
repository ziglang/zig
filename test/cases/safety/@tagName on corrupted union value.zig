const std = @import("std");

pub const Panic = struct {
    pub const call = panic;
    pub const unwrapError = std.debug.FormattedPanic.unwrapError;
    pub const outOfBounds = std.debug.FormattedPanic.outOfBounds;
    pub const startGreaterThanEnd = std.debug.FormattedPanic.startGreaterThanEnd;
    pub const sentinelMismatch = std.debug.FormattedPanic.sentinelMismatch;
    pub const inactiveUnionField = std.debug.FormattedPanic.inactiveUnionField;
    pub const messages = std.debug.FormattedPanic.messages;
};

fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
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
    @memset(@as([*]u8, @ptrCast(&u))[0..@sizeOf(U)], 0x55);
    const t: @typeInfo(U).@"union".tag_type.? = u;
    const n = @tagName(t);
    _ = n;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native
