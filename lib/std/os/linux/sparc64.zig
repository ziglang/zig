usingnamespace @import("../bits.zig");

// TODO: Handle the case of pipe(2) returning multiple values.
// From syscall(2)'s manual page:
// Some architectures (namely, Alpha, IA-64, MIPS, SuperH, sparc/32, and sparc/64)
// use an additional register ("Retval2" in the above table) to pass back a second
// return value from the pipe(2) system call; Alpha uses this technique in the
// architecture-specific getxpid(2), getxuid(2), and getxgid(2) system calls
// as well. Other architectures do not use the second return value register in
// the system call interface, even if it is defined in the System V ABI.

pub fn syscall0(number: SYS) usize {
    return asm volatile (
        \\ t   0x6d
        \\ bcc %%xcc, 1f
        \\ neg %%o0
        \\ 1:
        : [ret] "={%o0}" (-> usize)
        : [number] "{%g1}" (@enumToInt(number))
        : "memory", "%o1", "%o2", "%o3", "%o4", "%o5", "%o7"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile (
        \\ t   0x6d
        \\ bcc %%xcc, 1f
        \\ neg %%o0
        \\ 1:
        : [ret] "={%o0}" (-> usize)
        : [number] "{%g1}" (@enumToInt(number)),
          [arg1] "{%o0}" (arg1)
        : "memory", "%o1", "%o2", "%o3", "%o4", "%o5", "%o7"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile (
        \\ t   0x6d
        \\ bcc %%xcc, 1f
        \\ neg %%o0
        \\ 1:
        : [ret] "={%o0}" (-> usize)
        : [number] "{%g1}" (@enumToInt(number)),
          [arg1] "{%o0}" (arg1),
          [arg2] "{%o1}" (arg2)
        : "memory", "%o1", "%o2", "%o3", "%o4", "%o5", "%o7"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile (
        \\ t   0x6d
        \\ bcc %%xcc, 1f
        \\ neg %%o0
        \\ 1:
        : [ret] "={%o0}" (-> usize)
        : [number] "{%g1}" (@enumToInt(number)),
          [arg1] "{%o0}" (arg1),
          [arg2] "{%o1}" (arg2),
          [arg3] "{%o2}" (arg3)
        : "memory", "%o1", "%o2", "%o3", "%o4", "%o5", "%o7"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile (
        \\ t   0x6d
        \\ bcc %%xcc, 1f
        \\ neg %%o0
        \\ 1:
        : [ret] "={%o0}" (-> usize)
        : [number] "{%g1}" (@enumToInt(number)),
          [arg1] "{%o0}" (arg1),
          [arg2] "{%o1}" (arg2),
          [arg3] "{%o2}" (arg3),
          [arg4] "{%o3}" (arg4)
        : "memory", "%o1", "%o2", "%o3", "%o4", "%o5", "%o7"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile (
        \\ t   0x6d
        \\ bcc %%xcc, 1f
        \\ neg %%o0
        \\ 1:
        : [ret] "={%o0}" (-> usize)
        : [number] "{%g1}" (@enumToInt(number)),
          [arg1] "{%o0}" (arg1),
          [arg2] "{%o1}" (arg2),
          [arg3] "{%o2}" (arg3),
          [arg4] "{%o3}" (arg4),
          [arg5] "{%o4}" (arg5),
        : "memory", "%o1", "%o2", "%o3", "%o4", "%o5", "%o7"
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
    return asm volatile (
        \\ t   0x6d
        \\ bcc %%xcc, 1f
        \\ neg %%o0
        \\ 1:
        : [ret] "={%o0}" (-> usize)
        : [number] "{%g1}" (@enumToInt(number)),
          [arg1] "{%o0}" (arg1),
          [arg2] "{%o1}" (arg2),
          [arg3] "{%o2}" (arg3),
          [arg4] "{%o3}" (arg4),
          [arg5] "{%o4}" (arg5),
          [arg6] "{%o5}" (arg6),
        : "memory", "%o1", "%o2", "%o3", "%o4", "%o5", "%o7"
    );
}

/// This matches the libc clone function.
pub extern fn clone(func: fn (arg: usize) callconv(.C) u8, stack: usize, flags: usize, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub const restore = restore_rt;

pub fn restore_rt() callconv(.Naked) void {
    return asm volatile ("t 0x6d"
        :
        : [number] "{%g1}" (@enumToInt(SYS.rt_sigreturn))
        : "memory", "%o0", "%o1", "%o2", "%o3", "%o4", "%o5", "%o7"
    );
}
