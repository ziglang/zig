// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("../bits.zig");

pub fn syscall0(number: SYS) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (@enumToInt(number))
        : "memory"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (@enumToInt(number)),
          [arg1] "{ebx}" (arg1)
        : "memory"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (@enumToInt(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2)
        : "memory"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (@enumToInt(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
          [arg3] "{edx}" (arg3)
        : "memory"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (@enumToInt(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
          [arg3] "{edx}" (arg3),
          [arg4] "{esi}" (arg4)
        : "memory"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (@enumToInt(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
          [arg3] "{edx}" (arg3),
          [arg4] "{esi}" (arg4),
          [arg5] "{edi}" (arg5)
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
    // The 6th argument is passed via memory as we're out of registers if ebp is
    // used as frame pointer. We push arg6 value on the stack before changing
    // ebp or esp as the compiler may reference it as an offset relative to one
    // of those two registers.
    return asm volatile (
        \\ push %[arg6]
        \\ push %%ebp
        \\ mov  4(%%esp), %%ebp
        \\ int  $0x80
        \\ pop  %%ebp
        \\ add  $4, %%esp
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (@enumToInt(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
          [arg3] "{edx}" (arg3),
          [arg4] "{esi}" (arg4),
          [arg5] "{edi}" (arg5),
          [arg6] "rm" (arg6)
        : "memory"
    );
}

pub fn socketcall(call: usize, args: [*]usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (@enumToInt(SYS.socketcall)),
          [arg1] "{ebx}" (call),
          [arg2] "{ecx}" (@ptrToInt(args))
        : "memory"
    );
}

/// This matches the libc clone function.
pub extern fn clone(func: fn (arg: usize) callconv(.C) u8, stack: usize, flags: u32, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub fn restore() callconv(.Naked) void {
    return asm volatile ("int $0x80"
        :
        : [number] "{eax}" (@enumToInt(SYS.sigreturn))
        : "memory"
    );
}

pub fn restore_rt() callconv(.Naked) void {
    return asm volatile ("int $0x80"
        :
        : [number] "{eax}" (@enumToInt(SYS.rt_sigreturn))
        : "memory"
    );
}
