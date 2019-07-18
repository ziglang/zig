pub fn syscall0(number: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={a0}" (-> usize)
        : [number] "{a7}" (number)
        : "memory"
    );
}

pub fn syscall1(number: usize, arg1: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={a0}" (-> usize)
        : [number] "{a7}" (number),
          [arg1] "{a0}" (arg1)
    );
}

pub fn syscall2(number: usize, arg1: usize, arg2: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={a0}" (-> usize)
        : [number] "{a7}" (number),
          [arg1] "{a0}" (arg1),
          [arg2] "{a1}" (arg2)
    );
}

pub fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={a0}" (-> usize)
        : [number] "{a7}" (number),
          [arg1] "{a0}" (arg1),
          [arg2] "{a1}" (arg2),
          [arg3] "{a2}" (arg3)
    );
}

pub fn syscall4(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={a0}" (-> usize)
        : [number] "{a7}" (number),
          [arg1] "{a0}" (arg1),
          [arg2] "{a1}" (arg2),
          [arg3] "{a2}" (arg3),
          [arg4] "{a3}" (arg4)
    );
}

pub fn syscall5(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={a0}" (-> usize)
        : [number] "{a7}" (number),
          [arg1] "{a0}" (arg1),
          [arg2] "{a1}" (arg2),
          [arg3] "{a2}" (arg3),
          [arg4] "{a3}" (arg4),
          [arg5] "{a4}" (arg5)
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
    return asm volatile ("ecall"
        : [ret] "={a0}" (-> usize)
        : [number] "{a7}" (number),
          [arg1] "{a0}" (arg1),
          [arg2] "{a1}" (arg2),
          [arg3] "{a2}" (arg3),
          [arg4] "{a3}" (arg4),
          [arg5] "{a4}" (arg5),
          [arg6] "{a5}" (arg6)
    );
}
