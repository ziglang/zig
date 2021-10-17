const std = @import("../../std.zig");
const uid_t = std.os.linux.uid_t;
const gid_t = std.os.linux.gid_t;
const pid_t = std.os.linux.pid_t;
const timespec = std.os.linux.timespec;

pub fn syscall0(number: SYS) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize),
        : [number] "{x17}" (@enumToInt(number)),
        : "memory"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize),
        : [number] "{x17}" (@enumToInt(number)),
          [arg1] "{x10}" (arg1),
        : "memory"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize),
        : [number] "{x17}" (@enumToInt(number)),
          [arg1] "{x10}" (arg1),
          [arg2] "{x11}" (arg2),
        : "memory"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize),
        : [number] "{x17}" (@enumToInt(number)),
          [arg1] "{x10}" (arg1),
          [arg2] "{x11}" (arg2),
          [arg3] "{x12}" (arg3),
        : "memory"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize),
        : [number] "{x17}" (@enumToInt(number)),
          [arg1] "{x10}" (arg1),
          [arg2] "{x11}" (arg2),
          [arg3] "{x12}" (arg3),
          [arg4] "{x13}" (arg4),
        : "memory"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize),
        : [number] "{x17}" (@enumToInt(number)),
          [arg1] "{x10}" (arg1),
          [arg2] "{x11}" (arg2),
          [arg3] "{x12}" (arg3),
          [arg4] "{x13}" (arg4),
          [arg5] "{x14}" (arg5),
        : "memory"
    );
}

pub fn syscall6(
    number: SYS,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
    arg6: usize,
) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize),
        : [number] "{x17}" (@enumToInt(number)),
          [arg1] "{x10}" (arg1),
          [arg2] "{x11}" (arg2),
          [arg3] "{x12}" (arg3),
          [arg4] "{x13}" (arg4),
          [arg5] "{x14}" (arg5),
          [arg6] "{x15}" (arg6),
        : "memory"
    );
}

pub extern fn clone(func: fn (arg: usize) callconv(.C) u8, stack: usize, flags: u32, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub const restore = restore_rt;

pub fn restore_rt() callconv(.Naked) void {
    return asm volatile ("ecall"
        :
        : [number] "{x17}" (@enumToInt(SYS.rt_sigreturn)),
        : "memory"
    );
}

pub const SYS = enum(usize) {
    pub const arch_specific_syscall = 244;

    io_setup = 0,
    io_destroy = 1,
    io_submit = 2,
    io_cancel = 3,
    io_getevents = 4,
    setxattr = 5,
    lsetxattr = 6,
    fsetxattr = 7,
    getxattr = 8,
    lgetxattr = 9,
    fgetxattr = 10,
    listxattr = 11,
    llistxattr = 12,
    flistxattr = 13,
    removexattr = 14,
    lremovexattr = 15,
    fremovexattr = 16,
    getcwd = 17,
    lookup_dcookie = 18,
    eventfd2 = 19,
    epoll_create1 = 20,
    epoll_ctl = 21,
    epoll_pwait = 22,
    dup = 23,
    dup3 = 24,
    fcntl = 25,
    inotify_init1 = 26,
    inotify_add_watch = 27,
    inotify_rm_watch = 28,
    ioctl = 29,
    ioprio_set = 30,
    ioprio_get = 31,
    flock = 32,
    mknodat = 33,
    mkdirat = 34,
    unlinkat = 35,
    symlinkat = 36,
    linkat = 37,
    umount2 = 39,
    mount = 40,
    pivot_root = 41,
    nfsservctl = 42,
    statfs = 43,
    fstatfs = 44,
    truncate = 45,
    ftruncate = 46,
    fallocate = 47,
    faccessat = 48,
    chdir = 49,
    fchdir = 50,
    chroot = 51,
    fchmod = 52,
    fchmodat = 53,
    fchownat = 54,
    fchown = 55,
    openat = 56,
    close = 57,
    vhangup = 58,
    pipe2 = 59,
    quotactl = 60,
    getdents64 = 61,
    lseek = 62,
    read = 63,
    write = 64,
    readv = 65,
    writev = 66,
    pread64 = 67,
    pwrite64 = 68,
    preadv = 69,
    pwritev = 70,
    sendfile = 71,
    pselect6 = 72,
    ppoll = 73,
    signalfd4 = 74,
    vmsplice = 75,
    splice = 76,
    tee = 77,
    readlinkat = 78,
    fstatat = 79,
    fstat = 80,
    sync = 81,
    fsync = 82,
    fdatasync = 83,
    sync_file_range = 84,
    timerfd_create = 85,
    timerfd_settime = 86,
    timerfd_gettime = 87,
    utimensat = 88,
    acct = 89,
    capget = 90,
    capset = 91,
    personality = 92,
    exit = 93,
    exit_group = 94,
    waitid = 95,
    set_tid_address = 96,
    unshare = 97,
    futex = 98,
    set_robust_list = 99,
    get_robust_list = 100,
    nanosleep = 101,
    getitimer = 102,
    setitimer = 103,
    kexec_load = 104,
    init_module = 105,
    delete_module = 106,
    timer_create = 107,
    timer_gettime = 108,
    timer_getoverrun = 109,
    timer_settime = 110,
    timer_delete = 111,
    clock_settime = 112,
    clock_gettime = 113,
    clock_getres = 114,
    clock_nanosleep = 115,
    syslog = 116,
    ptrace = 117,
    sched_setparam = 118,
    sched_setscheduler = 119,
    sched_getscheduler = 120,
    sched_getparam = 121,
    sched_setaffinity = 122,
    sched_getaffinity = 123,
    sched_yield = 124,
    sched_get_priority_max = 125,
    sched_get_priority_min = 126,
    sched_rr_get_interval = 127,
    restart_syscall = 128,
    kill = 129,
    tkill = 130,
    tgkill = 131,
    sigaltstack = 132,
    rt_sigsuspend = 133,
    rt_sigaction = 134,
    rt_sigprocmask = 135,
    rt_sigpending = 136,
    rt_sigtimedwait = 137,
    rt_sigqueueinfo = 138,
    rt_sigreturn = 139,
    setpriority = 140,
    getpriority = 141,
    reboot = 142,
    setregid = 143,
    setgid = 144,
    setreuid = 145,
    setuid = 146,
    setresuid = 147,
    getresuid = 148,
    setresgid = 149,
    getresgid = 150,
    setfsuid = 151,
    setfsgid = 152,
    times = 153,
    setpgid = 154,
    getpgid = 155,
    getsid = 156,
    setsid = 157,
    getgroups = 158,
    setgroups = 159,
    uname = 160,
    sethostname = 161,
    setdomainname = 162,
    getrlimit = 163,
    setrlimit = 164,
    getrusage = 165,
    umask = 166,
    prctl = 167,
    getcpu = 168,
    gettimeofday = 169,
    settimeofday = 170,
    adjtimex = 171,
    getpid = 172,
    getppid = 173,
    getuid = 174,
    geteuid = 175,
    getgid = 176,
    getegid = 177,
    gettid = 178,
    sysinfo = 179,
    mq_open = 180,
    mq_unlink = 181,
    mq_timedsend = 182,
    mq_timedreceive = 183,
    mq_notify = 184,
    mq_getsetattr = 185,
    msgget = 186,
    msgctl = 187,
    msgrcv = 188,
    msgsnd = 189,
    semget = 190,
    semctl = 191,
    semtimedop = 192,
    semop = 193,
    shmget = 194,
    shmctl = 195,
    shmat = 196,
    shmdt = 197,
    socket = 198,
    socketpair = 199,
    bind = 200,
    listen = 201,
    accept = 202,
    connect = 203,
    getsockname = 204,
    getpeername = 205,
    sendto = 206,
    recvfrom = 207,
    setsockopt = 208,
    getsockopt = 209,
    shutdown = 210,
    sendmsg = 211,
    recvmsg = 212,
    readahead = 213,
    brk = 214,
    munmap = 215,
    mremap = 216,
    add_key = 217,
    request_key = 218,
    keyctl = 219,
    clone = 220,
    execve = 221,
    mmap = 222,
    fadvise64 = 223,
    swapon = 224,
    swapoff = 225,
    mprotect = 226,
    msync = 227,
    mlock = 228,
    munlock = 229,
    mlockall = 230,
    munlockall = 231,
    mincore = 232,
    madvise = 233,
    remap_file_pages = 234,
    mbind = 235,
    get_mempolicy = 236,
    set_mempolicy = 237,
    migrate_pages = 238,
    move_pages = 239,
    rt_tgsigqueueinfo = 240,
    perf_event_open = 241,
    accept4 = 242,
    recvmmsg = 243,

    riscv_flush_icache = arch_specific_syscall + 15,

    wait4 = 260,
    prlimit64 = 261,
    fanotify_init = 262,
    fanotify_mark = 263,
    name_to_handle_at = 264,
    open_by_handle_at = 265,
    clock_adjtime = 266,
    syncfs = 267,
    setns = 268,
    sendmmsg = 269,
    process_vm_readv = 270,
    process_vm_writev = 271,
    kcmp = 272,
    finit_module = 273,
    sched_setattr = 274,
    sched_getattr = 275,
    renameat2 = 276,
    seccomp = 277,
    getrandom = 278,
    memfd_create = 279,
    bpf = 280,
    execveat = 281,
    userfaultfd = 282,
    membarrier = 283,
    mlock2 = 284,
    copy_file_range = 285,
    preadv2 = 286,
    pwritev2 = 287,
    pkey_mprotect = 288,
    pkey_alloc = 289,
    pkey_free = 290,
    statx = 291,
    io_pgetevents = 292,
    rseq = 293,
    kexec_file_load = 294,
    pidfd_send_signal = 424,
    io_uring_setup = 425,
    io_uring_enter = 426,
    io_uring_register = 427,
    open_tree = 428,
    move_mount = 429,
    fsopen = 430,
    fsconfig = 431,
    fsmount = 432,
    fspick = 433,
    pidfd_open = 434,
    clone3 = 435,
    close_range = 436,
    openat2 = 437,
    pidfd_getfd = 438,
    faccessat2 = 439,
    process_madvise = 440,
    epoll_pwait2 = 441,
    mount_setattr = 442,
    landlock_create_ruleset = 444,
    landlock_add_rule = 445,
    landlock_restrict_self = 446,

    _,
};

pub const O = struct {
    pub const CREAT = 0o100;
    pub const EXCL = 0o200;
    pub const NOCTTY = 0o400;
    pub const TRUNC = 0o1000;
    pub const APPEND = 0o2000;
    pub const NONBLOCK = 0o4000;
    pub const DSYNC = 0o10000;
    pub const SYNC = 0o4010000;
    pub const RSYNC = 0o4010000;
    pub const DIRECTORY = 0o200000;
    pub const NOFOLLOW = 0o400000;
    pub const CLOEXEC = 0o2000000;

    pub const ASYNC = 0o20000;
    pub const DIRECT = 0o40000;
    pub const LARGEFILE = 0o100000;
    pub const NOATIME = 0o1000000;
    pub const PATH = 0o10000000;
    pub const TMPFILE = 0o20200000;
    pub const NDELAY = NONBLOCK;
};

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;
    pub const GETLK = 5;
    pub const SETLK = 6;
    pub const SETLKW = 7;
    pub const SETOWN = 8;
    pub const GETOWN = 9;
    pub const SETSIG = 10;
    pub const GETSIG = 11;

    pub const RDLCK = 0;
    pub const WRLCK = 1;
    pub const UNLCK = 2;

    pub const SETOWN_EX = 15;
    pub const GETOWN_EX = 16;

    pub const GETOWNER_UIDS = 17;
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const UN = 8;
    pub const NB = 4;
};

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = isize;
pub const mode_t = u32;
pub const off_t = isize;
pub const ino_t = usize;
pub const dev_t = usize;
pub const blkcnt_t = isize;

pub const timeval = extern struct {
    tv_sec: time_t,
    tv_usec: i64,
};

pub const Flock = extern struct {
    l_type: i16,
    l_whence: i16,
    l_start: off_t,
    l_len: off_t,
    l_pid: pid_t,
    __unused: [4]u8,
};

// The `stat` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: dev_t,
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    __pad: usize,
    size: off_t,
    blksize: blksize_t,
    __pad2: i32,
    blocks: blkcnt_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    __unused: [2]u32,

    pub fn atime(self: @This()) timespec {
        return self.atim;
    }

    pub fn mtime(self: @This()) timespec {
        return self.mtim;
    }

    pub fn ctime(self: @This()) timespec {
        return self.ctim;
    }
};

pub const Elf_Symndx = u32;

pub const VDSO = struct {};
pub const MAP = struct {};
