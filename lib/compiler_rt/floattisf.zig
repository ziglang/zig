const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    const floattisf_fn = if (builtin.os.tag == .windows and arch == .x86_64) b: {
        // The "ti" functions must use Vector(2, u64) return types to adhere to the ABI
        // that LLVM expects compiler-rt to have.
        break :b __floattisf_windows_x86_64;
    } else __floattisf;

    @export(floattisf_fn, .{ .name = "__floattisf", .linkage = common.linkage });
}

pub fn __floattisf(a: i128) callconv(.C) f32 {
    return intToFloat(f32, a);
}

const v128 = @import("std").meta.Vector(2, u64);

fn __floattisf_windows_x86_64(a: v128) callconv(.C) f32 {
    return intToFloat(f32, @bitCast(i128, a));
}
