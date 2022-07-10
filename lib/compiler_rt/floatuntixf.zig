const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    const floatuntixf_fn = if (builtin.os.tag == .windows and arch == .x86_64) b: {
        // The "ti" functions must use Vector(2, u64) return types to adhere to the ABI
        // that LLVM expects compiler-rt to have.
        break :b __floatuntixf_windows_x86_64;
    } else __floatuntixf;

    @export(floatuntixf_fn, .{ .name = "__floatuntixf", .linkage = common.linkage });
}

pub fn __floatuntixf(a: u128) callconv(.C) f80 {
    return intToFloat(f80, a);
}

const v128 = @import("std").meta.Vector(2, u64);

fn __floatuntixf_windows_x86_64(a: v128) callconv(.C) f80 {
    return intToFloat(f80, @bitCast(u128, a));
}
