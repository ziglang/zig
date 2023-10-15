const std = @import("std");
const builtin = @import("builtin");
const wasi = std.os.wasi;
const iovec = std.os.iovec;
const iovec_const = std.os.iovec_const;
const c = std.c;

pub const FILE = c.FILE;

var __stack_chk_guard: usize = 0;
fn __stack_chk_fail() callconv(.C) void {
    std.debug.print("stack smashing detected: terminated\n", .{});
    emscripten_force_exit(127);
}

comptime {
    if (builtin.os.tag == .emscripten) {
        if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
            // Emscripten does not provide these symbols, so we must export our own
            @export(__stack_chk_guard, .{ .name = "__stack_chk_guard", .linkage = .Strong });
            @export(__stack_chk_fail, .{ .name = "__stack_chk_fail", .linkage = .Strong });
        }
    }
}

pub const PF = struct {
    pub const UNSPEC = 0;
    pub const LOCAL = 1;
    pub const UNIX = LOCAL;
    pub const FILE = LOCAL;
    pub const INET = 2;
    pub const AX25 = 3;
    pub const IPX = 4;
    pub const APPLETALK = 5;
    pub const NETROM = 6;
    pub const BRIDGE = 7;
    pub const ATMPVC = 8;
    pub const X25 = 9;
    pub const INET6 = 10;
    pub const ROSE = 11;
    pub const DECnet = 12;
    pub const NETBEUI = 13;
    pub const SECURITY = 14;
    pub const KEY = 15;
    pub const NETLINK = 16;
    pub const ROUTE = PF.NETLINK;
    pub const PACKET = 17;
    pub const ASH = 18;
    pub const ECONET = 19;
    pub const ATMSVC = 20;
    pub const RDS = 21;
    pub const SNA = 22;
    pub const IRDA = 23;
    pub const PPPOX = 24;
    pub const WANPIPE = 25;
    pub const LLC = 26;
    pub const IB = 27;
    pub const MPLS = 28;
    pub const CAN = 29;
    pub const TIPC = 30;
    pub const BLUETOOTH = 31;
    pub const IUCV = 32;
    pub const RXRPC = 33;
    pub const ISDN = 34;
    pub const PHONET = 35;
    pub const IEEE802154 = 36;
    pub const CAIF = 37;
    pub const ALG = 38;
    pub const NFC = 39;
    pub const VSOCK = 40;
    pub const KCM = 41;
    pub const QIPCRTR = 42;
    pub const SMC = 43;
    pub const XDP = 44;
    pub const MAX = 45;
};

pub const AF = struct {
    pub const UNSPEC = PF.UNSPEC;
    pub const LOCAL = PF.LOCAL;
    pub const UNIX = AF.LOCAL;
    pub const FILE = AF.LOCAL;
    pub const INET = PF.INET;
    pub const AX25 = PF.AX25;
    pub const IPX = PF.IPX;
    pub const APPLETALK = PF.APPLETALK;
    pub const NETROM = PF.NETROM;
    pub const BRIDGE = PF.BRIDGE;
    pub const ATMPVC = PF.ATMPVC;
    pub const X25 = PF.X25;
    pub const INET6 = PF.INET6;
    pub const ROSE = PF.ROSE;
    pub const DECnet = PF.DECnet;
    pub const NETBEUI = PF.NETBEUI;
    pub const SECURITY = PF.SECURITY;
    pub const KEY = PF.KEY;
    pub const NETLINK = PF.NETLINK;
    pub const ROUTE = PF.ROUTE;
    pub const PACKET = PF.PACKET;
    pub const ASH = PF.ASH;
    pub const ECONET = PF.ECONET;
    pub const ATMSVC = PF.ATMSVC;
    pub const RDS = PF.RDS;
    pub const SNA = PF.SNA;
    pub const IRDA = PF.IRDA;
    pub const PPPOX = PF.PPPOX;
    pub const WANPIPE = PF.WANPIPE;
    pub const LLC = PF.LLC;
    pub const IB = PF.IB;
    pub const MPLS = PF.MPLS;
    pub const CAN = PF.CAN;
    pub const TIPC = PF.TIPC;
    pub const BLUETOOTH = PF.BLUETOOTH;
    pub const IUCV = PF.IUCV;
    pub const RXRPC = PF.RXRPC;
    pub const ISDN = PF.ISDN;
    pub const PHONET = PF.PHONET;
    pub const IEEE802154 = PF.IEEE802154;
    pub const CAIF = PF.CAIF;
    pub const ALG = PF.ALG;
    pub const NFC = PF.NFC;
    pub const VSOCK = PF.VSOCK;
    pub const KCM = PF.KCM;
    pub const QIPCRTR = PF.QIPCRTR;
    pub const SMC = PF.SMC;
    pub const XDP = PF.XDP;
    pub const MAX = PF.MAX;
};

pub const AT = struct {
    pub const FDCWD = -100;
    pub const SYMLINK_NOFOLLOW = 0x100;
    pub const REMOVEDIR = 0x200;
    pub const SYMLINK_FOLLOW = 0x400;
    pub const NO_AUTOMOUNT = 0x800;
    pub const EMPTY_PATH = 0x1000;
    pub const STATX_SYNC_TYPE = 0x6000;
    pub const STATX_SYNC_AS_STAT = 0x0000;
    pub const STATX_FORCE_SYNC = 0x2000;
    pub const STATX_DONT_SYNC = 0x4000;
    pub const RECURSIVE = 0x8000;
};

pub const CLOCK = struct {
    pub const REALTIME = 0;
    pub const MONOTONIC = 1;
    pub const PROCESS_CPUTIME_ID = 2;
    pub const THREAD_CPUTIME_ID = 3;
    pub const MONOTONIC_RAW = 4;
    pub const REALTIME_COARSE = 5;
    pub const MONOTONIC_COARSE = 6;
    pub const BOOTTIME = 7;
    pub const REALTIME_ALARM = 8;
    pub const BOOTTIME_ALARM = 9;
    pub const SGI_CYCLE = 10;
    pub const TAI = 11;
};

pub const CPU_SETSIZE = 128;
pub const cpu_set_t = [CPU_SETSIZE / @sizeOf(usize)]usize;
pub const cpu_count_t = std.meta.Int(.unsigned, std.math.log2(CPU_SETSIZE * 8));

pub fn CPU_COUNT(set: cpu_set_t) cpu_count_t {
    var sum: cpu_count_t = 0;
    for (set) |x| {
        sum += @popCount(x);
    }
    return sum;
}

pub const E = enum(u16) {
    SUCCESS = @intFromEnum(wasi.E.SUCCESS),
    @"2BIG" = @intFromEnum(wasi.E.@"2BIG"),
    ACCES = @intFromEnum(wasi.E.ACCES),
    ADDRINUSE = @intFromEnum(wasi.E.ADDRINUSE),
    ADDRNOTAVAIL = @intFromEnum(wasi.E.ADDRNOTAVAIL),
    AFNOSUPPORT = @intFromEnum(wasi.E.AFNOSUPPORT),
    /// This is also the error code used for `WOULDBLOCK`.
    AGAIN = @intFromEnum(wasi.E.AGAIN),
    ALREADY = @intFromEnum(wasi.E.ALREADY),
    BADF = @intFromEnum(wasi.E.BADF),
    BADMSG = @intFromEnum(wasi.E.BADMSG),
    BUSY = @intFromEnum(wasi.E.BUSY),
    CANCELED = @intFromEnum(wasi.E.CANCELED),
    CHILD = @intFromEnum(wasi.E.CHILD),
    CONNABORTED = @intFromEnum(wasi.E.CONNABORTED),
    CONNREFUSED = @intFromEnum(wasi.E.CONNREFUSED),
    CONNRESET = @intFromEnum(wasi.E.CONNRESET),
    DEADLK = @intFromEnum(wasi.E.DEADLK),
    DESTADDRREQ = @intFromEnum(wasi.E.DESTADDRREQ),
    DOM = @intFromEnum(wasi.E.DOM),
    DQUOT = @intFromEnum(wasi.E.DQUOT),
    EXIST = @intFromEnum(wasi.E.EXIST),
    FAULT = @intFromEnum(wasi.E.FAULT),
    FBIG = @intFromEnum(wasi.E.FBIG),
    HOSTUNREACH = @intFromEnum(wasi.E.HOSTUNREACH),
    IDRM = @intFromEnum(wasi.E.IDRM),
    ILSEQ = @intFromEnum(wasi.E.ILSEQ),
    INPROGRESS = @intFromEnum(wasi.E.INPROGRESS),
    INTR = @intFromEnum(wasi.E.INTR),
    INVAL = @intFromEnum(wasi.E.INVAL),
    IO = @intFromEnum(wasi.E.IO),
    ISCONN = @intFromEnum(wasi.E.ISCONN),
    ISDIR = @intFromEnum(wasi.E.ISDIR),
    LOOP = @intFromEnum(wasi.E.LOOP),
    MFILE = @intFromEnum(wasi.E.MFILE),
    MLINK = @intFromEnum(wasi.E.MLINK),
    MSGSIZE = @intFromEnum(wasi.E.MSGSIZE),
    MULTIHOP = @intFromEnum(wasi.E.MULTIHOP),
    NAMETOOLONG = @intFromEnum(wasi.E.NAMETOOLONG),
    NETDOWN = @intFromEnum(wasi.E.NETDOWN),
    NETRESET = @intFromEnum(wasi.E.NETRESET),
    NETUNREACH = @intFromEnum(wasi.E.NETUNREACH),
    NFILE = @intFromEnum(wasi.E.NFILE),
    NOBUFS = @intFromEnum(wasi.E.NOBUFS),
    NODEV = @intFromEnum(wasi.E.NODEV),
    NOENT = @intFromEnum(wasi.E.NOENT),
    NOEXEC = @intFromEnum(wasi.E.NOEXEC),
    NOLCK = @intFromEnum(wasi.E.NOLCK),
    NOLINK = @intFromEnum(wasi.E.NOLINK),
    NOMEM = @intFromEnum(wasi.E.NOMEM),
    NOMSG = @intFromEnum(wasi.E.NOMSG),
    NOPROTOOPT = @intFromEnum(wasi.E.NOPROTOOPT),
    NOSPC = @intFromEnum(wasi.E.NOSPC),
    NOSYS = @intFromEnum(wasi.E.NOSYS),
    NOTCONN = @intFromEnum(wasi.E.NOTCONN),
    NOTDIR = @intFromEnum(wasi.E.NOTDIR),
    NOTEMPTY = @intFromEnum(wasi.E.NOTEMPTY),
    NOTRECOVERABLE = @intFromEnum(wasi.E.NOTRECOVERABLE),
    NOTSOCK = @intFromEnum(wasi.E.NOTSOCK),
    /// This is also the code used for `NOTSUP`.
    OPNOTSUPP = @intFromEnum(wasi.E.OPNOTSUPP),
    NOTTY = @intFromEnum(wasi.E.NOTTY),
    NXIO = @intFromEnum(wasi.E.NXIO),
    OVERFLOW = @intFromEnum(wasi.E.OVERFLOW),
    OWNERDEAD = @intFromEnum(wasi.E.OWNERDEAD),
    PERM = @intFromEnum(wasi.E.PERM),
    PIPE = @intFromEnum(wasi.E.PIPE),
    PROTO = @intFromEnum(wasi.E.PROTO),
    PROTONOSUPPORT = @intFromEnum(wasi.E.PROTONOSUPPORT),
    PROTOTYPE = @intFromEnum(wasi.E.PROTOTYPE),
    RANGE = @intFromEnum(wasi.E.RANGE),
    ROFS = @intFromEnum(wasi.E.ROFS),
    SPIPE = @intFromEnum(wasi.E.SPIPE),
    SRCH = @intFromEnum(wasi.E.SRCH),
    STALE = @intFromEnum(wasi.E.STALE),
    TIMEDOUT = @intFromEnum(wasi.E.TIMEDOUT),
    TXTBSY = @intFromEnum(wasi.E.TXTBSY),
    XDEV = @intFromEnum(wasi.E.XDEV),
    NOTCAPABLE = @intFromEnum(wasi.E.NOTCAPABLE),

    ENOSTR = 100,
    EBFONT = 101,
    EBADSLT = 102,
    EBADRQC = 103,
    ENOANO = 104,
    ENOTBLK = 105,
    ECHRNG = 106,
    EL3HLT = 107,
    EL3RST = 108,
    ELNRNG = 109,
    EUNATCH = 110,
    ENOCSI = 111,
    EL2HLT = 112,
    EBADE = 113,
    EBADR = 114,
    EXFULL = 115,
    ENODATA = 116,
    ETIME = 117,
    ENOSR = 118,
    ENONET = 119,
    ENOPKG = 120,
    EREMOTE = 121,
    EADV = 122,
    ESRMNT = 123,
    ECOMM = 124,
    EDOTDOT = 125,
    ENOTUNIQ = 126,
    EBADFD = 127,
    EREMCHG = 128,
    ELIBACC = 129,
    ELIBBAD = 130,
    ELIBSCN = 131,
    ELIBMAX = 132,
    ELIBEXEC = 133,
    ERESTART = 134,
    ESTRPIPE = 135,
    EUSERS = 136,
    ESOCKTNOSUPPORT = 137,
    EOPNOTSUPP = 138,
    EPFNOSUPPORT = 139,
    ESHUTDOWN = 140,
    ETOOMANYREFS = 141,
    EHOSTDOWN = 142,
    EUCLEAN = 143,
    ENOTNAM = 144,
    ENAVAIL = 145,
    EISNAM = 146,
    EREMOTEIO = 147,
    ENOMEDIUM = 148,
    EMEDIUMTYPE = 149,
    ENOKEY = 150,
    EKEYEXPIRED = 151,
    EKEYREVOKED = 152,
    EKEYREJECTED = 153,
    ERFKILL = 154,
    EHWPOISON = 155,
    EL2NSYNC = 156,
    _,
};

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;
    pub const SETOWN = 8;
    pub const GETOWN = 9;
    pub const SETSIG = 10;
    pub const GETSIG = 11;
    pub const GETLK = 12;
    pub const SETLK = 13;
    pub const SETLKW = 14;
    pub const SETOWN_EX = 15;
    pub const GETOWN_EX = 16;
    pub const GETOWNER_UIDS = 17;

    pub const RDLCK = 0;
    pub const WRLCK = 1;
    pub const UNLCK = 2;
};

pub const FD_CLOEXEC = 1;

pub const F_OK = 0;
pub const X_OK = 1;
pub const W_OK = 2;
pub const R_OK = 4;

pub const W = struct {
    pub const NOHANG = 1;
    pub const UNTRACED = 2;
    pub const STOPPED = 2;
    pub const EXITED = 4;
    pub const CONTINUED = 8;
    pub const NOWAIT = 0x1000000;

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
        return @as(u16, @truncate(((s & 0xffff) *% 0x10001) >> 8)) > 0x7f00;
    }
    pub fn IFSIGNALED(s: u32) bool {
        return (s & 0xffff) -% 1 < 0xff;
    }
};

pub const Flock = extern struct {
    type: i16,
    whence: i16,
    start: off_t,
    len: off_t,
    pid: pid_t,
};

pub const IFNAMESIZE = 16;

pub const NAME_MAX = 255;
pub const PATH_MAX = 4096;
pub const IOV_MAX = 1024;

pub const IPPORT_RESERVED = 1024;

pub const IPPROTO = struct {
    pub const IP = 0;
    pub const HOPOPTS = 0;
    pub const ICMP = 1;
    pub const IGMP = 2;
    pub const IPIP = 4;
    pub const TCP = 6;
    pub const EGP = 8;
    pub const PUP = 12;
    pub const UDP = 17;
    pub const IDP = 22;
    pub const TP = 29;
    pub const DCCP = 33;
    pub const IPV6 = 41;
    pub const ROUTING = 43;
    pub const FRAGMENT = 44;
    pub const RSVP = 46;
    pub const GRE = 47;
    pub const ESP = 50;
    pub const AH = 51;
    pub const ICMPV6 = 58;
    pub const NONE = 59;
    pub const DSTOPTS = 60;
    pub const MTP = 92;
    pub const BEETPH = 94;
    pub const ENCAP = 98;
    pub const PIM = 103;
    pub const COMP = 108;
    pub const SCTP = 132;
    pub const MH = 135;
    pub const UDPLITE = 136;
    pub const MPLS = 137;
    pub const RAW = 255;
    pub const MAX = 256;
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const NB = 4;
    pub const UN = 8;
};

pub const MADV = struct {
    pub const NORMAL = 0;
    pub const RANDOM = 1;
    pub const SEQUENTIAL = 2;
    pub const WILLNEED = 3;
    pub const DONTNEED = 4;
    pub const FREE = 8;
    pub const REMOVE = 9;
    pub const DONTFORK = 10;
    pub const DOFORK = 11;
    pub const MERGEABLE = 12;
    pub const UNMERGEABLE = 13;
    pub const HUGEPAGE = 14;
    pub const NOHUGEPAGE = 15;
    pub const DONTDUMP = 16;
    pub const DODUMP = 17;
    pub const WIPEONFORK = 18;
    pub const KEEPONFORK = 19;
    pub const COLD = 20;
    pub const PAGEOUT = 21;
    pub const HWPOISON = 100;
    pub const SOFT_OFFLINE = 101;
};

pub const MAP = struct {
    pub const SHARED = 0x01;
    pub const PRIVATE = 0x02;
    pub const SHARED_VALIDATE = 0x03;
    pub const TYPE = 0x0f;
    pub const FIXED = 0x10;
    pub const ANON = 0x20;
    pub const ANONYMOUS = ANON;
    pub const NORESERVE = 0x4000;
    pub const GROWSDOWN = 0x0100;
    pub const DENYWRITE = 0x0800;
    pub const EXECUTABLE = 0x1000;
    pub const LOCKED = 0x2000;
    pub const POPULATE = 0x8000;
    pub const NONBLOCK = 0x10000;
    pub const STACK = 0x20000;
    pub const HUGETLB = 0x40000;
    pub const SYNC = 0x80000;
    pub const FIXED_NOREPLACE = 0x100000;
};

pub const MSF = struct {
    pub const ASYNC = 1;
    pub const INVALIDATE = 2;
    pub const SYNC = 4;
};

pub const MSG = struct {
    pub const OOB = 0x0001;
    pub const PEEK = 0x0002;
    pub const DONTROUTE = 0x0004;
    pub const CTRUNC = 0x0008;
    pub const PROXY = 0x0010;
    pub const TRUNC = 0x0020;
    pub const DONTWAIT = 0x0040;
    pub const EOR = 0x0080;
    pub const WAITALL = 0x0100;
    pub const FIN = 0x0200;
    pub const SYN = 0x0400;
    pub const CONFIRM = 0x0800;
    pub const RST = 0x1000;
    pub const ERRQUEUE = 0x2000;
    pub const NOSIGNAL = 0x4000;
    pub const MORE = 0x8000;
    pub const WAITFORONE = 0x10000;
    pub const BATCH = 0x40000;
    pub const ZEROCOPY = 0x4000000;
    pub const FASTOPEN = 0x20000000;
    pub const CMSG_CLOEXEC = 0x40000000;
};

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
    pub const LARGEFILE = 0o100000;
    pub const NOATIME = 0o1000000;
    pub const PATH = 0o10000000;
    pub const TMPFILE = 0o20200000;
    pub const NDELAY = NONBLOCK;
};

pub const POLL = struct {
    pub const IN = 0x001;
    pub const PRI = 0x002;
    pub const OUT = 0x004;
    pub const ERR = 0x008;
    pub const HUP = 0x010;
    pub const NVAL = 0x020;
    pub const RDNORM = 0x040;
    pub const RDBAND = 0x080;
};

pub const PROT = struct {
    pub const NONE = 0x0;
    pub const READ = 0x1;
    pub const WRITE = 0x2;
    pub const EXEC = 0x4;
    pub const GROWSDOWN = 0x01000000;
    pub const GROWSUP = 0x02000000;
};

pub const rlim_t = u64;

pub const RLIM = struct {
    pub const INFINITY = ~@as(rlim_t, 0);

    pub const SAVED_MAX = INFINITY;
    pub const SAVED_CUR = INFINITY;
};

pub const rlimit = extern struct {
    cur: rlim_t,
    max: rlim_t,
};

pub const rlimit_resource = enum(c_int) {
    CPU,
    FSIZE,
    DATA,
    STACK,
    CORE,
    RSS,
    NPROC,
    NOFILE,
    MEMLOCK,
    AS,
    LOCKS,
    SIGPENDING,
    MSGQUEUE,
    NICE,
    RTPRIO,
    RTTIME,
    _,
};

pub const rusage = extern struct {
    utime: timeval,
    stime: timeval,
    maxrss: isize,
    ixrss: isize,
    idrss: isize,
    isrss: isize,
    minflt: isize,
    majflt: isize,
    nswap: isize,
    inblock: isize,
    oublock: isize,
    msgsnd: isize,
    msgrcv: isize,
    nsignals: isize,
    nvcsw: isize,
    nivcsw: isize,
    __reserved: [16]isize = [1]isize{0} ** 16,

    pub const SELF = 0;
    pub const CHILDREN = -1;
    pub const THREAD = 1;
};

pub const timeval = extern struct {
    tv_sec: i64,
    tv_usec: i32,
};

pub const REG = struct {
    pub const GS = 0;
    pub const FS = 1;
    pub const ES = 2;
    pub const DS = 3;
    pub const EDI = 4;
    pub const ESI = 5;
    pub const EBP = 6;
    pub const ESP = 7;
    pub const EBX = 8;
    pub const EDX = 9;
    pub const ECX = 10;
    pub const EAX = 11;
    pub const TRAPNO = 12;
    pub const ERR = 13;
    pub const EIP = 14;
    pub const CS = 15;
    pub const EFL = 16;
    pub const UESP = 17;
    pub const SS = 18;
};

pub const S = struct {
    pub const IFMT = 0o170000;

    pub const IFDIR = 0o040000;
    pub const IFCHR = 0o020000;
    pub const IFBLK = 0o060000;
    pub const IFREG = 0o100000;
    pub const IFIFO = 0o010000;
    pub const IFLNK = 0o120000;
    pub const IFSOCK = 0o140000;

    pub const ISUID = 0o4000;
    pub const ISGID = 0o2000;
    pub const ISVTX = 0o1000;
    pub const IRUSR = 0o400;
    pub const IWUSR = 0o200;
    pub const IXUSR = 0o100;
    pub const IRWXU = 0o700;
    pub const IRGRP = 0o040;
    pub const IWGRP = 0o020;
    pub const IXGRP = 0o010;
    pub const IRWXG = 0o070;
    pub const IROTH = 0o004;
    pub const IWOTH = 0o002;
    pub const IXOTH = 0o001;
    pub const IRWXO = 0o007;

    pub fn ISREG(m: mode_t) bool {
        return m & IFMT == IFREG;
    }

    pub fn ISDIR(m: mode_t) bool {
        return m & IFMT == IFDIR;
    }

    pub fn ISCHR(m: mode_t) bool {
        return m & IFMT == IFCHR;
    }

    pub fn ISBLK(m: mode_t) bool {
        return m & IFMT == IFBLK;
    }

    pub fn ISFIFO(m: mode_t) bool {
        return m & IFMT == IFIFO;
    }

    pub fn ISLNK(m: mode_t) bool {
        return m & IFMT == IFLNK;
    }

    pub fn ISSOCK(m: mode_t) bool {
        return m & IFMT == IFSOCK;
    }
};

pub const SA = struct {
    pub const NOCLDSTOP = 1;
    pub const NOCLDWAIT = 2;
    pub const SIGINFO = 4;
    pub const RESTART = 0x10000000;
    pub const RESETHAND = 0x80000000;
    pub const ONSTACK = 0x08000000;
    pub const NODEFER = 0x40000000;
    pub const RESTORER = 0x04000000;
};

pub const SEEK = struct {
    pub const SET = 0;
    pub const CUR = 1;
    pub const END = 2;
};

pub const SHUT = struct {
    pub const RD = 0;
    pub const WR = 1;
    pub const RDWR = 2;
};

pub const SIG = struct {
    pub const BLOCK = 0;
    pub const UNBLOCK = 1;
    pub const SETMASK = 2;

    pub const HUP = 1;
    pub const INT = 2;
    pub const QUIT = 3;
    pub const ILL = 4;
    pub const TRAP = 5;
    pub const ABRT = 6;
    pub const IOT = ABRT;
    pub const BUS = 7;
    pub const FPE = 8;
    pub const KILL = 9;
    pub const USR1 = 10;
    pub const SEGV = 11;
    pub const USR2 = 12;
    pub const PIPE = 13;
    pub const ALRM = 14;
    pub const TERM = 15;
    pub const STKFLT = 16;
    pub const CHLD = 17;
    pub const CONT = 18;
    pub const STOP = 19;
    pub const TSTP = 20;
    pub const TTIN = 21;
    pub const TTOU = 22;
    pub const URG = 23;
    pub const XCPU = 24;
    pub const XFSZ = 25;
    pub const VTALRM = 26;
    pub const PROF = 27;
    pub const WINCH = 28;
    pub const IO = 29;
    pub const POLL = 29;
    pub const PWR = 30;
    pub const SYS = 31;
    pub const UNUSED = SIG.SYS;

    pub const ERR = @as(?Sigaction.handler_fn, @ptrFromInt(std.math.maxInt(usize)));
    pub const DFL = @as(?Sigaction.handler_fn, @ptrFromInt(0));
    pub const IGN = @as(?Sigaction.handler_fn, @ptrFromInt(1));
};

pub const Sigaction = extern struct {
    pub const handler_fn = *const fn (c_int) align(1) callconv(.C) void;
    pub const sigaction_fn = *const fn (c_int, *const siginfo_t, ?*const anyopaque) callconv(.C) void;

    handler: extern union {
        handler: ?handler_fn,
        sigaction: ?sigaction_fn,
    },
    mask: sigset_t,
    flags: c_uint,
    restorer: ?*const fn () callconv(.C) void = null,
};

pub const sigset_t = [1024 / 32]u32;
pub const empty_sigset = [_]u32{0} ** @typeInfo(sigset_t).Array.len;
pub const siginfo_t = extern struct {
    signo: i32,
    errno: i32,
    code: i32,
    fields: siginfo_fields_union,
};
const siginfo_fields_union = extern union {
    pad: [128 - 2 * @sizeOf(c_int) - @sizeOf(c_long)]u8,
    common: extern struct {
        first: extern union {
            piduid: extern struct {
                pid: pid_t,
                uid: uid_t,
            },
            timer: extern struct {
                timerid: i32,
                overrun: i32,
            },
        },
        second: extern union {
            value: sigval,
            sigchld: extern struct {
                status: i32,
                utime: clock_t,
                stime: clock_t,
            },
        },
    },
    sigfault: extern struct {
        addr: *anyopaque,
        addr_lsb: i16,
        first: extern union {
            addr_bnd: extern struct {
                lower: *anyopaque,
                upper: *anyopaque,
            },
            pkey: u32,
        },
    },
    sigpoll: extern struct {
        band: isize,
        fd: i32,
    },
    sigsys: extern struct {
        call_addr: *anyopaque,
        syscall: i32,
        native_arch: u32,
    },
};
pub const sigval = extern union {
    int: i32,
    ptr: *anyopaque,
};

pub const SIOCGIFINDEX = 0x8933;

pub const SO = struct {
    pub const DEBUG = 1;
    pub const REUSEADDR = 2;
    pub const TYPE = 3;
    pub const ERROR = 4;
    pub const DONTROUTE = 5;
    pub const BROADCAST = 6;
    pub const SNDBUF = 7;
    pub const RCVBUF = 8;
    pub const KEEPALIVE = 9;
    pub const OOBINLINE = 10;
    pub const NO_CHECK = 11;
    pub const PRIORITY = 12;
    pub const LINGER = 13;
    pub const BSDCOMPAT = 14;
    pub const REUSEPORT = 15;
    pub const PASSCRED = 16;
    pub const PEERCRED = 17;
    pub const RCVLOWAT = 18;
    pub const SNDLOWAT = 19;
    pub const RCVTIMEO = 20;
    pub const SNDTIMEO = 21;
    pub const ACCEPTCONN = 30;
    pub const PEERSEC = 31;
    pub const SNDBUFFORCE = 32;
    pub const RCVBUFFORCE = 33;
    pub const PROTOCOL = 38;
    pub const DOMAIN = 39;
    pub const SECURITY_AUTHENTICATION = 22;
    pub const SECURITY_ENCRYPTION_TRANSPORT = 23;
    pub const SECURITY_ENCRYPTION_NETWORK = 24;
    pub const BINDTODEVICE = 25;
    pub const ATTACH_FILTER = 26;
    pub const DETACH_FILTER = 27;
    pub const GET_FILTER = ATTACH_FILTER;
    pub const PEERNAME = 28;
    pub const TIMESTAMP_OLD = 29;
    pub const PASSSEC = 34;
    pub const TIMESTAMPNS_OLD = 35;
    pub const MARK = 36;
    pub const TIMESTAMPING_OLD = 37;
    pub const RXQ_OVFL = 40;
    pub const WIFI_STATUS = 41;
    pub const PEEK_OFF = 42;
    pub const NOFCS = 43;
    pub const LOCK_FILTER = 44;
    pub const SELECT_ERR_QUEUE = 45;
    pub const BUSY_POLL = 46;
    pub const MAX_PACING_RATE = 47;
    pub const BPF_EXTENSIONS = 48;
    pub const INCOMING_CPU = 49;
    pub const ATTACH_BPF = 50;
    pub const DETACH_BPF = DETACH_FILTER;
    pub const ATTACH_REUSEPORT_CBPF = 51;
    pub const ATTACH_REUSEPORT_EBPF = 52;
    pub const CNX_ADVICE = 53;
    pub const MEMINFO = 55;
    pub const INCOMING_NAPI_ID = 56;
    pub const COOKIE = 57;
    pub const PEERGROUPS = 59;
    pub const ZEROCOPY = 60;
    pub const TXTIME = 61;
    pub const BINDTOIFINDEX = 62;
    pub const TIMESTAMP_NEW = 63;
    pub const TIMESTAMPNS_NEW = 64;
    pub const TIMESTAMPING_NEW = 65;
    pub const RCVTIMEO_NEW = 66;
    pub const SNDTIMEO_NEW = 67;
    pub const DETACH_REUSEPORT_BPF = 68;
};

pub const SOCK = struct {
    pub const STREAM = 1;
    pub const DGRAM = 2;
    pub const RAW = 3;
    pub const RDM = 4;
    pub const SEQPACKET = 5;
    pub const DCCP = 6;
    pub const PACKET = 10;
    pub const CLOEXEC = 0o2000000;
    pub const NONBLOCK = 0o4000;
};

pub const SOL = struct {
    pub const SOCKET = 1;

    pub const IP = 0;
    pub const IPV6 = 41;
    pub const ICMPV6 = 58;

    pub const RAW = 255;
    pub const DECNET = 261;
    pub const X25 = 262;
    pub const PACKET = 263;
    pub const ATM = 264;
    pub const AAL = 265;
    pub const IRDA = 266;
    pub const NETBEUI = 267;
    pub const LLC = 268;
    pub const DCCP = 269;
    pub const NETLINK = 270;
    pub const TIPC = 271;
    pub const RXRPC = 272;
    pub const PPPOL2TP = 273;
    pub const BLUETOOTH = 274;
    pub const PNPIPE = 275;
    pub const RDS = 276;
    pub const IUCV = 277;
    pub const CAIF = 278;
    pub const ALG = 279;
    pub const NFC = 280;
    pub const KCM = 281;
    pub const TLS = 282;
    pub const XDP = 283;
};

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const TCP = struct {
    pub const NODELAY = 1;
    pub const MAXSEG = 2;
    pub const CORK = 3;
    pub const KEEPIDLE = 4;
    pub const KEEPINTVL = 5;
    pub const KEEPCNT = 6;
    pub const SYNCNT = 7;
    pub const LINGER2 = 8;
    pub const DEFER_ACCEPT = 9;
    pub const WINDOW_CLAMP = 10;
    pub const INFO = 11;
    pub const QUICKACK = 12;
    pub const CONGESTION = 13;
    pub const MD5SIG = 14;
    pub const THIN_LINEAR_TIMEOUTS = 16;
    pub const THIN_DUPACK = 17;
    pub const USER_TIMEOUT = 18;
    pub const REPAIR = 19;
    pub const REPAIR_QUEUE = 20;
    pub const QUEUE_SEQ = 21;
    pub const REPAIR_OPTIONS = 22;
    pub const FASTOPEN = 23;
    pub const TIMESTAMP = 24;
    pub const NOTSENT_LOWAT = 25;
    pub const CC_INFO = 26;
    pub const SAVE_SYN = 27;
    pub const SAVED_SYN = 28;
    pub const REPAIR_WINDOW = 29;
    pub const FASTOPEN_CONNECT = 30;
    pub const ULP = 31;
    pub const MD5SIG_EXT = 32;
    pub const FASTOPEN_KEY = 33;
    pub const FASTOPEN_NO_COOKIE = 34;
    pub const ZEROCOPY_RECEIVE = 35;
    pub const INQ = 36;
    pub const CM_INQ = INQ;
    pub const TX_DELAY = 37;

    pub const REPAIR_ON = 1;
    pub const REPAIR_OFF = 0;
    pub const REPAIR_OFF_NO_WP = -1;
};

pub const TCSA = enum(c_uint) {
    NOW,
    DRAIN,
    FLUSH,
    _,
};

pub const addrinfo = extern struct {
    flags: i32,
    family: i32,
    socktype: i32,
    protocol: i32,
    addrlen: socklen_t,
    addr: ?*sockaddr,
    canonname: ?[*:0]u8,
    next: ?*addrinfo,
};

pub const in_port_t = u16;
pub const sa_family_t = u16;
pub const socklen_t = u32;

pub const sockaddr = extern struct {
    family: sa_family_t,
    data: [14]u8,

    pub const SS_MAXSIZE = 128;
    pub const storage = extern struct {
        family: sa_family_t align(8),
        padding: [SS_MAXSIZE - @sizeOf(sa_family_t)]u8 = undefined,

        comptime {
            std.debug.assert(@sizeOf(storage) == SS_MAXSIZE);
            std.debug.assert(@alignOf(storage) == 8);
        }
    };

    /// IPv4 socket address
    pub const in = extern struct {
        family: sa_family_t = AF.INET,
        port: in_port_t,
        addr: u32,
        zero: [8]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
    };

    /// IPv6 socket address
    pub const in6 = extern struct {
        family: sa_family_t = AF.INET6,
        port: in_port_t,
        flowinfo: u32,
        addr: [16]u8,
        scope_id: u32,
    };

    /// UNIX domain socket address
    pub const un = extern struct {
        family: sa_family_t = AF.UNIX,
        path: [108]u8,
    };

    /// Packet socket address
    pub const ll = extern struct {
        family: sa_family_t = AF.PACKET,
        protocol: u16,
        ifindex: i32,
        hatype: u16,
        pkttype: u8,
        halen: u8,
        addr: [8]u8,
    };

    /// Netlink socket address
    pub const nl = extern struct {
        family: sa_family_t = AF.NETLINK,
        __pad1: c_ushort = 0,

        /// port ID
        pid: u32,

        /// multicast groups mask
        groups: u32,
    };

    pub const xdp = extern struct {
        family: u16 = AF.XDP,
        flags: u16,
        ifindex: u32,
        queue_id: u32,
        shared_umem_fd: u32,
    };

    /// Address structure for vSockets
    pub const vm = extern struct {
        family: sa_family_t = AF.VSOCK,
        reserved1: u16 = 0,
        port: u32,
        cid: u32,
        flags: u8,

        /// The total size of this structure should be exactly the same as that of struct sockaddr.
        zero: [3]u8 = [_]u8{0} ** 3,
        comptime {
            std.debug.assert(@sizeOf(vm) == @sizeOf(sockaddr));
        }
    };
};

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = i64;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u32;
pub const blkcnt_t = i32;

pub const pid_t = i32;
pub const fd_t = i32;
pub const uid_t = u32;
pub const gid_t = u32;
pub const clock_t = i32;

pub const dl_phdr_info = extern struct {
    dlpi_addr: usize,
    dlpi_name: ?[*:0]const u8,
    dlpi_phdr: [*]std.elf.Phdr,
    dlpi_phnum: u16,
};

pub const mcontext_t = extern struct {
    gregs: [19]usize,
    fpregs: [*]u8,
    oldmask: usize,
    cr2: usize,
};

pub const msghdr = extern struct {
    name: ?*sockaddr,
    namelen: socklen_t,
    iov: [*]iovec,
    iovlen: i32,
    control: ?*anyopaque,
    controllen: socklen_t,
    flags: i32,
};

pub const msghdr_const = extern struct {
    name: ?*const sockaddr,
    namelen: socklen_t,
    iov: [*]const iovec_const,
    iovlen: i32,
    control: ?*const anyopaque,
    controllen: socklen_t,
    flags: i32,
};

pub const nfds_t = usize;
pub const pollfd = extern struct {
    fd: fd_t,
    events: i16,
    revents: i16,
};

pub const stack_t = extern struct {
    sp: [*]u8,
    flags: i32,
    size: usize,
};

pub const cc_t = u8;
pub const speed_t = u32;
pub const tcflag_t = u32;

pub const NCCS = 32;

pub const termios = extern struct {
    iflag: tcflag_t,
    oflag: tcflag_t,
    cflag: tcflag_t,
    lflag: tcflag_t,
    line: cc_t,
    cc: [NCCS]cc_t,
    ispeed: speed_t,
    ospeed: speed_t,
};

pub const timespec = extern struct {
    tv_sec: time_t,
    tv_nsec: isize,
};

pub const timezone = extern struct {
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

pub const ucontext_t = extern struct {
    flags: usize,
    link: ?*ucontext_t,
    stack: stack_t,
    mcontext: mcontext_t,
    sigmask: sigset_t,
    regspace: [28]usize,
};

pub const utsname = extern struct {
    sysname: [64:0]u8,
    nodename: [64:0]u8,
    release: [64:0]u8,
    version: [64:0]u8,
    machine: [64:0]u8,
    domainname: [64:0]u8,
};

pub const Stat = extern struct {
    dev: dev_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    size: off_t,
    blksize: blksize_t,
    blocks: blkcnt_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    ino: ino_t,

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

pub const TIMING = struct {
    pub const SETTIMEOUT = 0;
    pub const RAF = 1;
    pub const SETIMMEDIATE = 2;
};

pub const LOG = struct {
    pub const CONSOLE = 1;
    pub const WARN = 2;
    pub const ERROR = 4;
    pub const C_STACK = 8;
    pub const JS_STACK = 16;
    pub const DEMANGLE = 32;
    pub const NO_PATHS = 64;
    pub const FUNC_PARAMS = 128;
    pub const DEBUG = 256;
    pub const INFO = 512;
};

pub const em_callback_func = ?*const fn () callconv(.C) void;
pub const em_arg_callback_func = ?*const fn (?*anyopaque) callconv(.C) void;
pub const em_str_callback_func = ?*const fn ([*:0]const u8) callconv(.C) void;

pub extern "c" fn emscripten_async_wget(url: [*:0]const u8, file: [*:0]const u8, onload: em_str_callback_func, onerror: em_str_callback_func) void;

pub const em_async_wget_onload_func = ?*const fn (?*anyopaque, ?*anyopaque, c_int) callconv(.C) void;
pub extern "c" fn emscripten_async_wget_data(url: [*:0]const u8, arg: ?*anyopaque, onload: em_async_wget_onload_func, onerror: em_arg_callback_func) void;

pub const em_async_wget2_onload_func = ?*const fn (c_uint, ?*anyopaque, [*:0]const u8) callconv(.C) void;
pub const em_async_wget2_onstatus_func = ?*const fn (c_uint, ?*anyopaque, c_int) callconv(.C) void;

pub extern "c" fn emscripten_async_wget2(url: [*:0]const u8, file: [*:0]const u8, requesttype: [*:0]const u8, param: [*:0]const u8, arg: ?*anyopaque, onload: em_async_wget2_onload_func, onerror: em_async_wget2_onstatus_func, onprogress: em_async_wget2_onstatus_func) c_int;

pub const em_async_wget2_data_onload_func = ?*const fn (c_uint, ?*anyopaque, ?*anyopaque, c_uint) callconv(.C) void;
pub const em_async_wget2_data_onerror_func = ?*const fn (c_uint, ?*anyopaque, c_int, [*:0]const u8) callconv(.C) void;
pub const em_async_wget2_data_onprogress_func = ?*const fn (c_uint, ?*anyopaque, c_int, c_int) callconv(.C) void;

pub extern "c" fn emscripten_async_wget2_data(url: [*:0]const u8, requesttype: [*:0]const u8, param: [*:0]const u8, arg: ?*anyopaque, free: c_int, onload: em_async_wget2_data_onload_func, onerror: em_async_wget2_data_onerror_func, onprogress: em_async_wget2_data_onprogress_func) c_int;
pub extern "c" fn emscripten_async_wget2_abort(handle: c_int) void;
pub extern "c" fn emscripten_wget(url: [*:0]const u8, file: [*:0]const u8) c_int;
pub extern "c" fn emscripten_wget_data(url: [*:0]const u8, pbuffer: *(?*anyopaque), pnum: *c_int, perror: *c_int) void;
pub extern "c" fn emscripten_run_script(script: [*:0]const u8) void;
pub extern "c" fn emscripten_run_script_int(script: [*:0]const u8) c_int;
pub extern "c" fn emscripten_run_script_string(script: [*:0]const u8) [*:0]u8;
pub extern "c" fn emscripten_async_run_script(script: [*:0]const u8, millis: c_int) void;
pub extern "c" fn emscripten_async_load_script(script: [*:0]const u8, onload: em_callback_func, onerror: em_callback_func) void;
pub extern "c" fn emscripten_set_main_loop(func: em_callback_func, fps: c_int, simulate_infinite_loop: c_int) void;
pub extern "c" fn emscripten_set_main_loop_timing(mode: c_int, value: c_int) c_int;
pub extern "c" fn emscripten_get_main_loop_timing(mode: *c_int, value: *c_int) void;
pub extern "c" fn emscripten_set_main_loop_arg(func: em_arg_callback_func, arg: ?*anyopaque, fps: c_int, simulate_infinite_loop: c_int) void;
pub extern "c" fn emscripten_pause_main_loop() void;
pub extern "c" fn emscripten_resume_main_loop() void;
pub extern "c" fn emscripten_cancel_main_loop() void;

pub const em_socket_callback = ?*const fn (c_int, ?*anyopaque) callconv(.C) void;
pub const em_socket_error_callback = ?*const fn (c_int, c_int, [*:0]const u8, ?*anyopaque) callconv(.C) void;

pub extern "c" fn emscripten_set_socket_error_callback(userData: ?*anyopaque, callback: em_socket_error_callback) void;
pub extern "c" fn emscripten_set_socket_open_callback(userData: ?*anyopaque, callback: em_socket_callback) void;
pub extern "c" fn emscripten_set_socket_listen_callback(userData: ?*anyopaque, callback: em_socket_callback) void;
pub extern "c" fn emscripten_set_socket_connection_callback(userData: ?*anyopaque, callback: em_socket_callback) void;
pub extern "c" fn emscripten_set_socket_message_callback(userData: ?*anyopaque, callback: em_socket_callback) void;
pub extern "c" fn emscripten_set_socket_close_callback(userData: ?*anyopaque, callback: em_socket_callback) void;
pub extern "c" fn _emscripten_push_main_loop_blocker(func: em_arg_callback_func, arg: ?*anyopaque, name: [*:0]const u8) void;
pub extern "c" fn _emscripten_push_uncounted_main_loop_blocker(func: em_arg_callback_func, arg: ?*anyopaque, name: [*:0]const u8) void;
pub extern "c" fn emscripten_set_main_loop_expected_blockers(num: c_int) void;
pub extern "c" fn emscripten_async_call(func: em_arg_callback_func, arg: ?*anyopaque, millis: c_int) void;
pub extern "c" fn emscripten_exit_with_live_runtime() noreturn;
pub extern "c" fn emscripten_force_exit(status: c_int) noreturn;
pub extern "c" fn emscripten_get_device_pixel_ratio() f64;
pub extern "c" fn emscripten_get_window_title() [*:0]u8;
pub extern "c" fn emscripten_set_window_title([*:0]const u8) void;
pub extern "c" fn emscripten_get_screen_size(width: *c_int, height: *c_int) void;
pub extern "c" fn emscripten_hide_mouse() void;
pub extern "c" fn emscripten_set_canvas_size(width: c_int, height: c_int) void;
pub extern "c" fn emscripten_get_canvas_size(width: *c_int, height: *c_int, isFullscreen: *c_int) void;
pub extern "c" fn emscripten_get_now() f64;
pub extern "c" fn emscripten_random() f32;
pub const em_idb_onload_func = ?*const fn (?*anyopaque, ?*anyopaque, c_int) callconv(.C) void;
pub extern "c" fn emscripten_idb_async_load(db_name: [*:0]const u8, file_id: [*:0]const u8, arg: ?*anyopaque, onload: em_idb_onload_func, onerror: em_arg_callback_func) void;
pub extern "c" fn emscripten_idb_async_store(db_name: [*:0]const u8, file_id: [*:0]const u8, ptr: ?*anyopaque, num: c_int, arg: ?*anyopaque, onstore: em_arg_callback_func, onerror: em_arg_callback_func) void;
pub extern "c" fn emscripten_idb_async_delete(db_name: [*:0]const u8, file_id: [*:0]const u8, arg: ?*anyopaque, ondelete: em_arg_callback_func, onerror: em_arg_callback_func) void;
pub const em_idb_exists_func = ?*const fn (?*anyopaque, c_int) callconv(.C) void;
pub extern "c" fn emscripten_idb_async_exists(db_name: [*:0]const u8, file_id: [*:0]const u8, arg: ?*anyopaque, oncheck: em_idb_exists_func, onerror: em_arg_callback_func) void;
pub extern "c" fn emscripten_idb_load(db_name: [*:0]const u8, file_id: [*:0]const u8, pbuffer: *?*anyopaque, pnum: *c_int, perror: *c_int) void;
pub extern "c" fn emscripten_idb_store(db_name: [*:0]const u8, file_id: [*:0]const u8, buffer: *anyopaque, num: c_int, perror: *c_int) void;
pub extern "c" fn emscripten_idb_delete(db_name: [*:0]const u8, file_id: [*:0]const u8, perror: *c_int) void;
pub extern "c" fn emscripten_idb_exists(db_name: [*:0]const u8, file_id: [*:0]const u8, pexists: *c_int, perror: *c_int) void;
pub extern "c" fn emscripten_idb_load_blob(db_name: [*:0]const u8, file_id: [*:0]const u8, pblob: *c_int, perror: *c_int) void;
pub extern "c" fn emscripten_idb_store_blob(db_name: [*:0]const u8, file_id: [*:0]const u8, buffer: *anyopaque, num: c_int, perror: *c_int) void;
pub extern "c" fn emscripten_idb_read_from_blob(blob: c_int, start: c_int, num: c_int, buffer: ?*anyopaque) void;
pub extern "c" fn emscripten_idb_free_blob(blob: c_int) void;
pub extern "c" fn emscripten_run_preload_plugins(file: [*:0]const u8, onload: em_str_callback_func, onerror: em_str_callback_func) c_int;
pub const em_run_preload_plugins_data_onload_func = ?*const fn (?*anyopaque, [*:0]const u8) callconv(.C) void;
pub extern "c" fn emscripten_run_preload_plugins_data(data: [*]u8, size: c_int, suffix: [*:0]const u8, arg: ?*anyopaque, onload: em_run_preload_plugins_data_onload_func, onerror: em_arg_callback_func) void;
pub extern "c" fn emscripten_lazy_load_code() void;
pub const worker_handle = c_int;
pub extern "c" fn emscripten_create_worker(url: [*:0]const u8) worker_handle;
pub extern "c" fn emscripten_destroy_worker(worker: worker_handle) void;
pub const em_worker_callback_func = ?*const fn ([*]u8, c_int, ?*anyopaque) callconv(.C) void;
pub extern "c" fn emscripten_call_worker(worker: worker_handle, funcname: [*:0]const u8, data: [*]u8, size: c_int, callback: em_worker_callback_func, arg: ?*anyopaque) void;
pub extern "c" fn emscripten_worker_respond(data: [*]u8, size: c_int) void;
pub extern "c" fn emscripten_worker_respond_provisionally(data: [*]u8, size: c_int) void;
pub extern "c" fn emscripten_get_worker_queue_size(worker: worker_handle) c_int;
pub extern "c" fn emscripten_get_compiler_setting(name: [*:0]const u8) c_long;
pub extern "c" fn emscripten_has_asyncify() c_int;
pub extern "c" fn emscripten_debugger() void;

pub extern "c" fn emscripten_get_preloaded_image_data(path: [*:0]const u8, w: *c_int, h: *c_int) ?[*]u8;
pub extern "c" fn emscripten_get_preloaded_image_data_from_FILE(file: *FILE, w: *c_int, h: *c_int) ?[*]u8;
pub extern "c" fn emscripten_log(flags: c_int, format: [*:0]const u8, ...) void;
pub extern "c" fn emscripten_get_callstack(flags: c_int, out: ?[*]u8, maxbytes: c_int) c_int;
pub extern "c" fn emscripten_print_double(x: f64, to: ?[*]u8, max: c_int) c_int;
pub const em_scan_func = ?*const fn (?*anyopaque, ?*anyopaque) callconv(.C) void;
pub extern "c" fn emscripten_scan_registers(func: em_scan_func) void;
pub extern "c" fn emscripten_scan_stack(func: em_scan_func) void;
pub const em_dlopen_callback = ?*const fn (?*anyopaque, ?*anyopaque) callconv(.C) void;
pub extern "c" fn emscripten_dlopen(filename: [*:0]const u8, flags: c_int, user_data: ?*anyopaque, onsuccess: em_dlopen_callback, onerror: em_arg_callback_func) void;
pub extern "c" fn emscripten_dlopen_promise(filename: [*:0]const u8, flags: c_int) em_promise_t;
pub extern "c" fn emscripten_throw_number(number: f64) void;
pub extern "c" fn emscripten_throw_string(utf8String: [*:0]const u8) void;
pub extern "c" fn emscripten_sleep(ms: c_uint) void;

pub const PROMISE = struct {
    pub const FULFILL = 0;
    pub const MATCH = 1;
    pub const MATCH_RELEASE = 2;
    pub const REJECT = 3;
};

pub const struct__em_promise = opaque {};
pub const em_promise_t = ?*struct__em_promise;
pub const enum_em_promise_result_t = c_uint;
pub const em_promise_result_t = enum_em_promise_result_t;
pub const em_promise_callback_t = ?*const fn (?*?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.C) em_promise_result_t;

pub extern "c" fn emscripten_promise_create() em_promise_t;
pub extern "c" fn emscripten_promise_destroy(promise: em_promise_t) void;
pub extern "c" fn emscripten_promise_resolve(promise: em_promise_t, result: em_promise_result_t, value: ?*anyopaque) void;
pub extern "c" fn emscripten_promise_then(promise: em_promise_t, on_fulfilled: em_promise_callback_t, on_rejected: em_promise_callback_t, data: ?*anyopaque) em_promise_t;
pub extern "c" fn emscripten_promise_all(promises: [*]em_promise_t, results: ?[*]?*anyopaque, num_promises: usize) em_promise_t;

pub const struct_em_settled_result_t = extern struct {
    result: em_promise_result_t,
    value: ?*anyopaque,
};
pub const em_settled_result_t = struct_em_settled_result_t;
