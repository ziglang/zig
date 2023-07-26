const std = @import("std");
const mod = @import("mod");

pub fn main() void {
    std.debug.print("{d}\n", .{mod.add(9, 10)});
}
