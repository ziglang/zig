const std = @import("../../std.zig");
const maxInt = std.math.maxInt;
const pid_t = linux.pid_t;
const uid_t = linux.uid_t;
const clock_t = linux.clock_t;
const stack_t = linux.stack_t;
const sigset_t = linux.sigset_t;

const linux = std.os.linux;
const sockaddr = linux.sockaddr;
const socklen_t = linux.socklen_t;
const iovec = linux.iovec;
const iovec_const = linux.iovec_const;
const timespec = linux.timespec;

pub fn syscall_pipe(fd: *[2]i32) usize {
    return asm volatile (
        \\ mov %[arg], %%g3
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ # Return the error code
        \\ ba 2f
        \\ neg %%o0
        \\1:
        \\ st %%o0, [%%g3+0]
        \\ st %%o1, [%%g3+4]
        \\ clr %%o0
        \\2:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@enumToInt(SYS.pipe)),
          [arg] "r" (fd),
        : "memory", "g3"
    );
}

pub fn syscall_fork() usize {
    // Linux/sparc64 fork() returns two values in %o0 and %o1:
    // - On the parent's side, %o0 is the child's PID and %o1 is 0.
    // - On the child's side, %o0 is the parent's PID and %o1 is 1.
    // We need to clear the child's %o0 so that the return values
    // conform to the libc convention.
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ ba 2f
        \\ neg %%o0
        \\ 1:
        \\ # Clear the child's %%o0
        \\ dec %%o1
        \\ and %%o1, %%o0, %%o0
        \\ 2:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@enumToInt(SYS.fork)),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub fn syscall0(number: SYS) usize {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@enumToInt(number)),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@enumToInt(number)),
          [arg1] "{o0}" (arg1),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@enumToInt(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@enumToInt(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
          [arg3] "{o2}" (arg3),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@enumToInt(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
          [arg3] "{o2}" (arg3),
          [arg4] "{o3}" (arg4),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@enumToInt(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
          [arg3] "{o2}" (arg3),
          [arg4] "{o3}" (arg4),
          [arg5] "{o4}" (arg5),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
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
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@enumToInt(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
          [arg3] "{o2}" (arg3),
          [arg4] "{o3}" (arg4),
          [arg5] "{o4}" (arg5),
          [arg6] "{o5}" (arg6),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

/// This matches the libc clone function.
pub extern fn clone(func: fn (arg: usize) callconv(.C) u8, stack: usize, flags: usize, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub const restore = restore_rt;

// Need to use C ABI here instead of naked
// to prevent an infinite loop when calling rt_sigreturn.
pub fn restore_rt() callconv(.C) void {
    return asm volatile ("t 0x6d"
        :
        : [number] "{g1}" (@enumToInt(SYS.rt_sigreturn)),
        : "memory", "xcc", "o0", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub const SYS = enum(usize) {
    restart_syscall = 0,
    exit = 1,
    fork = 2,
    read = 3,
    write = 4,
    open = 5,
    close = 6,
    wait4 = 7,
    creat = 8,
    link = 9,
    unlink = 10,
    execv = 11,
    chdir = 12,
    chown = 13,
    mknod = 14,
    chmod = 15,
    lchown = 16,
    brk = 17,
    perfctr = 18,
    lseek = 19,
    getpid = 20,
    capget = 21,
    capset = 22,
    setuid = 23,
    getuid = 24,
    vmsplice = 25,
    ptrace = 26,
    alarm = 27,
    sigaltstack = 28,
    pause = 29,
    utime = 30,
    access = 33,
    nice = 34,
    sync = 36,
    kill = 37,
    stat = 38,
    sendfile = 39,
    lstat = 40,
    dup = 41,
    pipe = 42,
    times = 43,
    umount2 = 45,
    setgid = 46,
    getgid = 47,
    signal = 48,
    geteuid = 49,
    getegid = 50,
    acct = 51,
    memory_ordering = 52,
    ioctl = 54,
    reboot = 55,
    symlink = 57,
    readlink = 58,
    execve = 59,
    umask = 60,
    chroot = 61,
    fstat = 62,
    fstat64 = 63,
    getpagesize = 64,
    msync = 65,
    vfork = 66,
    pread64 = 67,
    pwrite64 = 68,
    mmap = 71,
    munmap = 73,
    mprotect = 74,
    madvise = 75,
    vhangup = 76,
    mincore = 78,
    getgroups = 79,
    setgroups = 80,
    getpgrp = 81,
    setitimer = 83,
    swapon = 85,
    getitimer = 86,
    sethostname = 88,
    dup2 = 90,
    fcntl = 92,
    select = 93,
    fsync = 95,
    setpriority = 96,
    socket = 97,
    connect = 98,
    accept = 99,
    getpriority = 100,
    rt_sigreturn = 101,
    rt_sigaction = 102,
    rt_sigprocmask = 103,
    rt_sigpending = 104,
    rt_sigtimedwait = 105,
    rt_sigqueueinfo = 106,
    rt_sigsuspend = 107,
    setresuid = 108,
    getresuid = 109,
    setresgid = 110,
    getresgid = 111,
    recvmsg = 113,
    sendmsg = 114,
    gettimeofday = 116,
    getrusage = 117,
    getsockopt = 118,
    getcwd = 119,
    readv = 120,
    writev = 121,
    settimeofday = 122,
    fchown = 123,
    fchmod = 124,
    recvfrom = 125,
    setreuid = 126,
    setregid = 127,
    rename = 128,
    truncate = 129,
    ftruncate = 130,
    flock = 131,
    lstat64 = 132,
    sendto = 133,
    shutdown = 134,
    socketpair = 135,
    mkdir = 136,
    rmdir = 137,
    utimes = 138,
    stat64 = 139,
    sendfile64 = 140,
    getpeername = 141,
    futex = 142,
    gettid = 143,
    getrlimit = 144,
    setrlimit = 145,
    pivot_root = 146,
    prctl = 147,
    pciconfig_read = 148,
    pciconfig_write = 149,
    getsockname = 150,
    inotify_init = 151,
    inotify_add_watch = 152,
    poll = 153,
    getdents64 = 154,
    inotify_rm_watch = 156,
    statfs = 157,
    fstatfs = 158,
    umount = 159,
    sched_set_affinity = 160,
    sched_get_affinity = 161,
    getdomainname = 162,
    setdomainname = 163,
    utrap_install = 164,
    quotactl = 165,
    set_tid_address = 166,
    mount = 167,
    ustat = 168,
    setxattr = 169,
    lsetxattr = 170,
    fsetxattr = 171,
    getxattr = 172,
    lgetxattr = 173,
    getdents = 174,
    setsid = 175,
    fchdir = 176,
    fgetxattr = 177,
    listxattr = 178,
    llistxattr = 179,
    flistxattr = 180,
    removexattr = 181,
    lremovexattr = 182,
    sigpending = 183,
    query_module = 184,
    setpgid = 185,
    fremovexattr = 186,
    tkill = 187,
    exit_group = 188,
    uname = 189,
    init_module = 190,
    personality = 191,
    remap_file_pages = 192,
    epoll_create = 193,
    epoll_ctl = 194,
    epoll_wait = 195,
    ioprio_set = 196,
    getppid = 197,
    sigaction = 198,
    sgetmask = 199,
    ssetmask = 200,
    sigsuspend = 201,
    oldlstat = 202,
    uselib = 203,
    readdir = 204,
    readahead = 205,
    socketcall = 206,
    syslog = 207,
    lookup_dcookie = 208,
    fadvise64 = 209,
    fadvise64_64 = 210,
    tgkill = 211,
    waitpid = 212,
    swapoff = 213,
    sysinfo = 214,
    ipc = 215,
    sigreturn = 216,
    clone = 217,
    ioprio_get = 218,
    adjtimex = 219,
    sigprocmask = 220,
    create_module = 221,
    delete_module = 222,
    get_kernel_syms = 223,
    getpgid = 224,
    bdflush = 225,
    sysfs = 226,
    afs_syscall = 227,
    setfsuid = 228,
    setfsgid = 229,
    _newselect = 230,
    splice = 232,
    stime = 233,
    statfs64 = 234,
    fstatfs64 = 235,
    _llseek = 236,
    mlock = 237,
    munlock = 238,
    mlockall = 239,
    munlockall = 240,
    sched_setparam = 241,
    sched_getparam = 242,
    sched_setscheduler = 243,
    sched_getscheduler = 244,
    sched_yield = 245,
    sched_get_priority_max = 246,
    sched_get_priority_min = 247,
    sched_rr_get_interval = 248,
    nanosleep = 249,
    mremap = 250,
    _sysctl = 251,
    getsid = 252,
    fdatasync = 253,
    nfsservctl = 254,
    sync_file_range = 255,
    clock_settime = 256,
    clock_gettime = 257,
    clock_getres = 258,
    clock_nanosleep = 259,
    sched_getaffinity = 260,
    sched_setaffinity = 261,
    timer_settime = 262,
    timer_gettime = 263,
    timer_getoverrun = 264,
    timer_delete = 265,
    timer_create = 266,
    vserver = 267,
    io_setup = 268,
    io_destroy = 269,
    io_submit = 270,
    io_cancel = 271,
    io_getevents = 272,
    mq_open = 273,
    mq_unlink = 274,
    mq_timedsend = 275,
    mq_timedreceive = 276,
    mq_notify = 277,
    mq_getsetattr = 278,
    waitid = 279,
    tee = 280,
    add_key = 281,
    request_key = 282,
    keyctl = 283,
    openat = 284,
    mkdirat = 285,
    mknodat = 286,
    fchownat = 287,
    futimesat = 288,
    fstatat64 = 289,
    unlinkat = 290,
    renameat = 291,
    linkat = 292,
    symlinkat = 293,
    readlinkat = 294,
    fchmodat = 295,
    faccessat = 296,
    pselect6 = 297,
    ppoll = 298,
    unshare = 299,
    set_robust_list = 300,
    get_robust_list = 301,
    migrate_pages = 302,
    mbind = 303,
    get_mempolicy = 304,
    set_mempolicy = 305,
    kexec_load = 306,
    move_pages = 307,
    getcpu = 308,
    epoll_pwait = 309,
    utimensat = 310,
    signalfd = 311,
    timerfd_create = 312,
    eventfd = 313,
    fallocate = 314,
    timerfd_settime = 315,
    timerfd_gettime = 316,
    signalfd4 = 317,
    eventfd2 = 318,
    epoll_create1 = 319,
    dup3 = 320,
    pipe2 = 321,
    inotify_init1 = 322,
    accept4 = 323,
    preadv = 324,
    pwritev = 325,
    rt_tgsigqueueinfo = 326,
    perf_event_open = 327,
    recvmmsg = 328,
    fanotify_init = 329,
    fanotify_mark = 330,
    prlimit64 = 331,
    name_to_handle_at = 332,
    open_by_handle_at = 333,
    clock_adjtime = 334,
    syncfs = 335,
    sendmmsg = 336,
    setns = 337,
    process_vm_readv = 338,
    process_vm_writev = 339,
    kern_features = 340,
    kcmp = 341,
    finit_module = 342,
    sched_setattr = 343,
    sched_getattr = 344,
    renameat2 = 345,
    seccomp = 346,
    getrandom = 347,
    memfd_create = 348,
    bpf = 349,
    execveat = 350,
    membarrier = 351,
    userfaultfd = 352,
    bind = 353,
    listen = 354,
    setsockopt = 355,
    mlock2 = 356,
    copy_file_range = 357,
    preadv2 = 358,
    pwritev2 = 359,
    statx = 360,
    io_pgetevents = 361,
    pkey_mprotect = 362,
    pkey_alloc = 363,
    pkey_free = 364,
    rseq = 365,
    semtimedop = 392,
    semget = 393,
    semctl = 394,
    shmget = 395,
    shmctl = 396,
    shmat = 397,
    shmdt = 398,
    msgget = 399,
    msgsnd = 400,
    msgrcv = 401,
    msgctl = 402,
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
    pub const CREAT = 0x200;
    pub const EXCL = 0x800;
    pub const NOCTTY = 0x8000;
    pub const TRUNC = 0x400;
    pub const APPEND = 0x8;
    pub const NONBLOCK = 0x4000;
    pub const SYNC = 0x802000;
    pub const DSYNC = 0x2000;
    pub const RSYNC = SYNC;
    pub const DIRECTORY = 0x10000;
    pub const NOFOLLOW = 0x20000;
    pub const CLOEXEC = 0x400000;

    pub const ASYNC = 0x40;
    pub const DIRECT = 0x100000;
    pub const LARGEFILE = 0;
    pub const NOATIME = 0x200000;
    pub const PATH = 0x1000000;
    pub const TMPFILE = 0x2010000;
    pub const NDELAY = NONBLOCK | 0x4;
};

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;

    pub const SETOWN = 5;
    pub const GETOWN = 6;
    pub const GETLK = 7;
    pub const SETLK = 8;
    pub const SETLKW = 9;

    pub const RDLCK = 1;
    pub const WRLCK = 2;
    pub const UNLCK = 3;

    pub const SETOWN_EX = 15;
    pub const GETOWN_EX = 16;

    pub const GETOWNER_UIDS = 17;
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const NB = 4;
    pub const UN = 8;
};

pub const MAP = struct {
    /// stack-like segment
    pub const GROWSDOWN = 0x0200;
    /// ETXTBSY
    pub const DENYWRITE = 0x0800;
    /// mark it as an executable
    pub const EXECUTABLE = 0x1000;
    /// pages are locked
    pub const LOCKED = 0x0100;
    /// don't check for reservations
    pub const NORESERVE = 0x0040;
};

pub const VDSO = struct {
    pub const CGT_SYM = "__vdso_clock_gettime";
    pub const CGT_VER = "LINUX_2.6";
};

pub const Flock = extern struct {
    l_type: i16,
    l_whence: i16,
    l_start: off_t,
    l_len: off_t,
    l_pid: pid_t,
};

pub const msghdr = extern struct {
    msg_name: ?*sockaddr,
    msg_namelen: socklen_t,
    msg_iov: [*]iovec,
    msg_iovlen: u64,
    msg_control: ?*anyopaque,
    msg_controllen: u64,
    msg_flags: i32,
};

pub const msghdr_const = extern struct {
    msg_name: ?*const sockaddr,
    msg_namelen: socklen_t,
    msg_iov: [*]iovec_const,
    msg_iovlen: u64,
    msg_control: ?*anyopaque,
    msg_controllen: u64,
    msg_flags: i32,
};

pub const off_t = i64;
pub const ino_t = u64;
pub const mode_t = u32;
pub const dev_t = usize;
pub const nlink_t = u32;
pub const blksize_t = isize;
pub const blkcnt_t = isize;

// The `stat64` definition used by the kernel.
pub const Stat = extern struct {
    dev: u64,
    ino: u64,
    nlink: u64,

    mode: u32,
    uid: u32,
    gid: u32,
    __pad0: u32,

    rdev: u64,
    size: i64,
    blksize: i64,
    blocks: i64,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    __unused: [3]u64,

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

pub const timeval = extern struct {
    tv_sec: isize,
    tv_usec: i32,
};

pub const timezone = extern struct {
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

// TODO I'm not sure if the code below is correct, need someone with more
// knowledge about sparc64 linux internals to look into.

pub const Elf_Symndx = u32;

pub const fpstate = extern struct {
    regs: [32]u64,
    fsr: u64,
    gsr: u64,
    fprs: u64,
};

pub const __fpq = extern struct {
    fpq_addr: *u32,
    fpq_instr: u32,
};

pub const __fq = extern struct {
    FQu: extern union {
        whole: f64,
        fpq: __fpq,
    },
};

pub const fpregset_t = extern struct {
    fpu_fr: extern union {
        fpu_regs: [32]u32,
        fpu_dregs: [32]f64,
        fpu_qregs: [16]c_longdouble,
    },
    fpu_q: *__fq,
    fpu_fsr: u64,
    fpu_qcnt: u8,
    fpu_q_entrysize: u8,
    fpu_en: u8,
};

pub const siginfo_fpu_t = extern struct {
    float_regs: [64]u32,
    fsr: u64,
    gsr: u64,
    fprs: u64,
};

pub const sigcontext = extern struct {
    info: [128]i8,
    regs: extern struct {
        u_regs: [16]u64,
        tstate: u64,
        tpc: u64,
        tnpc: u64,
        y: u64,
        fprs: u64,
    },
    fpu_save: *siginfo_fpu_t,
    stack: extern struct {
        sp: usize,
        flags: i32,
        size: u64,
    },
    mask: u64,
};

pub const greg_t = u64;
pub const gregset_t = [19]greg_t;

pub const fq = extern struct {
    addr: *u64,
    insn: u32,
};

pub const fpu_t = extern struct {
    fregs: extern union {
        sregs: [32]u32,
        dregs: [32]u64,
        qregs: [16]c_longdouble,
    },
    fsr: u64,
    fprs: u64,
    gsr: u64,
    fq: *fq,
    qcnt: u8,
    qentsz: u8,
    enab: u8,
};

pub const mcontext_t = extern struct {
    gregs: gregset_t,
    fp: greg_t,
    @"i7": greg_t,
    fpregs: fpu_t,
};

pub const ucontext_t = extern struct {
    link: *ucontext_t,
    flags: u64,
    sigmask: u64,
    mcontext: mcontext_t,
    stack: stack_t,
    sigmask: sigset_t,
};

pub const rlimit_resource = enum(c_int) {
    /// Per-process CPU limit, in seconds.
    CPU,

    /// Largest file that can be created, in bytes.
    FSIZE,

    /// Maximum size of data segment, in bytes.
    DATA,

    /// Maximum size of stack segment, in bytes.
    STACK,

    /// Largest core file that can be created, in bytes.
    CORE,

    /// Largest resident set size, in bytes.
    /// This affects swapping; processes that are exceeding their
    /// resident set size will be more likely to have physical memory
    /// taken from them.
    RSS,

    /// Number of open files.
    NOFILE,

    /// Number of processes.
    NPROC,

    /// Locked-in-memory address space.
    MEMLOCK,

    /// Address space limit.
    AS,

    /// Maximum number of file locks.
    LOCKS,

    /// Maximum number of pending signals.
    SIGPENDING,

    /// Maximum bytes in POSIX message queues.
    MSGQUEUE,

    /// Maximum nice priority allowed to raise to.
    /// Nice levels 19 .. -20 correspond to 0 .. 39
    /// values of this resource limit.
    NICE,

    /// Maximum realtime priority allowed for non-priviledged
    /// processes.
    RTPRIO,

    /// Maximum CPU time in µs that a process scheduled under a real-time
    /// scheduling policy may consume without making a blocking system
    /// call before being forcibly descheduled.
    RTTIME,

    _,
};
