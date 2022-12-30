const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__fixunstfdi, .{ .name = "__fixunskfdi", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(_Qp_qtoux, .{ .name = "_Qp_qtoux", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(__fixunstfdi, .{ .name = "__fixunstfdi", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fixunstfdi(a: f128) callconv(.C) u64 {
    return floatToInt(u64, a);
}

fn _Qp_qtoux(a: *const f128) callconv(.C) u64 {
    return floatToInt(u64, a.*);
}
