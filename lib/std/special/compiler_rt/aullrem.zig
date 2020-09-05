// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");

pub fn _allrem(a: i64, b: i64) callconv(.Stdcall) i64 {
    @setRuntimeSafety(builtin.is_test);
    const s_a = a >> (64 - 1);
    const s_b = b >> (64 - 1);

    const an = (a ^ s_a) -% s_a;
    const bn = (b ^ s_b) -% s_b;

    const r = @bitCast(u64, an) % @bitCast(u64, bn);
    const s = s_a ^ s_b;
    return (@bitCast(i64, r) ^ s) -% s;
}

pub fn _aullrem() callconv(.Naked) void {
    @setRuntimeSafety(false);

    // The stack layout is:
    // ESP+16 divisor (hi)
    // ESP+12 divisor (low)
    // ESP+8 dividend (hi)
    // ESP+4 dividend (low)
    // ESP   return address

    asm volatile (
        \\  push   %%ebx
        \\  mov    0x14(%%esp),%%eax
        \\  or     %%eax,%%eax
        \\  jne    1f
        \\  mov    0x10(%%esp),%%ecx
        \\  mov    0xc(%%esp),%%eax
        \\  xor    %%edx,%%edx
        \\  div    %%ecx
        \\  mov    0x8(%%esp),%%eax
        \\  div    %%ecx
        \\  mov    %%edx,%%eax
        \\  xor    %%edx,%%edx
        \\  jmp    6f
        \\ 1:
        \\  mov    %%eax,%%ecx
        \\  mov    0x10(%%esp),%%ebx
        \\  mov    0xc(%%esp),%%edx
        \\  mov    0x8(%%esp),%%eax
        \\ 2:
        \\  shr    %%ecx
        \\  rcr    %%ebx
        \\  shr    %%edx
        \\  rcr    %%eax
        \\  or     %%ecx,%%ecx
        \\  jne    2b
        \\  div    %%ebx
        \\  mov    %%eax,%%ecx
        \\  mull   0x14(%%esp)
        \\  xchg   %%eax,%%ecx
        \\  mull   0x10(%%esp)
        \\  add    %%ecx,%%edx
        \\  jb     3f
        \\  cmp    0xc(%%esp),%%edx
        \\  ja     3f
        \\  jb     4f
        \\  cmp    0x8(%%esp),%%eax
        \\  jbe    4f
        \\ 3:
        \\  sub    0x10(%%esp),%%eax
        \\  sbb    0x14(%%esp),%%edx
        \\ 4:
        \\  sub    0x8(%%esp),%%eax
        \\  sbb    0xc(%%esp),%%edx
        \\  neg    %%edx
        \\  neg    %%eax
        \\  sbb    $0x0,%%edx
        \\ 6:
        \\  pop    %%ebx
        \\  ret    $0x10
    );
}
