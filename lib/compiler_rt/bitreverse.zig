const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(&__bitreversesi2, .{ .name = "__bitreversesi2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__bitreversedi2, .{ .name = "__bitreversedi2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__bitreverseti2, .{ .name = "__bitreverseti2", .linkage = common.linkage, .visibility = common.visibility });
}

inline fn bitreverseXi2(comptime T: type, a: T) T {
    switch (@bitSizeOf(T)) {
        32 => {
            var t: T = a;
            t = ((t >> 1) & 0x55555555) | ((t & 0x55555555) << 1);
            t = ((t >> 2) & 0x33333333) | ((t & 0x33333333) << 2);
            t = ((t >> 4) & 0x0F0F0F0F) | ((t & 0x0F0F0F0F) << 4);
            t = ((t >> 8) & 0x00FF00FF) | ((t & 0x00FF00FF) << 8);
            t = (t >> 16) | (t << 16);
            return t;
        },
        64 => {
            var t: T = a;
            t = ((t >> 1) & 0x5555555555555555) | ((t & 0x5555555555555555) << 1);
            t = ((t >> 2) & 0x3333333333333333) | ((t & 0x3333333333333333) << 2);
            t = ((t >> 4) & 0x0F0F0F0F0F0F0F0F) | ((t & 0x0F0F0F0F0F0F0F0F) << 4);
            t = ((t >> 8) & 0x00FF00FF00FF00FF) | ((t & 0x00FF00FF00FF00FF) << 8);
            t = ((t >> 16) & 0x0000FFFF0000FFFF) | ((t & 0x0000FFFF0000FFFF) << 16);
            t = (t >> 32) | (t << 32);
            return t;
        },
        128 => {
            var t: T = a;
            t = ((t >> 1) & 0x55555555555555555555555555555555) | ((t & 0x55555555555555555555555555555555) << 1);
            t = ((t >> 2) & 0x33333333333333333333333333333333) | ((t & 0x33333333333333333333333333333333) << 2);
            t = ((t >> 4) & 0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) | ((t & 0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) << 4);
            t = ((t >> 8) & 0x00FF00FF00FF00FF00FF00FF00FF00FF) | ((t & 0x00FF00FF00FF00FF00FF00FF00FF00FF) << 8);
            t = ((t >> 16) & 0x0000FFFF0000FFFF0000FFFF0000FFFF) | ((t & 0x0000FFFF0000FFFF0000FFFF0000FFFF) << 16);
            t = ((t >> 32) & 0x00000000FFFFFFFF00000000FFFFFFFF) | ((t & 0x00000000FFFFFFFF00000000FFFFFFFF) << 32);
            t = (t >> 64) | (t << 64);
            return t;
        },
        else => unreachable,
    }
}

pub fn __bitreversesi2(a: u32) callconv(.C) u32 {
    return bitreverseXi2(u32, a);
}

pub fn __bitreversedi2(a: u64) callconv(.C) u64 {
    return bitreverseXi2(u64, a);
}

pub fn __bitreverseti2(a: u128) callconv(.C) u128 {
    return bitreverseXi2(u128, a);
}

test {
    _ = @import("bitreversesi2_test.zig");
    _ = @import("bitreversedi2_test.zig");
    _ = @import("bitreverseti2_test.zig");
}
