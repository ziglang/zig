//! Implementation of ARM specific builtins for Run-time ABI
//! This file includes all ARM-only functions.
const std = @import("std");
const builtin = @import("builtin");
const target = builtin.target;
const arch = builtin.cpu.arch;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    if (!builtin.is_test) {
        if (arch.isArmOrThumb()) {
            @export(&__aeabi_unwind_cpp_pr0, .{ .name = "__aeabi_unwind_cpp_pr0", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_unwind_cpp_pr1, .{ .name = "__aeabi_unwind_cpp_pr1", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_unwind_cpp_pr2, .{ .name = "__aeabi_unwind_cpp_pr2", .linkage = common.linkage, .visibility = common.visibility });

            @export(&__aeabi_ldivmod, .{ .name = if (target.isMinGW()) "__rt_sdiv64" else "__aeabi_ldivmod", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_uldivmod, .{ .name = if (target.isMinGW()) "__rt_udiv64" else "__aeabi_uldivmod", .linkage = common.linkage, .visibility = common.visibility });

            @export(&__aeabi_idivmod, .{ .name = if (target.isMinGW()) "__rt_sdiv" else "__aeabi_idivmod", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_uidivmod, .{ .name = if (target.isMinGW()) "__rt_udiv" else "__aeabi_uidivmod", .linkage = common.linkage, .visibility = common.visibility });

            @export(&__aeabi_memcpy, .{ .name = "__aeabi_memcpy", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_memcpy4, .{ .name = "__aeabi_memcpy4", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_memcpy8, .{ .name = "__aeabi_memcpy8", .linkage = common.linkage, .visibility = common.visibility });

            @export(&__aeabi_memmove, .{ .name = "__aeabi_memmove", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_memmove4, .{ .name = "__aeabi_memmove4", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_memmove8, .{ .name = "__aeabi_memmove8", .linkage = common.linkage, .visibility = common.visibility });

            @export(&__aeabi_memset, .{ .name = "__aeabi_memset", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_memset4, .{ .name = "__aeabi_memset4", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_memset8, .{ .name = "__aeabi_memset8", .linkage = common.linkage, .visibility = common.visibility });

            @export(&__aeabi_memclr, .{ .name = "__aeabi_memclr", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_memclr4, .{ .name = "__aeabi_memclr4", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_memclr8, .{ .name = "__aeabi_memclr8", .linkage = common.linkage, .visibility = common.visibility });

            if (builtin.os.tag == .linux) {
                @export(&__aeabi_read_tp, .{ .name = "__aeabi_read_tp", .linkage = common.linkage, .visibility = common.visibility });
            }

            // floating-point helper functions (single+double-precision reverse subtraction, y – x), see subdf3.zig
            @export(&__aeabi_frsub, .{ .name = "__aeabi_frsub", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_drsub, .{ .name = "__aeabi_drsub", .linkage = common.linkage, .visibility = common.visibility });
        }
    }
}

const __divmodsi4 = @import("int.zig").__divmodsi4;
const __udivmodsi4 = @import("int.zig").__udivmodsi4;
const __divmoddi4 = @import("int.zig").__divmoddi4;
const __udivmoddi4 = @import("int.zig").__udivmoddi4;

extern fn memset(dest: ?[*]u8, c: i32, n: usize) ?[*]u8;
extern fn memcpy(noalias dest: ?[*]u8, noalias src: ?[*]const u8, n: usize) ?[*]u8;
extern fn memmove(dest: ?[*]u8, src: ?[*]const u8, n: usize) ?[*]u8;

pub fn __aeabi_memcpy(dest: [*]u8, src: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memcpy(dest, src, n);
}
pub fn __aeabi_memcpy4(dest: [*]u8, src: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memcpy(dest, src, n);
}
pub fn __aeabi_memcpy8(dest: [*]u8, src: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memcpy(dest, src, n);
}

pub fn __aeabi_memmove(dest: [*]u8, src: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memmove(dest, src, n);
}
pub fn __aeabi_memmove4(dest: [*]u8, src: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memmove(dest, src, n);
}
pub fn __aeabi_memmove8(dest: [*]u8, src: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memmove(dest, src, n);
}

pub fn __aeabi_memset(dest: [*]u8, n: usize, c: i32) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    // This is dentical to the standard `memset` definition but with the last
    // two arguments swapped
    _ = memset(dest, c, n);
}
pub fn __aeabi_memset4(dest: [*]u8, n: usize, c: i32) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memset(dest, c, n);
}
pub fn __aeabi_memset8(dest: [*]u8, n: usize, c: i32) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memset(dest, c, n);
}

pub fn __aeabi_memclr(dest: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memset(dest, 0, n);
}
pub fn __aeabi_memclr4(dest: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memset(dest, 0, n);
}
pub fn __aeabi_memclr8(dest: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memset(dest, 0, n);
}

// Dummy functions to avoid errors during the linking phase
pub fn __aeabi_unwind_cpp_pr0() callconv(.AAPCS) void {}
pub fn __aeabi_unwind_cpp_pr1() callconv(.AAPCS) void {}
pub fn __aeabi_unwind_cpp_pr2() callconv(.AAPCS) void {}

// This function can only clobber r0 according to the ABI
pub fn __aeabi_read_tp() callconv(.Naked) void {
    @setRuntimeSafety(false);
    asm volatile (
        \\ mrc p15, 0, r0, c13, c0, 3
        \\ bx lr
    );
    unreachable;
}

// The following functions are wrapped in an asm block to ensure the required
// calling convention is always respected

pub fn __aeabi_uidivmod() callconv(.Naked) void {
    @setRuntimeSafety(false);
    // Divide r0 by r1; the quotient goes in r0, the remainder in r1
    asm volatile (
        \\ push {lr}
        \\ sub sp, #4
        \\ mov r2, sp
        \\ bl  __udivmodsi4
        \\ ldr r1, [sp]
        \\ add sp, #4
        \\ pop {pc}
        ::: "memory");
    unreachable;
}

pub fn __aeabi_uldivmod() callconv(.Naked) void {
    @setRuntimeSafety(false);
    // Divide r1:r0 by r3:r2; the quotient goes in r1:r0, the remainder in r3:r2
    asm volatile (
        \\ push {r4, lr}
        \\ sub sp, #16
        \\ add r4, sp, #8
        \\ str r4, [sp]
        \\ bl  __udivmoddi4
        \\ ldr r2, [sp, #8]
        \\ ldr r3, [sp, #12]
        \\ add sp, #16
        \\ pop {r4, pc}
        ::: "memory");
    unreachable;
}

pub fn __aeabi_idivmod() callconv(.Naked) void {
    @setRuntimeSafety(false);
    // Divide r0 by r1; the quotient goes in r0, the remainder in r1
    asm volatile (
        \\ push {lr}
        \\ sub sp, #4
        \\ mov r2, sp
        \\ bl  __divmodsi4
        \\ ldr r1, [sp]
        \\ add sp, #4
        \\ pop {pc}
        ::: "memory");
    unreachable;
}

pub fn __aeabi_ldivmod() callconv(.Naked) void {
    @setRuntimeSafety(false);
    // Divide r1:r0 by r3:r2; the quotient goes in r1:r0, the remainder in r3:r2
    asm volatile (
        \\ push {r4, lr}
        \\ sub sp, #16
        \\ add r4, sp, #8
        \\ str r4, [sp]
        \\ bl  __divmoddi4
        \\ ldr r2, [sp, #8]
        \\ ldr r3, [sp, #12]
        \\ add sp, #16
        \\ pop {r4, pc}
        ::: "memory");
    unreachable;
}

// Float Arithmetic

fn __aeabi_frsub(a: f32, b: f32) callconv(.AAPCS) f32 {
    const neg_a: f32 = @bitCast(@as(u32, @bitCast(a)) ^ (@as(u32, 1) << 31));
    return b + neg_a;
}

fn __aeabi_drsub(a: f64, b: f64) callconv(.AAPCS) f64 {
    const neg_a: f64 = @bitCast(@as(u64, @bitCast(a)) ^ (@as(u64, 1) << 63));
    return b + neg_a;
}

test "__aeabi_frsub" {
    if (!builtin.cpu.arch.isARM()) return error.SkipZigTest;
    const inf32 = std.math.inf(f32);
    const maxf32 = std.math.floatMax(f32);
    const frsub_data = [_][3]f32{
        [_]f32{ 0.0, 0.0, -0.0 },
        [_]f32{ 0.0, -0.0, -0.0 },
        [_]f32{ -0.0, 0.0, 0.0 },
        [_]f32{ -0.0, -0.0, -0.0 },
        [_]f32{ 0.0, 1.0, 1.0 },
        [_]f32{ 1.0, 0.0, -1.0 },
        [_]f32{ 1.0, 1.0, 0.0 },
        [_]f32{ 1234.56789, 9876.54321, 8641.97532 },
        [_]f32{ 9876.54321, 1234.56789, -8641.97532 },
        [_]f32{ -8641.97532, 1234.56789, 9876.54321 },
        [_]f32{ 8641.97532, 9876.54321, 1234.56789 },
        [_]f32{ -maxf32, -maxf32, 0.0 },
        [_]f32{ maxf32, maxf32, 0.0 },
        [_]f32{ maxf32, -maxf32, -inf32 },
        [_]f32{ -maxf32, maxf32, inf32 },
    };
    if (!builtin.cpu.arch.isARM()) return error.SkipZigTest;
    for (frsub_data) |data| {
        try std.testing.expectApproxEqAbs(data[2], __aeabi_frsub(data[0], data[1]), 0.001);
    }
}

test "__aeabi_drsub" {
    if (!builtin.cpu.arch.isARM()) return error.SkipZigTest;
    const inf64 = std.math.inf(f64);
    const maxf64 = std.math.floatMax(f64);
    const frsub_data = [_][3]f64{
        [_]f64{ 0.0, 0.0, -0.0 },
        [_]f64{ 0.0, -0.0, -0.0 },
        [_]f64{ -0.0, 0.0, 0.0 },
        [_]f64{ -0.0, -0.0, -0.0 },
        [_]f64{ 0.0, 1.0, 1.0 },
        [_]f64{ 1.0, 0.0, -1.0 },
        [_]f64{ 1.0, 1.0, 0.0 },
        [_]f64{ 1234.56789, 9876.54321, 8641.97532 },
        [_]f64{ 9876.54321, 1234.56789, -8641.97532 },
        [_]f64{ -8641.97532, 1234.56789, 9876.54321 },
        [_]f64{ 8641.97532, 9876.54321, 1234.56789 },
        [_]f64{ -maxf64, -maxf64, 0.0 },
        [_]f64{ maxf64, maxf64, 0.0 },
        [_]f64{ maxf64, -maxf64, -inf64 },
        [_]f64{ -maxf64, maxf64, inf64 },
    };
    if (!builtin.cpu.arch.isARM()) return error.SkipZigTest;
    for (frsub_data) |data| {
        try std.testing.expectApproxEqAbs(data[2], __aeabi_drsub(data[0], data[1]), 0.000001);
    }
}
