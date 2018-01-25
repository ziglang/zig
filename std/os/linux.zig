const std = @import("../index.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const arch = switch (builtin.arch) {
    builtin.Arch.x86_64 => @import("linux_x86_64.zig"),
    builtin.Arch.i386 => @import("linux_i386.zig"),
    else => @compileError("unsupported arch"),
};
pub use @import("linux_errno.zig");

pub const PATH_MAX = 4096;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const PROT_NONE      = 0;
pub const PROT_READ      = 1;
pub const PROT_WRITE     = 2;
pub const PROT_EXEC      = 4;
pub const PROT_GROWSDOWN = 0x01000000;
pub const PROT_GROWSUP   = 0x02000000;

pub const MAP_FAILED     = @maxValue(usize);
pub const MAP_SHARED     = 0x01;
pub const MAP_PRIVATE    = 0x02;
pub const MAP_TYPE       = 0x0f;
pub const MAP_FIXED      = 0x10;
pub const MAP_ANONYMOUS  = 0x20;
pub const MAP_NORESERVE  = 0x4000;
pub const MAP_GROWSDOWN  = 0x0100;
pub const MAP_DENYWRITE  = 0x0800;
pub const MAP_EXECUTABLE = 0x1000;
pub const MAP_LOCKED     = 0x2000;
pub const MAP_POPULATE   = 0x8000;
pub const MAP_NONBLOCK   = 0x10000;
pub const MAP_STACK      = 0x20000;
pub const MAP_HUGETLB    = 0x40000;
pub const MAP_FILE       = 0;

pub const WNOHANG    = 1;
pub const WUNTRACED  = 2;
pub const WSTOPPED   = 2;
pub const WEXITED    = 4;
pub const WCONTINUED = 8;
pub const WNOWAIT    = 0x1000000;

pub const SA_NOCLDSTOP  = 1;
pub const SA_NOCLDWAIT  = 2;
pub const SA_SIGINFO    = 4;
pub const SA_ONSTACK    = 0x08000000;
pub const SA_RESTART    = 0x10000000;
pub const SA_NODEFER    = 0x40000000;
pub const SA_RESETHAND  = 0x80000000;
pub const SA_RESTORER   = 0x04000000;

pub const SIGHUP    = 1;
pub const SIGINT    = 2;
pub const SIGQUIT   = 3;
pub const SIGILL    = 4;
pub const SIGTRAP   = 5;
pub const SIGABRT   = 6;
pub const SIGIOT    = SIGABRT;
pub const SIGBUS    = 7;
pub const SIGFPE    = 8;
pub const SIGKILL   = 9;
pub const SIGUSR1   = 10;
pub const SIGSEGV   = 11;
pub const SIGUSR2   = 12;
pub const SIGPIPE   = 13;
pub const SIGALRM   = 14;
pub const SIGTERM   = 15;
pub const SIGSTKFLT = 16;
pub const SIGCHLD   = 17;
pub const SIGCONT   = 18;
pub const SIGSTOP   = 19;
pub const SIGTSTP   = 20;
pub const SIGTTIN   = 21;
pub const SIGTTOU   = 22;
pub const SIGURG    = 23;
pub const SIGXCPU   = 24;
pub const SIGXFSZ   = 25;
pub const SIGVTALRM = 26;
pub const SIGPROF   = 27;
pub const SIGWINCH  = 28;
pub const SIGIO     = 29;
pub const SIGPOLL   = 29;
pub const SIGPWR    = 30;
pub const SIGSYS    = 31;
pub const SIGUNUSED = SIGSYS;

pub const O_RDONLY = 0o0;
pub const O_WRONLY = 0o1;
pub const O_RDWR   = 0o2;

pub const O_CREAT = arch.O_CREAT;
pub const O_EXCL = arch.O_EXCL;
pub const O_NOCTTY = arch.O_NOCTTY;
pub const O_TRUNC = arch.O_TRUNC;
pub const O_APPEND = arch.O_APPEND;
pub const O_NONBLOCK = arch.O_NONBLOCK;
pub const O_DSYNC = arch.O_DSYNC;
pub const O_SYNC = arch.O_SYNC;
pub const O_RSYNC = arch.O_RSYNC;
pub const O_DIRECTORY = arch.O_DIRECTORY;
pub const O_NOFOLLOW = arch.O_NOFOLLOW;
pub const O_CLOEXEC = arch.O_CLOEXEC;

pub const O_ASYNC = arch.O_ASYNC;
pub const O_DIRECT = arch.O_DIRECT;
pub const O_LARGEFILE = arch.O_LARGEFILE;
pub const O_NOATIME = arch.O_NOATIME;
pub const O_PATH = arch.O_PATH;
pub const O_TMPFILE = arch.O_TMPFILE;
pub const O_NDELAY = arch.O_NDELAY;

pub const SEEK_SET = 0;
pub const SEEK_CUR = 1;
pub const SEEK_END = 2;

pub const SIG_BLOCK   = 0;
pub const SIG_UNBLOCK = 1;
pub const SIG_SETMASK = 2;

pub const SOCK_STREAM = 1;
pub const SOCK_DGRAM = 2;
pub const SOCK_RAW = 3;
pub const SOCK_RDM = 4;
pub const SOCK_SEQPACKET = 5;
pub const SOCK_DCCP = 6;
pub const SOCK_PACKET = 10;
pub const SOCK_CLOEXEC = 0o2000000;
pub const SOCK_NONBLOCK = 0o4000;


pub const PROTO_ip = 0o000;
pub const PROTO_icmp = 0o001;
pub const PROTO_igmp = 0o002;
pub const PROTO_ggp = 0o003;
pub const PROTO_ipencap = 0o004;
pub const PROTO_st = 0o005;
pub const PROTO_tcp = 0o006;
pub const PROTO_egp = 0o010;
pub const PROTO_pup = 0o014;
pub const PROTO_udp = 0o021;
pub const PROTO_hmp = 0o024;
pub const PROTO_xns_idp = 0o026;
pub const PROTO_rdp = 0o033;
pub const PROTO_iso_tp4 = 0o035;
pub const PROTO_xtp = 0o044;
pub const PROTO_ddp = 0o045;
pub const PROTO_idpr_cmtp = 0o046;
pub const PROTO_ipv6 = 0o051;
pub const PROTO_ipv6_route = 0o053;
pub const PROTO_ipv6_frag = 0o054;
pub const PROTO_idrp = 0o055;
pub const PROTO_rsvp = 0o056;
pub const PROTO_gre = 0o057;
pub const PROTO_esp = 0o062;
pub const PROTO_ah = 0o063;
pub const PROTO_skip = 0o071;
pub const PROTO_ipv6_icmp = 0o072;
pub const PROTO_ipv6_nonxt = 0o073;
pub const PROTO_ipv6_opts = 0o074;
pub const PROTO_rspf = 0o111;
pub const PROTO_vmtp = 0o121;
pub const PROTO_ospf = 0o131;
pub const PROTO_ipip = 0o136;
pub const PROTO_encap = 0o142;
pub const PROTO_pim = 0o147;
pub const PROTO_raw = 0o377;

pub const PF_UNSPEC = 0;
pub const PF_LOCAL = 1;
pub const PF_UNIX = PF_LOCAL;
pub const PF_FILE = PF_LOCAL;
pub const PF_INET = 2;
pub const PF_AX25 = 3;
pub const PF_IPX = 4;
pub const PF_APPLETALK = 5;
pub const PF_NETROM = 6;
pub const PF_BRIDGE = 7;
pub const PF_ATMPVC = 8;
pub const PF_X25 = 9;
pub const PF_INET6 = 10;
pub const PF_ROSE = 11;
pub const PF_DECnet = 12;
pub const PF_NETBEUI = 13;
pub const PF_SECURITY = 14;
pub const PF_KEY = 15;
pub const PF_NETLINK = 16;
pub const PF_ROUTE = PF_NETLINK;
pub const PF_PACKET = 17;
pub const PF_ASH = 18;
pub const PF_ECONET = 19;
pub const PF_ATMSVC = 20;
pub const PF_RDS = 21;
pub const PF_SNA = 22;
pub const PF_IRDA = 23;
pub const PF_PPPOX = 24;
pub const PF_WANPIPE = 25;
pub const PF_LLC = 26;
pub const PF_IB = 27;
pub const PF_MPLS = 28;
pub const PF_CAN = 29;
pub const PF_TIPC = 30;
pub const PF_BLUETOOTH = 31;
pub const PF_IUCV = 32;
pub const PF_RXRPC = 33;
pub const PF_ISDN = 34;
pub const PF_PHONET = 35;
pub const PF_IEEE802154 = 36;
pub const PF_CAIF = 37;
pub const PF_ALG = 38;
pub const PF_NFC = 39;
pub const PF_VSOCK = 40;
pub const PF_MAX = 41;

pub const AF_UNSPEC = PF_UNSPEC;
pub const AF_LOCAL = PF_LOCAL;
pub const AF_UNIX = AF_LOCAL;
pub const AF_FILE = AF_LOCAL;
pub const AF_INET = PF_INET;
pub const AF_AX25 = PF_AX25;
pub const AF_IPX = PF_IPX;
pub const AF_APPLETALK = PF_APPLETALK;
pub const AF_NETROM = PF_NETROM;
pub const AF_BRIDGE = PF_BRIDGE;
pub const AF_ATMPVC = PF_ATMPVC;
pub const AF_X25 = PF_X25;
pub const AF_INET6 = PF_INET6;
pub const AF_ROSE = PF_ROSE;
pub const AF_DECnet = PF_DECnet;
pub const AF_NETBEUI = PF_NETBEUI;
pub const AF_SECURITY = PF_SECURITY;
pub const AF_KEY = PF_KEY;
pub const AF_NETLINK = PF_NETLINK;
pub const AF_ROUTE = PF_ROUTE;
pub const AF_PACKET = PF_PACKET;
pub const AF_ASH = PF_ASH;
pub const AF_ECONET = PF_ECONET;
pub const AF_ATMSVC = PF_ATMSVC;
pub const AF_RDS = PF_RDS;
pub const AF_SNA = PF_SNA;
pub const AF_IRDA = PF_IRDA;
pub const AF_PPPOX = PF_PPPOX;
pub const AF_WANPIPE = PF_WANPIPE;
pub const AF_LLC = PF_LLC;
pub const AF_IB = PF_IB;
pub const AF_MPLS = PF_MPLS;
pub const AF_CAN = PF_CAN;
pub const AF_TIPC = PF_TIPC;
pub const AF_BLUETOOTH = PF_BLUETOOTH;
pub const AF_IUCV = PF_IUCV;
pub const AF_RXRPC = PF_RXRPC;
pub const AF_ISDN = PF_ISDN;
pub const AF_PHONET = PF_PHONET;
pub const AF_IEEE802154 = PF_IEEE802154;
pub const AF_CAIF = PF_CAIF;
pub const AF_ALG = PF_ALG;
pub const AF_NFC = PF_NFC;
pub const AF_VSOCK = PF_VSOCK;
pub const AF_MAX = PF_MAX;

pub const DT_UNKNOWN = 0;
pub const DT_FIFO = 1;
pub const DT_CHR = 2;
pub const DT_DIR = 4;
pub const DT_BLK = 6;
pub const DT_REG = 8;
pub const DT_LNK = 10;
pub const DT_SOCK = 12;
pub const DT_WHT = 14;


pub const TCGETS = 0x5401;
pub const TCSETS = 0x5402;
pub const TCSETSW = 0x5403;
pub const TCSETSF = 0x5404;
pub const TCGETA = 0x5405;
pub const TCSETA = 0x5406;
pub const TCSETAW = 0x5407;
pub const TCSETAF = 0x5408;
pub const TCSBRK = 0x5409;
pub const TCXONC = 0x540A;
pub const TCFLSH = 0x540B;
pub const TIOCEXCL = 0x540C;
pub const TIOCNXCL = 0x540D;
pub const TIOCSCTTY = 0x540E;
pub const TIOCGPGRP = 0x540F;
pub const TIOCSPGRP = 0x5410;
pub const TIOCOUTQ = 0x5411;
pub const TIOCSTI = 0x5412;
pub const TIOCGWINSZ = 0x5413;
pub const TIOCSWINSZ = 0x5414;
pub const TIOCMGET = 0x5415;
pub const TIOCMBIS = 0x5416;
pub const TIOCMBIC = 0x5417;
pub const TIOCMSET = 0x5418;
pub const TIOCGSOFTCAR = 0x5419;
pub const TIOCSSOFTCAR = 0x541A;
pub const FIONREAD = 0x541B;
pub const TIOCINQ = FIONREAD;
pub const TIOCLINUX = 0x541C;
pub const TIOCCONS = 0x541D;
pub const TIOCGSERIAL = 0x541E;
pub const TIOCSSERIAL = 0x541F;
pub const TIOCPKT = 0x5420;
pub const FIONBIO = 0x5421;
pub const TIOCNOTTY = 0x5422;
pub const TIOCSETD = 0x5423;
pub const TIOCGETD = 0x5424;
pub const TCSBRKP = 0x5425;
pub const TIOCSBRK = 0x5427;
pub const TIOCCBRK = 0x5428;
pub const TIOCGSID = 0x5429;
pub const TIOCGRS485 = 0x542E;
pub const TIOCSRS485 = 0x542F;
pub const TIOCGPTN = 0x80045430;
pub const TIOCSPTLCK = 0x40045431;
pub const TIOCGDEV = 0x80045432;
pub const TCGETX = 0x5432;
pub const TCSETX = 0x5433;
pub const TCSETXF = 0x5434;
pub const TCSETXW = 0x5435;
pub const TIOCSIG = 0x40045436;
pub const TIOCVHANGUP = 0x5437;
pub const TIOCGPKT = 0x80045438;
pub const TIOCGPTLCK = 0x80045439;
pub const TIOCGEXCL = 0x80045440;

pub const EPOLL_CTL_ADD = 1;
pub const EPOLL_CTL_DEL = 2;
pub const EPOLL_CTL_MOD = 3;

pub const EPOLLIN = 0x001;
pub const EPOLLPRI = 0x002;
pub const EPOLLOUT = 0x004;
pub const EPOLLRDNORM = 0x040;
pub const EPOLLRDBAND = 0x080;
pub const EPOLLWRNORM = 0x100;
pub const EPOLLWRBAND = 0x200;
pub const EPOLLMSG = 0x400;
pub const EPOLLERR = 0x008;
pub const EPOLLHUP = 0x010;
pub const EPOLLRDHUP = 0x2000;
pub const EPOLLEXCLUSIVE = (u32(1) << 28);
pub const EPOLLWAKEUP = (u32(1) << 29);
pub const EPOLLONESHOT = (u32(1) << 30);
pub const EPOLLET = (u32(1) << 31);

pub const CLOCK_REALTIME = 0;
pub const CLOCK_MONOTONIC = 1;
pub const CLOCK_PROCESS_CPUTIME_ID = 2;
pub const CLOCK_THREAD_CPUTIME_ID = 3;
pub const CLOCK_MONOTONIC_RAW = 4;
pub const CLOCK_REALTIME_COARSE = 5;
pub const CLOCK_MONOTONIC_COARSE = 6;
pub const CLOCK_BOOTTIME = 7;
pub const CLOCK_REALTIME_ALARM = 8;
pub const CLOCK_BOOTTIME_ALARM = 9;
pub const CLOCK_SGI_CYCLE = 10;
pub const CLOCK_TAI = 11;

pub const TFD_NONBLOCK = O_NONBLOCK;
pub const TFD_CLOEXEC = O_CLOEXEC;

pub const TFD_TIMER_ABSTIME = 1;
pub const TFD_TIMER_CANCEL_ON_SET = (1 << 1);

fn unsigned(s: i32) u32 { return @bitCast(u32, s); }
fn signed(s: u32) i32 { return @bitCast(i32, s); }
pub fn WEXITSTATUS(s: i32) i32 { return signed((unsigned(s) & 0xff00) >> 8); }
pub fn WTERMSIG(s: i32) i32 { return signed(unsigned(s) & 0x7f); }
pub fn WSTOPSIG(s: i32) i32 { return WEXITSTATUS(s); }
pub fn WIFEXITED(s: i32) bool { return WTERMSIG(s) == 0; }
pub fn WIFSTOPPED(s: i32) bool { return (u16)(((unsigned(s)&0xffff)*%0x10001)>>8) > 0x7f00; }
pub fn WIFSIGNALED(s: i32) bool { return (unsigned(s)&0xffff)-%1 < 0xff; }


pub const winsize = extern struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

/// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: usize) usize {
    const signed_r = @bitCast(isize, r);
    return if (signed_r > -4096 and signed_r < 0) usize(-signed_r) else 0;
}

pub fn dup2(old: i32, new: i32) usize {
    return arch.syscall2(arch.SYS_dup2, usize(old), usize(new));
}

pub fn chdir(path: &const u8) usize {
    return arch.syscall1(arch.SYS_chdir, @ptrToInt(path));
}

pub fn execve(path: &const u8, argv: &const ?&const u8, envp: &const ?&const u8) usize {
    return arch.syscall3(arch.SYS_execve, @ptrToInt(path), @ptrToInt(argv), @ptrToInt(envp));
}

pub fn fork() usize {
    return arch.syscall0(arch.SYS_fork);
}

pub fn getcwd(buf: &u8, size: usize) usize {
    return arch.syscall2(arch.SYS_getcwd, @ptrToInt(buf), size);
}

pub fn getdents(fd: i32, dirp: &u8, count: usize) usize {
    return arch.syscall3(arch.SYS_getdents, usize(fd), @ptrToInt(dirp), count);
}

pub fn isatty(fd: i32) bool {
    var wsz: winsize = undefined;
    return arch.syscall3(arch.SYS_ioctl, usize(fd), TIOCGWINSZ, @ptrToInt(&wsz)) == 0;
}

pub fn readlink(noalias path: &const u8, noalias buf_ptr: &u8, buf_len: usize) usize {
    return arch.syscall3(arch.SYS_readlink, @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
}

pub fn mkdir(path: &const u8, mode: u32) usize {
    return arch.syscall2(arch.SYS_mkdir, @ptrToInt(path), mode);
}

pub fn mmap(address: ?&u8, length: usize, prot: usize, flags: usize, fd: i32, offset: isize) usize {
    return arch.syscall6(arch.SYS_mmap, @ptrToInt(address), length, prot, flags, usize(fd),
        @bitCast(usize, offset));
}

pub fn munmap(address: &u8, length: usize) usize {
    return arch.syscall2(arch.SYS_munmap, @ptrToInt(address), length);
}

pub fn read(fd: i32, buf: &u8, count: usize) usize {
    return arch.syscall3(arch.SYS_read, usize(fd), @ptrToInt(buf), count);
}

pub fn rmdir(path: &const u8) usize {
    return arch.syscall1(arch.SYS_rmdir, @ptrToInt(path));
}

pub fn symlink(existing: &const u8, new: &const u8) usize {
    return arch.syscall2(arch.SYS_symlink, @ptrToInt(existing), @ptrToInt(new));
}

pub fn pread(fd: i32, buf: &u8, count: usize, offset: usize) usize {
    return arch.syscall4(arch.SYS_pread, usize(fd), @ptrToInt(buf), count, offset);
}

pub fn pipe(fd: &[2]i32) usize {
    return pipe2(fd, 0);
}

pub fn pipe2(fd: &[2]i32, flags: usize) usize {
    return arch.syscall2(arch.SYS_pipe2, @ptrToInt(fd), flags);
}

pub fn write(fd: i32, buf: &const u8, count: usize) usize {
    return arch.syscall3(arch.SYS_write, usize(fd), @ptrToInt(buf), count);
}

pub fn pwrite(fd: i32, buf: &const u8, count: usize, offset: usize) usize {
    return arch.syscall4(arch.SYS_pwrite, usize(fd), @ptrToInt(buf), count, offset);
}

pub fn rename(old: &const u8, new: &const u8) usize {
    return arch.syscall2(arch.SYS_rename, @ptrToInt(old), @ptrToInt(new));
}

pub fn open(path: &const u8, flags: u32, perm: usize) usize {
    return arch.syscall3(arch.SYS_open, @ptrToInt(path), flags, perm);
}

pub fn create(path: &const u8, perm: usize) usize {
    return arch.syscall2(arch.SYS_creat, @ptrToInt(path), perm);
}

pub fn openat(dirfd: i32, path: &const u8, flags: usize, mode: usize) usize {
    return arch.syscall4(arch.SYS_openat, usize(dirfd), @ptrToInt(path), flags, mode);
}

pub fn close(fd: i32) usize {
    return arch.syscall1(arch.SYS_close, usize(fd));
}

pub fn lseek(fd: i32, offset: isize, ref_pos: usize) usize {
    return arch.syscall3(arch.SYS_lseek, usize(fd), @bitCast(usize, offset), ref_pos);
}

pub fn exit(status: i32) noreturn {
    _ = arch.syscall1(arch.SYS_exit, @bitCast(usize, isize(status)));
    unreachable;
}

pub fn getrandom(buf: &u8, count: usize, flags: u32) usize {
    return arch.syscall3(arch.SYS_getrandom, @ptrToInt(buf), count, usize(flags));
}

pub fn kill(pid: i32, sig: i32) usize {
    return arch.syscall2(arch.SYS_kill, @bitCast(usize, isize(pid)), usize(sig));
}

pub fn unlink(path: &const u8) usize {
    return arch.syscall1(arch.SYS_unlink, @ptrToInt(path));
}

pub fn waitpid(pid: i32, status: &i32, options: i32) usize {
    return arch.syscall4(arch.SYS_wait4, @bitCast(usize, isize(pid)), @ptrToInt(status), @bitCast(usize, isize(options)), 0);
}

pub fn nanosleep(req: &const timespec, rem: ?&timespec) usize {
    return arch.syscall2(arch.SYS_nanosleep, @ptrToInt(req), @ptrToInt(rem));
}

pub fn setuid(uid: u32) usize {
    return arch.syscall1(arch.SYS_setuid, uid);
}

pub fn setgid(gid: u32) usize {
    return arch.syscall1(arch.SYS_setgid, gid);
}

pub fn setreuid(ruid: u32, euid: u32) usize {
    return arch.syscall2(arch.SYS_setreuid, ruid, euid);
}

pub fn setregid(rgid: u32, egid: u32) usize {
    return arch.syscall2(arch.SYS_setregid, rgid, egid);
}

pub fn sigprocmask(flags: u32, noalias set: &const sigset_t, noalias oldset: ?&sigset_t) usize {
    return arch.syscall4(arch.SYS_rt_sigprocmask, flags, @ptrToInt(set), @ptrToInt(oldset), NSIG/8);
}

pub fn sigaction(sig: u6, noalias act: &const Sigaction, noalias oact: ?&Sigaction) usize {
    assert(sig >= 1);
    assert(sig != SIGKILL);
    assert(sig != SIGSTOP);
    var ksa = k_sigaction {
        .handler = act.handler,
        .flags = act.flags | SA_RESTORER,
        .mask = undefined,
        .restorer = @ptrCast(extern fn()void, arch.restore_rt),
    };
    var ksa_old: k_sigaction = undefined;
    @memcpy(@ptrCast(&u8, &ksa.mask), @ptrCast(&const u8, &act.mask), 8);
    const result = arch.syscall4(arch.SYS_rt_sigaction, sig, @ptrToInt(&ksa), @ptrToInt(&ksa_old), @sizeOf(@typeOf(ksa.mask)));
    const err = getErrno(result);
    if (err != 0) {
        return result;
    }
    if (oact) |old| {
        old.handler = ksa_old.handler;
        old.flags = @truncate(u32, ksa_old.flags);
        @memcpy(@ptrCast(&u8, &old.mask), @ptrCast(&const u8, &ksa_old.mask), @sizeOf(@typeOf(ksa_old.mask)));
    }
    return 0;
}

const NSIG = 65;
const sigset_t = [128 / @sizeOf(usize)]usize;
const all_mask = []usize{@maxValue(usize)};
const app_mask = []usize{0xfffffffc7fffffff};

const k_sigaction = extern struct {
    handler: extern fn(i32)void,
    flags: usize,
    restorer: extern fn()void,
    mask: [2]u32,
};

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = struct {
    handler: extern fn(i32)void,
    mask: sigset_t,
    flags: u32,
};

pub const SIG_ERR = @intToPtr(extern fn(i32)void, @maxValue(usize));
pub const SIG_DFL = @intToPtr(extern fn(i32)void, 0);
pub const SIG_IGN = @intToPtr(extern fn(i32)void, 1);
pub const empty_sigset = []usize{0} ** sigset_t.len;

pub fn raise(sig: i32) usize {
    var set: sigset_t = undefined;
    blockAppSignals(&set);
    const tid = i32(arch.syscall0(arch.SYS_gettid));
    const ret = arch.syscall2(arch.SYS_tkill, usize(tid), usize(sig));
    restoreSignals(&set);
    return ret;
}

fn blockAllSignals(set: &sigset_t) void {
    _ = arch.syscall4(arch.SYS_rt_sigprocmask, SIG_BLOCK, @ptrToInt(&all_mask), @ptrToInt(set), NSIG/8);
}

fn blockAppSignals(set: &sigset_t) void {
    _ = arch.syscall4(arch.SYS_rt_sigprocmask, SIG_BLOCK, @ptrToInt(&app_mask), @ptrToInt(set), NSIG/8);
}

fn restoreSignals(set: &sigset_t) void {
    _ = arch.syscall4(arch.SYS_rt_sigprocmask, SIG_SETMASK, @ptrToInt(set), 0, NSIG/8);
}

pub fn sigaddset(set: &sigset_t, sig: u6) void {
    const s = sig - 1;
    (*set)[usize(s) / usize.bit_count] |= usize(1) << (s & (usize.bit_count - 1));
}

pub fn sigismember(set: &const sigset_t, sig: u6) bool {
    const s = sig - 1;
    return ((*set)[usize(s) / usize.bit_count] & (usize(1) << (s & (usize.bit_count - 1)))) != 0;
}


pub const sa_family_t = u16;
pub const socklen_t = u32;
pub const in_addr = u32;
pub const in6_addr = [16]u8;

pub const sockaddr = extern struct {
    family: sa_family_t,
    port: u16,
    data: [12]u8,
};

pub const sockaddr_in = extern struct {
    family: sa_family_t,
    port: u16,
    addr: in_addr,
    zero: [8]u8,
};

pub const sockaddr_in6 = extern struct {
    family: sa_family_t,
    port: u16,
    flowinfo: u32,
    addr: in6_addr,
    scope_id: u32,
};

pub const iovec = extern struct {
    iov_base: &u8,
    iov_len: usize,
};

pub fn getsockname(fd: i32, noalias addr: &sockaddr, noalias len: &socklen_t) usize {
    return arch.syscall3(arch.SYS_getsockname, usize(fd), @ptrToInt(addr), @ptrToInt(len));
}

pub fn getpeername(fd: i32, noalias addr: &sockaddr, noalias len: &socklen_t) usize {
    return arch.syscall3(arch.SYS_getpeername, usize(fd), @ptrToInt(addr), @ptrToInt(len));
}

pub fn socket(domain: i32, socket_type: i32, protocol: i32) usize {
    return arch.syscall3(arch.SYS_socket, usize(domain), usize(socket_type), usize(protocol));
}

pub fn setsockopt(fd: i32, level: i32, optname: i32, optval: &const u8, optlen: socklen_t) usize {
    return arch.syscall5(arch.SYS_setsockopt, usize(fd), usize(level), usize(optname), usize(optval), @ptrToInt(optlen));
}

pub fn getsockopt(fd: i32, level: i32, optname: i32, noalias optval: &u8, noalias optlen: &socklen_t) usize {
    return arch.syscall5(arch.SYS_getsockopt, usize(fd), usize(level), usize(optname), @ptrToInt(optval), @ptrToInt(optlen));
}

pub fn sendmsg(fd: i32, msg: &const arch.msghdr, flags: u32) usize {
    return arch.syscall3(arch.SYS_sendmsg, usize(fd), @ptrToInt(msg), flags);
}

pub fn connect(fd: i32, addr: &const sockaddr, len: socklen_t) usize {
    return arch.syscall3(arch.SYS_connect, usize(fd), @ptrToInt(addr), usize(len));
}

pub fn recvmsg(fd: i32, msg: &arch.msghdr, flags: u32) usize {
    return arch.syscall3(arch.SYS_recvmsg, usize(fd), @ptrToInt(msg), flags);
}

pub fn recvfrom(fd: i32, noalias buf: &u8, len: usize, flags: u32,
    noalias addr: ?&sockaddr, noalias alen: ?&socklen_t) usize
{
    return arch.syscall6(arch.SYS_recvfrom, usize(fd), @ptrToInt(buf), len, flags, @ptrToInt(addr), @ptrToInt(alen));
}

pub fn shutdown(fd: i32, how: i32) usize {
    return arch.syscall2(arch.SYS_shutdown, usize(fd), usize(how));
}

pub fn bind(fd: i32, addr: &const sockaddr, len: socklen_t) usize {
    return arch.syscall3(arch.SYS_bind, usize(fd), @ptrToInt(addr), usize(len));
}

pub fn listen(fd: i32, backlog: i32) usize {
    return arch.syscall2(arch.SYS_listen, usize(fd), usize(backlog));
}

pub fn sendto(fd: i32, buf: &const u8, len: usize, flags: u32, addr: ?&const sockaddr, alen: socklen_t) usize {
    return arch.syscall6(arch.SYS_sendto, usize(fd), @ptrToInt(buf), len, flags, @ptrToInt(addr), usize(alen));
}

pub fn socketpair(domain: i32, socket_type: i32, protocol: i32, fd: [2]i32) usize {
    return arch.syscall4(arch.SYS_socketpair, usize(domain), usize(socket_type), usize(protocol), @ptrToInt(&fd[0]));
}

pub fn accept(fd: i32, noalias addr: &sockaddr, noalias len: &socklen_t) usize {
    return accept4(fd, addr, len, 0);
}

pub fn accept4(fd: i32, noalias addr: &sockaddr, noalias len: &socklen_t, flags: u32) usize {
    return arch.syscall4(arch.SYS_accept4, usize(fd), @ptrToInt(addr), @ptrToInt(len), flags);
}

// error NameTooLong;
// error SystemResources;
// error Io;
// 
// pub fn if_nametoindex(name: []u8) %u32 {
//     var ifr: ifreq = undefined;
// 
//     if (name.len >= ifr.ifr_name.len) {
//         return error.NameTooLong;
//     }
// 
//     const socket_ret = socket(AF_UNIX, SOCK_DGRAM|SOCK_CLOEXEC, 0);
//     const socket_err = getErrno(socket_ret);
//     if (socket_err > 0) {
//         return error.SystemResources;
//     }
//     const socket_fd = i32(socket_ret);
//     @memcpy(&ifr.ifr_name[0], &name[0], name.len);
//     ifr.ifr_name[name.len] = 0;
//     const ioctl_ret = ioctl(socket_fd, SIOCGIFINDEX, &ifr);
//     close(socket_fd);
//     const ioctl_err = getErrno(ioctl_ret);
//     if (ioctl_err > 0) {
//         return error.Io;
//     }
//     return ifr.ifr_ifindex;
// }

pub const Stat = arch.Stat;
pub const timespec = arch.timespec;

pub fn fstat(fd: i32, stat_buf: &Stat) usize {
    return arch.syscall2(arch.SYS_fstat, usize(fd), @ptrToInt(stat_buf));
}

pub const epoll_data = u64;

pub const epoll_event = extern struct {
    events: u32,
    data: epoll_data
};

pub fn epoll_create() usize {
    return arch.syscall1(arch.SYS_epoll_create, usize(1));
}

pub fn epoll_ctl(epoll_fd: i32, op: i32, fd: i32, ev: &epoll_event) usize {
    return arch.syscall4(arch.SYS_epoll_ctl, usize(epoll_fd), usize(op), usize(fd), @ptrToInt(ev));
}

pub fn epoll_wait(epoll_fd: i32, events: &epoll_event, maxevents: i32, timeout: i32) usize {
    return arch.syscall4(arch.SYS_epoll_wait, usize(epoll_fd), @ptrToInt(events), usize(maxevents), usize(timeout));
}

pub fn timerfd_create(clockid: i32, flags: u32) usize {
    return arch.syscall2(arch.SYS_timerfd_create, usize(clockid), usize(flags));
}

pub const itimerspec = extern struct {
    it_interval: timespec,
    it_value: timespec
};

pub fn timerfd_gettime(fd: i32, curr_value: &itimerspec) usize {
    return arch.syscall2(arch.SYS_timerfd_gettime, usize(fd), @ptrToInt(curr_value));
}

pub fn timerfd_settime(fd: i32, flags: u32, new_value: &const itimerspec, old_value: ?&itimerspec) usize {
    return arch.syscall4(arch.SYS_timerfd_settime, usize(fd), usize(flags), @ptrToInt(new_value), @ptrToInt(old_value));
}

test "import linux_test" {
    // TODO lazy analysis should prevent this test from being compiled on windows, but
    // it is still compiled on windows
    if (builtin.os == builtin.Os.linux) {
        _ = @import("linux_test.zig");
    }
}
