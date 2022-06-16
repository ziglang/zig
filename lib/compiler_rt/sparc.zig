//
// SPARC uses a different naming scheme for its support routines so we map it here to the x86 name.

const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;
pub const panic = @import("common.zig").panic;

comptime {
    if (arch.isSPARC()) {
        // SPARC systems use a different naming scheme
        @export(_Qp_add, .{ .name = "_Qp_add", .linkage = linkage });
        @export(_Qp_div, .{ .name = "_Qp_div", .linkage = linkage });
        @export(_Qp_mul, .{ .name = "_Qp_mul", .linkage = linkage });
        @export(_Qp_sub, .{ .name = "_Qp_sub", .linkage = linkage });

        @export(_Qp_cmp, .{ .name = "_Qp_cmp", .linkage = linkage });
        @export(_Qp_feq, .{ .name = "_Qp_feq", .linkage = linkage });
        @export(_Qp_fne, .{ .name = "_Qp_fne", .linkage = linkage });
        @export(_Qp_flt, .{ .name = "_Qp_flt", .linkage = linkage });
        @export(_Qp_fle, .{ .name = "_Qp_fle", .linkage = linkage });
        @export(_Qp_fgt, .{ .name = "_Qp_fgt", .linkage = linkage });
        @export(_Qp_fge, .{ .name = "_Qp_fge", .linkage = linkage });

        @export(_Qp_itoq, .{ .name = "_Qp_itoq", .linkage = linkage });
        @export(_Qp_uitoq, .{ .name = "_Qp_uitoq", .linkage = linkage });
        @export(_Qp_xtoq, .{ .name = "_Qp_xtoq", .linkage = linkage });
        @export(_Qp_uxtoq, .{ .name = "_Qp_uxtoq", .linkage = linkage });
        @export(_Qp_stoq, .{ .name = "_Qp_stoq", .linkage = linkage });
        @export(_Qp_dtoq, .{ .name = "_Qp_dtoq", .linkage = linkage });
        @export(_Qp_qtoi, .{ .name = "_Qp_qtoi", .linkage = linkage });
        @export(_Qp_qtoui, .{ .name = "_Qp_qtoui", .linkage = linkage });
        @export(_Qp_qtox, .{ .name = "_Qp_qtox", .linkage = linkage });
        @export(_Qp_qtoux, .{ .name = "_Qp_qtoux", .linkage = linkage });
        @export(_Qp_qtos, .{ .name = "_Qp_qtos", .linkage = linkage });
        @export(_Qp_qtod, .{ .name = "_Qp_qtod", .linkage = linkage });
    }
}

// The SPARC Architecture Manual, Version 9:
// A.13 Floating-Point Compare
const FCMP = enum(i32) {
    Equal = 0,
    Less = 1,
    Greater = 2,
    Unordered = 3,
};

// Basic arithmetic

pub fn _Qp_add(c: *f128, a: *f128, b: *f128) callconv(.C) void {
    c.* = @import("addf3.zig").__addtf3(a.*, b.*);
}

pub fn _Qp_div(c: *f128, a: *f128, b: *f128) callconv(.C) void {
    c.* = @import("divtf3.zig").__divtf3(a.*, b.*);
}

pub fn _Qp_mul(c: *f128, a: *f128, b: *f128) callconv(.C) void {
    c.* = @import("mulf3.zig").__multf3(a.*, b.*);
}

pub fn _Qp_sub(c: *f128, a: *f128, b: *f128) callconv(.C) void {
    c.* = @import("addf3.zig").__subtf3(a.*, b.*);
}

// Comparison

pub fn _Qp_cmp(a: *f128, b: *f128) callconv(.C) i32 {
    return @enumToInt(@import("compareXf2.zig").cmp(f128, FCMP, a.*, b.*));
}

pub fn _Qp_feq(a: *f128, b: *f128) callconv(.C) bool {
    return _Qp_cmp(a, b) == @enumToInt(FCMP.Equal);
}

pub fn _Qp_fne(a: *f128, b: *f128) callconv(.C) bool {
    return _Qp_cmp(a, b) != @enumToInt(FCMP.Equal);
}

pub fn _Qp_flt(a: *f128, b: *f128) callconv(.C) bool {
    return _Qp_cmp(a, b) == @enumToInt(FCMP.Less);
}

pub fn _Qp_fle(a: *f128, b: *f128) callconv(.C) bool {
    const cmp = _Qp_cmp(a, b);
    return cmp == @enumToInt(FCMP.Less) or cmp == @enumToInt(FCMP.Equal);
}

pub fn _Qp_fgt(a: *f128, b: *f128) callconv(.C) bool {
    return _Qp_cmp(a, b) == @enumToInt(FCMP.Greater);
}

pub fn _Qp_fge(a: *f128, b: *f128) callconv(.C) bool {
    const cmp = _Qp_cmp(a, b);
    return cmp == @enumToInt(FCMP.Greater) or cmp == @enumToInt(FCMP.Equal);
}

// Conversion

pub fn _Qp_itoq(c: *f128, a: i32) callconv(.C) void {
    c.* = @import("floatXiYf.zig").__floatsitf(a);
}

pub fn _Qp_uitoq(c: *f128, a: u32) callconv(.C) void {
    c.* = @import("floatXiYf.zig").__floatunsitf(a);
}

pub fn _Qp_xtoq(c: *f128, a: i64) callconv(.C) void {
    c.* = @import("floatXiYf.zig").__floatditf(a);
}

pub fn _Qp_uxtoq(c: *f128, a: u64) callconv(.C) void {
    c.* = @import("floatXiYf.zig").__floatunditf(a);
}

pub fn _Qp_stoq(c: *f128, a: f32) callconv(.C) void {
    c.* = @import("extendXfYf2.zig").__extendsftf2(a);
}

pub fn _Qp_dtoq(c: *f128, a: f64) callconv(.C) void {
    c.* = @import("extendXfYf2.zig").__extenddftf2(a);
}

pub fn _Qp_qtoi(a: *f128) callconv(.C) i32 {
    return @import("fixXfYi.zig").__fixtfsi(a.*);
}

pub fn _Qp_qtoui(a: *f128) callconv(.C) u32 {
    return @import("fixXfYi.zig").__fixunstfsi(a.*);
}

pub fn _Qp_qtox(a: *f128) callconv(.C) i64 {
    return @import("fixXfYi.zig").__fixtfdi(a.*);
}

pub fn _Qp_qtoux(a: *f128) callconv(.C) u64 {
    return @import("fixXfYi.zig").__fixunstfdi(a.*);
}

pub fn _Qp_qtos(a: *f128) callconv(.C) f32 {
    return @import("truncXfYf2.zig").__trunctfsf2(a.*);
}

pub fn _Qp_qtod(a: *f128) callconv(.C) f64 {
    return @import("truncXfYf2.zig").__trunctfdf2(a.*);
}
