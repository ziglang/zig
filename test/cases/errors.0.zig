const std = @import("std");

pub fn main() void {
    foo() catch print();
}

fn foo() anyerror!void {}

fn print() void {
    _ = std.posix.write(1, "Hello, World!\n") catch {};
}

// run
// target=x86_64-macos
//
