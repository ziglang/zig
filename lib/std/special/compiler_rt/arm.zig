// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// ARM specific builtins
const builtin = @import("builtin");

const __divmodsi4 = @import("int.zig").__divmodsi4;
const __udivmodsi4 = @import("int.zig").__udivmodsi4;
const __divmoddi4 = @import("int.zig").__divmoddi4;
const __udivmoddi4 = @import("int.zig").__udivmoddi4;

extern fn memset(dest: ?[*]u8, c: u8, n: usize) ?[*]u8;
extern fn memcpy(noalias dest: ?[*]u8, noalias src: ?[*]const u8, n: usize) ?[*]u8;
extern fn memmove(dest: ?[*]u8, src: ?[*]const u8, n: usize) ?[*]u8;

pub fn __aeabi_memcpy(dest: [*]u8, src: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memcpy(dest, src, n);
}

pub fn __aeabi_memmove(dest: [*]u8, src: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memmove(dest, src, n);
}

pub fn __aeabi_memset(dest: [*]u8, n: usize, c: u8) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    // This is dentical to the standard `memset` definition but with the last
    // two arguments swapped
    _ = memset(dest, c, n);
}

pub fn __aeabi_memclr(dest: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memset(dest, 0, n);
}

// Dummy functions to avoid errors during the linking phase
pub fn __aeabi_unwind_cpp_pr0() callconv(.C) void {}
pub fn __aeabi_unwind_cpp_pr1() callconv(.C) void {}
pub fn __aeabi_unwind_cpp_pr2() callconv(.C) void {}

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
        :
        :
        : "memory"
    );
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
        :
        :
        : "memory"
    );
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
        :
        :
        : "memory"
    );
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
        :
        :
        : "memory"
    );
    unreachable;
}
