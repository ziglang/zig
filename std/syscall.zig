// this file is specific to x86_64

const SYS_read           = 0;
const SYS_write          = 1;
const SYS_mmap           = 9;
const SYS_munmap         = 11;
const SYS_rt_sigprocmask = 14;
const SYS_exit           = 60;
const SYS_kill           = 62;
const SYS_getgid         = 104;
const SYS_gettid         = 186;
const SYS_tkill          = 200;
const SYS_tgkill         = 234;
const SYS_getrandom      = 318;

pub const MMAP_PROT_NONE =  0;
pub const MMAP_PROT_READ =  1;
pub const MMAP_PROT_WRITE = 2;
pub const MMAP_PROT_EXEC =  4;

pub const MMAP_MAP_FILE =    0;
pub const MMAP_MAP_SHARED =  1;
pub const MMAP_MAP_PRIVATE = 2;
pub const MMAP_MAP_FIXED =   16;
pub const MMAP_MAP_ANON =    32;

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

fn syscall0(number: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number)
        : "rcx", "r11")
}

fn syscall1(number: isize, arg1: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1)
        : "rcx", "r11")
}

fn syscall2(number: isize, arg1: isize, arg2: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2)
        : "rcx", "r11")
}

fn syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2),
            [arg3] "{rdx}" (arg3)
        : "rcx", "r11")
}

fn syscall4(number: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2),
            [arg3] "{rdx}" (arg3),
            [arg4] "{r10}" (arg4)
        : "rcx", "r11")
}

fn syscall6(number: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize, arg5: isize, arg6: isize) -> isize {
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

pub fn mmap(address: isize, length: isize, prot: isize, flags: isize, fd: isize, offset: isize) -> isize {
    syscall6(SYS_mmap, address, length, prot, flags, fd, offset)
}

pub fn munmap(address: isize, length: isize) -> isize {
    syscall2(SYS_munmap, address, length)
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
