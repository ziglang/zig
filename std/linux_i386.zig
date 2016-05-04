const linux = @import("linux.zig");
const socklen_t = linux.socklen_t;
const iovec = linux.iovec;

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
pub const SYS_madvise1 = 219;
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
pub const SYS_timer_settime = SYS_timer_create+1;
pub const SYS_timer_gettime = SYS_timer_create+2;
pub const SYS_timer_getoverrun = SYS_timer_create+3;
pub const SYS_timer_delete = SYS_timer_create+4;
pub const SYS_clock_settime = SYS_timer_create+5;
pub const SYS_clock_gettime = SYS_timer_create+6;
pub const SYS_clock_getres = SYS_timer_create+7;
pub const SYS_clock_nanosleep = SYS_timer_create+8;
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
pub const SYS_mq_unlink = SYS_mq_open+1;
pub const SYS_mq_timedsend = SYS_mq_open+2;
pub const SYS_mq_timedreceive = SYS_mq_open+3;
pub const SYS_mq_notify = SYS_mq_open+4;
pub const SYS_mq_getsetattr = SYS_mq_open+5;
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


pub const O_CREAT        = 0o100;
pub const O_EXCL         = 0o200;
pub const O_NOCTTY       = 0o400;
pub const O_TRUNC       = 0o1000;
pub const O_APPEND      = 0o2000;
pub const O_NONBLOCK    = 0o4000;
pub const O_DSYNC      = 0o10000;
pub const O_SYNC     = 0o4010000;
pub const O_RSYNC    = 0o4010000;
pub const O_DIRECTORY = 0o200000;
pub const O_NOFOLLOW  = 0o400000;
pub const O_CLOEXEC  = 0o2000000;

pub const O_ASYNC      = 0o20000;
pub const O_DIRECT     = 0o40000;
pub const O_LARGEFILE = 0o100000;
pub const O_NOATIME  = 0o1000000;
pub const O_PATH    = 0o10000000;
pub const O_TMPFILE = 0o20200000;
pub const O_NDELAY =  O_NONBLOCK;

pub const F_DUPFD  = 0;
pub const F_GETFD  = 1;
pub const F_SETFD  = 2;
pub const F_GETFL  = 3;
pub const F_SETFL  = 4;

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

pub fn syscall0(number: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number))
}

pub fn syscall1(number: isize, arg1: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1))
}

pub fn syscall2(number: isize, arg1: isize, arg2: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1),
            [arg2] "{ecx}" (arg2))
}

pub fn syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1),
            [arg2] "{ecx}" (arg2),
            [arg3] "{edx}" (arg3))
}

pub fn syscall4(number: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize) -> isize {
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1),
            [arg2] "{ecx}" (arg2),
            [arg3] "{edx}" (arg3),
            [arg4] "{esi}" (arg4))
}

pub fn syscall5(number: isize, arg1: isize, arg2: isize, arg3: isize,
    arg4: isize, arg5: isize) -> isize
{
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1),
            [arg2] "{ecx}" (arg2),
            [arg3] "{edx}" (arg3),
            [arg4] "{esi}" (arg4),
            [arg5] "{edi}" (arg5))
}

pub fn syscall6(number: isize, arg1: isize, arg2: isize, arg3: isize,
    arg4: isize, arg5: isize, arg6: isize) -> isize
{
    asm volatile ("int $0x80"
        : [ret] "={eax}" (-> isize)
        : [number] "{eax}" (number),
            [arg1] "{ebx}" (arg1),
            [arg2] "{ecx}" (arg2),
            [arg3] "{edx}" (arg3),
            [arg4] "{esi}" (arg4),
            [arg5] "{edi}" (arg5),
            [arg6] "{ebp}" (arg6))
}

export struct msghdr {
    msg_name: &u8,
    msg_namelen: socklen_t,
    msg_iov: &iovec,
    msg_iovlen: i32,
    msg_control: &u8,
    msg_controllen: socklen_t,
    msg_flags: i32,
}
