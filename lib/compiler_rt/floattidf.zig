const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    const floattidf_fn = if (builtin.os.tag == .windows and arch == .x86_64) b: {
        // The "ti" functions must use Vector(2, u64) return types to adhere to the ABI
        // that LLVM expects compiler-rt to have.
        break :b __floattidf_windows_x86_64;
    } else __floattidf;

    @export(floattidf_fn, .{ .name = "__floattidf", .linkage = common.linkage });
}

pub fn __floattidf(a: i128) callconv(.C) f64 {
    return intToFloat(f64, a);
}

const v128 = @import("std").meta.Vector(2, u64);

fn __floattidf_windows_x86_64(a: v128) callconv(.C) f64 {
    return intToFloat(f64, @bitCast(i128, a));
}
