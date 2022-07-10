const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    const fixunshfti_fn = if (builtin.os.tag == .windows and arch == .x86_64) b: {
        // The "ti" functions must use Vector(2, u64) return types to adhere to the ABI
        // that LLVM expects compiler-rt to have.
        break :b __fixunshfti_windows_x86_64;
    } else __fixunshfti;

    @export(fixunshfti_fn, .{ .name = "__fixunshfti", .linkage = common.linkage });
}

pub fn __fixunshfti(a: f16) callconv(.C) u128 {
    return floatToInt(u128, a);
}

const v128 = @import("std").meta.Vector(2, u64);

fn __fixunshfti_windows_x86_64(a: f16) callconv(.C) v128 {
    return @bitCast(v128, floatToInt(u128, a));
}
