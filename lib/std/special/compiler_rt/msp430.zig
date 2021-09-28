// MSP430 specific builtins

const builtin = @import("builtin");
const std = @import("std");
const fixint = @import("fixint.zig").fixint;
const __floathisf = @import("floatXisf.zig").__floathisf;
const floatsiXf = @import("floatsiXf.zig");
const fixuint = @import("fixuint.zig").fixuint;
const __floatsisf = floatsiXf.__floatsisf;
const __floatsidf = floatsiXf.__floatsidf;
const __floatunsidf = @import("floatunsidf.zig").__floatunsidf;
const __floatunsisf = @import("floatunsisf.zig").__floatunsisf;
const cmp = @import("compareXf2.zig").cmp;

// Floating-Point and Integer Conversions
pub fn __mspabi_cvtdf(x: f64) callconv(.C) f32 {
    _ = x;
    @compileError("__mspabi_cvtdf unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_cvtfd(x: f32) callconv(.C) f64 {
    _ = x;
    @compileError("__mspabi_cvtfd unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_fixdi(x: f64) callconv(.C) i16 {
    return @call(.{ .modifier = .always_inline }, fixint, .{ f64, i16, x });
}

pub fn __mspabi_fixdli(x: f64) callconv(.C) i32 {
    return @call(.{ .modifier = .always_inline }, fixint, .{ f64, i32, x });
}

pub fn __mspabi_fixdlli(x: f64) callconv(.C) i64 {
    return @call(.{ .modifier = .always_inline }, fixint, .{ f64, i64, x });
}

pub fn __mspabi_fixdu(x: f64) callconv(.C) u16 {
    return @call(.{ .modifier = .always_inline }, fixint, .{ f64, u16, x });
}

pub fn __mspabi_fixdul(x: f64) callconv(.C) u32 {
    return @call(.{ .modifier = .always_inline }, fixint, .{ f64, u32, x });
}

pub fn __mspabi_fixdull(x: f64) callconv(.C) u64 {
    return @call(.{ .modifier = .always_inline }, fixint, .{ f64, u64, x });
}

pub fn __mspabi_fixfi(x: f32) callconv(.C) i16 {
    return @call(.{ .modifier = .always_inline }, fixint, .{ f32, i16, x });
}

pub fn __mspabi_fixfli(x: f32) callconv(.C) i32 {
    return @call(.{ .modifier = .always_inline }, fixint, .{ f32, i32, x });
}

pub fn __mspabi_fixflli(x: f32) callconv(.C) i64 {
    return @call(.{ .modifier = .always_inline }, fixint, .{ f32, i64, x });
}

pub fn __mspabi_fixfu(x: f32) callconv(.C) u16 {
    return @call(.{ .modifier = .always_inline }, fixuint, .{ f32, u16, x });
}

pub fn __mspabi_fixful(x: f32) callconv(.C) u32 {
    return @call(.{ .modifier = .always_inline }, fixuint, .{ f32, u32, x });
}

pub fn __mspabi_fixfull(x: f32) callconv(.C) u64 {
    return @call(.{ .modifier = .always_inline }, fixuint, .{ f32, u64, x });
}

pub fn __mspabi_fltid(x: i16) callconv(.C) f64 {
    _ = x;
    @compileError("__mspabi_fltid unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_fltif(x: i16) callconv(.C) f32 {
    return @call(.{ .modifier = .always_inline }, __floathisf, .{x});
}

pub fn __mspabi_fltlid(x: i32) callconv(.C) f64 {
    return @call(.{ .modifier = .always_inline }, __floatsidf, .{x});
}

pub fn __mspabi_fltlif(x: i32) callconv(.C) f32 {
    return @call(.{ .modifier = .always_inline }, __floatsisf, .{x});
}

pub fn __mspabi_fltud(x: u16) callconv(.C) f64 {
    _ = x;
    @compileError("__mspabi_fltud unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_fltuf(x: u16) callconv(.C) f32 {
    _ = x;
    @compileError("__mspabi_fltuf unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_fltuld(x: u32) callconv(.C) f64 {
    return @call(.{ .modifier = .always_inline }, __floatunsidf, .{x});
}

pub fn __mspabi_fltulf(x: u32) callconv(.C) f32 {
    return @call(.{ .modifier = .always_inline }, __floatunsisf, .{x});
}

const Order = enum(i16) {
    Less = -1,
    Equal = 0,
    Greater = 1,

    // The ABI leaves this undefined.
    const Unordered: Order = undefined;
};

// Floating-Point Comparisons
pub fn __mspabi_cmpd(x: f64, y: f64) callconv(.C) i16 {
    // See ABI for special calling convention.
    _ = x;
    _ = y;
    @compileError("__mspabi_cmpd unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_cmpf(x: f32, y: f32) callconv(.C) i16 {
    return @call(.{ .modifier = .always_inline }, cmp, .{ f32, Order, x, y });
}

pub fn __mspabi_eqd(x: f64, y: f64) callconv(.C) i16 {
    _ = x;
    _ = y;
    @compileError("__mspabi_eqd unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_geqd(x: f64, y: f64) callconv(.C) i16 {
    _ = x;
    _ = y;
    @compileError("__mspabi_geqd unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_gtrd(x: f64, y: f64) callconv(.C) i16 {
    _ = x;
    _ = y;
    @compileError("__mspabi_gtrd unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_leqd(x: f64, y: f64) callconv(.C) i16 {
    _ = x;
    _ = y;
    @compileError("__mspabi_leqd unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_lssd(x: f64, y: f64) callconv(.C) i16 {
    _ = x;
    _ = y;
    @compileError("__mspabi_lssd unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_neqd(x: f64, y: f64) callconv(.C) i16 {
    _ = x;
    _ = y;
    @compileError("__mspabi_neqd unimplemented in Zig compiler_rt.");
}

// Floating-Point Arithmetic
pub fn __mspabi_addd(x: f64, y: f64) callconv(.C) f64 {
    // See ABI for special calling convention.
    _ = x;
    _ = y;
    @compileError("__mspabi_addd unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_addf(x: f32, y: f32) callconv(.C) f32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_addf unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_divd(x: f64, y: f64) callconv(.C) f64 {
    // See ABI for special calling convention.
    _ = x;
    _ = y;
    @compileError("__mspabi_divd unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_divf(x: f32, y: f32) callconv(.C) f32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_divf unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyd(x: f64, y: f64) callconv(.C) f64 {
    // See ABI for special calling convention.
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyd unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyf(x: f32, y: f32) callconv(.C) f32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyf unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_subd(x: f64, y: f64) callconv(.C) f64 {
    // See ABI for special calling convention.
    _ = x;
    _ = y;
    @compileError("__mspabi_subd unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_subf(x: f32, y: f32) callconv(.C) f32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_subf unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_negd(x: f64) callconv(.C) f64 {
    _ = x;
    @compileError("__mspabi_negd unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_negf(x: f32) callconv(.C) f32 {
    _ = x;
    @compileError("__mspabi_negf unimplemented in Zig compiler_rt.");
}

// Integer Multiply, Divide, and Remainder

// Multiplication
pub fn __mspabi_mpyi(x: i16, y: i16) callconv(.C) i16 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyi unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyi_hw(x: i16, y: i16) callconv(.C) i16 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyi_hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyi_f5hw(x: i16, y: i16) callconv(.C) i16 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyi_f5hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyl(x: i32, y: i32) callconv(.C) i32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyl unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyl_hw(x: i32, y: i32) callconv(.C) i32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyl_hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyl_hw32(x: i32, y: i32) callconv(.C) i32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyl_hw32 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyl_f5hw(x: i32, y: i32) callconv(.C) i32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyl_f5hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyll(x: i64, y: i64) callconv(.C) i64 {
    // See ABI for special calling convention.
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyll unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyll_hw(x: i64, y: i64) callconv(.C) i64 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyll_hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyll_hw32(x: i64, y: i64) callconv(.C) i64 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyll_hw32 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyll_f5hw(x: i64, y: i64) callconv(.C) i64 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyll_f5hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpysl(x: i16, y: i16) callconv(.C) i32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpysl unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpysl_hw(x: i16, y: i16) callconv(.C) i32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpysl_hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpysl_f5hw(x: i16, y: i16) callconv(.C) i32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpysl_f5hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpysll(x: i32, y: i32) callconv(.C) i64 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpysll unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpysll_hw(x: i32, y: i32) callconv(.C) i64 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpysll_hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpysll_hw32(x: i32, y: i32) callconv(.C) i64 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpysll_hw32 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpysll_f5hw(x: i32, y: i32) callconv(.C) i64 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpysll_f5hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyul(x: u16, y: u16) callconv(.C) u32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyul unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyul_hw(x: u16, y: u16) callconv(.C) u32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyul_hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyul_f5hw(x: u16, y: u16) callconv(.C) u32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyul_f5hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyull(x: u32, y: u32) callconv(.C) u64 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyull unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyull_hw(x: u32, y: u32) callconv(.C) u64 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyull_hw unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyull_hw32(x: u32, y: u32) callconv(.C) u64 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyull_hw32 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_mpyull_f5hw(x: u32, y: u32) callconv(.C) u64 {
    _ = x;
    _ = y;
    @compileError("__mspabi_mpyull_f5hw unimplemented in Zig compiler_rt.");
}

// Division
pub fn __mspabi_divi(x: i16, y: i16) callconv(.C) i16 {
    _ = x;
    _ = y;
    @compileError("__mspabi_divi unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_divli(x: i32, y: i32) callconv(.C) i32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_divli unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_divlli(x: i64, y: i64) callconv(.C) i64 {
    // See ABI for special calling convention.
    _ = x;
    _ = y;
    @compileError("__mspabi_divlli unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_divu(x: u16, y: u16) callconv(.C) u16 {
    // See ABI for special calling convention.
    _ = x;
    _ = y;
    @compileError("__mspabi_divu unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_divlu(x: u32, y: u32) callconv(.C) u32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_divlu unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_divllu(x: u64, y: u64) callconv(.C) u64 {
    _ = x;
    _ = y;
    @compileError("__mspabi_divllu unimplemented in compiler_rt.");
}

// Remainder (Modulus)
pub fn __mspabi_remi(num: i16, modulus: i16) callconv(.C) i16 {
    @setRuntimeSafety(builtin.is_test);
    var ret: i16 = num;
    var mod: i16 = std.math.absInt(modulus) catch unreachable;
    if (num < 0) {
        while (ret <= -1 * mod) {
            ret += mod;
        }
    } else {
        while (ret >= mod) {
            ret -= mod;
        }
    }
    return ret;
}

pub fn __mspabi_remli(x: i32, y: i32) callconv(.C) i32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_remli unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_remlli(x: i32, y: i32) callconv(.C) i64 {
    // See ABI for special calling convention.
    _ = x;
    _ = y;
    @compileError("__mspabi_remlli unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_remu(x: u16, y: u16) callconv(.C) u16 {
    _ = x;
    _ = y;
    @compileError("__mspabi_remu unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_remul(x: u32, y: u32) callconv(.C) u32 {
    _ = x;
    _ = y;
    @compileError("__mspabi_remul unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_remull(x: u64, y: u64) callconv(.C) u64 {
    // See ABI for special calling convention.
    _ = x;
    _ = y;
    @compileError("__mspabi_remull unimplemented in Zig compiler_rt.");
}

// Bitwise Operations

// Rotation
pub fn __mspabi_rlli(x: u16, n: i16) callconv(.C) u16 {
    _ = x;
    _ = n;
    @compileError("__mspabi_rlli unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_rlli_1(x: u16) callconv(.C) u16 {
    _ = x;
    @compileError("__mspabi_rlli_1 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_rlli_15(x: u16) callconv(.C) u16 {
    _ = x;
    @compileError("__mspabi_rlli_15 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_rlll(x: u32, n: i16) callconv(.C) u32 {
    _ = x;
    _ = n;
    @compileError("__mspabi_rlll unimplemented in Zig compiler_rt.");
}

// Logical Left Shift
pub fn __mspabi_slli(x: u16, n: i16) callconv(.C) u16 {
    _ = x;
    _ = n;
    @compileError("__mspabi_slli unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_slli_1(x: u16) callconv(.C) u16 {
    _ = x;
    @compileError("__mspabi_slli_1 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_slli_15(x: u16) callconv(.C) u16 {
    _ = x;
    @compileError("__mspabi_slli_15 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_slll(x: u32, n: i16) callconv(.C) u32 {
    _ = x;
    _ = n;
    @compileError("__mspabi_slll unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_slll_1(x: u32) callconv(.C) u32 {
    _ = x;
    @compileError("__mspabi_slll_1 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_slll_15(x: u32) callconv(.C) u32 {
    _ = x;
    @compileError("__mspabi_slll_15 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_sllll(x: u64, n: i16) callconv(.C) u64 {
    _ = x;
    _ = n;
    @compileError("__mspabi_sllll unimplemented in Zig compiler_rt.");
}

// Arithmetic Right Shift
pub fn __mspabi_srai(x: i16, n: i16) callconv(.C) i16 {
    _ = x;
    _ = n;
    @compileError("__mspabi_srai unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_srai_1(x: i16) callconv(.C) i16 {
    _ = x;
    @compileError("__mspabi_srai_1 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_srai_15(x: i16) callconv(.C) i32 {
    _ = x;
    @compileError("__mspabi_srai_15 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_sral(x: i32, n: i16) callconv(.C) i16 {
    _ = x;
    _ = n;
    @compileError("__mspabi_sral unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_sral_1(x: i32) callconv(.C) i32 {
    _ = x;
    @compileError("__mspabi_sral_1 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_sral_15(x: i32) callconv(.C) i32 {
    _ = x;
    @compileError("__mspabi_sral_15 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_srall(x: i64, n: i16) callconv(.C) i64 {
    _ = x;
    _ = n;
    @compileError("__mspabi_srall unimplemented in Zig compiler_rt.");
}

// Logical Right Shift
pub fn __mspabi_srli(x: u16, n: i16) callconv(.C) u16 {
    _ = x;
    _ = n;
    @compileError("__mspabi_srli unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_srli_1(x: u16) callconv(.C) u16 {
    _ = x;
    @compileError("__mspabi_srli_1 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_srli_15(x: u16) callconv(.C) u16 {
    _ = x;
    @compileError("__mspabi_srli_15 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_srll(x: u32, n: i16) callconv(.C) u32 {
    _ = x;
    _ = n;
    @compileError("__mspabi_srll unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_srll_1(x: u32) callconv(.C) u32 {
    _ = x;
    @compileError("__mspabi_srll_1 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_srll_15(x: u32) callconv(.C) u32 {
    _ = x;
    @compileError("__mspabi_srll_15 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_srlll(x: u64, n: i16) callconv(.C) u64 {
    _ = x;
    _ = n;
    @compileError("__mspabi_srlll unimplemented in Zig compiler_rt.");
}

// Epilog Helper Functions
pub fn __mspabi_epilog_1() callconv(.C) void {
    @compileError("__mspabi_epilog_1 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_epilog_2() callconv(.C) void {
    @compileError("__mspabi_epilog_2 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_epilog_3() callconv(.C) void {
    @compileError("__mspabi_epilog_3 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_epilog_4() callconv(.C) void {
    @compileError("__mspabi_epilog_4 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_epilog_5() callconv(.C) void {
    @compileError("__mspabi_epilog_5 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_epilog_6() callconv(.C) void {
    @compileError("__mspabi_epilog_6 unimplemented in Zig compiler_rt.");
}

pub fn __mspabi_epilog_7() callconv(.C) void {
    @compileError("__mspabi_epilog_7 unimplemented in Zig compiler_rt.");
}

// Misc Helper Functions
pub fn _abort_msg(string: [:0]u8) callconv(.C) void {
    _ = string;
    @compileError("__mspabi_epilog_7 unimplemented in Zig compiler_rt.");
}
