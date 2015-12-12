fn syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    let mut result : isize;
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

// TODO error handling
// TODO handle buffering and flushing
// TODO non-i32 integer literals so we can remove the casts
// TODO constants for SYS_write and stdout_fileno
pub fn print_str(str : string) -> isize {
    let SYS_write = 1;
    let stdout_fileno = 1;
    return syscall3(SYS_write as isize, stdout_fileno as isize, str.ptr as isize, str.len as isize);
}
