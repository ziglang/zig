const std = @import("std");
const C = @cImport({
    @cInclude("single_file_library.h");
});

pub fn main() !void {
    const msg = "hello";
    const val = C.tstlib_len(msg);
    if (val != msg.len)
        std.process.exit(1);
}
