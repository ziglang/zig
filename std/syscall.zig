const SYS_read      = 0;
const SYS_write     = 1;
const SYS_exit      = 60;
const SYS_getrandom = 318;

fn syscall1(number: isize, arg1: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number), [arg1] "{rdi}" (arg1)
        : "rcx", "r11")
}

fn syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number), [arg1] "{rdi}" (arg1), [arg2] "{rsi}" (arg2), [arg3] "{rdx}" (arg3)
        : "rcx", "r11")
}

pub fn read(fd: isize, buf: &u8, count: isize) -> isize {
    syscall3(SYS_read, isize(fd), isize(buf), count)
}

pub fn write(fd: isize, buf: &const u8, count: isize) -> isize {
    syscall3(SYS_write, isize(fd), isize(buf), count)
}

pub fn exit(status: i32) -> unreachable {
    syscall1(SYS_exit, isize(status));
    unreachable{}
}

pub fn getrandom(buf: &u8, count: isize, flags: u32) -> isize {
    syscall3(SYS_getrandom, isize(buf), count, isize(flags))
}
