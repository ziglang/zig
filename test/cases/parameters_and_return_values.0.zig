const std = @import("std");

pub fn main() void {
    print(id(14));
}

fn id(x: u32) u32 {
    return x;
}

fn print(len: u32) void {
    const str = "Hello, World!\n";
    _ = std.posix.write(1, str[0..len]) catch {};
}

// run
// target=x86_64-macos
//
// Hello, World!
//
