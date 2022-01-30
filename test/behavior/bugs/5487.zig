const std = @import("std");
const builtin = @import("builtin");
const io = std.io;

pub fn write(_: void, bytes: []const u8) !usize {
    _ = bytes;
    return 0;
}
pub fn writer() io.Writer(void, @typeInfo(@typeInfo(@TypeOf(write)).Fn.return_type.?).ErrorUnion.error_set, write) {
    return io.Writer(void, @typeInfo(@typeInfo(@TypeOf(write)).Fn.return_type.?).ErrorUnion.error_set, write){ .context = {} };
}

test "crash" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    _ = io.multiWriter(.{writer()});
}
