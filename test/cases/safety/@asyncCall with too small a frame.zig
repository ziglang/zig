const std = @import("std");
const builtin = @import("builtin");

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
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    if (builtin.zig_backend == .stage1 and builtin.os.tag == .wasi) {
        // TODO file a bug for this failure
        std.process.exit(0); // skip the test
    }
    var bytes: [1]u8 align(16) = undefined;
    var ptr = other;
    _ = &ptr;
    var frame = @asyncCall(&bytes, {}, ptr, .{});
    _ = &frame;
    return error.TestFailed;
}
fn other() callconv(.Async) void {
    suspend {}
}
// run
// backend=stage1
// target=native
