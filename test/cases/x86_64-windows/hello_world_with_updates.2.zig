const std = @import("std");

pub fn main() void {
    print();
}

fn print() void {
    const msg = "Hello, World!\n";
    const stdout = std.io.getStdOut();
    stdout.writeAll(msg) catch unreachable;
}

// run
//
// Hello, World!
//
