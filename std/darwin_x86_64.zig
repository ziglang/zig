
pub const SYSCALL_CLASS_SHIFT = 24;
pub const SYSCALL_CLASS_MASK = 0xFF << SYSCALL_CLASS_SHIFT;
// pub const SYSCALL_NUMBER_MASK = ~SYSCALL_CLASS_MASK; // ~ modifier not supported yet

pub const SYSCALL_CLASS_NONE = 0; // Invalid
pub const SYSCALL_CLASS_MACH = 1; // Mach
pub const SYSCALL_CLASS_UNIX = 2; // Unix/BSD
pub const SYSCALL_CLASS_MDEP = 3; // Machine-dependent
pub const SYSCALL_CLASS_DIAG = 4; // Diagnostics

// TODO: use the above constants to create the below values

pub const SYS_read = 0x2000003;
pub const SYS_write = 0x2000004;
pub const SYS_open = 0x2000005;
pub const SYS_close = 0x2000006;
pub const SYS_kill = 0x2000025;
pub const SYS_getpid = 0x2000030;
pub const SYS_fstat = 0x20000BD;
pub const SYS_lseek = 0x20000C7;

pub inline fn syscall0(number: usize) -> usize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number)
        : "rcx", "r11")
}

pub inline fn syscall1(number: usize, arg1: usize) -> usize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1)
        : "rcx", "r11")
}

pub inline fn syscall2(number: usize, arg1: usize, arg2: usize) -> usize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2)
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




export struct stat {
    dev: u32,
    mode: u16,
    nlink: u16,
    ino: u64,
    uid: u32,
    gid: u32,
    rdev: u64,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,

    size: u64,
    blocks: u64,
    blksize: u32,
    flags: u32,
    gen: u32,
    lspare: i32,
    qspare: [2]u64,

}

export struct timespec {
    tv_sec: isize,
    tv_nsec: isize,
}
