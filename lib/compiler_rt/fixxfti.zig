const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    const fixxfti_fn = if (builtin.os.tag == .windows and arch == .x86_64) b: {
        // The "ti" functions must use Vector(2, u64) return types to adhere to the ABI
        // that LLVM expects compiler-rt to have.
        break :b __fixxfti_windows_x86_64;
    } else __fixxfti;

    @export(fixxfti_fn, .{ .name = "__fixxfti", .linkage = common.linkage });
}

pub fn __fixxfti(a: f80) callconv(.C) i128 {
    return floatToInt(i128, a);
}

const v128 = @import("std").meta.Vector(2, u64);

fn __fixxfti_windows_x86_64(a: f80) callconv(.C) v128 {
    return @bitCast(v128, floatToInt(i128, a));
}
