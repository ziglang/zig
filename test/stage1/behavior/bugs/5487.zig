const io = @import("std").io;

pub fn write(_: void, bytes: []const u8) !usize {
    return 0;
}
pub fn outStream() io.OutStream(void, @TypeOf(write).ReturnType.ErrorSet, write) {
    return io.OutStream(void, @TypeOf(write).ReturnType.ErrorSet, write){ .context = {} };
}

test "crash" {
    _ = io.multiOutStream(.{outStream()});
}
