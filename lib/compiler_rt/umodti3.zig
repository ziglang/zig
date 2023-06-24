const std = @import("std");
const builtin = @import("builtin");
const udivmod = @import("udivmod.zig").udivmod;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__umodti3_windows_x86_64, .{ .name = "__umodti3", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__umodti3, .{ .name = "__umodti3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __umodti3(a: u128, b: u128) callconv(.C) u128 {
    var r: u128 = undefined;
    _ = udivmod(u128, a, b, &r);
    return r;
}

const v2u64 = @Vector(2, u64);

fn __umodti3_windows_x86_64(a: v2u64, b: v2u64) callconv(.C) v2u64 {
    var r: u128 = undefined;
    _ = udivmod(u128, @as(u128, @bitCast(a)), @as(u128, @bitCast(b)), &r);
    return @as(v2u64, @bitCast(r));
}
