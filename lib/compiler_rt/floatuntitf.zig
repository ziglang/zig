const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    const symbol_name = if (common.want_ppc_abi) "__floatuntikf" else "__floatuntitf";

    const floatuntitf_fn = if (builtin.os.tag == .windows and arch == .x86_64) b: {
        // The "ti" functions must use Vector(2, u64) return types to adhere to the ABI
        // that LLVM expects compiler-rt to have.
        break :b __floatuntitf_windows_x86_64;
    } else __floatuntitf;

    @export(floatuntitf_fn, .{ .name = symbol_name, .linkage = common.linkage });
}

pub fn __floatuntitf(a: u128) callconv(.C) f128 {
    return intToFloat(f128, a);
}

const v128 = @import("std").meta.Vector(2, u64);

fn __floatuntitf_windows_x86_64(a: v128) callconv(.C) f128 {
    return intToFloat(f128, @bitCast(u128, a));
}
