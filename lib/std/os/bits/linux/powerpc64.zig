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
    vm86 = 113,
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
    query_module = 166,
    poll = 167,
    nfsservctl = 168,
    setresgid = 169,
    getresgid = 170,
    prctl = 171,
    rt_sigreturn = 172,
    rt_sigaction = 173,
    rt_sigprocmask = 174,
    rt_sigpending = 175,
    rt_sigtimedwait = 176,
    rt_sigqueueinfo = 177,
    rt_sigsuspend = 178,
    pread64 = 179,
    pwrite64 = 180,
    chown = 181,
    getcwd = 182,
    capget = 183,
    capset = 184,
    sigaltstack = 185,
    sendfile = 186,
    getpmsg = 187,
    putpmsg = 188,
    vfork = 189,
    ugetrlimit = 190,
    readahead = 191,
    pciconfig_read = 198,
    pciconfig_write = 199,
    pciconfig_iobase = 200,
    multiplexer = 201,
    getdents64 = 202,
    pivot_root = 203,
    madvise = 205,
    mincore = 206,
    gettid = 207,
    tkill = 208,
    setxattr = 209,
    lsetxattr = 210,
    fsetxattr = 211,
    getxattr = 212,
    lgetxattr = 213,
    fgetxattr = 214,
    listxattr = 215,
    llistxattr = 216,
    flistxattr = 217,
    removexattr = 218,
    lremovexattr = 219,
    fremovexattr = 220,
    futex = 221,
    sched_setaffinity = 222,
    sched_getaffinity = 223,
    tuxcall = 225,
    io_setup = 227,
    io_destroy = 228,
    io_getevents = 229,
    io_submit = 230,
    io_cancel = 231,
    set_tid_address = 232,
    fadvise64 = 233,
    exit_group = 234,
    lookup_dcookie = 235,
    epoll_create = 236,
    epoll_ctl = 237,
    epoll_wait = 238,
    remap_file_pages = 239,
    timer_create = 240,
    timer_settime = 241,
    timer_gettime = 242,
    timer_getoverrun = 243,
    timer_delete = 244,
    clock_settime = 245,
    clock_gettime = 246,
    clock_getres = 247,
    clock_nanosleep = 248,
    swapcontext = 249,
    tgkill = 250,
    utimes = 251,
    statfs64 = 252,
    fstatfs64 = 253,
    rtas = 255,
    sys_debug_setcontext = 256,
    migrate_pages = 258,
    mbind = 259,
    get_mempolicy = 260,
    set_mempolicy = 261,
    mq_open = 262,
    mq_unlink = 263,
    mq_timedsend = 264,
    mq_timedreceive = 265,
    mq_notify = 266,
    mq_getsetattr = 267,
    kexec_load = 268,
    add_key = 269,
    request_key = 270,
    keyctl = 271,
    waitid = 272,
    ioprio_set = 273,
    ioprio_get = 274,
    inotify_init = 275,
    inotify_add_watch = 276,
    inotify_rm_watch = 277,
    spu_run = 278,
    spu_create = 279,
    pselect6 = 280,
    ppoll = 281,
    unshare = 282,
    splice = 283,
    tee = 284,
    vmsplice = 285,
    openat = 286,
    mkdirat = 287,
    mknodat = 288,
    fchownat = 289,
    futimesat = 290,
    newfstatat = 291,
    unlinkat = 292,
    renameat = 293,
    linkat = 294,
    symlinkat = 295,
    readlinkat = 296,
    fchmodat = 297,
    faccessat = 298,
    get_robust_list = 299,
    set_robust_list = 300,
    move_pages = 301,
    getcpu = 302,
    epoll_pwait = 303,
    utimensat = 304,
    signalfd = 305,
    timerfd_create = 306,
    eventfd = 307,
    sync_file_range2 = 308,
    fallocate = 309,
    subpage_prot = 310,
    timerfd_settime = 311,
    timerfd_gettime = 312,
    signalfd4 = 313,
    eventfd2 = 314,
    epoll_create1 = 315,
    dup3 = 316,
    pipe2 = 317,
    inotify_init1 = 318,
    perf_event_open = 319,
    preadv = 320,
    pwritev = 321,
    rt_tgsigqueueinfo = 322,
    fanotify_init = 323,
    fanotify_mark = 324,
    prlimit64 = 325,
    socket = 326,
    bind = 327,
    connect = 328,
    listen = 329,
    accept = 330,
    getsockname = 331,
    getpeername = 332,
    socketpair = 333,
    send = 334,
    sendto = 335,
    recv = 336,
    recvfrom = 337,
    shutdown = 338,
    setsockopt = 339,
    getsockopt = 340,
    sendmsg = 341,
    recvmsg = 342,
    recvmmsg = 343,
    accept4 = 344,
    name_to_handle_at = 345,
    open_by_handle_at = 346,
    clock_adjtime = 347,
    syncfs = 348,
    sendmmsg = 349,
    setns = 350,
    process_vm_readv = 351,
    process_vm_writev = 352,
    finit_module = 353,
    kcmp = 354,
    sched_setattr = 355,
    sched_getattr = 356,
    renameat2 = 357,
    seccomp = 358,
    getrandom = 359,
    memfd_create = 360,
    bpf = 361,
    execveat = 362,
    switch_endian = 363,
    userfaultfd = 364,
    membarrier = 365,
    mlock2 = 378,
    copy_file_range = 379,
    preadv2 = 380,
    pwritev2 = 381,
    kexec_file_load = 382,
    statx = 383,
    pkey_alloc = 384,
    pkey_free = 385,
    pkey_mprotect = 386,
    rseq = 387,
    io_pgetevents = 388,
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
pub const O_DIRECTORY = 0o40000;
pub const O_NOFOLLOW = 0o100000;
pub const O_CLOEXEC = 0o2000000;

pub const O_ASYNC = 0o20000;
pub const O_DIRECT = 0o400000;
pub const O_LARGEFILE = 0o200000;
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

pub const F_GETLK = 5;
pub const F_SETLK = 6;
pub const F_SETLKW = 7;

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

/// stack-like segment
pub const MAP_GROWSDOWN = 0x0100;

/// ETXTBSY
pub const MAP_DENYWRITE = 0x0800;

/// mark it as an executable
pub const MAP_EXECUTABLE = 0x1000;

/// pages are locked
pub const MAP_LOCKED = 0x0080;

/// don't check for reservations
pub const MAP_NORESERVE = 0x0040;

pub const VDSO_CGT_SYM = "__kernel_clock_gettime";
pub const VDSO_CGT_VER = "LINUX_2.6.15";

pub const Flock = extern struct {
    l_type: i16,
    l_whence: i16,
    l_start: off_t,
    l_len: off_t,
    l_pid: pid_t,
    __unused: [4]u8,
};

pub const msghdr = extern struct {
    msg_name: ?*sockaddr,
    msg_namelen: socklen_t,
    msg_iov: [*]iovec,
    msg_iovlen: usize,
    msg_control: ?*c_void,
    msg_controllen: usize,
    msg_flags: i32,
};

pub const msghdr_const = extern struct {
    msg_name: ?*const sockaddr,
    msg_namelen: socklen_t,
    msg_iov: [*]iovec_const,
    msg_iovlen: usize,
    msg_control: ?*c_void,
    msg_controllen: usize,
    msg_flags: i32,
};

pub const blksize_t = i64;
pub const nlink_t = u64;
pub const time_t = i64;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;
pub const blkcnt_t = i64;

// The `stat` definition used by the Linux kernel.
pub const kernel_stat = extern struct {
    dev: dev_t,
    ino: ino_t,
    nlink: nlink_t,
    mode: mode_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    size: off_t,
    blksize: blksize_t,
    blocks: blkcnt_t,
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

// The `stat64` definition used by the libc.
pub const libc_stat = kernel_stat;

pub const timespec = extern struct {
    tv_sec: time_t,
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

pub const greg_t = u64;
pub const gregset_t = [48]greg_t;
pub const fpregset_t = [33]f64;

/// The position of the vscr register depends on endianness.
/// On C, macros are used to change vscr_word's offset to
/// account for this. Here we'll just define vscr_word_le
/// and vscr_word_be. Code must take care to use the correct one.
pub const vrregset = extern struct {
    vrregs: [32][4]u32 align(16),
    vscr_word_le: u32,
    _pad1: [2]u32,
    vscr_word_be: u32,
    vrsave: u32,
    _pad2: [3]u32,
};
pub const vrregset_t = vrregset;

pub const mcontext_t = extern struct {
    __unused: [4]u64,
    signal: i32,
    _pad0: i32,
    handler: u64,
    oldmask: u64,
    regs: ?*c_void,
    gp_regs: gregset_t,
    fp_regs: fpregset_t,
    v_regs: *vrregset_t,
    vmx_reserve: [34 + 34 + 32 + 1]i64,
};

pub const ucontext_t = extern struct {
    flags: u32,
    link: *ucontext_t,
    stack: stack_t,
    sigmask: sigset_t,
    mcontext: mcontext_t,
};

pub const Elf_Symndx = u32;
