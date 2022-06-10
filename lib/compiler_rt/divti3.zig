const std = @import("std");
const builtin = @import("builtin");
const udivmod = @import("udivmod.zig").udivmod;
const arch = builtin.cpu.arch;
const is_test = builtin.is_test;
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;
pub const panic = @import("common.zig").panic;

comptime {
    if (builtin.os.tag == .windows) {
        switch (arch) {
            .i386 => {
                @export(__divti3, .{ .name = "__divti3", .linkage = linkage });
            },
            .x86_64 => {
                // The "ti" functions must use Vector(2, u64) parameter types to adhere to the ABI
                // that LLVM expects compiler-rt to have.
                @export(__divti3_windows_x86_64, .{ .name = "__divti3", .linkage = linkage });
            },
            else => {},
        }
        if (arch.isAARCH64()) {
            @export(__divti3, .{ .name = "__divti3", .linkage = linkage });
        }
    } else {
        @export(__divti3, .{ .name = "__divti3", .linkage = linkage });
    }
}

pub fn __divti3(a: i128, b: i128) callconv(.C) i128 {
    @setRuntimeSafety(builtin.is_test);

    const s_a = a >> (128 - 1);
    const s_b = b >> (128 - 1);

    const an = (a ^ s_a) -% s_a;
    const bn = (b ^ s_b) -% s_b;

    const r = udivmod(u128, @bitCast(u128, an), @bitCast(u128, bn), null);
    const s = s_a ^ s_b;
    return (@bitCast(i128, r) ^ s) -% s;
}

const v128 = @import("std").meta.Vector(2, u64);
pub fn __divti3_windows_x86_64(a: v128, b: v128) callconv(.C) v128 {
    return @bitCast(v128, @call(.{ .modifier = .always_inline }, __divti3, .{
        @bitCast(i128, a),
        @bitCast(i128, b),
    }));
}

test {
    _ = @import("divti3_test.zig");
}
