fn syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    var result : isize;
    asm volatile ("
        mov %[number], %%rax
        mov %[arg1], %%rdi
        mov %[arg2], %%rsi
        mov %[arg3], %%rdx
        syscall
        mov %%rax, %[ret]"
        : [ret] "=m" (result)
        : [number] "r" (number), [arg1] "r" (arg1), [arg2] "r" (arg2), [arg3] "r" (arg3)
        : "rcx", "r11", "rax", "rdi", "rsi", "rdx");
    return result;
}

// TODO constants for SYS_write and stdout_fileno
pub fn write(fd: isize, buf: &const u8, count: usize) -> isize {
    const SYS_write : isize = 1;
    return syscall3(SYS_write, fd, buf as isize, count as isize);
}

// TODO error handling
// TODO handle buffering and flushing
pub fn print_str(str : string) -> isize {
    const stdout_fileno : isize = 1;
    return write(stdout_fileno, str.ptr, str.len);
}
