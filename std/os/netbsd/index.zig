const builtin = @import("builtin");

pub use @import("errno.zig");

const std = @import("../../index.zig");
const c = std.c;

const assert = std.debug.assert;
const maxInt = std.math.maxInt;
pub const Kevent = c.Kevent;

pub const CTL_KERN = 1;
pub const CTL_DEBUG = 5;

pub const KERN_PROC_ARGS = 48; // struct: process argv/env
pub const KERN_PROC_PATHNAME = 5; // path to executable

pub const PATH_MAX = 1024;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const PROT_NONE = 0;
pub const PROT_READ = 1;
pub const PROT_WRITE = 2;
pub const PROT_EXEC = 4;

pub const CLOCK_REALTIME = 0;
pub const CLOCK_VIRTUAL = 1;
pub const CLOCK_PROF = 2;
pub const CLOCK_MONOTONIC = 3;
pub const CLOCK_THREAD_CPUTIME_ID = 0x20000000;
pub const CLOCK_PROCESS_CPUTIME_ID = 0x40000000;

pub const MAP_FAILED = maxInt(usize);
pub const MAP_SHARED = 0x0001;
pub const MAP_PRIVATE = 0x0002;
pub const MAP_REMAPDUP = 0x0004;
pub const MAP_FIXED = 0x0010;
pub const MAP_RENAME = 0x0020;
pub const MAP_NORESERVE = 0x0040;
pub const MAP_INHERIT = 0x0080;
pub const MAP_HASSEMAPHORE = 0x0200;
pub const MAP_TRYFIXED = 0x0400;
pub const MAP_WIRED = 0x0800;

pub const MAP_FILE = 0x0000;
pub const MAP_NOSYNC = 0x0800;
pub const MAP_ANON = 0x1000;
pub const MAP_ANONYMOUS = MAP_ANON;
pub const MAP_STACK = 0x2000;

pub const WNOHANG = 0x00000001;
pub const WUNTRACED = 0x00000002;
pub const WSTOPPED = WUNTRACED;
pub const WCONTINUED = 0x00000010;
pub const WNOWAIT = 0x00010000;
pub const WEXITED = 0x00000020;
pub const WTRAPPED = 0x00000040;

pub const SA_ONSTACK = 0x0001;
pub const SA_RESTART = 0x0002;
pub const SA_RESETHAND = 0x0004;
pub const SA_NOCLDSTOP = 0x0008;
pub const SA_NODEFER = 0x0010;
pub const SA_NOCLDWAIT = 0x0020;
pub const SA_SIGINFO = 0x0040;

pub const SIGHUP = 1;
pub const SIGINT = 2;
pub const SIGQUIT = 3;
pub const SIGILL = 4;
pub const SIGTRAP = 5;
pub const SIGABRT = 6;
pub const SIGIOT = SIGABRT;
pub const SIGEMT = 7;
pub const SIGFPE = 8;
pub const SIGKILL = 9;
pub const SIGBUS = 10;
pub const SIGSEGV = 11;
pub const SIGSYS = 12;
pub const SIGPIPE = 13;
pub const SIGALRM = 14;
pub const SIGTERM = 15;
pub const SIGURG = 16;
pub const SIGSTOP = 17;
pub const SIGTSTP = 18;
pub const SIGCONT = 19;
pub const SIGCHLD = 20;
pub const SIGTTIN = 21;
pub const SIGTTOU = 22;
pub const SIGIO = 23;
pub const SIGXCPU = 24;
pub const SIGXFSZ = 25;
pub const SIGVTALRM = 26;
pub const SIGPROF = 27;
pub const SIGWINCH = 28;
pub const SIGINFO = 29;
pub const SIGUSR1 = 30;
pub const SIGUSR2 = 31;
pub const SIGPWR = 32;

pub const SIGRTMIN = 33;
pub const SIGRTMAX = 63;

// access function
pub const F_OK = 0; // test for existence of file
pub const X_OK = 1; // test for execute or search permission
pub const W_OK = 2; // test for write permission
pub const R_OK = 4; // test for read permission


pub const O_RDONLY = 0x0000;
pub const O_WRONLY = 0x0001;
pub const O_RDWR = 0x0002;
pub const O_ACCMODE = 0x0003;

pub const O_CREAT = 0x0200;
pub const O_EXCL = 0x0800;
pub const O_NOCTTY = 0x8000;
pub const O_TRUNC = 0x0400;
pub const O_APPEND = 0x0008;
pub const O_NONBLOCK = 0x0004;
pub const O_DSYNC = 0x00010000;
pub const O_SYNC = 0x0080;
pub const O_RSYNC = 0x00020000;
pub const O_DIRECTORY = 0x00080000;
pub const O_NOFOLLOW = 0x00000100;
pub const O_CLOEXEC = 0x00400000;

pub const O_ASYNC = 0x0040;
pub const O_DIRECT = 0x00080000;
pub const O_LARGEFILE = 0;
pub const O_NOATIME = 0;
pub const O_PATH = 0;
pub const O_TMPFILE = 0;
pub const O_NDELAY = O_NONBLOCK;

pub const F_DUPFD = 0;
pub const F_GETFD = 1;
pub const F_SETFD = 2;
pub const F_GETFL = 3;
pub const F_SETFL = 4;

pub const F_GETOWN = 5;
pub const F_SETOWN = 6;

pub const F_GETLK = 7;
pub const F_SETLK = 8;
pub const F_SETLKW = 9;

pub const SEEK_SET = 0;
pub const SEEK_CUR = 1;
pub const SEEK_END = 2;

pub const SIG_BLOCK = 1;
pub const SIG_UNBLOCK = 2;
pub const SIG_SETMASK = 3;

pub const SOCK_STREAM = 1;
pub const SOCK_DGRAM = 2;
pub const SOCK_RAW = 3;
pub const SOCK_RDM = 4;
pub const SOCK_SEQPACKET = 5;

pub const SOCK_CLOEXEC = 0x10000000;
pub const SOCK_NONBLOCK = 0x20000000;

pub const PROTO_ip = 0;
pub const PROTO_icmp = 1;
pub const PROTO_igmp = 2;
pub const PROTO_ggp = 3;
pub const PROTO_ipencap = 4;
pub const PROTO_tcp = 6;
pub const PROTO_egp = 8;
pub const PROTO_pup = 12;
pub const PROTO_udp = 17;
pub const PROTO_xns_idp = 22;
pub const PROTO_iso_tp4 = 29;
pub const PROTO_ipv6 = 41;
pub const PROTO_ipv6_route = 43;
pub const PROTO_ipv6_frag = 44;
pub const PROTO_rsvp = 46;
pub const PROTO_gre = 47;
pub const PROTO_esp = 50;
pub const PROTO_ah = 51;
pub const PROTO_ipv6_icmp = 58;
pub const PROTO_ipv6_nonxt = 59;
pub const PROTO_ipv6_opts = 60;
pub const PROTO_encap = 98;
pub const PROTO_pim = 103;
pub const PROTO_raw = 255;

pub const PF_UNSPEC = 0;
pub const PF_LOCAL = 1;
pub const PF_UNIX = PF_LOCAL;
pub const PF_FILE = PF_LOCAL;
pub const PF_INET = 2;
pub const PF_APPLETALK = 16;
pub const PF_INET6 = 24;
pub const PF_DECnet = 12;
pub const PF_KEY = 29;
pub const PF_ROUTE = 34;
pub const PF_SNA = 11;
pub const PF_MPLS = 33;
pub const PF_CAN = 35;
pub const PF_BLUETOOTH = 31;
pub const PF_ISDN = 26;
pub const PF_MAX = 37;

pub const AF_UNSPEC = PF_UNSPEC;
pub const AF_LOCAL = PF_LOCAL;
pub const AF_UNIX = AF_LOCAL;
pub const AF_FILE = AF_LOCAL;
pub const AF_INET = PF_INET;
pub const AF_APPLETALK = PF_APPLETALK;
pub const AF_INET6 = PF_INET6;
pub const AF_KEY = PF_KEY;
pub const AF_ROUTE = PF_ROUTE;
pub const AF_SNA = PF_SNA;
pub const AF_MPLS = PF_MPLS;
pub const AF_CAN = PF_CAN;
pub const AF_BLUETOOTH = PF_BLUETOOTH;
pub const AF_ISDN = PF_ISDN;
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

/// add event to kq (implies enable)
pub const EV_ADD = 0x0001;

/// delete event from kq
pub const EV_DELETE = 0x0002;

/// enable event
pub const EV_ENABLE = 0x0004;

/// disable event (not reported)
pub const EV_DISABLE = 0x0008;

/// only report one occurrence
pub const EV_ONESHOT = 0x0010;

/// clear event state after reporting
pub const EV_CLEAR = 0x0020;

/// force immediate event output
/// ... with or without EV_ERROR
/// ... use KEVENT_FLAG_ERROR_EVENTS
///     on syscalls supporting flags
pub const EV_RECEIPT = 0x0040;

/// disable event after reporting
pub const EV_DISPATCH = 0x0080;

pub const EVFILT_READ = 0;
pub const EVFILT_WRITE = 1;

/// attached to aio requests
pub const EVFILT_AIO = 2;

/// attached to vnodes
pub const EVFILT_VNODE = 3;

/// attached to struct proc
pub const EVFILT_PROC = 4;

/// attached to struct proc
pub const EVFILT_SIGNAL = 5;

/// timers
pub const EVFILT_TIMER = 6;

/// Filesystem events
pub const EVFILT_FS = 7;

/// XXX no EVFILT_USER, but what is it
pub const EVFILT_USER = 0;

/// On input, NOTE_TRIGGER causes the event to be triggered for output.
pub const NOTE_TRIGGER = 0x08000000;

/// low water mark
pub const NOTE_LOWAT = 0x00000001;

/// vnode was removed
pub const NOTE_DELETE = 0x00000001;

/// data contents changed
pub const NOTE_WRITE = 0x00000002;

/// size increased
pub const NOTE_EXTEND = 0x00000004;

/// attributes changed
pub const NOTE_ATTRIB = 0x00000008;

/// link count changed
pub const NOTE_LINK = 0x00000010;

/// vnode was renamed
pub const NOTE_RENAME = 0x00000020;

/// vnode access was revoked
pub const NOTE_REVOKE = 0x00000040;

/// process exited
pub const NOTE_EXIT = 0x80000000;

/// process forked
pub const NOTE_FORK = 0x40000000;

/// process exec'd
pub const NOTE_EXEC = 0x20000000;

/// mask for signal & exit status
pub const NOTE_PDATAMASK = 0x000fffff;
pub const NOTE_PCTRLMASK = 0xf0000000;

pub const TIOCCBRK = 0x2000747a;
pub const TIOCCDTR = 0x20007478;
pub const TIOCCONS = 0x80047462;
pub const TIOCDCDTIMESTAMP = 0x40107458;
pub const TIOCDRAIN = 0x2000745e;
pub const TIOCEXCL = 0x2000740d;
pub const TIOCEXT = 0x80047460;
pub const TIOCFLAG_CDTRCTS = 0x10;
pub const TIOCFLAG_CLOCAL = 0x2;
pub const TIOCFLAG_CRTSCTS = 0x4;
pub const TIOCFLAG_MDMBUF = 0x8;
pub const TIOCFLAG_SOFTCAR = 0x1;
pub const TIOCFLUSH = 0x80047410;
pub const TIOCGETA = 0x402c7413;
pub const TIOCGETD = 0x4004741a;
pub const TIOCGFLAGS = 0x4004745d;
pub const TIOCGLINED = 0x40207442;
pub const TIOCGPGRP = 0x40047477;
pub const TIOCGQSIZE = 0x40047481;
pub const TIOCGRANTPT = 0x20007447;
pub const TIOCGSID = 0x40047463;
pub const TIOCGSIZE = 0x40087468;
pub const TIOCGWINSZ = 0x40087468;
pub const TIOCMBIC = 0x8004746b;
pub const TIOCMBIS = 0x8004746c;
pub const TIOCMGET = 0x4004746a;
pub const TIOCMSET = 0x8004746d;
pub const TIOCM_CAR = 0x40;
pub const TIOCM_CD = 0x40;
pub const TIOCM_CTS = 0x20;
pub const TIOCM_DSR = 0x100;
pub const TIOCM_DTR = 0x2;
pub const TIOCM_LE = 0x1;
pub const TIOCM_RI = 0x80;
pub const TIOCM_RNG = 0x80;
pub const TIOCM_RTS = 0x4;
pub const TIOCM_SR = 0x10;
pub const TIOCM_ST = 0x8;
pub const TIOCNOTTY = 0x20007471;
pub const TIOCNXCL = 0x2000740e;
pub const TIOCOUTQ = 0x40047473;
pub const TIOCPKT = 0x80047470;
pub const TIOCPKT_DATA = 0x0;
pub const TIOCPKT_DOSTOP = 0x20;
pub const TIOCPKT_FLUSHREAD = 0x1;
pub const TIOCPKT_FLUSHWRITE = 0x2;
pub const TIOCPKT_IOCTL = 0x40;
pub const TIOCPKT_NOSTOP = 0x10;
pub const TIOCPKT_START = 0x8;
pub const TIOCPKT_STOP = 0x4;
pub const TIOCPTMGET = 0x40287446;
pub const TIOCPTSNAME = 0x40287448;
pub const TIOCRCVFRAME = 0x80087445;
pub const TIOCREMOTE = 0x80047469;
pub const TIOCSBRK = 0x2000747b;
pub const TIOCSCTTY = 0x20007461;
pub const TIOCSDTR = 0x20007479;
pub const TIOCSETA = 0x802c7414;
pub const TIOCSETAF = 0x802c7416;
pub const TIOCSETAW = 0x802c7415;
pub const TIOCSETD = 0x8004741b;
pub const TIOCSFLAGS = 0x8004745c;
pub const TIOCSIG = 0x2000745f;
pub const TIOCSLINED = 0x80207443;
pub const TIOCSPGRP = 0x80047476;
pub const TIOCSQSIZE = 0x80047480;
pub const TIOCSSIZE = 0x80087467;
pub const TIOCSTART = 0x2000746e;
pub const TIOCSTAT = 0x80047465;
pub const TIOCSTI = 0x80017472;
pub const TIOCSTOP = 0x2000746f;
pub const TIOCSWINSZ = 0x80087467;
pub const TIOCUCNTL = 0x80047466;
pub const TIOCXMTFRAME = 0x80087444;

pub const sockaddr = c.sockaddr;
pub const sockaddr_in = c.sockaddr_in;
pub const sockaddr_in6 = c.sockaddr_in6;

fn unsigned(s: i32) u32 {
    return @bitCast(u32, s);
}
fn signed(s: u32) i32 {
    return @bitCast(i32, s);
}
pub fn WEXITSTATUS(s: i32) i32 {
    return signed((unsigned(s) >> 8) & 0xff);
}
pub fn WTERMSIG(s: i32) i32 {
    return signed(unsigned(s) & 0x7f);
}
pub fn WSTOPSIG(s: i32) i32 {
    return WEXITSTATUS(s);
}
pub fn WIFEXITED(s: i32) bool {
    return WTERMSIG(s) == 0;
}

pub fn WIFCONTINUED(s: i32) bool {
    return ((s & 0x7f) == 0xffff);
}

pub fn WIFSTOPPED(s: i32) bool {
    return ((s & 0x7f != 0x7f) and !WIFCONTINUED(s));
}

pub fn WIFSIGNALED(s: i32) bool {
    return !WIFSTOPPED(s) and !WIFCONTINUED(s) and !WIFEXITED(s);
}

pub const winsize = extern struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

/// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: usize) usize {
    const signed_r = @bitCast(isize, r);
    return if (signed_r > -4096 and signed_r < 0) @intCast(usize, -signed_r) else 0;
}

pub fn dup2(old: i32, new: i32) usize {
    return errnoWrap(c.dup2(old, new));
}

pub fn chdir(path: [*]const u8) usize {
    return errnoWrap(c.chdir(path));
}

pub fn execve(path: [*]const u8, argv: [*]const ?[*]const u8, envp: [*]const ?[*]const u8) usize {
    return errnoWrap(c.execve(path, argv, envp));
}

pub fn fork() usize {
    return errnoWrap(c.fork());
}

pub fn access(path: [*]const u8, mode: u32) usize {
    return errnoWrap(c.access(path, mode));
}

pub fn getcwd(buf: [*]u8, size: usize) usize {
    return if (c.getcwd(buf, size) == null) @bitCast(usize, -isize(c._errno().*)) else 0;
}

pub fn getdents(fd: i32, dirp: [*]u8, count: usize) usize {
    return errnoWrap(@bitCast(isize, c.getdents(fd, drip, count)));
}

pub fn getdirentries(fd: i32, buf_ptr: [*]u8, buf_len: usize, basep: *i64) usize {
    return errnoWrap(@bitCast(isize, c.getdirentries(fd, buf_ptr, buf_len, basep)));
}

pub fn realpath(noalias filename: [*]const u8, noalias resolved_name: [*]u8) usize {
    return if (c.realpath(filename, resolved_name) == null) @bitCast(usize, -isize(c._errno().*)) else 0;
}

pub fn isatty(fd: i32) bool {
    return c.isatty(fd) != 0;
}

pub fn readlink(noalias path: [*]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    return errnoWrap(c.readlink(path, buf_ptr, buf_len));
}

pub fn mkdir(path: [*]const u8, mode: u32) usize {
    return errnoWrap(c.mkdir(path, mode));
}

pub fn mmap(address: ?[*]u8, length: usize, prot: usize, flags: u32, fd: i32, offset: isize) usize {
    const ptr_result = c.mmap(
        @ptrCast(?*c_void, address),
        length,
        @bitCast(c_int, @intCast(c_uint, prot)),
        @bitCast(c_int, c_uint(flags)),
        fd,
        offset,
    );
    const isize_result = @bitCast(isize, @ptrToInt(ptr_result));
    return errnoWrap(isize_result);
}

pub fn munmap(address: usize, length: usize) usize {
    return errnoWrap(c.munmap(@intToPtr(*c_void, address), length));
}

pub fn read(fd: i32, buf: [*]u8, nbyte: usize) usize {
    return errnoWrap(c.read(fd, @ptrCast(*c_void, buf), nbyte));
}

pub fn rmdir(path: [*]const u8) usize {
    return errnoWrap(c.rmdir(path));
}

pub fn symlink(existing: [*]const u8, new: [*]const u8) usize {
    return errnoWrap(c.symlink(existing, new));
}

pub fn pread(fd: i32, buf: [*]u8, nbyte: usize, offset: u64) usize {
    return errnoWrap(c.pread(fd, @ptrCast(*c_void, buf), nbyte, offset));
}

pub fn preadv(fd: i32, iov: [*]const iovec, count: usize, offset: usize) usize {
    return errnoWrap(c.preadv(fd, @ptrCast(*const c_void, iov), @intCast(c_int, count), offset));
}

pub fn pipe(fd: *[2]i32) usize {
    return pipe2(fd, 0);
}

pub fn pipe2(fd: *[2]i32, flags: u32) usize {
    comptime assert(i32.bit_count == c_int.bit_count);
    return errnoWrap(c.pipe2(@ptrCast(*[2]c_int, fd), flags));
}

pub fn write(fd: i32, buf: [*]const u8, nbyte: usize) usize {
    return errnoWrap(c.write(fd, @ptrCast(*const c_void, buf), nbyte));
}

pub fn pwrite(fd: i32, buf: [*]const u8, nbyte: usize, offset: u64) usize {
    return errnoWrap(c.pwrite(fd, @ptrCast(*const c_void, buf), nbyte, offset));
}

pub fn pwritev(fd: i32, iov: [*]const iovec_const, count: usize, offset: usize) usize {
    return errnoWrap(c.pwritev(fd, @ptrCast(*const c_void, iov), @intCast(c_int, count), offset));
}

pub fn rename(old: [*]const u8, new: [*]const u8) usize {
    return errnoWrap(c.rename(old, new));
}

pub fn open(path: [*]const u8, flags: u32, mode: usize) usize {
    return errnoWrap(c.open(path, @bitCast(c_int, flags), mode));
}

pub fn create(path: [*]const u8, perm: usize) usize {
    return arch.syscall2(SYS_creat, @ptrToInt(path), perm);
}

pub fn openat(dirfd: i32, path: [*]const u8, flags: usize, mode: usize) usize {
    return errnoWrap(c.openat(@bitCast(usize, isize(dirfd)), @ptrToInt(path), flags, mode));
}

pub fn close(fd: i32) usize {
    return errnoWrap(c.close(fd));
}

pub fn lseek(fd: i32, offset: isize, whence: c_int) usize {
    return errnoWrap(c.lseek(fd, offset, whence));
}

pub fn exit(code: i32) noreturn {
    c.exit(code);
}

pub fn kill(pid: i32, sig: i32) usize {
    return errnoWrap(c.kill(pid, sig));
}

pub fn unlink(path: [*]const u8) usize {
    return errnoWrap(c.unlink(path));
}

pub fn waitpid(pid: i32, status: *i32, options: u32) usize {
    comptime assert(i32.bit_count == c_int.bit_count);
    return errnoWrap(c.waitpid(pid, @ptrCast(*c_int, status), @bitCast(c_int, options)));
}

pub fn nanosleep(req: *const timespec, rem: ?*timespec) usize {
    return errnoWrap(c.nanosleep(req, rem));
}

pub fn clock_gettime(clk_id: i32, tp: *timespec) usize {
    return errnoWrap(c.clock_gettime(clk_id, tp));
}

pub fn clock_getres(clk_id: i32, tp: *timespec) usize {
    return errnoWrap(c.clock_getres(clk_id, tp));
}

pub fn setuid(uid: u32) usize {
    return errnoWrap(c.setuid(uid));
}

pub fn setgid(gid: u32) usize {
    return errnoWrap(c.setgid(gid));
}

pub fn setreuid(ruid: u32, euid: u32) usize {
    return errnoWrap(c.setreuid(ruid, euid));
}

pub fn setregid(rgid: u32, egid: u32) usize {
    return errnoWrap(c.setregid(rgid, egid));
}

const NSIG = 32;

pub const SIG_ERR = @intToPtr(extern fn (i32) void, maxInt(usize));
pub const SIG_DFL = @intToPtr(extern fn (i32) void, 0);
pub const SIG_IGN = @intToPtr(extern fn (i32) void, 1);

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = extern struct {
    /// signal handler
    __sigaction_u: extern union {
        __sa_handler: extern fn (i32) void,
        __sa_sigaction: extern fn (i32, *__siginfo, usize) void,
    },

    /// see signal options
    sa_flags: u32,

    /// signal mask to apply
    sa_mask: sigset_t,
};

pub const _SIG_WORDS = 4;
pub const _SIG_MAXSIG = 128;

pub inline fn _SIG_IDX(sig: usize) usize {
    return sig - 1;
}
pub inline fn _SIG_WORD(sig: usize) usize {
    return_SIG_IDX(sig) >> 5;
}
pub inline fn _SIG_BIT(sig: usize) usize {
    return 1 << (_SIG_IDX(sig) & 31);
}
pub inline fn _SIG_VALID(sig: usize) usize {
    return sig <= _SIG_MAXSIG and sig > 0;
}

pub const sigset_t = extern struct {
    __bits: [_SIG_WORDS]u32,
};

pub fn raise(sig: i32) usize {
    return errnoWrap(c.raise(sig));
}

pub const Stat = c.Stat;
pub const dirent = c.dirent;
pub const timespec = c.timespec;

pub fn fstat(fd: i32, buf: *c.Stat) usize {
    return errnoWrap(c.fstat(fd, buf));
}
pub const iovec = extern struct {
    iov_base: [*]u8,
    iov_len: usize,
};

pub const iovec_const = extern struct {
    iov_base: [*]const u8,
    iov_len: usize,
};

// TODO avoid libc dependency
pub fn kqueue() usize {
    return errnoWrap(c.kqueue());
}

// TODO avoid libc dependency
pub fn kevent(kq: i32, changelist: []const Kevent, eventlist: []Kevent, timeout: ?*const timespec) usize {
    return errnoWrap(c.kevent(
        kq,
        changelist.ptr,
        @intCast(c_int, changelist.len),
        eventlist.ptr,
        @intCast(c_int, eventlist.len),
        timeout,
    ));
}

// TODO avoid libc dependency
pub fn sysctl(name: [*]c_int, namelen: c_uint, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) usize {
    return errnoWrap(c.sysctl(name, namelen, oldp, oldlenp, newp, newlen));
}

// TODO avoid libc dependency
pub fn sysctlbyname(name: [*]const u8, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) usize {
    return errnoWrap(c.sysctlbyname(name, oldp, oldlenp, newp, newlen));
}

// TODO avoid libc dependency
pub fn sysctlnametomib(name: [*]const u8, mibp: ?*c_int, sizep: ?*usize) usize {
    return errnoWrap(c.sysctlnametomib(name, wibp, sizep));
}

// TODO avoid libc dependency

/// Takes the return value from a syscall and formats it back in the way
/// that the kernel represents it to libc. Errno was a mistake, let's make
/// it go away forever.
fn errnoWrap(value: isize) usize {
    return @bitCast(usize, if (value == -1) -isize(c._errno().*) else value);
}
