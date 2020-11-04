// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// i386-specific declarations that are intended to be imported into the POSIX namespace.
// This does include Linux-only APIs.

const std = @import("../../../std.zig");
const linux = std.os.linux;
const socklen_t = linux.socklen_t;
const iovec = linux.iovec;
const iovec_const = linux.iovec_const;
const uid_t = linux.uid_t;
const gid_t = linux.gid_t;
const pid_t = linux.pid_t;
const stack_t = linux.stack_t;
const sigset_t = linux.sigset_t;

pub const SYS = extern enum(usize) {
    restart_syscall = 0,
    exit = 1,
    fork = 2,
    read = 3,
    write = 4,
    open = 5,
    close = 6,
    waitpid = 7,
    creat = 8,
    link = 9,
    unlink = 10,
    execve = 11,
    chdir = 12,
    time = 13,
    mknod = 14,
    chmod = 15,
    lchown = 16,
    @"break" = 17,
    oldstat = 18,
    lseek = 19,
    getpid = 20,
    mount = 21,
    umount = 22,
    setuid = 23,
    getuid = 24,
    stime = 25,
    ptrace = 26,
    alarm = 27,
    oldfstat = 28,
    pause = 29,
    utime = 30,
    stty = 31,
    gtty = 32,
    access = 33,
    nice = 34,
    ftime = 35,
    sync = 36,
    kill = 37,
    rename = 38,
    mkdir = 39,
    rmdir = 40,
    dup = 41,
    pipe = 42,
    times = 43,
    prof = 44,
    brk = 45,
    setgid = 46,
    getgid = 47,
    signal = 48,
    geteuid = 49,
    getegid = 50,
    acct = 51,
    umount2 = 52,
    lock = 53,
    ioctl = 54,
    fcntl = 55,
    mpx = 56,
    setpgid = 57,
    ulimit = 58,
    oldolduname = 59,
    umask = 60,
    chroot = 61,
    ustat = 62,
    dup2 = 63,
    getppid = 64,
    getpgrp = 65,
    setsid = 66,
    sigaction = 67,
    sgetmask = 68,
    ssetmask = 69,
    setreuid = 70,
    setregid = 71,
    sigsuspend = 72,
    sigpending = 73,
    sethostname = 74,
    setrlimit = 75,
    getrlimit = 76,
    getrusage = 77,
    gettimeofday = 78,
    settimeofday = 79,
    getgroups = 80,
    setgroups = 81,
    select = 82,
    symlink = 83,
    oldlstat = 84,
    readlink = 85,
    uselib = 86,
    swapon = 87,
    reboot = 88,
    readdir = 89,
    mmap = 90,
    munmap = 91,
    truncate = 92,
    ftruncate = 93,
    fchmod = 94,
    fchown = 95,
    getpriority = 96,
    setpriority = 97,
    profil = 98,
    statfs = 99,
    fstatfs = 100,
    ioperm = 101,
    socketcall = 102,
    syslog = 103,
    setitimer = 104,
    getitimer = 105,
    stat = 106,
    lstat = 107,
    fstat = 108,
    olduname = 109,
    iopl = 110,
    vhangup = 111,
    idle = 112,
    vm86old = 113,
    wait4 = 114,
    swapoff = 115,
    sysinfo = 116,
    ipc = 117,
    fsync = 118,
    sigreturn = 119,
    clone = 120,
    setdomainname = 121,
    uname = 122,
    modify_ldt = 123,
    adjtimex = 124,
    mprotect = 125,
    sigprocmask = 126,
    create_module = 127,
    init_module = 128,
    delete_module = 129,
    get_kernel_syms = 130,
    quotactl = 131,
    getpgid = 132,
    fchdir = 133,
    bdflush = 134,
    sysfs = 135,
    personality = 136,
    afs_syscall = 137,
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
    vm86 = 166,
    query_module = 167,
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
    getpmsg = 188,
    putpmsg = 189,
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
    pivot_root = 217,
    mincore = 218,
    madvise = 219,
    getdents64 = 220,
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
    set_thread_area = 243,
    get_thread_area = 244,
    io_setup = 245,
    io_destroy = 246,
    io_getevents = 247,
    io_submit = 248,
    io_cancel = 249,
    fadvise64 = 250,
    exit_group = 252,
    lookup_dcookie = 253,
    epoll_create = 254,
    epoll_ctl = 255,
    epoll_wait = 256,
    remap_file_pages = 257,
    set_tid_address = 258,
    timer_create = 259,
    timer_settime, // SYS_timer_create + 1
    timer_gettime, // SYS_timer_create + 2
    timer_getoverrun, // SYS_timer_create + 3
    timer_delete, // SYS_timer_create + 4
    clock_settime, // SYS_timer_create + 5
    clock_gettime, // SYS_timer_create + 6
    clock_getres, // SYS_timer_create + 7
    clock_nanosleep, // SYS_timer_create + 8
    statfs64 = 268,
    fstatfs64 = 269,
    tgkill = 270,
    utimes = 271,
    fadvise64_64 = 272,
    vserver = 273,
    mbind = 274,
    get_mempolicy = 275,
    set_mempolicy = 276,
    mq_open = 277,
    mq_unlink, // SYS_mq_open + 1
    mq_timedsend, // SYS_mq_open + 2
    mq_timedreceive, // SYS_mq_open + 3
    mq_notify, // SYS_mq_open + 4
    mq_getsetattr, // SYS_mq_open + 5
    kexec_load = 283,
    waitid = 284,
    add_key = 286,
    request_key = 287,
    keyctl = 288,
    ioprio_set = 289,
    ioprio_get = 290,
    inotify_init = 291,
    inotify_add_watch = 292,
    inotify_rm_watch = 293,
    migrate_pages = 294,
    openat = 295,
    mkdirat = 296,
    mknodat = 297,
    fchownat = 298,
    futimesat = 299,
    fstatat64 = 300,
    unlinkat = 301,
    renameat = 302,
    linkat = 303,
    symlinkat = 304,
    readlinkat = 305,
    fchmodat = 306,
    faccessat = 307,
    pselect6 = 308,
    ppoll = 309,
    unshare = 310,
    set_robust_list = 311,
    get_robust_list = 312,
    splice = 313,
    sync_file_range = 314,
    tee = 315,
    vmsplice = 316,
    move_pages = 317,
    getcpu = 318,
    epoll_pwait = 319,
    utimensat = 320,
    signalfd = 321,
    timerfd_create = 322,
    eventfd = 323,
    fallocate = 324,
    timerfd_settime = 325,
    timerfd_gettime = 326,
    signalfd4 = 327,
    eventfd2 = 328,
    epoll_create1 = 329,
    dup3 = 330,
    pipe2 = 331,
    inotify_init1 = 332,
    preadv = 333,
    pwritev = 334,
    rt_tgsigqueueinfo = 335,
    perf_event_open = 336,
    recvmmsg = 337,
    fanotify_init = 338,
    fanotify_mark = 339,
    prlimit64 = 340,
    name_to_handle_at = 341,
    open_by_handle_at = 342,
    clock_adjtime = 343,
    syncfs = 344,
    sendmmsg = 345,
    setns = 346,
    process_vm_readv = 347,
    process_vm_writev = 348,
    kcmp = 349,
    finit_module = 350,
    sched_setattr = 351,
    sched_getattr = 352,
    renameat2 = 353,
    seccomp = 354,
    getrandom = 355,
    memfd_create = 356,
    bpf = 357,
    execveat = 358,
    socket = 359,
    socketpair = 360,
    bind = 361,
    connect = 362,
    listen = 363,
    accept4 = 364,
    getsockopt = 365,
    setsockopt = 366,
    getsockname = 367,
    getpeername = 368,
    sendto = 369,
    sendmsg = 370,
    recvfrom = 371,
    recvmsg = 372,
    shutdown = 373,
    userfaultfd = 374,
    membarrier = 375,
    mlock2 = 376,
    copy_file_range = 377,
    preadv2 = 378,
    pwritev2 = 379,
    pkey_mprotect = 380,
    pkey_alloc = 381,
    pkey_free = 382,
    statx = 383,
    arch_prctl = 384,
    io_pgetevents = 385,
    rseq = 386,
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
    openat2 = 437,
    pidfd_getfd = 438,

    _,
};

pub const O_CREAT = 0o100;
pub const O_EXCL = 0o200;
pub const O_NOCTTY = 0o400;
pub const O_TRUNC = 0o1000;
pub const O_APPEND = 0o2000;
pub const O_NONBLOCK = 0o4000;
pub const O_DSYNC = 0o10000;
pub const O_SYNC = 0o4010000;
pub const O_RSYNC = 0o4010000;
pub const O_DIRECTORY = 0o200000;
pub const O_NOFOLLOW = 0o400000;
pub const O_CLOEXEC = 0o2000000;

pub const O_ASYNC = 0o20000;
pub const O_DIRECT = 0o40000;
pub const O_LARGEFILE = 0o100000;
pub const O_NOATIME = 0o1000000;
pub const O_PATH = 0o10000000;
pub const O_TMPFILE = 0o20200000;
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

pub const LOCK_SH = 1;
pub const LOCK_EX = 2;
pub const LOCK_UN = 8;
pub const LOCK_NB = 4;

pub const F_SETOWN_EX = 15;
pub const F_GETOWN_EX = 16;

pub const F_GETOWNER_UIDS = 17;

pub const MAP_NORESERVE = 0x4000;
pub const MAP_GROWSDOWN = 0x0100;
pub const MAP_DENYWRITE = 0x0800;
pub const MAP_EXECUTABLE = 0x1000;
pub const MAP_LOCKED = 0x2000;
pub const MAP_32BIT = 0x40;

pub const MMAP2_UNIT = 4096;

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

// The `stat` definition used by the Linux kernel.
pub const kernel_stat = extern struct {
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

// The `stat64` definition used by the libc.
pub const libc_stat = kernel_stat;

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
    gregs: [19]usize,
    fpregs: [*]u8,
    oldmask: usize,
    cr2: usize,
};

pub const REG_GS = 0;
pub const REG_FS = 1;
pub const REG_ES = 2;
pub const REG_DS = 3;
pub const REG_EDI = 4;
pub const REG_ESI = 5;
pub const REG_EBP = 6;
pub const REG_ESP = 7;
pub const REG_EBX = 8;
pub const REG_EDX = 9;
pub const REG_ECX = 10;
pub const REG_EAX = 11;
pub const REG_TRAPNO = 12;
pub const REG_ERR = 13;
pub const REG_EIP = 14;
pub const REG_CS = 15;
pub const REG_EFL = 16;
pub const REG_UESP = 17;
pub const REG_SS = 18;

pub const ucontext_t = extern struct {
    flags: usize,
    link: *ucontext_t,
    stack: stack_t,
    mcontext: mcontext_t,
    sigmask: sigset_t,
    regspace: [64]u64,
};

pub const Elf_Symndx = u32;

pub const user_desc = packed struct {
    entry_number: u32,
    base_addr: u32,
    limit: u32,
    seg_32bit: u1,
    contents: u2,
    read_exec_only: u1,
    limit_in_pages: u1,
    seg_not_present: u1,
    useable: u1,
};

// socketcall() call numbers
pub const SC_socket = 1;
pub const SC_bind = 2;
pub const SC_connect = 3;
pub const SC_listen = 4;
pub const SC_accept = 5;
pub const SC_getsockname = 6;
pub const SC_getpeername = 7;
pub const SC_socketpair = 8;
pub const SC_send = 9;
pub const SC_recv = 10;
pub const SC_sendto = 11;
pub const SC_recvfrom = 12;
pub const SC_shutdown = 13;
pub const SC_setsockopt = 14;
pub const SC_getsockopt = 15;
pub const SC_sendmsg = 16;
pub const SC_recvmsg = 17;
pub const SC_accept4 = 18;
pub const SC_recvmmsg = 19;
pub const SC_sendmmsg = 20;
