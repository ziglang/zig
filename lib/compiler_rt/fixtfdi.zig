const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(&__fixtfdi, .{ .name = "__fixkfdi", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(&_Qp_qtox, .{ .name = "_Qp_qtox", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&__fixtfdi, .{ .name = "__fixtfdi", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fixtfdi(a: f128) callconv(.C) i64 {
    return intFromFloat(i64, a);
}

fn _Qp_qtox(a: *const f128) callconv(.C) i64 {
    return intFromFloat(i64, a.*);
}
