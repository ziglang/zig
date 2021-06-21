export fn main(r0: u32, r1: u32, atags: u32) callconv(.C) noreturn {
    _ = r0;
    _ = r1;
    _ = atags;
    unreachable; // never gets run so it doesn't matter
}
pub fn panic(msg: []const u8, error_return_trace: ?*@import("std").builtin.StackTrace) noreturn {
    _ = msg;
    _ = error_return_trace;
    while (true) {}
}
