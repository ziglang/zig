// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("std");

pub fn __builtin_bswap16(val: u16) callconv(.Inline) u16 {
    return @byteSwap(u16, val);
}
pub fn __builtin_bswap32(val: u32) callconv(.Inline) u32 {
    return @byteSwap(u32, val);
}
pub fn __builtin_bswap64(val: u64) callconv(.Inline) u64 {
    return @byteSwap(u64, val);
}

pub fn __builtin_signbit(val: f64) callconv(.Inline) c_int {
    return @boolToInt(std.math.signbit(val));
}
pub fn __builtin_signbitf(val: f32) callconv(.Inline) c_int {
    return @boolToInt(std.math.signbit(val));
}

pub fn __builtin_popcount(val: c_uint) callconv(.Inline) c_int {
    // popcount of a c_uint will never exceed the capacity of a c_int
    @setRuntimeSafety(false);
    return @bitCast(c_int, @as(c_uint, @popCount(c_uint, val)));
}
pub fn __builtin_ctz(val: c_uint) callconv(.Inline) c_int {
    // Returns the number of trailing 0-bits in val, starting at the least significant bit position.
    // In C if `val` is 0, the result is undefined; in zig it's the number of bits in a c_uint
    @setRuntimeSafety(false);
    return @bitCast(c_int, @as(c_uint, @ctz(c_uint, val)));
}
pub fn __builtin_clz(val: c_uint) callconv(.Inline) c_int {
    // Returns the number of leading 0-bits in x, starting at the most significant bit position.
    // In C if `val` is 0, the result is undefined; in zig it's the number of bits in a c_uint
    @setRuntimeSafety(false);
    return @bitCast(c_int, @as(c_uint, @clz(c_uint, val)));
}

pub fn __builtin_sqrt(val: f64) callconv(.Inline) f64 {
    return @sqrt(val);
}
pub fn __builtin_sqrtf(val: f32) callconv(.Inline) f32 {
    return @sqrt(val);
}

pub fn __builtin_sin(val: f64) callconv(.Inline) f64 {
    return @sin(val);
}
pub fn __builtin_sinf(val: f32) callconv(.Inline) f32 {
    return @sin(val);
}
pub fn __builtin_cos(val: f64) callconv(.Inline) f64 {
    return @cos(val);
}
pub fn __builtin_cosf(val: f32) callconv(.Inline) f32 {
    return @cos(val);
}

pub fn __builtin_exp(val: f64) callconv(.Inline) f64 {
    return @exp(val);
}
pub fn __builtin_expf(val: f32) callconv(.Inline) f32 {
    return @exp(val);
}
pub fn __builtin_exp2(val: f64) callconv(.Inline) f64 {
    return @exp2(val);
}
pub fn __builtin_exp2f(val: f32) callconv(.Inline) f32 {
    return @exp2(val);
}
pub fn __builtin_log(val: f64) callconv(.Inline) f64 {
    return @log(val);
}
pub fn __builtin_logf(val: f32) callconv(.Inline) f32 {
    return @log(val);
}
pub fn __builtin_log2(val: f64) callconv(.Inline) f64 {
    return @log2(val);
}
pub fn __builtin_log2f(val: f32) callconv(.Inline) f32 {
    return @log2(val);
}
pub fn __builtin_log10(val: f64) callconv(.Inline) f64 {
    return @log10(val);
}
pub fn __builtin_log10f(val: f32) callconv(.Inline) f32 {
    return @log10(val);
}

// Standard C Library bug: The absolute value of the most negative integer remains negative.
pub fn __builtin_abs(val: c_int) callconv(.Inline) c_int {
    return std.math.absInt(val) catch std.math.minInt(c_int);
}
pub fn __builtin_fabs(val: f64) callconv(.Inline) f64 {
    return @fabs(val);
}
pub fn __builtin_fabsf(val: f32) callconv(.Inline) f32 {
    return @fabs(val);
}

pub fn __builtin_floor(val: f64) callconv(.Inline) f64 {
    return @floor(val);
}
pub fn __builtin_floorf(val: f32) callconv(.Inline) f32 {
    return @floor(val);
}
pub fn __builtin_ceil(val: f64) callconv(.Inline) f64 {
    return @ceil(val);
}
pub fn __builtin_ceilf(val: f32) callconv(.Inline) f32 {
    return @ceil(val);
}
pub fn __builtin_trunc(val: f64) callconv(.Inline) f64 {
    return @trunc(val);
}
pub fn __builtin_truncf(val: f32) callconv(.Inline) f32 {
    return @trunc(val);
}
pub fn __builtin_round(val: f64) callconv(.Inline) f64 {
    return @round(val);
}
pub fn __builtin_roundf(val: f32) callconv(.Inline) f32 {
    return @round(val);
}

pub fn __builtin_strlen(s: [*c]const u8) callconv(.Inline) usize {
    return std.mem.lenZ(s);
}
pub fn __builtin_strcmp(s1: [*c]const u8, s2: [*c]const u8) callconv(.Inline) c_int {
    return @as(c_int, std.cstr.cmp(s1, s2));
}

pub fn __builtin_object_size(ptr: ?*const c_void, ty: c_int) callconv(.Inline) usize {
    // clang semantics match gcc's: https://gcc.gnu.org/onlinedocs/gcc/Object-Size-Checking.html
    // If it is not possible to determine which objects ptr points to at compile time,
    // __builtin_object_size should return (size_t) -1 for type 0 or 1 and (size_t) 0
    // for type 2 or 3.
    if (ty == 0 or ty == 1) return @bitCast(usize, -@as(c_long, 1));
    if (ty == 2 or ty == 3) return 0;
    unreachable;
}

pub fn __builtin___memset_chk(
    dst: ?*c_void,
    val: c_int,
    len: usize,
    remaining: usize,
) callconv(.Inline) ?*c_void {
    if (len > remaining) @panic("std.c.builtins.memset_chk called with len > remaining");
    return __builtin_memset(dst, val, len);
}

pub fn __builtin_memset(dst: ?*c_void, val: c_int, len: usize) callconv(.Inline) ?*c_void {
    const dst_cast = @ptrCast([*c]u8, dst);
    @memset(dst_cast, @bitCast(u8, @truncate(i8, val)), len);
    return dst;
}

pub fn __builtin___memcpy_chk(
    noalias dst: ?*c_void,
    noalias src: ?*const c_void,
    len: usize,
    remaining: usize,
) callconv(.Inline) ?*c_void {
    if (len > remaining) @panic("std.c.builtins.memcpy_chk called with len > remaining");
    return __builtin_memcpy(dst, src, len);
}

pub fn __builtin_memcpy(
    noalias dst: ?*c_void,
    noalias src: ?*const c_void,
    len: usize,
) callconv(.Inline) ?*c_void {
    const dst_cast = @ptrCast([*c]u8, dst);
    const src_cast = @ptrCast([*c]const u8, src);

    @memcpy(dst_cast, src_cast, len);
    return dst;
}
