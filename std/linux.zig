const SYS_read = switch (@compile_var("arch")) {
    x86_64 => 0,
    i386 => 3,
    else => unreachable{},
};
const SYS_write = switch (@compile_var("arch")) {
    x86_64 => 1,
    i386 => 4,
    else => unreachable{},
};
const SYS_open = switch (@compile_var("arch")) {
    x86_64 => 2,
    i386 => 5,
    else => unreachable{},
};
const SYS_close = switch (@compile_var("arch")) {
    x86_64 => 3,
    i386 => 6,
    else => unreachable{},
};
const SYS_creat = switch (@compile_var("arch")) {
    x86_64 => 85,
    i386 => 8,
    else => unreachable{},
};
const SYS_lseek = switch (@compile_var("arch")) {
    x86_64 => 8,
    i386 => 19,
    else => unreachable{},
};
const SYS_mmap = switch (@compile_var("arch")) {
    x86_64 => 9,
    i386 => 90,
    else => unreachable{},
};
const SYS_munmap = switch (@compile_var("arch")) {
    x86_64 => 11,
    i386 => 91,
    else => unreachable{},
};
const SYS_rt_sigprocmask = switch (@compile_var("arch")) {
    x86_64 => 14,
    i386 => 175,
    else => unreachable{},
};
const SYS_exit = switch (@compile_var("arch")) {
    x86_64 => 60,
    i386 => 1,
    else => unreachable{},
};
const SYS_kill = switch (@compile_var("arch")) {
    x86_64 => 62,
    i386 => 37,
    else => unreachable{},
};
const SYS_getgid = switch (@compile_var("arch")) {
    x86_64 => 104,
    i386 => 47,
    else => unreachable{},
};
const SYS_gettid = switch (@compile_var("arch")) {
    x86_64 => 186,
    i386 => 224,
    else => unreachable{},
};
const SYS_tkill = switch (@compile_var("arch")) {
    x86_64 => 200,
    i386 => 238,
    else => unreachable{},
};
const SYS_tgkill = switch (@compile_var("arch")) {
    x86_64 => 234,
    i386 => 270,
    else => unreachable{},
};
const SYS_openat = switch (@compile_var("arch")) {
    x86_64 => 257,
    i386 => 295,
    else => unreachable{},
};
const SYS_getrandom = switch (@compile_var("arch")) {
    x86_64 => 318,
    i386 => 355,
    else => unreachable{},
};

pub const MMAP_PROT_NONE =  0;
pub const MMAP_PROT_READ =  1;
pub const MMAP_PROT_WRITE = 2;
pub const MMAP_PROT_EXEC =  4;

pub const MMAP_MAP_FILE =    0;
pub const MMAP_MAP_SHARED =  1;
pub const MMAP_MAP_PRIVATE = 2;
pub const MMAP_MAP_FIXED =   16;
pub const MMAP_MAP_ANON =    32;

pub const O_RDONLY  = 0x0;
pub const O_WRONLY  = 0x1;
pub const O_RDWR    = 0x2;
pub const O_CREAT   = 0x40;
pub const O_EXCL    = 0x80;
pub const O_TRUNC   = 0x200;
pub const O_APPEND  = 0x400;
pub const O_SYNC    = 0x101000;

pub const SIGHUP    = 1;
pub const SIGINT    = 2;
pub const SIGQUIT   = 3;
pub const SIGILL    = 4;
pub const SIGTRAP   = 5;
pub const SIGABRT   = 6;
pub const SIGIOT    = SIGABRT;
pub const SIGBUS    = 7;
pub const SIGFPE    = 8;
pub const SIGKILL   = 9;
pub const SIGUSR1   = 10;
pub const SIGSEGV   = 11;
pub const SIGUSR2   = 12;
pub const SIGPIPE   = 13;
pub const SIGALRM   = 14;
pub const SIGTERM   = 15;
pub const SIGSTKFLT = 16;
pub const SIGCHLD   = 17;
pub const SIGCONT   = 18;
pub const SIGSTOP   = 19;
pub const SIGTSTP   = 20;
pub const SIGTTIN   = 21;
pub const SIGTTOU   = 22;
pub const SIGURG    = 23;
pub const SIGXCPU   = 24;
pub const SIGXFSZ   = 25;
pub const SIGVTALRM = 26;
pub const SIGPROF   = 27;
pub const SIGWINCH  = 28;
pub const SIGIO     = 29;
pub const SIGPOLL   = 29;
pub const SIGPWR    = 30;
pub const SIGSYS    = 31;
pub const SIGUNUSED = SIGSYS;

const SIG_BLOCK   = 0;
const SIG_UNBLOCK = 1;
const SIG_SETMASK = 2;

const syscall0 = switch (@compile_var("arch")) {
    x86_64 => x86_64_syscall0,
    i386 => i386_syscall0,
    else => unreachable{},
};
const syscall1 = switch (@compile_var("arch")) {
    x86_64 => x86_64_syscall1,
    i386 => i386_syscall1,
    else => unreachable{},
};
const syscall2 = switch (@compile_var("arch")) {
    x86_64 => x86_64_syscall2,
    i386 => i386_syscall2,
    else => unreachable{},
};
const syscall3 = switch (@compile_var("arch")) {
    x86_64 => x86_64_syscall3,
    i386 => i386_syscall3,
    else => unreachable{},
};
const syscall4 = switch (@compile_var("arch")) {
    x86_64 => x86_64_syscall4,
    i386 => i386_syscall4,
    else => unreachable{},
};
const syscall6 = switch (@compile_var("arch")) {
    x86_64 => x86_64_syscall6,
    i386 => i386_syscall6,
    else => unreachable{},
};

fn x86_64_syscall0(number: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number)
        : "rcx", "r11")
}

fn x86_64_syscall1(number: isize, arg1: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1)
        : "rcx", "r11")
}

fn x86_64_syscall2(number: isize, arg1: isize, arg2: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2)
        : "rcx", "r11")
}

fn x86_64_syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2),
            [arg3] "{rdx}" (arg3)
        : "rcx", "r11")
}

fn x86_64_syscall4(number: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2),
            [arg3] "{rdx}" (arg3),
            [arg4] "{r10}" (arg4)
        : "rcx", "r11")
}

fn x86_64_syscall6(number: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize, arg5: isize, arg6: isize) -> isize {
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

fn i386_syscall0(number: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number))
}

fn i386_syscall1(number: isize, arg1: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1))
}

fn i386_syscall2(number: isize, arg1: isize, arg2: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1),
            [arg2] "{ecx}" (arg2))
}

fn i386_syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1),
            [arg2] "{ecx}" (arg2),
            [arg3] "{edx}" (arg3))
}

fn i386_syscall4(number: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1),
            [arg2] "{ecx}" (arg2),
            [arg3] "{edx}" (arg3),
            [arg4] "{esi}" (arg4))
}

fn i386_syscall6(number: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize, arg5: isize, arg6: isize) -> isize {
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

pub fn mmap(address: ?&u8, length: isize, prot: isize, flags: isize, fd: isize, offset: isize) -> isize {
    // TODO ability to cast maybe pointer to isize
    const addr = if (const unwrapped ?= address) isize(unwrapped) else 0;
    syscall6(SYS_mmap, addr, length, prot, flags, fd, offset)
}

pub fn munmap(address: &u8, length: isize) -> isize {
    syscall2(SYS_munmap, isize(address), length)
}

pub fn read(fd: isize, buf: &u8, count: isize) -> isize {
    syscall3(SYS_read, isize(fd), isize(buf), count)
}

pub fn write(fd: isize, buf: &const u8, count: isize) -> isize {
    syscall3(SYS_write, isize(fd), isize(buf), count)
}

pub fn open(path: []u8, flags: isize, perm: isize) -> isize {
    var buf: [path.len + 1]u8 = undefined;
    @memcpy(&buf[0], &path[0], path.len);
    buf[path.len] = 0;
    syscall3(SYS_open, isize(&buf[0]), flags, perm)
}

pub fn create(path: []u8, perm: isize) -> isize {
    var buf: [path.len + 1]u8 = undefined;
    @memcpy(&buf[0], &path[0], path.len);
    buf[path.len] = 0;
    syscall2(SYS_creat, isize(&buf[0]), perm)
}

pub fn openat(dirfd: isize, path: []u8, flags: isize, mode: isize) -> isize {
    var buf: [path.len + 1]u8 = undefined;
    @memcpy(&buf[0], &path[0], path.len);
    buf[path.len] = 0;
    syscall4(SYS_openat, dirfd, isize(&buf[0]), flags, mode)
}

pub fn close(fd: isize) -> isize {
    syscall1(SYS_close, fd)
}

pub fn lseek(fd: isize, offset: isize, ref_pos: isize) -> isize {
    syscall3(SYS_lseek, fd, offset, ref_pos)
}

pub fn exit(status: i32) -> unreachable {
    syscall1(SYS_exit, isize(status));
    unreachable{}
}

pub fn getrandom(buf: &u8, count: isize, flags: u32) -> isize {
    syscall3(SYS_getrandom, isize(buf), count, isize(flags))
}

pub fn kill(pid: i32, sig: i32) -> i32 {
    i32(syscall2(SYS_kill, pid, sig))
}

const NSIG = 65;
const sigset_t = [128]u8;
const all_mask = []u8 { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, };
const app_mask = []u8 { 0xff, 0xff, 0xff, 0xfc, 0x7f, 0xff, 0xff, 0xff, };

pub fn raise(sig: i32) -> i32 {
    var set: sigset_t = undefined;
    block_app_signals(&set);
    const tid = i32(syscall0(SYS_gettid));
    const ret = i32(syscall2(SYS_tkill, tid, sig));
    restore_signals(&set);
    return ret;
}

fn block_all_signals(set: &sigset_t) {
    syscall4(SYS_rt_sigprocmask, SIG_BLOCK, isize(&all_mask), isize(set), NSIG/8);
}

fn block_app_signals(set: &sigset_t) {
    syscall4(SYS_rt_sigprocmask, SIG_BLOCK, isize(&app_mask), isize(set), NSIG/8);
}

fn restore_signals(set: &sigset_t) {
    syscall4(SYS_rt_sigprocmask, SIG_SETMASK, isize(set), 0, NSIG/8);
}
