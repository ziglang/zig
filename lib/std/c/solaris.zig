const std = @import("../std.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;
const iovec = std.os.iovec;
const iovec_const = std.os.iovec_const;
const timezone = std.c.timezone;

extern "c" fn ___errno() *c_int;
pub const _errno = ___errno;

pub const dl_iterate_phdr_callback = *const fn (info: *dl_phdr_info, size: usize, data: ?*anyopaque) callconv(.C) c_int;
pub extern "c" fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*anyopaque) c_int;

pub extern "c" fn getdents(fd: c_int, buf_ptr: [*]u8, nbytes: usize) usize;
pub extern "c" fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) c_int;
pub extern "c" fn pipe2(fds: *[2]fd_t, flags: u32) c_int;
pub extern "c" fn arc4random_buf(buf: [*]u8, len: usize) void;
pub extern "c" fn posix_memalign(memptr: *?*anyopaque, alignment: usize, size: usize) c_int;
pub extern "c" fn sysconf(sc: c_int) i64;
pub extern "c" fn signalfd(fd: fd_t, mask: *const sigset_t, flags: u32) c_int;
pub extern "c" fn madvise(address: [*]u8, len: usize, advise: u32) c_int;

pub const pthread_mutex_t = extern struct {
    flag1: u16 = 0,
    flag2: u8 = 0,
    ceiling: u8 = 0,
    type: u16 = 0,
    magic: u16 = 0x4d58,
    lock: u64 = 0,
    data: u64 = 0,
};
pub const pthread_cond_t = extern struct {
    flag: [4]u8 = [_]u8{0} ** 4,
    type: u16 = 0,
    magic: u16 = 0x4356,
    data: u64 = 0,
};
pub const pthread_rwlock_t = extern struct {
    readers: i32 = 0,
    type: u16 = 0,
    magic: u16 = 0x5257,
    mutex: pthread_mutex_t = .{},
    readercv: pthread_cond_t = .{},
    writercv: pthread_cond_t = .{},
};
pub const pthread_attr_t = extern struct {
    mutexattr: ?*anyopaque = null,
};
pub const pthread_key_t = c_int;

pub const sem_t = extern struct {
    count: u32 = 0,
    type: u16 = 0,
    magic: u16 = 0x534d,
    __pad1: [3]u64 = [_]u64{0} ** 3,
    __pad2: [2]u64 = [_]u64{0} ** 2,
};

pub extern "c" fn pthread_setname_np(thread: std.c.pthread_t, name: [*:0]const u8, arg: ?*anyopaque) E;
pub extern "c" fn pthread_getname_np(thread: std.c.pthread_t, name: [*:0]u8, len: usize) E;

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
pub const suseconds_t = i64;
pub const uid_t = u32;
pub const major_t = u32;
pub const minor_t = u32;
pub const port_t = c_int;
pub const nfds_t = usize;
pub const id_t = i32;
pub const taskid_t = id_t;
pub const projid_t = id_t;
pub const poolid_t = id_t;
pub const zoneid_t = id_t;
pub const ctid_t = id_t;

pub const dl_phdr_info = extern struct {
    dlpi_addr: std.elf.Addr,
    dlpi_name: ?[*:0]const u8,
    dlpi_phdr: [*]std.elf.Phdr,
    dlpi_phnum: std.elf.Half,
    /// Incremented when a new object is mapped into the process.
    dlpi_adds: u64,
    /// Incremented when an object is unmapped from the process.
    dlpi_subs: u64,
};

pub const RTLD = struct {
    pub const LAZY = 0x00001;
    pub const NOW = 0x00002;
    pub const NOLOAD = 0x00004;
    pub const GLOBAL = 0x00100;
    pub const LOCAL = 0x00000;
    pub const PARENT = 0x00200;
    pub const GROUP = 0x00400;
    pub const WORLD = 0x00800;
    pub const NODELETE = 0x01000;
    pub const FIRST = 0x02000;
    pub const CONFGEN = 0x10000;

    pub const NEXT = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));
    pub const DEFAULT = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -2)))));
    pub const SELF = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -3)))));
    pub const PROBE = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -4)))));
};

pub const Flock = extern struct {
    type: c_short,
    whence: c_short,
    start: off_t,
    // len == 0 means until end of file.
    len: off_t,
    sysid: c_int,
    pid: pid_t,
    __pad: [4]c_long,
};

pub const utsname = extern struct {
    sysname: [256:0]u8,
    nodename: [256:0]u8,
    release: [256:0]u8,
    version: [256:0]u8,
    machine: [256:0]u8,
    domainname: [256:0]u8,
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

pub const EAI = enum(c_int) {
    /// address family for hostname not supported
    ADDRFAMILY = 1,
    /// name could not be resolved at this time
    AGAIN = 2,
    /// flags parameter had an invalid value
    BADFLAGS = 3,
    /// non-recoverable failure in name resolution
    FAIL = 4,
    /// address family not recognized
    FAMILY = 5,
    /// memory allocation failure
    MEMORY = 6,
    /// no address associated with hostname
    NODATA = 7,
    /// name does not resolve
    NONAME = 8,
    /// service not recognized for socket type
    SERVICE = 9,
    /// intended socket type was not recognized
    SOCKTYPE = 10,
    /// system error returned in errno
    SYSTEM = 11,
    /// argument buffer overflow
    OVERFLOW = 12,
    /// resolved protocol is unknown
    PROTOCOL = 13,

    _,
};

pub const EAI_MAX = 14;

pub const msghdr = extern struct {
    /// optional address
    msg_name: ?*sockaddr,
    /// size of address
    msg_namelen: socklen_t,
    /// scatter/gather array
    msg_iov: [*]iovec,
    /// # elements in msg_iov
    msg_iovlen: i32,
    /// ancillary data
    msg_control: ?*anyopaque,
    /// ancillary data buffer len
    msg_controllen: socklen_t,
    /// flags on received message
    msg_flags: i32,
};

pub const msghdr_const = extern struct {
    /// optional address
    msg_name: ?*const sockaddr,
    /// size of address
    msg_namelen: socklen_t,
    /// scatter/gather array
    msg_iov: [*]const iovec_const,
    /// # elements in msg_iov
    msg_iovlen: i32,
    /// ancillary data
    msg_control: ?*const anyopaque,
    /// ancillary data buffer len
    msg_controllen: socklen_t,
    /// flags on received message
    msg_flags: i32,
};

pub const cmsghdr = extern struct {
    cmsg_len: socklen_t,
    cmsg_level: i32,
    cmsg_type: i32,
};

/// The stat structure used by libc.
pub const Stat = extern struct {
    dev: dev_t,
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    size: off_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    blksize: blksize_t,
    blocks: blkcnt_t,
    fstype: [16]u8,

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
    tv_sec: i64,
    tv_nsec: isize,
};

pub const timeval = extern struct {
    /// seconds
    tv_sec: time_t,
    /// microseconds
    tv_usec: suseconds_t,
};

pub const MAXNAMLEN = 511;

pub const dirent = extern struct {
    /// Inode number of entry.
    d_ino: ino_t,
    /// Offset of this entry on disk.
    d_off: off_t,
    /// Length of this record.
    d_reclen: u16,
    /// File name.
    d_name: [MAXNAMLEN:0]u8,

    pub fn reclen(self: dirent) u16 {
        return self.d_reclen;
    }
};

pub const SOCK = struct {
    /// Datagram.
    pub const DGRAM = 1;
    /// STREAM.
    pub const STREAM = 2;
    /// Raw-protocol interface.
    pub const RAW = 4;
    /// Reliably-delivered message.
    pub const RDM = 5;
    /// Sequenced packed stream.
    pub const SEQPACKET = 6;

    pub const NONBLOCK = 0x100000;
    pub const NDELAY = 0x200000;
    pub const CLOEXEC = 0x080000;
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
    pub const DGRAM_ERRIND = 0x0200;
    pub const RECVUCRED = 0x0400;

    pub const SNDBUF = 0x1001;
    pub const RCVBUF = 0x1002;
    pub const SNDLOWAT = 0x1003;
    pub const RCVLOWAT = 0x1004;
    pub const SNDTIMEO = 0x1005;
    pub const RCVTIMEO = 0x1006;
    pub const ERROR = 0x1007;
    pub const TYPE = 0x1008;
    pub const PROTOTYPE = 0x1009;
    pub const ANON_MLP = 0x100a;
    pub const MAC_EXEMPT = 0x100b;
    pub const DOMAIN = 0x100c;
    pub const RCVPSH = 0x100d;

    pub const SECATTR = 0x1011;
    pub const TIMESTAMP = 0x1013;
    pub const ALLZONES = 0x1014;
    pub const EXCLBIND = 0x1015;
    pub const MAC_IMPLICIT = 0x1016;
    pub const VRRP = 0x1017;
};

pub const SOMAXCONN = 128;

pub const SCM = struct {
    pub const UCRED = 0x1012;
    pub const RIGHTS = 0x1010;
    pub const TIMESTAMP = SO.TIMESTAMP;
};

pub const AF = struct {
    pub const UNSPEC = 0;
    pub const UNIX = 1;
    pub const LOCAL = UNIX;
    pub const FILE = UNIX;
    pub const INET = 2;
    pub const IMPLINK = 3;
    pub const PUP = 4;
    pub const CHAOS = 5;
    pub const NS = 6;
    pub const NBS = 7;
    pub const ECMA = 8;
    pub const DATAKIT = 9;
    pub const CCITT = 10;
    pub const SNA = 11;
    pub const DECnet = 12;
    pub const DLI = 13;
    pub const LAT = 14;
    pub const HYLINK = 15;
    pub const APPLETALK = 16;
    pub const NIT = 17;
    pub const @"802" = 18;
    pub const OSI = 19;
    pub const X25 = 20;
    pub const OSINET = 21;
    pub const GOSIP = 22;
    pub const IPX = 23;
    pub const ROUTE = 24;
    pub const LINK = 25;
    pub const INET6 = 26;
    pub const KEY = 27;
    pub const NCA = 28;
    pub const POLICY = 29;
    pub const INET_OFFLOAD = 30;
    pub const TRILL = 31;
    pub const PACKET = 32;
    pub const LX_NETLINK = 33;
    pub const MAX = 33;
};

pub const SOL = struct {
    pub const SOCKET = 0xffff;
    pub const ROUTE = 0xfffe;
    pub const PACKET = 0xfffd;
    pub const FILTER = 0xfffc;
};

pub const PF = struct {
    pub const UNSPEC = AF.UNSPEC;
    pub const UNIX = AF.UNIX;
    pub const LOCAL = UNIX;
    pub const FILE = UNIX;
    pub const INET = AF.INET;
    pub const IMPLINK = AF.IMPLINK;
    pub const PUP = AF.PUP;
    pub const CHAOS = AF.CHAOS;
    pub const NS = AF.NS;
    pub const NBS = AF.NBS;
    pub const ECMA = AF.ECMA;
    pub const DATAKIT = AF.DATAKIT;
    pub const CCITT = AF.CCITT;
    pub const SNA = AF.SNA;
    pub const DECnet = AF.DECnet;
    pub const DLI = AF.DLI;
    pub const LAT = AF.LAT;
    pub const HYLINK = AF.HYLINK;
    pub const APPLETALK = AF.APPLETALK;
    pub const NIT = AF.NIT;
    pub const @"802" = AF.@"802";
    pub const OSI = AF.OSI;
    pub const X25 = AF.X25;
    pub const OSINET = AF.OSINET;
    pub const GOSIP = AF.GOSIP;
    pub const IPX = AF.IPX;
    pub const ROUTE = AF.ROUTE;
    pub const LINK = AF.LINK;
    pub const INET6 = AF.INET6;
    pub const KEY = AF.KEY;
    pub const NCA = AF.NCA;
    pub const POLICY = AF.POLICY;
    pub const TRILL = AF.TRILL;
    pub const PACKET = AF.PACKET;
    pub const LX_NETLINK = AF.LX_NETLINK;
    pub const MAX = AF.MAX;
};

pub const in_port_t = u16;
pub const sa_family_t = u16;

pub const sockaddr = extern struct {
    /// address family
    family: sa_family_t,

    /// actually longer; address value
    data: [14]u8,

    pub const SS_MAXSIZE = 256;
    pub const storage = extern struct {
        family: sa_family_t align(8),
        padding: [254]u8 = undefined,

        comptime {
            assert(@sizeOf(storage) == SS_MAXSIZE);
            assert(@alignOf(storage) == 8);
        }
    };

    pub const in = extern struct {
        family: sa_family_t = AF.INET,
        port: in_port_t,
        addr: u32,
        zero: [8]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
    };

    pub const in6 = extern struct {
        family: sa_family_t = AF.INET6,
        port: in_port_t,
        flowinfo: u32,
        addr: [16]u8,
        scope_id: u32,
        __src_id: u32 = 0,
    };

    /// Definitions for UNIX IPC domain.
    pub const un = extern struct {
        family: sa_family_t = AF.UNIX,
        path: [108]u8,
    };
};

pub const AI = struct {
    /// IPv4-mapped IPv6 address
    pub const V4MAPPED = 0x0001;
    pub const ALL = 0x0002;
    /// only if any address is assigned
    pub const ADDRCONFIG = 0x0004;
    /// get address to use bind()
    pub const PASSIVE = 0x0008;
    /// fill ai_canonname
    pub const CANONNAME = 0x0010;
    /// prevent host name resolution
    pub const NUMERICHOST = 0x0020;
    /// prevent service name resolution
    pub const NUMERICSERV = 0x0040;
};

pub const NI = struct {
    pub const NOFQDN = 0x0001;
    pub const NUMERICHOST = 0x0002;
    pub const NAMEREQD = 0x0004;
    pub const NUMERICSERV = 0x0008;
    pub const DGRAM = 0x0010;
    pub const WITHSCOPEID = 0x0020;
    pub const NUMERICSCOPE = 0x0040;

    pub const MAXHOST = 1025;
    pub const MAXSERV = 32;
};

pub const PATH_MAX = 1024;
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
    pub const VIRTUAL = 1;
    pub const THREAD_CPUTIME_ID = 2;
    pub const REALTIME = 3;
    pub const MONOTONIC = 4;
    pub const PROCESS_CPUTIME_ID = 5;
    pub const HIGHRES = MONOTONIC;
    pub const PROF = THREAD_CPUTIME_ID;
};

pub const MAP = struct {
    pub const FAILED = @as(*anyopaque, @ptrFromInt(maxInt(usize)));
    pub const SHARED = 0x0001;
    pub const PRIVATE = 0x0002;
    pub const TYPE = 0x000f;

    pub const FILE = 0x0000;
    pub const FIXED = 0x0010;
    // Unimplemented
    pub const RENAME = 0x0020;
    pub const NORESERVE = 0x0040;
    /// Force mapping in lower 4G address space
    pub const @"32BIT" = 0x0080;

    pub const ANON = 0x0100;
    pub const ANONYMOUS = ANON;
    pub const ALIGN = 0x0200;
    pub const TEXT = 0x0400;
    pub const INITDATA = 0x0800;
};

pub const MSF = struct {
    pub const ASYNC = 1;
    pub const INVALIDATE = 2;
    pub const SYNC = 4;
};

pub const MADV = struct {
    /// no further special treatment
    pub const NORMAL = 0;
    /// expect random page references
    pub const RANDOM = 1;
    /// expect sequential page references
    pub const SEQUENTIAL = 2;
    /// will need these pages
    pub const WILLNEED = 3;
    /// don't need these pages
    pub const DONTNEED = 4;
    /// contents can be freed
    pub const FREE = 5;
    /// default access
    pub const ACCESS_DEFAULT = 6;
    /// next LWP to access heavily
    pub const ACCESS_LWP = 7;
    /// many processes to access heavily
    pub const ACCESS_MANY = 8;
    /// contents will be purged
    pub const PURGE = 9;
};

pub const W = struct {
    pub const EXITED = 0o001;
    pub const TRAPPED = 0o002;
    pub const UNTRACED = 0o004;
    pub const STOPPED = UNTRACED;
    pub const CONTINUED = 0o010;
    pub const NOHANG = 0o100;
    pub const NOWAIT = 0o200;

    pub fn EXITSTATUS(s: u32) u8 {
        return @as(u8, @intCast((s >> 8) & 0xff));
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

    pub fn IFCONTINUED(s: u32) bool {
        return ((s & 0o177777) == 0o177777);
    }

    pub fn IFSTOPPED(s: u32) bool {
        return (s & 0x00ff != 0o177) and !(s & 0xff00 != 0);
    }

    pub fn IFSIGNALED(s: u32) bool {
        return s & 0x00ff > 0 and s & 0xff00 == 0;
    }
};

pub const SA = struct {
    pub const ONSTACK = 0x00000001;
    pub const RESETHAND = 0x00000002;
    pub const RESTART = 0x00000004;
    pub const SIGINFO = 0x00000008;
    pub const NODEFER = 0x00000010;
    pub const NOCLDWAIT = 0x00010000;
};

// access function
pub const F_OK = 0; // test for existence of file
pub const X_OK = 1; // test for execute or search permission
pub const W_OK = 2; // test for write permission
pub const R_OK = 4; // test for read permission

pub const F = struct {
    /// Unlock a previously locked region
    pub const ULOCK = 0;
    /// Lock a region for exclusive use
    pub const LOCK = 1;
    /// Test and lock a region for exclusive use
    pub const TLOCK = 2;
    /// Test a region for other processes locks
    pub const TEST = 3;

    /// Duplicate fildes
    pub const DUPFD = 0;
    /// Get fildes flags
    pub const GETFD = 1;
    /// Set fildes flags
    pub const SETFD = 2;
    /// Get file flags
    pub const GETFL = 3;
    /// Get file flags including open-only flags
    pub const GETXFL = 45;
    /// Set file flags
    pub const SETFL = 4;

    /// Unused
    pub const CHKFL = 8;
    /// Duplicate fildes at third arg
    pub const DUP2FD = 9;
    /// Like DUP2FD with O_CLOEXEC set EINVAL is fildes matches arg1
    pub const DUP2FD_CLOEXEC = 36;
    /// Like DUPFD with O_CLOEXEC set
    pub const DUPFD_CLOEXEC = 37;

    /// Is the file desc. a stream ?
    pub const ISSTREAM = 13;
    /// Turn on private access to file
    pub const PRIV = 15;
    /// Turn off private access to file
    pub const NPRIV = 16;
    /// UFS quota call
    pub const QUOTACTL = 17;
    /// Get number of BLKSIZE blocks allocated
    pub const BLOCKS = 18;
    /// Get optimal I/O block size
    pub const BLKSIZE = 19;
    /// Get owner (socket emulation)
    pub const GETOWN = 23;
    /// Set owner (socket emulation)
    pub const SETOWN = 24;
    /// Object reuse revoke access to file desc.
    pub const REVOKE = 25;
    /// Does vp have NFS locks private to lock manager
    pub const HASREMOTELOCKS = 26;

    /// Set file lock
    pub const SETLK = 6;
    /// Set file lock and wait
    pub const SETLKW = 7;
    /// Allocate file space
    pub const ALLOCSP = 10;
    /// Free file space
    pub const FREESP = 11;
    /// Get file lock
    pub const GETLK = 14;
    /// Get file lock owned by file
    pub const OFD_GETLK = 47;
    /// Set file lock owned by file
    pub const OFD_SETLK = 48;
    /// Set file lock owned by file and wait
    pub const OFD_SETLKW = 49;
    /// Set a file share reservation
    pub const SHARE = 40;
    /// Remove a file share reservation
    pub const UNSHARE = 41;
    /// Create Poison FD
    pub const BADFD = 46;

    /// Read lock
    pub const RDLCK = 1;
    /// Write lock
    pub const WRLCK = 2;
    /// Remove lock(s)
    pub const UNLCK = 3;
    /// remove remote locks for a given system
    pub const UNLKSYS = 4;

    // f_access values
    /// Read-only share access
    pub const RDACC = 0x1;
    /// Write-only share access
    pub const WRACC = 0x2;
    /// Read-Write share access
    pub const RWACC = 0x3;

    // f_deny values
    /// Don't deny others access
    pub const NODNY = 0x0;
    /// Deny others read share access
    pub const RDDNY = 0x1;
    /// Deny others write share access
    pub const WRDNY = 0x2;
    /// Deny others read or write share access
    pub const RWDNY = 0x3;
    /// private flag: Deny delete share access
    pub const RMDNY = 0x4;
};

pub const O = struct {
    pub const RDONLY = 0;
    pub const WRONLY = 1;
    pub const RDWR = 2;
    pub const SEARCH = 0x200000;
    pub const EXEC = 0x400000;
    pub const NDELAY = 0x04;
    pub const APPEND = 0x08;
    pub const SYNC = 0x10;
    pub const DSYNC = 0x40;
    pub const RSYNC = 0x8000;
    pub const NONBLOCK = 0x80;
    pub const LARGEFILE = 0x2000;

    pub const CREAT = 0x100;
    pub const TRUNC = 0x200;
    pub const EXCL = 0x400;
    pub const NOCTTY = 0x800;
    pub const XATTR = 0x4000;
    pub const NOFOLLOW = 0x20000;
    pub const NOLINKS = 0x40000;
    pub const CLOEXEC = 0x800000;
    pub const DIRECTORY = 0x1000000;
    pub const DIRECT = 0x2000000;
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const NB = 4;
    pub const UN = 8;
};

pub const FD_CLOEXEC = 1;

pub const SEEK = struct {
    pub const SET = 0;
    pub const CUR = 1;
    pub const END = 2;
    pub const DATA = 3;
    pub const HOLE = 4;
};

pub const tcflag_t = c_uint;
pub const cc_t = u8;
pub const speed_t = c_uint;

pub const NCCS = 19;

pub const termios = extern struct {
    c_iflag: tcflag_t,
    c_oflag: tcflag_t,
    c_cflag: tcflag_t,
    c_lflag: tcflag_t,
    c_cc: [NCCS]cc_t,
};

fn tioc(t: u16, num: u8) u16 {
    return (t << 8) | num;
}

pub const T = struct {
    pub const CGETA = tioc('T', 1);
    pub const CSETA = tioc('T', 2);
    pub const CSETAW = tioc('T', 3);
    pub const CSETAF = tioc('T', 4);
    pub const CSBRK = tioc('T', 5);
    pub const CXONC = tioc('T', 6);
    pub const CFLSH = tioc('T', 7);
    pub const IOCGWINSZ = tioc('T', 104);
    pub const IOCSWINSZ = tioc('T', 103);
    // Softcarrier ioctls
    pub const IOCGSOFTCAR = tioc('T', 105);
    pub const IOCSSOFTCAR = tioc('T', 106);
    // termios ioctls
    pub const CGETS = tioc('T', 13);
    pub const CSETS = tioc('T', 14);
    pub const CSANOW = tioc('T', 14);
    pub const CSETSW = tioc('T', 15);
    pub const CSADRAIN = tioc('T', 15);
    pub const CSETSF = tioc('T', 16);
    pub const IOCSETLD = tioc('T', 123);
    pub const IOCGETLD = tioc('T', 124);
    // NTP PPS ioctls
    pub const IOCGPPS = tioc('T', 125);
    pub const IOCSPPS = tioc('T', 126);
    pub const IOCGPPSEV = tioc('T', 127);

    pub const IOCGETD = tioc('t', 0);
    pub const IOCSETD = tioc('t', 1);
    pub const IOCHPCL = tioc('t', 2);
    pub const IOCGETP = tioc('t', 8);
    pub const IOCSETP = tioc('t', 9);
    pub const IOCSETN = tioc('t', 10);
    pub const IOCEXCL = tioc('t', 13);
    pub const IOCNXCL = tioc('t', 14);
    pub const IOCFLUSH = tioc('t', 16);
    pub const IOCSETC = tioc('t', 17);
    pub const IOCGETC = tioc('t', 18);
    /// bis local mode bits
    pub const IOCLBIS = tioc('t', 127);
    /// bic local mode bits
    pub const IOCLBIC = tioc('t', 126);
    /// set entire local mode word
    pub const IOCLSET = tioc('t', 125);
    /// get local modes
    pub const IOCLGET = tioc('t', 124);
    /// set break bit
    pub const IOCSBRK = tioc('t', 123);
    /// clear break bit
    pub const IOCCBRK = tioc('t', 122);
    /// set data terminal ready
    pub const IOCSDTR = tioc('t', 121);
    /// clear data terminal ready
    pub const IOCCDTR = tioc('t', 120);
    /// set local special chars
    pub const IOCSLTC = tioc('t', 117);
    /// get local special chars
    pub const IOCGLTC = tioc('t', 116);
    /// driver output queue size
    pub const IOCOUTQ = tioc('t', 115);
    /// void tty association
    pub const IOCNOTTY = tioc('t', 113);
    /// get a ctty
    pub const IOCSCTTY = tioc('t', 132);
    /// stop output, like ^S
    pub const IOCSTOP = tioc('t', 111);
    /// start output, like ^Q
    pub const IOCSTART = tioc('t', 110);
    /// get pgrp of tty
    pub const IOCGPGRP = tioc('t', 20);
    /// set pgrp of tty
    pub const IOCSPGRP = tioc('t', 21);
    /// get session id on ctty
    pub const IOCGSID = tioc('t', 22);
    /// simulate terminal input
    pub const IOCSTI = tioc('t', 23);
    /// set all modem bits
    pub const IOCMSET = tioc('t', 26);
    /// bis modem bits
    pub const IOCMBIS = tioc('t', 27);
    /// bic modem bits
    pub const IOCMBIC = tioc('t', 28);
    /// get all modem bits
    pub const IOCMGET = tioc('t', 29);
};

pub const winsize = extern struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

const NSIG = 75;

pub const SIG = struct {
    pub const DFL = @as(?Sigaction.handler_fn, @ptrFromInt(0));
    pub const ERR = @as(?Sigaction.handler_fn, @ptrFromInt(maxInt(usize)));
    pub const IGN = @as(?Sigaction.handler_fn, @ptrFromInt(1));
    pub const HOLD = @as(?Sigaction.handler_fn, @ptrFromInt(2));

    pub const WORDS = 4;
    pub const MAXSIG = 75;

    pub const SIG_BLOCK = 1;
    pub const SIG_UNBLOCK = 2;
    pub const SIG_SETMASK = 3;

    pub const HUP = 1;
    pub const INT = 2;
    pub const QUIT = 3;
    pub const ILL = 4;
    pub const TRAP = 5;
    pub const IOT = 6;
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
    pub const USR1 = 16;
    pub const USR2 = 17;
    pub const CLD = 18;
    pub const CHLD = 18;
    pub const PWR = 19;
    pub const WINCH = 20;
    pub const URG = 21;
    pub const POLL = 22;
    pub const IO = .POLL;
    pub const STOP = 23;
    pub const TSTP = 24;
    pub const CONT = 25;
    pub const TTIN = 26;
    pub const TTOU = 27;
    pub const VTALRM = 28;
    pub const PROF = 29;
    pub const XCPU = 30;
    pub const XFSZ = 31;
    pub const WAITING = 32;
    pub const LWP = 33;
    pub const FREEZE = 34;
    pub const THAW = 35;
    pub const CANCEL = 36;
    pub const LOST = 37;
    pub const XRES = 38;
    pub const JVM1 = 39;
    pub const JVM2 = 40;
    pub const INFO = 41;

    pub const RTMIN = 42;
    pub const RTMAX = 74;

    pub inline fn IDX(sig: usize) usize {
        return sig - 1;
    }
    pub inline fn WORD(sig: usize) usize {
        return IDX(sig) >> 5;
    }
    pub inline fn BIT(sig: usize) usize {
        return 1 << (IDX(sig) & 31);
    }
    pub inline fn VALID(sig: usize) usize {
        return sig <= MAXSIG and sig > 0;
    }
};

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = extern struct {
    pub const handler_fn = *const fn (c_int) align(1) callconv(.C) void;
    pub const sigaction_fn = *const fn (c_int, *const siginfo_t, ?*const anyopaque) callconv(.C) void;

    /// signal options
    flags: c_uint,
    /// signal handler
    handler: extern union {
        handler: ?handler_fn,
        sigaction: ?sigaction_fn,
    },
    /// signal mask to apply
    mask: sigset_t,
};

pub const sigval_t = extern union {
    int: c_int,
    ptr: ?*anyopaque,
};

pub const siginfo_t = extern struct {
    signo: c_int,
    code: c_int,
    errno: c_int,
    // 64bit architectures insert 4bytes of padding here, this is done by
    // correctly aligning the reason field
    reason: extern union {
        proc: extern struct {
            pid: pid_t,
            pdata: extern union {
                kill: extern struct {
                    uid: uid_t,
                    value: sigval_t,
                },
                cld: extern struct {
                    utime: clock_t,
                    status: c_int,
                    stime: clock_t,
                },
            },
            contract: ctid_t,
            zone: zoneid_t,
        },
        fault: extern struct {
            addr: ?*anyopaque,
            trapno: c_int,
            pc: ?*anyopaque,
        },
        file: extern struct {
            // fd not currently available for SIGPOLL.
            fd: c_int,
            band: c_long,
        },
        prof: extern struct {
            addr: ?*anyopaque,
            timestamp: timespec,
            syscall: c_short,
            sysarg: u8,
            fault: u8,
            args: [8]c_long,
            state: [10]c_int,
        },
        rctl: extern struct {
            entity: i32,
        },
        __pad: [256 - 4 * @sizeOf(c_int)]u8,
    } align(@sizeOf(usize)),
};

comptime {
    std.debug.assert(@sizeOf(siginfo_t) == 256);
    std.debug.assert(@alignOf(siginfo_t) == @sizeOf(usize));
}

pub const sigset_t = extern struct {
    __bits: [SIG.WORDS]u32,
};

pub const empty_sigset = sigset_t{ .__bits = [_]u32{0} ** SIG.WORDS };

pub const fpregset_t = extern union {
    regs: [130]u32,
    chip_state: extern struct {
        cw: u16,
        sw: u16,
        fctw: u8,
        __fx_rsvd: u8,
        fop: u16,
        rip: u64,
        rdp: u64,
        mxcsr: u32,
        mxcsr_mask: u32,
        st: [8]extern union {
            fpr_16: [5]u16,
            __fpr_pad: u128,
        },
        xmm: [16]u128,
        __fx_ign2: [6]u128,
        status: u32,
        xstatus: u32,
    },
};

pub const mcontext_t = extern struct {
    gregs: [28]u64,
    fpregs: fpregset_t,
};

pub const REG = struct {
    pub const RBP = 10;
    pub const RIP = 17;
    pub const RSP = 20;
};

pub const ucontext_t = extern struct {
    flags: u64,
    link: ?*ucontext_t,
    sigmask: sigset_t,
    stack: stack_t,
    mcontext: mcontext_t,
    brand_data: [3]?*anyopaque,
    filler: [2]i64,
};

pub const GETCONTEXT = 0;
pub const SETCONTEXT = 1;
pub const GETUSTACK = 2;
pub const SETUSTACK = 3;

pub const E = enum(u16) {
    /// No error occurred.
    SUCCESS = 0,
    /// Not super-user
    PERM = 1,
    /// No such file or directory
    NOENT = 2,
    /// No such process
    SRCH = 3,
    /// interrupted system call
    INTR = 4,
    /// I/O error
    IO = 5,
    /// No such device or address
    NXIO = 6,
    /// Arg list too long
    @"2BIG" = 7,
    /// Exec format error
    NOEXEC = 8,
    /// Bad file number
    BADF = 9,
    /// No children
    CHILD = 10,
    /// Resource temporarily unavailable.
    /// also: WOULDBLOCK: Operation would block.
    AGAIN = 11,
    /// Not enough core
    NOMEM = 12,
    /// Permission denied
    ACCES = 13,
    /// Bad address
    FAULT = 14,
    /// Block device required
    NOTBLK = 15,
    /// Mount device busy
    BUSY = 16,
    /// File exists
    EXIST = 17,
    /// Cross-device link
    XDEV = 18,
    /// No such device
    NODEV = 19,
    /// Not a directory
    NOTDIR = 20,
    /// Is a directory
    ISDIR = 21,
    /// Invalid argument
    INVAL = 22,
    /// File table overflow
    NFILE = 23,
    /// Too many open files
    MFILE = 24,
    /// Inappropriate ioctl for device
    NOTTY = 25,
    /// Text file busy
    TXTBSY = 26,
    /// File too large
    FBIG = 27,
    /// No space left on device
    NOSPC = 28,
    /// Illegal seek
    SPIPE = 29,
    /// Read only file system
    ROFS = 30,
    /// Too many links
    MLINK = 31,
    /// Broken pipe
    PIPE = 32,
    /// Math arg out of domain of func
    DOM = 33,
    /// Math result not representable
    RANGE = 34,
    /// No message of desired type
    NOMSG = 35,
    /// Identifier removed
    IDRM = 36,
    /// Channel number out of range
    CHRNG = 37,
    /// Level 2 not synchronized
    L2NSYNC = 38,
    /// Level 3 halted
    L3HLT = 39,
    /// Level 3 reset
    L3RST = 40,
    /// Link number out of range
    LNRNG = 41,
    /// Protocol driver not attached
    UNATCH = 42,
    /// No CSI structure available
    NOCSI = 43,
    /// Level 2 halted
    L2HLT = 44,
    /// Deadlock condition.
    DEADLK = 45,
    /// No record locks available.
    NOLCK = 46,
    /// Operation canceled
    CANCELED = 47,
    /// Operation not supported
    NOTSUP = 48,

    // Filesystem Quotas
    /// Disc quota exceeded
    DQUOT = 49,

    // Convergent Error Returns
    /// invalid exchange
    BADE = 50,
    /// invalid request descriptor
    BADR = 51,
    /// exchange full
    XFULL = 52,
    /// no anode
    NOANO = 53,
    /// invalid request code
    BADRQC = 54,
    /// invalid slot
    BADSLT = 55,
    /// file locking deadlock error
    DEADLOCK = 56,
    /// bad font file fmt
    BFONT = 57,

    // Interprocess Robust Locks
    /// process died with the lock
    OWNERDEAD = 58,
    /// lock is not recoverable
    NOTRECOVERABLE = 59,
    /// locked lock was unmapped
    LOCKUNMAPPED = 72,
    /// Facility is not active
    NOTACTIVE = 73,
    /// multihop attempted
    MULTIHOP = 74,
    /// trying to read unreadable message
    BADMSG = 77,
    /// path name is too long
    NAMETOOLONG = 78,
    /// value too large to be stored in data type
    OVERFLOW = 79,
    /// given log. name not unique
    NOTUNIQ = 80,
    /// f.d. invalid for this operation
    BADFD = 81,
    /// Remote address changed
    REMCHG = 82,

    // Stream Problems
    /// Device not a stream
    NOSTR = 60,
    /// no data (for no delay io)
    NODATA = 61,
    /// timer expired
    TIME = 62,
    /// out of streams resources
    NOSR = 63,
    /// Machine is not on the network
    NONET = 64,
    /// Package not installed
    NOPKG = 65,
    /// The object is remote
    REMOTE = 66,
    /// the link has been severed
    NOLINK = 67,
    /// advertise error
    ADV = 68,
    /// srmount error
    SRMNT = 69,
    /// Communication error on send
    COMM = 70,
    /// Protocol error
    PROTO = 71,

    // Shared Library Problems
    /// Can't access a needed shared lib.
    LIBACC = 83,
    /// Accessing a corrupted shared lib.
    LIBBAD = 84,
    /// .lib section in a.out corrupted.
    LIBSCN = 85,
    /// Attempting to link in too many libs.
    LIBMAX = 86,
    /// Attempting to exec a shared library.
    LIBEXEC = 87,
    /// Illegal byte sequence.
    ILSEQ = 88,
    /// Unsupported file system operation
    NOSYS = 89,
    /// Symbolic link loop
    LOOP = 90,
    /// Restartable system call
    RESTART = 91,
    /// if pipe/FIFO, don't sleep in stream head
    STRPIPE = 92,
    /// directory not empty
    NOTEMPTY = 93,
    /// Too many users (for UFS)
    USERS = 94,

    // BSD Networking Software
    // Argument Errors
    /// Socket operation on non-socket
    NOTSOCK = 95,
    /// Destination address required
    DESTADDRREQ = 96,
    /// Message too long
    MSGSIZE = 97,
    /// Protocol wrong type for socket
    PROTOTYPE = 98,
    /// Protocol not available
    NOPROTOOPT = 99,
    /// Protocol not supported
    PROTONOSUPPORT = 120,
    /// Socket type not supported
    SOCKTNOSUPPORT = 121,
    /// Operation not supported on socket
    OPNOTSUPP = 122,
    /// Protocol family not supported
    PFNOSUPPORT = 123,
    /// Address family not supported by
    AFNOSUPPORT = 124,
    /// Address already in use
    ADDRINUSE = 125,
    /// Can't assign requested address
    ADDRNOTAVAIL = 126,

    // Operational Errors
    /// Network is down
    NETDOWN = 127,
    /// Network is unreachable
    NETUNREACH = 128,
    /// Network dropped connection because
    NETRESET = 129,
    /// Software caused connection abort
    CONNABORTED = 130,
    /// Connection reset by peer
    CONNRESET = 131,
    /// No buffer space available
    NOBUFS = 132,
    /// Socket is already connected
    ISCONN = 133,
    /// Socket is not connected
    NOTCONN = 134,
    /// Can't send after socket shutdown
    SHUTDOWN = 143,
    /// Too many references: can't splice
    TOOMANYREFS = 144,
    /// Connection timed out
    TIMEDOUT = 145,
    /// Connection refused
    CONNREFUSED = 146,
    /// Host is down
    HOSTDOWN = 147,
    /// No route to host
    HOSTUNREACH = 148,
    /// operation already in progress
    ALREADY = 149,
    /// operation now in progress
    INPROGRESS = 150,

    // SUN Network File System
    /// Stale NFS file handle
    STALE = 151,

    _,
};

pub const MINSIGSTKSZ = 2048;
pub const SIGSTKSZ = 8192;

pub const SS_ONSTACK = 0x1;
pub const SS_DISABLE = 0x2;

pub const stack_t = extern struct {
    sp: [*]u8,
    size: isize,
    flags: i32,
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
    /// SunOS 2.6 Door
    pub const IFDOOR = 0o150000;
    /// Solaris 10 Event Port
    pub const IFPORT = 0o160000;

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

    pub fn ISDOOR(m: u32) bool {
        return m & IFMT == IFDOOR;
    }

    pub fn ISPORT(m: u32) bool {
        return m & IFMT == IFPORT;
    }
};

pub const AT = struct {
    /// Magic value that specify the use of the current working directory
    /// to determine the target of relative file paths in the openat() and
    /// similar syscalls.
    pub const FDCWD = @as(fd_t, @bitCast(@as(u32, 0xffd19553)));

    /// Do not follow symbolic links
    pub const SYMLINK_NOFOLLOW = 0x1000;
    /// Follow symbolic link
    pub const SYMLINK_FOLLOW = 0x2000;
    /// Remove directory instead of file
    pub const REMOVEDIR = 0x1;
    pub const TRIGGER = 0x2;
    /// Check access using effective user and group ID
    pub const EACCESS = 0x4;
};

pub const POSIX_FADV = struct {
    pub const NORMAL = 0;
    pub const RANDOM = 1;
    pub const SEQUENTIAL = 2;
    pub const WILLNEED = 3;
    pub const DONTNEED = 4;
    pub const NOREUSE = 5;
};

pub const HOST_NAME_MAX = 255;

pub const IPPROTO = struct {
    /// dummy for IP
    pub const IP = 0;
    /// Hop by hop header for IPv6
    pub const HOPOPTS = 0;
    /// control message protocol
    pub const ICMP = 1;
    /// group control protocol
    pub const IGMP = 2;
    /// gateway^2 (deprecated)
    pub const GGP = 3;
    /// IP in IP encapsulation
    pub const ENCAP = 4;
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
    /// IPv6 encapsulated in IP
    pub const IPV6 = 41;
    /// Routing header for IPv6
    pub const ROUTING = 43;
    /// Fragment header for IPv6
    pub const FRAGMENT = 44;
    /// rsvp
    pub const RSVP = 46;
    /// IPsec Encap. Sec. Payload
    pub const ESP = 50;
    /// IPsec Authentication Hdr.
    pub const AH = 51;
    /// ICMP for IPv6
    pub const ICMPV6 = 58;
    /// No next header for IPv6
    pub const NONE = 59;
    /// Destination options
    pub const DSTOPTS = 60;
    /// "hello" routing protocol
    pub const HELLO = 63;
    /// UNOFFICIAL net disk proto
    pub const ND = 77;
    /// ISO clnp
    pub const EON = 80;
    /// OSPF
    pub const OSPF = 89;
    /// PIM routing protocol
    pub const PIM = 103;
    /// Stream Control
    pub const SCTP = 132;
    /// raw IP packet
    pub const RAW = 255;
    /// Sockets Direct Protocol
    pub const PROTO_SDP = 257;
};

pub const priority = enum(c_int) {
    PROCESS = 0,
    PGRP = 1,
    USER = 2,
    GROUP = 3,
    SESSION = 4,
    LWP = 5,
    TASK = 6,
    PROJECT = 7,
    ZONE = 8,
    CONTRACT = 9,
};

pub const rlimit_resource = enum(c_int) {
    CPU = 0,
    FSIZE = 1,
    DATA = 2,
    STACK = 3,
    CORE = 4,
    NOFILE = 5,
    VMEM = 6,
    _,

    pub const AS: rlimit_resource = .VMEM;
};

pub const rlim_t = u64;

pub const RLIM = struct {
    /// No limit
    pub const INFINITY: rlim_t = (1 << 63) - 3;
    pub const SAVED_MAX: rlim_t = (1 << 63) - 2;
    pub const SAVED_CUR: rlim_t = (1 << 63) - 1;
};

pub const rlimit = extern struct {
    /// Soft limit
    cur: rlim_t,
    /// Hard limit
    max: rlim_t,
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

    pub const SELF = 0;
    pub const CHILDREN = -1;
    pub const THREAD = 1;
};

pub const SHUT = struct {
    pub const RD = 0;
    pub const WR = 1;
    pub const RDWR = 2;
};

pub const pollfd = extern struct {
    fd: fd_t,
    events: i16,
    revents: i16,
};

/// Testable events (may be specified in ::pollfd::events).
pub const POLL = struct {
    pub const IN = 0x0001;
    pub const PRI = 0x0002;
    pub const OUT = 0x0004;
    pub const RDNORM = 0x0040;
    pub const WRNORM = .OUT;
    pub const RDBAND = 0x0080;
    pub const WRBAND = 0x0100;
    /// Read-side hangup.
    pub const RDHUP = 0x4000;

    /// Non-testable events (may not be specified in events).
    pub const ERR = 0x0008;
    pub const HUP = 0x0010;
    pub const NVAL = 0x0020;

    /// Events to control `/dev/poll` (not specified in revents)
    pub const REMOVE = 0x0800;
    pub const ONESHOT = 0x1000;
    pub const ET = 0x2000;
};

/// Extensions to the ELF auxiliary vector.
pub const AT_SUN = struct {
    /// effective user id
    pub const UID = 2000;
    /// real user id
    pub const RUID = 2001;
    /// effective group id
    pub const GID = 2002;
    /// real group id
    pub const RGID = 2003;
    /// dynamic linker's ELF header
    pub const LDELF = 2004;
    /// dynamic linker's section headers
    pub const LDSHDR = 2005;
    /// name of dynamic linker
    pub const LDNAME = 2006;
    /// large pagesize
    pub const LPAGESZ = 2007;
    /// platform name
    pub const PLATFORM = 2008;
    /// hints about hardware capabilities.
    pub const HWCAP = 2009;
    pub const HWCAP2 = 2023;
    /// flush icache?
    pub const IFLUSH = 2010;
    /// cpu name
    pub const CPU = 2011;
    /// exec() path name in the auxv, null terminated.
    pub const EXECNAME = 2014;
    /// mmu module name
    pub const MMU = 2015;
    /// dynamic linkers data segment
    pub const LDDATA = 2016;
    /// AF_SUN_ flags passed from the kernel
    pub const AUXFLAGS = 2017;
    /// name of the emulation binary for the linker
    pub const EMULATOR = 2018;
    /// name of the brand library for the linker
    pub const BRANDNAME = 2019;
    /// vectors for brand modules.
    pub const BRAND_AUX1 = 2020;
    pub const BRAND_AUX2 = 2021;
    pub const BRAND_AUX3 = 2022;
    pub const BRAND_AUX4 = 2025;
    pub const BRAND_NROOT = 2024;
    /// vector for comm page.
    pub const COMMPAGE = 2026;
    /// information about the x86 FPU.
    pub const FPTYPE = 2027;
    pub const FPSIZE = 2028;
};

/// ELF auxiliary vector flags.
pub const AF_SUN = struct {
    /// tell ld.so.1 to run "secure" and ignore the environment.
    pub const SETUGID = 0x00000001;
    /// hardware capabilities can be verified against AT_SUN_HWCAP
    pub const HWCAPVERIFY = 0x00000002;
    pub const NOPLM = 0x00000004;
};

// TODO: Add sysconf numbers when the other OSs do.
pub const _SC = struct {
    pub const NPROCESSORS_ONLN = 15;
};

pub const procfs = struct {
    pub const misc_header = extern struct {
        size: u32,
        type: enum(u32) {
            Pathname,
            Socketname,
            Peersockname,
            SockoptsBoolOpts,
            SockoptLinger,
            SockoptSndbuf,
            SockoptRcvbuf,
            SockoptIpNexthop,
            SockoptIpv6Nexthop,
            SockoptType,
            SockoptTcpCongestion,
            SockfiltersPriv = 14,
        },
    };

    pub const fdinfo = extern struct {
        fd: fd_t,
        mode: mode_t,
        ino: ino_t,
        size: off_t,
        offset: off_t,
        uid: uid_t,
        gid: gid_t,
        dev_major: major_t,
        dev_minor: minor_t,
        special_major: major_t,
        special_minor: minor_t,
        fileflags: i32,
        fdflags: i32,
        locktype: i16,
        lockpid: pid_t,
        locksysid: i32,
        peerpid: pid_t,
        __filler: [25]c_int,
        peername: [15:0]u8,
        misc: [1]u8,
    };
};

pub const SFD = struct {
    pub const CLOEXEC = 0o2000000;
    pub const NONBLOCK = 0o4000;
};

pub const signalfd_siginfo = extern struct {
    signo: u32,
    errno: i32,
    code: i32,
    pid: u32,
    uid: uid_t,
    fd: i32,
    tid: u32, // unused
    band: u32,
    overrun: u32, // unused
    trapno: u32,
    status: i32,
    int: i32, // unused
    ptr: u64, // unused
    utime: u64,
    stime: u64,
    addr: u64,
    __pad: [48]u8,
};

pub const PORT_SOURCE = struct {
    pub const AIO = 1;
    pub const TIMER = 2;
    pub const USER = 3;
    pub const FD = 4;
    pub const ALERT = 5;
    pub const MQ = 6;
    pub const FILE = 7;
};

pub const PORT_ALERT = struct {
    pub const SET = 0x01;
    pub const UPDATE = 0x02;
};

/// User watchable file events.
pub const FILE_EVENT = struct {
    pub const ACCESS = 0x00000001;
    pub const MODIFIED = 0x00000002;
    pub const ATTRIB = 0x00000004;
    pub const DELETE = 0x00000010;
    pub const RENAME_TO = 0x00000020;
    pub const RENAME_FROM = 0x00000040;
    pub const TRUNC = 0x00100000;
    pub const NOFOLLOW = 0x10000000;
    /// The filesystem holding the watched file was unmounted.
    pub const UNMOUNTED = 0x20000000;
    /// Some other file/filesystem got mounted over the watched file/directory.
    pub const MOUNTEDOVER = 0x40000000;

    pub fn isException(event: u32) bool {
        return event & (UNMOUNTED | DELETE | RENAME_TO | RENAME_FROM | MOUNTEDOVER) > 0;
    }
};

pub const port_event = extern struct {
    events: u32,
    /// Event source.
    source: u16,
    __pad: u16,
    /// Source-specific object.
    object: ?*anyopaque,
    /// User cookie.
    cookie: ?*anyopaque,
};

pub const port_notify = extern struct {
    /// Bind request(s) to port.
    port: u32,
    /// User defined variable.
    user: ?*void,
};

pub const file_obj = extern struct {
    /// Access time.
    atim: timespec,
    /// Modification time
    mtim: timespec,
    /// Change time
    ctim: timespec,
    __pad: [3]usize,
    name: [*:0]u8,
};

// struct ifreq is marked obsolete, with struct lifreq preferred for interface requests.
// Here we alias lifreq to ifreq to avoid chainging existing code in os and x.os.IPv6.
pub const SIOCGLIFINDEX = IOWR('i', 133, lifreq);
pub const SIOCGIFINDEX = SIOCGLIFINDEX;
pub const MAX_HDW_LEN = 64;
pub const IFNAMESIZE = 32;

pub const lif_nd_req = extern struct {
    addr: sockaddr.storage,
    state_create: u8,
    state_same_lla: u8,
    state_diff_lla: u8,
    hdw_len: i32,
    flags: i32,
    __pad: i32,
    hdw_addr: [MAX_HDW_LEN]u8,
};

pub const lif_ifinfo_req = extern struct {
    maxhops: u8,
    reachtime: u32,
    reachretrans: u32,
    maxmtu: u32,
};

/// IP interface request. See if_tcp(7p) for more info.
pub const lifreq = extern struct {
    // Not actually in a union, but the stdlib expects one for ifreq
    ifrn: extern union {
        /// Interface name, e.g. "lo0", "en0".
        name: [IFNAMESIZE]u8,
    },
    ru1: extern union {
        /// For subnet/token etc.
        addrlen: i32,
        /// Driver's PPA (physical point of attachment).
        ppa: u32,
    },
    /// One of the IFT types, e.g. IFT_ETHER.
    type: u32,
    ifru: extern union {
        /// Address.
        addr: sockaddr.storage,
        /// Other end of a peer-to-peer link.
        dstaddr: sockaddr.storage,
        /// Broadcast address.
        broadaddr: sockaddr.storage,
        /// Address token.
        token: sockaddr.storage,
        /// Subnet prefix.
        subnet: sockaddr.storage,
        /// Interface index.
        ivalue: i32,
        /// Flags for SIOC?LIFFLAGS.
        flags: u64,
        /// Hop count metric
        metric: i32,
        /// Maximum transmission unit
        mtu: u32,
        // Technically [2]i32
        muxid: packed struct { ip: i32, arp: i32 },
        /// Neighbor reachability determination entries
        nd_req: lif_nd_req,
        /// Link info
        ifinfo_req: lif_ifinfo_req,
        /// Name of the multipath interface group
        groupname: [IFNAMESIZE]u8,
        binding: [IFNAMESIZE]u8,
        /// Zone id associated with this interface.
        zoneid: zoneid_t,
        /// Duplicate address detection state. Either in progress or completed.
        dadstate: u32,
    },
};

pub const ifreq = lifreq;

const IoCtlCommand = enum(u32) {
    none = 0x20000000, // no parameters
    write = 0x40000000, // copy out parameters
    read = 0x80000000, // copy in parameters
    read_write = 0xc0000000,
};

fn ioImpl(cmd: IoCtlCommand, io_type: u8, nr: u8, comptime IOT: type) i32 {
    const size = @as(u32, @intCast(@as(u8, @truncate(@sizeOf(IOT))))) << 16;
    const t = @as(u32, @intCast(io_type)) << 8;
    return @as(i32, @bitCast(@intFromEnum(cmd) | size | t | nr));
}

pub fn IO(io_type: u8, nr: u8) i32 {
    return ioImpl(.none, io_type, nr, void);
}

pub fn IOR(io_type: u8, nr: u8, comptime IOT: type) i32 {
    return ioImpl(.write, io_type, nr, IOT);
}

pub fn IOW(io_type: u8, nr: u8, comptime IOT: type) i32 {
    return ioImpl(.read, io_type, nr, IOT);
}

pub fn IOWR(io_type: u8, nr: u8, comptime IOT: type) i32 {
    return ioImpl(.read_write, io_type, nr, IOT);
}
