const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__unordtf2, .{ .name = "__unordkf2", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        // These exports are handled in cmptf2.zig because unordered comparisons
        // are based on calling _Qp_cmp.
    }
    @export(__unordtf2, .{ .name = "__unordtf2", .linkage = common.linkage, .visibility = common.visibility });
}

fn __unordtf2(a: f128, b: f128) callconv(.C) i32 {
    return comparef.unordcmp(f128, a, b);
}
