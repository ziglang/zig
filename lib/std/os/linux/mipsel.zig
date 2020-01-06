usingnamespace @import("../bits.zig");

pub fn syscall0(number: usize) usize {
    return asm volatile (
        \\ syscall
        \\ blez $7, 1f
        \\ subu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize)
        : [number] "{$2}" (number)
        : "memory", "cc", "$7"
    );
}

pub fn syscall_pipe(fd: *[2]i32) usize {
    return asm volatile (
        \\ .set noat
        \\ .set noreorder
        \\ syscall
        \\ blez $7, 1f
        \\ nop
        \\ b 2f
        \\ subu $2, $0, $2
        \\ 1:
        \\ sw $2, 0($4)
        \\ sw $3, 4($4)
        \\ 2:
        : [ret] "={$2}" (-> usize)
        : [number] "{$2}" (@as(usize, SYS_pipe))
        : "memory", "cc", "$7"
    );
}

pub fn syscall1(number: usize, arg1: usize) usize {
    return asm volatile (
        \\ syscall
        \\ blez $7, 1f
        \\ subu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize)
        : [number] "{$2}" (number),
          [arg1] "{$4}" (arg1)
        : "memory", "cc", "$7"
    );
}

pub fn syscall2(number: usize, arg1: usize, arg2: usize) usize {
    return asm volatile (
        \\ syscall
        \\ blez $7, 1f
        \\ subu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize)
        : [number] "{$2}" (number),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2)
        : "memory", "cc", "$7"
    );
}

pub fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile (
        \\ syscall
        \\ blez $7, 1f
        \\ subu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize)
        : [number] "{$2}" (number),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3)
        : "memory", "cc", "$7"
    );
}

pub fn syscall4(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile (
        \\ syscall
        \\ blez $7, 1f
        \\ subu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize)
        : [number] "{$2}" (number),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4)
        : "memory", "cc", "$7"
    );
}

pub fn syscall5(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile (
        \\ .set noat
        \\ subu $sp, $sp, 24
        \\ sw %[arg5], 16($sp)
        \\ syscall
        \\ addu $sp, $sp, 24
        \\ blez $7, 1f
        \\ subu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize)
        : [number] "{$2}" (number),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
          [arg5] "r" (arg5)
        : "memory", "cc", "$7"
    );
}

pub fn syscall6(
    number: usize,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
    arg6: usize,
) usize {
    return asm volatile (
        \\ .set noat
        \\ subu $sp, $sp, 24
        \\ sw %[arg5], 16($sp)
        \\ sw %[arg6], 20($sp)
        \\ syscall
        \\ addu $sp, $sp, 24
        \\ blez $7, 1f
        \\ subu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize)
        : [number] "{$2}" (number),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
          [arg5] "r" (arg5),
          [arg6] "r" (arg6)
        : "memory", "cc", "$7"
    );
}

/// This matches the libc clone function.
pub extern fn clone(func: extern fn (arg: usize) u8, stack: usize, flags: u32, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub fn restore() callconv(.Naked) void {
    return asm volatile ("syscall"
        :
        : [number] "{$2}" (@as(usize, SYS_sigreturn))
        : "memory", "cc", "$7"
    );
}

pub fn restore_rt() callconv(.Naked) void {
    return asm volatile ("syscall"
        :
        : [number] "{$2}" (@as(usize, SYS_rt_sigreturn))
        : "memory", "cc", "$7"
    );
}
