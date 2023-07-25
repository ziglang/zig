const std = @import("std");
const mem = std.mem;
const testing = std.testing;

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn leftpad(alloc: mem.Allocator, str: []const u8, len: usize, ch: u8) ![]const u8 {
    const pad: []u8 = try alloc.alloc(u8, len);
    defer alloc.free(pad);
    @memset(pad, ch);
    const padded = mem.concat(alloc, u8, &[_][]const u8{
        pad, str,
    });

    return padded;
}

test leftpad {
    const input = "instr";
    const output = try leftpad(std.testing.allocator, input, 4, ' ');
    defer std.testing.allocator.free(output);

    try std.testing.expectEqualStrings("    instr", output);
}
