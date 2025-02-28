const std = @import("std");
const builtin = @import("builtin");
const udivmod = @import("udivmod.zig").udivmod;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(&__udivti3_windows_x86_64, .{ .name = "__udivti3", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__udivti3, .{ .name = "__udivti3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __udivti3(a: u128, b: u128) callconv(.C) u128 {
    return udivmod(u128, a, b, null);
}

const v2u64 = @Vector(2, u64);

fn __udivti3_windows_x86_64(a: v2u64, b: v2u64) callconv(.C) v2u64 {
    return @bitCast(udivmod(u128, @bitCast(a), @bitCast(b), null));
}
