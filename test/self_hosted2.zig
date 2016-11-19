pub const SYS_write = 1;
pub const SYS_exit = 60;
pub const stdout_fileno = 1;
const text = "hello\n";

export nakedcc fn _start() -> unreachable {
    myMain();
}

fn myMain() -> unreachable {
    write(stdout_fileno, &text[0], text.len);
    exit(0);
}

pub inline fn syscall1(number: usize, arg1: usize) -> usize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1)
        : "rcx", "r11")
}

pub inline fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) -> usize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2),
            [arg3] "{rdx}" (arg3)
        : "rcx", "r11")
}

pub fn write(fd: i32, buf: &const u8, count: usize) -> usize {
    syscall3(SYS_write, usize(fd), usize(buf), count)
}

pub fn exit(status: i32) -> unreachable {
    syscall1(SYS_exit, usize(status));
    @unreachable()
}

