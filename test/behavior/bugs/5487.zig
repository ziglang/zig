const io = @import("std").io;
const builtin = @import("builtin");

pub fn write(_: void, bytes: []const u8) !usize {
    _ = bytes;
    return 0;
}
pub fn writer() io.Writer(void, @typeInfo(@typeInfo(@TypeOf(write)).Fn.return_type.?).ErrorUnion.error_set, write) {
    return io.Writer(void, @typeInfo(@typeInfo(@TypeOf(write)).Fn.return_type.?).ErrorUnion.error_set, write){ .context = {} };
}

test "crash" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    _ = io.multiWriter(.{writer()});
}
