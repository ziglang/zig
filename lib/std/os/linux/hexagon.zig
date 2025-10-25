const builtin = @import("builtin");
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

pub fn syscall0(number: SYS) u32 {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> u32),
        : [number] "{r6}" (@intFromEnum(number)),
        : .{ .memory = true });
}

pub fn syscall1(number: SYS, arg1: u32) u32 {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> u32),
        : [number] "{r6}" (@intFromEnum(number)),
          [arg1] "{r0}" (arg1),
        : .{ .memory = true });
}

pub fn syscall2(number: SYS, arg1: u32, arg2: u32) u32 {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> u32),
        : [number] "{r6}" (@intFromEnum(number)),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
        : .{ .memory = true });
}

pub fn syscall3(number: SYS, arg1: u32, arg2: u32, arg3: u32) u32 {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> u32),
        : [number] "{r6}" (@intFromEnum(number)),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
        : .{ .memory = true });
}

pub fn syscall4(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32) u32 {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> u32),
        : [number] "{r6}" (@intFromEnum(number)),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
          [arg4] "{r3}" (arg4),
        : .{ .memory = true });
}

pub fn syscall5(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32, arg5: u32) u32 {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> u32),
        : [number] "{r6}" (@intFromEnum(number)),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
          [arg4] "{r3}" (arg4),
          [arg5] "{r4}" (arg5),
        : .{ .memory = true });
}

pub fn syscall6(
    number: SYS,
    arg1: u32,
    arg2: u32,
    arg3: u32,
    arg4: u32,
    arg5: u32,
    arg6: u32,
) u32 {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> u32),
        : [number] "{r6}" (@intFromEnum(number)),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
          [arg4] "{r3}" (arg4),
          [arg5] "{r4}" (arg5),
          [arg6] "{r5}" (arg6),
        : .{ .memory = true });
}

pub fn clone() callconv(.naked) u32 {
    // __clone(func, stack, flags, arg, ptid, tls, ctid)
    //         r0,   r1,    r2,    r3,  r4,   r5,  +0
    //
    // syscall(SYS_clone, flags, stack, ptid, ctid, tls)
    //         r6         r0,    r1,    r2,   r3,   r4
    asm volatile (
        \\ allocframe(#8)
        \\
        \\ r11 = r0
        \\ r10 = r3
        \\
        \\ r6 = #220 // SYS_clone
        \\ r0 = r2
        \\ r1 = and(r1, #-8)
        \\ r2 = r4
        \\ r3 = memw(r30 + #8)
        \\ r4 = r5
        \\ trap0(#1)
        \\
        \\ p0 = cmp.eq(r0, #0)
        \\ if (!p0) dealloc_return
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\ .cfi_undefined r31
    );
    asm volatile (
        \\ r30 = #0
        \\ r31 = #0
        \\
        \\ r0 = r10
        \\ callr r11
        \\
        \\ r6 = #93 // SYS_exit
        \\ r0 = #0
        \\ trap0(#1)
    );
}

pub const time_t = i64;

pub const VDSO = void;
