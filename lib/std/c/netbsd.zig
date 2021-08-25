const std = @import("../std.zig");
const builtin = @import("builtin");
const maxInt = std.math.maxInt;

usingnamespace std.c;

extern "c" fn __errno() *c_int;
pub const _errno = __errno;

pub const dl_iterate_phdr_callback = fn (info: *dl_phdr_info, size: usize, data: ?*c_void) callconv(.C) c_int;
pub extern "c" fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*c_void) c_int;

pub extern "c" fn _lwp_self() lwpid_t;

pub extern "c" fn pipe2(fds: *[2]fd_t, flags: u32) c_int;
pub extern "c" fn arc4random_buf(buf: [*]u8, len: usize) void;
pub extern "c" fn __fstat50(fd: fd_t, buf: *Stat) c_int;
pub extern "c" fn __stat50(path: [*:0]const u8, buf: *Stat) c_int;
pub extern "c" fn __clock_gettime50(clk_id: c_int, tp: *timespec) c_int;
pub extern "c" fn __clock_getres50(clk_id: c_int, tp: *timespec) c_int;
pub extern "c" fn __getdents30(fd: c_int, buf_ptr: [*]u8, nbytes: usize) c_int;
pub extern "c" fn __sigaltstack14(ss: ?*stack_t, old_ss: ?*stack_t) c_int;
pub extern "c" fn __nanosleep50(rqtp: *const timespec, rmtp: ?*timespec) c_int;
pub extern "c" fn __sigaction14(sig: c_int, noalias act: ?*const Sigaction, noalias oact: ?*Sigaction) c_int;
pub extern "c" fn __sigprocmask14(how: c_int, noalias set: ?*const sigset_t, noalias oset: ?*sigset_t) c_int;
pub extern "c" fn __socket30(domain: c_uint, sock_type: c_uint, protocol: c_uint) c_int;
pub extern "c" fn __gettimeofday50(noalias tv: ?*timeval, noalias tz: ?*timezone) c_int;
pub extern "c" fn __getrusage50(who: c_int, usage: *rusage) c_int;
// libc aliases this as sched_yield
pub extern "c" fn __libc_thr_yield() c_int;

pub extern "c" fn posix_memalign(memptr: *?*c_void, alignment: usize, size: usize) c_int;

pub const pthread_mutex_t = extern struct {
    ptm_magic: u32 = 0x33330003,
    ptm_errorcheck: padded_pthread_spin_t = 0,
    ptm_ceiling: padded_pthread_spin_t = 0,
    ptm_owner: usize = 0,
    ptm_waiters: ?*u8 = null,
    ptm_recursed: u32 = 0,
    ptm_spare2: ?*c_void = null,
};

pub const pthread_cond_t = extern struct {
    ptc_magic: u32 = 0x55550005,
    ptc_lock: pthread_spin_t = 0,
    ptc_waiters_first: ?*u8 = null,
    ptc_waiters_last: ?*u8 = null,
    ptc_mutex: ?*pthread_mutex_t = null,
    ptc_private: ?*c_void = null,
};

pub const pthread_rwlock_t = extern struct {
    ptr_magic: c_uint = 0x99990009,
    ptr_interlock: switch (builtin.cpu.arch) {
        .aarch64, .sparc, .x86_64, .i386 => u8,
        .arm, .powerpc => c_int,
        else => unreachable,
    } = 0,
    ptr_rblocked_first: ?*u8 = null,
    ptr_rblocked_last: ?*u8 = null,
    ptr_wblocked_first: ?*u8 = null,
    ptr_wblocked_last: ?*u8 = null,
    ptr_nreaders: c_uint = 0,
    ptr_owner: std.c.pthread_t = null,
    ptr_private: ?*c_void = null,
};

const pthread_spin_t = switch (builtin.cpu.arch) {
    .aarch64, .aarch64_be, .aarch64_32 => u8,
    .mips, .mipsel, .mips64, .mips64el => u32,
    .powerpc, .powerpc64, .powerpc64le => i32,
    .i386, .x86_64 => u8,
    .arm, .armeb, .thumb, .thumbeb => i32,
    .sparc, .sparcel, .sparcv9 => u8,
    .riscv32, .riscv64 => u32,
    else => @compileError("undefined pthread_spin_t for this arch"),
};

const padded_pthread_spin_t = switch (builtin.cpu.arch) {
    .i386, .x86_64 => u32,
    .sparc, .sparcel, .sparcv9 => u32,
    else => pthread_spin_t,
};

pub const pthread_attr_t = extern struct {
    pta_magic: u32,
    pta_flags: i32,
    pta_private: ?*c_void,
};

pub const sem_t = ?*opaque {};

pub extern "c" fn pthread_setname_np(thread: std.c.pthread_t, name: [*:0]const u8, arg: ?*c_void) E;
pub extern "c" fn pthread_getname_np(thread: std.c.pthread_t, name: [*:0]u8, len: usize) E;

pub const clock_getres = __clock_getres50;
pub const clock_gettime = __clock_gettime50;
pub const fstat = __fstat50;
pub const getdents = __getdents30;
pub const getrusage = __getrusage50;
pub const gettimeofday = __gettimeofday50;
pub const nanosleep = __nanosleep50;
pub const sched_yield = __libc_thr_yield;
pub const sigaction = __sigaction14;
pub const sigaltstack = __sigaltstack14;
pub const sigprocmask = __sigprocmask14;
pub const socket = __socket30;
pub const stat = __stat50;

pub const blkcnt_t = i64;
pub const blksize_t = i32;
pub const clock_t = u32;
pub const dev_t = u64;
pub const fd_t = i32;
pub const gid_t = u32;
pub const ino_t = u64;
pub const mode_t = u32;
pub const nlink_t = u32;
pub const off_t = i64;
pub const pid_t = i32;
pub const socklen_t = u32;
pub const time_t = i64;
pub const uid_t = u32;
pub const lwpid_t = i32;
pub const suseconds_t = c_int;

/// Renamed from `kevent` to `Kevent` to avoid conflict with function name.
pub const Kevent = extern struct {
    ident: usize,
    filter: i32,
    flags: u32,
    fflags: u32,
    data: i64,
    udata: usize,
};

pub const RTLD = struct {
    pub const LAZY = 1;
    pub const NOW = 2;
    pub const GLOBAL = 0x100;
    pub const LOCAL = 0x200;
    pub const NODELETE = 0x01000;
    pub const NOLOAD = 0x02000;

    pub const NEXT = @intToPtr(*c_void, @bitCast(usize, @as(isize, -1)));
    pub const DEFAULT = @intToPtr(*c_void, @bitCast(usize, @as(isize, -2)));
    pub const SELF = @intToPtr(*c_void, @bitCast(usize, @as(isize, -3)));
};

pub const dl_phdr_info = extern struct {
    dlpi_addr: usize,
    dlpi_name: ?[*:0]const u8,
    dlpi_phdr: [*]std.elf.Phdr,
    dlpi_phnum: u16,
};

pub const Flock = extern struct {
    l_start: off_t,
    l_len: off_t,
    l_pid: pid_t,
    l_type: i16,
    l_whence: i16,
};

pub const addrinfo = extern struct {
    flags: i32,
    family: i32,
    socktype: i32,
    protocol: i32,
    addrlen: socklen_t,
    canonname: ?[*:0]u8,
    addr: ?*sockaddr,
    next: ?*addrinfo,
};

pub const EAI = enum(c_int) {
    /// address family for hostname not supported
    ADDRFAMILY = 1,

    /// name could not be resolved at this time
    AGAIN = 2,

    /// flags parameter had an invalid value
    BADFLAGS = 3,

    /// non-recoverable failure in name resolution
    FAIL = 4,

    /// address family not recognized
    FAMILY = 5,

    /// memory allocation failure
    MEMORY = 6,

    /// no address associated with hostname
    NODATA = 7,

    /// name does not resolve
    NONAME = 8,

    /// service not recognized for socket type
    SERVICE = 9,

    /// intended socket type was not recognized
    SOCKTYPE = 10,

    /// system error returned in errno
    SYSTEM = 11,

    /// invalid value for hints
    BADHINTS = 12,

    /// resolved protocol is unknown
    PROTOCOL = 13,

    /// argument buffer overflow
    OVERFLOW = 14,

    _,
};

pub const EAI_MAX = 15;

pub const msghdr = extern struct {
    /// optional address
    msg_name: ?*sockaddr,

    /// size of address
    msg_namelen: socklen_t,

    /// scatter/gather array
    msg_iov: [*]iovec,

    /// # elements in msg_iov
    msg_iovlen: i32,

    /// ancillary data
    msg_control: ?*c_void,

    /// ancillary data buffer len
    msg_controllen: socklen_t,

    /// flags on received message
    msg_flags: i32,
};

pub const msghdr_const = extern struct {
    /// optional address
    msg_name: ?*const sockaddr,

    /// size of address
    msg_namelen: socklen_t,

    /// scatter/gather array
    msg_iov: [*]iovec_const,

    /// # elements in msg_iov
    msg_iovlen: i32,

    /// ancillary data
    msg_control: ?*c_void,

    /// ancillary data buffer len
    msg_controllen: socklen_t,

    /// flags on received message
    msg_flags: i32,
};

/// The stat structure used by libc.
pub const Stat = extern struct {
    dev: dev_t,
    mode: mode_t,
    ino: ino_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    birthtim: timespec,
    size: off_t,
    blocks: blkcnt_t,
    blksize: blksize_t,
    flags: u32,
    gen: u32,
    __spare: [2]u32,

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

pub const timespec = extern struct {
    tv_sec: i64,
    tv_nsec: isize,
};

pub const timeval = extern struct {
    /// seconds
    tv_sec: time_t,
    /// microseconds
    tv_usec: suseconds_t,
};

pub const MAXNAMLEN = 511;

pub const dirent = extern struct {
    d_fileno: ino_t,
    d_reclen: u16,
    d_namlen: u16,
    d_type: u8,
    d_name: [MAXNAMLEN:0]u8,

    pub fn reclen(self: dirent) u16 {
        return self.d_reclen;
    }
};

pub const SOCK = struct {
    pub const STREAM = 1;
    pub const DGRAM = 2;
    pub const RAW = 3;
    pub const RDM = 4;
    pub const SEQPACKET = 5;
    pub const CONN_DGRAM = 6;
    pub const DCCP = CONN_DGRAM;

    pub const CLOEXEC = 0x10000000;
    pub const NONBLOCK = 0x20000000;
    pub const NOSIGPIPE = 0x40000000;
    pub const FLAGS_MASK = 0xf0000000;
};

pub const SO = struct {
    pub const DEBUG = 0x0001;
    pub const ACCEPTCONN = 0x0002;
    pub const REUSEADDR = 0x0004;
    pub const KEEPALIVE = 0x0008;
    pub const DONTROUTE = 0x0010;
    pub const BROADCAST = 0x0020;
    pub const USELOOPBACK = 0x0040;
    pub const LINGER = 0x0080;
    pub const OOBINLINE = 0x0100;
    pub const REUSEPORT = 0x0200;
    pub const NOSIGPIPE = 0x0800;
    pub const ACCEPTFILTER = 0x1000;
    pub const TIMESTAMP = 0x2000;
    pub const RERROR = 0x4000;

    pub const SNDBUF = 0x1001;
    pub const RCVBUF = 0x1002;
    pub const SNDLOWAT = 0x1003;
    pub const RCVLOWAT = 0x1004;
    pub const ERROR = 0x1007;
    pub const TYPE = 0x1008;
    pub const OVERFLOWED = 0x1009;

    pub const NOHEADER = 0x100a;
    pub const SNDTIMEO = 0x100b;
    pub const RCVTIMEO = 0x100c;
};

pub const SOL = struct {
    pub const SOCKET = 0xffff;
};

pub const PF = struct {
    pub const UNSPEC = AF.UNSPEC;
    pub const LOCAL = AF.LOCAL;
    pub const UNIX = PF.LOCAL;
    pub const INET = AF.INET;
    pub const IMPLINK = AF.IMPLINK;
    pub const PUP = AF.PUP;
    pub const CHAOS = AF.CHAOS;
    pub const NS = AF.NS;
    pub const ISO = AF.ISO;
    pub const OSI = AF.ISO;
    pub const ECMA = AF.ECMA;
    pub const DATAKIT = AF.DATAKIT;
    pub const CCITT = AF.CCITT;
    pub const SNA = AF.SNA;
    pub const DECnet = AF.DECnet;
    pub const DLI = AF.DLI;
    pub const LAT = AF.LAT;
    pub const HYLINK = AF.HYLINK;
    pub const APPLETALK = AF.APPLETALK;
    pub const OROUTE = AF.OROUTE;
    pub const LINK = AF.LINK;
    pub const COIP = AF.COIP;
    pub const CNT = AF.CNT;
    pub const INET6 = AF.INET6;
    pub const IPX = AF.IPX;
    pub const ISDN = AF.ISDN;
    pub const E164 = AF.E164;
    pub const NATM = AF.NATM;
    pub const ARP = AF.ARP;
    pub const BLUETOOTH = AF.BLUETOOTH;
    pub const MPLS = AF.MPLS;
    pub const ROUTE = AF.ROUTE;
    pub const CAN = AF.CAN;
    pub const ETHER = AF.ETHER;
    pub const MAX = AF.MAX;
};

pub const AF = struct {
    pub const UNSPEC = 0;
    pub const LOCAL = 1;
    pub const UNIX = LOCAL;
    pub const INET = 2;
    pub const IMPLINK = 3;
    pub const PUP = 4;
    pub const CHAOS = 5;
    pub const NS = 6;
    pub const ISO = 7;
    pub const OSI = ISO;
    pub const ECMA = 8;
    pub const DATAKIT = 9;
    pub const CCITT = 10;
    pub const SNA = 11;
    pub const DECnet = 12;
    pub const DLI = 13;
    pub const LAT = 14;
    pub const HYLINK = 15;
    pub const APPLETALK = 16;
    pub const OROUTE = 17;
    pub const LINK = 18;
    pub const COIP = 20;
    pub const CNT = 21;
    pub const IPX = 23;
    pub const INET6 = 24;
    pub const ISDN = 26;
    pub const E164 = ISDN;
    pub const NATM = 27;
    pub const ARP = 28;
    pub const BLUETOOTH = 31;
    pub const IEEE80211 = 32;
    pub const MPLS = 33;
    pub const ROUTE = 34;
    pub const CAN = 35;
    pub const ETHER = 36;
    pub const MAX = 37;
};

pub const in_port_t = u16;
pub const sa_family_t = u8;

pub const sockaddr = extern struct {
    /// total length
    len: u8,
    /// address family
    family: sa_family_t,
    /// actually longer; address value
    data: [14]u8,

    pub const storage = std.x.os.Socket.Address.Native.Storage;

    pub const in = extern struct {
        len: u8 = @sizeOf(in),
        family: sa_family_t = AF.INET,
        port: in_port_t,
        addr: u32,
        zero: [8]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
    };

    pub const in6 = extern struct {
        len: u8 = @sizeOf(in6),
        family: sa_family_t = AF.INET6,
        port: in_port_t,
        flowinfo: u32,
        addr: [16]u8,
        scope_id: u32,
    };

    /// Definitions for UNIX IPC domain.
    pub const un = extern struct {
        /// total sockaddr length
        len: u8 = @sizeOf(un),

        family: sa_family_t = AF.LOCAL,

        /// path name
        path: [104]u8,
    };
};

pub const AI = struct {
    /// get address to use bind()
    pub const PASSIVE = 0x00000001;
    /// fill ai_canonname
    pub const CANONNAME = 0x00000002;
    /// prevent host name resolution
    pub const NUMERICHOST = 0x00000004;
    /// prevent service name resolution
    pub const NUMERICSERV = 0x00000008;
    /// only if any address is assigned
    pub const ADDRCONFIG = 0x00000400;
};

pub const CTL_KERN = 1;
pub const CTL_DEBUG = 5;

pub const KERN_PROC_ARGS = 48; // struct: process argv/env
pub const KERN_PROC_PATHNAME = 5; // path to executable
pub const KERN_IOV_MAX = 38;

pub const PATH_MAX = 1024;
pub const IOV_MAX = KERN_IOV_MAX;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const PROT_NONE = 0;
pub const PROT_READ = 1;
pub const PROT_WRITE = 2;
pub const PROT_EXEC = 4;

pub const CLOCK = struct {
    pub const REALTIME = 0;
    pub const VIRTUAL = 1;
    pub const PROF = 2;
    pub const MONOTONIC = 3;
    pub const THREAD_CPUTIME_ID = 0x20000000;
    pub const PROCESS_CPUTIME_ID = 0x40000000;
};

pub const MAP = struct {
    pub const FAILED = @intToPtr(*c_void, maxInt(usize));
    pub const SHARED = 0x0001;
    pub const PRIVATE = 0x0002;
    pub const REMAPDUP = 0x0004;
    pub const FIXED = 0x0010;
    pub const RENAME = 0x0020;
    pub const NORESERVE = 0x0040;
    pub const INHERIT = 0x0080;
    pub const HASSEMAPHORE = 0x0200;
    pub const TRYFIXED = 0x0400;
    pub const WIRED = 0x0800;

    pub const FILE = 0x0000;
    pub const NOSYNC = 0x0800;
    pub const ANON = 0x1000;
    pub const ANONYMOUS = ANON;
    pub const STACK = 0x2000;
};
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

/// open for reading only
pub const O_RDONLY = 0x00000000;

/// open for writing only
pub const O_WRONLY = 0x00000001;

/// open for reading and writing
pub const O_RDWR = 0x00000002;

/// mask for above modes
pub const O_ACCMODE = 0x00000003;

/// no delay
pub const O_NONBLOCK = 0x00000004;

/// set append mode
pub const O_APPEND = 0x00000008;

/// open with shared file lock
pub const O_SHLOCK = 0x00000010;

/// open with exclusive file lock
pub const O_EXLOCK = 0x00000020;

/// signal pgrp when data ready
pub const O_ASYNC = 0x00000040;

/// synchronous writes
pub const O_SYNC = 0x00000080;

/// don't follow symlinks on the last
pub const O_NOFOLLOW = 0x00000100;

/// create if nonexistent
pub const O_CREAT = 0x00000200;

/// truncate to zero length
pub const O_TRUNC = 0x00000400;

/// error if already exists
pub const O_EXCL = 0x00000800;

/// don't assign controlling terminal
pub const O_NOCTTY = 0x00008000;

/// write: I/O data completion
pub const O_DSYNC = 0x00010000;

/// read: I/O completion as for write
pub const O_RSYNC = 0x00020000;

/// use alternate i/o semantics
pub const O_ALT_IO = 0x00040000;

/// direct I/O hint
pub const O_DIRECT = 0x00080000;

/// fail if not a directory
pub const O_DIRECTORY = 0x00200000;

/// set close on exec
pub const O_CLOEXEC = 0x00400000;

/// skip search permission checks
pub const O_SEARCH = 0x00800000;

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

pub const F_RDLCK = 1;
pub const F_WRLCK = 3;
pub const F_UNLCK = 2;

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const UN = 8;
    pub const NB = 4;
};

pub const FD_CLOEXEC = 1;

pub const SEEK_SET = 0;
pub const SEEK_CUR = 1;
pub const SEEK_END = 2;

pub const SIG_BLOCK = 1;
pub const SIG_UNBLOCK = 2;
pub const SIG_SETMASK = 3;

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

pub fn WEXITSTATUS(s: u32) u8 {
    return @intCast(u8, (s >> 8) & 0xff);
}
pub fn WTERMSIG(s: u32) u32 {
    return s & 0x7f;
}
pub fn WSTOPSIG(s: u32) u32 {
    return WEXITSTATUS(s);
}
pub fn WIFEXITED(s: u32) bool {
    return WTERMSIG(s) == 0;
}

pub fn WIFCONTINUED(s: u32) bool {
    return ((s & 0x7f) == 0xffff);
}

pub fn WIFSTOPPED(s: u32) bool {
    return ((s & 0x7f != 0x7f) and !WIFCONTINUED(s));
}

pub fn WIFSIGNALED(s: u32) bool {
    return !WIFSTOPPED(s) and !WIFCONTINUED(s) and !WIFEXITED(s);
}

pub const winsize = extern struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

const NSIG = 32;

pub const SIG_DFL = @intToPtr(?Sigaction.sigaction_fn, 0);
pub const SIG_IGN = @intToPtr(?Sigaction.sigaction_fn, 1);
pub const SIG_ERR = @intToPtr(?Sigaction.sigaction_fn, maxInt(usize));

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = extern struct {
    pub const handler_fn = fn (c_int) callconv(.C) void;
    pub const sigaction_fn = fn (c_int, *const siginfo_t, ?*const c_void) callconv(.C) void;

    /// signal handler
    handler: extern union {
        handler: ?handler_fn,
        sigaction: ?sigaction_fn,
    },
    /// signal mask to apply
    mask: sigset_t,
    /// signal options
    flags: c_uint,
};

pub const sigval_t = extern union {
    int: i32,
    ptr: ?*c_void,
};

pub const siginfo_t = extern union {
    pad: [128]u8,
    info: _ksiginfo,
};

pub const _ksiginfo = extern struct {
    signo: i32,
    code: i32,
    errno: i32,
    // 64bit architectures insert 4bytes of padding here, this is done by
    // correctly aligning the reason field
    reason: extern union {
        rt: extern struct {
            pid: pid_t,
            uid: uid_t,
            value: sigval_t,
        },
        child: extern struct {
            pid: pid_t,
            uid: uid_t,
            status: i32,
            utime: clock_t,
            stime: clock_t,
        },
        fault: extern struct {
            addr: ?*c_void,
            trap: i32,
            trap2: i32,
            trap3: i32,
        },
        poll: extern struct {
            band: i32,
            fd: i32,
        },
        syscall: extern struct {
            sysnum: i32,
            retval: [2]i32,
            @"error": i32,
            args: [8]u64,
        },
        ptrace_state: extern struct {
            pe_report_event: i32,
            option: extern union {
                pe_other_pid: pid_t,
                pe_lwp: lwpid_t,
            },
        },
    } align(@sizeOf(usize)),
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

pub const empty_sigset = sigset_t{ .__bits = [_]u32{0} ** _SIG_WORDS };

// XXX x86_64 specific
pub const mcontext_t = extern struct {
    gregs: [26]u64,
    mc_tlsbase: u64,
    fpregs: [512]u8 align(8),
};

pub const REG_RBP = 12;
pub const REG_RIP = 21;
pub const REG_RSP = 24;

pub const ucontext_t = extern struct {
    flags: u32,
    link: ?*ucontext_t,
    sigmask: sigset_t,
    stack: stack_t,
    mcontext: mcontext_t,
    __pad: [
        switch (builtin.cpu.arch) {
            .i386 => 4,
            .mips, .mipsel, .mips64, .mips64el => 14,
            .arm, .armeb, .thumb, .thumbeb => 1,
            .sparc, .sparcel, .sparcv9 => if (@sizeOf(usize) == 4) 43 else 8,
            else => 0,
        }
    ]u32,
};

pub const E = enum(u16) {
    /// No error occurred.
    SUCCESS = 0,
    PERM = 1, // Operation not permitted
    NOENT = 2, // No such file or directory
    SRCH = 3, // No such process
    INTR = 4, // Interrupted system call
    IO = 5, // Input/output error
    NXIO = 6, // Device not configured
    @"2BIG" = 7, // Argument list too long
    NOEXEC = 8, // Exec format error
    BADF = 9, // Bad file descriptor
    CHILD = 10, // No child processes
    DEADLK = 11, // Resource deadlock avoided
    // 11 was AGAIN
    NOMEM = 12, // Cannot allocate memory
    ACCES = 13, // Permission denied
    FAULT = 14, // Bad address
    NOTBLK = 15, // Block device required
    BUSY = 16, // Device busy
    EXIST = 17, // File exists
    XDEV = 18, // Cross-device link
    NODEV = 19, // Operation not supported by device
    NOTDIR = 20, // Not a directory
    ISDIR = 21, // Is a directory
    INVAL = 22, // Invalid argument
    NFILE = 23, // Too many open files in system
    MFILE = 24, // Too many open files
    NOTTY = 25, // Inappropriate ioctl for device
    TXTBSY = 26, // Text file busy
    FBIG = 27, // File too large
    NOSPC = 28, // No space left on device
    SPIPE = 29, // Illegal seek
    ROFS = 30, // Read-only file system
    MLINK = 31, // Too many links
    PIPE = 32, // Broken pipe

    // math software
    DOM = 33, // Numerical argument out of domain
    RANGE = 34, // Result too large or too small

    // non-blocking and interrupt i/o
    // also: WOULDBLOCK: operation would block
    AGAIN = 35, // Resource temporarily unavailable
    INPROGRESS = 36, // Operation now in progress
    ALREADY = 37, // Operation already in progress

    // ipc/network software -- argument errors
    NOTSOCK = 38, // Socket operation on non-socket
    DESTADDRREQ = 39, // Destination address required
    MSGSIZE = 40, // Message too long
    PROTOTYPE = 41, // Protocol wrong type for socket
    NOPROTOOPT = 42, // Protocol option not available
    PROTONOSUPPORT = 43, // Protocol not supported
    SOCKTNOSUPPORT = 44, // Socket type not supported
    OPNOTSUPP = 45, // Operation not supported
    PFNOSUPPORT = 46, // Protocol family not supported
    AFNOSUPPORT = 47, // Address family not supported by protocol family
    ADDRINUSE = 48, // Address already in use
    ADDRNOTAVAIL = 49, // Can't assign requested address

    // ipc/network software -- operational errors
    NETDOWN = 50, // Network is down
    NETUNREACH = 51, // Network is unreachable
    NETRESET = 52, // Network dropped connection on reset
    CONNABORTED = 53, // Software caused connection abort
    CONNRESET = 54, // Connection reset by peer
    NOBUFS = 55, // No buffer space available
    ISCONN = 56, // Socket is already connected
    NOTCONN = 57, // Socket is not connected
    SHUTDOWN = 58, // Can't send after socket shutdown
    TOOMANYREFS = 59, // Too many references: can't splice
    TIMEDOUT = 60, // Operation timed out
    CONNREFUSED = 61, // Connection refused

    LOOP = 62, // Too many levels of symbolic links
    NAMETOOLONG = 63, // File name too long

    // should be rearranged
    HOSTDOWN = 64, // Host is down
    HOSTUNREACH = 65, // No route to host
    NOTEMPTY = 66, // Directory not empty

    // quotas & mush
    PROCLIM = 67, // Too many processes
    USERS = 68, // Too many users
    DQUOT = 69, // Disc quota exceeded

    // Network File System
    STALE = 70, // Stale NFS file handle
    REMOTE = 71, // Too many levels of remote in path
    BADRPC = 72, // RPC struct is bad
    RPCMISMATCH = 73, // RPC version wrong
    PROGUNAVAIL = 74, // RPC prog. not avail
    PROGMISMATCH = 75, // Program version wrong
    PROCUNAVAIL = 76, // Bad procedure for program

    NOLCK = 77, // No locks available
    NOSYS = 78, // Function not implemented

    FTYPE = 79, // Inappropriate file type or format
    AUTH = 80, // Authentication error
    NEEDAUTH = 81, // Need authenticator

    // SystemV IPC
    IDRM = 82, // Identifier removed
    NOMSG = 83, // No message of desired type
    OVERFLOW = 84, // Value too large to be stored in data type

    // Wide/multibyte-character handling, ISO/IEC 9899/AMD1:1995
    ILSEQ = 85, // Illegal byte sequence

    // From IEEE Std 1003.1-2001
    // Base, Realtime, Threads or Thread Priority Scheduling option errors
    NOTSUP = 86, // Not supported

    // Realtime option errors
    CANCELED = 87, // Operation canceled

    // Realtime, XSI STREAMS option errors
    BADMSG = 88, // Bad or Corrupt message

    // XSI STREAMS option errors
    NODATA = 89, // No message available
    NOSR = 90, // No STREAM resources
    NOSTR = 91, // Not a STREAM
    TIME = 92, // STREAM ioctl timeout

    // File system extended attribute errors
    NOATTR = 93, // Attribute not found

    // Realtime, XSI STREAMS option errors
    MULTIHOP = 94, // Multihop attempted
    NOLINK = 95, // Link has been severed
    PROTO = 96, // Protocol error

    _,
};

pub const MINSIGSTKSZ = 8192;
pub const SIGSTKSZ = MINSIGSTKSZ + 32768;

pub const SS_ONSTACK = 1;
pub const SS_DISABLE = 4;

pub const stack_t = extern struct {
    ss_sp: [*]u8,
    ss_size: isize,
    ss_flags: i32,
};

pub const S_IFMT = 0o170000;

pub const S_IFIFO = 0o010000;
pub const S_IFCHR = 0o020000;
pub const S_IFDIR = 0o040000;
pub const S_IFBLK = 0o060000;
pub const S_IFREG = 0o100000;
pub const S_IFLNK = 0o120000;
pub const S_IFSOCK = 0o140000;
pub const S_IFWHT = 0o160000;

pub const S_ISUID = 0o4000;
pub const S_ISGID = 0o2000;
pub const S_ISVTX = 0o1000;
pub const S_IRWXU = 0o700;
pub const S_IRUSR = 0o400;
pub const S_IWUSR = 0o200;
pub const S_IXUSR = 0o100;
pub const S_IRWXG = 0o070;
pub const S_IRGRP = 0o040;
pub const S_IWGRP = 0o020;
pub const S_IXGRP = 0o010;
pub const S_IRWXO = 0o007;
pub const S_IROTH = 0o004;
pub const S_IWOTH = 0o002;
pub const S_IXOTH = 0o001;

pub fn S_ISFIFO(m: u32) bool {
    return m & S_IFMT == S_IFIFO;
}

pub fn S_ISCHR(m: u32) bool {
    return m & S_IFMT == S_IFCHR;
}

pub fn S_ISDIR(m: u32) bool {
    return m & S_IFMT == S_IFDIR;
}

pub fn S_ISBLK(m: u32) bool {
    return m & S_IFMT == S_IFBLK;
}

pub fn S_ISREG(m: u32) bool {
    return m & S_IFMT == S_IFREG;
}

pub fn S_ISLNK(m: u32) bool {
    return m & S_IFMT == S_IFLNK;
}

pub fn S_ISSOCK(m: u32) bool {
    return m & S_IFMT == S_IFSOCK;
}

pub fn S_IWHT(m: u32) bool {
    return m & S_IFMT == S_IFWHT;
}

/// Magic value that specify the use of the current working directory
/// to determine the target of relative file paths in the openat() and
/// similar syscalls.
pub const AT_FDCWD = -100;

/// Check access using effective user and group ID
pub const AT_EACCESS = 0x0100;

/// Do not follow symbolic links
pub const AT_SYMLINK_NOFOLLOW = 0x0200;

/// Follow symbolic link
pub const AT_SYMLINK_FOLLOW = 0x0400;

/// Remove directory instead of file
pub const AT_REMOVEDIR = 0x0800;

pub const HOST_NAME_MAX = 255;

pub const IPPROTO = struct {
    /// dummy for IP
    pub const IP = 0;
    /// IP6 hop-by-hop options
    pub const HOPOPTS = 0;
    /// control message protocol
    pub const ICMP = 1;
    /// group mgmt protocol
    pub const IGMP = 2;
    /// gateway^2 (deprecated)
    pub const GGP = 3;
    /// IP header
    pub const IPV4 = 4;
    /// IP inside IP
    pub const IPIP = 4;
    /// tcp
    pub const TCP = 6;
    /// exterior gateway protocol
    pub const EGP = 8;
    /// pup
    pub const PUP = 12;
    /// user datagram protocol
    pub const UDP = 17;
    /// xns idp
    pub const IDP = 22;
    /// tp-4 w/ class negotiation
    pub const TP = 29;
    /// DCCP
    pub const DCCP = 33;
    /// IP6 header
    pub const IPV6 = 41;
    /// IP6 routing header
    pub const ROUTING = 43;
    /// IP6 fragmentation header
    pub const FRAGMENT = 44;
    /// resource reservation
    pub const RSVP = 46;
    /// GRE encaps RFC 1701
    pub const GRE = 47;
    /// encap. security payload
    pub const ESP = 50;
    /// authentication header
    pub const AH = 51;
    /// IP Mobility RFC 2004
    pub const MOBILE = 55;
    /// IPv6 ICMP
    pub const IPV6_ICMP = 58;
    /// ICMP6
    pub const ICMPV6 = 58;
    /// IP6 no next header
    pub const NONE = 59;
    /// IP6 destination option
    pub const DSTOPTS = 60;
    /// ISO cnlp
    pub const EON = 80;
    /// Ethernet-in-IP
    pub const ETHERIP = 97;
    /// encapsulation header
    pub const ENCAP = 98;
    /// Protocol indep. multicast
    pub const PIM = 103;
    /// IP Payload Comp. Protocol
    pub const IPCOMP = 108;
    /// VRRP RFC 2338
    pub const VRRP = 112;
    /// Common Address Resolution Protocol
    pub const CARP = 112;
    /// L2TPv3
    pub const L2TP = 115;
    /// SCTP
    pub const SCTP = 132;
    /// PFSYNC
    pub const PFSYNC = 240;
    /// raw IP packet
    pub const RAW = 255;
};

pub const rlimit_resource = enum(c_int) {
    CPU = 0,
    FSIZE = 1,
    DATA = 2,
    STACK = 3,
    CORE = 4,
    RSS = 5,
    MEMLOCK = 6,
    NPROC = 7,
    NOFILE = 8,
    SBSIZE = 9,
    VMEM = 10,
    NTHR = 11,
    _,

    pub const AS: rlimit_resource = .VMEM;
};

pub const rlim_t = u64;

pub const RLIM = struct {
    /// No limit
    pub const INFINITY: rlim_t = (1 << 63) - 1;

    pub const SAVED_MAX = INFINITY;
    pub const SAVED_CUR = INFINITY;
};

pub const rlimit = extern struct {
    /// Soft limit
    cur: rlim_t,
    /// Hard limit
    max: rlim_t,
};

pub const SHUT_RD = 0;
pub const SHUT_WR = 1;
pub const SHUT_RDWR = 2;

pub const nfds_t = u32;

pub const pollfd = extern struct {
    fd: fd_t,
    events: i16,
    revents: i16,
};

pub const POLL = struct {
    /// Testable events (may be specified in events field).
    pub const IN = 0x0001;
    pub const PRI = 0x0002;
    pub const OUT = 0x0004;
    pub const RDNORM = 0x0040;
    pub const WRNORM = OUT;
    pub const RDBAND = 0x0080;
    pub const WRBAND = 0x0100;

    /// Non-testable events (may not be specified in events field).
    pub const ERR = 0x0008;
    pub const HUP = 0x0010;
    pub const NVAL = 0x0020;
};
