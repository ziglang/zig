// arm64-specific declarations that are intended to be imported into the POSIX namespace.
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

pub const SYS_io_setup = 0;
pub const SYS_io_destroy = 1;
pub const SYS_io_submit = 2;
pub const SYS_io_cancel = 3;
pub const SYS_io_getevents = 4;
pub const SYS_setxattr = 5;
pub const SYS_lsetxattr = 6;
pub const SYS_fsetxattr = 7;
pub const SYS_getxattr = 8;
pub const SYS_lgetxattr = 9;
pub const SYS_fgetxattr = 10;
pub const SYS_listxattr = 11;
pub const SYS_llistxattr = 12;
pub const SYS_flistxattr = 13;
pub const SYS_removexattr = 14;
pub const SYS_lremovexattr = 15;
pub const SYS_fremovexattr = 16;
pub const SYS_getcwd = 17;
pub const SYS_lookup_dcookie = 18;
pub const SYS_eventfd2 = 19;
pub const SYS_epoll_create1 = 20;
pub const SYS_epoll_ctl = 21;
pub const SYS_epoll_pwait = 22;
pub const SYS_dup = 23;
pub const SYS_dup3 = 24;
pub const SYS_fcntl = 25;
pub const SYS_inotify_init1 = 26;
pub const SYS_inotify_add_watch = 27;
pub const SYS_inotify_rm_watch = 28;
pub const SYS_ioctl = 29;
pub const SYS_ioprio_set = 30;
pub const SYS_ioprio_get = 31;
pub const SYS_flock = 32;
pub const SYS_mknodat = 33;
pub const SYS_mkdirat = 34;
pub const SYS_unlinkat = 35;
pub const SYS_symlinkat = 36;
pub const SYS_linkat = 37;
pub const SYS_renameat = 38;
pub const SYS_umount2 = 39;
pub const SYS_mount = 40;
pub const SYS_pivot_root = 41;
pub const SYS_nfsservctl = 42;
pub const SYS_statfs = 43;
pub const SYS_fstatfs = 44;
pub const SYS_truncate = 45;
pub const SYS_ftruncate = 46;
pub const SYS_fallocate = 47;
pub const SYS_faccessat = 48;
pub const SYS_chdir = 49;
pub const SYS_fchdir = 50;
pub const SYS_chroot = 51;
pub const SYS_fchmod = 52;
pub const SYS_fchmodat = 53;
pub const SYS_fchownat = 54;
pub const SYS_fchown = 55;
pub const SYS_openat = 56;
pub const SYS_close = 57;
pub const SYS_vhangup = 58;
pub const SYS_pipe2 = 59;
pub const SYS_quotactl = 60;
pub const SYS_getdents64 = 61;
pub const SYS_lseek = 62;
pub const SYS_read = 63;
pub const SYS_write = 64;
pub const SYS_readv = 65;
pub const SYS_writev = 66;
pub const SYS_pread64 = 67;
pub const SYS_pwrite64 = 68;
pub const SYS_preadv = 69;
pub const SYS_pwritev = 70;
pub const SYS_sendfile = 71;
pub const SYS_pselect6 = 72;
pub const SYS_ppoll = 73;
pub const SYS_signalfd4 = 74;
pub const SYS_vmsplice = 75;
pub const SYS_splice = 76;
pub const SYS_tee = 77;
pub const SYS_readlinkat = 78;
pub const SYS_fstatat = 79;
pub const SYS_fstat = 80;
pub const SYS_sync = 81;
pub const SYS_fsync = 82;
pub const SYS_fdatasync = 83;
pub const SYS_sync_file_range2 = 84;
pub const SYS_sync_file_range = 84;
pub const SYS_timerfd_create = 85;
pub const SYS_timerfd_settime = 86;
pub const SYS_timerfd_gettime = 87;
pub const SYS_utimensat = 88;
pub const SYS_acct = 89;
pub const SYS_capget = 90;
pub const SYS_capset = 91;
pub const SYS_personality = 92;
pub const SYS_exit = 93;
pub const SYS_exit_group = 94;
pub const SYS_waitid = 95;
pub const SYS_set_tid_address = 96;
pub const SYS_unshare = 97;
pub const SYS_futex = 98;
pub const SYS_set_robust_list = 99;
pub const SYS_get_robust_list = 100;
pub const SYS_nanosleep = 101;
pub const SYS_getitimer = 102;
pub const SYS_setitimer = 103;
pub const SYS_kexec_load = 104;
pub const SYS_init_module = 105;
pub const SYS_delete_module = 106;
pub const SYS_timer_create = 107;
pub const SYS_timer_gettime = 108;
pub const SYS_timer_getoverrun = 109;
pub const SYS_timer_settime = 110;
pub const SYS_timer_delete = 111;
pub const SYS_clock_settime = 112;
pub const SYS_clock_gettime = 113;
pub const SYS_clock_getres = 114;
pub const SYS_clock_nanosleep = 115;
pub const SYS_syslog = 116;
pub const SYS_ptrace = 117;
pub const SYS_sched_setparam = 118;
pub const SYS_sched_setscheduler = 119;
pub const SYS_sched_getscheduler = 120;
pub const SYS_sched_getparam = 121;
pub const SYS_sched_setaffinity = 122;
pub const SYS_sched_getaffinity = 123;
pub const SYS_sched_yield = 124;
pub const SYS_sched_get_priority_max = 125;
pub const SYS_sched_get_priority_min = 126;
pub const SYS_sched_rr_get_interval = 127;
pub const SYS_restart_syscall = 128;
pub const SYS_kill = 129;
pub const SYS_tkill = 130;
pub const SYS_tgkill = 131;
pub const SYS_sigaltstack = 132;
pub const SYS_rt_sigsuspend = 133;
pub const SYS_rt_sigaction = 134;
pub const SYS_rt_sigprocmask = 135;
pub const SYS_rt_sigpending = 136;
pub const SYS_rt_sigtimedwait = 137;
pub const SYS_rt_sigqueueinfo = 138;
pub const SYS_rt_sigreturn = 139;
pub const SYS_setpriority = 140;
pub const SYS_getpriority = 141;
pub const SYS_reboot = 142;
pub const SYS_setregid = 143;
pub const SYS_setgid = 144;
pub const SYS_setreuid = 145;
pub const SYS_setuid = 146;
pub const SYS_setresuid = 147;
pub const SYS_getresuid = 148;
pub const SYS_setresgid = 149;
pub const SYS_getresgid = 150;
pub const SYS_setfsuid = 151;
pub const SYS_setfsgid = 152;
pub const SYS_times = 153;
pub const SYS_setpgid = 154;
pub const SYS_getpgid = 155;
pub const SYS_getsid = 156;
pub const SYS_setsid = 157;
pub const SYS_getgroups = 158;
pub const SYS_setgroups = 159;
pub const SYS_uname = 160;
pub const SYS_sethostname = 161;
pub const SYS_setdomainname = 162;
pub const SYS_getrlimit = 163;
pub const SYS_setrlimit = 164;
pub const SYS_getrusage = 165;
pub const SYS_umask = 166;
pub const SYS_prctl = 167;
pub const SYS_getcpu = 168;
pub const SYS_gettimeofday = 169;
pub const SYS_settimeofday = 170;
pub const SYS_adjtimex = 171;
pub const SYS_getpid = 172;
pub const SYS_getppid = 173;
pub const SYS_getuid = 174;
pub const SYS_geteuid = 175;
pub const SYS_getgid = 176;
pub const SYS_getegid = 177;
pub const SYS_gettid = 178;
pub const SYS_sysinfo = 179;
pub const SYS_mq_open = 180;
pub const SYS_mq_unlink = 181;
pub const SYS_mq_timedsend = 182;
pub const SYS_mq_timedreceive = 183;
pub const SYS_mq_notify = 184;
pub const SYS_mq_getsetattr = 185;
pub const SYS_msgget = 186;
pub const SYS_msgctl = 187;
pub const SYS_msgrcv = 188;
pub const SYS_msgsnd = 189;
pub const SYS_semget = 190;
pub const SYS_semctl = 191;
pub const SYS_semtimedop = 192;
pub const SYS_semop = 193;
pub const SYS_shmget = 194;
pub const SYS_shmctl = 195;
pub const SYS_shmat = 196;
pub const SYS_shmdt = 197;
pub const SYS_socket = 198;
pub const SYS_socketpair = 199;
pub const SYS_bind = 200;
pub const SYS_listen = 201;
pub const SYS_accept = 202;
pub const SYS_connect = 203;
pub const SYS_getsockname = 204;
pub const SYS_getpeername = 205;
pub const SYS_sendto = 206;
pub const SYS_recvfrom = 207;
pub const SYS_setsockopt = 208;
pub const SYS_getsockopt = 209;
pub const SYS_shutdown = 210;
pub const SYS_sendmsg = 211;
pub const SYS_recvmsg = 212;
pub const SYS_readahead = 213;
pub const SYS_brk = 214;
pub const SYS_munmap = 215;
pub const SYS_mremap = 216;
pub const SYS_add_key = 217;
pub const SYS_request_key = 218;
pub const SYS_keyctl = 219;
pub const SYS_clone = 220;
pub const SYS_execve = 221;
pub const SYS_mmap = 222;
pub const SYS_fadvise64 = 223;
pub const SYS_swapon = 224;
pub const SYS_swapoff = 225;
pub const SYS_mprotect = 226;
pub const SYS_msync = 227;
pub const SYS_mlock = 228;
pub const SYS_munlock = 229;
pub const SYS_mlockall = 230;
pub const SYS_munlockall = 231;
pub const SYS_mincore = 232;
pub const SYS_madvise = 233;
pub const SYS_remap_file_pages = 234;
pub const SYS_mbind = 235;
pub const SYS_get_mempolicy = 236;
pub const SYS_set_mempolicy = 237;
pub const SYS_migrate_pages = 238;
pub const SYS_move_pages = 239;
pub const SYS_rt_tgsigqueueinfo = 240;
pub const SYS_perf_event_open = 241;
pub const SYS_accept4 = 242;
pub const SYS_recvmmsg = 243;
pub const SYS_arch_specific_syscall = 244;
pub const SYS_wait4 = 260;
pub const SYS_prlimit64 = 261;
pub const SYS_fanotify_init = 262;
pub const SYS_fanotify_mark = 263;
pub const SYS_clock_adjtime = 266;
pub const SYS_syncfs = 267;
pub const SYS_setns = 268;
pub const SYS_sendmmsg = 269;
pub const SYS_process_vm_readv = 270;
pub const SYS_process_vm_writev = 271;
pub const SYS_kcmp = 272;
pub const SYS_finit_module = 273;
pub const SYS_sched_setattr = 274;
pub const SYS_sched_getattr = 275;
pub const SYS_renameat2 = 276;
pub const SYS_seccomp = 277;
pub const SYS_getrandom = 278;
pub const SYS_memfd_create = 279;
pub const SYS_bpf = 280;
pub const SYS_execveat = 281;
pub const SYS_userfaultfd = 282;
pub const SYS_membarrier = 283;
pub const SYS_mlock2 = 284;
pub const SYS_copy_file_range = 285;
pub const SYS_preadv2 = 286;
pub const SYS_pwritev2 = 287;
pub const SYS_pkey_mprotect = 288;
pub const SYS_pkey_alloc = 289;
pub const SYS_pkey_free = 290;
pub const SYS_statx = 291;
pub const SYS_io_pgetevents = 292;
pub const SYS_rseq = 293;
pub const SYS_kexec_file_load = 294;
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

pub const F_GETLK = 5;
pub const F_SETLK = 6;
pub const F_SETLKW = 7;

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

pub const VDSO_CGT_SYM = "__kernel_clock_gettime";
pub const VDSO_CGT_VER = "LINUX_2.6.39";

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

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = isize;
pub const mode_t = u32;
pub const off_t = isize;
pub const ino_t = usize;
pub const dev_t = usize;
pub const blkcnt_t = isize;

/// Renamed to Stat to not conflict with the stat function.
/// atime, mtime, and ctime have functions to return `timespec`,
/// because although this is a POSIX API, the layout and names of
/// the structs are inconsistent across operating systems, and
/// in C, macros are used to hide the differences. Here we use
/// methods to accomplish this.
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

pub const mcontext_t = extern struct {
    fault_address: usize,
    regs: [31]usize,
    sp: usize,
    pc: usize,
    pstate: usize,
    // Make sure the field is correctly aligned since this area
    // holds various FP/vector registers
    reserved1: [256 * 16]u8 align(16),
};

pub const ucontext_t = extern struct {
    flags: usize,
    link: *ucontext_t,
    stack: stack_t,
    sigmask: sigset_t,
    mcontext: mcontext_t,
};

pub const Elf_Symndx = u32;
