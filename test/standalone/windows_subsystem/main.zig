const std = @import("std");

pub fn main() void {
    std.debug.print("{}\n", .{std.os.windows.peb().ImageSubSystem});
}
