// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../../../std.zig");
const linux = std.os.linux;
const socklen_t = linux.socklen_t;
const iovec = linux.iovec;
const iovec_const = linux.iovec_const;
const uid_t = linux.uid_t;
const gid_t = linux.gid_t;
const pid_t = linux.pid_t;

pub const SYS = extern enum(usize) {
    pub const Linux = 4000;

    syscall = Linux + 0,
    exit = Linux + 1,
    fork = Linux + 2,
    read = Linux + 3,
    write = Linux + 4,
    open = Linux + 5,
    close = Linux + 6,
    waitpid = Linux + 7,
    creat = Linux + 8,
    link = Linux + 9,
    unlink = Linux + 10,
    execve = Linux + 11,
    chdir = Linux + 12,
    time = Linux + 13,
    mknod = Linux + 14,
    chmod = Linux + 15,
    lchown = Linux + 16,
    @"break" = Linux + 17,
    unused18 = Linux + 18,
    lseek = Linux + 19,
    getpid = Linux + 20,
    mount = Linux + 21,
    umount = Linux + 22,
    setuid = Linux + 23,
    getuid = Linux + 24,
    stime = Linux + 25,
    ptrace = Linux + 26,
    alarm = Linux + 27,
    unused28 = Linux + 28,
    pause = Linux + 29,
    utime = Linux + 30,
    stty = Linux + 31,
    gtty = Linux + 32,
    access = Linux + 33,
    nice = Linux + 34,
    ftime = Linux + 35,
    sync = Linux + 36,
    kill = Linux + 37,
    rename = Linux + 38,
    mkdir = Linux + 39,
    rmdir = Linux + 40,
    dup = Linux + 41,
    pipe = Linux + 42,
    times = Linux + 43,
    prof = Linux + 44,
    brk = Linux + 45,
    setgid = Linux + 46,
    getgid = Linux + 47,
    signal = Linux + 48,
    geteuid = Linux + 49,
    getegid = Linux + 50,
    acct = Linux + 51,
    umount2 = Linux + 52,
    lock = Linux + 53,
    ioctl = Linux + 54,
    fcntl = Linux + 55,
    mpx = Linux + 56,
    setpgid = Linux + 57,
    ulimit = Linux + 58,
    unused59 = Linux + 59,
    umask = Linux + 60,
    chroot = Linux + 61,
    ustat = Linux + 62,
    dup2 = Linux + 63,
    getppid = Linux + 64,
    getpgrp = Linux + 65,
    setsid = Linux + 66,
    sigaction = Linux + 67,
    sgetmask = Linux + 68,
    ssetmask = Linux + 69,
    setreuid = Linux + 70,
    setregid = Linux + 71,
    sigsuspend = Linux + 72,
    sigpending = Linux + 73,
    sethostname = Linux + 74,
    setrlimit = Linux + 75,
    getrlimit = Linux + 76,
    getrusage = Linux + 77,
    gettimeofday = Linux + 78,
    settimeofday = Linux + 79,
    getgroups = Linux + 80,
    setgroups = Linux + 81,
    reserved82 = Linux + 82,
    symlink = Linux + 83,
    unused84 = Linux + 84,
    readlink = Linux + 85,
    uselib = Linux + 86,
    swapon = Linux + 87,
    reboot = Linux + 88,
    readdir = Linux + 89,
    mmap = Linux + 90,
    munmap = Linux + 91,
    truncate = Linux + 92,
    ftruncate = Linux + 93,
    fchmod = Linux + 94,
    fchown = Linux + 95,
    getpriority = Linux + 96,
    setpriority = Linux + 97,
    profil = Linux + 98,
    statfs = Linux + 99,
    fstatfs = Linux + 100,
    ioperm = Linux + 101,
    socketcall = Linux + 102,
    syslog = Linux + 103,
    setitimer = Linux + 104,
    getitimer = Linux + 105,
    stat = Linux + 106,
    lstat = Linux + 107,
    fstat = Linux + 108,
    unused109 = Linux + 109,
    iopl = Linux + 110,
    vhangup = Linux + 111,
    idle = Linux + 112,
    vm86 = Linux + 113,
    wait4 = Linux + 114,
    swapoff = Linux + 115,
    sysinfo = Linux + 116,
    ipc = Linux + 117,
    fsync = Linux + 118,
    sigreturn = Linux + 119,
    clone = Linux + 120,
    setdomainname = Linux + 121,
    uname = Linux + 122,
    modify_ldt = Linux + 123,
    adjtimex = Linux + 124,
    mprotect = Linux + 125,
    sigprocmask = Linux + 126,
    create_module = Linux + 127,
    init_module = Linux + 128,
    delete_module = Linux + 129,
    get_kernel_syms = Linux + 130,
    quotactl = Linux + 131,
    getpgid = Linux + 132,
    fchdir = Linux + 133,
    bdflush = Linux + 134,
    sysfs = Linux + 135,
    personality = Linux + 136,
    afs_syscall = Linux + 137,
    setfsuid = Linux + 138,
    setfsgid = Linux + 139,
    _llseek = Linux + 140,
    getdents = Linux + 141,
    _newselect = Linux + 142,
    flock = Linux + 143,
    msync = Linux + 144,
    readv = Linux + 145,
    writev = Linux + 146,
    cacheflush = Linux + 147,
    cachectl = Linux + 148,
    sysmips = Linux + 149,
    unused150 = Linux + 150,
    getsid = Linux + 151,
    fdatasync = Linux + 152,
    _sysctl = Linux + 153,
    mlock = Linux + 154,
    munlock = Linux + 155,
    mlockall = Linux + 156,
    munlockall = Linux + 157,
    sched_setparam = Linux + 158,
    sched_getparam = Linux + 159,
    sched_setscheduler = Linux + 160,
    sched_getscheduler = Linux + 161,
    sched_yield = Linux + 162,
    sched_get_priority_max = Linux + 163,
    sched_get_priority_min = Linux + 164,
    sched_rr_get_interval = Linux + 165,
    nanosleep = Linux + 166,
    mremap = Linux + 167,
    accept = Linux + 168,
    bind = Linux + 169,
    connect = Linux + 170,
    getpeername = Linux + 171,
    getsockname = Linux + 172,
    getsockopt = Linux + 173,
    listen = Linux + 174,
    recv = Linux + 175,
    recvfrom = Linux + 176,
    recvmsg = Linux + 177,
    send = Linux + 178,
    sendmsg = Linux + 179,
    sendto = Linux + 180,
    setsockopt = Linux + 181,
    shutdown = Linux + 182,
    socket = Linux + 183,
    socketpair = Linux + 184,
    setresuid = Linux + 185,
    getresuid = Linux + 186,
    query_module = Linux + 187,
    poll = Linux + 188,
    nfsservctl = Linux + 189,
    setresgid = Linux + 190,
    getresgid = Linux + 191,
    prctl = Linux + 192,
    rt_sigreturn = Linux + 193,
    rt_sigaction = Linux + 194,
    rt_sigprocmask = Linux + 195,
    rt_sigpending = Linux + 196,
    rt_sigtimedwait = Linux + 197,
    rt_sigqueueinfo = Linux + 198,
    rt_sigsuspend = Linux + 199,
    pread64 = Linux + 200,
    pwrite64 = Linux + 201,
    chown = Linux + 202,
    getcwd = Linux + 203,
    capget = Linux + 204,
    capset = Linux + 205,
    sigaltstack = Linux + 206,
    sendfile = Linux + 207,
    getpmsg = Linux + 208,
    putpmsg = Linux + 209,
    mmap2 = Linux + 210,
    truncate64 = Linux + 211,
    ftruncate64 = Linux + 212,
    stat64 = Linux + 213,
    lstat64 = Linux + 214,
    fstat64 = Linux + 215,
    pivot_root = Linux + 216,
    mincore = Linux + 217,
    madvise = Linux + 218,
    getdents64 = Linux + 219,
    fcntl64 = Linux + 220,
    reserved221 = Linux + 221,
    gettid = Linux + 222,
    readahead = Linux + 223,
    setxattr = Linux + 224,
    lsetxattr = Linux + 225,
    fsetxattr = Linux + 226,
    getxattr = Linux + 227,
    lgetxattr = Linux + 228,
    fgetxattr = Linux + 229,
    listxattr = Linux + 230,
    llistxattr = Linux + 231,
    flistxattr = Linux + 232,
    removexattr = Linux + 233,
    lremovexattr = Linux + 234,
    fremovexattr = Linux + 235,
    tkill = Linux + 236,
    sendfile64 = Linux + 237,
    futex = Linux + 238,
    sched_setaffinity = Linux + 239,
    sched_getaffinity = Linux + 240,
    io_setup = Linux + 241,
    io_destroy = Linux + 242,
    io_getevents = Linux + 243,
    io_submit = Linux + 244,
    io_cancel = Linux + 245,
    exit_group = Linux + 246,
    lookup_dcookie = Linux + 247,
    epoll_create = Linux + 248,
    epoll_ctl = Linux + 249,
    epoll_wait = Linux + 250,
    remap_file_pages = Linux + 251,
    set_tid_address = Linux + 252,
    restart_syscall = Linux + 253,
    fadvise64 = Linux + 254,
    statfs64 = Linux + 255,
    fstatfs64 = Linux + 256,
    timer_create = Linux + 257,
    timer_settime = Linux + 258,
    timer_gettime = Linux + 259,
    timer_getoverrun = Linux + 260,
    timer_delete = Linux + 261,
    clock_settime = Linux + 262,
    clock_gettime = Linux + 263,
    clock_getres = Linux + 264,
    clock_nanosleep = Linux + 265,
    tgkill = Linux + 266,
    utimes = Linux + 267,
    mbind = Linux + 268,
    get_mempolicy = Linux + 269,
    set_mempolicy = Linux + 270,
    mq_open = Linux + 271,
    mq_unlink = Linux + 272,
    mq_timedsend = Linux + 273,
    mq_timedreceive = Linux + 274,
    mq_notify = Linux + 275,
    mq_getsetattr = Linux + 276,
    vserver = Linux + 277,
    waitid = Linux + 278,
    add_key = Linux + 280,
    request_key = Linux + 281,
    keyctl = Linux + 282,
    set_thread_area = Linux + 283,
    inotify_init = Linux + 284,
    inotify_add_watch = Linux + 285,
    inotify_rm_watch = Linux + 286,
    migrate_pages = Linux + 287,
    openat = Linux + 288,
    mkdirat = Linux + 289,
    mknodat = Linux + 290,
    fchownat = Linux + 291,
    futimesat = Linux + 292,
    fstatat64 = Linux + 293,
    unlinkat = Linux + 294,
    renameat = Linux + 295,
    linkat = Linux + 296,
    symlinkat = Linux + 297,
    readlinkat = Linux + 298,
    fchmodat = Linux + 299,
    faccessat = Linux + 300,
    pselect6 = Linux + 301,
    ppoll = Linux + 302,
    unshare = Linux + 303,
    splice = Linux + 304,
    sync_file_range = Linux + 305,
    tee = Linux + 306,
    vmsplice = Linux + 307,
    move_pages = Linux + 308,
    set_robust_list = Linux + 309,
    get_robust_list = Linux + 310,
    kexec_load = Linux + 311,
    getcpu = Linux + 312,
    epoll_pwait = Linux + 313,
    ioprio_set = Linux + 314,
    ioprio_get = Linux + 315,
    utimensat = Linux + 316,
    signalfd = Linux + 317,
    timerfd = Linux + 318,
    eventfd = Linux + 319,
    fallocate = Linux + 320,
    timerfd_create = Linux + 321,
    timerfd_gettime = Linux + 322,
    timerfd_settime = Linux + 323,
    signalfd4 = Linux + 324,
    eventfd2 = Linux + 325,
    epoll_create1 = Linux + 326,
    dup3 = Linux + 327,
    pipe2 = Linux + 328,
    inotify_init1 = Linux + 329,
    preadv = Linux + 330,
    pwritev = Linux + 331,
    rt_tgsigqueueinfo = Linux + 332,
    perf_event_open = Linux + 333,
    accept4 = Linux + 334,
    recvmmsg = Linux + 335,
    fanotify_init = Linux + 336,
    fanotify_mark = Linux + 337,
    prlimit64 = Linux + 338,
    name_to_handle_at = Linux + 339,
    open_by_handle_at = Linux + 340,
    clock_adjtime = Linux + 341,
    syncfs = Linux + 342,
    sendmmsg = Linux + 343,
    setns = Linux + 344,
    process_vm_readv = Linux + 345,
    process_vm_writev = Linux + 346,
    kcmp = Linux + 347,
    finit_module = Linux + 348,
    sched_setattr = Linux + 349,
    sched_getattr = Linux + 350,
    renameat2 = Linux + 351,
    seccomp = Linux + 352,
    getrandom = Linux + 353,
    memfd_create = Linux + 354,
    bpf = Linux + 355,
    execveat = Linux + 356,
    userfaultfd = Linux + 357,
    membarrier = Linux + 358,
    mlock2 = Linux + 359,
    copy_file_range = Linux + 360,
    preadv2 = Linux + 361,
    pwritev2 = Linux + 362,
    pkey_mprotect = Linux + 363,
    pkey_alloc = Linux + 364,
    pkey_free = Linux + 365,
    statx = Linux + 366,
    rseq = Linux + 367,
    io_pgetevents = Linux + 368,
    semget = Linux + 393,
    semctl = Linux + 394,
    shmget = Linux + 395,
    shmctl = Linux + 396,
    shmat = Linux + 397,
    shmdt = Linux + 398,
    msgget = Linux + 399,
    msgsnd = Linux + 400,
    msgrcv = Linux + 401,
    msgctl = Linux + 402,
    clock_gettime64 = Linux + 403,
    clock_settime64 = Linux + 404,
    clock_adjtime64 = Linux + 405,
    clock_getres_time64 = Linux + 406,
    clock_nanosleep_time64 = Linux + 407,
    timer_gettime64 = Linux + 408,
    timer_settime64 = Linux + 409,
    timerfd_gettime64 = Linux + 410,
    timerfd_settime64 = Linux + 411,
    utimensat_time64 = Linux + 412,
    pselect6_time64 = Linux + 413,
    ppoll_time64 = Linux + 414,
    io_pgetevents_time64 = Linux + 416,
    recvmmsg_time64 = Linux + 417,
    mq_timedsend_time64 = Linux + 418,
    mq_timedreceive_time64 = Linux + 419,
    semtimedop_time64 = Linux + 420,
    rt_sigtimedwait_time64 = Linux + 421,
    futex_time64 = Linux + 422,
    sched_rr_get_interval_time64 = Linux + 423,
    pidfd_send_signal = Linux + 424,
    io_uring_setup = Linux + 425,
    io_uring_enter = Linux + 426,
    io_uring_register = Linux + 427,
    open_tree = Linux + 428,
    move_mount = Linux + 429,
    fsopen = Linux + 430,
    fsconfig = Linux + 431,
    fsmount = Linux + 432,
    fspick = Linux + 433,
    pidfd_open = Linux + 434,
    clone3 = Linux + 435,
    close_range = Linux + 436,
    openat2 = Linux + 437,
    pidfd_getfd = Linux + 438,
    faccessat2 = Linux + 439,
    process_madvise = Linux + 440,

    _,
};

pub const O_CREAT = 0o0400;
pub const O_EXCL = 0o02000;
pub const O_NOCTTY = 0o04000;
pub const O_TRUNC = 0o01000;
pub const O_APPEND = 0o0010;
pub const O_NONBLOCK = 0o0200;
pub const O_DSYNC = 0o0020;
pub const O_SYNC = 0o040020;
pub const O_RSYNC = 0o040020;
pub const O_DIRECTORY = 0o0200000;
pub const O_NOFOLLOW = 0o0400000;
pub const O_CLOEXEC = 0o02000000;

pub const O_ASYNC = 0o010000;
pub const O_DIRECT = 0o0100000;
pub const O_LARGEFILE = 0o020000;
pub const O_NOATIME = 0o01000000;
pub const O_PATH = 0o010000000;
pub const O_TMPFILE = 0o020200000;
pub const O_NDELAY = O_NONBLOCK;

pub const F_DUPFD = 0;
pub const F_GETFD = 1;
pub const F_SETFD = 2;
pub const F_GETFL = 3;
pub const F_SETFL = 4;

pub const F_SETOWN = 24;
pub const F_GETOWN = 23;
pub const F_SETSIG = 10;
pub const F_GETSIG = 11;

pub const F_GETLK = 33;
pub const F_SETLK = 34;
pub const F_SETLKW = 35;

pub const F_RDLCK = 0;
pub const F_WRLCK = 1;
pub const F_UNLCK = 2;

pub const LOCK_SH = 1;
pub const LOCK_EX = 2;
pub const LOCK_UN = 8;
pub const LOCK_NB = 4;

pub const F_SETOWN_EX = 15;
pub const F_GETOWN_EX = 16;

pub const F_GETOWNER_UIDS = 17;

pub const MMAP2_UNIT = 4096;

pub const MAP_NORESERVE = 0x0400;
pub const MAP_GROWSDOWN = 0x1000;
pub const MAP_DENYWRITE = 0x2000;
pub const MAP_EXECUTABLE = 0x4000;
pub const MAP_LOCKED = 0x8000;
pub const MAP_32BIT = 0x40;

pub const SO_DEBUG = 1;
pub const SO_REUSEADDR = 0x0004;
pub const SO_KEEPALIVE = 0x0008;
pub const SO_DONTROUTE = 0x0010;
pub const SO_BROADCAST = 0x0020;
pub const SO_LINGER = 0x0080;
pub const SO_OOBINLINE = 0x0100;
pub const SO_REUSEPORT = 0x0200;
pub const SO_SNDBUF = 0x1001;
pub const SO_RCVBUF = 0x1002;
pub const SO_SNDLOWAT = 0x1003;
pub const SO_RCVLOWAT = 0x1004;
pub const SO_RCVTIMEO = 0x1006;
pub const SO_SNDTIMEO = 0x1005;
pub const SO_ERROR = 0x1007;
pub const SO_TYPE = 0x1008;
pub const SO_ACCEPTCONN = 0x1009;
pub const SO_PROTOCOL = 0x1028;
pub const SO_DOMAIN = 0x1029;
pub const SO_NO_CHECK = 11;
pub const SO_PRIORITY = 12;
pub const SO_BSDCOMPAT = 14;
pub const SO_PASSCRED = 17;
pub const SO_PEERCRED = 18;
pub const SO_PEERSEC = 30;
pub const SO_SNDBUFFORCE = 31;
pub const SO_RCVBUFFORCE = 33;

pub const VDSO_CGT_SYM = "__kernel_clock_gettime";
pub const VDSO_CGT_VER = "LINUX_2.6.39";

pub const Flock = extern struct {
    l_type: i16,
    l_whence: i16,
    __pad0: [4]u8,
    l_start: off_t,
    l_len: off_t,
    l_pid: pid_t,
    __unused: [4]u8,
};

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = i32;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;
pub const blkcnt_t = i64;

// The `stat` definition used by the Linux kernel.
pub const kernel_stat = extern struct {
    dev: u32,
    __pad0: [3]u32, // Reserved for st_dev expansion
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: u32,
    __pad1: [3]u32,
    size: off_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    blksize: blksize_t,
    __pad3: u32,
    blocks: blkcnt_t,
    __pad4: [14]usize,

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

pub const libc_stat = extern struct {
    dev: dev_t,
    __pad0: [2]u32,
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    __pad1: [2]u32,
    size: off_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    blksize: blksize_t,
    __pad3: u32,
    blocks: blkcnt_t,
    __pad4: [14]u32,

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

pub const Elf_Symndx = u32;
