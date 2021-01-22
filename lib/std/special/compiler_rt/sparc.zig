// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// SPARC uses a different naming scheme for its support routines so we map it here to the x86 name.

const std = @import("std");
const builtin = @import("builtin");

// The SPARC Architecture Manual, Version 9:
// A.13 Floating-Point Compare
const FCMP = extern enum(i32) {
    Equal = 0,
    Less = 1,
    Greater = 2,
    Unordered = 3,
};

// Basic arithmetic

pub fn _Qp_add(c: *f128, a: *f128, b: *f128) callconv(.C) void {
    c.* = @import("addXf3.zig").__addtf3(a.*, b.*);
}

pub fn _Qp_div(c: *f128, a: *f128, b: *f128) callconv(.C) void {
    c.* = @import("divtf3.zig").__divtf3(a.*, b.*);
}

pub fn _Qp_mul(c: *f128, a: *f128, b: *f128) callconv(.C) void {
    c.* = @import("mulXf3.zig").__multf3(a.*, b.*);
}

pub fn _Qp_sub(c: *f128, a: *f128, b: *f128) callconv(.C) void {
    c.* = @import("addXf3.zig").__subtf3(a.*, b.*);
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

// Casting

pub fn _Qp_dtoq(c: *f128, a: f64) callconv(.C) void {
    c.* = @import("extendXfYf2.zig").__extenddftf2(a);
}

pub fn _Qp_qtod(a: *f128) callconv(.C) f64 {
    return @import("truncXfYf2.zig").__trunctfdf2(a.*);
}
