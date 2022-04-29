const std = @import("std");
const builtin = @import("builtin");
pub const io_mode = .evented;
pub fn main() !void {
    if (builtin.os.tag == .windows) {
        _ = try (std.net.StreamServer.init(.{})).accept();
    } else {
        @compileError("Unsupported OS");
    }
}

// error
// backend=stage1
// target=native
//
// error: Unsupported OS
