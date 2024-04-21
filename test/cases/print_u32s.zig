const std = @import("std");

pub fn main() void {
    printNumberHex(0x00000000);
    printNumberHex(0xaaaaaaaa);
    printNumberHex(0xdeadbeef);
    printNumberHex(0x31415926);
}

fn printNumberHex(x: u32) void {
    const digit_chars = "0123456789abcdef";
    var i: u5 = 28;
    while (true) : (i -= 4) {
        const digit = (x >> i) & 0xf;
        _ = std.posix.write(1, &.{digit_chars[digit]}) catch {};
        if (i == 0) break;
    }
    _ = std.posix.write(1, "\n") catch {};
}

// run
// target=x86_64-macos
//
// 00000000
// aaaaaaaa
// deadbeef
// 31415926
//
