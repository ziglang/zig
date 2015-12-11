fn syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    let mut result : isize;
    asm volatile (
        "mov %[number], %%rax\n"
        "mov %[arg1], %%rdi\n"
        "mov %[arg2], %%rsi\n"
        "mov %[arg3], %%rdx\n"
        "syscall\n"
        "mov %%rax, %[ret]\n"
        : [ret] "=r" (result)
        : [number] "r" (number), [arg1] "r" (arg1), [arg2] "r" (arg2), [arg3] "r" (arg3)
        : "rcx", "r11", "rax", "rdi", "rsi", "rdx");
    return result;
}

// TODO error handling
// TODO zig strings instead of C strings
// TODO handle buffering and flushing
pub print_str(str : *const u8, len: isize) {
    let SYS_write = 1;
    let stdout_fileno = 1;
    syscall3(SYS_write, stdout_fileno, str as isize, str_len);
}
