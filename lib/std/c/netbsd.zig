const std = @import("../std.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;
const iovec = std.os.iovec;
const iovec_const = std.os.iovec_const;
const timezone = std.c.timezone;
const rusage = std.c.rusage;

extern "c" fn __errno() *c_int;
pub const _errno = __errno;

pub const dl_iterate_phdr_callback = *const fn (info: *dl_phdr_info, size: usize, data: ?*anyopaque) callconv(.C) c_int;
pub extern "c" fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*anyopaque) c_int;

pub extern "c" fn _lwp_self() lwpid_t;

pub extern "c" fn pipe2(fds: *[2]fd_t, flags: u32) c_int;
pub extern "c" fn arc4random_buf(buf: [*]u8, len: usize) void;

pub extern "c" fn __fstat50(fd: fd_t, buf: *Stat) c_int;
pub const fstat = __fstat50;

pub extern "c" fn __stat50(path: [*:0]const u8, buf: *Stat) c_int;
pub const stat = __stat50;

pub extern "c" fn __clock_gettime50(clk_id: c_int, tp: *timespec) c_int;
pub const clock_gettime = __clock_gettime50;

pub extern "c" fn __clock_getres50(clk_id: c_int, tp: *timespec) c_int;
pub const clock_getres = __clock_getres50;

pub extern "c" fn __getdents30(fd: c_int, buf_ptr: [*]u8, nbytes: usize) c_int;
pub const getdents = __getdents30;

pub extern "c" fn __sigaltstack14(ss: ?*stack_t, old_ss: ?*stack_t) c_int;
pub const sigaltstack = __sigaltstack14;

pub extern "c" fn __nanosleep50(rqtp: *const timespec, rmtp: ?*timespec) c_int;
pub const nanosleep = __nanosleep50;

pub extern "c" fn __sigaction14(sig: c_int, noalias act: ?*const Sigaction, noalias oact: ?*Sigaction) c_int;
pub const sigaction = __sigaction14;

pub extern "c" fn __sigprocmask14(how: c_int, noalias set: ?*const sigset_t, noalias oset: ?*sigset_t) c_int;
pub const sigprocmask = __sigaction14;

pub extern "c" fn __socket30(domain: c_uint, sock_type: c_uint, protocol: c_uint) c_int;
pub const socket = __socket30;

pub extern "c" fn __gettimeofday50(noalias tv: ?*timeval, noalias tz: ?*timezone) c_int;
pub const gettimeofday = __gettimeofday50;

pub extern "c" fn __getrusage50(who: c_int, usage: *rusage) c_int;
pub const getrusage = __getrusage50;

pub extern "c" fn __libc_thr_yield() c_int;
pub const sched_yield = __libc_thr_yield;

pub extern "c" fn posix_memalign(memptr: *?*anyopaque, alignment: usize, size: usize) c_int;

pub extern "c" fn __msync13(addr: *align(std.mem.page_size) const anyopaque, len: usize, flags: c_int) c_int;
pub const msync = __msync13;

pub const pthread_mutex_t = extern struct {
    magic: u32 = 0x33330003,
    errorcheck: padded_pthread_spin_t = 0,
    ceiling: padded_pthread_spin_t = 0,
    owner: usize = 0,
    waiters: ?*u8 = null,
    recursed: u32 = 0,
    spare2: ?*anyopaque = null,
};

pub const pthread_cond_t = extern struct {
    magic: u32 = 0x55550005,
    lock: pthread_spin_t = 0,
    waiters_first: ?*u8 = null,
    waiters_last: ?*u8 = null,
    mutex: ?*pthread_mutex_t = null,
    private: ?*anyopaque = null,
};

pub const pthread_rwlock_t = extern struct {
    magic: c_uint = 0x99990009,
    interlock: switch (builtin.cpu.arch) {
        .aarch64, .sparc, .x86_64, .x86 => u8,
        .arm, .powerpc => c_int,
        else => unreachable,
    } = 0,
    rblocked_first: ?*u8 = null,
    rblocked_last: ?*u8 = null,
    wblocked_first: ?*u8 = null,
    wblocked_last: ?*u8 = null,
    nreaders: c_uint = 0,
    owner: std.c.pthread_t = null,
    private: ?*anyopaque = null,
};

const pthread_spin_t = switch (builtin.cpu.arch) {
    .aarch64, .aarch64_be, .aarch64_32 => u8,
    .mips, .mipsel, .mips64, .mips64el => u32,
    .powerpc, .powerpc64, .powerpc64le => i32,
    .x86, .x86_64 => u8,
    .arm, .armeb, .thumb, .thumbeb => i32,
    .sparc, .sparcel, .sparc64 => u8,
    .riscv32, .riscv64 => u32,
    else => @compileError("undefined pthread_spin_t for this arch"),
};

const padded_pthread_spin_t = switch (builtin.cpu.arch) {
    .x86, .x86_64 => u32,
    .sparc, .sparcel, .sparc64 => u32,
    else => pthread_spin_t,
};

pub const pthread_attr_t = extern struct {
    pta_magic: u32,
    pta_flags: i32,
    pta_private: ?*anyopaque,
};

pub const sem_t = ?*opaque {};

pub extern "c" fn pthread_setname_np(thread: std.c.pthread_t, name: [*:0]const u8, arg: ?*anyopaque) E;
pub extern "c" fn pthread_getname_np(thread: std.c.pthread_t, name: [*:0]u8, len: usize) E;

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

    pub const NEXT = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));
    pub const DEFAULT = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -2)))));
    pub const SELF = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -3)))));
};

pub const dl_phdr_info = extern struct {
    dlpi_addr: usize,
    dlpi_name: ?[*:0]const u8,
    dlpi_phdr: [*]std.elf.Phdr,
    dlpi_phnum: u16,
};

pub const Flock = extern struct {
    start: off_t,
    len: off_t,
    pid: pid_t,
    type: i16,
    whence: i16,
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
    msg_control: ?*anyopaque,

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
    msg_iov: [*]const iovec_const,

    /// # elements in msg_iov
    msg_iovlen: i32,

    /// ancillary data
    msg_control: ?*const anyopaque,

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

    pub fn birthtime(self: @This()) timespec {
        return self.birthtim;
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
    d_name: [MAXNAMLEN + 1]u8,

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

    pub const SS_MAXSIZE = 128;
    pub const storage = extern struct {
        len: u8 align(8),
        family: sa_family_t,
        padding: [126]u8 = undefined,

        comptime {
            assert(@sizeOf(storage) == SS_MAXSIZE);
            assert(@alignOf(storage) == 8);
        }
    };

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

pub const CTL = struct {
    pub const KERN = 1;
    pub const DEBUG = 5;
};

pub const KERN = struct {
    pub const PROC_ARGS = 48; // struct: process argv/env
    pub const PROC_PATHNAME = 5; // path to executable
    pub const IOV_MAX = 38;
};

pub const PATH_MAX = 1024;
pub const NAME_MAX = 255;
pub const IOV_MAX = KERN.IOV_MAX;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const PROT = struct {
    pub const NONE = 0;
    pub const READ = 1;
    pub const WRITE = 2;
    pub const EXEC = 4;
};

pub const CLOCK = struct {
    pub const REALTIME = 0;
    pub const VIRTUAL = 1;
    pub const PROF = 2;
    pub const MONOTONIC = 3;
    pub const THREAD_CPUTIME_ID = 0x20000000;
    pub const PROCESS_CPUTIME_ID = 0x40000000;
};

pub const MAP = struct {
    pub const FAILED = @as(*anyopaque, @ptrFromInt(maxInt(usize)));
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

pub const MSF = struct {
    pub const ASYNC = 1;
    pub const INVALIDATE = 2;
    pub const SYNC = 4;
};

pub const W = struct {
    pub const NOHANG = 0x00000001;
    pub const UNTRACED = 0x00000002;
    pub const STOPPED = UNTRACED;
    pub const CONTINUED = 0x00000010;
    pub const NOWAIT = 0x00010000;
    pub const EXITED = 0x00000020;
    pub const TRAPPED = 0x00000040;

    pub fn EXITSTATUS(s: u32) u8 {
        return @as(u8, @intCast((s >> 8) & 0xff));
    }
    pub fn TERMSIG(s: u32) u32 {
        return s & 0x7f;
    }
    pub fn STOPSIG(s: u32) u32 {
        return EXITSTATUS(s);
    }
    pub fn IFEXITED(s: u32) bool {
        return TERMSIG(s) == 0;
    }

    pub fn IFCONTINUED(s: u32) bool {
        return ((s & 0x7f) == 0xffff);
    }

    pub fn IFSTOPPED(s: u32) bool {
        return ((s & 0x7f != 0x7f) and !IFCONTINUED(s));
    }

    pub fn IFSIGNALED(s: u32) bool {
        return !IFSTOPPED(s) and !IFCONTINUED(s) and !IFEXITED(s);
    }
};

pub const SA = struct {
    pub const ONSTACK = 0x0001;
    pub const RESTART = 0x0002;
    pub const RESETHAND = 0x0004;
    pub const NOCLDSTOP = 0x0008;
    pub const NODEFER = 0x0010;
    pub const NOCLDWAIT = 0x0020;
    pub const SIGINFO = 0x0040;
};

// access function
pub const F_OK = 0; // test for existence of file
pub const X_OK = 1; // test for execute or search permission
pub const W_OK = 2; // test for write permission
pub const R_OK = 4; // test for read permission

pub const O = struct {
    /// open for reading only
    pub const RDONLY = 0x00000000;
    /// open for writing only
    pub const WRONLY = 0x00000001;
    /// open for reading and writing
    pub const RDWR = 0x00000002;
    /// mask for above modes
    pub const ACCMODE = 0x00000003;
    /// no delay
    pub const NONBLOCK = 0x00000004;
    /// set append mode
    pub const APPEND = 0x00000008;
    /// open with shared file lock
    pub const SHLOCK = 0x00000010;
    /// open with exclusive file lock
    pub const EXLOCK = 0x00000020;
    /// signal pgrp when data ready
    pub const ASYNC = 0x00000040;
    /// synchronous writes
    pub const SYNC = 0x00000080;
    /// don't follow symlinks on the last
    pub const NOFOLLOW = 0x00000100;
    /// create if nonexistent
    pub const CREAT = 0x00000200;
    /// truncate to zero length
    pub const TRUNC = 0x00000400;
    /// error if already exists
    pub const EXCL = 0x00000800;
    /// don't assign controlling terminal
    pub const NOCTTY = 0x00008000;
    /// write: I/O data completion
    pub const DSYNC = 0x00010000;
    /// read: I/O completion as for write
    pub const RSYNC = 0x00020000;
    /// use alternate i/o semantics
    pub const ALT_IO = 0x00040000;
    /// direct I/O hint
    pub const DIRECT = 0x00080000;
    /// fail if not a directory
    pub const DIRECTORY = 0x00200000;
    /// set close on exec
    pub const CLOEXEC = 0x00400000;
    /// skip search permission checks
    pub const SEARCH = 0x00800000;
};

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;
    pub const GETOWN = 5;
    pub const SETOWN = 6;
    pub const GETLK = 7;
    pub const SETLK = 8;
    pub const SETLKW = 9;
    pub const CLOSEM = 10;
    pub const MAXFD = 11;
    pub const DUPFD_CLOEXEC = 12;
    pub const GETNOSIGPIPE = 13;
    pub const SETNOSIGPIPE = 14;
    pub const GETPATH = 15;

    pub const RDLCK = 1;
    pub const WRLCK = 3;
    pub const UNLCK = 2;
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const UN = 8;
    pub const NB = 4;
};

pub const FD_CLOEXEC = 1;

pub const SEEK = struct {
    pub const SET = 0;
    pub const CUR = 1;
    pub const END = 2;
};

pub const DT = struct {
    pub const UNKNOWN = 0;
    pub const FIFO = 1;
    pub const CHR = 2;
    pub const DIR = 4;
    pub const BLK = 6;
    pub const REG = 8;
    pub const LNK = 10;
    pub const SOCK = 12;
    pub const WHT = 14;
};

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

/// User events
pub const EVFILT_USER = 1;

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

pub const T = struct {
    pub const IOCCBRK = 0x2000747a;
    pub const IOCCDTR = 0x20007478;
    pub const IOCCONS = 0x80047462;
    pub const IOCDCDTIMESTAMP = 0x40107458;
    pub const IOCDRAIN = 0x2000745e;
    pub const IOCEXCL = 0x2000740d;
    pub const IOCEXT = 0x80047460;
    pub const IOCFLAG_CDTRCTS = 0x10;
    pub const IOCFLAG_CLOCAL = 0x2;
    pub const IOCFLAG_CRTSCTS = 0x4;
    pub const IOCFLAG_MDMBUF = 0x8;
    pub const IOCFLAG_SOFTCAR = 0x1;
    pub const IOCFLUSH = 0x80047410;
    pub const IOCGETA = 0x402c7413;
    pub const IOCGETD = 0x4004741a;
    pub const IOCGFLAGS = 0x4004745d;
    pub const IOCGLINED = 0x40207442;
    pub const IOCGPGRP = 0x40047477;
    pub const IOCGQSIZE = 0x40047481;
    pub const IOCGRANTPT = 0x20007447;
    pub const IOCGSID = 0x40047463;
    pub const IOCGSIZE = 0x40087468;
    pub const IOCGWINSZ = 0x40087468;
    pub const IOCMBIC = 0x8004746b;
    pub const IOCMBIS = 0x8004746c;
    pub const IOCMGET = 0x4004746a;
    pub const IOCMSET = 0x8004746d;
    pub const IOCM_CAR = 0x40;
    pub const IOCM_CD = 0x40;
    pub const IOCM_CTS = 0x20;
    pub const IOCM_DSR = 0x100;
    pub const IOCM_DTR = 0x2;
    pub const IOCM_LE = 0x1;
    pub const IOCM_RI = 0x80;
    pub const IOCM_RNG = 0x80;
    pub const IOCM_RTS = 0x4;
    pub const IOCM_SR = 0x10;
    pub const IOCM_ST = 0x8;
    pub const IOCNOTTY = 0x20007471;
    pub const IOCNXCL = 0x2000740e;
    pub const IOCOUTQ = 0x40047473;
    pub const IOCPKT = 0x80047470;
    pub const IOCPKT_DATA = 0x0;
    pub const IOCPKT_DOSTOP = 0x20;
    pub const IOCPKT_FLUSHREAD = 0x1;
    pub const IOCPKT_FLUSHWRITE = 0x2;
    pub const IOCPKT_IOCTL = 0x40;
    pub const IOCPKT_NOSTOP = 0x10;
    pub const IOCPKT_START = 0x8;
    pub const IOCPKT_STOP = 0x4;
    pub const IOCPTMGET = 0x40287446;
    pub const IOCPTSNAME = 0x40287448;
    pub const IOCRCVFRAME = 0x80087445;
    pub const IOCREMOTE = 0x80047469;
    pub const IOCSBRK = 0x2000747b;
    pub const IOCSCTTY = 0x20007461;
    pub const IOCSDTR = 0x20007479;
    pub const IOCSETA = 0x802c7414;
    pub const IOCSETAF = 0x802c7416;
    pub const IOCSETAW = 0x802c7415;
    pub const IOCSETD = 0x8004741b;
    pub const IOCSFLAGS = 0x8004745c;
    pub const IOCSIG = 0x2000745f;
    pub const IOCSLINED = 0x80207443;
    pub const IOCSPGRP = 0x80047476;
    pub const IOCSQSIZE = 0x80047480;
    pub const IOCSSIZE = 0x80087467;
    pub const IOCSTART = 0x2000746e;
    pub const IOCSTAT = 0x80047465;
    pub const IOCSTI = 0x80017472;
    pub const IOCSTOP = 0x2000746f;
    pub const IOCSWINSZ = 0x80087467;
    pub const IOCUCNTL = 0x80047466;
    pub const IOCXMTFRAME = 0x80087444;
};

// Term
const V = struct {
    pub const EOF = 0; // ICANON
    pub const EOL = 1; // ICANON
    pub const EOL2 = 2; // ICANON
    pub const ERASE = 3; // ICANON
    pub const WERASE = 4; // ICANON
    pub const KILL = 5; // ICANON
    pub const REPRINT = 6; // ICANON
    //  7    spare 1
    pub const INTR = 8; // ISIG
    pub const QUIT = 9; // ISIG
    pub const SUSP = 10; // ISIG
    pub const DSUSP = 11; // ISIG
    pub const START = 12; // IXON, IXOFF
    pub const STOP = 13; // IXON, IXOFF
    pub const LNEXT = 14; // IEXTEN
    pub const DISCARD = 15; // IEXTEN
    pub const MIN = 16; // !ICANON
    pub const TIME = 17; // !ICANON
    pub const STATUS = 18; // ICANON
    //  19      spare 2
};

// Input flags - software input processing
pub const IGNBRK: tcflag_t = 0x00000001; // ignore BREAK condition
pub const BRKINT: tcflag_t = 0x00000002; // map BREAK to SIGINT
pub const IGNPAR: tcflag_t = 0x00000004; // ignore (discard) parity errors
pub const PARMRK: tcflag_t = 0x00000008; // mark parity and framing errors
pub const INPCK: tcflag_t = 0x00000010; // enable checking of parity errors
pub const ISTRIP: tcflag_t = 0x00000020; // strip 8th bit off chars
pub const INLCR: tcflag_t = 0x00000040; // map NL into CR
pub const IGNCR: tcflag_t = 0x00000080; // ignore CR
pub const ICRNL: tcflag_t = 0x00000100; // map CR to NL (ala CRMOD)
pub const IXON: tcflag_t = 0x00000200; // enable output flow control
pub const IXOFF: tcflag_t = 0x00000400; // enable input flow control
pub const IXANY: tcflag_t = 0x00000800; // any char will restart after stop
pub const IMAXBEL: tcflag_t = 0x00002000; // ring bell on input queue full

// Output flags - software output processing
pub const OPOST: tcflag_t = 0x00000001; // enable following output processing
pub const ONLCR: tcflag_t = 0x00000002; // map NL to CR-NL (ala CRMOD)
pub const OXTABS: tcflag_t = 0x00000004; // expand tabs to spaces
pub const ONOEOT: tcflag_t = 0x00000008; // discard EOT's (^D) on output
pub const OCRNL: tcflag_t = 0x00000010; // map CR to NL
pub const ONOCR: tcflag_t = 0x00000040; // discard CR's when on column 0
pub const ONLRET: tcflag_t = 0x00000080; // move to column 0 on CR

// Control flags - hardware control of terminal
pub const CIGNORE: tcflag_t = 0x00000001; // ignore control flags
pub const CSIZE: tcflag_t = 0x00000300; // character size mask
pub const CS5: tcflag_t = 0x00000000; // 5 bits (pseudo)
pub const CS6: tcflag_t = 0x00000100; // 6 bits
pub const CS7: tcflag_t = 0x00000200; // 7 bits
pub const CS8: tcflag_t = 0x00000300; // 8 bits
pub const CSTOPB: tcflag_t = 0x00000400; // send 2 stop bits
pub const CREAD: tcflag_t = 0x00000800; // enable receiver
pub const PARENB: tcflag_t = 0x00001000; // parity enable
pub const PARODD: tcflag_t = 0x00002000; // odd parity, else even
pub const HUPCL: tcflag_t = 0x00004000; // hang up on last close
pub const CLOCAL: tcflag_t = 0x00008000; // ignore modem status lines
pub const CRTSCTS: tcflag_t = 0x00010000; // RTS/CTS full-duplex flow control
pub const CRTS_IFLOW: tcflag_t = CRTSCTS; // XXX compat
pub const CCTS_OFLOW: tcflag_t = CRTSCTS; // XXX compat
pub const CDTRCTS: tcflag_t = 0x00020000; // DTR/CTS full-duplex flow control
pub const MDMBUF: tcflag_t = 0x00100000; // DTR/DCD hardware flow control
pub const CHWFLOW: tcflag_t = (MDMBUF | CRTSCTS | CDTRCTS); // all types of hw flow control

pub const tcflag_t = c_uint;
pub const speed_t = c_uint;
pub const cc_t = u8;

pub const NCCS = 20;

pub const termios = extern struct {
    iflag: tcflag_t, // input flags
    oflag: tcflag_t, // output flags
    cflag: tcflag_t, // control flags
    lflag: tcflag_t, // local flags
    cc: [NCCS]cc_t, // control chars
    ispeed: c_int, // input speed
    ospeed: c_int, // output speed
};

// Commands passed to tcsetattr() for setting the termios structure.
pub const TCSA = struct {
    pub const NOW = 0; // make change immediate
    pub const DRAIN = 1; // drain output, then chage
    pub const FLUSH = 2; // drain output, flush input
    pub const SOFT = 0x10; // flag - don't alter h.w. state
};

// Standard speeds
pub const B0: c_uint = 0;
pub const B50: c_uint = 50;
pub const B75: c_uint = 75;
pub const B110: c_uint = 110;
pub const B134: c_uint = 134;
pub const B150: c_uint = 150;
pub const B200: c_uint = 200;
pub const B300: c_uint = 300;
pub const B600: c_uint = 600;
pub const B1200: c_uint = 1200;
pub const B1800: c_uint = 1800;
pub const B2400: c_uint = 2400;
pub const B4800: c_uint = 4800;
pub const B9600: c_uint = 9600;
pub const B19200: c_uint = 19200;
pub const B38400: c_uint = 38400;
pub const B7200: c_uint = 7200;
pub const B14400: c_uint = 14400;
pub const B28800: c_uint = 28800;
pub const B57600: c_uint = 57600;
pub const B76800: c_uint = 76800;
pub const B115200: c_uint = 115200;
pub const B230400: c_uint = 230400;
pub const B460800: c_uint = 460800;
pub const B500000: c_uint = 500000;
pub const B921600: c_uint = 921600;
pub const B1000000: c_uint = 1000000;
pub const B1500000: c_uint = 1500000;
pub const B2000000: c_uint = 2000000;
pub const B2500000: c_uint = 2500000;
pub const B3000000: c_uint = 3000000;
pub const B3500000: c_uint = 3500000;
pub const B4000000: c_uint = 4000000;
pub const EXTA: c_uint = 19200;
pub const EXTB: c_uint = 38400;

pub const TCIFLUSH = 1;
pub const TCOFLUSH = 2;
pub const TCIOFLUSH = 3;
pub const TCOOFF = 1;
pub const TCOON = 2;
pub const TCIOFF = 3;
pub const TCION = 4;

pub const winsize = extern struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

const NSIG = 32;

pub const SIG = struct {
    pub const DFL = @as(?Sigaction.handler_fn, @ptrFromInt(0));
    pub const IGN = @as(?Sigaction.handler_fn, @ptrFromInt(1));
    pub const ERR = @as(?Sigaction.handler_fn, @ptrFromInt(maxInt(usize)));

    pub const WORDS = 4;
    pub const MAXSIG = 128;

    pub const BLOCK = 1;
    pub const UNBLOCK = 2;
    pub const SETMASK = 3;

    pub const HUP = 1;
    pub const INT = 2;
    pub const QUIT = 3;
    pub const ILL = 4;
    pub const TRAP = 5;
    pub const ABRT = 6;
    pub const IOT = ABRT;
    pub const EMT = 7;
    pub const FPE = 8;
    pub const KILL = 9;
    pub const BUS = 10;
    pub const SEGV = 11;
    pub const SYS = 12;
    pub const PIPE = 13;
    pub const ALRM = 14;
    pub const TERM = 15;
    pub const URG = 16;
    pub const STOP = 17;
    pub const TSTP = 18;
    pub const CONT = 19;
    pub const CHLD = 20;
    pub const TTIN = 21;
    pub const TTOU = 22;
    pub const IO = 23;
    pub const XCPU = 24;
    pub const XFSZ = 25;
    pub const VTALRM = 26;
    pub const PROF = 27;
    pub const WINCH = 28;
    pub const INFO = 29;
    pub const USR1 = 30;
    pub const USR2 = 31;
    pub const PWR = 32;

    pub const RTMIN = 33;
    pub const RTMAX = 63;

    pub inline fn IDX(sig: usize) usize {
        return sig - 1;
    }
    pub inline fn WORD(sig: usize) usize {
        return IDX(sig) >> 5;
    }
    pub inline fn BIT(sig: usize) usize {
        return 1 << (IDX(sig) & 31);
    }
    pub inline fn VALID(sig: usize) usize {
        return sig <= MAXSIG and sig > 0;
    }
};

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = extern struct {
    pub const handler_fn = *const fn (c_int) align(1) callconv(.C) void;
    pub const sigaction_fn = *const fn (c_int, *const siginfo_t, ?*const anyopaque) callconv(.C) void;

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
    ptr: ?*anyopaque,
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
            addr: ?*anyopaque,
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

pub const sigset_t = extern struct {
    __bits: [SIG.WORDS]u32,
};

pub const empty_sigset = sigset_t{ .__bits = [_]u32{0} ** SIG.WORDS };

pub const mcontext_t = switch (builtin.cpu.arch) {
    .aarch64 => extern struct {
        gregs: [35]u64,
        fregs: [528]u8 align(16),
        spare: [8]u64,
    },
    .x86_64 => extern struct {
        gregs: [26]u64,
        mc_tlsbase: u64,
        fpregs: [512]u8 align(8),
    },
    else => struct {},
};

pub const REG = switch (builtin.cpu.arch) {
    .aarch64 => struct {
        pub const FP = 29;
        pub const SP = 31;
        pub const PC = 32;
    },
    .arm => struct {
        pub const FP = 11;
        pub const SP = 13;
        pub const PC = 15;
    },
    .x86_64 => struct {
        pub const RBP = 12;
        pub const RIP = 21;
        pub const RSP = 24;
    },
    else => struct {},
};

pub const ucontext_t = extern struct {
    flags: u32,
    link: ?*ucontext_t,
    sigmask: sigset_t,
    stack: stack_t,
    mcontext: mcontext_t,
    __pad: [
        switch (builtin.cpu.arch) {
            .x86 => 4,
            .mips, .mipsel, .mips64, .mips64el => 14,
            .arm, .armeb, .thumb, .thumbeb => 1,
            .sparc, .sparcel, .sparc64 => if (@sizeOf(usize) == 4) 43 else 8,
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
    sp: [*]u8,
    size: isize,
    flags: i32,
};

pub const S = struct {
    pub const IFMT = 0o170000;

    pub const IFIFO = 0o010000;
    pub const IFCHR = 0o020000;
    pub const IFDIR = 0o040000;
    pub const IFBLK = 0o060000;
    pub const IFREG = 0o100000;
    pub const IFLNK = 0o120000;
    pub const IFSOCK = 0o140000;
    pub const IFWHT = 0o160000;

    pub const ISUID = 0o4000;
    pub const ISGID = 0o2000;
    pub const ISVTX = 0o1000;
    pub const IRWXU = 0o700;
    pub const IRUSR = 0o400;
    pub const IWUSR = 0o200;
    pub const IXUSR = 0o100;
    pub const IRWXG = 0o070;
    pub const IRGRP = 0o040;
    pub const IWGRP = 0o020;
    pub const IXGRP = 0o010;
    pub const IRWXO = 0o007;
    pub const IROTH = 0o004;
    pub const IWOTH = 0o002;
    pub const IXOTH = 0o001;

    pub fn ISFIFO(m: u32) bool {
        return m & IFMT == IFIFO;
    }

    pub fn ISCHR(m: u32) bool {
        return m & IFMT == IFCHR;
    }

    pub fn ISDIR(m: u32) bool {
        return m & IFMT == IFDIR;
    }

    pub fn ISBLK(m: u32) bool {
        return m & IFMT == IFBLK;
    }

    pub fn ISREG(m: u32) bool {
        return m & IFMT == IFREG;
    }

    pub fn ISLNK(m: u32) bool {
        return m & IFMT == IFLNK;
    }

    pub fn ISSOCK(m: u32) bool {
        return m & IFMT == IFSOCK;
    }

    pub fn IWHT(m: u32) bool {
        return m & IFMT == IFWHT;
    }
};

pub const AT = struct {
    /// Magic value that specify the use of the current working directory
    /// to determine the target of relative file paths in the openat() and
    /// similar syscalls.
    pub const FDCWD = -100;
    /// Check access using effective user and group ID
    pub const EACCESS = 0x0100;
    /// Do not follow symbolic links
    pub const SYMLINK_NOFOLLOW = 0x0200;
    /// Follow symbolic link
    pub const SYMLINK_FOLLOW = 0x0400;
    /// Remove directory instead of file
    pub const REMOVEDIR = 0x0800;
};

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

pub const SHUT = struct {
    pub const RD = 0;
    pub const WR = 1;
    pub const RDWR = 2;
};

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
