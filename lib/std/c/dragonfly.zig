const builtin = @import("builtin");
const std = @import("../std.zig");
const assert = std.debug.assert;
const maxInt = std.math.maxInt;
const iovec = std.os.iovec;

extern "c" threadlocal var errno: c_int;
pub fn _errno() *c_int {
    return &errno;
}

pub extern "c" fn getdents(fd: c_int, buf_ptr: [*]u8, nbytes: usize) c_int;
pub extern "c" fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) c_int;
pub extern "c" fn getrandom(buf_ptr: [*]u8, buf_len: usize, flags: c_uint) isize;
pub extern "c" fn pipe2(fds: *[2]fd_t, flags: u32) c_int;
pub extern "c" fn arc4random_buf(buf: [*]u8, len: usize) void;

pub const dl_iterate_phdr_callback = *const fn (info: *dl_phdr_info, size: usize, data: ?*anyopaque) callconv(.C) c_int;
pub extern "c" fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*anyopaque) c_int;

pub extern "c" fn lwp_gettid() c_int;

pub extern "c" fn posix_memalign(memptr: *?*anyopaque, alignment: usize, size: usize) c_int;

pub const pthread_mutex_t = extern struct {
    inner: ?*anyopaque = null,
};
pub const pthread_cond_t = extern struct {
    inner: ?*anyopaque = null,
};

pub const pthread_attr_t = extern struct { // copied from freebsd
    __size: [56]u8,
    __align: c_long,
};

pub const sem_t = ?*opaque {};

pub extern "c" fn pthread_setname_np(thread: std.c.pthread_t, name: [*:0]const u8) E;
pub extern "c" fn pthread_getname_np(thread: std.c.pthread_t, name: [*:0]u8, len: usize) E;

pub extern "c" fn umtx_sleep(ptr: *const volatile c_int, value: c_int, timeout: c_int) c_int;
pub extern "c" fn umtx_wakeup(ptr: *const volatile c_int, count: c_int) c_int;

// See:
// - https://gitweb.dragonflybsd.org/dragonfly.git/blob/HEAD:/include/unistd.h
// - https://gitweb.dragonflybsd.org/dragonfly.git/blob/HEAD:/sys/sys/types.h
// TODO: mode_t should probably be changed to a u16, audit pid_t/off_t as well
pub const fd_t = c_int;
pub const pid_t = c_int;
pub const off_t = c_long;
pub const mode_t = c_uint;
pub const uid_t = u32;
pub const gid_t = u32;
pub const time_t = isize;
pub const suseconds_t = c_long;

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

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const PROT = struct {
    pub const NONE = 0;
    pub const READ = 1;
    pub const WRITE = 2;
    pub const EXEC = 4;
};

pub const MAP = struct {
    pub const FILE = 0;
    pub const FAILED = @as(*anyopaque, @ptrFromInt(maxInt(usize)));
    pub const ANONYMOUS = ANON;
    pub const COPY = PRIVATE;
    pub const SHARED = 1;
    pub const PRIVATE = 2;
    pub const FIXED = 16;
    pub const RENAME = 32;
    pub const NORESERVE = 64;
    pub const INHERIT = 128;
    pub const NOEXTEND = 256;
    pub const HASSEMAPHORE = 512;
    pub const STACK = 1024;
    pub const NOSYNC = 2048;
    pub const ANON = 4096;
    pub const VPAGETABLE = 8192;
    pub const TRYFIXED = 65536;
    pub const NOCORE = 131072;
    pub const SIZEALIGN = 262144;
};

pub const MSF = struct {
    pub const ASYNC = 1;
    pub const INVALIDATE = 2;
    pub const SYNC = 4;
};

pub const W = struct {
    pub const NOHANG = 0x0001;
    pub const UNTRACED = 0x0002;
    pub const CONTINUED = 0x0004;
    pub const STOPPED = UNTRACED;
    pub const NOWAIT = 0x0008;
    pub const EXITED = 0x0010;
    pub const TRAPPED = 0x0020;

    pub fn EXITSTATUS(s: u32) u8 {
        return @as(u8, @intCast((s & 0xff00) >> 8));
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
    pub fn IFSTOPPED(s: u32) bool {
        return @as(u16, @truncate((((s & 0xffff) *% 0x10001) >> 8))) > 0x7f00;
    }
    pub fn IFSIGNALED(s: u32) bool {
        return (s & 0xffff) -% 1 < 0xff;
    }
};

pub const SA = struct {
    pub const ONSTACK = 0x0001;
    pub const RESTART = 0x0002;
    pub const RESETHAND = 0x0004;
    pub const NODEFER = 0x0010;
    pub const NOCLDWAIT = 0x0020;
    pub const SIGINFO = 0x0040;
};

pub const PATH_MAX = 1024;
pub const NAME_MAX = 255;
pub const IOV_MAX = KERN.IOV_MAX;

pub const ino_t = c_ulong;

pub const Stat = extern struct {
    ino: ino_t,
    nlink: c_uint,
    dev: c_uint,
    mode: c_ushort,
    padding1: u16,
    uid: uid_t,
    gid: gid_t,
    rdev: c_uint,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    size: c_ulong,
    blocks: i64,
    blksize: u32,
    flags: u32,
    gen: u32,
    lspare: i32,
    qspare1: i64,
    qspare2: i64,
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
    tv_sec: c_long,
    tv_nsec: c_long,
};

pub const timeval = extern struct {
    /// seconds
    tv_sec: time_t,
    /// microseconds
    tv_usec: suseconds_t,
};

pub const CTL = struct {
    pub const UNSPEC = 0;
    pub const KERN = 1;
    pub const VM = 2;
    pub const VFS = 3;
    pub const NET = 4;
    pub const DEBUG = 5;
    pub const HW = 6;
    pub const MACHDEP = 7;
    pub const USER = 8;
    pub const LWKT = 10;
    pub const MAXID = 11;
    pub const MAXNAME = 12;
};

pub const KERN = struct {
    pub const PROC_ALL = 0;
    pub const OSTYPE = 1;
    pub const PROC_PID = 1;
    pub const OSRELEASE = 2;
    pub const PROC_PGRP = 2;
    pub const OSREV = 3;
    pub const PROC_SESSION = 3;
    pub const VERSION = 4;
    pub const PROC_TTY = 4;
    pub const MAXVNODES = 5;
    pub const PROC_UID = 5;
    pub const MAXPROC = 6;
    pub const PROC_RUID = 6;
    pub const MAXFILES = 7;
    pub const PROC_ARGS = 7;
    pub const ARGMAX = 8;
    pub const PROC_CWD = 8;
    pub const PROC_PATHNAME = 9;
    pub const SECURELVL = 9;
    pub const PROC_SIGTRAMP = 10;
    pub const HOSTNAME = 10;
    pub const HOSTID = 11;
    pub const CLOCKRATE = 12;
    pub const VNODE = 13;
    pub const PROC = 14;
    pub const FILE = 15;
    pub const PROC_FLAGMASK = 16;
    pub const PROF = 16;
    pub const PROC_FLAG_LWP = 16;
    pub const POSIX1 = 17;
    pub const NGROUPS = 18;
    pub const JOB_CONTROL = 19;
    pub const SAVED_IDS = 20;
    pub const BOOTTIME = 21;
    pub const NISDOMAINNAME = 22;
    pub const UPDATEINTERVAL = 23;
    pub const OSRELDATE = 24;
    pub const NTP_PLL = 25;
    pub const BOOTFILE = 26;
    pub const MAXFILESPERPROC = 27;
    pub const MAXPROCPERUID = 28;
    pub const DUMPDEV = 29;
    pub const IPC = 30;
    pub const DUMMY = 31;
    pub const PS_STRINGS = 32;
    pub const USRSTACK = 33;
    pub const LOGSIGEXIT = 34;
    pub const IOV_MAX = 35;
    pub const MAXPOSIXLOCKSPERUID = 36;
    pub const MAXID = 37;
};

pub const HOST_NAME_MAX = 255;

// access function
pub const F_OK = 0; // test for existence of file
pub const X_OK = 1; // test for execute or search permission
pub const W_OK = 2; // test for write permission
pub const R_OK = 4; // test for read permission

pub const O = struct {
    pub const RDONLY = 0;
    pub const NDELAY = NONBLOCK;
    pub const WRONLY = 1;
    pub const RDWR = 2;
    pub const ACCMODE = 3;
    pub const NONBLOCK = 4;
    pub const APPEND = 8;
    pub const SHLOCK = 16;
    pub const EXLOCK = 32;
    pub const ASYNC = 64;
    pub const FSYNC = 128;
    pub const SYNC = 128;
    pub const NOFOLLOW = 256;
    pub const CREAT = 512;
    pub const TRUNC = 1024;
    pub const EXCL = 2048;
    pub const NOCTTY = 32768;
    pub const DIRECT = 65536;
    pub const CLOEXEC = 131072;
    pub const FBLOCKING = 262144;
    pub const FNONBLOCKING = 524288;
    pub const FAPPEND = 1048576;
    pub const FOFFSET = 2097152;
    pub const FSYNCWRITE = 4194304;
    pub const FASYNCWRITE = 8388608;
    pub const DIRECTORY = 134217728;
};

pub const SEEK = struct {
    pub const SET = 0;
    pub const CUR = 1;
    pub const END = 2;
    pub const DATA = 3;
    pub const HOLE = 4;
};

pub const F = struct {
    pub const ULOCK = 0;
    pub const LOCK = 1;
    pub const TLOCK = 2;
    pub const TEST = 3;

    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const RDLCK = 1;
    pub const SETFD = 2;
    pub const UNLCK = 2;
    pub const WRLCK = 3;
    pub const GETFL = 3;
    pub const SETFL = 4;
    pub const GETOWN = 5;
    pub const SETOWN = 6;
    pub const GETLK = 7;
    pub const SETLK = 8;
    pub const SETLKW = 9;
    pub const DUP2FD = 10;
    pub const DUPFD_CLOEXEC = 17;
    pub const DUP2FD_CLOEXEC = 18;
    pub const GETPATH = 19;
};

pub const FD_CLOEXEC = 1;

pub const AT = struct {
    pub const FDCWD = -328243;
    pub const SYMLINK_NOFOLLOW = 1;
    pub const REMOVEDIR = 2;
    pub const EACCESS = 4;
    pub const SYMLINK_FOLLOW = 8;
};

pub const dirent = extern struct {
    d_fileno: c_ulong,
    d_namlen: u16,
    d_type: u8,
    d_unused1: u8,
    d_unused2: u32,
    d_name: [256]u8,

    pub fn reclen(self: dirent) u16 {
        return (@offsetOf(dirent, "d_name") + self.d_namlen + 1 + 7) & ~@as(u16, 7);
    }
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
    pub const DBF = 15;
};

pub const CLOCK = struct {
    pub const REALTIME = 0;
    pub const VIRTUAL = 1;
    pub const PROF = 2;
    pub const MONOTONIC = 4;
    pub const UPTIME = 5;
    pub const UPTIME_PRECISE = 7;
    pub const UPTIME_FAST = 8;
    pub const REALTIME_PRECISE = 9;
    pub const REALTIME_FAST = 10;
    pub const MONOTONIC_PRECISE = 11;
    pub const MONOTONIC_FAST = 12;
    pub const SECOND = 13;
    pub const THREAD_CPUTIME_ID = 14;
    pub const PROCESS_CPUTIME_ID = 15;
};

pub const sockaddr = extern struct {
    len: u8,
    family: sa_family_t,
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
};

pub const Kevent = extern struct {
    ident: usize,
    filter: c_short,
    flags: c_ushort,
    fflags: c_uint,
    data: isize,
    udata: usize,
};

pub const EVFILT_FS = -10;
pub const EVFILT_USER = -9;
pub const EVFILT_EXCEPT = -8;
pub const EVFILT_TIMER = -7;
pub const EVFILT_SIGNAL = -6;
pub const EVFILT_PROC = -5;
pub const EVFILT_VNODE = -4;
pub const EVFILT_AIO = -3;
pub const EVFILT_WRITE = -2;
pub const EVFILT_READ = -1;
pub const EVFILT_SYSCOUNT = 10;
pub const EVFILT_MARKER = 15;

pub const EV_ADD = 1;
pub const EV_DELETE = 2;
pub const EV_ENABLE = 4;
pub const EV_DISABLE = 8;
pub const EV_ONESHOT = 16;
pub const EV_CLEAR = 32;
pub const EV_RECEIPT = 64;
pub const EV_DISPATCH = 128;
pub const EV_NODATA = 4096;
pub const EV_FLAG1 = 8192;
pub const EV_ERROR = 16384;
pub const EV_EOF = 32768;
pub const EV_SYSFLAGS = 61440;

pub const NOTE_FFNOP = 0;
pub const NOTE_TRACK = 1;
pub const NOTE_DELETE = 1;
pub const NOTE_LOWAT = 1;
pub const NOTE_TRACKERR = 2;
pub const NOTE_OOB = 2;
pub const NOTE_WRITE = 2;
pub const NOTE_EXTEND = 4;
pub const NOTE_CHILD = 4;
pub const NOTE_ATTRIB = 8;
pub const NOTE_LINK = 16;
pub const NOTE_RENAME = 32;
pub const NOTE_REVOKE = 64;
pub const NOTE_PDATAMASK = 1048575;
pub const NOTE_FFLAGSMASK = 16777215;
pub const NOTE_TRIGGER = 16777216;
pub const NOTE_EXEC = 536870912;
pub const NOTE_FFAND = 1073741824;
pub const NOTE_FORK = 1073741824;
pub const NOTE_EXIT = 2147483648;
pub const NOTE_FFOR = 2147483648;
pub const NOTE_FFCTRLMASK = 3221225472;
pub const NOTE_FFCOPY = 3221225472;
pub const NOTE_PCTRLMASK = 4026531840;

pub const stack_t = extern struct {
    sp: [*]u8,
    size: isize,
    flags: i32,
};

pub const S = struct {
    pub const IREAD = IRUSR;
    pub const IEXEC = IXUSR;
    pub const IWRITE = IWUSR;
    pub const IXOTH = 1;
    pub const IWOTH = 2;
    pub const IROTH = 4;
    pub const IRWXO = 7;
    pub const IXGRP = 8;
    pub const IWGRP = 16;
    pub const IRGRP = 32;
    pub const IRWXG = 56;
    pub const IXUSR = 64;
    pub const IWUSR = 128;
    pub const IRUSR = 256;
    pub const IRWXU = 448;
    pub const ISTXT = 512;
    pub const BLKSIZE = 512;
    pub const ISVTX = 512;
    pub const ISGID = 1024;
    pub const ISUID = 2048;
    pub const IFIFO = 4096;
    pub const IFCHR = 8192;
    pub const IFDIR = 16384;
    pub const IFBLK = 24576;
    pub const IFREG = 32768;
    pub const IFDB = 36864;
    pub const IFLNK = 40960;
    pub const IFSOCK = 49152;
    pub const IFWHT = 57344;
    pub const IFMT = 61440;

    pub fn ISCHR(m: u32) bool {
        return m & IFMT == IFCHR;
    }
};

pub const BADSIG = SIG.ERR;

pub const SIG = struct {
    pub const DFL = @as(?Sigaction.handler_fn, @ptrFromInt(0));
    pub const IGN = @as(?Sigaction.handler_fn, @ptrFromInt(1));
    pub const ERR = @as(?Sigaction.handler_fn, @ptrFromInt(maxInt(usize)));

    pub const BLOCK = 1;
    pub const UNBLOCK = 2;
    pub const SETMASK = 3;

    pub const IOT = ABRT;
    pub const HUP = 1;
    pub const INT = 2;
    pub const QUIT = 3;
    pub const ILL = 4;
    pub const TRAP = 5;
    pub const ABRT = 6;
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
    pub const THR = 32;
    pub const CKPT = 33;
    pub const CKPTEXIT = 34;
};

pub const siginfo_t = extern struct {
    signo: c_int,
    errno: c_int,
    code: c_int,
    pid: c_int,
    uid: uid_t,
    status: c_int,
    addr: ?*anyopaque,
    value: sigval,
    band: c_long,
    __spare__: [7]c_int,
};

pub const sigval = extern union {
    sival_int: c_int,
    sival_ptr: ?*anyopaque,
};

pub const _SIG_WORDS = 4;

pub const sigset_t = extern struct {
    __bits: [_SIG_WORDS]c_uint,
};

pub const empty_sigset = sigset_t{ .__bits = [_]c_uint{0} ** _SIG_WORDS };

pub const sig_atomic_t = c_int;

pub const Sigaction = extern struct {
    pub const handler_fn = *const fn (c_int) align(1) callconv(.C) void;
    pub const sigaction_fn = *const fn (c_int, *const siginfo_t, ?*const anyopaque) callconv(.C) void;

    /// signal handler
    handler: extern union {
        handler: ?handler_fn,
        sigaction: ?sigaction_fn,
    },
    flags: c_uint,
    mask: sigset_t,
};

pub const sig_t = *const fn (c_int) callconv(.C) void;

pub const SOCK = struct {
    pub const STREAM = 1;
    pub const DGRAM = 2;
    pub const RAW = 3;
    pub const RDM = 4;
    pub const SEQPACKET = 5;
    pub const MAXADDRLEN = 255;
    pub const CLOEXEC = 0x10000000;
    pub const NONBLOCK = 0x20000000;
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
    pub const TIMESTAMP = 0x0400;
    pub const NOSIGPIPE = 0x0800;
    pub const ACCEPTFILTER = 0x1000;
    pub const RERROR = 0x2000;
    pub const PASSCRED = 0x4000;

    pub const SNDBUF = 0x1001;
    pub const RCVBUF = 0x1002;
    pub const SNDLOWAT = 0x1003;
    pub const RCVLOWAT = 0x1004;
    pub const SNDTIMEO = 0x1005;
    pub const RCVTIMEO = 0x1006;
    pub const ERROR = 0x1007;
    pub const TYPE = 0x1008;
    pub const SNDSPACE = 0x100a;
    pub const CPUHINT = 0x1030;
};

pub const SOL = struct {
    pub const SOCKET = 0xffff;
};

pub const PF = struct {
    pub const INET6 = AF.INET6;
    pub const IMPLINK = AF.IMPLINK;
    pub const ROUTE = AF.ROUTE;
    pub const ISO = AF.ISO;
    pub const PIP = AF.pseudo_PIP;
    pub const CHAOS = AF.CHAOS;
    pub const DATAKIT = AF.DATAKIT;
    pub const INET = AF.INET;
    pub const APPLETALK = AF.APPLETALK;
    pub const SIP = AF.SIP;
    pub const OSI = AF.ISO;
    pub const CNT = AF.CNT;
    pub const LINK = AF.LINK;
    pub const HYLINK = AF.HYLINK;
    pub const MAX = AF.MAX;
    pub const KEY = AF.pseudo_KEY;
    pub const PUP = AF.PUP;
    pub const COIP = AF.COIP;
    pub const SNA = AF.SNA;
    pub const LOCAL = AF.LOCAL;
    pub const NETBIOS = AF.NETBIOS;
    pub const NATM = AF.NATM;
    pub const BLUETOOTH = AF.BLUETOOTH;
    pub const UNSPEC = AF.UNSPEC;
    pub const NETGRAPH = AF.NETGRAPH;
    pub const ECMA = AF.ECMA;
    pub const IPX = AF.IPX;
    pub const DLI = AF.DLI;
    pub const ATM = AF.ATM;
    pub const CCITT = AF.CCITT;
    pub const ISDN = AF.ISDN;
    pub const RTIP = AF.pseudo_RTIP;
    pub const LAT = AF.LAT;
    pub const UNIX = PF.LOCAL;
    pub const XTP = AF.pseudo_XTP;
    pub const DECnet = AF.DECnet;
};

pub const AF = struct {
    pub const UNSPEC = 0;
    pub const OSI = ISO;
    pub const UNIX = LOCAL;
    pub const LOCAL = 1;
    pub const INET = 2;
    pub const IMPLINK = 3;
    pub const PUP = 4;
    pub const CHAOS = 5;
    pub const NETBIOS = 6;
    pub const ISO = 7;
    pub const ECMA = 8;
    pub const DATAKIT = 9;
    pub const CCITT = 10;
    pub const SNA = 11;
    pub const DLI = 13;
    pub const LAT = 14;
    pub const HYLINK = 15;
    pub const APPLETALK = 16;
    pub const ROUTE = 17;
    pub const LINK = 18;
    pub const COIP = 20;
    pub const CNT = 21;
    pub const IPX = 23;
    pub const SIP = 24;
    pub const ISDN = 26;
    pub const INET6 = 28;
    pub const NATM = 29;
    pub const ATM = 30;
    pub const NETGRAPH = 32;
    pub const BLUETOOTH = 33;
    pub const MPLS = 34;
    pub const MAX = 36;
};

pub const in_port_t = u16;
pub const sa_family_t = u8;
pub const socklen_t = u32;

pub const EAI = enum(c_int) {
    ADDRFAMILY = 1,
    AGAIN = 2,
    BADFLAGS = 3,
    FAIL = 4,
    FAMILY = 5,
    MEMORY = 6,
    NODATA = 7,
    NONAME = 8,
    SERVICE = 9,
    SOCKTYPE = 10,
    SYSTEM = 11,
    BADHINTS = 12,
    PROTOCOL = 13,
    OVERFLOW = 14,
    _,
};

pub const AI = struct {
    pub const PASSIVE = 0x00000001;
    pub const CANONNAME = 0x00000002;
    pub const NUMERICHOST = 0x00000004;
    pub const NUMERICSERV = 0x00000008;
    pub const MASK = PASSIVE | CANONNAME | NUMERICHOST | NUMERICSERV | ADDRCONFIG;
    pub const ALL = 0x00000100;
    pub const V4MAPPED_CFG = 0x00000200;
    pub const ADDRCONFIG = 0x00000400;
    pub const V4MAPPED = 0x00000800;
    pub const DEFAULT = V4MAPPED_CFG | ADDRCONFIG;
};

pub const RTLD = struct {
    pub const LAZY = 1;
    pub const NOW = 2;
    pub const MODEMASK = 0x3;
    pub const GLOBAL = 0x100;
    pub const LOCAL = 0;
    pub const TRACE = 0x200;
    pub const NODELETE = 0x01000;
    pub const NOLOAD = 0x02000;

    pub const NEXT = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));
    pub const DEFAULT = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -2)))));
    pub const SELF = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -3)))));
    pub const ALL = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -4)))));
};

pub const dl_phdr_info = extern struct {
    dlpi_addr: usize,
    dlpi_name: ?[*:0]const u8,
    dlpi_phdr: [*]std.elf.Phdr,
    dlpi_phnum: u16,
};
pub const cmsghdr = extern struct {
    cmsg_len: socklen_t,
    cmsg_level: c_int,
    cmsg_type: c_int,
};
pub const msghdr = extern struct {
    msg_name: ?*anyopaque,
    msg_namelen: socklen_t,
    msg_iov: [*]iovec,
    msg_iovlen: c_int,
    msg_control: ?*anyopaque,
    msg_controllen: socklen_t,
    msg_flags: c_int,
};
pub const cmsgcred = extern struct {
    cmcred_pid: pid_t,
    cmcred_uid: uid_t,
    cmcred_euid: uid_t,
    cmcred_gid: gid_t,
    cmcred_ngroups: c_short,
    cmcred_groups: [16]gid_t,
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

pub const MADV = struct {
    pub const SEQUENTIAL = 2;
    pub const CONTROL_END = SETMAP;
    pub const DONTNEED = 4;
    pub const RANDOM = 1;
    pub const WILLNEED = 3;
    pub const NORMAL = 0;
    pub const CONTROL_START = INVAL;
    pub const FREE = 5;
    pub const NOSYNC = 6;
    pub const AUTOSYNC = 7;
    pub const NOCORE = 8;
    pub const CORE = 9;
    pub const INVAL = 10;
    pub const SETMAP = 11;
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const UN = 8;
    pub const NB = 4;
};

pub const Flock = extern struct {
    start: off_t,
    len: off_t,
    pid: pid_t,
    type: c_short,
    whence: c_short,
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

pub const IPPROTO = struct {
    pub const IP = 0;
    pub const ICMP = 1;
    pub const TCP = 6;
    pub const UDP = 17;
    pub const IPV6 = 41;
    pub const RAW = 255;
    pub const HOPOPTS = 0;
    pub const IGMP = 2;
    pub const GGP = 3;
    pub const IPV4 = 4;
    pub const IPIP = IPV4;
    pub const ST = 7;
    pub const EGP = 8;
    pub const PIGP = 9;
    pub const RCCMON = 10;
    pub const NVPII = 11;
    pub const PUP = 12;
    pub const ARGUS = 13;
    pub const EMCON = 14;
    pub const XNET = 15;
    pub const CHAOS = 16;
    pub const MUX = 18;
    pub const MEAS = 19;
    pub const HMP = 20;
    pub const PRM = 21;
    pub const IDP = 22;
    pub const TRUNK1 = 23;
    pub const TRUNK2 = 24;
    pub const LEAF1 = 25;
    pub const LEAF2 = 26;
    pub const RDP = 27;
    pub const IRTP = 28;
    pub const TP = 29;
    pub const BLT = 30;
    pub const NSP = 31;
    pub const INP = 32;
    pub const SEP = 33;
    pub const @"3PC" = 34;
    pub const IDPR = 35;
    pub const XTP = 36;
    pub const DDP = 37;
    pub const CMTP = 38;
    pub const TPXX = 39;
    pub const IL = 40;
    pub const SDRP = 42;
    pub const ROUTING = 43;
    pub const FRAGMENT = 44;
    pub const IDRP = 45;
    pub const RSVP = 46;
    pub const GRE = 47;
    pub const MHRP = 48;
    pub const BHA = 49;
    pub const ESP = 50;
    pub const AH = 51;
    pub const INLSP = 52;
    pub const SWIPE = 53;
    pub const NHRP = 54;
    pub const MOBILE = 55;
    pub const TLSP = 56;
    pub const SKIP = 57;
    pub const ICMPV6 = 58;
    pub const NONE = 59;
    pub const DSTOPTS = 60;
    pub const AHIP = 61;
    pub const CFTP = 62;
    pub const HELLO = 63;
    pub const SATEXPAK = 64;
    pub const KRYPTOLAN = 65;
    pub const RVD = 66;
    pub const IPPC = 67;
    pub const ADFS = 68;
    pub const SATMON = 69;
    pub const VISA = 70;
    pub const IPCV = 71;
    pub const CPNX = 72;
    pub const CPHB = 73;
    pub const WSN = 74;
    pub const PVP = 75;
    pub const BRSATMON = 76;
    pub const ND = 77;
    pub const WBMON = 78;
    pub const WBEXPAK = 79;
    pub const EON = 80;
    pub const VMTP = 81;
    pub const SVMTP = 82;
    pub const VINES = 83;
    pub const TTP = 84;
    pub const IGP = 85;
    pub const DGP = 86;
    pub const TCF = 87;
    pub const IGRP = 88;
    pub const OSPFIGP = 89;
    pub const SRPC = 90;
    pub const LARP = 91;
    pub const MTP = 92;
    pub const AX25 = 93;
    pub const IPEIP = 94;
    pub const MICP = 95;
    pub const SCCSP = 96;
    pub const ETHERIP = 97;
    pub const ENCAP = 98;
    pub const APES = 99;
    pub const GMTP = 100;
    pub const IPCOMP = 108;
    pub const PIM = 103;
    pub const CARP = 112;
    pub const PGM = 113;
    pub const PFSYNC = 240;
    pub const DIVERT = 254;
    pub const MAX = 256;
    pub const DONE = 257;
    pub const UNKNOWN = 258;
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
    POSIXLOCKS = 11,
    _,

    pub const AS: rlimit_resource = .VMEM;
};

pub const rlim_t = i64;

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
    /// Requestable events.
    pub const IN = 0x0001;
    pub const PRI = 0x0002;
    pub const OUT = 0x0004;
    pub const RDNORM = 0x0040;
    pub const WRNORM = OUT;
    pub const RDBAND = 0x0080;
    pub const WRBAND = 0x0100;

    /// These events are set if they occur regardless of whether they were requested.
    pub const ERR = 0x0008;
    pub const HUP = 0x0010;
    pub const NVAL = 0x0020;
};
