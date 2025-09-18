const std = @import("../std.zig");
const clock_t = std.c.clock_t;
const pid_t = std.c.pid_t;
const pthread_t = std.c.pthread_t;
const sigval_t = std.c.sigval_t;
const uid_t = std.c.uid_t;

pub extern "c" fn ptrace(request: c_int, pid: pid_t, addr: ?*anyopaque, data: c_int) c_int;

pub const lwpid_t = i32;

pub extern "c" fn _lwp_self() lwpid_t;
pub extern "c" fn pthread_setname_np(thread: pthread_t, name: [*:0]const u8, arg: ?*anyopaque) c_int;

pub const TCIFLUSH = 1;
pub const TCOFLUSH = 2;
pub const TCIOFLUSH = 3;
pub const TCOOFF = 1;
pub const TCOON = 2;
pub const TCIOFF = 3;
pub const TCION = 4;

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
            addr: *allowzero anyopaque,
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

// https://github.com/NetBSD/src/blob/80bf25a5691072d4755e84567ccbdf0729370dea/sys/netinet/in.h#L276
pub const IP = struct {
    pub const OPTIONS = 1;
    pub const HDRINCL = 2;
    pub const TOS = 3;
    pub const TTL = 4;
    pub const RECVOPTS = 5;
    pub const RECVRETOPTS = 6;
    pub const RECVDSTADDR = 7;
    pub const RETOPTS = 8;
    pub const MULTICAST_IF = 9;
    pub const MULTICAST_TTL = 10;
    pub const MULTICAST_LOOP = 11;
    pub const ADD_MEMBERSHIP = 12;
    pub const DROP_MEMBERSHIP = 13;
    pub const PORTALGO = 18;
    pub const PORTRANGE = 19;
    pub const RECVIF = 20;
    pub const ERRORMTU = 21;
    pub const IPSEC_POLICY = 22;
    pub const RECVTTL = 23;
    pub const MINTTL = 24;
    pub const PKTINFO = 25;
    pub const RECVPKTINFO = 26;
    pub const BINDANY = 27;
    pub const SENDSRCADDR = RECVDSTADDR;
    pub const DEFAULT_MULTICAST_TTL = 1;
    pub const DEFAULT_MULTICAST_LOOP = 1;
    pub const MAX_MEMBERSHIPS = 20;
    pub const PORTRANGE_DEFAULT = 0;
    pub const PORTRANGE_HIGH = 1;
    pub const PORTRANGE_LOW = 2;
};

// https://github.com/NetBSD/src/blob/80bf25a5691072d4755e84567ccbdf0729370dea/sys/netinet6/in6.h#L370
pub const IPV6 = struct {
    pub const UNICAST_HOPS = 4;
    pub const MULTICAST_IF = 9;
    pub const MULTICAST_HOPS = 10;
    pub const MULTICAST_LOOP = 11;
    pub const JOIN_GROUP = 12;
    pub const LEAVE_GROUP = 13;
    pub const PORTRANGE = 14;
    pub const PORTALGO = 17;
    pub const @"2292PKTINFO" = 19;
    pub const @"2292HOPLIMIT" = 20;
    pub const @"2292NEXTHOP" = 21;
    pub const @"2292HOPOPTS" = 22;
    pub const @"2292DSTOPTS" = 23;
    pub const @"2292RTHDR" = 24;
    pub const @"2292PKTOPTIONS" = 25;
    pub const CHECKSUM = 26;
    pub const V6ONLY = 27;
    pub const IPSEC_POLICY = 28;
    pub const FAITH = 29;
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
    pub const PKTINFO = 46;
    pub const HOPLIMIT = 47;
    pub const NEXTHOP = 48;
    pub const HOPOPTS = 49;
    pub const DSTOPTS = 50;
    pub const RTHDR = 51;
    pub const RECVTCLASS = 57;
    pub const OTCLASS = 58;
    pub const TCLASS = 61;
    pub const DONTFRAG = 62;
    pub const PREFER_TEMPADDR = 63;
    pub const BINDANY = 64;
    pub const RTHDR_LOOSE = 0;
    pub const RTHDR_STRICT = 1;
    pub const RTHDR_TYPE_0 = 0;
    pub const DEFAULT_MULTICAST_HOPS = 1;
    pub const DEFAULT_MULTICAST_LOOP = 1;
    pub const PORTRANGE_DEFAULT = 0;
    pub const PORTRANGE_HIGH = 1;
    pub const PORTRANGE_LOW = 2;
};

// https://github.com/NetBSD/src/blob/80bf25a5691072d4755e84567ccbdf0729370dea/sys/netinet/ip.h#L140
pub const IPTOS = struct {
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
    pub const DSCP_EF = 0xb8;
    pub const DSCP_CS6 = 0xc0;
    pub const DSCP_CS7 = 0xe0;
    pub const CLASS_CS0 = 0x00;
    pub const CLASS_CS1 = 0x20;
    pub const CLASS_CS2 = 0x40;
    pub const CLASS_CS3 = 0x60;
    pub const CLASS_CS4 = 0x80;
    pub const CLASS_CS5 = 0xa0;
    pub const CLASS_CS6 = 0xc0;
    pub const CLASS_CS7 = 0xe0;
    pub const CLASS_DEFAULT = CLASS_CS0;
    pub const CLASS_MASK = 0xe0;
    pub fn CLASS(t: anytype) @TypeOf(t) {
        return t & CLASS_MASK;
    }
    pub const DSCP_MASK = 0xfc;
    pub fn DSCP(t: anytype) @TypeOf(t) {
        return t & DSCP_MASK;
    }
    pub const ECN_NOTECT = 0x00;
    pub const ECN_ECT1 = 0x01;
    pub const ECN_ECT0 = 0x02;
    pub const ECN_CE = 0x03;
    pub const ECN_MASK = 0x03;
    pub fn ECN(t: anytype) @TypeOf(t) {
        return t & ECN_MASK;
    }
    pub const ECN_NOT_ECT = 0x00;
    pub const LOWDELAY = 0x10;
    pub const THROUGHPUT = 0x08;
    pub const RELIABILITY = 0x04;
    pub const MINCOST = 0x02;
    pub const CE = 0x01;
    pub const ECT = 0x02;
    pub const PREC_NETCONTROL = 0xe0;
    pub const PREC_INTERNETCONTROL = 0xc0;
    pub const PREC_CRITIC_ECP = 0xa0;
    pub const PREC_FLASHOVERRIDE = 0x80;
    pub const PREC_FLASH = 0x60;
    pub const PREC_IMMEDIATE = 0x40;
    pub const PREC_PRIORITY = 0x20;
    pub const PREC_ROUTINE = 0x00;
};
