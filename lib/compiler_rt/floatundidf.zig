const builtin = @import("builtin");
const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_ul2d, .{ .name = "__aeabi_ul2d", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        if (common.want_windows_arm_abi) {
            @export(&__floatundidf, .{ .name = "__u64tod", .linkage = common.linkage, .visibility = common.visibility });
        }
        @export(&__floatundidf, .{ .name = "__floatundidf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floatundidf(a: u64) callconv(.c) f64 {
    return floatFromInt(f64, a);
}

fn __aeabi_ul2d(a: u64) callconv(.{ .arm_aapcs = .{} }) f64 {
    return floatFromInt(f64, a);
}
