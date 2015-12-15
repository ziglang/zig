const SYS_write : isize = 1;
const SYS_exit : isize = 60;
const stdout_fileno : isize = 1;

fn syscall1(number: isize, arg1: isize) -> isize {
    asm volatile ("
        mov %[number], %%rax
        mov %[arg1], %%rdi
        syscall
        mov %%rax, %[ret]"
        : [ret] "=r" (return isize)
        : [number] "r" (number), [arg1] "r" (arg1)
        : "rcx", "r11", "rax", "rdi")
}

fn syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    asm volatile ("
        mov %[number], %%rax
        mov %[arg1], %%rdi
        mov %[arg2], %%rsi
        mov %[arg3], %%rdx
        syscall
        mov %%rax, %[ret]"
        : [ret] "=r" (return isize)
        : [number] "r" (number), [arg1] "r" (arg1), [arg2] "r" (arg2), [arg3] "r" (arg3)
        : "rcx", "r11", "rax", "rdi", "rsi", "rdx")
}

pub fn write(fd: isize, buf: &const u8, count: usize) -> isize {
    return syscall3(SYS_write, fd, buf as isize, count as isize);
}

pub fn exit(status: i32) -> unreachable {
    syscall1(SYS_exit, status as isize);
    unreachable;
}

// TODO error handling
// TODO handle buffering and flushing
pub fn print_str(str : string) -> isize {
    return write(stdout_fileno, str.ptr, str.len);
}
