const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const is_test = builtin.is_test;
const target = std.Target;
const os_tag = builtin.os.tag;
const is_darwin = target.Os.Tag.isDarwin(os_tag);
const has_lse = target.aarch64.featureSetHas(builtin.target.cpu.features, .lse);
const linkage = if (is_test)
    std.builtin.GlobalLinkage.Internal
else
    std.builtin.GlobalLinkage.Strong;

fn cas1RelaxDarwinLse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casb w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas1RelaxDarwinNolse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x00000000 + 0x000000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas1RelaxNondarwinLse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casb w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas1RelaxNondarwinNolse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x00000000 + 0x000000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas1_relax = if (is_darwin)
    if (has_lse)
        cas1RelaxDarwinLse
    else
        cas1RelaxDarwinNolse
else if (has_lse)
    cas1RelaxNondarwinLse
else
    cas1RelaxNondarwinNolse;
fn swp1RelaxDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpb  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        stxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp1RelaxDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x00000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        stxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp1RelaxNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpb  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        stxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp1RelaxNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x00000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        stxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp1_relax = if (is_darwin)
    if (has_lse)
        swp1RelaxDarwinLse
    else
        swp1RelaxDarwinNolse
else if (has_lse)
    swp1RelaxNondarwinLse
else
    swp1RelaxNondarwinNolse;
fn ldadd1RelaxDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd1RelaxDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x00000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd1RelaxNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd1RelaxNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x00000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd1_relax = if (is_darwin)
    if (has_lse)
        ldadd1RelaxDarwinLse
    else
        ldadd1RelaxDarwinNolse
else if (has_lse)
    ldadd1RelaxNondarwinLse
else
    ldadd1RelaxNondarwinNolse;
fn ldclr1RelaxDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr1RelaxDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x00000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr1RelaxNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr1RelaxNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x00000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr1_relax = if (is_darwin)
    if (has_lse)
        ldclr1RelaxDarwinLse
    else
        ldclr1RelaxDarwinNolse
else if (has_lse)
    ldclr1RelaxNondarwinLse
else
    ldclr1RelaxNondarwinNolse;
fn ldeor1RelaxDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor1RelaxDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x00000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor1RelaxNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor1RelaxNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x00000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor1_relax = if (is_darwin)
    if (has_lse)
        ldeor1RelaxDarwinLse
    else
        ldeor1RelaxDarwinNolse
else if (has_lse)
    ldeor1RelaxNondarwinLse
else
    ldeor1RelaxNondarwinNolse;
fn ldset1RelaxDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset1RelaxDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x00000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset1RelaxNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset1RelaxNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x00000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset1_relax = if (is_darwin)
    if (has_lse)
        ldset1RelaxDarwinLse
    else
        ldset1RelaxDarwinNolse
else if (has_lse)
    ldset1RelaxNondarwinLse
else
    ldset1RelaxNondarwinNolse;
fn cas1AcqDarwinLse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casab w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldaxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas1AcqDarwinNolse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x00000000 + 0x400000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldaxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas1AcqNondarwinLse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casab w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldaxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas1AcqNondarwinNolse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x00000000 + 0x400000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldaxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas1_acq = if (is_darwin)
    if (has_lse)
        cas1AcqDarwinLse
    else
        cas1AcqDarwinNolse
else if (has_lse)
    cas1AcqNondarwinLse
else
    cas1AcqNondarwinNolse;
fn swp1AcqDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpab  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        stxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp1AcqDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x00000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        stxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp1AcqNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpab  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        stxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp1AcqNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x00000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        stxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp1_acq = if (is_darwin)
    if (has_lse)
        swp1AcqDarwinLse
    else
        swp1AcqDarwinNolse
else if (has_lse)
    swp1AcqNondarwinLse
else
    swp1AcqNondarwinNolse;
fn ldadd1AcqDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddab w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd1AcqDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x00000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd1AcqNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddab w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd1AcqNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x00000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd1_acq = if (is_darwin)
    if (has_lse)
        ldadd1AcqDarwinLse
    else
        ldadd1AcqDarwinNolse
else if (has_lse)
    ldadd1AcqNondarwinLse
else
    ldadd1AcqNondarwinNolse;
fn ldclr1AcqDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrab w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr1AcqDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x00000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr1AcqNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrab w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr1AcqNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x00000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr1_acq = if (is_darwin)
    if (has_lse)
        ldclr1AcqDarwinLse
    else
        ldclr1AcqDarwinNolse
else if (has_lse)
    ldclr1AcqNondarwinLse
else
    ldclr1AcqNondarwinNolse;
fn ldeor1AcqDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorab w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor1AcqDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x00000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor1AcqNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorab w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor1AcqNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x00000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor1_acq = if (is_darwin)
    if (has_lse)
        ldeor1AcqDarwinLse
    else
        ldeor1AcqDarwinNolse
else if (has_lse)
    ldeor1AcqNondarwinLse
else
    ldeor1AcqNondarwinNolse;
fn ldset1AcqDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetab w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset1AcqDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x00000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset1AcqNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetab w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset1AcqNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x00000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset1_acq = if (is_darwin)
    if (has_lse)
        ldset1AcqDarwinLse
    else
        ldset1AcqDarwinNolse
else if (has_lse)
    ldset1AcqNondarwinLse
else
    ldset1AcqNondarwinNolse;
fn cas1RelDarwinLse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        caslb w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas1RelDarwinNolse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x00000000 + 0x008000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas1RelNondarwinLse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        caslb w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas1RelNondarwinNolse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x00000000 + 0x008000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas1_rel = if (is_darwin)
    if (has_lse)
        cas1RelDarwinLse
    else
        cas1RelDarwinNolse
else if (has_lse)
    cas1RelNondarwinLse
else
    cas1RelNondarwinNolse;
fn swp1RelDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swplb  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        stlxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp1RelDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x00000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        stlxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp1RelNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swplb  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        stlxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp1RelNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x00000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        stlxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp1_rel = if (is_darwin)
    if (has_lse)
        swp1RelDarwinLse
    else
        swp1RelDarwinNolse
else if (has_lse)
    swp1RelNondarwinLse
else
    swp1RelNondarwinNolse;
fn ldadd1RelDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddlb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd1RelDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x00000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd1RelNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddlb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd1RelNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x00000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd1_rel = if (is_darwin)
    if (has_lse)
        ldadd1RelDarwinLse
    else
        ldadd1RelDarwinNolse
else if (has_lse)
    ldadd1RelNondarwinLse
else
    ldadd1RelNondarwinNolse;
fn ldclr1RelDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrlb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr1RelDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x00000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr1RelNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrlb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr1RelNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x00000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr1_rel = if (is_darwin)
    if (has_lse)
        ldclr1RelDarwinLse
    else
        ldclr1RelDarwinNolse
else if (has_lse)
    ldclr1RelNondarwinLse
else
    ldclr1RelNondarwinNolse;
fn ldeor1RelDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorlb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor1RelDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x00000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor1RelNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorlb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor1RelNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x00000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor1_rel = if (is_darwin)
    if (has_lse)
        ldeor1RelDarwinLse
    else
        ldeor1RelDarwinNolse
else if (has_lse)
    ldeor1RelNondarwinLse
else
    ldeor1RelNondarwinNolse;
fn ldset1RelDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetlb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset1RelDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x00000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset1RelNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetlb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset1RelNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x00000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset1_rel = if (is_darwin)
    if (has_lse)
        ldset1RelDarwinLse
    else
        ldset1RelDarwinNolse
else if (has_lse)
    ldset1RelNondarwinLse
else
    ldset1RelNondarwinNolse;
fn cas1AcqRelDarwinLse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casalb w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldaxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas1AcqRelDarwinNolse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x00000000 + 0x408000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldaxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas1AcqRelNondarwinLse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casalb w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldaxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas1AcqRelNondarwinNolse(expected: u8, desired: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x00000000 + 0x408000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxtb    w16, w0
        \\0:
        \\        ldaxrb   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrb   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas1_acq_rel = if (is_darwin)
    if (has_lse)
        cas1AcqRelDarwinLse
    else
        cas1AcqRelDarwinNolse
else if (has_lse)
    cas1AcqRelNondarwinLse
else
    cas1AcqRelNondarwinNolse;
fn swp1AcqRelDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpalb  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        stlxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp1AcqRelDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x00000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        stlxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp1AcqRelNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpalb  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        stlxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp1AcqRelNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x00000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        stlxrb   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp1_acq_rel = if (is_darwin)
    if (has_lse)
        swp1AcqRelDarwinLse
    else
        swp1AcqRelDarwinNolse
else if (has_lse)
    swp1AcqRelNondarwinLse
else
    swp1AcqRelNondarwinNolse;
fn ldadd1AcqRelDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddalb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd1AcqRelDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x00000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd1AcqRelNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddalb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd1AcqRelNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x00000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd1_acq_rel = if (is_darwin)
    if (has_lse)
        ldadd1AcqRelDarwinLse
    else
        ldadd1AcqRelDarwinNolse
else if (has_lse)
    ldadd1AcqRelNondarwinLse
else
    ldadd1AcqRelNondarwinNolse;
fn ldclr1AcqRelDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclralb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr1AcqRelDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x00000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr1AcqRelNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclralb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr1AcqRelNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x00000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr1_acq_rel = if (is_darwin)
    if (has_lse)
        ldclr1AcqRelDarwinLse
    else
        ldclr1AcqRelDarwinNolse
else if (has_lse)
    ldclr1AcqRelNondarwinLse
else
    ldclr1AcqRelNondarwinNolse;
fn ldeor1AcqRelDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeoralb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor1AcqRelDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x00000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor1AcqRelNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeoralb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor1AcqRelNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x00000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor1_acq_rel = if (is_darwin)
    if (has_lse)
        ldeor1AcqRelDarwinLse
    else
        ldeor1AcqRelDarwinNolse
else if (has_lse)
    ldeor1AcqRelNondarwinLse
else
    ldeor1AcqRelNondarwinNolse;
fn ldset1AcqRelDarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetalb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset1AcqRelDarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x00000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset1AcqRelNondarwinLse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetalb w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset1AcqRelNondarwinNolse(val: u8, ptr: *u8) callconv(.C) u8 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x00000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrb   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrb   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u8),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset1_acq_rel = if (is_darwin)
    if (has_lse)
        ldset1AcqRelDarwinLse
    else
        ldset1AcqRelDarwinNolse
else if (has_lse)
    ldset1AcqRelNondarwinLse
else
    ldset1AcqRelNondarwinNolse;
fn cas2RelaxDarwinLse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        cash w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas2RelaxDarwinNolse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x40000000 + 0x000000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas2RelaxNondarwinLse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        cash w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas2RelaxNondarwinNolse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x40000000 + 0x000000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas2_relax = if (is_darwin)
    if (has_lse)
        cas2RelaxDarwinLse
    else
        cas2RelaxDarwinNolse
else if (has_lse)
    cas2RelaxNondarwinLse
else
    cas2RelaxNondarwinNolse;
fn swp2RelaxDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swph  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        stxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp2RelaxDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x40000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        stxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp2RelaxNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swph  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        stxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp2RelaxNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x40000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        stxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp2_relax = if (is_darwin)
    if (has_lse)
        swp2RelaxDarwinLse
    else
        swp2RelaxDarwinNolse
else if (has_lse)
    swp2RelaxNondarwinLse
else
    swp2RelaxNondarwinNolse;
fn ldadd2RelaxDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd2RelaxDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x40000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd2RelaxNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd2RelaxNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x40000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd2_relax = if (is_darwin)
    if (has_lse)
        ldadd2RelaxDarwinLse
    else
        ldadd2RelaxDarwinNolse
else if (has_lse)
    ldadd2RelaxNondarwinLse
else
    ldadd2RelaxNondarwinNolse;
fn ldclr2RelaxDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr2RelaxDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x40000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr2RelaxNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr2RelaxNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x40000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr2_relax = if (is_darwin)
    if (has_lse)
        ldclr2RelaxDarwinLse
    else
        ldclr2RelaxDarwinNolse
else if (has_lse)
    ldclr2RelaxNondarwinLse
else
    ldclr2RelaxNondarwinNolse;
fn ldeor2RelaxDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor2RelaxDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x40000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor2RelaxNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor2RelaxNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x40000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor2_relax = if (is_darwin)
    if (has_lse)
        ldeor2RelaxDarwinLse
    else
        ldeor2RelaxDarwinNolse
else if (has_lse)
    ldeor2RelaxNondarwinLse
else
    ldeor2RelaxNondarwinNolse;
fn ldset2RelaxDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldseth w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset2RelaxDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x40000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset2RelaxNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldseth w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset2RelaxNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x40000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset2_relax = if (is_darwin)
    if (has_lse)
        ldset2RelaxDarwinLse
    else
        ldset2RelaxDarwinNolse
else if (has_lse)
    ldset2RelaxNondarwinLse
else
    ldset2RelaxNondarwinNolse;
fn cas2AcqDarwinLse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casah w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldaxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas2AcqDarwinNolse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x40000000 + 0x400000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldaxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas2AcqNondarwinLse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casah w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldaxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas2AcqNondarwinNolse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x40000000 + 0x400000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldaxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas2_acq = if (is_darwin)
    if (has_lse)
        cas2AcqDarwinLse
    else
        cas2AcqDarwinNolse
else if (has_lse)
    cas2AcqNondarwinLse
else
    cas2AcqNondarwinNolse;
fn swp2AcqDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpah  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        stxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp2AcqDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x40000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        stxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp2AcqNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpah  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        stxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp2AcqNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x40000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        stxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp2_acq = if (is_darwin)
    if (has_lse)
        swp2AcqDarwinLse
    else
        swp2AcqDarwinNolse
else if (has_lse)
    swp2AcqNondarwinLse
else
    swp2AcqNondarwinNolse;
fn ldadd2AcqDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddah w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd2AcqDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x40000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd2AcqNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddah w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd2AcqNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x40000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd2_acq = if (is_darwin)
    if (has_lse)
        ldadd2AcqDarwinLse
    else
        ldadd2AcqDarwinNolse
else if (has_lse)
    ldadd2AcqNondarwinLse
else
    ldadd2AcqNondarwinNolse;
fn ldclr2AcqDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrah w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr2AcqDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x40000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr2AcqNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrah w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr2AcqNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x40000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr2_acq = if (is_darwin)
    if (has_lse)
        ldclr2AcqDarwinLse
    else
        ldclr2AcqDarwinNolse
else if (has_lse)
    ldclr2AcqNondarwinLse
else
    ldclr2AcqNondarwinNolse;
fn ldeor2AcqDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorah w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor2AcqDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x40000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor2AcqNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorah w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor2AcqNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x40000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor2_acq = if (is_darwin)
    if (has_lse)
        ldeor2AcqDarwinLse
    else
        ldeor2AcqDarwinNolse
else if (has_lse)
    ldeor2AcqNondarwinLse
else
    ldeor2AcqNondarwinNolse;
fn ldset2AcqDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetah w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset2AcqDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x40000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset2AcqNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetah w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset2AcqNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x40000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset2_acq = if (is_darwin)
    if (has_lse)
        ldset2AcqDarwinLse
    else
        ldset2AcqDarwinNolse
else if (has_lse)
    ldset2AcqNondarwinLse
else
    ldset2AcqNondarwinNolse;
fn cas2RelDarwinLse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        caslh w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas2RelDarwinNolse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x40000000 + 0x008000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas2RelNondarwinLse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        caslh w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas2RelNondarwinNolse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x40000000 + 0x008000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas2_rel = if (is_darwin)
    if (has_lse)
        cas2RelDarwinLse
    else
        cas2RelDarwinNolse
else if (has_lse)
    cas2RelNondarwinLse
else
    cas2RelNondarwinNolse;
fn swp2RelDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swplh  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        stlxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp2RelDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x40000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        stlxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp2RelNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swplh  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        stlxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp2RelNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x40000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        stlxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp2_rel = if (is_darwin)
    if (has_lse)
        swp2RelDarwinLse
    else
        swp2RelDarwinNolse
else if (has_lse)
    swp2RelNondarwinLse
else
    swp2RelNondarwinNolse;
fn ldadd2RelDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddlh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd2RelDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x40000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd2RelNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddlh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd2RelNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x40000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd2_rel = if (is_darwin)
    if (has_lse)
        ldadd2RelDarwinLse
    else
        ldadd2RelDarwinNolse
else if (has_lse)
    ldadd2RelNondarwinLse
else
    ldadd2RelNondarwinNolse;
fn ldclr2RelDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrlh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr2RelDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x40000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr2RelNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrlh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr2RelNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x40000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr2_rel = if (is_darwin)
    if (has_lse)
        ldclr2RelDarwinLse
    else
        ldclr2RelDarwinNolse
else if (has_lse)
    ldclr2RelNondarwinLse
else
    ldclr2RelNondarwinNolse;
fn ldeor2RelDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorlh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor2RelDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x40000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor2RelNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorlh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor2RelNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x40000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor2_rel = if (is_darwin)
    if (has_lse)
        ldeor2RelDarwinLse
    else
        ldeor2RelDarwinNolse
else if (has_lse)
    ldeor2RelNondarwinLse
else
    ldeor2RelNondarwinNolse;
fn ldset2RelDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetlh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset2RelDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x40000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset2RelNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetlh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset2RelNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x40000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset2_rel = if (is_darwin)
    if (has_lse)
        ldset2RelDarwinLse
    else
        ldset2RelDarwinNolse
else if (has_lse)
    ldset2RelNondarwinLse
else
    ldset2RelNondarwinNolse;
fn cas2AcqRelDarwinLse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casalh w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldaxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas2AcqRelDarwinNolse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x40000000 + 0x408000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldaxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas2AcqRelNondarwinLse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casalh w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldaxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas2AcqRelNondarwinNolse(expected: u16, desired: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x40000000 + 0x408000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        uxth    w16, w0
        \\0:
        \\        ldaxrh   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxrh   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas2_acq_rel = if (is_darwin)
    if (has_lse)
        cas2AcqRelDarwinLse
    else
        cas2AcqRelDarwinNolse
else if (has_lse)
    cas2AcqRelNondarwinLse
else
    cas2AcqRelNondarwinNolse;
fn swp2AcqRelDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpalh  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        stlxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp2AcqRelDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x40000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        stlxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp2AcqRelNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpalh  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        stlxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp2AcqRelNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x40000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        stlxrh   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp2_acq_rel = if (is_darwin)
    if (has_lse)
        swp2AcqRelDarwinLse
    else
        swp2AcqRelDarwinNolse
else if (has_lse)
    swp2AcqRelNondarwinLse
else
    swp2AcqRelNondarwinNolse;
fn ldadd2AcqRelDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddalh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd2AcqRelDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x40000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd2AcqRelNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddalh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd2AcqRelNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x40000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd2_acq_rel = if (is_darwin)
    if (has_lse)
        ldadd2AcqRelDarwinLse
    else
        ldadd2AcqRelDarwinNolse
else if (has_lse)
    ldadd2AcqRelNondarwinLse
else
    ldadd2AcqRelNondarwinNolse;
fn ldclr2AcqRelDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclralh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr2AcqRelDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x40000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr2AcqRelNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclralh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr2AcqRelNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x40000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr2_acq_rel = if (is_darwin)
    if (has_lse)
        ldclr2AcqRelDarwinLse
    else
        ldclr2AcqRelDarwinNolse
else if (has_lse)
    ldclr2AcqRelNondarwinLse
else
    ldclr2AcqRelNondarwinNolse;
fn ldeor2AcqRelDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeoralh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor2AcqRelDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x40000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor2AcqRelNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeoralh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor2AcqRelNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x40000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor2_acq_rel = if (is_darwin)
    if (has_lse)
        ldeor2AcqRelDarwinLse
    else
        ldeor2AcqRelDarwinNolse
else if (has_lse)
    ldeor2AcqRelNondarwinLse
else
    ldeor2AcqRelNondarwinNolse;
fn ldset2AcqRelDarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetalh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset2AcqRelDarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x40000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset2AcqRelNondarwinLse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetalh w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset2AcqRelNondarwinNolse(val: u16, ptr: *u16) callconv(.C) u16 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x40000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxrh   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxrh   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u16),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset2_acq_rel = if (is_darwin)
    if (has_lse)
        ldset2AcqRelDarwinLse
    else
        ldset2AcqRelDarwinNolse
else if (has_lse)
    ldset2AcqRelNondarwinLse
else
    ldset2AcqRelNondarwinNolse;
fn cas4RelaxDarwinLse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        cas w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas4RelaxDarwinNolse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x80000000 + 0x000000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas4RelaxNondarwinLse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        cas w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas4RelaxNondarwinNolse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x80000000 + 0x000000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas4_relax = if (is_darwin)
    if (has_lse)
        cas4RelaxDarwinLse
    else
        cas4RelaxDarwinNolse
else if (has_lse)
    cas4RelaxNondarwinLse
else
    cas4RelaxNondarwinNolse;
fn swp4RelaxDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swp  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        stxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp4RelaxDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x80000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        stxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp4RelaxNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swp  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        stxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp4RelaxNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x80000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        stxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp4_relax = if (is_darwin)
    if (has_lse)
        swp4RelaxDarwinLse
    else
        swp4RelaxDarwinNolse
else if (has_lse)
    swp4RelaxNondarwinLse
else
    swp4RelaxNondarwinNolse;
fn ldadd4RelaxDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldadd w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd4RelaxDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x80000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd4RelaxNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldadd w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd4RelaxNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x80000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd4_relax = if (is_darwin)
    if (has_lse)
        ldadd4RelaxDarwinLse
    else
        ldadd4RelaxDarwinNolse
else if (has_lse)
    ldadd4RelaxNondarwinLse
else
    ldadd4RelaxNondarwinNolse;
fn ldclr4RelaxDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclr w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr4RelaxDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x80000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr4RelaxNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclr w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr4RelaxNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x80000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr4_relax = if (is_darwin)
    if (has_lse)
        ldclr4RelaxDarwinLse
    else
        ldclr4RelaxDarwinNolse
else if (has_lse)
    ldclr4RelaxNondarwinLse
else
    ldclr4RelaxNondarwinNolse;
fn ldeor4RelaxDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeor w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor4RelaxDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x80000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor4RelaxNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeor w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor4RelaxNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x80000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor4_relax = if (is_darwin)
    if (has_lse)
        ldeor4RelaxDarwinLse
    else
        ldeor4RelaxDarwinNolse
else if (has_lse)
    ldeor4RelaxNondarwinLse
else
    ldeor4RelaxNondarwinNolse;
fn ldset4RelaxDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldset w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset4RelaxDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x80000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset4RelaxNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldset w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset4RelaxNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x80000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset4_relax = if (is_darwin)
    if (has_lse)
        ldset4RelaxDarwinLse
    else
        ldset4RelaxDarwinNolse
else if (has_lse)
    ldset4RelaxNondarwinLse
else
    ldset4RelaxNondarwinNolse;
fn cas4AcqDarwinLse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casa w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas4AcqDarwinNolse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x80000000 + 0x400000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas4AcqNondarwinLse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casa w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas4AcqNondarwinNolse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x80000000 + 0x400000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas4_acq = if (is_darwin)
    if (has_lse)
        cas4AcqDarwinLse
    else
        cas4AcqDarwinNolse
else if (has_lse)
    cas4AcqNondarwinLse
else
    cas4AcqNondarwinNolse;
fn swp4AcqDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpa  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        stxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp4AcqDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x80000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        stxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp4AcqNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpa  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        stxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp4AcqNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x80000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        stxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp4_acq = if (is_darwin)
    if (has_lse)
        swp4AcqDarwinLse
    else
        swp4AcqDarwinNolse
else if (has_lse)
    swp4AcqNondarwinLse
else
    swp4AcqNondarwinNolse;
fn ldadd4AcqDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldadda w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd4AcqDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x80000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd4AcqNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldadda w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd4AcqNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x80000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd4_acq = if (is_darwin)
    if (has_lse)
        ldadd4AcqDarwinLse
    else
        ldadd4AcqDarwinNolse
else if (has_lse)
    ldadd4AcqNondarwinLse
else
    ldadd4AcqNondarwinNolse;
fn ldclr4AcqDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclra w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr4AcqDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x80000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr4AcqNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclra w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr4AcqNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x80000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr4_acq = if (is_darwin)
    if (has_lse)
        ldclr4AcqDarwinLse
    else
        ldclr4AcqDarwinNolse
else if (has_lse)
    ldclr4AcqNondarwinLse
else
    ldclr4AcqNondarwinNolse;
fn ldeor4AcqDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeora w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor4AcqDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x80000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor4AcqNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeora w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor4AcqNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x80000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor4_acq = if (is_darwin)
    if (has_lse)
        ldeor4AcqDarwinLse
    else
        ldeor4AcqDarwinNolse
else if (has_lse)
    ldeor4AcqNondarwinLse
else
    ldeor4AcqNondarwinNolse;
fn ldset4AcqDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldseta w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset4AcqDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x80000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset4AcqNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldseta w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset4AcqNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x80000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset4_acq = if (is_darwin)
    if (has_lse)
        ldset4AcqDarwinLse
    else
        ldset4AcqDarwinNolse
else if (has_lse)
    ldset4AcqNondarwinLse
else
    ldset4AcqNondarwinNolse;
fn cas4RelDarwinLse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casl w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas4RelDarwinNolse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x80000000 + 0x008000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas4RelNondarwinLse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casl w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas4RelNondarwinNolse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x80000000 + 0x008000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas4_rel = if (is_darwin)
    if (has_lse)
        cas4RelDarwinLse
    else
        cas4RelDarwinNolse
else if (has_lse)
    cas4RelNondarwinLse
else
    cas4RelNondarwinNolse;
fn swp4RelDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpl  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        stlxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp4RelDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x80000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        stlxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp4RelNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpl  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        stlxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp4RelNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x80000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        stlxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp4_rel = if (is_darwin)
    if (has_lse)
        swp4RelDarwinLse
    else
        swp4RelDarwinNolse
else if (has_lse)
    swp4RelNondarwinLse
else
    swp4RelNondarwinNolse;
fn ldadd4RelDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddl w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd4RelDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x80000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd4RelNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddl w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd4RelNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x80000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd4_rel = if (is_darwin)
    if (has_lse)
        ldadd4RelDarwinLse
    else
        ldadd4RelDarwinNolse
else if (has_lse)
    ldadd4RelNondarwinLse
else
    ldadd4RelNondarwinNolse;
fn ldclr4RelDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrl w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr4RelDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x80000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr4RelNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrl w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr4RelNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x80000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr4_rel = if (is_darwin)
    if (has_lse)
        ldclr4RelDarwinLse
    else
        ldclr4RelDarwinNolse
else if (has_lse)
    ldclr4RelNondarwinLse
else
    ldclr4RelNondarwinNolse;
fn ldeor4RelDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorl w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor4RelDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x80000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor4RelNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorl w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor4RelNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x80000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor4_rel = if (is_darwin)
    if (has_lse)
        ldeor4RelDarwinLse
    else
        ldeor4RelDarwinNolse
else if (has_lse)
    ldeor4RelNondarwinLse
else
    ldeor4RelNondarwinNolse;
fn ldset4RelDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetl w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset4RelDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x80000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset4RelNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetl w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset4RelNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x80000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset4_rel = if (is_darwin)
    if (has_lse)
        ldset4RelDarwinLse
    else
        ldset4RelDarwinNolse
else if (has_lse)
    ldset4RelNondarwinLse
else
    ldset4RelNondarwinNolse;
fn cas4AcqRelDarwinLse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casal w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas4AcqRelDarwinNolse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x80000000 + 0x408000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas4AcqRelNondarwinLse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casal w0, w1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas4AcqRelNondarwinNolse(expected: u32, desired: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0x80000000 + 0x408000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x2]
        \\        cmp    w0, w16
        \\        bne    1f
        \\        stlxr   w17, w1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [expected] "{w0}" (expected),
          [desired] "{w1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas4_acq_rel = if (is_darwin)
    if (has_lse)
        cas4AcqRelDarwinLse
    else
        cas4AcqRelDarwinNolse
else if (has_lse)
    cas4AcqRelNondarwinLse
else
    cas4AcqRelNondarwinNolse;
fn swp4AcqRelDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpal  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        stlxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp4AcqRelDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x80000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        stlxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp4AcqRelNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpal  w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        stlxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp4AcqRelNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0x80000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        stlxr   w17, w16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp4_acq_rel = if (is_darwin)
    if (has_lse)
        swp4AcqRelDarwinLse
    else
        swp4AcqRelDarwinNolse
else if (has_lse)
    swp4AcqRelNondarwinLse
else
    swp4AcqRelNondarwinNolse;
fn ldadd4AcqRelDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddal w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd4AcqRelDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x80000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd4AcqRelNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddal w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd4AcqRelNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0x80000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        add     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd4_acq_rel = if (is_darwin)
    if (has_lse)
        ldadd4AcqRelDarwinLse
    else
        ldadd4AcqRelDarwinNolse
else if (has_lse)
    ldadd4AcqRelNondarwinLse
else
    ldadd4AcqRelNondarwinNolse;
fn ldclr4AcqRelDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclral w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr4AcqRelDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x80000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr4AcqRelNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclral w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr4AcqRelNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0x80000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        bic     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr4_acq_rel = if (is_darwin)
    if (has_lse)
        ldclr4AcqRelDarwinLse
    else
        ldclr4AcqRelDarwinNolse
else if (has_lse)
    ldclr4AcqRelNondarwinLse
else
    ldclr4AcqRelNondarwinNolse;
fn ldeor4AcqRelDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeoral w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor4AcqRelDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x80000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor4AcqRelNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeoral w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor4AcqRelNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0x80000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        eor     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor4_acq_rel = if (is_darwin)
    if (has_lse)
        ldeor4AcqRelDarwinLse
    else
        ldeor4AcqRelDarwinNolse
else if (has_lse)
    ldeor4AcqRelNondarwinLse
else
    ldeor4AcqRelNondarwinNolse;
fn ldset4AcqRelDarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetal w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset4AcqRelDarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x80000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset4AcqRelNondarwinLse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetal w0, w0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset4AcqRelNondarwinNolse(val: u32, ptr: *u32) callconv(.C) u32 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0x80000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    w16, w0
        \\0:
        \\        ldaxr   w0, [x1]
        \\        orr     w17, w0, w16
        \\        stlxr   w15, w17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={w0}" (-> u32),
        : [val] "{w0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset4_acq_rel = if (is_darwin)
    if (has_lse)
        ldset4AcqRelDarwinLse
    else
        ldset4AcqRelDarwinNolse
else if (has_lse)
    ldset4AcqRelNondarwinLse
else
    ldset4AcqRelNondarwinNolse;
fn cas8RelaxDarwinLse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        cas x0, x1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas8RelaxDarwinNolse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0xc0000000 + 0x000000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas8RelaxNondarwinLse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        cas x0, x1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas8RelaxNondarwinNolse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0xc0000000 + 0x000000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas8_relax = if (is_darwin)
    if (has_lse)
        cas8RelaxDarwinLse
    else
        cas8RelaxDarwinNolse
else if (has_lse)
    cas8RelaxNondarwinLse
else
    cas8RelaxNondarwinNolse;
fn swp8RelaxDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swp  x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        stxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp8RelaxDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0xc0000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        stxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp8RelaxNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swp  x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        stxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp8RelaxNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0xc0000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        stxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp8_relax = if (is_darwin)
    if (has_lse)
        swp8RelaxDarwinLse
    else
        swp8RelaxDarwinNolse
else if (has_lse)
    swp8RelaxNondarwinLse
else
    swp8RelaxNondarwinNolse;
fn ldadd8RelaxDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldadd x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd8RelaxDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0xc0000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd8RelaxNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldadd x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd8RelaxNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0xc0000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd8_relax = if (is_darwin)
    if (has_lse)
        ldadd8RelaxDarwinLse
    else
        ldadd8RelaxDarwinNolse
else if (has_lse)
    ldadd8RelaxNondarwinLse
else
    ldadd8RelaxNondarwinNolse;
fn ldclr8RelaxDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclr x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr8RelaxDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0xc0000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr8RelaxNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclr x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr8RelaxNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0xc0000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr8_relax = if (is_darwin)
    if (has_lse)
        ldclr8RelaxDarwinLse
    else
        ldclr8RelaxDarwinNolse
else if (has_lse)
    ldclr8RelaxNondarwinLse
else
    ldclr8RelaxNondarwinNolse;
fn ldeor8RelaxDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeor x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor8RelaxDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0xc0000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor8RelaxNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeor x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor8RelaxNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0xc0000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor8_relax = if (is_darwin)
    if (has_lse)
        ldeor8RelaxDarwinLse
    else
        ldeor8RelaxDarwinNolse
else if (has_lse)
    ldeor8RelaxNondarwinLse
else
    ldeor8RelaxNondarwinNolse;
fn ldset8RelaxDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldset x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset8RelaxDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0xc0000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset8RelaxNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldset x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset8RelaxNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0xc0000000 + 0x000000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset8_relax = if (is_darwin)
    if (has_lse)
        ldset8RelaxDarwinLse
    else
        ldset8RelaxDarwinNolse
else if (has_lse)
    ldset8RelaxNondarwinLse
else
    ldset8RelaxNondarwinNolse;
fn cas8AcqDarwinLse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casa x0, x1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas8AcqDarwinNolse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0xc0000000 + 0x400000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas8AcqNondarwinLse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casa x0, x1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas8AcqNondarwinNolse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0xc0000000 + 0x400000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas8_acq = if (is_darwin)
    if (has_lse)
        cas8AcqDarwinLse
    else
        cas8AcqDarwinNolse
else if (has_lse)
    cas8AcqNondarwinLse
else
    cas8AcqNondarwinNolse;
fn swp8AcqDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpa  x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        stxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp8AcqDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0xc0000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        stxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp8AcqNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpa  x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        stxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp8AcqNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0xc0000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        stxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp8_acq = if (is_darwin)
    if (has_lse)
        swp8AcqDarwinLse
    else
        swp8AcqDarwinNolse
else if (has_lse)
    swp8AcqNondarwinLse
else
    swp8AcqNondarwinNolse;
fn ldadd8AcqDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldadda x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd8AcqDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0xc0000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd8AcqNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldadda x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd8AcqNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0xc0000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd8_acq = if (is_darwin)
    if (has_lse)
        ldadd8AcqDarwinLse
    else
        ldadd8AcqDarwinNolse
else if (has_lse)
    ldadd8AcqNondarwinLse
else
    ldadd8AcqNondarwinNolse;
fn ldclr8AcqDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclra x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr8AcqDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0xc0000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr8AcqNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclra x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr8AcqNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0xc0000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr8_acq = if (is_darwin)
    if (has_lse)
        ldclr8AcqDarwinLse
    else
        ldclr8AcqDarwinNolse
else if (has_lse)
    ldclr8AcqNondarwinLse
else
    ldclr8AcqNondarwinNolse;
fn ldeor8AcqDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeora x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor8AcqDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0xc0000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor8AcqNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeora x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor8AcqNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0xc0000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor8_acq = if (is_darwin)
    if (has_lse)
        ldeor8AcqDarwinLse
    else
        ldeor8AcqDarwinNolse
else if (has_lse)
    ldeor8AcqNondarwinLse
else
    ldeor8AcqNondarwinNolse;
fn ldset8AcqDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldseta x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset8AcqDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0xc0000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset8AcqNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldseta x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset8AcqNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0xc0000000 + 0x800000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset8_acq = if (is_darwin)
    if (has_lse)
        ldset8AcqDarwinLse
    else
        ldset8AcqDarwinNolse
else if (has_lse)
    ldset8AcqNondarwinLse
else
    ldset8AcqNondarwinNolse;
fn cas8RelDarwinLse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casl x0, x1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stlxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas8RelDarwinNolse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0xc0000000 + 0x008000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stlxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas8RelNondarwinLse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casl x0, x1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stlxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas8RelNondarwinNolse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0xc0000000 + 0x008000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stlxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas8_rel = if (is_darwin)
    if (has_lse)
        cas8RelDarwinLse
    else
        cas8RelDarwinNolse
else if (has_lse)
    cas8RelNondarwinLse
else
    cas8RelNondarwinNolse;
fn swp8RelDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpl  x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        stlxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp8RelDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0xc0000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        stlxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp8RelNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpl  x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        stlxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp8RelNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0xc0000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        stlxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp8_rel = if (is_darwin)
    if (has_lse)
        swp8RelDarwinLse
    else
        swp8RelDarwinNolse
else if (has_lse)
    swp8RelNondarwinLse
else
    swp8RelNondarwinNolse;
fn ldadd8RelDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddl x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd8RelDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0xc0000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd8RelNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddl x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd8RelNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0xc0000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd8_rel = if (is_darwin)
    if (has_lse)
        ldadd8RelDarwinLse
    else
        ldadd8RelDarwinNolse
else if (has_lse)
    ldadd8RelNondarwinLse
else
    ldadd8RelNondarwinNolse;
fn ldclr8RelDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrl x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr8RelDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0xc0000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr8RelNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclrl x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr8RelNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0xc0000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr8_rel = if (is_darwin)
    if (has_lse)
        ldclr8RelDarwinLse
    else
        ldclr8RelDarwinNolse
else if (has_lse)
    ldclr8RelNondarwinLse
else
    ldclr8RelNondarwinNolse;
fn ldeor8RelDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorl x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor8RelDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0xc0000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor8RelNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeorl x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor8RelNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0xc0000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor8_rel = if (is_darwin)
    if (has_lse)
        ldeor8RelDarwinLse
    else
        ldeor8RelDarwinNolse
else if (has_lse)
    ldeor8RelNondarwinLse
else
    ldeor8RelNondarwinNolse;
fn ldset8RelDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetl x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset8RelDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0xc0000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset8RelNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetl x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset8RelNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0xc0000000 + 0x400000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset8_rel = if (is_darwin)
    if (has_lse)
        ldset8RelDarwinLse
    else
        ldset8RelDarwinNolse
else if (has_lse)
    ldset8RelNondarwinLse
else
    ldset8RelNondarwinNolse;
fn cas8AcqRelDarwinLse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casal x0, x1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stlxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas8AcqRelDarwinNolse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0xc0000000 + 0x408000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stlxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas8AcqRelNondarwinLse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casal x0, x1, [x2]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stlxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas8AcqRelNondarwinNolse(expected: u64, desired: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x08a07c41 + 0xc0000000 + 0x408000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x2]
        \\        cmp    x0, x16
        \\        bne    1f
        \\        stlxr   w17, x1, [x2]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas8_acq_rel = if (is_darwin)
    if (has_lse)
        cas8AcqRelDarwinLse
    else
        cas8AcqRelDarwinNolse
else if (has_lse)
    cas8AcqRelNondarwinLse
else
    cas8AcqRelNondarwinNolse;
fn swp8AcqRelDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpal  x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        stlxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp8AcqRelDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0xc0000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        stlxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp8AcqRelNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        swpal  x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        stlxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn swp8AcqRelNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38208020 + 0xc0000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        stlxr   w17, x16, [x1]
        \\        cbnz   w17, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_swp8_acq_rel = if (is_darwin)
    if (has_lse)
        swp8AcqRelDarwinLse
    else
        swp8AcqRelDarwinNolse
else if (has_lse)
    swp8AcqRelNondarwinLse
else
    swp8AcqRelNondarwinNolse;
fn ldadd8AcqRelDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddal x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd8AcqRelDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0xc0000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd8AcqRelNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldaddal x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldadd8AcqRelNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x0000 + 0xc0000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        add     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldadd8_acq_rel = if (is_darwin)
    if (has_lse)
        ldadd8AcqRelDarwinLse
    else
        ldadd8AcqRelDarwinNolse
else if (has_lse)
    ldadd8AcqRelNondarwinLse
else
    ldadd8AcqRelNondarwinNolse;
fn ldclr8AcqRelDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclral x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr8AcqRelDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0xc0000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr8AcqRelNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldclral x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldclr8AcqRelNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x1000 + 0xc0000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        bic     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldclr8_acq_rel = if (is_darwin)
    if (has_lse)
        ldclr8AcqRelDarwinLse
    else
        ldclr8AcqRelDarwinNolse
else if (has_lse)
    ldclr8AcqRelNondarwinLse
else
    ldclr8AcqRelNondarwinNolse;
fn ldeor8AcqRelDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeoral x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor8AcqRelDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0xc0000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor8AcqRelNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldeoral x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldeor8AcqRelNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x2000 + 0xc0000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        eor     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldeor8_acq_rel = if (is_darwin)
    if (has_lse)
        ldeor8AcqRelDarwinLse
    else
        ldeor8AcqRelDarwinNolse
else if (has_lse)
    ldeor8AcqRelNondarwinLse
else
    ldeor8AcqRelNondarwinNolse;
fn ldset8AcqRelDarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetal x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset8AcqRelDarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0xc0000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset8AcqRelNondarwinLse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        ldsetal x0, x0, [x1]
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn ldset8AcqRelNondarwinNolse(val: u64, ptr: *u64) callconv(.C) u64 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x38200020 + 0x3000 + 0xc0000000 + 0xc00000
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\0:
        \\        ldaxr   x0, [x1]
        \\        orr     x17, x0, x16
        \\        stlxr   w15, x17, [x1]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u64),
        : [val] "{x0}" (val),
          [ptr] "{x1}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_ldset8_acq_rel = if (is_darwin)
    if (has_lse)
        ldset8AcqRelDarwinLse
    else
        ldset8AcqRelDarwinNolse
else if (has_lse)
    ldset8AcqRelNondarwinLse
else
    ldset8AcqRelNondarwinNolse;
fn cas16RelaxDarwinLse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casp  x0, x1, x2, x3, [x4]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas16RelaxDarwinNolse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x48207c82 + 0x000000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas16RelaxNondarwinLse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        casp  x0, x1, x2, x3, [x4]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas16RelaxNondarwinNolse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x48207c82 + 0x000000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas16_relax = if (is_darwin)
    if (has_lse)
        cas16RelaxDarwinLse
    else
        cas16RelaxDarwinNolse
else if (has_lse)
    cas16RelaxNondarwinLse
else
    cas16RelaxNondarwinNolse;
fn cas16AcqDarwinLse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        caspa  x0, x1, x2, x3, [x4]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldaxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas16AcqDarwinNolse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x48207c82 + 0x400000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldaxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas16AcqNondarwinLse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        caspa  x0, x1, x2, x3, [x4]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldaxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas16AcqNondarwinNolse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x48207c82 + 0x400000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldaxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas16_acq = if (is_darwin)
    if (has_lse)
        cas16AcqDarwinLse
    else
        cas16AcqDarwinNolse
else if (has_lse)
    cas16AcqNondarwinLse
else
    cas16AcqNondarwinNolse;
fn cas16RelDarwinLse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        caspl  x0, x1, x2, x3, [x4]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stlxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas16RelDarwinNolse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x48207c82 + 0x008000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stlxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas16RelNondarwinLse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        caspl  x0, x1, x2, x3, [x4]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stlxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas16RelNondarwinNolse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x48207c82 + 0x008000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stlxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas16_rel = if (is_darwin)
    if (has_lse)
        cas16RelDarwinLse
    else
        cas16RelDarwinNolse
else if (has_lse)
    cas16RelNondarwinLse
else
    cas16RelNondarwinNolse;
fn cas16AcqRelDarwinLse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        caspal  x0, x1, x2, x3, [x4]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldaxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stlxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas16AcqRelDarwinNolse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x48207c82 + 0x408000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldaxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stlxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas16AcqRelNondarwinLse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        caspal  x0, x1, x2, x3, [x4]
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldaxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stlxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
fn cas16AcqRelNondarwinNolse(expected: u128, desired: u128, ptr: *u128) callconv(.C) u128 {
    @setRuntimeSafety(false);
    __init_aarch64_have_lse_atomics();

    return asm volatile (
        \\        cbz     w16, 8f
        \\        .inst 0x48207c82 + 0x408000
        \\
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    x16, x0
        \\        mov    x17, x1
        \\0:
        \\        ldaxp   x0, x1, [x4]
        \\        cmp    x0, x16
        \\        ccmp   x1, x17, #0, eq
        \\        bne    1f
        \\        stlxp   w15, x2, x3, [x4]
        \\        cbnz   w15, 0b
        \\1:
        : [ret] "={x0}" (-> u128),
        : [expected] "{x0}" (expected),
          [desired] "{x1}" (desired),
          [ptr] "{x2}" (ptr),
          [__aarch64_have_lse_atomics] "{w16}" (__aarch64_have_lse_atomics),
        : "w15", "w16", "w17", "memory"
    );
}
const __aarch64_cas16_acq_rel = if (is_darwin)
    if (has_lse)
        cas16AcqRelDarwinLse
    else
        cas16AcqRelDarwinNolse
else if (has_lse)
    cas16AcqRelNondarwinLse
else
    cas16AcqRelNondarwinNolse;
//TODO: Add linksection once implemented and remove init at writeFunction
fn __init_aarch64_have_lse_atomics() callconv(.C) void {
    const AT_HWCAP = 16;
    const HWCAP_ATOMICS = 1 << 8;
    const hwcap = std.os.linux.getauxval(AT_HWCAP);
    __aarch64_have_lse_atomics = @boolToInt((hwcap & HWCAP_ATOMICS) != 0);
}

var __aarch64_have_lse_atomics: u8 = @boolToInt(has_lse);

comptime {
    if (arch.isAARCH64()) {
        @export(__aarch64_cas1_relax, .{ .name = "__aarch64_cas1_relax", .linkage = linkage });
        @export(__aarch64_cas1_acq, .{ .name = "__aarch64_cas1_acq", .linkage = linkage });
        @export(__aarch64_cas1_rel, .{ .name = "__aarch64_cas1_rel", .linkage = linkage });
        @export(__aarch64_cas1_acq_rel, .{ .name = "__aarch64_cas1_acq_rel", .linkage = linkage });
        @export(__aarch64_cas2_relax, .{ .name = "__aarch64_cas2_relax", .linkage = linkage });
        @export(__aarch64_cas2_acq, .{ .name = "__aarch64_cas2_acq", .linkage = linkage });
        @export(__aarch64_cas2_rel, .{ .name = "__aarch64_cas2_rel", .linkage = linkage });
        @export(__aarch64_cas2_acq_rel, .{ .name = "__aarch64_cas2_acq_rel", .linkage = linkage });
        @export(__aarch64_cas4_relax, .{ .name = "__aarch64_cas4_relax", .linkage = linkage });
        @export(__aarch64_cas4_acq, .{ .name = "__aarch64_cas4_acq", .linkage = linkage });
        @export(__aarch64_cas4_rel, .{ .name = "__aarch64_cas4_rel", .linkage = linkage });
        @export(__aarch64_cas4_acq_rel, .{ .name = "__aarch64_cas4_acq_rel", .linkage = linkage });
        @export(__aarch64_cas8_relax, .{ .name = "__aarch64_cas8_relax", .linkage = linkage });
        @export(__aarch64_cas8_acq, .{ .name = "__aarch64_cas8_acq", .linkage = linkage });
        @export(__aarch64_cas8_rel, .{ .name = "__aarch64_cas8_rel", .linkage = linkage });
        @export(__aarch64_cas8_acq_rel, .{ .name = "__aarch64_cas8_acq_rel", .linkage = linkage });
        @export(__aarch64_cas16_relax, .{ .name = "__aarch64_cas16_relax", .linkage = linkage });
        @export(__aarch64_cas16_acq, .{ .name = "__aarch64_cas16_acq", .linkage = linkage });
        @export(__aarch64_cas16_rel, .{ .name = "__aarch64_cas16_rel", .linkage = linkage });
        @export(__aarch64_cas16_acq_rel, .{ .name = "__aarch64_cas16_acq_rel", .linkage = linkage });
        @export(__aarch64_swp1_relax, .{ .name = "__aarch64_swp1_relax", .linkage = linkage });
        @export(__aarch64_swp1_acq, .{ .name = "__aarch64_swp1_acq", .linkage = linkage });
        @export(__aarch64_swp1_rel, .{ .name = "__aarch64_swp1_rel", .linkage = linkage });
        @export(__aarch64_swp1_acq_rel, .{ .name = "__aarch64_swp1_acq_rel", .linkage = linkage });
        @export(__aarch64_swp2_relax, .{ .name = "__aarch64_swp2_relax", .linkage = linkage });
        @export(__aarch64_swp2_acq, .{ .name = "__aarch64_swp2_acq", .linkage = linkage });
        @export(__aarch64_swp2_rel, .{ .name = "__aarch64_swp2_rel", .linkage = linkage });
        @export(__aarch64_swp2_acq_rel, .{ .name = "__aarch64_swp2_acq_rel", .linkage = linkage });
        @export(__aarch64_swp4_relax, .{ .name = "__aarch64_swp4_relax", .linkage = linkage });
        @export(__aarch64_swp4_acq, .{ .name = "__aarch64_swp4_acq", .linkage = linkage });
        @export(__aarch64_swp4_rel, .{ .name = "__aarch64_swp4_rel", .linkage = linkage });
        @export(__aarch64_swp4_acq_rel, .{ .name = "__aarch64_swp4_acq_rel", .linkage = linkage });
        @export(__aarch64_swp8_relax, .{ .name = "__aarch64_swp8_relax", .linkage = linkage });
        @export(__aarch64_swp8_acq, .{ .name = "__aarch64_swp8_acq", .linkage = linkage });
        @export(__aarch64_swp8_rel, .{ .name = "__aarch64_swp8_rel", .linkage = linkage });
        @export(__aarch64_swp8_acq_rel, .{ .name = "__aarch64_swp8_acq_rel", .linkage = linkage });
        @export(__aarch64_ldadd1_relax, .{ .name = "__aarch64_ldadd1_relax", .linkage = linkage });
        @export(__aarch64_ldadd1_acq, .{ .name = "__aarch64_ldadd1_acq", .linkage = linkage });
        @export(__aarch64_ldadd1_rel, .{ .name = "__aarch64_ldadd1_rel", .linkage = linkage });
        @export(__aarch64_ldadd1_acq_rel, .{ .name = "__aarch64_ldadd1_acq_rel", .linkage = linkage });
        @export(__aarch64_ldadd2_relax, .{ .name = "__aarch64_ldadd2_relax", .linkage = linkage });
        @export(__aarch64_ldadd2_acq, .{ .name = "__aarch64_ldadd2_acq", .linkage = linkage });
        @export(__aarch64_ldadd2_rel, .{ .name = "__aarch64_ldadd2_rel", .linkage = linkage });
        @export(__aarch64_ldadd2_acq_rel, .{ .name = "__aarch64_ldadd2_acq_rel", .linkage = linkage });
        @export(__aarch64_ldadd4_relax, .{ .name = "__aarch64_ldadd4_relax", .linkage = linkage });
        @export(__aarch64_ldadd4_acq, .{ .name = "__aarch64_ldadd4_acq", .linkage = linkage });
        @export(__aarch64_ldadd4_rel, .{ .name = "__aarch64_ldadd4_rel", .linkage = linkage });
        @export(__aarch64_ldadd4_acq_rel, .{ .name = "__aarch64_ldadd4_acq_rel", .linkage = linkage });
        @export(__aarch64_ldadd8_relax, .{ .name = "__aarch64_ldadd8_relax", .linkage = linkage });
        @export(__aarch64_ldadd8_acq, .{ .name = "__aarch64_ldadd8_acq", .linkage = linkage });
        @export(__aarch64_ldadd8_rel, .{ .name = "__aarch64_ldadd8_rel", .linkage = linkage });
        @export(__aarch64_ldadd8_acq_rel, .{ .name = "__aarch64_ldadd8_acq_rel", .linkage = linkage });
        @export(__aarch64_ldclr1_relax, .{ .name = "__aarch64_ldclr1_relax", .linkage = linkage });
        @export(__aarch64_ldclr1_acq, .{ .name = "__aarch64_ldclr1_acq", .linkage = linkage });
        @export(__aarch64_ldclr1_rel, .{ .name = "__aarch64_ldclr1_rel", .linkage = linkage });
        @export(__aarch64_ldclr1_acq_rel, .{ .name = "__aarch64_ldclr1_acq_rel", .linkage = linkage });
        @export(__aarch64_ldclr2_relax, .{ .name = "__aarch64_ldclr2_relax", .linkage = linkage });
        @export(__aarch64_ldclr2_acq, .{ .name = "__aarch64_ldclr2_acq", .linkage = linkage });
        @export(__aarch64_ldclr2_rel, .{ .name = "__aarch64_ldclr2_rel", .linkage = linkage });
        @export(__aarch64_ldclr2_acq_rel, .{ .name = "__aarch64_ldclr2_acq_rel", .linkage = linkage });
        @export(__aarch64_ldclr4_relax, .{ .name = "__aarch64_ldclr4_relax", .linkage = linkage });
        @export(__aarch64_ldclr4_acq, .{ .name = "__aarch64_ldclr4_acq", .linkage = linkage });
        @export(__aarch64_ldclr4_rel, .{ .name = "__aarch64_ldclr4_rel", .linkage = linkage });
        @export(__aarch64_ldclr4_acq_rel, .{ .name = "__aarch64_ldclr4_acq_rel", .linkage = linkage });
        @export(__aarch64_ldclr8_relax, .{ .name = "__aarch64_ldclr8_relax", .linkage = linkage });
        @export(__aarch64_ldclr8_acq, .{ .name = "__aarch64_ldclr8_acq", .linkage = linkage });
        @export(__aarch64_ldclr8_rel, .{ .name = "__aarch64_ldclr8_rel", .linkage = linkage });
        @export(__aarch64_ldclr8_acq_rel, .{ .name = "__aarch64_ldclr8_acq_rel", .linkage = linkage });
        @export(__aarch64_ldeor1_relax, .{ .name = "__aarch64_ldeor1_relax", .linkage = linkage });
        @export(__aarch64_ldeor1_acq, .{ .name = "__aarch64_ldeor1_acq", .linkage = linkage });
        @export(__aarch64_ldeor1_rel, .{ .name = "__aarch64_ldeor1_rel", .linkage = linkage });
        @export(__aarch64_ldeor1_acq_rel, .{ .name = "__aarch64_ldeor1_acq_rel", .linkage = linkage });
        @export(__aarch64_ldeor2_relax, .{ .name = "__aarch64_ldeor2_relax", .linkage = linkage });
        @export(__aarch64_ldeor2_acq, .{ .name = "__aarch64_ldeor2_acq", .linkage = linkage });
        @export(__aarch64_ldeor2_rel, .{ .name = "__aarch64_ldeor2_rel", .linkage = linkage });
        @export(__aarch64_ldeor2_acq_rel, .{ .name = "__aarch64_ldeor2_acq_rel", .linkage = linkage });
        @export(__aarch64_ldeor4_relax, .{ .name = "__aarch64_ldeor4_relax", .linkage = linkage });
        @export(__aarch64_ldeor4_acq, .{ .name = "__aarch64_ldeor4_acq", .linkage = linkage });
        @export(__aarch64_ldeor4_rel, .{ .name = "__aarch64_ldeor4_rel", .linkage = linkage });
        @export(__aarch64_ldeor4_acq_rel, .{ .name = "__aarch64_ldeor4_acq_rel", .linkage = linkage });
        @export(__aarch64_ldeor8_relax, .{ .name = "__aarch64_ldeor8_relax", .linkage = linkage });
        @export(__aarch64_ldeor8_acq, .{ .name = "__aarch64_ldeor8_acq", .linkage = linkage });
        @export(__aarch64_ldeor8_rel, .{ .name = "__aarch64_ldeor8_rel", .linkage = linkage });
        @export(__aarch64_ldeor8_acq_rel, .{ .name = "__aarch64_ldeor8_acq_rel", .linkage = linkage });
        @export(__aarch64_ldset1_relax, .{ .name = "__aarch64_ldset1_relax", .linkage = linkage });
        @export(__aarch64_ldset1_acq, .{ .name = "__aarch64_ldset1_acq", .linkage = linkage });
        @export(__aarch64_ldset1_rel, .{ .name = "__aarch64_ldset1_rel", .linkage = linkage });
        @export(__aarch64_ldset1_acq_rel, .{ .name = "__aarch64_ldset1_acq_rel", .linkage = linkage });
        @export(__aarch64_ldset2_relax, .{ .name = "__aarch64_ldset2_relax", .linkage = linkage });
        @export(__aarch64_ldset2_acq, .{ .name = "__aarch64_ldset2_acq", .linkage = linkage });
        @export(__aarch64_ldset2_rel, .{ .name = "__aarch64_ldset2_rel", .linkage = linkage });
        @export(__aarch64_ldset2_acq_rel, .{ .name = "__aarch64_ldset2_acq_rel", .linkage = linkage });
        @export(__aarch64_ldset4_relax, .{ .name = "__aarch64_ldset4_relax", .linkage = linkage });
        @export(__aarch64_ldset4_acq, .{ .name = "__aarch64_ldset4_acq", .linkage = linkage });
        @export(__aarch64_ldset4_rel, .{ .name = "__aarch64_ldset4_rel", .linkage = linkage });
        @export(__aarch64_ldset4_acq_rel, .{ .name = "__aarch64_ldset4_acq_rel", .linkage = linkage });
        @export(__aarch64_ldset8_relax, .{ .name = "__aarch64_ldset8_relax", .linkage = linkage });
        @export(__aarch64_ldset8_acq, .{ .name = "__aarch64_ldset8_acq", .linkage = linkage });
        @export(__aarch64_ldset8_rel, .{ .name = "__aarch64_ldset8_rel", .linkage = linkage });
        @export(__aarch64_ldset8_acq_rel, .{ .name = "__aarch64_ldset8_acq_rel", .linkage = linkage });
    }
}
