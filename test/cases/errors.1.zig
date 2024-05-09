const std = @import("std");

pub fn main() void {
    foo() catch print();
}

fn foo() anyerror!void {
    return error.Test;
}

fn print() void {
    _ = std.posix.write(1, "Hello, World!\n") catch {};
}

// run
//
// Hello, World!
//
