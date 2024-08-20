//! The syscall interface is identical to the ARM one but we're facing an extra
//! challenge: r7, the register where the syscall number is stored, may be
//! reserved for the frame pointer.
//! Save and restore r7 around the syscall without touching the stack pointer not
//! to break the frame chain.
const std = @import("../../std.zig");
const linux = std.os.linux;
const SYS = linux.SYS;

pub fn syscall0(number: SYS) usize {
    @setRuntimeSafety(false);

    var buf: [2]usize = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> usize),
        : [tmp] "{r1}" (&buf),
        : "memory"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    @setRuntimeSafety(false);

    var buf: [2]usize = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> usize),
        : [tmp] "{r1}" (&buf),
          [arg1] "{r0}" (arg1),
        : "memory"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    @setRuntimeSafety(false);

    var buf: [2]usize = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> usize),
        : [tmp] "{r2}" (&buf),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
        : "memory"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    @setRuntimeSafety(false);

    var buf: [2]usize = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> usize),
        : [tmp] "{r3}" (&buf),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
        : "memory"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    @setRuntimeSafety(false);

    var buf: [2]usize = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> usize),
        : [tmp] "{r4}" (&buf),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
          [arg4] "{r3}" (arg4),
        : "memory"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    @setRuntimeSafety(false);

    var buf: [2]usize = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> usize),
        : [tmp] "{r5}" (&buf),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
          [arg4] "{r3}" (arg4),
          [arg5] "{r4}" (arg5),
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
    @setRuntimeSafety(false);

    var buf: [2]usize = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> usize),
        : [tmp] "{r6}" (&buf),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
          [arg4] "{r3}" (arg4),
          [arg5] "{r4}" (arg5),
          [arg6] "{r5}" (arg6),
        : "memory"
    );
}

pub const clone = @import("arm-eabi.zig").clone;

pub fn restore() callconv(.Naked) noreturn {
    asm volatile (
        \\ mov r7, %[number]
        \\ svc #0
        :
        : [number] "I" (@intFromEnum(SYS.sigreturn)),
    );
}

pub fn restore_rt() callconv(.Naked) noreturn {
    asm volatile (
        \\ mov r7, %[number]
        \\ svc #0
        :
        : [number] "I" (@intFromEnum(SYS.rt_sigreturn)),
        : "memory"
    );
}
