const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__fixkfsi, .{ .name = "__fixkfsi", .linkage = common.linkage });
    } else if (common.want_sparc_abi) {
        @export(_Qp_qtoi, .{ .name = "_Qp_qtoi", .linkage = common.linkage });
    } else {
        @export(__fixtfsi, .{ .name = "__fixtfsi", .linkage = common.linkage });
    }
}

pub fn __fixtfsi(a: f128) callconv(.C) i32 {
    return floatToInt(i32, a);
}

fn __fixkfsi(a: f128) callconv(.C) i32 {
    return floatToInt(i32, a);
}

fn _Qp_qtoi(a: *const f128) callconv(.C) i32 {
    return floatToInt(i32, a.*);
}
