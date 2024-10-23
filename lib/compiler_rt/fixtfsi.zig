const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(&__fixtfsi, .{ .name = "__fixkfsi", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(&_Qp_qtoi, .{ .name = "_Qp_qtoi", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&__fixtfsi, .{ .name = "__fixtfsi", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fixtfsi(a: f128) callconv(.C) i32 {
    return intFromFloat(i32, a);
}

fn _Qp_qtoi(a: *const f128) callconv(.C) i32 {
    return intFromFloat(i32, a.*);
}
