const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    const fixsfti_fn = if (builtin.os.tag == .windows and arch == .x86_64) b: {
        // The "ti" functions must use Vector(2, u64) return types to adhere to the ABI
        // that LLVM expects compiler-rt to have.
        break :b __fixsfti_windows_x86_64;
    } else __fixsfti;

    @export(fixsfti_fn, .{ .name = "__fixsfti", .linkage = common.linkage });
}

pub fn __fixsfti(a: f32) callconv(.C) i128 {
    return floatToInt(i128, a);
}

const v128 = @import("std").meta.Vector(2, u64);

fn __fixsfti_windows_x86_64(a: f32) callconv(.C) v128 {
    return @bitCast(v128, floatToInt(i128, a));
}
