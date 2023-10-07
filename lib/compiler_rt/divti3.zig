const std = @import("std");
const builtin = @import("builtin");
const udivmod = @import("udivmod.zig").udivmod;
const arch = builtin.cpu.arch;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__divti3_windows_x86_64, .{ .name = "__divti3", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__divti3, .{ .name = "__divti3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __divti3(a: i128, b: i128) callconv(.C) i128 {
    return div(a, b);
}

const v128 = @Vector(2, u64);

fn __divti3_windows_x86_64(a: v128, b: v128) callconv(.C) v128 {
    return @bitCast(div(@bitCast(a), @bitCast(b)));
}

inline fn div(a: i128, b: i128) i128 {
    const s_a = a >> (128 - 1);
    const s_b = b >> (128 - 1);

    const an = (a ^ s_a) -% s_a;
    const bn = (b ^ s_b) -% s_b;

    const r = udivmod(u128, @bitCast(an), @bitCast(bn), null);
    const s = s_a ^ s_b;
    return (@as(i128, @bitCast(r)) ^ s) -% s;
}

test {
    _ = @import("divti3_test.zig");
}
