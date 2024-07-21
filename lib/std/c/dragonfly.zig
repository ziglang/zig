const std = @import("../std.zig");

const SIG = std.c.SIG;
const gid_t = std.c.gid_t;
const iovec = std.c.iovec;
const pid_t = std.c.pid_t;
const socklen_t = std.c.socklen_t;
const uid_t = std.c.uid_t;

pub extern "c" fn lwp_gettid() c_int;
pub extern "c" fn umtx_sleep(ptr: *const volatile c_int, value: c_int, timeout: c_int) c_int;
pub extern "c" fn umtx_wakeup(ptr: *const volatile c_int, count: c_int) c_int;

pub const mcontext_t = extern struct {
    onstack: register_t, // XXX - sigcontext compat.
    rdi: register_t,
    rsi: register_t,
    rdx: register_t,
    rcx: register_t,
    r8: register_t,
    r9: register_t,
    rax: register_t,
    rbx: register_t,
    rbp: register_t,
    r10: register_t,
    r11: register_t,
    r12: register_t,
    r13: register_t,
    r14: register_t,
    r15: register_t,
    xflags: register_t,
    trapno: register_t,
    addr: register_t,
    flags: register_t,
    err: register_t,
    rip: register_t,
    cs: register_t,
    rflags: register_t,
    rsp: register_t, // machine state
    ss: register_t,

    len: c_uint, // sizeof(mcontext_t)
    fpformat: c_uint,
    ownedfp: c_uint,
    reserved: c_uint,
    unused: [8]c_uint,

    // NOTE! 64-byte aligned as of here. Also must match savefpu structure.
    fpregs: [256]c_int align(64),
};

pub const register_t = isize;

pub const E = enum(u16) {
    /// No error occurred.
    SUCCESS = 0,

    PERM = 1,
    NOENT = 2,
    SRCH = 3,
    INTR = 4,
    IO = 5,
    NXIO = 6,
    @"2BIG" = 7,
    NOEXEC = 8,
    BADF = 9,
    CHILD = 10,
    DEADLK = 11,
    NOMEM = 12,
    ACCES = 13,
    FAULT = 14,
    NOTBLK = 15,
    BUSY = 16,
    EXIST = 17,
    XDEV = 18,
    NODEV = 19,
    NOTDIR = 20,
    ISDIR = 21,
    INVAL = 22,
    NFILE = 23,
    MFILE = 24,
    NOTTY = 25,
    TXTBSY = 26,
    FBIG = 27,
    NOSPC = 28,
    SPIPE = 29,
    ROFS = 30,
    MLINK = 31,
    PIPE = 32,
    DOM = 33,
    RANGE = 34,
    /// This code is also used for `WOULDBLOCK`.
    AGAIN = 35,
    INPROGRESS = 36,
    ALREADY = 37,
    NOTSOCK = 38,
    DESTADDRREQ = 39,
    MSGSIZE = 40,
    PROTOTYPE = 41,
    NOPROTOOPT = 42,
    PROTONOSUPPORT = 43,
    SOCKTNOSUPPORT = 44,
    /// This code is also used for `NOTSUP`.
    OPNOTSUPP = 45,
    PFNOSUPPORT = 46,
    AFNOSUPPORT = 47,
    ADDRINUSE = 48,
    ADDRNOTAVAIL = 49,
    NETDOWN = 50,
    NETUNREACH = 51,
    NETRESET = 52,
    CONNABORTED = 53,
    CONNRESET = 54,
    NOBUFS = 55,
    ISCONN = 56,
    NOTCONN = 57,
    SHUTDOWN = 58,
    TOOMANYREFS = 59,
    TIMEDOUT = 60,
    CONNREFUSED = 61,
    LOOP = 62,
    NAMETOOLONG = 63,
    HOSTDOWN = 64,
    HOSTUNREACH = 65,
    NOTEMPTY = 66,
    PROCLIM = 67,
    USERS = 68,
    DQUOT = 69,
    STALE = 70,
    REMOTE = 71,
    BADRPC = 72,
    RPCMISMATCH = 73,
    PROGUNAVAIL = 74,
    PROGMISMATCH = 75,
    PROCUNAVAIL = 76,
    NOLCK = 77,
    NOSYS = 78,
    FTYPE = 79,
    AUTH = 80,
    NEEDAUTH = 81,
    IDRM = 82,
    NOMSG = 83,
    OVERFLOW = 84,
    CANCELED = 85,
    ILSEQ = 86,
    NOATTR = 87,
    DOOFUS = 88,
    BADMSG = 89,
    MULTIHOP = 90,
    NOLINK = 91,
    PROTO = 92,
    NOMEDIUM = 93,
    ASYNC = 99,
    _,
};

pub const BADSIG = SIG.ERR;

pub const sig_t = *const fn (i32) callconv(.C) void;

pub const cmsghdr = extern struct {
    len: socklen_t,
    level: c_int,
    type: c_int,
};

pub const cmsgcred = extern struct {
    pid: pid_t,
    uid: uid_t,
    euid: uid_t,
    gid: gid_t,
    ngroups: c_short,
    groups: [16]gid_t,
};
pub const sf_hdtr = extern struct {
    headers: [*]iovec,
    hdr_cnt: c_int,
    trailers: [*]iovec,
    trl_cnt: c_int,
};

pub const MS_SYNC = 0;
pub const MS_ASYNC = 1;
pub const MS_INVALIDATE = 2;

pub const POSIX_MADV_SEQUENTIAL = 2;
pub const POSIX_MADV_RANDOM = 1;
pub const POSIX_MADV_DONTNEED = 4;
pub const POSIX_MADV_NORMAL = 0;
pub const POSIX_MADV_WILLNEED = 3;
