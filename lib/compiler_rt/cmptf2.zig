///! The quoted behavior definitions are from
///! https://gcc.gnu.org/onlinedocs/gcc-12.1.0/gccint/Soft-float-library-routines.html#Soft-float-library-routines
const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__eqtf2, .{ .name = "__eqkf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(__netf2, .{ .name = "__nekf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(__lttf2, .{ .name = "__ltkf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(__letf2, .{ .name = "__lekf2", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(_Qp_cmp, .{ .name = "_Qp_cmp", .linkage = common.linkage, .visibility = common.visibility });
        @export(_Qp_feq, .{ .name = "_Qp_feq", .linkage = common.linkage, .visibility = common.visibility });
        @export(_Qp_fne, .{ .name = "_Qp_fne", .linkage = common.linkage, .visibility = common.visibility });
        @export(_Qp_flt, .{ .name = "_Qp_flt", .linkage = common.linkage, .visibility = common.visibility });
        @export(_Qp_fle, .{ .name = "_Qp_fle", .linkage = common.linkage, .visibility = common.visibility });
        @export(_Qp_fgt, .{ .name = "_Qp_fgt", .linkage = common.linkage, .visibility = common.visibility });
        @export(_Qp_fge, .{ .name = "_Qp_fge", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(__eqtf2, .{ .name = "__eqtf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(__netf2, .{ .name = "__netf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(__letf2, .{ .name = "__letf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(__cmptf2, .{ .name = "__cmptf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(__lttf2, .{ .name = "__lttf2", .linkage = common.linkage, .visibility = common.visibility });
}

/// "These functions calculate a <=> b. That is, if a is less than b, they return -1;
/// if a is greater than b, they return 1; and if a and b are equal they return 0.
/// If either argument is NaN they return 1..."
///
/// Note that this matches the definition of `__letf2`, `__eqtf2`, `__netf2`, `__cmptf2`,
/// and `__lttf2`.
fn __cmptf2(a: f128, b: f128) callconv(.C) i32 {
    return @intFromEnum(comparef.cmpf2(f128, comparef.LE, a, b));
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

const SparcFCMP = enum(i32) {
    Equal = 0,
    Less = 1,
    Greater = 2,
    Unordered = 3,
};

fn _Qp_cmp(a: *const f128, b: *const f128) callconv(.C) i32 {
    return @intFromEnum(comparef.cmpf2(f128, SparcFCMP, a.*, b.*));
}

fn _Qp_feq(a: *const f128, b: *const f128) callconv(.C) bool {
    return @as(SparcFCMP, @enumFromInt(_Qp_cmp(a, b))) == .Equal;
}

fn _Qp_fne(a: *const f128, b: *const f128) callconv(.C) bool {
    return @as(SparcFCMP, @enumFromInt(_Qp_cmp(a, b))) != .Equal;
}

fn _Qp_flt(a: *const f128, b: *const f128) callconv(.C) bool {
    return @as(SparcFCMP, @enumFromInt(_Qp_cmp(a, b))) == .Less;
}

fn _Qp_fgt(a: *const f128, b: *const f128) callconv(.C) bool {
    return @as(SparcFCMP, @enumFromInt(_Qp_cmp(a, b))) == .Greater;
}

fn _Qp_fge(a: *const f128, b: *const f128) callconv(.C) bool {
    return switch (@as(SparcFCMP, @enumFromInt(_Qp_cmp(a, b)))) {
        .Equal, .Greater => true,
        .Less, .Unordered => false,
    };
}

fn _Qp_fle(a: *const f128, b: *const f128) callconv(.C) bool {
    return switch (@as(SparcFCMP, @enumFromInt(_Qp_cmp(a, b)))) {
        .Equal, .Less => true,
        .Greater, .Unordered => false,
    };
}
