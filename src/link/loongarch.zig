const std = @import("std");
const mem = std.mem;

pub fn page(val: u64) u64 {
    return val & ~0xfff;
}

pub fn hi20(val: u64, pc: u64) i20 {
    return @bitCast(@as(i20, @truncate((@as(i64, @intCast(val)) - @as(i64, @intCast(pc)) + 0x800) >> 12)));
}

pub fn lo12(val: u64, pc: u64) i12 {
    return @bitCast(@as(i12, @truncate((@as(i64, @intCast(val)) - @as(i64, @intCast(pc))) & 0xfff)));
}
