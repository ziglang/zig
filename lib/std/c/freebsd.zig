const builtin = @import("builtin");
const std = @import("../std.zig");
const assert = std.debug.assert;

const PATH_MAX = std.c.PATH_MAX;
const blkcnt_t = std.c.blkcnt_t;
const blksize_t = std.c.blksize_t;
const caddr_t = std.c.caddr_t;
const dev_t = std.c.dev_t;
const fd_t = std.c.fd_t;
const gid_t = std.c.gid_t;
const ino_t = std.c.ino_t;
const iovec_const = std.posix.iovec_const;
const mode_t = std.c.mode_t;
const nlink_t = std.c.nlink_t;
const off_t = std.c.off_t;
const pid_t = std.c.pid_t;
const sockaddr = std.c.sockaddr;
const time_t = std.c.time_t;
const timespec = std.c.timespec;
const uid_t = std.c.uid_t;
const sf_hdtr = std.c.sf_hdtr;
const clockid_t = std.c.clockid_t;

comptime {
    assert(builtin.os.tag == .freebsd); // Prevent access of std.c symbols on wrong OS.
}

pub extern "c" fn ptrace(request: c_int, pid: pid_t, addr: caddr_t, data: c_int) c_int;

pub extern "c" fn kinfo_getfile(pid: pid_t, cntp: *c_int) ?[*]kinfo_file;
pub extern "c" fn copy_file_range(fd_in: fd_t, off_in: ?*off_t, fd_out: fd_t, off_out: ?*off_t, len: usize, flags: u32) usize;

pub extern "c" fn sendfile(
    in_fd: fd_t,
    out_fd: fd_t,
    offset: off_t,
    nbytes: usize,
    sf_hdtr: ?*sf_hdtr,
    sbytes: ?*off_t,
    flags: u32,
) c_int;

pub const UMTX_OP = enum(c_int) {
    LOCK = 0,
    UNLOCK = 1,
    WAIT = 2,
    WAKE = 3,
    MUTEX_TRYLOCK = 4,
    MUTEX_LOCK = 5,
    MUTEX_UNLOCK = 6,
    SET_CEILING = 7,
    CV_WAIT = 8,
    CV_SIGNAL = 9,
    CV_BROADCAST = 10,
    WAIT_UINT = 11,
    RW_RDLOCK = 12,
    RW_WRLOCK = 13,
    RW_UNLOCK = 14,
    WAIT_UINT_PRIVATE = 15,
    WAKE_PRIVATE = 16,
    MUTEX_WAIT = 17,
    MUTEX_WAKE = 18, // deprecated
    SEM_WAIT = 19, // deprecated
    SEM_WAKE = 20, // deprecated
    NWAKE_PRIVATE = 31,
    MUTEX_WAKE2 = 22,
    SEM2_WAIT = 23,
    SEM2_WAKE = 24,
    SHM = 25,
    ROBUST_LISTS = 26,
};

pub const UMTX_ABSTIME = 0x01;
pub const _umtx_time = extern struct {
    timeout: timespec,
    flags: u32,
    clockid: clockid_t,
};

pub extern "c" fn _umtx_op(obj: usize, op: c_int, val: c_ulong, uaddr: usize, uaddr2: usize) c_int;

pub const fflags_t = u32;

pub const Stat = extern struct {
    /// The inode's device.
    dev: dev_t,
    /// The inode's number.
    ino: ino_t,
    /// Number of hard links.
    nlink: nlink_t,
    /// Inode protection mode.
    mode: mode_t,
    __pad0: i16,
    /// User ID of the file's owner.
    uid: uid_t,
    /// Group ID of the file's group.
    gid: gid_t,
    __pad1: i32,
    /// Device type.
    rdev: dev_t,
    /// Time of last access.
    atim: timespec,
    /// Time of last data modification.
    mtim: timespec,
    /// Time of last file status change.
    ctim: timespec,
    /// Time of file creation.
    birthtim: timespec,
    /// File size, in bytes.
    size: off_t,
    /// Blocks allocated for file.
    blocks: blkcnt_t,
    /// Optimal blocksize for I/O.
    blksize: blksize_t,
    /// User defined flags for file.
    flags: fflags_t,
    /// File generation number.
    gen: u64,
    __spare: [10]u64,

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

pub const fsblkcnt_t = u64;
pub const fsfilcnt_t = u64;

pub const CAP_RIGHTS_VERSION = 0;

pub const cap_rights = extern struct {
    rights: [CAP_RIGHTS_VERSION + 2]u64,
};

pub const kinfo_file = extern struct {
    /// Size of this record.
    /// A zero value is for the sentinel record at the end of an array.
    structsize: c_int,
    /// Descriptor type.
    type: c_int,
    /// Array index.
    fd: fd_t,
    /// Reference count.
    ref_count: c_int,
    /// Flags.
    flags: c_int,
    // 64bit padding.
    _pad0: c_int,
    /// Seek location.
    offset: i64,
    un: extern union {
        socket: extern struct {
            /// Sendq size.
            sendq: u32,
            /// Socket domain.
            domain: c_int,
            /// Socket type.
            type: c_int,
            /// Socket protocol.
            protocol: c_int,
            /// Socket address.
            address: sockaddr.storage,
            /// Peer address.
            peer: sockaddr.storage,
            /// Address of so_pcb.
            pcb: u64,
            /// Address of inp_ppcb.
            inpcb: u64,
            /// Address of unp_conn.
            unpconn: u64,
            /// Send buffer state.
            snd_sb_state: u16,
            /// Receive buffer state.
            rcv_sb_state: u16,
            /// Recvq size.
            recvq: u32,
        },
        file: extern struct {
            /// Vnode type.
            type: i32,
            // Reserved for future use
            _spare1: [3]i32,
            _spare2: [30]u64,
            /// Vnode filesystem id.
            fsid: u64,
            /// File device.
            rdev: u64,
            /// Global file id.
            fileid: u64,
            /// File size.
            size: u64,
            /// fsid compat for FreeBSD 11.
            fsid_freebsd11: u32,
            /// rdev compat for FreeBSD 11.
            rdev_freebsd11: u32,
            /// File mode.
            mode: u16,
            // 64bit padding.
            _pad0: u16,
            _pad1: u32,
        },
        sem: extern struct {
            _spare0: [4]u32,
            _spare1: [32]u64,
            /// Semaphore value.
            value: u32,
            /// Semaphore mode.
            mode: u16,
        },
        pipe: extern struct {
            _spare1: [4]u32,
            _spare2: [32]u64,
            addr: u64,
            peer: u64,
            buffer_cnt: u32,
            // 64bit padding.
            kf_pipe_pad0: [3]u32,
        },
        proc: extern struct {
            _spare1: [4]u32,
            _spare2: [32]u64,
            pid: pid_t,
        },
        eventfd: extern struct {
            value: u64,
            flags: u32,
        },
    },
    /// Status flags.
    status: u16,
    // 32-bit alignment padding.
    _pad1: u16,
    // Reserved for future use.
    _spare: c_int,
    /// Capability rights.
    cap_rights: cap_rights,
    /// Reserved for future cap_rights
    _cap_spare: u64,
    /// Path to file, if any.
    path: [PATH_MAX - 1:0]u8,

    comptime {
        assert(@sizeOf(@This()) == KINFO_FILE_SIZE);
        assert(@alignOf(@This()) == @sizeOf(u64));
    }
};

pub const KINFO_FILE_SIZE = 1392;

pub const MFD = struct {
    pub const CLOEXEC = 0x0001;
    pub const ALLOW_SEALING = 0x0002;
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
    ROFS = 30, // Read-only filesystem
    MLINK = 31, // Too many links
    PIPE = 32, // Broken pipe

    // math software
    DOM = 33, // Numerical argument out of domain
    RANGE = 34, // Result too large

    // non-blocking and interrupt i/o

    /// Resource temporarily unavailable
    /// This code is also used for `WOULDBLOCK`: operation would block.
    AGAIN = 35,
    INPROGRESS = 36, // Operation now in progress
    ALREADY = 37, // Operation already in progress

    // ipc/network software -- argument errors
    NOTSOCK = 38, // Socket operation on non-socket
    DESTADDRREQ = 39, // Destination address required
    MSGSIZE = 40, // Message too long
    PROTOTYPE = 41, // Protocol wrong type for socket
    NOPROTOOPT = 42, // Protocol not available
    PROTONOSUPPORT = 43, // Protocol not supported
    SOCKTNOSUPPORT = 44, // Socket type not supported
    /// Operation not supported
    /// This code is also used for `NOTSUP`.
    OPNOTSUPP = 45,
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
    IDRM = 82, // Identifier removed
    NOMSG = 83, // No message of desired type
    OVERFLOW = 84, // Value too large to be stored in data type
    CANCELED = 85, // Operation canceled
    ILSEQ = 86, // Illegal byte sequence
    NOATTR = 87, // Attribute not found

    DOOFUS = 88, // Programming error

    BADMSG = 89, // Bad message
    MULTIHOP = 90, // Multihop attempted
    NOLINK = 91, // Link has been severed
    PROTO = 92, // Protocol error

    NOTCAPABLE = 93, // Capabilities insufficient
    CAPMODE = 94, // Not permitted in capability mode
    NOTRECOVERABLE = 95, // State not recoverable
    OWNERDEAD = 96, // Previous owner died
    INTEGRITY = 97, // Integrity check failed
    _,
};

// https://github.com/freebsd/freebsd-src/blob/9bfbc6826f72eb385bf52f4cde8080bccf7e3ebd/sys/netinet/in.h#L436
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
    pub const IPSEC_POLICY = 21;
    pub const ONESBCAST = 23;
    pub const BINDANY = 24;
    pub const ORIGDSTADDR = 27;
    pub const RECVORIGDSTADDR = ORIGDSTADDR;
    pub const FW_TABLE_ADD = 40;
    pub const FW_TABLE_DEL = 41;
    pub const FW_TABLE_FLUSH = 42;
    pub const FW_TABLE_GETSIZE = 43;
    pub const FW_TABLE_LIST = 44;
    pub const FW3 = 48;
    pub const DUMMYNET3 = 49;
    pub const FW_ADD = 50;
    pub const FW_DEL = 51;
    pub const FW_FLUSH = 52;
    pub const FW_ZERO = 53;
    pub const FW_GET = 54;
    pub const FW_RESETLOG = 55;
    pub const FW_NAT_CFG = 56;
    pub const FW_NAT_DEL = 57;
    pub const FW_NAT_GET_CONFIG = 58;
    pub const FW_NAT_GET_LOG = 59;
    pub const DUMMYNET_CONFIGURE = 60;
    pub const DUMMYNET_DEL = 61;
    pub const DUMMYNET_FLUSH = 62;
    pub const DUMMYNET_GET = 64;
    pub const RECVTTL = 65;
    pub const MINTTL = 66;
    pub const DONTFRAG = 67;
    pub const RECVTOS = 68;
    pub const ADD_SOURCE_MEMBERSHIP = 70;
    pub const DROP_SOURCE_MEMBERSHIP = 71;
    pub const BLOCK_SOURCE = 72;
    pub const UNBLOCK_SOURCE = 73;
    pub const MSFILTER = 74;
    pub const VLAN_PCP = 75;
    pub const FLOWID = 90;
    pub const FLOWTYPE = 91;
    pub const RSSBUCKETID = 92;
    pub const RECVFLOWID = 93;
    pub const RECVRSSBUCKETID = 94;
    // Same namespace, but these are arguments rather than option names
    pub const DEFAULT_MULTICAST_TTL = 1;
    pub const DEFAULT_MULTICAST_LOOP = 1;
    pub const MAX_MEMBERSHIPS = 4095;
    pub const MAX_GROUP_SRC_FILTER = 512;
    pub const MAX_SOCK_SRC_FILTER = 128;
    pub const MAX_SOCK_MUTE_FILTER = 128;
    pub const PORTRANGE_DEFAULT = 0;
    pub const PORTRANGE_HIGH = 1;
    pub const PORTRANGE_LOW = 2;
};

// https://github.com/freebsd/freebsd-src/blob/9bfbc6826f72eb385bf52f4cde8080bccf7e3ebd/sys/netinet6/in6.h#L402
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
    pub const IPSEC_POLICY = 28;
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
    pub const BINDANY = 64;
    pub const FLOWID = 67;
    pub const FLOWTYPE = 68;
    pub const RSSBUCKETID = 69;
    pub const RECVFLOWID = 70;
    pub const RECVRSSBUCKETID = 71;
    pub const ORIGDSTADDR = 72;
    pub const RECVORIGDSTADDR = ORIGDSTADDR;
    pub const MSFILTER = 74;
    pub const VLAN_PCP = 75;
    // Same namespace, but these are arguments rather than option names
    pub const RTHDR_LOOSE = 0;
    pub const RTHDR_STRICT = 1;
    pub const RTHDR_TYPE_0 = 0;
    pub const DEFAULT_MULTICAST_HOPS = 1;
    pub const DEFAULT_MULTICAST_LOOP = 1;
    pub const MAX_MEMBERSHIPS = 4095;
    pub const MAX_GROUP_SRC_FILTER = 512;
    pub const MAX_SOCK_SRC_FILTER = 128;
    pub const PORTRANGE_DEFAULT = 0;
    pub const PORTRANGE_HIGH = 1;
    pub const PORTRANGE_LOW = 2;
};

// https://github.com/freebsd/freebsd-src/blob/9bfbc6826f72eb385bf52f4cde8080bccf7e3ebd/sys/netinet/ip.h#L77
pub const IPTOS = struct {
    pub const LOWDELAY = 0x10;
    pub const THROUGHPUT = 0x08;
    pub const RELIABILITY = 0x04;
    pub const MINCOST = DSCP_CS0;
    pub const PREC_ROUTINE = DSCP_CS0;
    pub const PREC_PRIORITY = DSCP_CS1;
    pub const PREC_IMMEDIATE = DSCP_CS2;
    pub const PREC_FLASH = DSCP_CS3;
    pub const PREC_FLASHOVERRIDE = DSCP_CS4;
    pub const PREC_CRITIC_ECP = DSCP_CS5;
    pub const PREC_INTERNETCONTROL = DSCP_CS6;
    pub const PREC_NETCONTROL = DSCP_CS7;
    pub const DSCP_OFFSET = 2;
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
