// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// arm-eabi-specific declarations that are intended to be imported into the POSIX namespace.
const std = @import("../../../std.zig");
const linux = std.os.linux;
const socklen_t = linux.socklen_t;
const iovec = linux.iovec;
const iovec_const = linux.iovec_const;
const stack_t = linux.stack_t;
const sigset_t = linux.sigset_t;
const uid_t = linux.uid_t;
const gid_t = linux.gid_t;
const pid_t = linux.pid_t;

pub const SYS = extern enum(usize) {
    restart_syscall = 0,
    exit = 1,
    fork = 2,
    read = 3,
    write = 4,
    open = 5,
    close = 6,
    creat = 8,
    link = 9,
    unlink = 10,
    execve = 11,
    chdir = 12,
    mknod = 14,
    chmod = 15,
    lchown = 16,
    lseek = 19,
    getpid = 20,
    mount = 21,
    setuid = 23,
    getuid = 24,
    ptrace = 26,
    pause = 29,
    access = 33,
    nice = 34,
    sync = 36,
    kill = 37,
    rename = 38,
    mkdir = 39,
    rmdir = 40,
    dup = 41,
    pipe = 42,
    times = 43,
    brk = 45,
    setgid = 46,
    getgid = 47,
    geteuid = 49,
    getegid = 50,
    acct = 51,
    umount2 = 52,
    ioctl = 54,
    fcntl = 55,
    setpgid = 57,
    umask = 60,
    chroot = 61,
    ustat = 62,
    dup2 = 63,
    getppid = 64,
    getpgrp = 65,
    setsid = 66,
    sigaction = 67,
    setreuid = 70,
    setregid = 71,
    sigsuspend = 72,
    sigpending = 73,
    sethostname = 74,
    setrlimit = 75,
    getrusage = 77,
    gettimeofday = 78,
    settimeofday = 79,
    getgroups = 80,
    setgroups = 81,
    symlink = 83,
    readlink = 85,
    uselib = 86,
    swapon = 87,
    reboot = 88,
    munmap = 91,
    truncate = 92,
    ftruncate = 93,
    fchmod = 94,
    fchown = 95,
    getpriority = 96,
    setpriority = 97,
    statfs = 99,
    fstatfs = 100,
    syslog = 103,
    setitimer = 104,
    getitimer = 105,
    stat = 106,
    lstat = 107,
    fstat = 108,
    vhangup = 111,
    wait4 = 114,
    swapoff = 115,
    sysinfo = 116,
    fsync = 118,
    sigreturn = 119,
    clone = 120,
    setdomainname = 121,
    uname = 122,
    adjtimex = 124,
    mprotect = 125,
    sigprocmask = 126,
    init_module = 128,
    delete_module = 129,
    quotactl = 131,
    getpgid = 132,
    fchdir = 133,
    bdflush = 134,
    sysfs = 135,
    personality = 136,
    setfsuid = 138,
    setfsgid = 139,
    _llseek = 140,
    getdents = 141,
    _newselect = 142,
    flock = 143,
    msync = 144,
    readv = 145,
    writev = 146,
    getsid = 147,
    fdatasync = 148,
    _sysctl = 149,
    mlock = 150,
    munlock = 151,
    mlockall = 152,
    munlockall = 153,
    sched_setparam = 154,
    sched_getparam = 155,
    sched_setscheduler = 156,
    sched_getscheduler = 157,
    sched_yield = 158,
    sched_get_priority_max = 159,
    sched_get_priority_min = 160,
    sched_rr_get_interval = 161,
    nanosleep = 162,
    mremap = 163,
    setresuid = 164,
    getresuid = 165,
    poll = 168,
    nfsservctl = 169,
    setresgid = 170,
    getresgid = 171,
    prctl = 172,
    rt_sigreturn = 173,
    rt_sigaction = 174,
    rt_sigprocmask = 175,
    rt_sigpending = 176,
    rt_sigtimedwait = 177,
    rt_sigqueueinfo = 178,
    rt_sigsuspend = 179,
    pread64 = 180,
    pwrite64 = 181,
    chown = 182,
    getcwd = 183,
    capget = 184,
    capset = 185,
    sigaltstack = 186,
    sendfile = 187,
    vfork = 190,
    ugetrlimit = 191,
    mmap2 = 192,
    truncate64 = 193,
    ftruncate64 = 194,
    stat64 = 195,
    lstat64 = 196,
    fstat64 = 197,
    lchown32 = 198,
    getuid32 = 199,
    getgid32 = 200,
    geteuid32 = 201,
    getegid32 = 202,
    setreuid32 = 203,
    setregid32 = 204,
    getgroups32 = 205,
    setgroups32 = 206,
    fchown32 = 207,
    setresuid32 = 208,
    getresuid32 = 209,
    setresgid32 = 210,
    getresgid32 = 211,
    chown32 = 212,
    setuid32 = 213,
    setgid32 = 214,
    setfsuid32 = 215,
    setfsgid32 = 216,
    getdents64 = 217,
    pivot_root = 218,
    mincore = 219,
    madvise = 220,
    fcntl64 = 221,
    gettid = 224,
    readahead = 225,
    setxattr = 226,
    lsetxattr = 227,
    fsetxattr = 228,
    getxattr = 229,
    lgetxattr = 230,
    fgetxattr = 231,
    listxattr = 232,
    llistxattr = 233,
    flistxattr = 234,
    removexattr = 235,
    lremovexattr = 236,
    fremovexattr = 237,
    tkill = 238,
    sendfile64 = 239,
    futex = 240,
    sched_setaffinity = 241,
    sched_getaffinity = 242,
    io_setup = 243,
    io_destroy = 244,
    io_getevents = 245,
    io_submit = 246,
    io_cancel = 247,
    exit_group = 248,
    lookup_dcookie = 249,
    epoll_create = 250,
    epoll_ctl = 251,
    epoll_wait = 252,
    remap_file_pages = 253,
    set_tid_address = 256,
    timer_create = 257,
    timer_settime = 258,
    timer_gettime = 259,
    timer_getoverrun = 260,
    timer_delete = 261,
    clock_settime = 262,
    clock_gettime = 263,
    clock_getres = 264,
    clock_nanosleep = 265,
    statfs64 = 266,
    fstatfs64 = 267,
    tgkill = 268,
    utimes = 269,
    fadvise64_64 = 270,
    arm_fadvise64_64 = 270,
    pciconfig_iobase = 271,
    pciconfig_read = 272,
    pciconfig_write = 273,
    mq_open = 274,
    mq_unlink = 275,
    mq_timedsend = 276,
    mq_timedreceive = 277,
    mq_notify = 278,
    mq_getsetattr = 279,
    waitid = 280,
    socket = 281,
    bind = 282,
    connect = 283,
    listen = 284,
    accept = 285,
    getsockname = 286,
    getpeername = 287,
    socketpair = 288,
    send = 289,
    sendto = 290,
    recv = 291,
    recvfrom = 292,
    shutdown = 293,
    setsockopt = 294,
    getsockopt = 295,
    sendmsg = 296,
    recvmsg = 297,
    semop = 298,
    semget = 299,
    semctl = 300,
    msgsnd = 301,
    msgrcv = 302,
    msgget = 303,
    msgctl = 304,
    shmat = 305,
    shmdt = 306,
    shmget = 307,
    shmctl = 308,
    add_key = 309,
    request_key = 310,
    keyctl = 311,
    semtimedop = 312,
    vserver = 313,
    ioprio_set = 314,
    ioprio_get = 315,
    inotify_init = 316,
    inotify_add_watch = 317,
    inotify_rm_watch = 318,
    mbind = 319,
    get_mempolicy = 320,
    set_mempolicy = 321,
    openat = 322,
    mkdirat = 323,
    mknodat = 324,
    fchownat = 325,
    futimesat = 326,
    fstatat64 = 327,
    unlinkat = 328,
    renameat = 329,
    linkat = 330,
    symlinkat = 331,
    readlinkat = 332,
    fchmodat = 333,
    faccessat = 334,
    pselect6 = 335,
    ppoll = 336,
    unshare = 337,
    set_robust_list = 338,
    get_robust_list = 339,
    splice = 340,
    sync_file_range2 = 341,
    arm_sync_file_range = 341,
    tee = 342,
    vmsplice = 343,
    move_pages = 344,
    getcpu = 345,
    epoll_pwait = 346,
    kexec_load = 347,
    utimensat = 348,
    signalfd = 349,
    timerfd_create = 350,
    eventfd = 351,
    fallocate = 352,
    timerfd_settime = 353,
    timerfd_gettime = 354,
    signalfd4 = 355,
    eventfd2 = 356,
    epoll_create1 = 357,
    dup3 = 358,
    pipe2 = 359,
    inotify_init1 = 360,
    preadv = 361,
    pwritev = 362,
    rt_tgsigqueueinfo = 363,
    perf_event_open = 364,
    recvmmsg = 365,
    accept4 = 366,
    fanotify_init = 367,
    fanotify_mark = 368,
    prlimit64 = 369,
    name_to_handle_at = 370,
    open_by_handle_at = 371,
    clock_adjtime = 372,
    syncfs = 373,
    sendmmsg = 374,
    setns = 375,
    process_vm_readv = 376,
    process_vm_writev = 377,
    kcmp = 378,
    finit_module = 379,
    sched_setattr = 380,
    sched_getattr = 381,
    renameat2 = 382,
    seccomp = 383,
    getrandom = 384,
    memfd_create = 385,
    bpf = 386,
    execveat = 387,
    userfaultfd = 388,
    membarrier = 389,
    mlock2 = 390,
    copy_file_range = 391,
    preadv2 = 392,
    pwritev2 = 393,
    pkey_mprotect = 394,
    pkey_alloc = 395,
    pkey_free = 396,
    statx = 397,
    rseq = 398,
    io_pgetevents = 399,
    migrate_pages = 400,
    kexec_file_load = 401,
    clock_gettime64 = 403,
    clock_settime64 = 404,
    clock_adjtime64 = 405,
    clock_getres_time64 = 406,
    clock_nanosleep_time64 = 407,
    timer_gettime64 = 408,
    timer_settime64 = 409,
    timerfd_gettime64 = 410,
    timerfd_settime64 = 411,
    utimensat_time64 = 412,
    pselect6_time64 = 413,
    ppoll_time64 = 414,
    io_pgetevents_time64 = 416,
    recvmmsg_time64 = 417,
    mq_timedsend_time64 = 418,
    mq_timedreceive_time64 = 419,
    semtimedop_time64 = 420,
    rt_sigtimedwait_time64 = 421,
    futex_time64 = 422,
    sched_rr_get_interval_time64 = 423,
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
    openat2 = 437,
    pidfd_getfd = 438,

    breakpoint = 0x0f0001,
    cacheflush = 0x0f0002,
    usr26 = 0x0f0003,
    usr32 = 0x0f0004,
    set_tls = 0x0f0005,
    get_tls = 0x0f0006,

    _,
};

pub const MMAP2_UNIT = 4096;

pub const O_CREAT = 0o100;
pub const O_EXCL = 0o200;
pub const O_NOCTTY = 0o400;
pub const O_TRUNC = 0o1000;
pub const O_APPEND = 0o2000;
pub const O_NONBLOCK = 0o4000;
pub const O_DSYNC = 0o10000;
pub const O_SYNC = 0o4010000;
pub const O_RSYNC = 0o4010000;
pub const O_DIRECTORY = 0o40000;
pub const O_NOFOLLOW = 0o100000;
pub const O_CLOEXEC = 0o2000000;

pub const O_ASYNC = 0o20000;
pub const O_DIRECT = 0o200000;
pub const O_LARGEFILE = 0o400000;
pub const O_NOATIME = 0o1000000;
pub const O_PATH = 0o10000000;
pub const O_TMPFILE = 0o20040000;
pub const O_NDELAY = O_NONBLOCK;

pub const F_DUPFD = 0;
pub const F_GETFD = 1;
pub const F_SETFD = 2;
pub const F_GETFL = 3;
pub const F_SETFL = 4;

pub const F_SETOWN = 8;
pub const F_GETOWN = 9;
pub const F_SETSIG = 10;
pub const F_GETSIG = 11;

pub const F_GETLK = 12;
pub const F_SETLK = 13;
pub const F_SETLKW = 14;

pub const F_RDLCK = 0;
pub const F_WRLCK = 1;
pub const F_UNLCK = 2;

pub const F_SETOWN_EX = 15;
pub const F_GETOWN_EX = 16;

pub const F_GETOWNER_UIDS = 17;

pub const LOCK_SH = 1;
pub const LOCK_EX = 2;
pub const LOCK_UN = 8;
pub const LOCK_NB = 4;

/// stack-like segment
pub const MAP_GROWSDOWN = 0x0100;

/// ETXTBSY
pub const MAP_DENYWRITE = 0x0800;

/// mark it as an executable
pub const MAP_EXECUTABLE = 0x1000;

/// pages are locked
pub const MAP_LOCKED = 0x2000;

/// don't check for reservations
pub const MAP_NORESERVE = 0x4000;

pub const VDSO_CGT_SYM = "__vdso_clock_gettime";
pub const VDSO_CGT_VER = "LINUX_2.6";

pub const HWCAP_SWP = 1 << 0;
pub const HWCAP_HALF = 1 << 1;
pub const HWCAP_THUMB = 1 << 2;
pub const HWCAP_26BIT = 1 << 3;
pub const HWCAP_FAST_MULT = 1 << 4;
pub const HWCAP_FPA = 1 << 5;
pub const HWCAP_VFP = 1 << 6;
pub const HWCAP_EDSP = 1 << 7;
pub const HWCAP_JAVA = 1 << 8;
pub const HWCAP_IWMMXT = 1 << 9;
pub const HWCAP_CRUNCH = 1 << 10;
pub const HWCAP_THUMBEE = 1 << 11;
pub const HWCAP_NEON = 1 << 12;
pub const HWCAP_VFPv3 = 1 << 13;
pub const HWCAP_VFPv3D16 = 1 << 14;
pub const HWCAP_TLS = 1 << 15;
pub const HWCAP_VFPv4 = 1 << 16;
pub const HWCAP_IDIVA = 1 << 17;
pub const HWCAP_IDIVT = 1 << 18;
pub const HWCAP_VFPD32 = 1 << 19;
pub const HWCAP_IDIV = HWCAP_IDIVA | HWCAP_IDIVT;
pub const HWCAP_LPAE = 1 << 20;
pub const HWCAP_EVTSTRM = 1 << 21;

pub const Flock = extern struct {
    l_type: i16,
    l_whence: i16,
    __pad0: [4]u8,
    l_start: off_t,
    l_len: off_t,
    l_pid: pid_t,
    __unused: [4]u8,
};

pub const msghdr = extern struct {
    msg_name: ?*sockaddr,
    msg_namelen: socklen_t,
    msg_iov: [*]iovec,
    msg_iovlen: i32,
    msg_control: ?*c_void,
    msg_controllen: socklen_t,
    msg_flags: i32,
};

pub const msghdr_const = extern struct {
    msg_name: ?*const sockaddr,
    msg_namelen: socklen_t,
    msg_iov: [*]iovec_const,
    msg_iovlen: i32,
    msg_control: ?*c_void,
    msg_controllen: socklen_t,
    msg_flags: i32,
};

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = isize;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;
pub const blkcnt_t = i64;

/// Renamed to Stat to not conflict with the stat function.
/// atime, mtime, and ctime have functions to return `timespec`,
/// because although this is a POSIX API, the layout and names of
/// the structs are inconsistent across operating systems, and
/// in C, macros are used to hide the differences. Here we use
/// methods to accomplish this.
pub const Stat = extern struct {
    dev: dev_t,
    __dev_padding: u32,
    __ino_truncated: u32,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    __rdev_padding: u32,
    size: off_t,
    blksize: blksize_t,
    blocks: blkcnt_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    ino: ino_t,

    pub fn atime(self: Stat) timespec {
        return self.atim;
    }

    pub fn mtime(self: Stat) timespec {
        return self.mtim;
    }

    pub fn ctime(self: Stat) timespec {
        return self.ctim;
    }
};

pub const timespec = extern struct {
    tv_sec: i32,
    tv_nsec: i32,
};

pub const timeval = extern struct {
    tv_sec: i32,
    tv_usec: i32,
};

pub const timezone = extern struct {
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

pub const mcontext_t = extern struct {
    trap_no: usize,
    error_code: usize,
    oldmask: usize,
    arm_r0: usize,
    arm_r1: usize,
    arm_r2: usize,
    arm_r3: usize,
    arm_r4: usize,
    arm_r5: usize,
    arm_r6: usize,
    arm_r7: usize,
    arm_r8: usize,
    arm_r9: usize,
    arm_r10: usize,
    arm_fp: usize,
    arm_ip: usize,
    arm_sp: usize,
    arm_lr: usize,
    arm_pc: usize,
    arm_cpsr: usize,
    fault_address: usize,
};

pub const ucontext_t = extern struct {
    flags: usize,
    link: *ucontext_t,
    stack: stack_t,
    mcontext: mcontext_t,
    sigmask: sigset_t,
    regspace: [64]u64,
};

pub const Elf_Symndx = u32;
