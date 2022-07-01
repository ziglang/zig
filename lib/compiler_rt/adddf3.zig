const common = @import("./common.zig");
const addf3 = @import("./addf3.zig").addf3;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_dadd, .{ .name = "__aeabi_dadd", .linkage = common.linkage });
    } else {
        @export(__adddf3, .{ .name = "__adddf3", .linkage = common.linkage });
    }
}

fn __adddf3(a: f64, b: f64) callconv(.C) f64 {
    return addf3(f64, a, b);
}

fn __aeabi_dadd(a: f64, b: f64) callconv(.AAPCS) f64 {
    return addf3(f64, a, b);
}
