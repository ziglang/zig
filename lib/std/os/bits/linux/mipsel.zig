const std = @import("../../../std.zig");
const linux = std.os.linux;
const socklen_t = linux.socklen_t;
const iovec = linux.iovec;
const iovec_const = linux.iovec_const;
const uid_t = linux.uid_t;
const gid_t = linux.gid_t;

pub const SYS_Linux = 4000;
pub const SYS_syscall = (SYS_Linux + 0);
pub const SYS_exit = (SYS_Linux + 1);
pub const SYS_fork = (SYS_Linux + 2);
pub const SYS_read = (SYS_Linux + 3);
pub const SYS_write = (SYS_Linux + 4);
pub const SYS_open = (SYS_Linux + 5);
pub const SYS_close = (SYS_Linux + 6);
pub const SYS_waitpid = (SYS_Linux + 7);
pub const SYS_creat = (SYS_Linux + 8);
pub const SYS_link = (SYS_Linux + 9);
pub const SYS_unlink = (SYS_Linux + 10);
pub const SYS_execve = (SYS_Linux + 11);
pub const SYS_chdir = (SYS_Linux + 12);
pub const SYS_time = (SYS_Linux + 13);
pub const SYS_mknod = (SYS_Linux + 14);
pub const SYS_chmod = (SYS_Linux + 15);
pub const SYS_lchown = (SYS_Linux + 16);
pub const SYS_break = (SYS_Linux + 17);
pub const SYS_unused18 = (SYS_Linux + 18);
pub const SYS_lseek = (SYS_Linux + 19);
pub const SYS_getpid = (SYS_Linux + 20);
pub const SYS_mount = (SYS_Linux + 21);
pub const SYS_umount = (SYS_Linux + 22);
pub const SYS_setuid = (SYS_Linux + 23);
pub const SYS_getuid = (SYS_Linux + 24);
pub const SYS_stime = (SYS_Linux + 25);
pub const SYS_ptrace = (SYS_Linux + 26);
pub const SYS_alarm = (SYS_Linux + 27);
pub const SYS_unused28 = (SYS_Linux + 28);
pub const SYS_pause = (SYS_Linux + 29);
pub const SYS_utime = (SYS_Linux + 30);
pub const SYS_stty = (SYS_Linux + 31);
pub const SYS_gtty = (SYS_Linux + 32);
pub const SYS_access = (SYS_Linux + 33);
pub const SYS_nice = (SYS_Linux + 34);
pub const SYS_ftime = (SYS_Linux + 35);
pub const SYS_sync = (SYS_Linux + 36);
pub const SYS_kill = (SYS_Linux + 37);
pub const SYS_rename = (SYS_Linux + 38);
pub const SYS_mkdir = (SYS_Linux + 39);
pub const SYS_rmdir = (SYS_Linux + 40);
pub const SYS_dup = (SYS_Linux + 41);
pub const SYS_pipe = (SYS_Linux + 42);
pub const SYS_times = (SYS_Linux + 43);
pub const SYS_prof = (SYS_Linux + 44);
pub const SYS_brk = (SYS_Linux + 45);
pub const SYS_setgid = (SYS_Linux + 46);
pub const SYS_getgid = (SYS_Linux + 47);
pub const SYS_signal = (SYS_Linux + 48);
pub const SYS_geteuid = (SYS_Linux + 49);
pub const SYS_getegid = (SYS_Linux + 50);
pub const SYS_acct = (SYS_Linux + 51);
pub const SYS_umount2 = (SYS_Linux + 52);
pub const SYS_lock = (SYS_Linux + 53);
pub const SYS_ioctl = (SYS_Linux + 54);
pub const SYS_fcntl = (SYS_Linux + 55);
pub const SYS_mpx = (SYS_Linux + 56);
pub const SYS_setpgid = (SYS_Linux + 57);
pub const SYS_ulimit = (SYS_Linux + 58);
pub const SYS_unused59 = (SYS_Linux + 59);
pub const SYS_umask = (SYS_Linux + 60);
pub const SYS_chroot = (SYS_Linux + 61);
pub const SYS_ustat = (SYS_Linux + 62);
pub const SYS_dup2 = (SYS_Linux + 63);
pub const SYS_getppid = (SYS_Linux + 64);
pub const SYS_getpgrp = (SYS_Linux + 65);
pub const SYS_setsid = (SYS_Linux + 66);
pub const SYS_sigaction = (SYS_Linux + 67);
pub const SYS_sgetmask = (SYS_Linux + 68);
pub const SYS_ssetmask = (SYS_Linux + 69);
pub const SYS_setreuid = (SYS_Linux + 70);
pub const SYS_setregid = (SYS_Linux + 71);
pub const SYS_sigsuspend = (SYS_Linux + 72);
pub const SYS_sigpending = (SYS_Linux + 73);
pub const SYS_sethostname = (SYS_Linux + 74);
pub const SYS_setrlimit = (SYS_Linux + 75);
pub const SYS_getrlimit = (SYS_Linux + 76);
pub const SYS_getrusage = (SYS_Linux + 77);
pub const SYS_gettimeofday = (SYS_Linux + 78);
pub const SYS_settimeofday = (SYS_Linux + 79);
pub const SYS_getgroups = (SYS_Linux + 80);
pub const SYS_setgroups = (SYS_Linux + 81);
pub const SYS_reserved82 = (SYS_Linux + 82);
pub const SYS_symlink = (SYS_Linux + 83);
pub const SYS_unused84 = (SYS_Linux + 84);
pub const SYS_readlink = (SYS_Linux + 85);
pub const SYS_uselib = (SYS_Linux + 86);
pub const SYS_swapon = (SYS_Linux + 87);
pub const SYS_reboot = (SYS_Linux + 88);
pub const SYS_readdir = (SYS_Linux + 89);
pub const SYS_mmap = (SYS_Linux + 90);
pub const SYS_munmap = (SYS_Linux + 91);
pub const SYS_truncate = (SYS_Linux + 92);
pub const SYS_ftruncate = (SYS_Linux + 93);
pub const SYS_fchmod = (SYS_Linux + 94);
pub const SYS_fchown = (SYS_Linux + 95);
pub const SYS_getpriority = (SYS_Linux + 96);
pub const SYS_setpriority = (SYS_Linux + 97);
pub const SYS_profil = (SYS_Linux + 98);
pub const SYS_statfs = (SYS_Linux + 99);
pub const SYS_fstatfs = (SYS_Linux + 100);
pub const SYS_ioperm = (SYS_Linux + 101);
pub const SYS_socketcall = (SYS_Linux + 102);
pub const SYS_syslog = (SYS_Linux + 103);
pub const SYS_setitimer = (SYS_Linux + 104);
pub const SYS_getitimer = (SYS_Linux + 105);
pub const SYS_stat = (SYS_Linux + 106);
pub const SYS_lstat = (SYS_Linux + 107);
pub const SYS_fstat = (SYS_Linux + 108);
pub const SYS_unused109 = (SYS_Linux + 109);
pub const SYS_iopl = (SYS_Linux + 110);
pub const SYS_vhangup = (SYS_Linux + 111);
pub const SYS_idle = (SYS_Linux + 112);
pub const SYS_vm86 = (SYS_Linux + 113);
pub const SYS_wait4 = (SYS_Linux + 114);
pub const SYS_swapoff = (SYS_Linux + 115);
pub const SYS_sysinfo = (SYS_Linux + 116);
pub const SYS_ipc = (SYS_Linux + 117);
pub const SYS_fsync = (SYS_Linux + 118);
pub const SYS_sigreturn = (SYS_Linux + 119);
pub const SYS_clone = (SYS_Linux + 120);
pub const SYS_setdomainname = (SYS_Linux + 121);
pub const SYS_uname = (SYS_Linux + 122);
pub const SYS_modify_ldt = (SYS_Linux + 123);
pub const SYS_adjtimex = (SYS_Linux + 124);
pub const SYS_mprotect = (SYS_Linux + 125);
pub const SYS_sigprocmask = (SYS_Linux + 126);
pub const SYS_create_module = (SYS_Linux + 127);
pub const SYS_init_module = (SYS_Linux + 128);
pub const SYS_delete_module = (SYS_Linux + 129);
pub const SYS_get_kernel_syms = (SYS_Linux + 130);
pub const SYS_quotactl = (SYS_Linux + 131);
pub const SYS_getpgid = (SYS_Linux + 132);
pub const SYS_fchdir = (SYS_Linux + 133);
pub const SYS_bdflush = (SYS_Linux + 134);
pub const SYS_sysfs = (SYS_Linux + 135);
pub const SYS_personality = (SYS_Linux + 136);
pub const SYS_afs_syscall = (SYS_Linux + 137);
pub const SYS_setfsuid = (SYS_Linux + 138);
pub const SYS_setfsgid = (SYS_Linux + 139);
pub const SYS__llseek = (SYS_Linux + 140);
pub const SYS_getdents = (SYS_Linux + 141);
pub const SYS__newselect = (SYS_Linux + 142);
pub const SYS_flock = (SYS_Linux + 143);
pub const SYS_msync = (SYS_Linux + 144);
pub const SYS_readv = (SYS_Linux + 145);
pub const SYS_writev = (SYS_Linux + 146);
pub const SYS_cacheflush = (SYS_Linux + 147);
pub const SYS_cachectl = (SYS_Linux + 148);
pub const SYS_sysmips = (SYS_Linux + 149);
pub const SYS_unused150 = (SYS_Linux + 150);
pub const SYS_getsid = (SYS_Linux + 151);
pub const SYS_fdatasync = (SYS_Linux + 152);
pub const SYS__sysctl = (SYS_Linux + 153);
pub const SYS_mlock = (SYS_Linux + 154);
pub const SYS_munlock = (SYS_Linux + 155);
pub const SYS_mlockall = (SYS_Linux + 156);
pub const SYS_munlockall = (SYS_Linux + 157);
pub const SYS_sched_setparam = (SYS_Linux + 158);
pub const SYS_sched_getparam = (SYS_Linux + 159);
pub const SYS_sched_setscheduler = (SYS_Linux + 160);
pub const SYS_sched_getscheduler = (SYS_Linux + 161);
pub const SYS_sched_yield = (SYS_Linux + 162);
pub const SYS_sched_get_priority_max = (SYS_Linux + 163);
pub const SYS_sched_get_priority_min = (SYS_Linux + 164);
pub const SYS_sched_rr_get_interval = (SYS_Linux + 165);
pub const SYS_nanosleep = (SYS_Linux + 166);
pub const SYS_mremap = (SYS_Linux + 167);
pub const SYS_accept = (SYS_Linux + 168);
pub const SYS_bind = (SYS_Linux + 169);
pub const SYS_connect = (SYS_Linux + 170);
pub const SYS_getpeername = (SYS_Linux + 171);
pub const SYS_getsockname = (SYS_Linux + 172);
pub const SYS_getsockopt = (SYS_Linux + 173);
pub const SYS_listen = (SYS_Linux + 174);
pub const SYS_recv = (SYS_Linux + 175);
pub const SYS_recvfrom = (SYS_Linux + 176);
pub const SYS_recvmsg = (SYS_Linux + 177);
pub const SYS_send = (SYS_Linux + 178);
pub const SYS_sendmsg = (SYS_Linux + 179);
pub const SYS_sendto = (SYS_Linux + 180);
pub const SYS_setsockopt = (SYS_Linux + 181);
pub const SYS_shutdown = (SYS_Linux + 182);
pub const SYS_socket = (SYS_Linux + 183);
pub const SYS_socketpair = (SYS_Linux + 184);
pub const SYS_setresuid = (SYS_Linux + 185);
pub const SYS_getresuid = (SYS_Linux + 186);
pub const SYS_query_module = (SYS_Linux + 187);
pub const SYS_poll = (SYS_Linux + 188);
pub const SYS_nfsservctl = (SYS_Linux + 189);
pub const SYS_setresgid = (SYS_Linux + 190);
pub const SYS_getresgid = (SYS_Linux + 191);
pub const SYS_prctl = (SYS_Linux + 192);
pub const SYS_rt_sigreturn = (SYS_Linux + 193);
pub const SYS_rt_sigaction = (SYS_Linux + 194);
pub const SYS_rt_sigprocmask = (SYS_Linux + 195);
pub const SYS_rt_sigpending = (SYS_Linux + 196);
pub const SYS_rt_sigtimedwait = (SYS_Linux + 197);
pub const SYS_rt_sigqueueinfo = (SYS_Linux + 198);
pub const SYS_rt_sigsuspend = (SYS_Linux + 199);
pub const SYS_pread64 = (SYS_Linux + 200);
pub const SYS_pwrite64 = (SYS_Linux + 201);
pub const SYS_chown = (SYS_Linux + 202);
pub const SYS_getcwd = (SYS_Linux + 203);
pub const SYS_capget = (SYS_Linux + 204);
pub const SYS_capset = (SYS_Linux + 205);
pub const SYS_sigaltstack = (SYS_Linux + 206);
pub const SYS_sendfile = (SYS_Linux + 207);
pub const SYS_getpmsg = (SYS_Linux + 208);
pub const SYS_putpmsg = (SYS_Linux + 209);
pub const SYS_mmap2 = (SYS_Linux + 210);
pub const SYS_truncate64 = (SYS_Linux + 211);
pub const SYS_ftruncate64 = (SYS_Linux + 212);
pub const SYS_stat64 = (SYS_Linux + 213);
pub const SYS_lstat64 = (SYS_Linux + 214);
pub const SYS_fstat64 = (SYS_Linux + 215);
pub const SYS_pivot_root = (SYS_Linux + 216);
pub const SYS_mincore = (SYS_Linux + 217);
pub const SYS_madvise = (SYS_Linux + 218);
pub const SYS_getdents64 = (SYS_Linux + 219);
pub const SYS_fcntl64 = (SYS_Linux + 220);
pub const SYS_reserved221 = (SYS_Linux + 221);
pub const SYS_gettid = (SYS_Linux + 222);
pub const SYS_readahead = (SYS_Linux + 223);
pub const SYS_setxattr = (SYS_Linux + 224);
pub const SYS_lsetxattr = (SYS_Linux + 225);
pub const SYS_fsetxattr = (SYS_Linux + 226);
pub const SYS_getxattr = (SYS_Linux + 227);
pub const SYS_lgetxattr = (SYS_Linux + 228);
pub const SYS_fgetxattr = (SYS_Linux + 229);
pub const SYS_listxattr = (SYS_Linux + 230);
pub const SYS_llistxattr = (SYS_Linux + 231);
pub const SYS_flistxattr = (SYS_Linux + 232);
pub const SYS_removexattr = (SYS_Linux + 233);
pub const SYS_lremovexattr = (SYS_Linux + 234);
pub const SYS_fremovexattr = (SYS_Linux + 235);
pub const SYS_tkill = (SYS_Linux + 236);
pub const SYS_sendfile64 = (SYS_Linux + 237);
pub const SYS_futex = (SYS_Linux + 238);
pub const SYS_sched_setaffinity = (SYS_Linux + 239);
pub const SYS_sched_getaffinity = (SYS_Linux + 240);
pub const SYS_io_setup = (SYS_Linux + 241);
pub const SYS_io_destroy = (SYS_Linux + 242);
pub const SYS_io_getevents = (SYS_Linux + 243);
pub const SYS_io_submit = (SYS_Linux + 244);
pub const SYS_io_cancel = (SYS_Linux + 245);
pub const SYS_exit_group = (SYS_Linux + 246);
pub const SYS_lookup_dcookie = (SYS_Linux + 247);
pub const SYS_epoll_create = (SYS_Linux + 248);
pub const SYS_epoll_ctl = (SYS_Linux + 249);
pub const SYS_epoll_wait = (SYS_Linux + 250);
pub const SYS_remap_file_pages = (SYS_Linux + 251);
pub const SYS_set_tid_address = (SYS_Linux + 252);
pub const SYS_restart_syscall = (SYS_Linux + 253);
pub const SYS_fadvise64 = (SYS_Linux + 254);
pub const SYS_statfs64 = (SYS_Linux + 255);
pub const SYS_fstatfs64 = (SYS_Linux + 256);
pub const SYS_timer_create = (SYS_Linux + 257);
pub const SYS_timer_settime = (SYS_Linux + 258);
pub const SYS_timer_gettime = (SYS_Linux + 259);
pub const SYS_timer_getoverrun = (SYS_Linux + 260);
pub const SYS_timer_delete = (SYS_Linux + 261);
pub const SYS_clock_settime = (SYS_Linux + 262);
pub const SYS_clock_gettime = (SYS_Linux + 263);
pub const SYS_clock_getres = (SYS_Linux + 264);
pub const SYS_clock_nanosleep = (SYS_Linux + 265);
pub const SYS_tgkill = (SYS_Linux + 266);
pub const SYS_utimes = (SYS_Linux + 267);
pub const SYS_mbind = (SYS_Linux + 268);
pub const SYS_get_mempolicy = (SYS_Linux + 269);
pub const SYS_set_mempolicy = (SYS_Linux + 270);
pub const SYS_mq_open = (SYS_Linux + 271);
pub const SYS_mq_unlink = (SYS_Linux + 272);
pub const SYS_mq_timedsend = (SYS_Linux + 273);
pub const SYS_mq_timedreceive = (SYS_Linux + 274);
pub const SYS_mq_notify = (SYS_Linux + 275);
pub const SYS_mq_getsetattr = (SYS_Linux + 276);
pub const SYS_vserver = (SYS_Linux + 277);
pub const SYS_waitid = (SYS_Linux + 278);
pub const SYS_add_key = (SYS_Linux + 280);
pub const SYS_request_key = (SYS_Linux + 281);
pub const SYS_keyctl = (SYS_Linux + 282);
pub const SYS_set_thread_area = (SYS_Linux + 283);
pub const SYS_inotify_init = (SYS_Linux + 284);
pub const SYS_inotify_add_watch = (SYS_Linux + 285);
pub const SYS_inotify_rm_watch = (SYS_Linux + 286);
pub const SYS_migrate_pages = (SYS_Linux + 287);
pub const SYS_openat = (SYS_Linux + 288);
pub const SYS_mkdirat = (SYS_Linux + 289);
pub const SYS_mknodat = (SYS_Linux + 290);
pub const SYS_fchownat = (SYS_Linux + 291);
pub const SYS_futimesat = (SYS_Linux + 292);
pub const SYS_fstatat64 = (SYS_Linux + 293);
pub const SYS_unlinkat = (SYS_Linux + 294);
pub const SYS_renameat = (SYS_Linux + 295);
pub const SYS_linkat = (SYS_Linux + 296);
pub const SYS_symlinkat = (SYS_Linux + 297);
pub const SYS_readlinkat = (SYS_Linux + 298);
pub const SYS_fchmodat = (SYS_Linux + 299);
pub const SYS_faccessat = (SYS_Linux + 300);
pub const SYS_pselect6 = (SYS_Linux + 301);
pub const SYS_ppoll = (SYS_Linux + 302);
pub const SYS_unshare = (SYS_Linux + 303);
pub const SYS_splice = (SYS_Linux + 304);
pub const SYS_sync_file_range = (SYS_Linux + 305);
pub const SYS_tee = (SYS_Linux + 306);
pub const SYS_vmsplice = (SYS_Linux + 307);
pub const SYS_move_pages = (SYS_Linux + 308);
pub const SYS_set_robust_list = (SYS_Linux + 309);
pub const SYS_get_robust_list = (SYS_Linux + 310);
pub const SYS_kexec_load = (SYS_Linux + 311);
pub const SYS_getcpu = (SYS_Linux + 312);
pub const SYS_epoll_pwait = (SYS_Linux + 313);
pub const SYS_ioprio_set = (SYS_Linux + 314);
pub const SYS_ioprio_get = (SYS_Linux + 315);
pub const SYS_utimensat = (SYS_Linux + 316);
pub const SYS_signalfd = (SYS_Linux + 317);
pub const SYS_timerfd = (SYS_Linux + 318);
pub const SYS_eventfd = (SYS_Linux + 319);
pub const SYS_fallocate = (SYS_Linux + 320);
pub const SYS_timerfd_create = (SYS_Linux + 321);
pub const SYS_timerfd_gettime = (SYS_Linux + 322);
pub const SYS_timerfd_settime = (SYS_Linux + 323);
pub const SYS_signalfd4 = (SYS_Linux + 324);
pub const SYS_eventfd2 = (SYS_Linux + 325);
pub const SYS_epoll_create1 = (SYS_Linux + 326);
pub const SYS_dup3 = (SYS_Linux + 327);
pub const SYS_pipe2 = (SYS_Linux + 328);
pub const SYS_inotify_init1 = (SYS_Linux + 329);
pub const SYS_preadv = (SYS_Linux + 330);
pub const SYS_pwritev = (SYS_Linux + 331);
pub const SYS_rt_tgsigqueueinfo = (SYS_Linux + 332);
pub const SYS_perf_event_open = (SYS_Linux + 333);
pub const SYS_accept4 = (SYS_Linux + 334);
pub const SYS_recvmmsg = (SYS_Linux + 335);
pub const SYS_fanotify_init = (SYS_Linux + 336);
pub const SYS_fanotify_mark = (SYS_Linux + 337);
pub const SYS_prlimit64 = (SYS_Linux + 338);
pub const SYS_name_to_handle_at = (SYS_Linux + 339);
pub const SYS_open_by_handle_at = (SYS_Linux + 340);
pub const SYS_clock_adjtime = (SYS_Linux + 341);
pub const SYS_syncfs = (SYS_Linux + 342);
pub const SYS_sendmmsg = (SYS_Linux + 343);
pub const SYS_setns = (SYS_Linux + 344);
pub const SYS_process_vm_readv = (SYS_Linux + 345);
pub const SYS_process_vm_writev = (SYS_Linux + 346);
pub const SYS_kcmp = (SYS_Linux + 347);
pub const SYS_finit_module = (SYS_Linux + 348);
pub const SYS_sched_setattr = (SYS_Linux + 349);
pub const SYS_sched_getattr = (SYS_Linux + 350);
pub const SYS_renameat2 = (SYS_Linux + 351);
pub const SYS_seccomp = (SYS_Linux + 352);
pub const SYS_getrandom = (SYS_Linux + 353);
pub const SYS_memfd_create = (SYS_Linux + 354);
pub const SYS_bpf = (SYS_Linux + 355);
pub const SYS_execveat = (SYS_Linux + 356);
pub const SYS_userfaultfd = (SYS_Linux + 357);
pub const SYS_membarrier = (SYS_Linux + 358);
pub const SYS_mlock2 = (SYS_Linux + 359);
pub const SYS_copy_file_range = (SYS_Linux + 360);
pub const SYS_preadv2 = (SYS_Linux + 361);
pub const SYS_pwritev2 = (SYS_Linux + 362);
pub const SYS_pkey_mprotect = (SYS_Linux + 363);
pub const SYS_pkey_alloc = (SYS_Linux + 364);
pub const SYS_pkey_free = (SYS_Linux + 365);
pub const SYS_statx = (SYS_Linux + 366);
pub const SYS_rseq = (SYS_Linux + 367);
pub const SYS_io_pgetevents = (SYS_Linux + 368);

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

pub const VDSO_USEFUL = true;
pub const VDSO_CGT_SYM = "__kernel_clock_gettime";
pub const VDSO_CGT_VER = "LINUX_2.6.39";

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = isize;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = usize;
pub const blkcnt_t = i64;

pub const Stat = extern struct {
    dev: u32,
    __pad0: [3]u32,
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    __pad1: [3]u32,
    size: off_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    blksize: blksize_t,
    __pad3: [1]u32,
    blocks: blkcnt_t,
    __pad4: [14]usize,

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
