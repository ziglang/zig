// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");

pub fn _alldiv(a: i64, b: i64) callconv(.Stdcall) i64 {
    @setRuntimeSafety(builtin.is_test);
    const s_a = a >> (64 - 1);
    const s_b = b >> (64 - 1);

    const an = (a ^ s_a) -% s_a;
    const bn = (b ^ s_b) -% s_b;

    const r = @bitCast(u64, an) / @bitCast(u64, bn);
    const s = s_a ^ s_b;
    return (@bitCast(i64, r) ^ s) -% s;
}

pub fn _aulldiv() callconv(.Naked) void {
    @setRuntimeSafety(false);

    // The stack layout is:
    // ESP+16 divisor (hi)
    // ESP+12 divisor (low)
    // ESP+8 dividend (hi)
    // ESP+4 dividend (low)
    // ESP   return address

    asm volatile (
        \\  push   %%ebx
        \\  push   %%esi
        \\  mov    0x18(%%esp),%%eax
        \\  or     %%eax,%%eax
        \\  jne    1f
        \\  mov    0x14(%%esp),%%ecx
        \\  mov    0x10(%%esp),%%eax
        \\  xor    %%edx,%%edx
        \\  div    %%ecx
        \\  mov    %%eax,%%ebx
        \\  mov    0xc(%%esp),%%eax
        \\  div    %%ecx
        \\  mov    %%ebx,%%edx
        \\  jmp    5f
        \\ 1:
        \\  mov    %%eax,%%ecx
        \\  mov    0x14(%%esp),%%ebx
        \\  mov    0x10(%%esp),%%edx
        \\  mov    0xc(%%esp),%%eax
        \\ 2:
        \\  shr    %%ecx
        \\  rcr    %%ebx
        \\  shr    %%edx
        \\  rcr    %%eax
        \\  or     %%ecx,%%ecx
        \\  jne    2b
        \\  div    %%ebx
        \\  mov    %%eax,%%esi
        \\  mull   0x18(%%esp)
        \\  mov    %%eax,%%ecx
        \\  mov    0x14(%%esp),%%eax
        \\  mul    %%esi
        \\  add    %%ecx,%%edx
        \\  jb     3f
        \\  cmp    0x10(%%esp),%%edx
        \\  ja     3f
        \\  jb     4f
        \\  cmp    0xc(%%esp),%%eax
        \\  jbe    4f
        \\ 3:
        \\  dec    %%esi
        \\ 4:
        \\  xor    %%edx,%%edx
        \\  mov    %%esi,%%eax
        \\ 5:
        \\  pop    %%esi
        \\  pop    %%ebx
        \\  ret    $0x10
    );
}
