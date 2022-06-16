const common = @import("./common.zig");
const extendf = @import("./extendf.zig").extendf;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__extendsfkf2, .{ .name = "__extendsfkf2", .linkage = common.linkage });
    } else if (common.want_sparc_abi) {
        @export(_Qp_stoq, .{ .name = "_Qp_stoq", .linkage = common.linkage });
    } else {
        @export(__extendsftf2, .{ .name = "__extendsftf2", .linkage = common.linkage });
    }
}

pub fn __extendsftf2(a: f32) callconv(.C) f128 {
    return extendf(f128, f32, @bitCast(u32, a));
}

fn __extendsfkf2(a: f32) callconv(.C) f128 {
    return extendf(f128, f32, @bitCast(u32, a));
}

fn _Qp_stoq(c: *f128, a: f32) callconv(.C) void {
    c.* = extendf(f128, f32, @bitCast(u32, a));
}
