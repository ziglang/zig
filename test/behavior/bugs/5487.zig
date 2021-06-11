const io = @import("std").io;

pub fn write(_: void, bytes: []const u8) !usize {
    return 0;
}
pub fn writer() io.Writer(void, @typeInfo(@typeInfo(@TypeOf(write)).Fn.return_type.?).ErrorUnion.error_set, write) {
    return io.Writer(void, @typeInfo(@typeInfo(@TypeOf(write)).Fn.return_type.?).ErrorUnion.error_set, write){ .context = {} };
}

test "crash" {
    _ = io.multiWriter(.{writer()});
}
