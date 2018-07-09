const freebsd = @import("index.zig");
const socklen_t = freebsd.socklen_t;
const iovec = freebsd.iovec;

pub const SYS_syscall = 0;
pub const SYS_exit = 1;
pub const SYS_fork = 2;
pub const SYS_read = 3;
pub const SYS_write = 4;
pub const SYS_open = 5;
pub const SYS_close = 6;
pub const SYS_wait4 = 7;
// 8 is old creat
pub const SYS_link = 9;
pub const SYS_unlink = 10;
// 11 is obsolete execv
pub const SYS_chdir = 12;
pub const SYS_fchdir = 13;
pub const SYS_freebsd11_mknod = 14;
pub const SYS_chmod = 15;
pub const SYS_chown = 16;
pub const SYS_break = 17;
// 18 is freebsd4 getfsstat
// 19 is old lseek
pub const SYS_getpid = 20;
pub const SYS_mount = 21;
pub const SYS_unmount = 22;
pub const SYS_setuid = 23;
pub const SYS_getuid = 24;
pub const SYS_geteuid = 25;
pub const SYS_ptrace = 26;
pub const SYS_recvmsg = 27;
pub const SYS_sendmsg = 28;
pub const SYS_recvfrom = 29;
pub const SYS_accept = 30;
pub const SYS_getpeername = 31;
pub const SYS_getsockname = 32;
pub const SYS_access = 33;
pub const SYS_chflags = 34;
pub const SYS_fchflags = 35;
pub const SYS_sync = 36;
pub const SYS_kill = 37;
// 38 is old stat
pub const SYS_getppid = 39;
// 40 is old lstat
pub const SYS_dup = 41;
pub const SYS_freebsd10_pipe = 42;
pub const SYS_getegid = 43;
pub const SYS_profil = 44;
pub const SYS_ktrace = 45;
// 46 is old sigaction
pub const SYS_getgid = 47;
// 48 is old sigprocmask
pub const SYS_getlogin = 49;
pub const SYS_setlogin = 50;
pub const SYS_acct = 51;
// 52 is old sigpending
pub const SYS_sigaltstack = 53;
pub const SYS_ioctl = 54;
pub const SYS_reboot = 55;
pub const SYS_revoke = 56;
pub const SYS_symlink = 57;
pub const SYS_readlink = 58;
pub const SYS_execve = 59;
pub const SYS_umask = 60;
pub const SYS_chroot = 61;
// 62 is old fstat
// 63 is old getkerninfo
// 64 is old getpagesize
pub const SYS_msync = 65;
pub const SYS_vfork = 66;
// 67 is obsolete vread
// 68 is obsolete vwrite
pub const SYS_sbrk = 69;
pub const SYS_sstk = 70;
// 71 is old mmap
pub const SYS_vadvise = 72;
pub const SYS_munmap = 73;
pub const SYS_mprotect = 74;
pub const SYS_madvise = 75;
// 76 is obsolete vhangup
// 77 is obsolete vlimit
pub const SYS_mincore = 78;
pub const SYS_getgroups = 79;
pub const SYS_setgroups = 80;
pub const SYS_getpgrp = 81;
pub const SYS_setpgid = 82;
pub const SYS_setitimer = 83;
// 84 is old wait
pub const SYS_swapon = 85;
pub const SYS_getitimer = 86;
// 87 is old gethostname
// 88 is old sethostname
pub const SYS_getdtablesize = 89;
pub const SYS_dup2 = 90;
pub const SYS_fcntl = 92;
pub const SYS_select = 93;
pub const SYS_fsync = 95;
pub const SYS_setpriority = 96;
pub const SYS_socket = 97;
pub const SYS_connect = 98;
// 99 is old accept
pub const SYS_getpriority = 100;
// 101 is old send
// 102 is old recv
// 103 is old sigreturn
pub const SYS_bind = 104;
pub const SYS_setsockopt = 105;
pub const SYS_listen = 106;
// 107 is obsolete vtimes
// 108 is old sigvec
// 109 is old sigblock
// 110 is old sigsetmask
// 111 is old sigsuspend
// 112 is old sigstack
// 113 is old recvmsg
// 114 is old sendmsg
// 115 is obsolete vtrace
pub const SYS_gettimeofday = 116;
pub const SYS_getrusage = 117;
pub const SYS_getsockopt = 118;
pub const SYS_readv = 120;
pub const SYS_writev = 121;
pub const SYS_settimeofday = 122;
pub const SYS_fchown = 123;
pub const SYS_fchmod = 124;
// 125 is old recvfrom
pub const SYS_setreuid = 126;
pub const SYS_setregid = 127;
pub const SYS_rename = 128;
// 129 is old truncate
// 130 is old ftruncate
pub const SYS_flock = 131;
pub const SYS_mkfifo = 132;
pub const SYS_sendto = 133;
pub const SYS_shutdown = 134;
pub const SYS_socketpair = 135;
pub const SYS_mkdir = 136;
pub const SYS_rmdir = 137;
pub const SYS_utimes = 138;
// 139 is obsolete 4.2 sigreturn
pub const SYS_adjtime = 140;
// 141 is old getpeername
// 142 is old gethostid
// 143 is old sethostid
// 144 is old getrlimit
// 145 is old setrlimit
// 146 is old killpg
pub const SYS_setsid = 147;
pub const SYS_quotactl = 148;
// 149 is old quota
// 150 is old getsockname
pub const SYS_nlm_syscall = 154;
pub const SYS_nfssvc = 155;
// 156 is old getdirentries
// 157 is freebsd4 statfs
// 158 is freebsd4 fstatfs
pub const SYS_lgetfh = 160;
pub const SYS_getfh = 161;
// 162 is freebsd4 getdomainname
// 163 is freebsd4 setdomainname
// 164 is freebsd4 uname
pub const SYS_sysarch = 165;
pub const SYS_rtprio = 166;
pub const SYS_semsys = 169;
pub const SYS_msgsys = 170;
pub const SYS_shmsys = 171;
// 173 is freebsd6 pread
// 174 is freebsd6 pwrite
pub const SYS_setfib = 175;
pub const SYS_ntp_adjtime = 176;
pub const SYS_setgid = 181;
pub const SYS_setegid = 182;
pub const SYS_seteuid = 183;
pub const SYS_freebsd11_stat = 188;
pub const SYS_freebsd11_fstat = 189;
pub const SYS_freebsd11_lstat = 190;
pub const SYS_pathconf = 191;
pub const SYS_fpathconf = 192;
pub const SYS_getrlimit = 194;
pub const SYS_setrlimit = 195;
pub const SYS_freebsd11_getdirentries = 196;
// 197 is freebsd6 mmap
pub const SYS___syscall = 198;
// 199 is freebsd6 lseek
// 200 is freebsd6 truncate
// 201 is freebsd6 ftruncate
pub const SYS___sysctl = 202;
pub const SYS_mlock = 203;
pub const SYS_munlock = 204;
pub const SYS_undelete = 205;
pub const SYS_futimes = 206;
pub const SYS_getpgid = 207;
pub const SYS_poll = 209;
pub const SYS_freebsd7___semctl = 220;
pub const SYS_semget = 221;
pub const SYS_semop = 222;
pub const SYS_freebsd7_msgctl = 224;
pub const SYS_msgget = 225;
pub const SYS_msgsnd = 226;
pub const SYS_msgrcv = 227;
pub const SYS_shmat = 228;
pub const SYS_freebsd7_shmctl = 229;
pub const SYS_shmdt = 230;
pub const SYS_shmget = 231;
pub const SYS_clock_gettime = 232;
pub const SYS_clock_settime = 233;
pub const SYS_clock_getres = 234;
pub const SYS_ktimer_create = 235;
pub const SYS_ktimer_delete = 236;
pub const SYS_ktimer_settime = 237;
pub const SYS_ktimer_gettime = 238;
pub const SYS_ktimer_getoverrun = 239;
pub const SYS_nanosleep = 240;
pub const SYS_ffclock_getcounter = 241;
pub const SYS_ffclock_setestimate = 242;
pub const SYS_ffclock_getestimate = 243;
pub const SYS_clock_nanosleep = 244;
pub const SYS_clock_getcpuclockid2 = 247;
pub const SYS_ntp_gettime = 248;
pub const SYS_minherit = 250;
pub const SYS_rfork = 251;
// 252 is obsolete openbsd_poll
pub const SYS_issetugid = 253;
pub const SYS_lchown = 254;
pub const SYS_aio_read = 255;
pub const SYS_aio_write = 256;
pub const SYS_lio_listio = 257;
pub const SYS_freebsd11_getdents = 272;
pub const SYS_lchmod = 274;
pub const SYS_netbsd_lchown = 275;
pub const SYS_lutimes = 276;
pub const SYS_netbsd_msync = 277;
pub const SYS_freebsd11_nstat = 278;
pub const SYS_freebsd11_nfstat = 279;
pub const SYS_freebsd11_nlstat = 280;
pub const SYS_preadv = 289;
pub const SYS_pwritev = 290;
// 297 is freebsd4 fhstatfs
pub const SYS_fhopen = 298;
pub const SYS_freebsd11_fhstat = 299;
pub const SYS_modnext = 300;
pub const SYS_modstat = 301;
pub const SYS_modfnext = 302;
pub const SYS_modfind = 303;
pub const SYS_kldload = 304;
pub const SYS_kldunload = 305;
pub const SYS_kldfind = 306;
pub const SYS_kldnext = 307;
pub const SYS_kldstat = 308;
pub const SYS_kldfirstmod = 309;
pub const SYS_getsid = 310;
pub const SYS_setresuid = 311;
pub const SYS_setresgid = 312;
// 313 is obsolete signanosleep
pub const SYS_aio_return = 314;
pub const SYS_aio_suspend = 315;
pub const SYS_aio_cancel = 316;
pub const SYS_aio_error = 317;
// 318 is freebsd6 aio_read
// 319 is freebsd6 aio_write
// 320 is freebsd6 lio_listio
pub const SYS_yield = 321;
// 322 is obsolete thr_sleep
// 323 is obsolete thr_wakeup
pub const SYS_mlockall = 324;
pub const SYS_munlockall = 325;
pub const SYS___getcwd = 326;
pub const SYS_sched_setparam = 327;
pub const SYS_sched_getparam = 328;
pub const SYS_sched_setscheduler = 329;
pub const SYS_sched_getscheduler = 330;
pub const SYS_sched_yield = 331;
pub const SYS_sched_get_priority_max = 332;
pub const SYS_sched_get_priority_min = 333;
pub const SYS_sched_rr_get_interval = 334;
pub const SYS_utrace = 335;
// 336 is freebsd4 sendfile
pub const SYS_kldsym = 337;
pub const SYS_jail = 338;
pub const SYS_nnpfs_syscall = 339;
pub const SYS_sigprocmask = 340;
pub const SYS_sigsuspend = 341;
// 342 is freebsd4 sigaction
pub const SYS_sigpending = 343;
// 344 is freebsd4 sigreturn
pub const SYS_sigtimedwait = 345;
pub const SYS_sigwaitinfo = 346;
pub const SYS___acl_get_file = 347;
pub const SYS___acl_set_file = 348;
pub const SYS___acl_get_fd = 349;
pub const SYS___acl_set_fd = 350;
pub const SYS___acl_delete_file = 351;
pub const SYS___acl_delete_fd = 352;
pub const SYS___acl_aclcheck_file = 353;
pub const SYS___acl_aclcheck_fd = 354;
pub const SYS_extattrctl = 355;
pub const SYS_extattr_set_file = 356;
pub const SYS_extattr_get_file = 357;
pub const SYS_extattr_delete_file = 358;
pub const SYS_aio_waitcomplete = 359;
pub const SYS_getresuid = 360;
pub const SYS_getresgid = 361;
pub const SYS_kqueue = 362;
pub const SYS_freebsd11_kevent = 363;
pub const SYS_extattr_set_fd = 371;
pub const SYS_extattr_get_fd = 372;
pub const SYS_extattr_delete_fd = 373;
pub const SYS___setugid = 374;
pub const SYS_eaccess = 376;
pub const SYS_afs3_syscall = 377;
pub const SYS_nmount = 378;
pub const SYS___mac_get_proc = 384;
pub const SYS___mac_set_proc = 385;
pub const SYS___mac_get_fd = 386;
pub const SYS___mac_get_file = 387;
pub const SYS___mac_set_fd = 388;
pub const SYS___mac_set_file = 389;
pub const SYS_kenv = 390;
pub const SYS_lchflags = 391;
pub const SYS_uuidgen = 392;
pub const SYS_sendfile = 393;
pub const SYS_mac_syscall = 394;
pub const SYS_freebsd11_getfsstat = 395;
pub const SYS_freebsd11_statfs = 396;
pub const SYS_freebsd11_fstatfs = 397;
pub const SYS_freebsd11_fhstatfs = 398;
pub const SYS_ksem_close = 400;
pub const SYS_ksem_post = 401;
pub const SYS_ksem_wait = 402;
pub const SYS_ksem_trywait = 403;
pub const SYS_ksem_init = 404;
pub const SYS_ksem_open = 405;
pub const SYS_ksem_unlink = 406;
pub const SYS_ksem_getvalue = 407;
pub const SYS_ksem_destroy = 408;
pub const SYS___mac_get_pid = 409;
pub const SYS___mac_get_link = 410;
pub const SYS___mac_set_link = 411;
pub const SYS_extattr_set_link = 412;
pub const SYS_extattr_get_link = 413;
pub const SYS_extattr_delete_link = 414;
pub const SYS___mac_execve = 415;
pub const SYS_sigaction = 416;
pub const SYS_sigreturn = 417;
pub const SYS_getcontext = 421;
pub const SYS_setcontext = 422;
pub const SYS_swapcontext = 423;
pub const SYS_swapoff = 424;
pub const SYS___acl_get_link = 425;
pub const SYS___acl_set_link = 426;
pub const SYS___acl_delete_link = 427;
pub const SYS___acl_aclcheck_link = 428;
pub const SYS_sigwait = 429;
pub const SYS_thr_create = 430;
pub const SYS_thr_exit = 431;
pub const SYS_thr_self = 432;
pub const SYS_thr_kill = 433;
pub const SYS_jail_attach = 436;
pub const SYS_extattr_list_fd = 437;
pub const SYS_extattr_list_file = 438;
pub const SYS_extattr_list_link = 439;
pub const SYS_ksem_timedwait = 441;
pub const SYS_thr_suspend = 442;
pub const SYS_thr_wake = 443;
pub const SYS_kldunloadf = 444;
pub const SYS_audit = 445;
pub const SYS_auditon = 446;
pub const SYS_getauid = 447;
pub const SYS_setauid = 448;
pub const SYS_getaudit = 449;
pub const SYS_setaudit = 450;
pub const SYS_getaudit_addr = 451;
pub const SYS_setaudit_addr = 452;
pub const SYS_auditctl = 453;
pub const SYS__umtx_op = 454;
pub const SYS_thr_new = 455;
pub const SYS_sigqueue = 456;
pub const SYS_kmq_open = 457;
pub const SYS_kmq_setattr = 458;
pub const SYS_kmq_timedreceive = 459;
pub const SYS_kmq_timedsend = 460;
pub const SYS_kmq_notify = 461;
pub const SYS_kmq_unlink = 462;
pub const SYS_abort2 = 463;
pub const SYS_thr_set_name = 464;
pub const SYS_aio_fsync = 465;
pub const SYS_rtprio_thread = 466;
pub const SYS_sctp_peeloff = 471;
pub const SYS_sctp_generic_sendmsg = 472;
pub const SYS_sctp_generic_sendmsg_iov = 473;
pub const SYS_sctp_generic_recvmsg = 474;
pub const SYS_pread = 475;
pub const SYS_pwrite = 476;
pub const SYS_mmap = 477;
pub const SYS_lseek = 478;
pub const SYS_truncate = 479;
pub const SYS_ftruncate = 480;
pub const SYS_thr_kill2 = 481;
pub const SYS_shm_open = 482;
pub const SYS_shm_unlink = 483;
pub const SYS_cpuset = 484;
pub const SYS_cpuset_setid = 485;
pub const SYS_cpuset_getid = 486;
pub const SYS_cpuset_getaffinity = 487;
pub const SYS_cpuset_setaffinity = 488;
pub const SYS_faccessat = 489;
pub const SYS_fchmodat = 490;
pub const SYS_fchownat = 491;
pub const SYS_fexecve = 492;
pub const SYS_freebsd11_fstatat = 493;
pub const SYS_futimesat = 494;
pub const SYS_linkat = 495;
pub const SYS_mkdirat = 496;
pub const SYS_mkfifoat = 497;
pub const SYS_freebsd11_mknodat = 498;
pub const SYS_openat = 499;
pub const SYS_readlinkat = 500;
pub const SYS_renameat = 501;
pub const SYS_symlinkat = 502;
pub const SYS_unlinkat = 503;
pub const SYS_posix_openpt = 504;
pub const SYS_gssd_syscall = 505;
pub const SYS_jail_get = 506;
pub const SYS_jail_set = 507;
pub const SYS_jail_remove = 508;
pub const SYS_closefrom = 509;
pub const SYS___semctl = 510;
pub const SYS_msgctl = 511;
pub const SYS_shmctl = 512;
pub const SYS_lpathconf = 513;
// 514 is obsolete cap_new
pub const SYS___cap_rights_get = 515;
pub const SYS_cap_enter = 516;
pub const SYS_cap_getmode = 517;
pub const SYS_pdfork = 518;
pub const SYS_pdkill = 519;
pub const SYS_pdgetpid = 520;
pub const SYS_pselect = 522;
pub const SYS_getloginclass = 523;
pub const SYS_setloginclass = 524;
pub const SYS_rctl_get_racct = 525;
pub const SYS_rctl_get_rules = 526;
pub const SYS_rctl_get_limits = 527;
pub const SYS_rctl_add_rule = 528;
pub const SYS_rctl_remove_rule = 529;
pub const SYS_posix_fallocate = 530;
pub const SYS_posix_fadvise = 531;
pub const SYS_wait6 = 532;
pub const SYS_cap_rights_limit = 533;
pub const SYS_cap_ioctls_limit = 534;
pub const SYS_cap_ioctls_get = 535;
pub const SYS_cap_fcntls_limit = 536;
pub const SYS_cap_fcntls_get = 537;
pub const SYS_bindat = 538;
pub const SYS_connectat = 539;
pub const SYS_chflagsat = 540;
pub const SYS_accept4 = 541;
pub const SYS_pipe2 = 542;
pub const SYS_aio_mlock = 543;
pub const SYS_procctl = 544;
pub const SYS_ppoll = 545;
pub const SYS_futimens = 546;
pub const SYS_utimensat = 547;
pub const SYS_numa_getaffinity = 548;
pub const SYS_numa_setaffinity = 549;
pub const SYS_fdatasync = 550;
pub const SYS_fstat = 551;
pub const SYS_fstatat = 552;
pub const SYS_fhstat = 553;
pub const SYS_getdirentries = 554;
pub const SYS_statfs = 555;
pub const SYS_fstatfs = 556;
pub const SYS_getfsstat = 557;
pub const SYS_fhstatfs = 558;
pub const SYS_mknodat = 559;
pub const SYS_kevent = 560;
pub const SYS_MAXSYSCALL = 561;

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

pub fn syscall0(number: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number)
        : "rcx", "r11"
    );
}

pub fn syscall1(number: usize, arg1: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
          [arg1] "{rdi}" (arg1)
        : "rcx", "r11"
    );
}

pub fn syscall2(number: usize, arg1: usize, arg2: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2)
        : "rcx", "r11"
    );
}

pub fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3)
        : "rcx", "r11"
    );
}

pub fn syscall4(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4)
        : "rcx", "r11"
    );
}

pub fn syscall5(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
          [arg5] "{r8}" (arg5)
        : "rcx", "r11"
    );
}

pub fn syscall6(
    number: usize,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
    arg6: usize,
) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
          [arg5] "{r8}" (arg5),
          [arg6] "{r9}" (arg6)
        : "rcx", "r11"
    );
}

pub nakedcc fn restore_rt() void {
    asm volatile ("syscall"
        :
        : [number] "{rax}" (usize(SYS_rt_sigreturn))
        : "rcx", "r11"
    );
}

pub const msghdr = extern struct {
    msg_name: &u8,
    msg_namelen: socklen_t,
    msg_iov: &iovec,
    msg_iovlen: i32,
    __pad1: i32,
    msg_control: &u8,
    msg_controllen: socklen_t,
    __pad2: socklen_t,
    msg_flags: i32,
};

/// Renamed to Stat to not conflict with the stat function.
pub const Stat = extern struct {
    dev: u64,
    ino: u64,
    nlink: usize,

    mode: u32,
    uid: u32,
    gid: u32,
    __pad0: u32,
    rdev: u64,
    size: i64,
    blksize: isize,
    blocks: i64,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    __unused: [3]isize,
};

pub const timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};
