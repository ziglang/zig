const std = @import("../std.zig");
const assert = std.debug.assert;
const maxInt = std.math.maxInt;
const builtin = @import("builtin");
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;
const passwd = std.c.passwd;
const timespec = std.c.timespec;
const uid_t = std.c.uid_t;
const pid_t = std.c.pid_t;

comptime {
    assert(builtin.os.tag == .openbsd); // Prevent access of std.c symbols on wrong OS.
}

pub const pthread_spinlock_t = extern struct {
    inner: ?*anyopaque = null,
};

pub extern "c" fn pledge(promises: ?[*:0]const u8, execpromises: ?[*:0]const u8) c_int;
pub extern "c" fn unveil(path: ?[*:0]const u8, permissions: ?[*:0]const u8) c_int;
pub extern "c" fn getthrid() pid_t;

pub const FUTEX = struct {
    pub const WAIT = 1;
    pub const WAKE = 2;
    pub const REQUEUE = 3;
    pub const PRIVATE_FLAG = 128;
};
pub extern "c" fn futex(uaddr: ?*const volatile u32, op: c_int, val: c_int, timeout: ?*const timespec, uaddr2: ?*const volatile u32) c_int;

pub const login_cap_t = extern struct {
    class: ?[*:0]const u8,
    cap: ?[*:0]const u8,
    style: ?[*:0]const u8,
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

pub const auth_item_t = enum(c_int) {
    ALL = 0,
    CHALLENGE = 1,
    CLASS = 2,
    NAME = 3,
    SERVICE = 4,
    STYLE = 5,
    INTERACTIVE = 6,
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

pub const TCFLUSH = enum(u32) {
    none = 0,
    I = 1,
    O = 2,
    IO = 3,
};

pub const TCIO = enum(u32) {
    OOFF = 1,
    OON = 2,
    IOFF = 3,
    ION = 4,
};

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

pub const MAX_PAGE_SHIFT = switch (builtin.cpu.arch) {
    .x86 => 12,
    .sparc64 => 13,
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
