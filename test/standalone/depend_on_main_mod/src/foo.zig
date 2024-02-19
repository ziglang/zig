const std = @import("std");
const assert = std.debug.assert;

pub fn run() void {
    comptime assert(@import("root") == @import("root2"));
}
