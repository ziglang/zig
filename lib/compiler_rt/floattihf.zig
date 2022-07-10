const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    const floattihf_fn = if (builtin.os.tag == .windows and arch == .x86_64) b: {
        // The "ti" functions must use Vector(2, u64) return types to adhere to the ABI
        // that LLVM expects compiler-rt to have.
        break :b __floattihf_windows_x86_64;
    } else __floattihf;

    @export(floattihf_fn, .{ .name = "__floattihf", .linkage = common.linkage });
}

pub fn __floattihf(a: i128) callconv(.C) f16 {
    return intToFloat(f16, a);
}

const v128 = @import("std").meta.Vector(2, u64);

fn __floattihf_windows_x86_64(a: v128) callconv(.C) f16 {
    return intToFloat(f16, @bitCast(i128, a));
}
