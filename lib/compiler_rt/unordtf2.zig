const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__unordkf2, .{ .name = "__unordkf2", .linkage = common.linkage });
    } else if (common.want_sparc_abi) {
        // These exports are handled in cmptf2.zig because unordered comparisons
        // are based on calling _Qp_cmp.
    } else {
        @export(__unordtf2, .{ .name = "__unordtf2", .linkage = common.linkage });
    }
}

fn __unordtf2(a: f128, b: f128) callconv(.C) i32 {
    return comparef.unordcmp(f128, a, b);
}

fn __unordkf2(a: f128, b: f128) callconv(.C) i32 {
    return comparef.unordcmp(f128, a, b);
}
