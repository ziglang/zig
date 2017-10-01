comptime {
    _ = @import("comparetf2.zig");
    _ = @import("fixunsdfdi.zig");
    _ = @import("fixunsdfsi.zig");
    _ = @import("fixunsdfti.zig");
    _ = @import("fixunssfdi.zig");
    _ = @import("fixunssfsi.zig");
    _ = @import("fixunssfti.zig");
    _ = @import("fixunstfdi.zig");
    _ = @import("fixunstfsi.zig");
    _ = @import("fixunstfti.zig");
    _ = @import("udivmoddi4.zig");
    _ = @import("udivmodti4.zig");
    _ = @import("udivti3.zig");
    _ = @import("umodti3.zig");
    _ = @import("aulldiv.zig");
    _ = @import("aullrem.zig");
}

const builtin = @import("builtin");
const is_test = builtin.is_test;
const assert = @import("../../debug.zig").assert;

const __udivmoddi4 = @import("udivmoddi4.zig").__udivmoddi4;

// Avoid dragging in the debug safety mechanisms into this .o file,
// unless we're trying to test this file.
pub coldcc fn panic(msg: []const u8) -> noreturn {
    if (is_test) {
        @import("std").debug.panic("{}", msg);
    } else {
        unreachable;
    }
}

export fn __udivdi3(a: u64, b: u64) -> u64 {
    @setDebugSafety(this, is_test);
    @setGlobalLinkage(__udivdi3, builtin.GlobalLinkage.LinkOnce);
    return __udivmoddi4(a, b, null);
}

export fn __umoddi3(a: u64, b: u64) -> u64 {
    @setDebugSafety(this, is_test);
    @setGlobalLinkage(__umoddi3, builtin.GlobalLinkage.LinkOnce);

    var r: u64 = undefined;
    _ = __udivmoddi4(a, b, &r);
    return r;
}

const AeabiUlDivModResult = extern struct {
    quot: u64,
    rem: u64,
};
export fn __aeabi_uldivmod(numerator: u64, denominator: u64) -> AeabiUlDivModResult {
    @setDebugSafety(this, is_test);
    if (comptime isArmArch()) {
        @setGlobalLinkage(__aeabi_uldivmod, builtin.GlobalLinkage.LinkOnce);
        var result: AeabiUlDivModResult = undefined;
        result.quot = __udivmoddi4(numerator, denominator, &result.rem);
        return result;
    }

    @setGlobalLinkage(__aeabi_uldivmod, builtin.GlobalLinkage.Internal);
    unreachable;
}

fn isArmArch() -> bool {
    return switch (builtin.arch) {
        builtin.Arch.armv8_2a,
        builtin.Arch.armv8_1a,
        builtin.Arch.armv8,
        builtin.Arch.armv8r,
        builtin.Arch.armv8m_baseline,
        builtin.Arch.armv8m_mainline,
        builtin.Arch.armv7,
        builtin.Arch.armv7em,
        builtin.Arch.armv7m,
        builtin.Arch.armv7s,
        builtin.Arch.armv7k,
        builtin.Arch.armv6,
        builtin.Arch.armv6m,
        builtin.Arch.armv6k,
        builtin.Arch.armv6t2,
        builtin.Arch.armv5,
        builtin.Arch.armv5te,
        builtin.Arch.armv4t,
        builtin.Arch.armeb => true,
        else => false,
    };
}

export nakedcc fn __aeabi_uidivmod() {
    @setDebugSafety(this, false);

    if (comptime isArmArch()) {
        @setGlobalLinkage(__aeabi_uidivmod, builtin.GlobalLinkage.LinkOnce);
        asm volatile (
            \\ push    { lr }
            \\ sub     sp, sp, #4
            \\ mov     r2, sp
            \\ bl      __udivmodsi4
            \\ ldr     r1, [sp]
            \\ add     sp, sp, #4
            \\ pop     { pc }
        ::: "r2", "r1");
        unreachable;
    }

    @setGlobalLinkage(__aeabi_uidivmod, builtin.GlobalLinkage.Internal);
}

// _chkstk (_alloca) routine - probe stack between %esp and (%esp-%eax) in 4k increments,
// then decrement %esp by %eax.  Preserves all registers except %esp and flags.
// This routine is windows specific
// http://msdn.microsoft.com/en-us/library/ms648426.aspx
export nakedcc fn _chkstk() align(4) {
    @setDebugSafety(this, false);

    if (comptime builtin.os == builtin.Os.windows) {
        if (comptime builtin.arch == builtin.Arch.i386) {
            asm volatile (
                \\         push   %%ecx
                \\         cmp    $0x1000,%%eax
                \\         lea    8(%%esp),%%ecx     // esp before calling this routine -> ecx
                \\         jb     1f
                \\ 2:
                \\         sub    $0x1000,%%ecx
                \\         test   %%ecx,(%%ecx)
                \\         sub    $0x1000,%%eax
                \\         cmp    $0x1000,%%eax
                \\         ja     2b
                \\ 1:
                \\         sub    %%eax,%%ecx
                \\         test   %%ecx,(%%ecx)
                \\ 
                \\         lea    4(%%esp),%%eax     // load pointer to the return address into eax
                \\         mov    %%ecx,%%esp        // install the new top of stack pointer into esp
                \\         mov    -4(%%eax),%%ecx    // restore ecx
                \\         push   (%%eax)           // push return address onto the stack
                \\         sub    %%esp,%%eax        // restore the original value in eax
                \\         ret
            );
            unreachable;
        }
    }

    @setGlobalLinkage(_chkstk, builtin.GlobalLinkage.Internal);
}

export nakedcc fn __chkstk() align(4) {
    @setDebugSafety(this, false);

    if (comptime builtin.os == builtin.Os.windows) {
        if (comptime builtin.arch == builtin.Arch.x86_64) {
            asm volatile (
                \\         push   %%rcx
                \\         cmp    $0x1000,%%rax
                \\         lea    16(%%rsp),%%rcx     // rsp before calling this routine -> rcx
                \\         jb     1f
                \\ 2:
                \\         sub    $0x1000,%%rcx
                \\         test   %%rcx,(%%rcx)
                \\         sub    $0x1000,%%rax
                \\         cmp    $0x1000,%%rax
                \\         ja     2b
                \\ 1:
                \\         sub    %%rax,%%rcx
                \\         test   %%rcx,(%%rcx)
                \\ 
                \\         lea    8(%%rsp),%%rax     // load pointer to the return address into rax
                \\         mov    %%rcx,%%rsp        // install the new top of stack pointer into rsp
                \\         mov    -8(%%rax),%%rcx    // restore rcx
                \\         push   (%%rax)           // push return address onto the stack
                \\         sub    %%rsp,%%rax        // restore the original value in rax
                \\         ret
            );
            unreachable;
        }
    }

    @setGlobalLinkage(__chkstk, builtin.GlobalLinkage.Internal);
}

// _chkstk routine
// This routine is windows specific
// http://msdn.microsoft.com/en-us/library/ms648426.aspx
export nakedcc fn __chkstk_ms() align(4) {
    @setDebugSafety(this, false);

    if (comptime builtin.os == builtin.Os.windows) {
        if (comptime builtin.arch == builtin.Arch.i386) {
            asm volatile (
                \\         push   %%ecx
                \\         push   %%eax
                \\         cmp    $0x1000,%%eax
                \\         lea    12(%%esp),%%ecx
                \\         jb     1f
                \\ 2:
                \\         sub    $0x1000,%%ecx
                \\         test   %%ecx,(%%ecx)
                \\         sub    $0x1000,%%eax
                \\         cmp    $0x1000,%%eax
                \\         ja     2b
                \\ 1:
                \\         sub    %%eax,%%ecx
                \\         test   %%ecx,(%%ecx)
                \\         pop    %%eax
                \\         pop    %%ecx
                \\         ret
            );
            unreachable;
        }
    }

    @setGlobalLinkage(__chkstk_ms, builtin.GlobalLinkage.Internal);
}

export nakedcc fn ___chkstk_ms() align(4) {
    @setDebugSafety(this, false);

    if (comptime builtin.os == builtin.Os.windows) {
        if (comptime builtin.arch == builtin.Arch.x86_64) {
            asm volatile (
                \\        push   %%rcx
                \\        push   %%rax
                \\        cmp    $0x1000,%%rax
                \\        lea    24(%%rsp),%%rcx
                \\        jb     1f
                \\2:
                \\        sub    $0x1000,%%rcx
                \\        test   %%rcx,(%%rcx)
                \\        sub    $0x1000,%%rax
                \\        cmp    $0x1000,%%rax
                \\        ja     2b
                \\1:
                \\        sub    %%rax,%%rcx
                \\        test   %%rcx,(%%rcx)
                \\        pop    %%rax
                \\        pop    %%rcx
                \\        ret
            );
            unreachable;
        }
    }

    @setGlobalLinkage(___chkstk_ms, builtin.GlobalLinkage.Internal);
}

export fn __udivmodsi4(a: u32, b: u32, rem: &u32) -> u32 {
    @setDebugSafety(this, is_test);
    @setGlobalLinkage(__udivmodsi4, builtin.GlobalLinkage.LinkOnce);

    const d = __udivsi3(a, b);
    *rem = u32(i32(a) -% (i32(d) * i32(b)));
    return d;
}


// TODO make this an alias instead of an extra function call
// https://github.com/andrewrk/zig/issues/256

export fn __aeabi_uidiv(n: u32, d: u32) -> u32 {
    @setDebugSafety(this, is_test);
    @setGlobalLinkage(__aeabi_uidiv, builtin.GlobalLinkage.LinkOnce);

    return __udivsi3(n, d);
}

export fn __udivsi3(n: u32, d: u32) -> u32 {
    @setDebugSafety(this, is_test);
    @setGlobalLinkage(__udivsi3, builtin.GlobalLinkage.LinkOnce);

    const n_uword_bits: c_uint = u32.bit_count;
    // special cases
    if (d == 0)
        return 0; // ?!
    if (n == 0)
        return 0;
    var sr = @bitCast(c_uint, c_int(@clz(d)) - c_int(@clz(n)));
    // 0 <= sr <= n_uword_bits - 1 or sr large
    if (sr > n_uword_bits - 1)  // d > r
        return 0;
    if (sr == n_uword_bits - 1)  // d == 1
        return n;
    sr += 1;
    // 1 <= sr <= n_uword_bits - 1
    // Not a special case
    var q: u32 = n << u5(n_uword_bits - sr);
    var r: u32 = n >> u5(sr);
    var carry: u32 = 0;
    while (sr > 0) : (sr -= 1) {
        // r:q = ((r:q)  << 1) | carry
        r = (r << 1) | (q >> u5(n_uword_bits - 1));
        q = (q << 1) | carry;
        // carry = 0;
        // if (r.all >= d.all)
        // {
        //      r.all -= d.all;
        //      carry = 1;
        // }
        const s = i32(d -% r -% 1) >> u5(n_uword_bits - 1);
        carry = u32(s & 1);
        r -= d & @bitCast(u32, s);
    }
    q = (q << 1) | carry;
    return q;
}

test "test_umoddi3" {
    test_one_umoddi3(0, 1, 0);
    test_one_umoddi3(2, 1, 0);
    test_one_umoddi3(0x8000000000000000, 1, 0x0);
    test_one_umoddi3(0x8000000000000000, 2, 0x0);
    test_one_umoddi3(0xFFFFFFFFFFFFFFFF, 2, 0x1);
}

fn test_one_umoddi3(a: u64, b: u64, expected_r: u64) {
    const r = __umoddi3(a, b);
    assert(r == expected_r);
}

test "test_udivsi3" {
    const cases = [][3]u32 {
        []u32{0x00000000, 0x00000001, 0x00000000},
        []u32{0x00000000, 0x00000002, 0x00000000},
        []u32{0x00000000, 0x00000003, 0x00000000},
        []u32{0x00000000, 0x00000010, 0x00000000},
        []u32{0x00000000, 0x078644FA, 0x00000000},
        []u32{0x00000000, 0x0747AE14, 0x00000000},
        []u32{0x00000000, 0x7FFFFFFF, 0x00000000},
        []u32{0x00000000, 0x80000000, 0x00000000},
        []u32{0x00000000, 0xFFFFFFFD, 0x00000000},
        []u32{0x00000000, 0xFFFFFFFE, 0x00000000},
        []u32{0x00000000, 0xFFFFFFFF, 0x00000000},
        []u32{0x00000001, 0x00000001, 0x00000001},
        []u32{0x00000001, 0x00000002, 0x00000000},
        []u32{0x00000001, 0x00000003, 0x00000000},
        []u32{0x00000001, 0x00000010, 0x00000000},
        []u32{0x00000001, 0x078644FA, 0x00000000},
        []u32{0x00000001, 0x0747AE14, 0x00000000},
        []u32{0x00000001, 0x7FFFFFFF, 0x00000000},
        []u32{0x00000001, 0x80000000, 0x00000000},
        []u32{0x00000001, 0xFFFFFFFD, 0x00000000},
        []u32{0x00000001, 0xFFFFFFFE, 0x00000000},
        []u32{0x00000001, 0xFFFFFFFF, 0x00000000},
        []u32{0x00000002, 0x00000001, 0x00000002},
        []u32{0x00000002, 0x00000002, 0x00000001},
        []u32{0x00000002, 0x00000003, 0x00000000},
        []u32{0x00000002, 0x00000010, 0x00000000},
        []u32{0x00000002, 0x078644FA, 0x00000000},
        []u32{0x00000002, 0x0747AE14, 0x00000000},
        []u32{0x00000002, 0x7FFFFFFF, 0x00000000},
        []u32{0x00000002, 0x80000000, 0x00000000},
        []u32{0x00000002, 0xFFFFFFFD, 0x00000000},
        []u32{0x00000002, 0xFFFFFFFE, 0x00000000},
        []u32{0x00000002, 0xFFFFFFFF, 0x00000000},
        []u32{0x00000003, 0x00000001, 0x00000003},
        []u32{0x00000003, 0x00000002, 0x00000001},
        []u32{0x00000003, 0x00000003, 0x00000001},
        []u32{0x00000003, 0x00000010, 0x00000000},
        []u32{0x00000003, 0x078644FA, 0x00000000},
        []u32{0x00000003, 0x0747AE14, 0x00000000},
        []u32{0x00000003, 0x7FFFFFFF, 0x00000000},
        []u32{0x00000003, 0x80000000, 0x00000000},
        []u32{0x00000003, 0xFFFFFFFD, 0x00000000},
        []u32{0x00000003, 0xFFFFFFFE, 0x00000000},
        []u32{0x00000003, 0xFFFFFFFF, 0x00000000},
        []u32{0x00000010, 0x00000001, 0x00000010},
        []u32{0x00000010, 0x00000002, 0x00000008},
        []u32{0x00000010, 0x00000003, 0x00000005},
        []u32{0x00000010, 0x00000010, 0x00000001},
        []u32{0x00000010, 0x078644FA, 0x00000000},
        []u32{0x00000010, 0x0747AE14, 0x00000000},
        []u32{0x00000010, 0x7FFFFFFF, 0x00000000},
        []u32{0x00000010, 0x80000000, 0x00000000},
        []u32{0x00000010, 0xFFFFFFFD, 0x00000000},
        []u32{0x00000010, 0xFFFFFFFE, 0x00000000},
        []u32{0x00000010, 0xFFFFFFFF, 0x00000000},
        []u32{0x078644FA, 0x00000001, 0x078644FA},
        []u32{0x078644FA, 0x00000002, 0x03C3227D},
        []u32{0x078644FA, 0x00000003, 0x028216FE},
        []u32{0x078644FA, 0x00000010, 0x0078644F},
        []u32{0x078644FA, 0x078644FA, 0x00000001},
        []u32{0x078644FA, 0x0747AE14, 0x00000001},
        []u32{0x078644FA, 0x7FFFFFFF, 0x00000000},
        []u32{0x078644FA, 0x80000000, 0x00000000},
        []u32{0x078644FA, 0xFFFFFFFD, 0x00000000},
        []u32{0x078644FA, 0xFFFFFFFE, 0x00000000},
        []u32{0x078644FA, 0xFFFFFFFF, 0x00000000},
        []u32{0x0747AE14, 0x00000001, 0x0747AE14},
        []u32{0x0747AE14, 0x00000002, 0x03A3D70A},
        []u32{0x0747AE14, 0x00000003, 0x026D3A06},
        []u32{0x0747AE14, 0x00000010, 0x00747AE1},
        []u32{0x0747AE14, 0x078644FA, 0x00000000},
        []u32{0x0747AE14, 0x0747AE14, 0x00000001},
        []u32{0x0747AE14, 0x7FFFFFFF, 0x00000000},
        []u32{0x0747AE14, 0x80000000, 0x00000000},
        []u32{0x0747AE14, 0xFFFFFFFD, 0x00000000},
        []u32{0x0747AE14, 0xFFFFFFFE, 0x00000000},
        []u32{0x0747AE14, 0xFFFFFFFF, 0x00000000},
        []u32{0x7FFFFFFF, 0x00000001, 0x7FFFFFFF},
        []u32{0x7FFFFFFF, 0x00000002, 0x3FFFFFFF},
        []u32{0x7FFFFFFF, 0x00000003, 0x2AAAAAAA},
        []u32{0x7FFFFFFF, 0x00000010, 0x07FFFFFF},
        []u32{0x7FFFFFFF, 0x078644FA, 0x00000011},
        []u32{0x7FFFFFFF, 0x0747AE14, 0x00000011},
        []u32{0x7FFFFFFF, 0x7FFFFFFF, 0x00000001},
        []u32{0x7FFFFFFF, 0x80000000, 0x00000000},
        []u32{0x7FFFFFFF, 0xFFFFFFFD, 0x00000000},
        []u32{0x7FFFFFFF, 0xFFFFFFFE, 0x00000000},
        []u32{0x7FFFFFFF, 0xFFFFFFFF, 0x00000000},
        []u32{0x80000000, 0x00000001, 0x80000000},
        []u32{0x80000000, 0x00000002, 0x40000000},
        []u32{0x80000000, 0x00000003, 0x2AAAAAAA},
        []u32{0x80000000, 0x00000010, 0x08000000},
        []u32{0x80000000, 0x078644FA, 0x00000011},
        []u32{0x80000000, 0x0747AE14, 0x00000011},
        []u32{0x80000000, 0x7FFFFFFF, 0x00000001},
        []u32{0x80000000, 0x80000000, 0x00000001},
        []u32{0x80000000, 0xFFFFFFFD, 0x00000000},
        []u32{0x80000000, 0xFFFFFFFE, 0x00000000},
        []u32{0x80000000, 0xFFFFFFFF, 0x00000000},
        []u32{0xFFFFFFFD, 0x00000001, 0xFFFFFFFD},
        []u32{0xFFFFFFFD, 0x00000002, 0x7FFFFFFE},
        []u32{0xFFFFFFFD, 0x00000003, 0x55555554},
        []u32{0xFFFFFFFD, 0x00000010, 0x0FFFFFFF},
        []u32{0xFFFFFFFD, 0x078644FA, 0x00000022},
        []u32{0xFFFFFFFD, 0x0747AE14, 0x00000023},
        []u32{0xFFFFFFFD, 0x7FFFFFFF, 0x00000001},
        []u32{0xFFFFFFFD, 0x80000000, 0x00000001},
        []u32{0xFFFFFFFD, 0xFFFFFFFD, 0x00000001},
        []u32{0xFFFFFFFD, 0xFFFFFFFE, 0x00000000},
        []u32{0xFFFFFFFD, 0xFFFFFFFF, 0x00000000},
        []u32{0xFFFFFFFE, 0x00000001, 0xFFFFFFFE},
        []u32{0xFFFFFFFE, 0x00000002, 0x7FFFFFFF},
        []u32{0xFFFFFFFE, 0x00000003, 0x55555554},
        []u32{0xFFFFFFFE, 0x00000010, 0x0FFFFFFF},
        []u32{0xFFFFFFFE, 0x078644FA, 0x00000022},
        []u32{0xFFFFFFFE, 0x0747AE14, 0x00000023},
        []u32{0xFFFFFFFE, 0x7FFFFFFF, 0x00000002},
        []u32{0xFFFFFFFE, 0x80000000, 0x00000001},
        []u32{0xFFFFFFFE, 0xFFFFFFFD, 0x00000001},
        []u32{0xFFFFFFFE, 0xFFFFFFFE, 0x00000001},
        []u32{0xFFFFFFFE, 0xFFFFFFFF, 0x00000000},
        []u32{0xFFFFFFFF, 0x00000001, 0xFFFFFFFF},
        []u32{0xFFFFFFFF, 0x00000002, 0x7FFFFFFF},
        []u32{0xFFFFFFFF, 0x00000003, 0x55555555},
        []u32{0xFFFFFFFF, 0x00000010, 0x0FFFFFFF},
        []u32{0xFFFFFFFF, 0x078644FA, 0x00000022},
        []u32{0xFFFFFFFF, 0x0747AE14, 0x00000023},
        []u32{0xFFFFFFFF, 0x7FFFFFFF, 0x00000002},
        []u32{0xFFFFFFFF, 0x80000000, 0x00000001},
        []u32{0xFFFFFFFF, 0xFFFFFFFD, 0x00000001},
        []u32{0xFFFFFFFF, 0xFFFFFFFE, 0x00000001},
        []u32{0xFFFFFFFF, 0xFFFFFFFF, 0x00000001},
    };

    for (cases) |case| {
        test_one_udivsi3(case[0], case[1], case[2]);
    }
}

fn test_one_udivsi3(a: u32, b: u32, expected_q: u32) {
    const q: u32 = __udivsi3(a, b);
    assert(q == expected_q);
}

