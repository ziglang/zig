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

pub const SYS_restart_syscall = 0;
pub const SYS_exit = 1;
pub const SYS_fork = 2;
pub const SYS_read = 3;
pub const SYS_write = 4;
pub const SYS_open = 5;
pub const SYS_close = 6;
pub const SYS_creat = 8;
pub const SYS_link = 9;
pub const SYS_unlink = 10;
pub const SYS_execve = 11;
pub const SYS_chdir = 12;
pub const SYS_mknod = 14;
pub const SYS_chmod = 15;
pub const SYS_lchown = 16;
pub const SYS_lseek = 19;
pub const SYS_getpid = 20;
pub const SYS_mount = 21;
pub const SYS_setuid = 23;
pub const SYS_getuid = 24;
pub const SYS_ptrace = 26;
pub const SYS_pause = 29;
pub const SYS_access = 33;
pub const SYS_nice = 34;
pub const SYS_sync = 36;
pub const SYS_kill = 37;
pub const SYS_rename = 38;
pub const SYS_mkdir = 39;
pub const SYS_rmdir = 40;
pub const SYS_dup = 41;
pub const SYS_pipe = 42;
pub const SYS_times = 43;
pub const SYS_brk = 45;
pub const SYS_setgid = 46;
pub const SYS_getgid = 47;
pub const SYS_geteuid = 49;
pub const SYS_getegid = 50;
pub const SYS_acct = 51;
pub const SYS_umount2 = 52;
pub const SYS_ioctl = 54;
pub const SYS_fcntl = 55;
pub const SYS_setpgid = 57;
pub const SYS_umask = 60;
pub const SYS_chroot = 61;
pub const SYS_ustat = 62;
pub const SYS_dup2 = 63;
pub const SYS_getppid = 64;
pub const SYS_getpgrp = 65;
pub const SYS_setsid = 66;
pub const SYS_sigaction = 67;
pub const SYS_setreuid = 70;
pub const SYS_setregid = 71;
pub const SYS_sigsuspend = 72;
pub const SYS_sigpending = 73;
pub const SYS_sethostname = 74;
pub const SYS_setrlimit = 75;
pub const SYS_getrusage = 77;
pub const SYS_gettimeofday = 78;
pub const SYS_settimeofday = 79;
pub const SYS_getgroups = 80;
pub const SYS_setgroups = 81;
pub const SYS_symlink = 83;
pub const SYS_readlink = 85;
pub const SYS_uselib = 86;
pub const SYS_swapon = 87;
pub const SYS_reboot = 88;
pub const SYS_munmap = 91;
pub const SYS_truncate = 92;
pub const SYS_ftruncate = 93;
pub const SYS_fchmod = 94;
pub const SYS_fchown = 95;
pub const SYS_getpriority = 96;
pub const SYS_setpriority = 97;
pub const SYS_statfs = 99;
pub const SYS_fstatfs = 100;
pub const SYS_syslog = 103;
pub const SYS_setitimer = 104;
pub const SYS_getitimer = 105;
pub const SYS_stat = 106;
pub const SYS_lstat = 107;
pub const SYS_fstat = 108;
pub const SYS_vhangup = 111;
pub const SYS_wait4 = 114;
pub const SYS_swapoff = 115;
pub const SYS_sysinfo = 116;
pub const SYS_fsync = 118;
pub const SYS_sigreturn = 119;
pub const SYS_clone = 120;
pub const SYS_setdomainname = 121;
pub const SYS_uname = 122;
pub const SYS_adjtimex = 124;
pub const SYS_mprotect = 125;
pub const SYS_sigprocmask = 126;
pub const SYS_init_module = 128;
pub const SYS_delete_module = 129;
pub const SYS_quotactl = 131;
pub const SYS_getpgid = 132;
pub const SYS_fchdir = 133;
pub const SYS_bdflush = 134;
pub const SYS_sysfs = 135;
pub const SYS_personality = 136;
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
pub const SYS_getdents64 = 217;
pub const SYS_pivot_root = 218;
pub const SYS_mincore = 219;
pub const SYS_madvise = 220;
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
pub const SYS_io_setup = 243;
pub const SYS_io_destroy = 244;
pub const SYS_io_getevents = 245;
pub const SYS_io_submit = 246;
pub const SYS_io_cancel = 247;
pub const SYS_exit_group = 248;
pub const SYS_lookup_dcookie = 249;
pub const SYS_epoll_create = 250;
pub const SYS_epoll_ctl = 251;
pub const SYS_epoll_wait = 252;
pub const SYS_remap_file_pages = 253;
pub const SYS_set_tid_address = 256;
pub const SYS_timer_create = 257;
pub const SYS_timer_settime = 258;
pub const SYS_timer_gettime = 259;
pub const SYS_timer_getoverrun = 260;
pub const SYS_timer_delete = 261;
pub const SYS_clock_settime = 262;
pub const SYS_clock_gettime = 263;
pub const SYS_clock_getres = 264;
pub const SYS_clock_nanosleep = 265;
pub const SYS_statfs64 = 266;
pub const SYS_fstatfs64 = 267;
pub const SYS_tgkill = 268;
pub const SYS_utimes = 269;
pub const SYS_fadvise64_64 = 270;
pub const SYS_arm_fadvise64_64 = 270;
pub const SYS_pciconfig_iobase = 271;
pub const SYS_pciconfig_read = 272;
pub const SYS_pciconfig_write = 273;
pub const SYS_mq_open = 274;
pub const SYS_mq_unlink = 275;
pub const SYS_mq_timedsend = 276;
pub const SYS_mq_timedreceive = 277;
pub const SYS_mq_notify = 278;
pub const SYS_mq_getsetattr = 279;
pub const SYS_waitid = 280;
pub const SYS_socket = 281;
pub const SYS_bind = 282;
pub const SYS_connect = 283;
pub const SYS_listen = 284;
pub const SYS_accept = 285;
pub const SYS_getsockname = 286;
pub const SYS_getpeername = 287;
pub const SYS_socketpair = 288;
pub const SYS_send = 289;
pub const SYS_sendto = 290;
pub const SYS_recv = 291;
pub const SYS_recvfrom = 292;
pub const SYS_shutdown = 293;
pub const SYS_setsockopt = 294;
pub const SYS_getsockopt = 295;
pub const SYS_sendmsg = 296;
pub const SYS_recvmsg = 297;
pub const SYS_semop = 298;
pub const SYS_semget = 299;
pub const SYS_semctl = 300;
pub const SYS_msgsnd = 301;
pub const SYS_msgrcv = 302;
pub const SYS_msgget = 303;
pub const SYS_msgctl = 304;
pub const SYS_shmat = 305;
pub const SYS_shmdt = 306;
pub const SYS_shmget = 307;
pub const SYS_shmctl = 308;
pub const SYS_add_key = 309;
pub const SYS_request_key = 310;
pub const SYS_keyctl = 311;
pub const SYS_semtimedop = 312;
pub const SYS_vserver = 313;
pub const SYS_ioprio_set = 314;
pub const SYS_ioprio_get = 315;
pub const SYS_inotify_init = 316;
pub const SYS_inotify_add_watch = 317;
pub const SYS_inotify_rm_watch = 318;
pub const SYS_mbind = 319;
pub const SYS_get_mempolicy = 320;
pub const SYS_set_mempolicy = 321;
pub const SYS_openat = 322;
pub const SYS_mkdirat = 323;
pub const SYS_mknodat = 324;
pub const SYS_fchownat = 325;
pub const SYS_futimesat = 326;
pub const SYS_fstatat64 = 327;
pub const SYS_unlinkat = 328;
pub const SYS_renameat = 329;
pub const SYS_linkat = 330;
pub const SYS_symlinkat = 331;
pub const SYS_readlinkat = 332;
pub const SYS_fchmodat = 333;
pub const SYS_faccessat = 334;
pub const SYS_pselect6 = 335;
pub const SYS_ppoll = 336;
pub const SYS_unshare = 337;
pub const SYS_set_robust_list = 338;
pub const SYS_get_robust_list = 339;
pub const SYS_splice = 340;
pub const SYS_sync_file_range2 = 341;
pub const SYS_arm_sync_file_range = 341;
pub const SYS_tee = 342;
pub const SYS_vmsplice = 343;
pub const SYS_move_pages = 344;
pub const SYS_getcpu = 345;
pub const SYS_epoll_pwait = 346;
pub const SYS_kexec_load = 347;
pub const SYS_utimensat = 348;
pub const SYS_signalfd = 349;
pub const SYS_timerfd_create = 350;
pub const SYS_eventfd = 351;
pub const SYS_fallocate = 352;
pub const SYS_timerfd_settime = 353;
pub const SYS_timerfd_gettime = 354;
pub const SYS_signalfd4 = 355;
pub const SYS_eventfd2 = 356;
pub const SYS_epoll_create1 = 357;
pub const SYS_dup3 = 358;
pub const SYS_pipe2 = 359;
pub const SYS_inotify_init1 = 360;
pub const SYS_preadv = 361;
pub const SYS_pwritev = 362;
pub const SYS_rt_tgsigqueueinfo = 363;
pub const SYS_perf_event_open = 364;
pub const SYS_recvmmsg = 365;
pub const SYS_accept4 = 366;
pub const SYS_fanotify_init = 367;
pub const SYS_fanotify_mark = 368;
pub const SYS_prlimit64 = 369;
pub const SYS_name_to_handle_at = 370;
pub const SYS_open_by_handle_at = 371;
pub const SYS_clock_adjtime = 372;
pub const SYS_syncfs = 373;
pub const SYS_sendmmsg = 374;
pub const SYS_setns = 375;
pub const SYS_process_vm_readv = 376;
pub const SYS_process_vm_writev = 377;
pub const SYS_kcmp = 378;
pub const SYS_finit_module = 379;
pub const SYS_sched_setattr = 380;
pub const SYS_sched_getattr = 381;
pub const SYS_renameat2 = 382;
pub const SYS_seccomp = 383;
pub const SYS_getrandom = 384;
pub const SYS_memfd_create = 385;
pub const SYS_bpf = 386;
pub const SYS_execveat = 387;
pub const SYS_userfaultfd = 388;
pub const SYS_membarrier = 389;
pub const SYS_mlock2 = 390;
pub const SYS_copy_file_range = 391;
pub const SYS_preadv2 = 392;
pub const SYS_pwritev2 = 393;
pub const SYS_pkey_mprotect = 394;
pub const SYS_pkey_alloc = 395;
pub const SYS_pkey_free = 396;
pub const SYS_statx = 397;
pub const SYS_rseq = 398;
pub const SYS_io_pgetevents = 399;
pub const SYS_migrate_pages = 400;
pub const SYS_kexec_file_load = 401;
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
pub const SYS_pidfd_open = 434;
pub const SYS_clone3 = 435;

pub const SYS_breakpoint = 0x0f0001;
pub const SYS_cacheflush = 0x0f0002;
pub const SYS_usr26 = 0x0f0003;
pub const SYS_usr32 = 0x0f0004;
pub const SYS_set_tls = 0x0f0005;
pub const SYS_get_tls = 0x0f0006;

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
pub const MAP_LOCKED = 0x2000;

/// don't check for reservations
pub const MAP_NORESERVE = 0x4000;

pub const VDSO_USEFUL = true;
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
