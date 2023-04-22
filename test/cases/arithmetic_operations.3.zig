const std = @import("std");

pub fn main() void {
    print(4, 2);
    print(3, 7);
}

fn print(a: u32, b: u32) void {
    const str = "123456789";
    const len = a | b;
    _ = std.os.write(1, str[0..len]) catch {};
}

// run
//
// 1234561234567
