///! The quoted behavior definitions are from
///! https://gcc.gnu.org/onlinedocs/gcc-12.1.0/gccint/Soft-float-library-routines.html#Soft-float-library-routines
const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__eqkf2, .{ .name = "__eqkf2", .linkage = common.linkage });
        @export(__nekf2, .{ .name = "__nekf2", .linkage = common.linkage });
        @export(__ltkf2, .{ .name = "__ltkf2", .linkage = common.linkage });
        @export(__lekf2, .{ .name = "__lekf2", .linkage = common.linkage });
    } else {
        @export(__eqtf2, .{ .name = "__eqtf2", .linkage = common.linkage });
        @export(__netf2, .{ .name = "__netf2", .linkage = common.linkage });
        @export(__letf2, .{ .name = "__letf2", .linkage = common.linkage });
        @export(__cmptf2, .{ .name = "__cmptf2", .linkage = common.linkage });
        @export(__lttf2, .{ .name = "__lttf2", .linkage = common.linkage });
    }
}

/// "These functions calculate a <=> b. That is, if a is less than b, they return -1;
/// if a is greater than b, they return 1; and if a and b are equal they return 0.
/// If either argument is NaN they return 1..."
///
/// Note that this matches the definition of `__letf2`, `__eqtf2`, `__netf2`, `__cmptf2`,
/// and `__lttf2`.
fn __cmptf2(a: f128, b: f128) callconv(.C) i32 {
    return @enumToInt(comparef.cmpf2(f128, comparef.LE, a, b));
}

/// "These functions return a value less than or equal to zero if neither argument is NaN,
/// and a is less than or equal to b."
fn __letf2(a: f128, b: f128) callconv(.C) i32 {
    return __cmptf2(a, b);
}

/// "These functions return zero if neither argument is NaN, and a and b are equal."
/// Note that due to some kind of historical accident, __eqtf2 and __netf2 are defined
/// to have the same return value.
fn __eqtf2(a: f128, b: f128) callconv(.C) i32 {
    return __cmptf2(a, b);
}

/// "These functions return a nonzero value if either argument is NaN, or if a and b are unequal."
/// Note that due to some kind of historical accident, __eqtf2 and __netf2 are defined
/// to have the same return value.
fn __netf2(a: f128, b: f128) callconv(.C) i32 {
    return __cmptf2(a, b);
}

/// "These functions return a value less than zero if neither argument is NaN, and a
/// is strictly less than b."
fn __lttf2(a: f128, b: f128) callconv(.C) i32 {
    return __cmptf2(a, b);
}

fn __eqkf2(a: f128, b: f128) callconv(.C) i32 {
    return __cmptf2(a, b);
}

fn __nekf2(a: f128, b: f128) callconv(.C) i32 {
    return __cmptf2(a, b);
}

fn __ltkf2(a: f128, b: f128) callconv(.C) i32 {
    return __cmptf2(a, b);
}

fn __lekf2(a: f128, b: f128) callconv(.C) i32 {
    return __cmptf2(a, b);
}
