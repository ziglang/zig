//! negv - negate oVerflow
//! * @panic, if result can not be represented
//! - negvXi4_generic for unoptimized version
const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(&__negvsi2, .{ .name = "__negvsi2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__negvdi2, .{ .name = "__negvdi2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__negvti2, .{ .name = "__negvti2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __negvsi2(a: i32) callconv(.C) i32 {
    return negvXi(i32, a);
}

pub fn __negvdi2(a: i64) callconv(.C) i64 {
    return negvXi(i64, a);
}

pub fn __negvti2(a: i128) callconv(.C) i128 {
    return negvXi(i128, a);
}

inline fn negvXi(comptime ST: type, a: ST) ST {
    const UT = switch (ST) {
        i32 => u32,
        i64 => u64,
        i128 => u128,
        else => unreachable,
    };
    const N: UT = @bitSizeOf(ST);
    const min: ST = @as(ST, @bitCast((@as(UT, 1) << (N - 1))));
    if (a == min)
        @panic("compiler_rt negv: overflow");
    return -a;
}

test {
    _ = @import("negvsi2_test.zig");
    _ = @import("negvdi2_test.zig");
    _ = @import("negvti2_test.zig");
}
