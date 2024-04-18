const std = @import("../std.zig");
const assert = std.debug.assert;
const maxInt = std.math.maxInt;
const builtin = @import("builtin");
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;

extern "c" fn __errno() *c_int;
pub const _errno = __errno;

pub const dl_iterate_phdr_callback = *const fn (info: *dl_phdr_info, size: usize, data: ?*anyopaque) callconv(.C) c_int;
pub extern "c" fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*anyopaque) c_int;

pub extern "c" fn arc4random_buf(buf: [*]u8, len: usize) void;

pub extern "c" fn getthrid() pid_t;
pub extern "c" fn pipe2(fds: *[2]fd_t, flags: std.c.O) c_int;

pub extern "c" fn getdents(fd: c_int, buf_ptr: [*]u8, nbytes: usize) c_int;
pub extern "c" fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) c_int;

pub const pthread_spinlock_t = extern struct {
    inner: ?*anyopaque = null,
};
pub const pthread_attr_t = extern struct {
    inner: ?*anyopaque = null,
};
pub const pthread_key_t = c_int;

pub const sem_t = ?*opaque {};

pub extern "c" fn posix_memalign(memptr: *?*anyopaque, alignment: usize, size: usize) c_int;

pub extern "c" fn pledge(promises: ?[*:0]const u8, execpromises: ?[*:0]const u8) c_int;
pub extern "c" fn unveil(path: ?[*:0]const u8, permissions: ?[*:0]const u8) c_int;

pub extern "c" fn pthread_set_name_np(thread: std.c.pthread_t, name: [*:0]const u8) void;
pub extern "c" fn pthread_get_name_np(thread: std.c.pthread_t, name: [*:0]u8, len: usize) void;

// https://github.com/openbsd/src/blob/2207c4325726fdc5c4bcd0011af0fdf7d3dab137/sys/sys/futex.h
pub const FUTEX_WAIT = 1;
pub const FUTEX_WAKE = 2;
pub const FUTEX_REQUEUE = 3;
pub const FUTEX_PRIVATE_FLAG = 128;
pub extern "c" fn futex(uaddr: ?*const volatile u32, op: c_int, val: c_int, timeout: ?*const timespec, uaddr2: ?*const volatile u32) c_int;

pub const login_cap_t = extern struct {
    lc_class: ?[*:0]const u8,
    lc_cap: ?[*:0]const u8,
    lc_style: ?[*:0]const u8,
};

pub extern "c" fn login_getclass(class: ?[*:0]const u8) ?*login_cap_t;
pub extern "c" fn login_getstyle(lc: *login_cap_t, style: ?[*:0]const u8, atype: ?[*:0]const u8) ?[*:0]const u8;
pub extern "c" fn login_getcapbool(lc: *login_cap_t, cap: [*:0]const u8, def: c_int) c_int;
pub extern "c" fn login_getcapnum(lc: *login_cap_t, cap: [*:0]const u8, def: i64, err: i64) i64;
pub extern "c" fn login_getcapsize(lc: *login_cap_t, cap: [*:0]const u8, def: i64, err: i64) i64;
pub extern "c" fn login_getcapstr(lc: *login_cap_t, cap: [*:0]const u8, def: [*:0]const u8, err: [*:0]const u8) [*:0]const u8;
pub extern "c" fn login_getcaptime(lc: *login_cap_t, cap: [*:0]const u8, def: i64, err: i64) i64;
pub extern "c" fn login_close(lc: *login_cap_t) void;
pub extern "c" fn setclasscontext(class: [*:0]const u8, flags: c_uint) c_int;
pub extern "c" fn setusercontext(lc: *login_cap_t, pwd: *passwd, uid: uid_t, flags: c_uint) c_int;

pub const auth_session_t = opaque {};

pub extern "c" fn auth_userokay(name: [*:0]const u8, style: ?[*:0]const u8, arg_type: ?[*:0]const u8, password: ?[*:0]const u8) c_int;
pub extern "c" fn auth_approval(as: ?*auth_session_t, ?*login_cap_t, name: ?[*:0]const u8, type: ?[*:0]const u8) c_int;
pub extern "c" fn auth_userchallenge(name: [*:0]const u8, style: ?[*:0]const u8, arg_type: ?[*:0]const u8, chappengep: *?[*:0]const u8) ?*auth_session_t;
pub extern "c" fn auth_userresponse(as: *auth_session_t, response: [*:0]const u8, more: c_int) c_int;
pub extern "c" fn auth_usercheck(name: [*:0]const u8, style: ?[*:0]const u8, arg_type: ?[*:0]const u8, password: ?[*:0]const u8) ?*auth_session_t;
pub extern "c" fn auth_open() ?*auth_session_t;
pub extern "c" fn auth_close(as: *auth_session_t) c_int;
pub extern "c" fn auth_setdata(as: *auth_session_t, ptr: *anyopaque, len: usize) c_int;
pub extern "c" fn auth_setitem(as: *auth_session_t, item: auth_item_t, value: [*:0]const u8) c_int;
pub extern "c" fn auth_getitem(as: *auth_session_t, item: auth_item_t) ?[*:0]const u8;
pub extern "c" fn auth_setoption(as: *auth_session_t, n: [*:0]const u8, v: [*:0]const u8) c_int;
pub extern "c" fn auth_setstate(as: *auth_session_t, s: c_int) void;
pub extern "c" fn auth_getstate(as: *auth_session_t) c_int;
pub extern "c" fn auth_clean(as: *auth_session_t) void;
pub extern "c" fn auth_clrenv(as: *auth_session_t) void;
pub extern "c" fn auth_clroption(as: *auth_session_t, option: [*:0]const u8) void;
pub extern "c" fn auth_clroptions(as: *auth_session_t) void;
pub extern "c" fn auth_setenv(as: *auth_session_t) void;
pub extern "c" fn auth_getvalue(as: *auth_session_t, what: [*:0]const u8) ?[*:0]const u8;
pub extern "c" fn auth_verify(as: ?*auth_session_t, style: ?[*:0]const u8, name: ?[*:0]const u8, ...) ?*auth_session_t;
pub extern "c" fn auth_call(as: *auth_session_t, path: [*:0]const u8, ...) c_int;
pub extern "c" fn auth_challenge(as: *auth_session_t) [*:0]const u8;
pub extern "c" fn auth_check_expire(as: *auth_session_t) i64;
pub extern "c" fn auth_check_change(as: *auth_session_t) i64;
pub extern "c" fn auth_getpwd(as: *auth_session_t) ?*passwd;
pub extern "c" fn auth_setpwd(as: *auth_session_t, pwd: *passwd) c_int;
pub extern "c" fn auth_mkvalue(value: [*:0]const u8) ?[*:0]const u8;
pub extern "c" fn auth_cat(file: [*:0]const u8) c_int;
pub extern "c" fn auth_checknologin(lc: *login_cap_t) void;
// TODO: auth_set_va_list requires zig support for va_list type (#515)

pub const passwd = extern struct {
    pw_name: ?[*:0]const u8, // user name
    pw_passwd: ?[*:0]const u8, // encrypted password
    pw_uid: uid_t, // user uid
    pw_gid: gid_t, // user gid
    pw_change: time_t, // password change time
    pw_class: ?[*:0]const u8, // user access class
    pw_gecos: ?[*:0]const u8, // Honeywell login info
    pw_dir: ?[*:0]const u8, // home directory
    pw_shell: ?[*:0]const u8, // default shell
    pw_expire: time_t, // account expiration
};

pub extern "c" fn getpwuid(uid: uid_t) ?*passwd;
pub extern "c" fn getpwnam(name: [*:0]const u8) ?*passwd;
pub extern "c" fn getpwuid_shadow(uid: uid_t) ?*passwd;
pub extern "c" fn getpwnam_shadow(name: [*:0]const u8) ?*passwd;
pub extern "c" fn getpwnam_r(name: [*:0]const u8, pw: *passwd, buf: [*]u8, buflen: usize, pwretp: *?*passwd) c_int;
pub extern "c" fn getpwuid_r(uid: uid_t, pw: *passwd, buf: [*]u8, buflen: usize, pwretp: *?*passwd) c_int;
pub extern "c" fn getpwent() ?*passwd;
pub extern "c" fn setpwent() void;
pub extern "c" fn endpwent() void;
pub extern "c" fn setpassent(stayopen: c_int) c_int;
pub extern "c" fn uid_from_user(name: [*:0]const u8, uid: *uid_t) c_int;
pub extern "c" fn user_from_uid(uid: uid_t, noname: c_int) ?[*:0]const u8;
pub extern "c" fn bcrypt_gensalt(log_rounds: u8) [*:0]const u8;
pub extern "c" fn bcrypt(pass: [*:0]const u8, salt: [*:0]const u8) ?[*:0]const u8;
pub extern "c" fn bcrypt_newhash(pass: [*:0]const u8, log_rounds: c_int, hash: [*]u8, hashlen: usize) c_int;
pub extern "c" fn bcrypt_checkpass(pass: [*:0]const u8, goodhash: [*:0]const u8) c_int;
pub extern "c" fn pw_dup(pw: *const passwd) ?*passwd;

pub const blkcnt_t = i64;
pub const blksize_t = i32;
pub const clock_t = i64;
pub const dev_t = i32;
pub const fd_t = c_int;
pub const gid_t = u32;
pub const ino_t = u64;
pub const mode_t = u32;
pub const nlink_t = u32;
pub const off_t = i64;
pub const pid_t = i32;
pub const socklen_t = u32;
pub const time_t = i64;
pub const uid_t = u32;

/// Renamed from `kevent` to `Kevent` to avoid conflict with function name.
pub const Kevent = extern struct {
    ident: usize,
    filter: c_short,
    flags: u16,
    fflags: c_uint,
    data: i64,
    udata: usize,
};

// Modes and flags for dlopen()
// include/dlfcn.h

pub const RTLD = struct {
    /// Bind function calls lazily.
    pub const LAZY = 1;
    /// Bind function calls immediately.
    pub const NOW = 2;
    /// Make symbols globally available.
    pub const GLOBAL = 0x100;
    /// Opposite of GLOBAL, and the default.
    pub const LOCAL = 0x000;
    /// Trace loaded objects and exit.
    pub const TRACE = 0x200;
};

pub const dl_phdr_info = extern struct {
    dlpi_addr: std.elf.Addr,
    dlpi_name: ?[*:0]const u8,
    dlpi_phdr: [*]std.elf.Phdr,
    dlpi_phnum: std.elf.Half,
};

pub const Flock = extern struct {
    start: off_t,
    len: off_t,
    pid: pid_t,
    type: c_short,
    whence: c_short,
};

pub const addrinfo = extern struct {
    flags: c_int,
    family: c_int,
    socktype: c_int,
    protocol: c_int,
    addrlen: socklen_t,
    addr: ?*sockaddr,
    canonname: ?[*:0]u8,
    next: ?*addrinfo,
};

pub const EAI = enum(c_int) {
    /// address family for hostname not supported
    ADDRFAMILY = -9,

    /// name could not be resolved at this time
    AGAIN = -3,

    /// flags parameter had an invalid value
    BADFLAGS = -1,

    /// non-recoverable failure in name resolution
    FAIL = -4,

    /// address family not recognized
    FAMILY = -6,

    /// memory allocation failure
    MEMORY = -10,

    /// no address associated with hostname
    NODATA = -5,

    /// name does not resolve
    NONAME = -2,

    /// service not recognized for socket type
    SERVICE = -8,

    /// intended socket type was not recognized
    SOCKTYPE = -7,

    /// system error returned in errno
    SYSTEM = -11,

    /// invalid value for hints
    BADHINTS = -12,

    /// resolved protocol is unknown
    PROTOCOL = -13,

    /// argument buffer overflow
    OVERFLOW = -14,

    _,
};

pub const EAI_MAX = 15;

pub const msghdr = extern struct {
    /// optional address
    name: ?*sockaddr,
    /// size of address
    namelen: socklen_t,
    /// scatter/gather array
    iov: [*]iovec,
    /// # elements in iov
    iovlen: c_uint,
    /// ancillary data
    control: ?*anyopaque,
    /// ancillary data buffer len
    controllen: socklen_t,
    /// flags on received message
    flags: c_int,
};

pub const msghdr_const = extern struct {
    /// optional address
    name: ?*const sockaddr,
    /// size of address
    namelen: socklen_t,
    /// scatter/gather array
    iov: [*]const iovec_const,
    /// # elements in iov
    iovlen: c_uint,
    /// ancillary data
    control: ?*const anyopaque,
    /// ancillary data buffer len
    controllen: socklen_t,
    /// flags on received message
    flags: c_int,
};

pub const Stat = extern struct {
    mode: mode_t,
    dev: dev_t,
    ino: ino_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    size: off_t,
    blocks: blkcnt_t,
    blksize: blksize_t,
    flags: u32,
    gen: u32,
    birthtim: timespec,

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
    tv_sec: time_t,
    tv_nsec: c_long,
};

pub const timeval = extern struct {
    tv_sec: time_t,
    tv_usec: c_long,
};

pub const timezone = extern struct {
    tz_minuteswest: c_int,
    tz_dsttime: c_int,
};

pub const MAXNAMLEN = 255;

pub const dirent = extern struct {
    fileno: ino_t,
    off: off_t,
    reclen: u16,
    type: u8,
    namlen: u8,
    _: u32 align(1) = 0,
    name: [MAXNAMLEN + 1]u8,
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

    pub const SS_MAXSIZE = 256;
    pub const storage = extern struct {
        len: u8 align(8),
        family: sa_family_t,
        padding: [254]u8 = undefined,

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

pub const IFNAMESIZE = 16;

pub const AI = struct {
    /// get address to use bind()
    pub const PASSIVE = 1;
    /// fill ai_canonname
    pub const CANONNAME = 2;
    /// prevent host name resolution
    pub const NUMERICHOST = 4;
    /// prevent service name resolution
    pub const NUMERICSERV = 16;
    /// only if any address is assigned
    pub const ADDRCONFIG = 64;
};

pub const PATH_MAX = 1024;
pub const NAME_MAX = 255;
pub const IOV_MAX = 1024;

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
    pub const PROCESS_CPUTIME_ID = 2;
    pub const MONOTONIC = 3;
    pub const THREAD_CPUTIME_ID = 4;
};

pub const MSF = struct {
    pub const ASYNC = 1;
    pub const INVALIDATE = 2;
    pub const SYNC = 4;
};

pub const W = struct {
    pub const NOHANG = 1;
    pub const UNTRACED = 2;
    pub const CONTINUED = 8;

    pub fn EXITSTATUS(s: u32) u8 {
        return @as(u8, @intCast((s >> 8) & 0xff));
    }
    pub fn TERMSIG(s: u32) u32 {
        return (s & 0x7f);
    }
    pub fn STOPSIG(s: u32) u32 {
        return EXITSTATUS(s);
    }
    pub fn IFEXITED(s: u32) bool {
        return TERMSIG(s) == 0;
    }

    pub fn IFCONTINUED(s: u32) bool {
        return ((s & 0o177777) == 0o177777);
    }

    pub fn IFSTOPPED(s: u32) bool {
        return (s & 0xff == 0o177);
    }

    pub fn IFSIGNALED(s: u32) bool {
        return (((s) & 0o177) != 0o177) and (((s) & 0o177) != 0);
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

    pub const RDLCK = 1;
    pub const UNLCK = 2;
    pub const WRLCK = 3;
};

pub const LOCK = struct {
    pub const SH = 0x01;
    pub const EX = 0x02;
    pub const NB = 0x04;
    pub const UN = 0x08;
};

pub const FD_CLOEXEC = 1;

pub const SEEK = struct {
    pub const SET = 0;
    pub const CUR = 1;
    pub const END = 2;
};

pub const SOCK = struct {
    pub const STREAM = 1;
    pub const DGRAM = 2;
    pub const RAW = 3;
    pub const RDM = 4;
    pub const SEQPACKET = 5;

    pub const CLOEXEC = 0x8000;
    pub const NONBLOCK = 0x4000;
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
    pub const TIMESTAMP = 0x0800;
    pub const BINDANY = 0x1000;
    pub const ZEROIZE = 0x2000;
    pub const SNDBUF = 0x1001;
    pub const RCVBUF = 0x1002;
    pub const SNDLOWAT = 0x1003;
    pub const RCVLOWAT = 0x1004;
    pub const SNDTIMEO = 0x1005;
    pub const RCVTIMEO = 0x1006;
    pub const ERROR = 0x1007;
    pub const TYPE = 0x1008;
    pub const NETPROC = 0x1020;
    pub const RTABLE = 0x1021;
    pub const PEERCRED = 0x1022;
    pub const SPLICE = 0x1023;
    pub const DOMAIN = 0x1024;
    pub const PROTOCOL = 0x1025;
};

pub const SOL = struct {
    pub const SOCKET = 0xffff;
};

pub const PF = struct {
    pub const UNSPEC = AF.UNSPEC;
    pub const LOCAL = AF.LOCAL;
    pub const UNIX = AF.UNIX;
    pub const INET = AF.INET;
    pub const APPLETALK = AF.APPLETALK;
    pub const INET6 = AF.INET6;
    pub const DECnet = AF.DECnet;
    pub const KEY = AF.KEY;
    pub const ROUTE = AF.ROUTE;
    pub const SNA = AF.SNA;
    pub const MPLS = AF.MPLS;
    pub const BLUETOOTH = AF.BLUETOOTH;
    pub const ISDN = AF.ISDN;
    pub const MAX = AF.MAX;
};

pub const AF = struct {
    pub const UNSPEC = 0;
    pub const UNIX = 1;
    pub const LOCAL = UNIX;
    pub const INET = 2;
    pub const APPLETALK = 16;
    pub const INET6 = 24;
    pub const KEY = 30;
    pub const ROUTE = 17;
    pub const SNA = 11;
    pub const MPLS = 33;
    pub const BLUETOOTH = 32;
    pub const ISDN = 26;
    pub const MAX = 36;
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
    pub const WHT = 14; // XXX
};

pub const EV_ADD = 0x0001;
pub const EV_DELETE = 0x0002;
pub const EV_ENABLE = 0x0004;
pub const EV_DISABLE = 0x0008;
pub const EV_ONESHOT = 0x0010;
pub const EV_CLEAR = 0x0020;
pub const EV_RECEIPT = 0x0040;
pub const EV_DISPATCH = 0x0080;
pub const EV_FLAG1 = 0x2000;
pub const EV_ERROR = 0x4000;
pub const EV_EOF = 0x8000;

pub const EVFILT_READ = -1;
pub const EVFILT_WRITE = -2;
pub const EVFILT_AIO = -3;
pub const EVFILT_VNODE = -4;
pub const EVFILT_PROC = -5;
pub const EVFILT_SIGNAL = -6;
pub const EVFILT_TIMER = -7;
pub const EVFILT_EXCEPT = -9;

// data/hint flags for EVFILT_{READ|WRITE}
pub const NOTE_LOWAT = 0x0001;
pub const NOTE_EOF = 0x0002;

// data/hint flags for EVFILT_EXCEPT and EVFILT_{READ|WRITE}
pub const NOTE_OOB = 0x0004;

// data/hint flags for EVFILT_VNODE
pub const NOTE_DELETE = 0x0001;
pub const NOTE_WRITE = 0x0002;
pub const NOTE_EXTEND = 0x0004;
pub const NOTE_ATTRIB = 0x0008;
pub const NOTE_LINK = 0x0010;
pub const NOTE_RENAME = 0x0020;
pub const NOTE_REVOKE = 0x0040;
pub const NOTE_TRUNCATE = 0x0080;

// data/hint flags for EVFILT_PROC
pub const NOTE_EXIT = 0x80000000;
pub const NOTE_FORK = 0x40000000;
pub const NOTE_EXEC = 0x20000000;
pub const NOTE_PDATAMASK = 0x000fffff;
pub const NOTE_PCTRLMASK = 0xf0000000;
pub const NOTE_TRACK = 0x00000001;
pub const NOTE_TRACKERR = 0x00000002;
pub const NOTE_CHILD = 0x00000004;

// data/hint flags for EVFILT_DEVICE
pub const NOTE_CHANGE = 0x00000001;

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

// BSD Authentication
pub const auth_item_t = c_int;

pub const AUTHV = struct {
    pub const ALL: auth_item_t = 0;
    pub const CHALLENGE: auth_item_t = 1;
    pub const CLASS: auth_item_t = 2;
    pub const NAME: auth_item_t = 3;
    pub const SERVICE: auth_item_t = 4;
    pub const STYLE: auth_item_t = 5;
    pub const INTERACTIVE: auth_item_t = 6;
};

pub const BI = struct {
    pub const AUTH = "authorize"; // Accepted authentication
    pub const REJECT = "reject"; // Rejected authentication
    pub const CHALLENGE = "reject challenge"; // Reject with a challenge
    pub const SILENT = "reject silent"; // Reject silently
    pub const REMOVE = "remove"; // remove file on error
    pub const ROOTOKAY = "authorize root"; // root authenticated
    pub const SECURE = "authorize secure"; // okay on non-secure line
    pub const SETENV = "setenv"; // set environment variable
    pub const UNSETENV = "unsetenv"; // unset environment variable
    pub const VALUE = "value"; // set local variable
    pub const EXPIRED = "reject expired"; // account expired
    pub const PWEXPIRED = "reject pwexpired"; // password expired
    pub const FDPASS = "fd"; // child is passing an fd
};

pub const AUTH = struct {
    pub const OKAY: c_int = 0x01; // user authenticated
    pub const ROOTOKAY: c_int = 0x02; // authenticated as root
    pub const SECURE: c_int = 0x04; // secure login
    pub const SILENT: c_int = 0x08; // silent rejection
    pub const CHALLENGE: c_int = 0x10; // a challenge was given
    pub const EXPIRED: c_int = 0x20; // account expired
    pub const PWEXPIRED: c_int = 0x40; // password expired
    pub const ALLOW: c_int = (OKAY | ROOTOKAY | SECURE);
};

pub const TCSA = enum(c_uint) {
    NOW,
    DRAIN,
    FLUSH,
    _,
};

pub const TCIFLUSH = 1;
pub const TCOFLUSH = 2;
pub const TCIOFLUSH = 3;
pub const TCOOFF = 1;
pub const TCOON = 2;
pub const TCIOFF = 3;
pub const TCION = 4;

pub const winsize = extern struct {
    ws_row: c_ushort,
    ws_col: c_ushort,
    ws_xpixel: c_ushort,
    ws_ypixel: c_ushort,
};

const NSIG = 33;

pub const SIG = struct {
    pub const DFL: ?Sigaction.handler_fn = @ptrFromInt(0);
    pub const IGN: ?Sigaction.handler_fn = @ptrFromInt(1);
    pub const ERR: ?Sigaction.handler_fn = @ptrFromInt(maxInt(usize));
    pub const CATCH: ?Sigaction.handler_fn = @ptrFromInt(2);
    pub const HOLD: ?Sigaction.handler_fn = @ptrFromInt(3);

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

    pub const BLOCK = 1;
    pub const UNBLOCK = 2;
    pub const SETMASK = 3;
};

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = extern struct {
    pub const handler_fn = *align(1) const fn (i32) callconv(.C) void;
    pub const sigaction_fn = *const fn (i32, *const siginfo_t, ?*anyopaque) callconv(.C) void;

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

pub const sigval = extern union {
    int: c_int,
    ptr: ?*anyopaque,
};

pub const siginfo_t = extern struct {
    signo: c_int,
    code: c_int,
    errno: c_int,
    data: extern union {
        proc: extern struct {
            pid: pid_t,
            pdata: extern union {
                kill: extern struct {
                    uid: uid_t,
                    value: sigval,
                },
                cld: extern struct {
                    utime: clock_t,
                    stime: clock_t,
                    status: c_int,
                },
            },
        },
        fault: extern struct {
            addr: *allowzero anyopaque,
            trapno: c_int,
        },
        __pad: [128 - 3 * @sizeOf(c_int)]u8,
    },
};

comptime {
    if (@sizeOf(usize) == 4)
        std.debug.assert(@sizeOf(siginfo_t) == 128)
    else
        // Take into account the padding between errno and data fields.
        std.debug.assert(@sizeOf(siginfo_t) == 136);
}

pub const ucontext_t = switch (builtin.cpu.arch) {
    .x86_64 => extern struct {
        sc_rdi: c_long,
        sc_rsi: c_long,
        sc_rdx: c_long,
        sc_rcx: c_long,
        sc_r8: c_long,
        sc_r9: c_long,
        sc_r10: c_long,
        sc_r11: c_long,
        sc_r12: c_long,
        sc_r13: c_long,
        sc_r14: c_long,
        sc_r15: c_long,
        sc_rbp: c_long,
        sc_rbx: c_long,
        sc_rax: c_long,
        sc_gs: c_long,
        sc_fs: c_long,
        sc_es: c_long,
        sc_ds: c_long,
        sc_trapno: c_long,
        sc_err: c_long,
        sc_rip: c_long,
        sc_cs: c_long,
        sc_rflags: c_long,
        sc_rsp: c_long,
        sc_ss: c_long,

        sc_fpstate: *anyopaque, // struct fxsave64 *
        __sc_unused: c_int,
        sc_mask: c_int,
        sc_cookie: c_long,
    },
    .aarch64 => extern struct {
        __sc_unused: c_int,
        sc_mask: c_int,
        sc_sp: c_ulong,
        sc_lr: c_ulong,
        sc_elr: c_ulong,
        sc_spsr: c_ulong,
        sc_x: [30]c_ulong,
        sc_cookie: c_long,
    },
    else => @compileError("missing ucontext_t type definition"),
};

pub const sigset_t = c_uint;
pub const empty_sigset: sigset_t = 0;

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
    IPSEC = 82, // IPsec processing failure
    NOATTR = 83, // Attribute not found

    // Wide/multibyte-character handling, ISO/IEC 9899/AMD1:1995
    ILSEQ = 84, // Illegal byte sequence

    NOMEDIUM = 85, // No medium found
    MEDIUMTYPE = 86, // Wrong medium type
    OVERFLOW = 87, // Value too large to be stored in data type
    CANCELED = 88, // Operation canceled
    IDRM = 89, // Identifier removed
    NOMSG = 90, // No message of desired type
    NOTSUP = 91, // Not supported
    BADMSG = 92, // Bad or Corrupt message
    NOTRECOVERABLE = 93, // State not recoverable
    OWNERDEAD = 94, // Previous owner died
    PROTO = 95, // Protocol error

    _,
};

const _MAX_PAGE_SHIFT = switch (builtin.cpu.arch) {
    .x86 => 12,
    .sparc64 => 13,
};
pub const MINSIGSTKSZ = 1 << _MAX_PAGE_SHIFT;
pub const SIGSTKSZ = MINSIGSTKSZ + (1 << _MAX_PAGE_SHIFT) * 4;

pub const SS_ONSTACK = 0x0001;
pub const SS_DISABLE = 0x0004;

pub const stack_t = extern struct {
    sp: [*]u8,
    size: usize,
    flags: c_int,
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
};

pub const HOST_NAME_MAX = 255;

pub const IPPROTO = struct {
    /// dummy for IP
    pub const IP = 0;
    /// IP6 hop-by-hop options
    pub const HOPOPTS = IP;
    /// control message protocol
    pub const ICMP = 1;
    /// group mgmt protocol
    pub const IGMP = 2;
    /// gateway^2 (deprecated)
    pub const GGP = 3;
    /// IP header
    pub const IPV4 = IPIP;
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
    /// PFSYNC
    pub const PFSYNC = 240;
    /// raw IP packet
    pub const RAW = 255;
};

pub const rlimit_resource = enum(c_int) {
    CPU,
    FSIZE,
    DATA,
    STACK,
    CORE,
    RSS,
    MEMLOCK,
    NPROC,
    NOFILE,

    _,
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

pub const nfds_t = c_uint;

pub const pollfd = extern struct {
    fd: fd_t,
    events: c_short,
    revents: c_short,
};

pub const POLL = struct {
    pub const IN = 0x0001;
    pub const PRI = 0x0002;
    pub const OUT = 0x0004;
    pub const ERR = 0x0008;
    pub const HUP = 0x0010;
    pub const NVAL = 0x0020;
    pub const RDNORM = 0x0040;
    pub const NORM = RDNORM;
    pub const WRNORM = OUT;
    pub const RDBAND = 0x0080;
    pub const WRBAND = 0x0100;
};

pub const CTL = struct {
    pub const UNSPEC = 0;
    pub const KERN = 1;
    pub const VM = 2;
    pub const FS = 3;
    pub const NET = 4;
    pub const DEBUG = 5;
    pub const HW = 6;
    pub const MACHDEP = 7;

    pub const DDB = 9;
    pub const VFS = 10;
};

pub const KERN = struct {
    pub const OSTYPE = 1;
    pub const OSRELEASE = 2;
    pub const OSREV = 3;
    pub const VERSION = 4;
    pub const MAXVNODES = 5;
    pub const MAXPROC = 6;
    pub const MAXFILES = 7;
    pub const ARGMAX = 8;
    pub const SECURELVL = 9;
    pub const HOSTNAME = 10;
    pub const HOSTID = 11;
    pub const CLOCKRATE = 12;

    pub const PROF = 16;
    pub const POSIX1 = 17;
    pub const NGROUPS = 18;
    pub const JOB_CONTROL = 19;
    pub const SAVED_IDS = 20;
    pub const BOOTTIME = 21;
    pub const DOMAINNAME = 22;
    pub const MAXPARTITIONS = 23;
    pub const RAWPARTITION = 24;
    pub const MAXTHREAD = 25;
    pub const NTHREADS = 26;
    pub const OSVERSION = 27;
    pub const SOMAXCONN = 28;
    pub const SOMINCONN = 29;

    pub const NOSUIDCOREDUMP = 32;
    pub const FSYNC = 33;
    pub const SYSVMSG = 34;
    pub const SYSVSEM = 35;
    pub const SYSVSHM = 36;

    pub const MSGBUFSIZE = 38;
    pub const MALLOCSTATS = 39;
    pub const CPTIME = 40;
    pub const NCHSTATS = 41;
    pub const FORKSTAT = 42;
    pub const NSELCOLL = 43;
    pub const TTY = 44;
    pub const CCPU = 45;
    pub const FSCALE = 46;
    pub const NPROCS = 47;
    pub const MSGBUF = 48;
    pub const POOL = 49;
    pub const STACKGAPRANDOM = 50;
    pub const SYSVIPC_INFO = 51;
    pub const ALLOWKMEM = 52;
    pub const WITNESSWATCH = 53;
    pub const SPLASSERT = 54;
    pub const PROC_ARGS = 55;
    pub const NFILES = 56;
    pub const TTYCOUNT = 57;
    pub const NUMVNODES = 58;
    pub const MBSTAT = 59;
    pub const WITNESS = 60;
    pub const SEMINFO = 61;
    pub const SHMINFO = 62;
    pub const INTRCNT = 63;
    pub const WATCHDOG = 64;
    pub const ALLOWDT = 65;
    pub const PROC = 66;
    pub const MAXCLUSTERS = 67;
    pub const EVCOUNT = 68;
    pub const TIMECOUNTER = 69;
    pub const MAXLOCKSPERUID = 70;
    pub const CPTIME2 = 71;
    pub const CACHEPCT = 72;
    pub const FILE = 73;
    pub const WXABORT = 74;
    pub const CONSDEV = 75;
    pub const NETLIVELOCKS = 76;
    pub const POOL_DEBUG = 77;
    pub const PROC_CWD = 78;
    pub const PROC_NOBROADCASTKILL = 79;
    pub const PROC_VMMAP = 80;
    pub const GLOBAL_PTRACE = 81;
    pub const CONSBUFSIZE = 82;
    pub const CONSBUF = 83;
    pub const AUDIO = 84;
    pub const CPUSTATS = 85;
    pub const PFSTATUS = 86;
    pub const TIMEOUT_STATS = 87;
    pub const UTC_OFFSET = 88;
    pub const VIDEO = 89;

    pub const PROC_ALL = 0;
    pub const PROC_PID = 1;
    pub const PROC_PGRP = 2;
    pub const PROC_SESSION = 3;
    pub const PROC_TTY = 4;
    pub const PROC_UID = 5;
    pub const PROC_RUID = 6;
    pub const PROC_KTHREAD = 7;
    pub const PROC_SHOW_THREADS = 0x40000000;

    pub const PROC_ARGV = 1;
    pub const PROC_NARGV = 2;
    pub const PROC_ENV = 3;
    pub const PROC_NENV = 4;
};

pub const HW = struct {
    pub const MACHINE = 1;
    pub const MODEL = 2;
    pub const NCPU = 3;
    pub const BYTEORDER = 4;
    pub const PHYSMEM = 5;
    pub const USERMEM = 6;
    pub const PAGESIZE = 7;
    pub const DISKNAMES = 8;
    pub const DISKSTATS = 9;
    pub const DISKCOUNT = 10;
    pub const SENSORS = 11;
    pub const CPUSPEED = 12;
    pub const SETPERF = 13;
    pub const VENDOR = 14;
    pub const PRODUCT = 15;
    pub const VERSION = 16;
    pub const SERIALNO = 17;
    pub const UUID = 18;
    pub const PHYSMEM64 = 19;
    pub const USERMEM64 = 20;
    pub const NCPUFOUND = 21;
    pub const ALLOWPOWERDOWN = 22;
    pub const PERFPOLICY = 23;
    pub const SMT = 24;
    pub const NCPUONLINE = 25;
    pub const POWER = 26;
};

pub const PTHREAD_STACK_MIN = switch (builtin.cpu.arch) {
    .sparc64 => 1 << 13,
    .mips64 => 1 << 14,
    else => 1 << 12,
};
