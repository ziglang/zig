//! Ported from:
//!
//! https://github.com/llvm/llvm-project/blob/2ffb1b0413efa9a24eb3c49e710e36f92e2cb50b/compiler-rt/lib/builtins/modti3.c

const std = @import("std");
const builtin = @import("builtin");
const udivmod = @import("udivmod.zig").udivmod;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__modti3_windows_x86_64, .{ .name = "__modti3", .linkage = common.linkage });
    } else {
        @export(__modti3, .{ .name = "__modti3", .linkage = common.linkage });
    }
}

pub fn __modti3(a: i128, b: i128) callconv(.C) i128 {
    return mod(a, b);
}

const v2u64 = @Vector(2, u64);

fn __modti3_windows_x86_64(a: v2u64, b: v2u64) callconv(.C) v2u64 {
    return @bitCast(v2u64, mod(@bitCast(i128, a), @bitCast(i128, b)));
}

inline fn mod(a: i128, b: i128) i128 {
    const s_a = a >> (128 - 1); // s = a < 0 ? -1 : 0
    const s_b = b >> (128 - 1); // s = b < 0 ? -1 : 0

    const an = (a ^ s_a) -% s_a; // negate if s == -1
    const bn = (b ^ s_b) -% s_b; // negate if s == -1

    var r: u128 = undefined;
    _ = udivmod(u128, @bitCast(u128, an), @bitCast(u128, bn), &r);
    return (@bitCast(i128, r) ^ s_a) -% s_a; // negate if s == -1
}

test {
    _ = @import("modti3_test.zig");
}
