export fn main() callconv(.C) noreturn {
    unreachable; // never gets run so it doesn't matter
}
pub fn panic(msg: []const u8, error_return_trace: ?*@import("std").builtin.StackTrace) noreturn {
    _ = msg;
    _ = error_return_trace;
    while (true) {}
}
