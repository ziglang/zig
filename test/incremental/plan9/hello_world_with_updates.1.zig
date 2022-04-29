const std = @import("std");
pub fn main() void {
    const str = "Hello World!\n";
    _ = std.os.plan9.pwrite(1, str, str.len, 0);
}

// run
//
// Hello World
//
