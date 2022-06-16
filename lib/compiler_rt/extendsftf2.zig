const common = @import("./common.zig");
const extendf = @import("./extendf.zig").extendf;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__extendsfkf2, .{ .name = "__extendsfkf2", .linkage = common.linkage });
    } else {
        @export(__extendsftf2, .{ .name = "__extendsftf2", .linkage = common.linkage });
    }
}

fn __extendsftf2(a: f32) callconv(.C) f128 {
    return extendf(f128, f32, @bitCast(u32, a));
}

fn __extendsfkf2(a: f32) callconv(.C) f128 {
    return extendf(f128, f32, @bitCast(u32, a));
}
