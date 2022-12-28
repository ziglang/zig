const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__fixunstfsi, .{ .name = "__fixunskfsi", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(_Qp_qtoui, .{ .name = "_Qp_qtoui", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(__fixunstfsi, .{ .name = "__fixunstfsi", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fixunstfsi(a: f128) callconv(.C) u32 {
    return floatToInt(u32, a);
}

fn _Qp_qtoui(a: *const f128) callconv(.C) u32 {
    return floatToInt(u32, a.*);
}
