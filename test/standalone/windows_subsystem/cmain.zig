const std = @import("std");

pub export fn main() callconv(.c) c_int {
    std.debug.print("{}\n", .{std.os.windows.peb().ImageSubSystem});
    return 0;
}
