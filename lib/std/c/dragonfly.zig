const std = @import("../std.zig");

const SIG = std.c.SIG;
const caddr_t = std.c.caddr_t;
const gid_t = std.c.gid_t;
const iovec = std.c.iovec;
const pid_t = std.c.pid_t;
const socklen_t = std.c.socklen_t;
const uid_t = std.c.uid_t;

pub extern "c" fn lwp_gettid() c_int;
pub extern "c" fn ptrace(request: c_int, pid: pid_t, addr: caddr_t, data: c_int) c_int;
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

pub const sig_t = *const fn (i32) callconv(.c) void;

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

// https://github.com/DragonFlyBSD/DragonFlyBSD/blob/6098912863ed4c7b3f70d7483910ce2956cf4ed3/sys/netinet/ip.h#L94
pub const IP = struct {
    pub const OPTIONS = 1;
    pub const HDRINCL = 2;
    pub const TOS = 3;
    pub const TTL = 4;
    pub const RECVOPTS = 5;
    pub const RECVRETOPTS = 6;
    pub const RECVDSTADDR = 7;
    pub const SENDSRCADDR = RECVDSTADDR;
    pub const RETOPTS = 8;
    pub const MULTICAST_IF = 9;
    pub const MULTICAST_TTL = 10;
    pub const MULTICAST_LOOP = 11;
    pub const ADD_MEMBERSHIP = 12;
    pub const DROP_MEMBERSHIP = 13;
    pub const MULTICAST_VIF = 14;
    pub const RSVP_ON = 15;
    pub const RSVP_OFF = 16;
    pub const RSVP_VIF_ON = 17;
    pub const RSVP_VIF_OFF = 18;
    pub const PORTRANGE = 19;
    pub const RECVIF = 20;
    pub const FW_TBL_CREATE = 40;
    pub const FW_TBL_DESTROY = 41;
    pub const FW_TBL_ADD = 42;
    pub const FW_TBL_DEL = 43;
    pub const FW_TBL_FLUSH = 44;
    pub const FW_TBL_GET = 45;
    pub const FW_TBL_ZERO = 46;
    pub const FW_TBL_EXPIRE = 47;
    pub const FW_X = 49;
    pub const FW_ADD = 50;
    pub const FW_DEL = 51;
    pub const FW_FLUSH = 52;
    pub const FW_ZERO = 53;
    pub const FW_GET = 54;
    pub const FW_RESETLOG = 55;
    pub const DUMMYNET_CONFIGURE = 60;
    pub const DUMMYNET_DEL = 61;
    pub const DUMMYNET_FLUSH = 62;
    pub const DUMMYNET_GET = 64;
    pub const RECVTTL = 65;
    pub const MINTTL = 66;
    pub const RECVTOS = 68;
    // Same namespace, but these are arguments rather than option names
    pub const DEFAULT_MULTICAST_TTL = 1;
    pub const DEFAULT_MULTICAST_LOOP = 1;
    pub const MAX_MEMBERSHIPS = 20;
    pub const PORTRANGE_DEFAULT = 0;
    pub const PORTRANGE_HIGH = 1;
    pub const PORTRANGE_LOW = 2;
};

// https://github.com/DragonFlyBSD/DragonFlyBSD/blob/6098912863ed4c7b3f70d7483910ce2956cf4ed3/sys/netinet6/in6.h#L448
pub const IPV6 = struct {
    pub const UNICAST_HOPS = 4;
    pub const MULTICAST_IF = 9;
    pub const MULTICAST_HOPS = 10;
    pub const MULTICAST_LOOP = 11;
    pub const JOIN_GROUP = 12;
    pub const LEAVE_GROUP = 13;
    pub const PORTRANGE = 14;
    pub const @"2292PKTINFO" = 19;
    pub const @"2292HOPLIMIT" = 20;
    pub const @"2292NEXTHOP" = 21;
    pub const @"2292HOPOPTS" = 22;
    pub const @"2292DSTOPTS" = 23;
    pub const @"2292RTHDR" = 24;
    pub const @"2292PKTOPTIONS" = 25;
    pub const CHECKSUM = 26;
    pub const V6ONLY = 27;
    pub const BINDV6ONLY = V6ONLY;
    pub const FW_ADD = 30;
    pub const FW_DEL = 31;
    pub const FW_FLUSH = 32;
    pub const FW_ZERO = 33;
    pub const FW_GET = 34;
    pub const RTHDRDSTOPTS = 35;
    pub const RECVPKTINFO = 36;
    pub const RECVHOPLIMIT = 37;
    pub const RECVRTHDR = 38;
    pub const RECVHOPOPTS = 39;
    pub const RECVDSTOPTS = 40;
    pub const RECVRTHDRDSTOPTS = 41;
    pub const USE_MIN_MTU = 42;
    pub const RECVPATHMTU = 43;
    pub const PATHMTU = 44;
    pub const REACHCONF = 45;
    pub const PKTINFO = 46;
    pub const HOPLIMIT = 47;
    pub const NEXTHOP = 48;
    pub const HOPOPTS = 49;
    pub const DSTOPTS = 50;
    pub const RTHDR = 51;
    pub const PKTOPTIONS = 52;
    pub const RECVTCLASS = 57;
    pub const AUTOFLOWLABEL = 59;
    pub const TCLASS = 61;
    pub const DONTFRAG = 62;
    pub const PREFER_TEMPADDR = 63;
    pub const MSFILTER = 74;
    // Same namespace, but these are arguments rather than option names
    pub const RTHDR_LOOSE = 0;
    pub const RTHDR_STRICT = 1;
    pub const RTHDR_TYPE_0 = 0;
    pub const DEFAULT_MULTICAST_HOPS = 1;
    pub const DEFAULT_MULTICAST_LOOP = 1;
    pub const PORTRANGE_DEFAULT = 0;
    pub const PORTRANGE_HIGH = 1;
    pub const PORTRANGE_LOW = 2;
};

// https://github.com/DragonFlyBSD/DragonFlyBSD/blob/6098912863ed4c7b3f70d7483910ce2956cf4ed3/sys/netinet/ip.h#L94
pub const IPTOS = struct {
    pub const LOWDELAY = 0x10;
    pub const THROUGHPUT = 0x08;
    pub const RELIABILITY = 0x04;
    pub const MINCOST = 0x02;
    pub const CE = 0x01;
    pub const ECT = 0x02;
    pub const PREC_ROUTINE = DSCP_CS0;
    pub const PREC_PRIORITY = DSCP_CS1;
    pub const PREC_IMMEDIATE = DSCP_CS2;
    pub const PREC_FLASH = DSCP_CS3;
    pub const PREC_FLASHOVERRIDE = DSCP_CS4;
    pub const PREC_CRITIC_ECP = DSCP_CS5;
    pub const PREC_INTERNETCONTROL = DSCP_CS6;
    pub const PREC_NETCONTROL = DSCP_CS7;
    pub const DSCP_CS0 = 0x00;
    pub const DSCP_CS1 = 0x20;
    pub const DSCP_AF11 = 0x28;
    pub const DSCP_AF12 = 0x30;
    pub const DSCP_AF13 = 0x38;
    pub const DSCP_CS2 = 0x40;
    pub const DSCP_AF21 = 0x48;
    pub const DSCP_AF22 = 0x50;
    pub const DSCP_AF23 = 0x58;
    pub const DSCP_CS3 = 0x60;
    pub const DSCP_AF31 = 0x68;
    pub const DSCP_AF32 = 0x70;
    pub const DSCP_AF33 = 0x78;
    pub const DSCP_CS4 = 0x80;
    pub const DSCP_AF41 = 0x88;
    pub const DSCP_AF42 = 0x90;
    pub const DSCP_AF43 = 0x98;
    pub const DSCP_CS5 = 0xa0;
    pub const DSCP_VA = 0xb0;
    pub const DSCP_EF = 0xb8;
    pub const DSCP_CS6 = 0xc0;
    pub const DSCP_CS7 = 0xe0;
    pub const ECN_NOTECT = 0x00;
    pub const ECN_ECT1 = 0x01;
    pub const ECN_ECT0 = 0x02;
    pub const ECN_CE = 0x03;
    pub const ECN_MASK = 0x03;
};
