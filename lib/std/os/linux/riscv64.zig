// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("../bits.zig");

pub fn syscall0(number: SYS) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize)
        : [number] "{x17}" (@enumToInt(number))
        : "memory"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize)
        : [number] "{x17}" (@enumToInt(number)),
          [arg1] "{x10}" (arg1)
        : "memory"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize)
        : [number] "{x17}" (@enumToInt(number)),
          [arg1] "{x10}" (arg1),
          [arg2] "{x11}" (arg2)
        : "memory"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize)
        : [number] "{x17}" (@enumToInt(number)),
          [arg1] "{x10}" (arg1),
          [arg2] "{x11}" (arg2),
          [arg3] "{x12}" (arg3)
        : "memory"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize)
        : [number] "{x17}" (@enumToInt(number)),
          [arg1] "{x10}" (arg1),
          [arg2] "{x11}" (arg2),
          [arg3] "{x12}" (arg3),
          [arg4] "{x13}" (arg4)
        : "memory"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize)
        : [number] "{x17}" (@enumToInt(number)),
          [arg1] "{x10}" (arg1),
          [arg2] "{x11}" (arg2),
          [arg3] "{x12}" (arg3),
          [arg4] "{x13}" (arg4),
          [arg5] "{x14}" (arg5)
        : "memory"
    );
}

pub fn syscall6(
    number: SYS,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
    arg6: usize,
) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize)
        : [number] "{x17}" (@enumToInt(number)),
          [arg1] "{x10}" (arg1),
          [arg2] "{x11}" (arg2),
          [arg3] "{x12}" (arg3),
          [arg4] "{x13}" (arg4),
          [arg5] "{x14}" (arg5),
          [arg6] "{x15}" (arg6)
        : "memory"
    );
}

pub extern fn clone(func: fn (arg: usize) callconv(.C) u8, stack: usize, flags: u32, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub const restore = restore_rt;

pub fn restore_rt() callconv(.Naked) void {
    return asm volatile ("ecall"
        :
        : [number] "{x17}" (@enumToInt(SYS.rt_sigreturn))
        : "memory"
    );
}
