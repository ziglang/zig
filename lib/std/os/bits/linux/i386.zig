// i386-specific declarations that are intended to be imported into the POSIX namespace.
// This does include Linux-only APIs.

const std = @import("../../../std.zig");
const linux = std.os.linux;
const socklen_t = linux.socklen_t;
const iovec = linux.iovec;
const iovec_const = linux.iovec_const;
const uid_t = linux.uid_t;
const gid_t = linux.gid_t;
const stack_t = linux.stack_t;
const sigset_t = linux.sigset_t;

pub const SYS_restart_syscall = 0;
pub const SYS_exit = 1;
pub const SYS_fork = 2;
pub const SYS_read = 3;
pub const SYS_write = 4;
pub const SYS_open = 5;
pub const SYS_close = 6;
pub const SYS_waitpid = 7;
pub const SYS_creat = 8;
pub const SYS_link = 9;
pub const SYS_unlink = 10;
pub const SYS_execve = 11;
pub const SYS_chdir = 12;
pub const SYS_time = 13;
pub const SYS_mknod = 14;
pub const SYS_chmod = 15;
pub const SYS_lchown = 16;
pub const SYS_break = 17;
pub const SYS_oldstat = 18;
pub const SYS_lseek = 19;
pub const SYS_getpid = 20;
pub const SYS_mount = 21;
pub const SYS_umount = 22;
pub const SYS_setuid = 23;
pub const SYS_getuid = 24;
pub const SYS_stime = 25;
pub const SYS_ptrace = 26;
pub const SYS_alarm = 27;
pub const SYS_oldfstat = 28;
pub const SYS_pause = 29;
pub const SYS_utime = 30;
pub const SYS_stty = 31;
pub const SYS_gtty = 32;
pub const SYS_access = 33;
pub const SYS_nice = 34;
pub const SYS_ftime = 35;
pub const SYS_sync = 36;
pub const SYS_kill = 37;
pub const SYS_rename = 38;
pub const SYS_mkdir = 39;
pub const SYS_rmdir = 40;
pub const SYS_dup = 41;
pub const SYS_pipe = 42;
pub const SYS_times = 43;
pub const SYS_prof = 44;
pub const SYS_brk = 45;
pub const SYS_setgid = 46;
pub const SYS_getgid = 47;
pub const SYS_signal = 48;
pub const SYS_geteuid = 49;
pub const SYS_getegid = 50;
pub const SYS_acct = 51;
pub const SYS_umount2 = 52;
pub const SYS_lock = 53;
pub const SYS_ioctl = 54;
pub const SYS_fcntl = 55;
pub const SYS_mpx = 56;
pub const SYS_setpgid = 57;
pub const SYS_ulimit = 58;
pub const SYS_oldolduname = 59;
pub const SYS_umask = 60;
pub const SYS_chroot = 61;
pub const SYS_ustat = 62;
pub const SYS_dup2 = 63;
pub const SYS_getppid = 64;
pub const SYS_getpgrp = 65;
pub const SYS_setsid = 66;
pub const SYS_sigaction = 67;
pub const SYS_sgetmask = 68;
pub const SYS_ssetmask = 69;
pub const SYS_setreuid = 70;
pub const SYS_setregid = 71;
pub const SYS_sigsuspend = 72;
pub const SYS_sigpending = 73;
pub const SYS_sethostname = 74;
pub const SYS_setrlimit = 75;
pub const SYS_getrlimit = 76;
pub const SYS_getrusage = 77;
pub const SYS_gettimeofday = 78;
pub const SYS_settimeofday = 79;
pub const SYS_getgroups = 80;
pub const SYS_setgroups = 81;
pub const SYS_select = 82;
pub const SYS_symlink = 83;
pub const SYS_oldlstat = 84;
pub const SYS_readlink = 85;
pub const SYS_uselib = 86;
pub const SYS_swapon = 87;
pub const SYS_reboot = 88;
pub const SYS_readdir = 89;
pub const SYS_mmap = 90;
pub const SYS_munmap = 91;
pub const SYS_truncate = 92;
pub const SYS_ftruncate = 93;
pub const SYS_fchmod = 94;
pub const SYS_fchown = 95;
pub const SYS_getpriority = 96;
pub const SYS_setpriority = 97;
pub const SYS_profil = 98;
pub const SYS_statfs = 99;
pub const SYS_fstatfs = 100;
pub const SYS_ioperm = 101;
pub const SYS_socketcall = 102;
pub const SYS_syslog = 103;
pub const SYS_setitimer = 104;
pub const SYS_getitimer = 105;
pub const SYS_stat = 106;
pub const SYS_lstat = 107;
pub const SYS_fstat = 108;
pub const SYS_olduname = 109;
pub const SYS_iopl = 110;
pub const SYS_vhangup = 111;
pub const SYS_idle = 112;
pub const SYS_vm86old = 113;
pub const SYS_wait4 = 114;
pub const SYS_swapoff = 115;
pub const SYS_sysinfo = 116;
pub const SYS_ipc = 117;
pub const SYS_fsync = 118;
pub const SYS_sigreturn = 119;
pub const SYS_clone = 120;
pub const SYS_setdomainname = 121;
pub const SYS_uname = 122;
pub const SYS_modify_ldt = 123;
pub const SYS_adjtimex = 124;
pub const SYS_mprotect = 125;
pub const SYS_sigprocmask = 126;
pub const SYS_create_module = 127;
pub const SYS_init_module = 128;
pub const SYS_delete_module = 129;
pub const SYS_get_kernel_syms = 130;
pub const SYS_quotactl = 131;
pub const SYS_getpgid = 132;
pub const SYS_fchdir = 133;
pub const SYS_bdflush = 134;
pub const SYS_sysfs = 135;
pub const SYS_personality = 136;
pub const SYS_afs_syscall = 137;
pub const SYS_setfsuid = 138;
pub const SYS_setfsgid = 139;
pub const SYS__llseek = 140;
pub const SYS_getdents = 141;
pub const SYS__newselect = 142;
pub const SYS_flock = 143;
pub const SYS_msync = 144;
pub const SYS_readv = 145;
pub const SYS_writev = 146;
pub const SYS_getsid = 147;
pub const SYS_fdatasync = 148;
pub const SYS__sysctl = 149;
pub const SYS_mlock = 150;
pub const SYS_munlock = 151;
pub const SYS_mlockall = 152;
pub const SYS_munlockall = 153;
pub const SYS_sched_setparam = 154;
pub const SYS_sched_getparam = 155;
pub const SYS_sched_setscheduler = 156;
pub const SYS_sched_getscheduler = 157;
pub const SYS_sched_yield = 158;
pub const SYS_sched_get_priority_max = 159;
pub const SYS_sched_get_priority_min = 160;
pub const SYS_sched_rr_get_interval = 161;
pub const SYS_nanosleep = 162;
pub const SYS_mremap = 163;
pub const SYS_setresuid = 164;
pub const SYS_getresuid = 165;
pub const SYS_vm86 = 166;
pub const SYS_query_module = 167;
pub const SYS_poll = 168;
pub const SYS_nfsservctl = 169;
pub const SYS_setresgid = 170;
pub const SYS_getresgid = 171;
pub const SYS_prctl = 172;
pub const SYS_rt_sigreturn = 173;
pub const SYS_rt_sigaction = 174;
pub const SYS_rt_sigprocmask = 175;
pub const SYS_rt_sigpending = 176;
pub const SYS_rt_sigtimedwait = 177;
pub const SYS_rt_sigqueueinfo = 178;
pub const SYS_rt_sigsuspend = 179;
pub const SYS_pread64 = 180;
pub const SYS_pwrite64 = 181;
pub const SYS_chown = 182;
pub const SYS_getcwd = 183;
pub const SYS_capget = 184;
pub const SYS_capset = 185;
pub const SYS_sigaltstack = 186;
pub const SYS_sendfile = 187;
pub const SYS_getpmsg = 188;
pub const SYS_putpmsg = 189;
pub const SYS_vfork = 190;
pub const SYS_ugetrlimit = 191;
pub const SYS_mmap2 = 192;
pub const SYS_truncate64 = 193;
pub const SYS_ftruncate64 = 194;
pub const SYS_stat64 = 195;
pub const SYS_lstat64 = 196;
pub const SYS_fstat64 = 197;
pub const SYS_lchown32 = 198;
pub const SYS_getuid32 = 199;
pub const SYS_getgid32 = 200;
pub const SYS_geteuid32 = 201;
pub const SYS_getegid32 = 202;
pub const SYS_setreuid32 = 203;
pub const SYS_setregid32 = 204;
pub const SYS_getgroups32 = 205;
pub const SYS_setgroups32 = 206;
pub const SYS_fchown32 = 207;
pub const SYS_setresuid32 = 208;
pub const SYS_getresuid32 = 209;
pub const SYS_setresgid32 = 210;
pub const SYS_getresgid32 = 211;
pub const SYS_chown32 = 212;
pub const SYS_setuid32 = 213;
pub const SYS_setgid32 = 214;
pub const SYS_setfsuid32 = 215;
pub const SYS_setfsgid32 = 216;
pub const SYS_pivot_root = 217;
pub const SYS_mincore = 218;
pub const SYS_madvise = 219;
pub const SYS_getdents64 = 220;
pub const SYS_fcntl64 = 221;
pub const SYS_gettid = 224;
pub const SYS_readahead = 225;
pub const SYS_setxattr = 226;
pub const SYS_lsetxattr = 227;
pub const SYS_fsetxattr = 228;
pub const SYS_getxattr = 229;
pub const SYS_lgetxattr = 230;
pub const SYS_fgetxattr = 231;
pub const SYS_listxattr = 232;
pub const SYS_llistxattr = 233;
pub const SYS_flistxattr = 234;
pub const SYS_removexattr = 235;
pub const SYS_lremovexattr = 236;
pub const SYS_fremovexattr = 237;
pub const SYS_tkill = 238;
pub const SYS_sendfile64 = 239;
pub const SYS_futex = 240;
pub const SYS_sched_setaffinity = 241;
pub const SYS_sched_getaffinity = 242;
pub const SYS_set_thread_area = 243;
pub const SYS_get_thread_area = 244;
pub const SYS_io_setup = 245;
pub const SYS_io_destroy = 246;
pub const SYS_io_getevents = 247;
pub const SYS_io_submit = 248;
pub const SYS_io_cancel = 249;
pub const SYS_fadvise64 = 250;
pub const SYS_exit_group = 252;
pub const SYS_lookup_dcookie = 253;
pub const SYS_epoll_create = 254;
pub const SYS_epoll_ctl = 255;
pub const SYS_epoll_wait = 256;
pub const SYS_remap_file_pages = 257;
pub const SYS_set_tid_address = 258;
pub const SYS_timer_create = 259;
pub const SYS_timer_settime = SYS_timer_create + 1;
pub const SYS_timer_gettime = SYS_timer_create + 2;
pub const SYS_timer_getoverrun = SYS_timer_create + 3;
pub const SYS_timer_delete = SYS_timer_create + 4;
pub const SYS_clock_settime = SYS_timer_create + 5;
pub const SYS_clock_gettime = SYS_timer_create + 6;
pub const SYS_clock_getres = SYS_timer_create + 7;
pub const SYS_clock_nanosleep = SYS_timer_create + 8;
pub const SYS_statfs64 = 268;
pub const SYS_fstatfs64 = 269;
pub const SYS_tgkill = 270;
pub const SYS_utimes = 271;
pub const SYS_fadvise64_64 = 272;
pub const SYS_vserver = 273;
pub const SYS_mbind = 274;
pub const SYS_get_mempolicy = 275;
pub const SYS_set_mempolicy = 276;
pub const SYS_mq_open = 277;
pub const SYS_mq_unlink = SYS_mq_open + 1;
pub const SYS_mq_timedsend = SYS_mq_open + 2;
pub const SYS_mq_timedreceive = SYS_mq_open + 3;
pub const SYS_mq_notify = SYS_mq_open + 4;
pub const SYS_mq_getsetattr = SYS_mq_open + 5;
pub const SYS_kexec_load = 283;
pub const SYS_waitid = 284;
pub const SYS_add_key = 286;
pub const SYS_request_key = 287;
pub const SYS_keyctl = 288;
pub const SYS_ioprio_set = 289;
pub const SYS_ioprio_get = 290;
pub const SYS_inotify_init = 291;
pub const SYS_inotify_add_watch = 292;
pub const SYS_inotify_rm_watch = 293;
pub const SYS_migrate_pages = 294;
pub const SYS_openat = 295;
pub const SYS_mkdirat = 296;
pub const SYS_mknodat = 297;
pub const SYS_fchownat = 298;
pub const SYS_futimesat = 299;
pub const SYS_fstatat64 = 300;
pub const SYS_unlinkat = 301;
pub const SYS_renameat = 302;
pub const SYS_linkat = 303;
pub const SYS_symlinkat = 304;
pub const SYS_readlinkat = 305;
pub const SYS_fchmodat = 306;
pub const SYS_faccessat = 307;
pub const SYS_pselect6 = 308;
pub const SYS_ppoll = 309;
pub const SYS_unshare = 310;
pub const SYS_set_robust_list = 311;
pub const SYS_get_robust_list = 312;
pub const SYS_splice = 313;
pub const SYS_sync_file_range = 314;
pub const SYS_tee = 315;
pub const SYS_vmsplice = 316;
pub const SYS_move_pages = 317;
pub const SYS_getcpu = 318;
pub const SYS_epoll_pwait = 319;
pub const SYS_utimensat = 320;
pub const SYS_signalfd = 321;
pub const SYS_timerfd_create = 322;
pub const SYS_eventfd = 323;
pub const SYS_fallocate = 324;
pub const SYS_timerfd_settime = 325;
pub const SYS_timerfd_gettime = 326;
pub const SYS_signalfd4 = 327;
pub const SYS_eventfd2 = 328;
pub const SYS_epoll_create1 = 329;
pub const SYS_dup3 = 330;
pub const SYS_pipe2 = 331;
pub const SYS_inotify_init1 = 332;
pub const SYS_preadv = 333;
pub const SYS_pwritev = 334;
pub const SYS_rt_tgsigqueueinfo = 335;
pub const SYS_perf_event_open = 336;
pub const SYS_recvmmsg = 337;
pub const SYS_fanotify_init = 338;
pub const SYS_fanotify_mark = 339;
pub const SYS_prlimit64 = 340;
pub const SYS_name_to_handle_at = 341;
pub const SYS_open_by_handle_at = 342;
pub const SYS_clock_adjtime = 343;
pub const SYS_syncfs = 344;
pub const SYS_sendmmsg = 345;
pub const SYS_setns = 346;
pub const SYS_process_vm_readv = 347;
pub const SYS_process_vm_writev = 348;
pub const SYS_kcmp = 349;
pub const SYS_finit_module = 350;
pub const SYS_sched_setattr = 351;
pub const SYS_sched_getattr = 352;
pub const SYS_renameat2 = 353;
pub const SYS_seccomp = 354;
pub const SYS_getrandom = 355;
pub const SYS_memfd_create = 356;
pub const SYS_bpf = 357;
pub const SYS_execveat = 358;
pub const SYS_socket = 359;
pub const SYS_socketpair = 360;
pub const SYS_bind = 361;
pub const SYS_connect = 362;
pub const SYS_listen = 363;
pub const SYS_accept4 = 364;
pub const SYS_getsockopt = 365;
pub const SYS_setsockopt = 366;
pub const SYS_getsockname = 367;
pub const SYS_getpeername = 368;
pub const SYS_sendto = 369;
pub const SYS_sendmsg = 370;
pub const SYS_recvfrom = 371;
pub const SYS_recvmsg = 372;
pub const SYS_shutdown = 373;
pub const SYS_userfaultfd = 374;
pub const SYS_membarrier = 375;
pub const SYS_mlock2 = 376;
pub const SYS_copy_file_range = 377;
pub const SYS_preadv2 = 378;
pub const SYS_pwritev2 = 379;
pub const SYS_pkey_mprotect = 380;
pub const SYS_pkey_alloc = 381;
pub const SYS_pkey_free = 382;
pub const SYS_statx = 383;
pub const SYS_arch_prctl = 384;
pub const SYS_io_pgetevents = 385;
pub const SYS_rseq = 386;
pub const SYS_semget = 393;
pub const SYS_semctl = 394;
pub const SYS_shmget = 395;
pub const SYS_shmctl = 396;
pub const SYS_shmat = 397;
pub const SYS_shmdt = 398;
pub const SYS_msgget = 399;
pub const SYS_msgsnd = 400;
pub const SYS_msgrcv = 401;
pub const SYS_msgctl = 402;
pub const SYS_clock_gettime64 = 403;
pub const SYS_clock_settime64 = 404;
pub const SYS_clock_adjtime64 = 405;
pub const SYS_clock_getres_time64 = 406;
pub const SYS_clock_nanosleep_time64 = 407;
pub const SYS_timer_gettime64 = 408;
pub const SYS_timer_settime64 = 409;
pub const SYS_timerfd_gettime64 = 410;
pub const SYS_timerfd_settime64 = 411;
pub const SYS_utimensat_time64 = 412;
pub const SYS_pselect6_time64 = 413;
pub const SYS_ppoll_time64 = 414;
pub const SYS_io_pgetevents_time64 = 416;
pub const SYS_recvmmsg_time64 = 417;
pub const SYS_mq_timedsend_time64 = 418;
pub const SYS_mq_timedreceive_time64 = 419;
pub const SYS_semtimedop_time64 = 420;
pub const SYS_rt_sigtimedwait_time64 = 421;
pub const SYS_futex_time64 = 422;
pub const SYS_sched_rr_get_interval_time64 = 423;
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
