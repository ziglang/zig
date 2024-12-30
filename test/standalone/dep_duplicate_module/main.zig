const std = @import("std");
const mod = @import("mod");

extern fn work(x: u32) u32;

pub fn main() !void {
    _ = work(mod.half(25));
}
