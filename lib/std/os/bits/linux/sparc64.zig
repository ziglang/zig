// sparc64-specific declarations that are intended to be imported into the POSIX namespace.
const std = @import("../../../std.zig");
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

pub const SYS = extern enum(usize) {
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

    _,
};

pub const O_CREAT = 0x200;
pub const O_EXCL = 0x800;
pub const O_NOCTTY = 0x8000;
pub const O_TRUNC = 0x400;
pub const O_APPEND = 0x8;
pub const O_NONBLOCK = 0x4000;
pub const O_SYNC = 0x802000;
pub const O_DSYNC = 0x2000;
pub const O_RSYNC = O_SYNC;
pub const O_DIRECTORY = 0x10000;
pub const O_NOFOLLOW = 0x20000;
pub const O_CLOEXEC = 0x400000;

pub const O_ASYNC = 0x40;
pub const O_DIRECT = 0x100000;
pub const O_LARGEFILE = 0;
pub const O_NOATIME = 0x200000;
pub const O_PATH = 0x1000000;
pub const O_TMPFILE = 0x2010000;
pub const O_NDELAY = O_NONBLOCK | 0x4;

pub const F_DUPFD = 0;
pub const F_GETFD = 1;
pub const F_SETFD = 2;
pub const F_GETFL = 3;
pub const F_SETFL = 4;

pub const F_SETOWN = 5;
pub const F_GETOWN = 6;
pub const F_GETLK = 7;
pub const F_SETLK = 8;
pub const F_SETLKW = 9;

pub const F_RDLCK = 1;
pub const F_WRLCK = 2;
pub const F_UNLCK = 3;

pub const F_SETOWN_EX = 15;
pub const F_GETOWN_EX = 16;

pub const F_GETOWNER_UIDS = 17;

pub const LOCK_SH = 1;
pub const LOCK_EX = 2;
pub const LOCK_NB = 4;
pub const LOCK_UN = 8;

/// stack-like segment
pub const MAP_GROWSDOWN = 0x0200;

/// ETXTBSY
pub const MAP_DENYWRITE = 0x0800;

/// mark it as an executable
pub const MAP_EXECUTABLE = 0x1000;

/// pages are locked
pub const MAP_LOCKED = 0x0100;

/// don't check for reservations
pub const MAP_NORESERVE = 0x0040;

pub const VDSO_CGT_SYM = "__vdso_clock_gettime";
pub const VDSO_CGT_VER = "LINUX_2.6";

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
    msg_control: ?*c_void,
    msg_controllen: u64,
    msg_flags: i32,
};

pub const msghdr_const = extern struct {
    msg_name: ?*const sockaddr,
    msg_namelen: socklen_t,
    msg_iov: [*]iovec_const,
    msg_iovlen: u64,
    msg_control: ?*c_void,
    msg_controllen: u64,
    msg_flags: i32,
};

pub const off_t = i64;
pub const ino_t = u64;
pub const mode_t = u32;

// The `stat64` definition used by the libc.
pub const libc_stat = extern struct {
    dev: u64,
    ino: ino_t,
    mode: u32,
    nlink: usize,

    uid: u32,
    gid: u32,
    rdev: u64,
    __pad0: u32,

    size: off_t,
    blksize: isize,
    blocks: i64,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    __unused: [2]isize,

    pub fn atime(self: libc_stat) timespec {
        return self.atim;
    }

    pub fn mtime(self: libc_stat) timespec {
        return self.mtim;
    }

    pub fn ctime(self: libc_stat) timespec {
        return self.ctim;
    }
};

// The `stat64` definition used by the kernel.
pub const kernel_stat = extern struct {
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

pub const timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};

pub const timeval = extern struct {
    tv_sec: isize,
    tv_usec: isize,
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
