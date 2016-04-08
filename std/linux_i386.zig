pub const O_CREAT        = 0o100;
pub const O_EXCL         = 0o200;
pub const O_NOCTTY       = 0o400;
pub const O_TRUNC       = 0o1000;
pub const O_APPEND      = 0o2000;
pub const O_NONBLOCK    = 0o4000;
pub const O_DSYNC      = 0o10000;
pub const O_SYNC     = 0o4010000;
pub const O_RSYNC    = 0o4010000;
pub const O_DIRECTORY = 0o200000;
pub const O_NOFOLLOW  = 0o400000;
pub const O_CLOEXEC  = 0o2000000;

pub const O_ASYNC      = 0o20000;
pub const O_DIRECT     = 0o40000;
pub const O_LARGEFILE = 0o100000;
pub const O_NOATIME  = 0o1000000;
pub const O_PATH    = 0o10000000;
pub const O_TMPFILE = 0o20200000;
pub const O_NDELAY =  O_NONBLOCK;

pub const F_DUPFD  = 0;
pub const F_GETFD  = 1;
pub const F_SETFD  = 2;
pub const F_GETFL  = 3;
pub const F_SETFL  = 4;

pub const F_SETOWN = 8;
pub const F_GETOWN = 9;
pub const F_SETSIG = 10;
pub const F_GETSIG = 11;

pub const F_GETLK = 12;
pub const F_SETLK = 13;
pub const F_SETLKW = 14;

pub const F_SETOWN_EX = 15;
pub const F_GETOWN_EX = 16;

pub const F_GETOWNER_UIDS = 17;

pub fn syscall0(number: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number))
}

pub fn syscall1(number: isize, arg1: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1))
}

pub fn syscall2(number: isize, arg1: isize, arg2: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1),
            [arg2] "{ecx}" (arg2))
}

pub fn syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1),
            [arg2] "{ecx}" (arg2),
            [arg3] "{edx}" (arg3))
}

pub fn syscall4(number: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1),
            [arg2] "{ecx}" (arg2),
            [arg3] "{edx}" (arg3),
            [arg4] "{esi}" (arg4))
}

pub fn syscall6(number: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize, arg5: isize, arg6: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1),
            [arg2] "{ecx}" (arg2),
            [arg3] "{edx}" (arg3),
            [arg4] "{esi}" (arg4),
            [arg5] "{edi}" (arg5),
            [arg6] "{ebp}" (arg6))
}
