//! parity - if number of bits set is even => 0, else => 1
//! - pariytXi2_generic for big and little endian

const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(&__paritysi2, .{ .name = "__paritysi2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__paritydi2, .{ .name = "__paritydi2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__parityti2, .{ .name = "__parityti2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __paritysi2(a: i32) callconv(.C) i32 {
    return parityXi2(i32, a);
}

pub fn __paritydi2(a: i64) callconv(.C) i32 {
    return parityXi2(i64, a);
}

pub fn __parityti2(a: i128) callconv(.C) i32 {
    return parityXi2(i128, a);
}

inline fn parityXi2(comptime T: type, a: T) i32 {
    var x: std.meta.Int(.unsigned, @typeInfo(T).int.bits) = @bitCast(a);
    // Bit Twiddling Hacks: Compute parity in parallel
    comptime var shift: u8 = @bitSizeOf(T) / 2;
    inline while (shift > 2) {
        x ^= x >> shift;
        shift = shift >> 1;
    }
    x &= 0xf;
    return (@as(u16, 0x6996) >> @intCast(x)) & 1; // optimization for >>2 and >>1
}

test {
    _ = @import("paritysi2_test.zig");
    _ = @import("paritydi2_test.zig");
    _ = @import("parityti2_test.zig");
}
