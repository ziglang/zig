const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__fixtfdi, .{ .name = "__fixkfdi", .linkage = common.linkage });
    } else if (common.want_sparc_abi) {
        @export(_Qp_qtox, .{ .name = "_Qp_qtox", .linkage = common.linkage });
    }
    @export(__fixtfdi, .{ .name = "__fixtfdi", .linkage = common.linkage });
}

pub fn __fixtfdi(a: f128) callconv(.C) i64 {
    return floatToInt(i64, a);
}

fn _Qp_qtox(a: *const f128) callconv(.C) i64 {
    return floatToInt(i64, a.*);
}
