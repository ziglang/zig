// The reference for these types and values is Microsoft Windows's ucrt (Universal C RunTime).

usingnamespace @import("../windows/bits.zig");
const ws2_32 = @import("../windows/ws2_32.zig");

// TODO: Stop using os.iovec in std.fs et al on Windows in the future
const posix = @import("posix.zig");
pub const iovec = posix.iovec;
pub const iovec_const = posix.iovec_const;

pub const fd_t = HANDLE;
pub const ino_t = LARGE_INTEGER;
pub const pid_t = HANDLE;
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

pub const sig_atomic_t = c_int;

/// maximum signal number + 1
pub const NSIG = 23;

// Signal types

/// interrupt
pub const SIGINT = 2;

/// illegal instruction - invalid function image
pub const SIGILL = 4;

/// floating point exception
pub const SIGFPE = 8;

/// segment violation
pub const SIGSEGV = 11;

/// Software termination signal from kill
pub const SIGTERM = 15;

/// Ctrl-Break sequence
pub const SIGBREAK = 21;

/// abnormal termination triggered by abort call
pub const SIGABRT = 22;

/// SIGABRT compatible with other platforms, same as SIGABRT
pub const SIGABRT_COMPAT = 6;

// Signal action codes

/// default signal action
pub const SIG_DFL = 0;

/// ignore signal
pub const SIG_IGN = 1;

/// return current value
pub const SIG_GET = 2;

/// signal gets error
pub const SIG_SGE = 3;

/// acknowledge
pub const SIG_ACK = 4;

/// Signal error value (returned by signal call on error)
pub const SIG_ERR = -1;

pub const SEEK_SET = 0;
pub const SEEK_CUR = 1;
pub const SEEK_END = 2;

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
pub const AT_REMOVEDIR = 0x200;

pub const in_port_t = u16;
pub const sa_family_t = ws2_32.ADDRESS_FAMILY;
pub const socklen_t = ws2_32.socklen_t;

pub const sockaddr = ws2_32.sockaddr;
pub const sockaddr_in = ws2_32.sockaddr_in;
pub const sockaddr_in6 = ws2_32.sockaddr_in6;
pub const sockaddr_un = ws2_32.sockaddr_un;

pub const in6_addr = [16]u8;
pub const in_addr = u32;

pub const addrinfo = ws2_32.addrinfo;

pub const AF_UNSPEC = ws2_32.AF_UNSPEC;
pub const AF_UNIX = ws2_32.AF_UNIX;
pub const AF_INET = ws2_32.AF_INET;
pub const AF_IMPLINK = ws2_32.AF_IMPLINK;
pub const AF_PUP = ws2_32.AF_PUP;
pub const AF_CHAOS = ws2_32.AF_CHAOS;
pub const AF_NS = ws2_32.AF_NS;
pub const AF_IPX = ws2_32.AF_IPX;
pub const AF_ISO = ws2_32.AF_ISO;
pub const AF_OSI = ws2_32.AF_OSI;
pub const AF_ECMA = ws2_32.AF_ECMA;
pub const AF_DATAKIT = ws2_32.AF_DATAKIT;
pub const AF_CCITT = ws2_32.AF_CCITT;
pub const AF_SNA = ws2_32.AF_SNA;
pub const AF_DECnet = ws2_32.AF_DECnet;
pub const AF_DLI = ws2_32.AF_DLI;
pub const AF_LAT = ws2_32.AF_LAT;
pub const AF_HYLINK = ws2_32.AF_HYLINK;
pub const AF_APPLETALK = ws2_32.AF_APPLETALK;
pub const AF_NETBIOS = ws2_32.AF_NETBIOS;
pub const AF_VOICEVIEW = ws2_32.AF_VOICEVIEW;
pub const AF_FIREFOX = ws2_32.AF_FIREFOX;
pub const AF_UNKNOWN1 = ws2_32.AF_UNKNOWN1;
pub const AF_BAN = ws2_32.AF_BAN;
pub const AF_ATM = ws2_32.AF_ATM;
pub const AF_INET6 = ws2_32.AF_INET6;
pub const AF_CLUSTER = ws2_32.AF_CLUSTER;
pub const AF_12844 = ws2_32.AF_12844;
pub const AF_IRDA = ws2_32.AF_IRDA;
pub const AF_NETDES = ws2_32.AF_NETDES;
pub const AF_TCNPROCESS = ws2_32.AF_TCNPROCESS;
pub const AF_TCNMESSAGE = ws2_32.AF_TCNMESSAGE;
pub const AF_ICLFXBM = ws2_32.AF_ICLFXBM;
pub const AF_BTH = ws2_32.AF_BTH;
pub const AF_MAX = ws2_32.AF_MAX;

pub const SOCK_STREAM = ws2_32.SOCK_STREAM;
pub const SOCK_DGRAM = ws2_32.SOCK_DGRAM;
pub const SOCK_RAW = ws2_32.SOCK_RAW;
pub const SOCK_RDM = ws2_32.SOCK_RDM;
pub const SOCK_SEQPACKET = ws2_32.SOCK_SEQPACKET;

/// WARNING: this flag is not supported by windows socket functions directly,
///          it is only supported by std.os.socket. Be sure that this value does
///          not share any bits with any of the SOCK_* values.
pub const SOCK_CLOEXEC = 0x10000;
/// WARNING: this flag is not supported by windows socket functions directly,
///          it is only supported by std.os.socket. Be sure that this value does
///          not share any bits with any of the SOCK_* values.
pub const SOCK_NONBLOCK = 0x20000;

pub const IPPROTO_ICMP = ws2_32.IPPROTO_ICMP;
pub const IPPROTO_IGMP = ws2_32.IPPROTO_IGMP;
pub const BTHPROTO_RFCOMM = ws2_32.BTHPROTO_RFCOMM;
pub const IPPROTO_TCP = ws2_32.IPPROTO_TCP;
pub const IPPROTO_UDP = ws2_32.IPPROTO_UDP;
pub const IPPROTO_ICMPV6 = ws2_32.IPPROTO_ICMPV6;
pub const IPPROTO_RM = ws2_32.IPPROTO_RM;

pub const nfds_t = c_ulong;
pub const pollfd = ws2_32.pollfd;

pub const POLLRDNORM = ws2_32.POLLRDNORM;
pub const POLLRDBAND = ws2_32.POLLRDBAND;
pub const POLLIN = ws2_32.POLLIN;
pub const POLLPRI = ws2_32.POLLPRI;
pub const POLLWRNORM = ws2_32.POLLWRNORM;
pub const POLLOUT = ws2_32.POLLOUT;
pub const POLLWRBAND = ws2_32.POLLWRBAND;
pub const POLLERR = ws2_32.POLLERR;
pub const POLLHUP = ws2_32.POLLHUP;
pub const POLLNVAL = ws2_32.POLLNVAL;

pub const SOL_SOCKET = ws2_32.SOL_SOCKET;

pub const SO_DEBUG = ws2_32.SO_DEBUG;
pub const SO_ACCEPTCONN = ws2_32.SO_ACCEPTCONN;
pub const SO_REUSEADDR = ws2_32.SO_REUSEADDR;
pub const SO_KEEPALIVE = ws2_32.SO_KEEPALIVE;
pub const SO_DONTROUTE = ws2_32.SO_DONTROUTE;
pub const SO_BROADCAST = ws2_32.SO_BROADCAST;
pub const SO_USELOOPBACK = ws2_32.SO_USELOOPBACK;
pub const SO_LINGER = ws2_32.SO_LINGER;
pub const SO_OOBINLINE = ws2_32.SO_OOBINLINE;

pub const SO_DONTLINGER = ws2_32.SO_DONTLINGER;
pub const SO_EXCLUSIVEADDRUSE = ws2_32.SO_EXCLUSIVEADDRUSE;

pub const SO_SNDBUF = ws2_32.SO_SNDBUF;
pub const SO_RCVBUF = ws2_32.SO_RCVBUF;
pub const SO_SNDLOWAT = ws2_32.SO_SNDLOWAT;
pub const SO_RCVLOWAT = ws2_32.SO_RCVLOWAT;
pub const SO_SNDTIMEO = ws2_32.SO_SNDTIMEO;
pub const SO_RCVTIMEO = ws2_32.SO_RCVTIMEO;
pub const SO_ERROR = ws2_32.SO_ERROR;
pub const SO_TYPE = ws2_32.SO_TYPE;

pub const SO_GROUP_ID = ws2_32.SO_GROUP_ID;
pub const SO_GROUP_PRIORITY = ws2_32.SO_GROUP_PRIORITY;
pub const SO_MAX_MSG_SIZE = ws2_32.SO_MAX_MSG_SIZE;
pub const SO_PROTOCOL_INFOA = ws2_32.SO_PROTOCOL_INFOA;
pub const SO_PROTOCOL_INFOW = ws2_32.SO_PROTOCOL_INFOW;

pub const PVD_CONFIG = ws2_32.PVD_CONFIG;
pub const SO_CONDITIONAL_ACCEPT = ws2_32.SO_CONDITIONAL_ACCEPT;

pub const TCP_NODELAY = ws2_32.TCP_NODELAY;

pub const O_RDONLY = 0o0;
pub const O_WRONLY = 0o1;
pub const O_RDWR = 0o2;

pub const O_CREAT = 0o100;
pub const O_EXCL = 0o200;
pub const O_NOCTTY = 0o400;
pub const O_TRUNC = 0o1000;
pub const O_APPEND = 0o2000;
pub const O_NONBLOCK = 0o4000;
pub const O_DSYNC = 0o10000;
pub const O_SYNC = 0o4010000;
pub const O_RSYNC = 0o4010000;
pub const O_DIRECTORY = 0o200000;
pub const O_NOFOLLOW = 0o400000;
pub const O_CLOEXEC = 0o2000000;

pub const O_ASYNC = 0o20000;
pub const O_DIRECT = 0o40000;
pub const O_LARGEFILE = 0;
pub const O_NOATIME = 0o1000000;
pub const O_PATH = 0o10000000;
pub const O_TMPFILE = 0o20200000;
pub const O_NDELAY = O_NONBLOCK;

pub const IFNAMESIZE = 30;
