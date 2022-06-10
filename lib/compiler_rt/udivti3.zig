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
                @export(__udivti3, .{ .name = "__udivti3", .linkage = linkage });
            },
            .x86_64 => {
                // The "ti" functions must use Vector(2, u64) parameter types to adhere to the ABI
                // that LLVM expects compiler-rt to have.
                @export(__udivti3_windows_x86_64, .{ .name = "__udivti3", .linkage = linkage });
            },
            else => {},
        }
        if (arch.isAARCH64()) {
            @export(__udivti3, .{ .name = "__udivti3", .linkage = linkage });
        }
    } else {
        @export(__udivti3, .{ .name = "__udivti3", .linkage = linkage });
    }
}

pub fn __udivti3(a: u128, b: u128) callconv(.C) u128 {
    @setRuntimeSafety(builtin.is_test);
    return udivmod(u128, a, b, null);
}

const v128 = std.meta.Vector(2, u64);
pub fn __udivti3_windows_x86_64(a: v128, b: v128) callconv(.C) v128 {
    @setRuntimeSafety(builtin.is_test);
    return @bitCast(v128, udivmod(u128, @bitCast(u128, a), @bitCast(u128, b), null));
}
