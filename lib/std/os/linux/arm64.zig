usingnamespace @import("../bits.zig");

pub fn syscall0(number: usize) usize {
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize)
        : [number] "{x8}" (number)
        : "memory", "cc"
    );
}

pub fn syscall1(number: usize, arg1: usize) usize {
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize)
        : [number] "{x8}" (number),
          [arg1] "{x0}" (arg1)
        : "memory", "cc"
    );
}

pub fn syscall2(number: usize, arg1: usize, arg2: usize) usize {
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize)
        : [number] "{x8}" (number),
          [arg1] "{x0}" (arg1),
          [arg2] "{x1}" (arg2)
        : "memory", "cc"
    );
}

pub fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize)
        : [number] "{x8}" (number),
          [arg1] "{x0}" (arg1),
          [arg2] "{x1}" (arg2),
          [arg3] "{x2}" (arg3)
        : "memory", "cc"
    );
}

pub fn syscall4(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize)
        : [number] "{x8}" (number),
          [arg1] "{x0}" (arg1),
          [arg2] "{x1}" (arg2),
          [arg3] "{x2}" (arg3),
          [arg4] "{x3}" (arg4)
        : "memory", "cc"
    );
}

pub fn syscall5(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize)
        : [number] "{x8}" (number),
          [arg1] "{x0}" (arg1),
          [arg2] "{x1}" (arg2),
          [arg3] "{x2}" (arg3),
          [arg4] "{x3}" (arg4),
          [arg5] "{x4}" (arg5)
        : "memory", "cc"
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
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize)
        : [number] "{x8}" (number),
          [arg1] "{x0}" (arg1),
          [arg2] "{x1}" (arg2),
          [arg3] "{x2}" (arg3),
          [arg4] "{x3}" (arg4),
          [arg5] "{x4}" (arg5),
          [arg6] "{x5}" (arg6)
        : "memory", "cc"
    );
}

/// This matches the libc clone function.
pub extern fn clone(func: extern fn (arg: usize) u8, stack: usize, flags: u32, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub const restore = restore_rt;

pub fn restore_rt() callconv(.Naked) void {
    return asm volatile ("svc #0"
        :
        : [number] "{x8}" (@as(usize, SYS_rt_sigreturn))
        : "memory", "cc"
    );
}
