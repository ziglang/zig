const std = @import("std");
const builtin = @import("builtin");
const udivmod = @import("udivmod.zig").udivmod;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__udivmodti4_windows_x86_64, .{ .name = "__udivmodti4", .linkage = common.linkage });
    } else {
        @export(__udivmodti4, .{ .name = "__udivmodti4", .linkage = common.linkage });
    }
}

pub fn __udivmodti4(a: u128, b: u128, maybe_rem: ?*u128) callconv(.C) u128 {
    return udivmod(u128, a, b, maybe_rem);
}

const v2u64 = @Vector(2, u64);

fn __udivmodti4_windows_x86_64(a: v2u64, b: v2u64, maybe_rem: ?*u128) callconv(.C) v2u64 {
    return @bitCast(v2u64, udivmod(u128, @bitCast(u128, a), @bitCast(u128, b), maybe_rem));
}

test {
    _ = @import("udivmodti4_test.zig");
}
