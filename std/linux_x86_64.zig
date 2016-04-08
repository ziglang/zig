pub const SYS_read = 0;
pub const SYS_write = 1;
pub const SYS_open = 2;
pub const SYS_close = 3;
pub const SYS_creat = 85;
pub const SYS_lseek = 8;
pub const SYS_mmap = 9;
pub const SYS_munmap = 11;
pub const SYS_rt_sigprocmask = 14;
pub const SYS_exit = 60;
pub const SYS_kill = 62;
pub const SYS_getgid = 104;
pub const SYS_gettid = 186;
pub const SYS_tkill = 200;
pub const SYS_tgkill = 234;
pub const SYS_openat = 257;
pub const SYS_getrandom = 318;

pub const O_CREAT =        0o100;
pub const O_EXCL =         0o200;
pub const O_NOCTTY =       0o400;
pub const O_TRUNC =       0o1000;
pub const O_APPEND =      0o2000;
pub const O_NONBLOCK =    0o4000;
pub const O_DSYNC =      0o10000;
pub const O_SYNC =     0o4010000;
pub const O_RSYNC =    0o4010000;
pub const O_DIRECTORY = 0o200000;
pub const O_NOFOLLOW =  0o400000;
pub const O_CLOEXEC =  0o2000000;

pub const O_ASYNC      = 0o20000;
pub const O_DIRECT     = 0o40000;
pub const O_LARGEFILE       =  0;
pub const O_NOATIME  = 0o1000000;
pub const O_PATH    = 0o10000000;
pub const O_TMPFILE = 0o20200000;
pub const O_NDELAY  = O_NONBLOCK;

pub const F_DUPFD = 0;
pub const F_GETFD = 1;
pub const F_SETFD = 2;
pub const F_GETFL = 3;
pub const F_SETFL = 4;

pub const F_SETOWN = 8;
pub const F_GETOWN = 9;
pub const F_SETSIG = 10;
pub const F_GETSIG = 11;

pub const F_GETLK = 5;
pub const F_SETLK = 6;
pub const F_SETLKW = 7;

pub const F_SETOWN_EX = 15;
pub const F_GETOWN_EX = 16;

pub const F_GETOWNER_UIDS = 17;

pub fn syscall0(number: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number)
        : "rcx", "r11")
}

pub fn syscall1(number: isize, arg1: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1)
        : "rcx", "r11")
}

pub fn syscall2(number: isize, arg1: isize, arg2: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2)
        : "rcx", "r11")
}

pub fn syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2),
            [arg3] "{rdx}" (arg3)
        : "rcx", "r11")
}

pub fn syscall4(number: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2),
            [arg3] "{rdx}" (arg3),
            [arg4] "{r10}" (arg4)
        : "rcx", "r11")
}

pub fn syscall6(number: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize, arg5: isize, arg6: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2),
            [arg3] "{rdx}" (arg3),
            [arg4] "{r10}" (arg4),
            [arg5] "{r8}" (arg5),
            [arg6] "{r9}" (arg6)
        : "rcx", "r11")
}
