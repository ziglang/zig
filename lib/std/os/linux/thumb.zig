//! The syscall interface is identical to the ARM one but we're facing an extra
//! challenge: r7, the register where the syscall number is stored, may be
//! reserved for the frame pointer.
//! Save and restore r7 around the syscall without touching the stack pointer not
//! to break the frame chain.
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

pub fn syscall0(number: SYS) u32 {
    var buf: [2]u32 = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> u32),
        : [tmp] "{r1}" (&buf),
        : .{ .memory = true });
}

pub fn syscall1(number: SYS, arg1: u32) u32 {
    var buf: [2]u32 = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> u32),
        : [tmp] "{r1}" (&buf),
          [arg1] "{r0}" (arg1),
        : .{ .memory = true });
}

pub fn syscall2(number: SYS, arg1: u32, arg2: u32) u32 {
    var buf: [2]u32 = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> u32),
        : [tmp] "{r2}" (&buf),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
        : .{ .memory = true });
}

pub fn syscall3(number: SYS, arg1: u32, arg2: u32, arg3: u32) u32 {
    var buf: [2]u32 = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> u32),
        : [tmp] "{r3}" (&buf),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
        : .{ .memory = true });
}

pub fn syscall4(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32) u32 {
    var buf: [2]u32 = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> u32),
        : [tmp] "{r4}" (&buf),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
          [arg4] "{r3}" (arg4),
        : .{ .memory = true });
}

pub fn syscall5(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32, arg5: u32) u32 {
    var buf: [2]u32 = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> u32),
        : [tmp] "{r5}" (&buf),
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
    var buf: [2]u32 = .{ @intFromEnum(number), undefined };
    return asm volatile (
        \\ str r7, [%[tmp], #4]
        \\ ldr r7, [%[tmp]]
        \\ svc #0
        \\ ldr r7, [%[tmp], #4]
        : [ret] "={r0}" (-> u32),
        : [tmp] "{r6}" (&buf),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
          [arg4] "{r3}" (arg4),
          [arg5] "{r4}" (arg5),
          [arg6] "{r5}" (arg6),
        : .{ .memory = true });
}

pub const clone = @import("arm.zig").clone;

pub fn restore() callconv(.naked) noreturn {
    asm volatile (
        \\ mov r7, %[number]
        \\ svc #0
        :
        : [number] "I" (@intFromEnum(SYS.sigreturn)),
    );
}

pub fn restore_rt() callconv(.naked) noreturn {
    asm volatile (
        \\ mov r7, %[number]
        \\ svc #0
        :
        : [number] "I" (@intFromEnum(SYS.rt_sigreturn)),
    );
}
