const SYS_write : isize = 1;
const SYS_exit : isize = 60;
const stdout_fileno : isize = 1;

fn syscall1(number: isize, arg1: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (return isize)
        : [number] "{rax}" (number), [arg1] "{rdi}" (arg1)
        : "rcx", "r11")
}

fn syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (return isize)
        : [number] "{rax}" (number), [arg1] "{rdi}" (arg1), [arg2] "{rsi}" (arg2), [arg3] "{rdx}" (arg3)
        : "rcx", "r11")
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
