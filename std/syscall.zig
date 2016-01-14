const SYS_read : usize = 0;
const SYS_write : usize = 1;
const SYS_exit : usize = 60;
const SYS_getrandom : usize = 318;

fn syscall1(number: usize, arg1: usize) usize => {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number), [arg1] "{rdi}" (arg1)
        : "rcx", "r11")
}

fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) usize => {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number), [arg1] "{rdi}" (arg1), [arg2] "{rsi}" (arg2), [arg3] "{rdx}" (arg3)
        : "rcx", "r11")
}

pub fn read(fd: isize, buf: &u8, count: usize) isize => {
    syscall3(SYS_read, fd as usize, buf as usize, count) as isize
}

pub fn write(fd: isize, buf: &const u8, count: usize) isize => {
    syscall3(SYS_write, fd as usize, buf as usize, count) as isize
}

pub fn exit(status: i32) unreachable => {
    syscall1(SYS_exit, status as usize);
    unreachable{}
}

pub fn getrandom(buf: &u8, count: usize, flags: u32) isize => {
    syscall3(SYS_getrandom, buf as usize, count, flags as usize) as isize
}

