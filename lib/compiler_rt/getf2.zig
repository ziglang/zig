///! The quoted behavior definitions are from
///! https://gcc.gnu.org/onlinedocs/gcc-12.1.0/gccint/Soft-float-library-routines.html#Soft-float-library-routines
const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(&__getf2, .{ .name = "__gekf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__gttf2, .{ .name = "__gtkf2", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        // These exports are handled in cmptf2.zig because gt and ge on sparc
        // are based on calling _Qp_cmp.
    }
    @export(&__getf2, .{ .name = "__getf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__gttf2, .{ .name = "__gttf2", .linkage = common.linkage, .visibility = common.visibility });
}

/// "These functions return a value greater than or equal to zero if neither
/// argument is NaN, and a is greater than or equal to b."
fn __getf2(a: f128, b: f128) callconv(.C) i32 {
    return @intFromEnum(comparef.cmpf2(f128, comparef.GE, a, b));
}

/// "These functions return a value greater than zero if neither argument is NaN,
/// and a is strictly greater than b."
fn __gttf2(a: f128, b: f128) callconv(.C) i32 {
    return __getf2(a, b);
}
