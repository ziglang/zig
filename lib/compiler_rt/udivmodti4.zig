const std = @import("std");
const builtin = @import("builtin");
const udivmod = @import("udivmod.zig").udivmod;
const arch = builtin.cpu.arch;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    if (builtin.os.tag == .windows) {
        switch (arch) {
            .i386 => {
                @export(__udivmodti4, .{ .name = "__udivmodti4", .linkage = common.linkage });
            },
            .x86_64 => {
                // The "ti" functions must use Vector(2, u64) parameter types to adhere to the ABI
                // that LLVM expects compiler-rt to have.
                @export(__udivmodti4_windows_x86_64, .{ .name = "__udivmodti4", .linkage = common.linkage });
            },
            else => {},
        }
    } else {
        @export(__udivmodti4, .{ .name = "__udivmodti4", .linkage = common.linkage });
    }
}

pub fn __udivmodti4(a: u128, b: u128, maybe_rem: ?*u128) callconv(.C) u128 {
    return udivmod(u128, a, b, maybe_rem);
}

const v128 = std.meta.Vector(2, u64);

fn __udivmodti4_windows_x86_64(a: v128, b: v128, maybe_rem: ?*u128) callconv(.C) v128 {
    return @bitCast(v128, udivmod(u128, @bitCast(u128, a), @bitCast(u128, b), maybe_rem));
}

test {
    _ = @import("udivmodti4_test.zig");
}
