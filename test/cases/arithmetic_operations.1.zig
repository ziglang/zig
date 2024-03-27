const std = @import("std");

pub fn main() void {
    print(10, 5);
    print(4, 3);
}

fn print(a: u32, b: u32) void {
    const str = "123456789";
    const len = a - b;
    _ = std.posix.write(1, str[0..len]) catch {};
}

// run
//
// 123451
