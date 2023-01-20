//! The reference for these types and values is Microsoft Windows's ucrt (Universal C RunTime).
const std = @import("../std.zig");
const ws2_32 = std.os.windows.ws2_32;
const windows = std.os.windows;

pub extern "c" fn _errno() *c_int;

pub extern "c" fn _msize(memblock: ?*anyopaque) usize;

// TODO: copied the else case and removed the socket function (because its in ws2_32)
//       need to verify which of these is actually supported on windows
pub extern "c" fn clock_getres(clk_id: c_int, tp: *timespec) c_int;
pub extern "c" fn clock_gettime(clk_id: c_int, tp: *timespec) c_int;
pub extern "c" fn fstat(fd: fd_t, buf: *Stat) c_int;
pub extern "c" fn getrusage(who: c_int, usage: *rusage) c_int;
pub extern "c" fn gettimeofday(noalias tv: ?*timeval, noalias tz: ?*timezone) c_int;
pub extern "c" fn nanosleep(rqtp: *const timespec, rmtp: ?*timespec) c_int;
pub extern "c" fn sched_yield() c_int;
pub extern "c" fn sigaction(sig: c_int, noalias act: ?*const Sigaction, noalias oact: ?*Sigaction) c_int;
pub extern "c" fn sigprocmask(how: c_int, noalias set: ?*const sigset_t, noalias oset: ?*sigset_t) c_int;
pub extern "c" fn stat(noalias path: [*:0]const u8, noalias buf: *Stat) c_int;
pub extern "c" fn sigfillset(set: ?*sigset_t) void;
pub extern "c" fn alarm(seconds: c_uint) c_uint;
pub extern "c" fn sigwait(set: ?*sigset_t, sig: ?*c_int) c_int;

pub const fd_t = windows.HANDLE;
pub const ino_t = windows.LARGE_INTEGER;
pub const pid_t = windows.HANDLE;
pub const mode_t = u0;

pub const PATH_MAX = 260;

pub const time_t = c_longlong;

pub const timespec = extern struct {
    tv_sec: time_t,
    tv_nsec: c_long,
};

pub const timeval = extern struct {
    tv_sec: c_long,
    tv_usec: c_long,
};

pub const Stat = @compileError("TODO windows Stat definition");

pub const sig_atomic_t = c_int;

pub const sigset_t = @compileError("TODO windows sigset_t definition");
pub const Sigaction = @compileError("TODO windows Sigaction definition");
pub const timezone = @compileError("TODO windows timezone definition");
pub const rusage = @compileError("TODO windows rusage definition");

/// maximum signal number + 1
pub const NSIG = 23;

/// Signal types
pub const SIG = struct {
    /// interrupt
    pub const INT = 2;
    /// illegal instruction - invalid function image
    pub const ILL = 4;
    /// floating point exception
    pub const FPE = 8;
    /// segment violation
    pub const SEGV = 11;
    /// Software termination signal from kill
    pub const TERM = 15;
    /// Ctrl-Break sequence
    pub const BREAK = 21;
    /// abnormal termination triggered by abort call
    pub const ABRT = 22;
    /// SIGABRT compatible with other platforms, same as SIGABRT
    pub const ABRT_COMPAT = 6;

    // Signal action codes
    /// default signal action
    pub const DFL = 0;
    /// ignore signal
    pub const IGN = 1;
    /// return current value
    pub const GET = 2;
    /// signal gets error
    pub const SGE = 3;
    /// acknowledge
    pub const ACK = 4;
    /// Signal error value (returned by signal call on error)
    pub const ERR = -1;
};

pub const SEEK = struct {
    pub const SET = 0;
    pub const CUR = 1;
    pub const END = 2;
};

/// Basic memory protection flags
pub const PROT = struct {
    /// page can not be accessed
    pub const NONE = 0x0;
    /// page can be read
    pub const READ = 0x1;
    /// page can be written
    pub const WRITE = 0x2;
    /// page can be executed
    pub const EXEC = 0x4;
};

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
    AGAIN = 11,
    NOMEM = 12,
    ACCES = 13,
    FAULT = 14,
    BUSY = 16,
    EXIST = 17,
    XDEV = 18,
    NODEV = 19,
    NOTDIR = 20,
    ISDIR = 21,
    NFILE = 23,
    MFILE = 24,
    NOTTY = 25,
    FBIG = 27,
    NOSPC = 28,
    SPIPE = 29,
    ROFS = 30,
    MLINK = 31,
    PIPE = 32,
    DOM = 33,
    /// Also means `DEADLOCK`.
    DEADLK = 36,
    NAMETOOLONG = 38,
    NOLCK = 39,
    NOSYS = 40,
    NOTEMPTY = 41,

    INVAL = 22,
    RANGE = 34,
    ILSEQ = 42,

    // POSIX Supplement
    ADDRINUSE = 100,
    ADDRNOTAVAIL = 101,
    AFNOSUPPORT = 102,
    ALREADY = 103,
    BADMSG = 104,
    CANCELED = 105,
    CONNABORTED = 106,
    CONNREFUSED = 107,
    CONNRESET = 108,
    DESTADDRREQ = 109,
    HOSTUNREACH = 110,
    IDRM = 111,
    INPROGRESS = 112,
    ISCONN = 113,
    LOOP = 114,
    MSGSIZE = 115,
    NETDOWN = 116,
    NETRESET = 117,
    NETUNREACH = 118,
    NOBUFS = 119,
    NODATA = 120,
    NOLINK = 121,
    NOMSG = 122,
    NOPROTOOPT = 123,
    NOSR = 124,
    NOSTR = 125,
    NOTCONN = 126,
    NOTRECOVERABLE = 127,
    NOTSOCK = 128,
    NOTSUP = 129,
    OPNOTSUPP = 130,
    OTHER = 131,
    OVERFLOW = 132,
    OWNERDEAD = 133,
    PROTO = 134,
    PROTONOSUPPORT = 135,
    PROTOTYPE = 136,
    TIME = 137,
    TIMEDOUT = 138,
    TXTBSY = 139,
    WOULDBLOCK = 140,
    DQUOT = 10069,
    _,
};

pub const STRUNCATE = 80;

pub const F_OK = 0;

/// Remove directory instead of unlinking file
pub const AT = struct {
    pub const REMOVEDIR = 0x200;
};

pub const in_port_t = u16;
pub const sa_family_t = ws2_32.ADDRESS_FAMILY;
pub const socklen_t = ws2_32.socklen_t;

pub const sockaddr = ws2_32.sockaddr;

pub const in6_addr = [16]u8;
pub const in_addr = u32;

pub const addrinfo = ws2_32.addrinfo;
pub const AF = ws2_32.AF;
pub const MSG = ws2_32.MSG;
pub const SOCK = ws2_32.SOCK;
pub const TCP = ws2_32.TCP;
pub const IPPROTO = ws2_32.IPPROTO;
pub const BTHPROTO_RFCOMM = ws2_32.BTHPROTO_RFCOMM;

pub const nfds_t = c_ulong;
pub const pollfd = ws2_32.pollfd;
pub const POLL = ws2_32.POLL;
pub const SOL = ws2_32.SOL;
pub const SO = ws2_32.SO;
pub const PVD_CONFIG = ws2_32.PVD_CONFIG;

pub const O = struct {
    pub const RDONLY = 0o0;
    pub const WRONLY = 0o1;
    pub const RDWR = 0o2;

    pub const CREAT = 0o100;
    pub const EXCL = 0o200;
    pub const NOCTTY = 0o400;
    pub const TRUNC = 0o1000;
    pub const APPEND = 0o2000;
    pub const NONBLOCK = 0o4000;
    pub const DSYNC = 0o10000;
    pub const SYNC = 0o4010000;
    pub const RSYNC = 0o4010000;
    pub const DIRECTORY = 0o200000;
    pub const NOFOLLOW = 0o400000;
    pub const CLOEXEC = 0o2000000;

    pub const ASYNC = 0o20000;
    pub const DIRECT = 0o40000;
    pub const LARGEFILE = 0;
    pub const NOATIME = 0o1000000;
    pub const PATH = 0o10000000;
    pub const TMPFILE = 0o20200000;
    pub const NDELAY = NONBLOCK;
};

pub const IFNAMESIZE = 30;
