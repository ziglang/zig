const common = @import("./common.zig");
const extendf = @import("./extendf.zig").extendf;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__extenddfkf2, .{ .name = "__extenddfkf2", .linkage = common.linkage });
    } else if (common.want_sparc_abi) {
        @export(_Qp_dtoq, .{ .name = "_Qp_dtoq", .linkage = common.linkage });
    } else {
        @export(__extenddftf2, .{ .name = "__extenddftf2", .linkage = common.linkage });
    }
}

pub fn __extenddftf2(a: f64) callconv(.C) f128 {
    return extendf(f128, f64, @bitCast(u64, a));
}

fn __extenddfkf2(a: f64) callconv(.C) f128 {
    return extendf(f128, f64, @bitCast(u64, a));
}

fn _Qp_dtoq(c: *f128, a: f64) callconv(.C) void {
    c.* = extendf(f128, f64, @bitCast(u64, a));
}
