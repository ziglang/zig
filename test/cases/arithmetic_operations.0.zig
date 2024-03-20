const std = @import("std");

pub fn main() void {
    print(2, 4);
    print(1, 7);
}

fn print(a: u32, b: u32) void {
    const str = "123456789";
    const len = a + b;
    _ = std.posix.write(1, str[0..len]) catch {};
}

// run
// target=x86_64-linux,x86_64-macos
//
// 12345612345678
