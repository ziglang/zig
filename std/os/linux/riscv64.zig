pub fn syscall0(number: usize) usize {
    return asm volatile (
        \\ mv a7, %[number]
        \\ ecall
        \\ mv %[ret], a0
        : [ret] "=r" (-> usize)
        : [number] "r" (number)
        : "memory"
    );
}

pub fn syscall1(number: usize, arg1: usize) usize {
    return asm volatile (
        \\ mv a7, %[number]
        \\ mv a0, %[arg1]
        \\ ecall
        \\ mv %[ret], a0
        : [ret] "=r" (-> usize)
        : [number] "r" (number),
          [arg1] "r" (arg1)
        : "memory"
    );
}

pub fn syscall2(number: usize, arg1: usize, arg2: usize) usize {
    return asm volatile (
        \\ mv a7, %[number]
        \\ mv a0, %[arg1]
        \\ mv a1, %[arg2]
        \\ ecall
        \\ mv %[ret], a0
        : [ret] "=r" (-> usize)
        : [number] "r" (number),
          [arg1] "r" (arg1),
          [arg2] "r" (arg2)
        : "memory"
    );
}

pub fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile (
        \\ mv a7, %[number]
        \\ mv a0, %[arg1]
        \\ mv a1, %[arg2]
        \\ mv a2, %[arg3]
        \\ ecall
        \\ mv %[ret], a0
        : [ret] "=r" (-> usize)
        : [number] "r" (number),
          [arg1] "r" (arg1),
          [arg2] "r" (arg2),
          [arg3] "r" (arg3)
        : "memory"
    );
}

pub fn syscall4(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile (
        \\ mv a7, %[number]
        \\ mv a0, %[arg1]
        \\ mv a1, %[arg2]
        \\ mv a2, %[arg3]
        \\ mv a3, %[arg4]
        \\ ecall
        \\ mv %[ret], a0
        : [ret] "=r" (-> usize)
        : [number] "r" (number),
          [arg1] "r" (arg1),
          [arg2] "r" (arg2),
          [arg3] "r" (arg3),
          [arg4] "r" (arg4)
        : "memory"
    );
}

pub fn syscall5(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile (
        \\ mv a7, %[number]
        \\ mv a0, %[arg1]
        \\ mv a1, %[arg2]
        \\ mv a2, %[arg3]
        \\ mv a3, %[arg4]
        \\ mv a4, %[arg5]
        \\ ecall
        \\ mv %[ret], a0
        : [ret] "=r" (-> usize)
        : [number] "r" (number),
          [arg1] "r" (arg1),
          [arg2] "r" (arg2),
          [arg3] "r" (arg3),
          [arg4] "r" (arg4),
          [arg5] "r" (arg5)
        : "memory"
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
        \\ mv a7, %[number]
        \\ mv a0, %[arg1]
        \\ mv a1, %[arg2]
        \\ mv a2, %[arg3]
        \\ mv a3, %[arg4]
        \\ mv a4, %[arg5]
        \\ mv a5, %[arg6]
        \\ ecall
        \\ mv %[ret], a0
        : [ret] "=r" (-> usize)
        : [number] "r" (number),
          [arg1] "r" (arg1),
          [arg2] "r" (arg2),
          [arg3] "r" (arg3),
          [arg4] "r" (arg4),
          [arg5] "r" (arg5),
          [arg6] "r" (arg6)
        : "memory"
    );
}
