// x86-64-specific declarations that are intended to be imported into the POSIX namespace.
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

pub const mode_t = usize;

pub const SYS_read = 0;
pub const SYS_write = 1;
pub const SYS_open = 2;
pub const SYS_close = 3;
pub const SYS_stat = 4;
pub const SYS_fstat = 5;
pub const SYS_lstat = 6;
pub const SYS_poll = 7;
pub const SYS_lseek = 8;
pub const SYS_mmap = 9;
pub const SYS_mprotect = 10;
pub const SYS_munmap = 11;
pub const SYS_brk = 12;
pub const SYS_rt_sigaction = 13;
pub const SYS_rt_sigprocmask = 14;
pub const SYS_rt_sigreturn = 15;
pub const SYS_ioctl = 16;
pub const SYS_pread = 17;
pub const SYS_pwrite = 18;
pub const SYS_readv = 19;
pub const SYS_writev = 20;
pub const SYS_access = 21;
pub const SYS_pipe = 22;
pub const SYS_select = 23;
pub const SYS_sched_yield = 24;
pub const SYS_mremap = 25;
pub const SYS_msync = 26;
pub const SYS_mincore = 27;
pub const SYS_madvise = 28;
pub const SYS_shmget = 29;
pub const SYS_shmat = 30;
pub const SYS_shmctl = 31;
pub const SYS_dup = 32;
pub const SYS_dup2 = 33;
pub const SYS_pause = 34;
pub const SYS_nanosleep = 35;
pub const SYS_getitimer = 36;
pub const SYS_alarm = 37;
pub const SYS_setitimer = 38;
pub const SYS_getpid = 39;
pub const SYS_sendfile = 40;
pub const SYS_socket = 41;
pub const SYS_connect = 42;
pub const SYS_accept = 43;
pub const SYS_sendto = 44;
pub const SYS_recvfrom = 45;
pub const SYS_sendmsg = 46;
pub const SYS_recvmsg = 47;
pub const SYS_shutdown = 48;
pub const SYS_bind = 49;
pub const SYS_listen = 50;
pub const SYS_getsockname = 51;
pub const SYS_getpeername = 52;
pub const SYS_socketpair = 53;
pub const SYS_setsockopt = 54;
pub const SYS_getsockopt = 55;
pub const SYS_clone = 56;
pub const SYS_fork = 57;
pub const SYS_vfork = 58;
pub const SYS_execve = 59;
pub const SYS_exit = 60;
pub const SYS_wait4 = 61;
pub const SYS_kill = 62;
pub const SYS_uname = 63;
pub const SYS_semget = 64;
pub const SYS_semop = 65;
pub const SYS_semctl = 66;
pub const SYS_shmdt = 67;
pub const SYS_msgget = 68;
pub const SYS_msgsnd = 69;
pub const SYS_msgrcv = 70;
pub const SYS_msgctl = 71;
pub const SYS_fcntl = 72;
pub const SYS_flock = 73;
pub const SYS_fsync = 74;
pub const SYS_fdatasync = 75;
pub const SYS_truncate = 76;
pub const SYS_ftruncate = 77;
pub const SYS_getdents = 78;
pub const SYS_getcwd = 79;
pub const SYS_chdir = 80;
pub const SYS_fchdir = 81;
pub const SYS_rename = 82;
pub const SYS_mkdir = 83;
pub const SYS_rmdir = 84;
pub const SYS_creat = 85;
pub const SYS_link = 86;
pub const SYS_unlink = 87;
pub const SYS_symlink = 88;
pub const SYS_readlink = 89;
pub const SYS_chmod = 90;
pub const SYS_fchmod = 91;
pub const SYS_chown = 92;
pub const SYS_fchown = 93;
pub const SYS_lchown = 94;
pub const SYS_umask = 95;
pub const SYS_gettimeofday = 96;
pub const SYS_getrlimit = 97;
pub const SYS_getrusage = 98;
pub const SYS_sysinfo = 99;
pub const SYS_times = 100;
pub const SYS_ptrace = 101;
pub const SYS_getuid = 102;
pub const SYS_syslog = 103;
pub const SYS_getgid = 104;
pub const SYS_setuid = 105;
pub const SYS_setgid = 106;
pub const SYS_geteuid = 107;
pub const SYS_getegid = 108;
pub const SYS_setpgid = 109;
pub const SYS_getppid = 110;
pub const SYS_getpgrp = 111;
pub const SYS_setsid = 112;
pub const SYS_setreuid = 113;
pub const SYS_setregid = 114;
pub const SYS_getgroups = 115;
pub const SYS_setgroups = 116;
pub const SYS_setresuid = 117;
pub const SYS_getresuid = 118;
pub const SYS_setresgid = 119;
pub const SYS_getresgid = 120;
pub const SYS_getpgid = 121;
pub const SYS_setfsuid = 122;
pub const SYS_setfsgid = 123;
pub const SYS_getsid = 124;
pub const SYS_capget = 125;
pub const SYS_capset = 126;
pub const SYS_rt_sigpending = 127;
pub const SYS_rt_sigtimedwait = 128;
pub const SYS_rt_sigqueueinfo = 129;
pub const SYS_rt_sigsuspend = 130;
pub const SYS_sigaltstack = 131;
pub const SYS_utime = 132;
pub const SYS_mknod = 133;
pub const SYS_uselib = 134;
pub const SYS_personality = 135;
pub const SYS_ustat = 136;
pub const SYS_statfs = 137;
pub const SYS_fstatfs = 138;
pub const SYS_sysfs = 139;
pub const SYS_getpriority = 140;
pub const SYS_setpriority = 141;
pub const SYS_sched_setparam = 142;
pub const SYS_sched_getparam = 143;
pub const SYS_sched_setscheduler = 144;
pub const SYS_sched_getscheduler = 145;
pub const SYS_sched_get_priority_max = 146;
pub const SYS_sched_get_priority_min = 147;
pub const SYS_sched_rr_get_interval = 148;
pub const SYS_mlock = 149;
pub const SYS_munlock = 150;
pub const SYS_mlockall = 151;
pub const SYS_munlockall = 152;
pub const SYS_vhangup = 153;
pub const SYS_modify_ldt = 154;
pub const SYS_pivot_root = 155;
pub const SYS__sysctl = 156;
pub const SYS_prctl = 157;
pub const SYS_arch_prctl = 158;
pub const SYS_adjtimex = 159;
pub const SYS_setrlimit = 160;
pub const SYS_chroot = 161;
pub const SYS_sync = 162;
pub const SYS_acct = 163;
pub const SYS_settimeofday = 164;
pub const SYS_mount = 165;
pub const SYS_umount2 = 166;
pub const SYS_swapon = 167;
pub const SYS_swapoff = 168;
pub const SYS_reboot = 169;
pub const SYS_sethostname = 170;
pub const SYS_setdomainname = 171;
pub const SYS_iopl = 172;
pub const SYS_ioperm = 173;
pub const SYS_create_module = 174;
pub const SYS_init_module = 175;
pub const SYS_delete_module = 176;
pub const SYS_get_kernel_syms = 177;
pub const SYS_query_module = 178;
pub const SYS_quotactl = 179;
pub const SYS_nfsservctl = 180;
pub const SYS_getpmsg = 181;
pub const SYS_putpmsg = 182;
pub const SYS_afs_syscall = 183;
pub const SYS_tuxcall = 184;
pub const SYS_security = 185;
pub const SYS_gettid = 186;
pub const SYS_readahead = 187;
pub const SYS_setxattr = 188;
pub const SYS_lsetxattr = 189;
pub const SYS_fsetxattr = 190;
pub const SYS_getxattr = 191;
pub const SYS_lgetxattr = 192;
pub const SYS_fgetxattr = 193;
pub const SYS_listxattr = 194;
pub const SYS_llistxattr = 195;
pub const SYS_flistxattr = 196;
pub const SYS_removexattr = 197;
pub const SYS_lremovexattr = 198;
pub const SYS_fremovexattr = 199;
pub const SYS_tkill = 200;
pub const SYS_time = 201;
pub const SYS_futex = 202;
pub const SYS_sched_setaffinity = 203;
pub const SYS_sched_getaffinity = 204;
pub const SYS_set_thread_area = 205;
pub const SYS_io_setup = 206;
pub const SYS_io_destroy = 207;
pub const SYS_io_getevents = 208;
pub const SYS_io_submit = 209;
pub const SYS_io_cancel = 210;
pub const SYS_get_thread_area = 211;
pub const SYS_lookup_dcookie = 212;
pub const SYS_epoll_create = 213;
pub const SYS_epoll_ctl_old = 214;
pub const SYS_epoll_wait_old = 215;
pub const SYS_remap_file_pages = 216;
pub const SYS_getdents64 = 217;
pub const SYS_set_tid_address = 218;
pub const SYS_restart_syscall = 219;
pub const SYS_semtimedop = 220;
pub const SYS_fadvise64 = 221;
pub const SYS_timer_create = 222;
pub const SYS_timer_settime = 223;
pub const SYS_timer_gettime = 224;
pub const SYS_timer_getoverrun = 225;
pub const SYS_timer_delete = 226;
pub const SYS_clock_settime = 227;
pub const SYS_clock_gettime = 228;
pub const SYS_clock_getres = 229;
pub const SYS_clock_nanosleep = 230;
pub const SYS_exit_group = 231;
pub const SYS_epoll_wait = 232;
pub const SYS_epoll_ctl = 233;
pub const SYS_tgkill = 234;
pub const SYS_utimes = 235;
pub const SYS_vserver = 236;
pub const SYS_mbind = 237;
pub const SYS_set_mempolicy = 238;
pub const SYS_get_mempolicy = 239;
pub const SYS_mq_open = 240;
pub const SYS_mq_unlink = 241;
pub const SYS_mq_timedsend = 242;
pub const SYS_mq_timedreceive = 243;
pub const SYS_mq_notify = 244;
pub const SYS_mq_getsetattr = 245;
pub const SYS_kexec_load = 246;
pub const SYS_waitid = 247;
pub const SYS_add_key = 248;
pub const SYS_request_key = 249;
pub const SYS_keyctl = 250;
pub const SYS_ioprio_set = 251;
pub const SYS_ioprio_get = 252;
pub const SYS_inotify_init = 253;
pub const SYS_inotify_add_watch = 254;
pub const SYS_inotify_rm_watch = 255;
pub const SYS_migrate_pages = 256;
pub const SYS_openat = 257;
pub const SYS_mkdirat = 258;
pub const SYS_mknodat = 259;
pub const SYS_fchownat = 260;
pub const SYS_futimesat = 261;
pub const SYS_newfstatat = 262;
pub const SYS_fstatat = 262;
pub const SYS_unlinkat = 263;
pub const SYS_renameat = 264;
pub const SYS_linkat = 265;
pub const SYS_symlinkat = 266;
pub const SYS_readlinkat = 267;
pub const SYS_fchmodat = 268;
pub const SYS_faccessat = 269;
pub const SYS_pselect6 = 270;
pub const SYS_ppoll = 271;
pub const SYS_unshare = 272;
pub const SYS_set_robust_list = 273;
pub const SYS_get_robust_list = 274;
pub const SYS_splice = 275;
pub const SYS_tee = 276;
pub const SYS_sync_file_range = 277;
pub const SYS_vmsplice = 278;
pub const SYS_move_pages = 279;
pub const SYS_utimensat = 280;
pub const SYS_epoll_pwait = 281;
pub const SYS_signalfd = 282;
pub const SYS_timerfd_create = 283;
pub const SYS_eventfd = 284;
pub const SYS_fallocate = 285;
pub const SYS_timerfd_settime = 286;
pub const SYS_timerfd_gettime = 287;
pub const SYS_accept4 = 288;
pub const SYS_signalfd4 = 289;
pub const SYS_eventfd2 = 290;
pub const SYS_epoll_create1 = 291;
pub const SYS_dup3 = 292;
pub const SYS_pipe2 = 293;
pub const SYS_inotify_init1 = 294;
pub const SYS_preadv = 295;
pub const SYS_pwritev = 296;
pub const SYS_rt_tgsigqueueinfo = 297;
pub const SYS_perf_event_open = 298;
pub const SYS_recvmmsg = 299;
pub const SYS_fanotify_init = 300;
pub const SYS_fanotify_mark = 301;
pub const SYS_prlimit64 = 302;
pub const SYS_name_to_handle_at = 303;
pub const SYS_open_by_handle_at = 304;
pub const SYS_clock_adjtime = 305;
pub const SYS_syncfs = 306;
pub const SYS_sendmmsg = 307;
pub const SYS_setns = 308;
pub const SYS_getcpu = 309;
pub const SYS_process_vm_readv = 310;
pub const SYS_process_vm_writev = 311;
pub const SYS_kcmp = 312;
pub const SYS_finit_module = 313;
pub const SYS_sched_setattr = 314;
pub const SYS_sched_getattr = 315;
pub const SYS_renameat2 = 316;
pub const SYS_seccomp = 317;
pub const SYS_getrandom = 318;
pub const SYS_memfd_create = 319;
pub const SYS_kexec_file_load = 320;
pub const SYS_bpf = 321;
pub const SYS_execveat = 322;
pub const SYS_userfaultfd = 323;
pub const SYS_membarrier = 324;
pub const SYS_mlock2 = 325;
pub const SYS_copy_file_range = 326;
pub const SYS_preadv2 = 327;
pub const SYS_pwritev2 = 328;
pub const SYS_pkey_mprotect = 329;
pub const SYS_pkey_alloc = 330;
pub const SYS_pkey_free = 331;
pub const SYS_statx = 332;
pub const SYS_io_pgetevents = 333;
pub const SYS_rseq = 334;
pub const SYS_pidfd_send_signal = 424;
pub const SYS_io_uring_setup = 425;
pub const SYS_io_uring_enter = 426;
pub const SYS_io_uring_register = 427;
pub const SYS_open_tree = 428;
pub const SYS_move_mount = 429;
pub const SYS_fsopen = 430;
pub const SYS_fsconfig = 431;
pub const SYS_fsmount = 432;
pub const SYS_fspick = 433;
pub const SYS_pidfd_open = 434;
pub const SYS_clone3 = 435;

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
pub const O_LARGEFILE = 0;
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

pub const F_SETOWN_EX = 15;
pub const F_GETOWN_EX = 16;

pub const F_GETOWNER_UIDS = 17;

/// only give out 32bit addresses
pub const MAP_32BIT = 0x40;

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
pub const VDSO_GETCPU_SYM = "__vdso_getcpu";
pub const VDSO_GETCPU_VER = "LINUX_2.6";

pub const ARCH_SET_GS = 0x1001;
pub const ARCH_SET_FS = 0x1002;
pub const ARCH_GET_FS = 0x1003;
pub const ARCH_GET_GS = 0x1004;

pub const REG_R8 = 0;
pub const REG_R9 = 1;
pub const REG_R10 = 2;
pub const REG_R11 = 3;
pub const REG_R12 = 4;
pub const REG_R13 = 5;
pub const REG_R14 = 6;
pub const REG_R15 = 7;
pub const REG_RDI = 8;
pub const REG_RSI = 9;
pub const REG_RBP = 10;
pub const REG_RBX = 11;
pub const REG_RDX = 12;
pub const REG_RAX = 13;
pub const REG_RCX = 14;
pub const REG_RSP = 15;
pub const REG_RIP = 16;
pub const REG_EFL = 17;
pub const REG_CSGSFS = 18;
pub const REG_ERR = 19;
pub const REG_TRAPNO = 20;
pub const REG_OLDMASK = 21;
pub const REG_CR2 = 22;

pub const msghdr = extern struct {
    msg_name: ?*sockaddr,
    msg_namelen: socklen_t,
    msg_iov: [*]iovec,
    msg_iovlen: i32,
    __pad1: i32,
    msg_control: ?*c_void,
    msg_controllen: socklen_t,
    __pad2: socklen_t,
    msg_flags: i32,
};

pub const msghdr_const = extern struct {
    msg_name: ?*const sockaddr,
    msg_namelen: socklen_t,
    msg_iov: [*]iovec_const,
    msg_iovlen: i32,
    __pad1: i32,
    msg_control: ?*c_void,
    msg_controllen: socklen_t,
    __pad2: socklen_t,
    msg_flags: i32,
};

pub const off_t = i64;
pub const ino_t = u64;

/// Renamed to Stat to not conflict with the stat function.
/// atime, mtime, and ctime have functions to return `timespec`,
/// because although this is a POSIX API, the layout and names of
/// the structs are inconsistent across operating systems, and
/// in C, macros are used to hide the differences. Here we use
/// methods to accomplish this.
pub const Stat = extern struct {
    dev: u64,
    ino: ino_t,
    nlink: usize,

    mode: u32,
    uid: u32,
    gid: u32,
    __pad0: u32,
    rdev: u64,
    size: off_t,
    blksize: isize,
    blocks: i64,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    __unused: [3]isize,

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

pub const greg_t = usize;
pub const gregset_t = [23]greg_t;
pub const fpstate = extern struct {
    cwd: u16,
    swd: u16,
    ftw: u16,
    fop: u16,
    rip: usize,
    rdp: usize,
    mxcsr: u32,
    mxcr_mask: u32,
    st: [8]extern struct {
        significand: [4]u16,
        exponent: u16,
        padding: [3]u16 = undefined,
    },
    xmm: [16]extern struct {
        element: [4]u32,
    },
    padding: [24]u32 = undefined,
};
pub const fpregset_t = *fpstate;
pub const sigcontext = extern struct {
    r8: usize,
    r9: usize,
    r10: usize,
    r11: usize,
    r12: usize,
    r13: usize,
    r14: usize,
    r15: usize,

    rdi: usize,
    rsi: usize,
    rbp: usize,
    rbx: usize,
    rdx: usize,
    rax: usize,
    rcx: usize,
    rsp: usize,
    rip: usize,
    eflags: usize,

    cs: u16,
    gs: u16,
    fs: u16,
    pad0: u16 = undefined,

    err: usize,
    trapno: usize,
    oldmask: usize,
    cr2: usize,

    fpstate: *fpstate,
    reserved1: [8]usize = undefined,
};

pub const mcontext_t = extern struct {
    gregs: gregset_t,
    fpregs: fpregset_t,
    reserved1: [8]usize = undefined,
};

pub const ucontext_t = extern struct {
    flags: usize,
    link: *ucontext_t,
    stack: stack_t,
    mcontext: mcontext_t,
    sigmask: sigset_t,
    fpregs_mem: [64]usize,
};
