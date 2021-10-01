const std = @import("../std.zig");
const builtin = @import("builtin");
const maxInt = std.math.maxInt;
const iovec = std.os.iovec;
const iovec_const = std.os.iovec_const;

extern "c" fn _errnop() *c_int;

pub const _errno = _errnop;

pub extern "c" fn find_directory(which: c_int, volume: i32, createIt: bool, path_ptr: [*]u8, length: i32) u64;

pub extern "c" fn find_thread(thread_name: ?*c_void) i32;

pub extern "c" fn get_system_info(system_info: *system_info) usize;

// TODO revisit if abi changes or better option becomes apparent
pub extern "c" fn _get_next_image_info(team: c_int, cookie: *i32, image_info: *image_info) usize;

pub extern "c" fn _kern_read_dir(fd: c_int, buf_ptr: [*]u8, nbytes: usize, maxcount: u32) usize;

pub extern "c" fn _kern_read_stat(fd: c_int, path_ptr: [*]u8, traverse_link: bool, st: *Stat, stat_size: i32) usize;

pub extern "c" fn _kern_get_current_team() i32;

pub const sem_t = extern struct {
    _magic: u32,
    _kern: extern struct {
        _count: u32,
        _flags: u32,
    },
    _padding: u32,
};

pub const pthread_attr_t = extern struct {
    __detach_state: i32,
    __sched_priority: i32,
    __stack_size: i32,
    __guard_size: i32,
    __stack_address: ?*c_void,
};

pub const pthread_mutex_t = extern struct {
    flags: u32 = 0,
    lock: i32 = 0,
    unused: i32 = -42,
    owner: i32 = -1,
    owner_count: i32 = 0,
};
pub const pthread_cond_t = extern struct {
    flags: u32 = 0,
    unused: i32 = -42,
    mutex: ?*c_void = null,
    waiter_count: i32 = 0,
    lock: i32 = 0,
};
pub const pthread_rwlock_t = extern struct {
    flags: u32 = 0,
    owner: i32 = -1,
    lock_sem: i32 = 0,
    lock_count: i32 = 0,
    reader_count: i32 = 0,
    writer_count: i32 = 0,
    waiters: [2]?*c_void = [_]?*c_void{ null, null },
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

    /// invalid value for hints
    BADHINTS = 12,

    /// resolved protocol is unknown
    PROTOCOL = 13,

    /// argument buffer overflow
    OVERFLOW = 14,

    _,
};

pub const EAI_MAX = 15;

pub const fd_t = c_int;
pub const pid_t = c_int;
pub const uid_t = u32;
pub const gid_t = u32;
pub const mode_t = c_uint;

pub const socklen_t = u32;

/// Renamed from `kevent` to `Kevent` to avoid conflict with function name.
pub const Kevent = extern struct {
    ident: usize,
    filter: i16,
    flags: u16,
    fflags: u32,
    data: i64,
    udata: usize,
    // TODO ext
};

// Modes and flags for dlopen()
// include/dlfcn.h

pub const POLL = struct {
    pub const IN = 0x0001;
    pub const ERR = 0x0004;
    pub const NVAL = 0x1000;
    pub const HUP = 0x0080;
};

pub const RTLD = struct {
    /// Bind function calls lazily.
    pub const LAZY = 1;
    /// Bind function calls immediately.
    pub const NOW = 2;
    pub const MODEMASK = 0x3;
    /// Make symbols globally available.
    pub const GLOBAL = 0x100;
    /// Opposite of GLOBAL, and the default.
    pub const LOCAL = 0;
    /// Trace loaded objects and exit.
    pub const TRACE = 0x200;
    /// Do not remove members.
    pub const NODELETE = 0x01000;
    /// Do not load if not already loaded.
    pub const NOLOAD = 0x02000;
};

pub const dl_phdr_info = extern struct {
    dlpi_addr: usize,
    dlpi_name: ?[*:0]const u8,
    dlpi_phdr: [*]std.elf.Phdr,
    dlpi_phnum: u16,
};

pub const Flock = extern struct {
    l_start: off_t,
    l_len: off_t,
    l_pid: pid_t,
    l_type: i16,
    l_whence: i16,
    l_sysid: i32,
    __unused: [4]u8,
};

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
    msg_control: ?*c_void,

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
    msg_iov: [*]iovec_const,

    /// # elements in msg_iov
    msg_iovlen: i32,

    /// ancillary data
    msg_control: ?*c_void,

    /// ancillary data buffer len
    msg_controllen: socklen_t,

    /// flags on received message
    msg_flags: i32,
};

pub const off_t = i64;
pub const ino_t = u64;

pub const nfds_t = u32;

pub const pollfd = extern struct {
    fd: i32,
    events: i16,
    revents: i16,
};

pub const Stat = extern struct {
    dev: i32,
    ino: u64,
    mode: u32,
    nlink: i32,
    uid: i32,
    gid: i32,
    size: i64,
    rdev: i32,
    blksize: i32,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    crtim: timespec,
    st_type: u32,
    blocks: i64,

    pub fn atime(self: @This()) timespec {
        return self.atim;
    }
    pub fn mtime(self: @This()) timespec {
        return self.mtim;
    }
    pub fn ctime(self: @This()) timespec {
        return self.ctim;
    }
    pub fn crtime(self: @This()) timespec {
        return self.crtim;
    }
};

pub const timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};

pub const dirent = extern struct {
    d_dev: i32,
    d_pdev: i32,
    d_ino: i64,
    d_pino: i64,
    d_reclen: u16,
    d_name: [256]u8,

    pub fn reclen(self: dirent) u16 {
        return self.d_reclen;
    }
};

pub const image_info = extern struct {
    id: u32,
    type: u32,
    sequence: i32,
    init_order: i32,
    init_routine: *c_void,
    term_routine: *c_void,
    device: i32,
    node: i32,
    name: [1024]u8,
    text: *c_void,
    data: *c_void,
    text_size: i32,
    data_size: i32,
    api_version: i32,
    abi: i32,
};

pub const system_info = extern struct {
    boot_time: i64,
    cpu_count: u32,
    max_pages: u64,
    used_pages: u64,
    cached_pages: u64,
    block_cache_pages: u64,
    ignored_pages: u64,
    needed_memory: u64,
    free_memory: u64,
    max_swap_pages: u64,
    free_swap_pages: u64,
    page_faults: u32,
    max_sems: u32,
    used_sems: u32,
    max_ports: u32,
    used_ports: u32,
    max_threads: u32,
    used_threads: u32,
    max_teams: u32,
    used_teams: u32,
    kernel_name: [256]u8,
    kernel_build_date: [32]u8,
    kernel_build_time: [32]u8,
    kernel_version: i64,
    abi: u32,
};

pub const in_port_t = u16;
pub const sa_family_t = u8;

pub const sockaddr = extern struct {
    /// total length
    len: u8,
    /// address family
    family: sa_family_t,
    /// actually longer; address value
    data: [14]u8,

    pub const SS_MAXSIZE = 128;
    pub const storage = std.x.os.Socket.Address.Native.Storage;

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

    pub const un = extern struct {
        len: u8 = @sizeOf(un),
        family: sa_family_t = AF.UNIX,
        path: [104]u8,
    };
};

pub const CTL = struct {
    pub const KERN = 1;
    pub const DEBUG = 5;
};

pub const KERN = struct {
    pub const PROC = 14; // struct: process entries
    pub const PROC_PATHNAME = 12; // path to executable
};

pub const PATH_MAX = 1024;

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
    pub const MONOTONIC = 0;
    pub const REALTIME = -1;
    pub const PROCESS_CPUTIME_ID = -2;
    pub const THREAD_CPUTIME_ID = -3;
};

pub const MAP = struct {
    pub const FAILED = @intToPtr(*c_void, maxInt(usize));
    pub const SHARED = 0x0001;
    pub const PRIVATE = 0x0002;
    pub const FIXED = 0x0010;
    pub const STACK = 0x0400;
    pub const NOSYNC = 0x0800;
    pub const ANON = 0x1000;
    pub const ANONYMOUS = ANON;
    pub const FILE = 0;

    pub const GUARD = 0x00002000;
    pub const EXCL = 0x00004000;
    pub const NOCORE = 0x00020000;
    pub const PREFAULT_READ = 0x00040000;
    pub const @"32BIT" = 0x00080000;
};

pub const W = struct {
    pub const NOHANG = 0x1;
    pub const UNTRACED = 0x2;
    pub const STOPPED = 0x10;
    pub const CONTINUED = 0x4;
    pub const NOWAIT = 0x20;
    pub const EXITED = 0x08;

    pub fn EXITSTATUS(s: u32) u8 {
        return @intCast(u8, s & 0xff);
    }

    pub fn TERMSIG(s: u32) u32 {
        return (s >> 8) & 0xff;
    }

    pub fn STOPSIG(s: u32) u32 {
        return EXITSTATUS(s);
    }

    pub fn IFEXITED(s: u32) bool {
        return TERMSIG(s) == 0;
    }

    pub fn IFSTOPPED(s: u32) bool {
        return ((s >> 16) & 0xff) != 0;
    }

    pub fn IFSIGNALED(s: u32) bool {
        return ((s >> 8) & 0xff) != 0;
    }
};

pub const SA = struct {
    pub const ONSTACK = 0x20;
    pub const RESTART = 0x10;
    pub const RESETHAND = 0x04;
    pub const NOCLDSTOP = 0x01;
    pub const NODEFER = 0x08;
    pub const NOCLDWAIT = 0x02;
    pub const SIGINFO = 0x40;
    pub const NOMASK = NODEFER;
    pub const STACK = ONSTACK;
    pub const ONESHOT = RESETHAND;
};

pub const SIG = struct {
    pub const ERR = @intToPtr(fn (i32) callconv(.C) void, maxInt(usize));
    pub const DFL = @intToPtr(fn (i32) callconv(.C) void, 0);
    pub const IGN = @intToPtr(fn (i32) callconv(.C) void, 1);

    pub const HUP = 1;
    pub const INT = 2;
    pub const QUIT = 3;
    pub const ILL = 4;
    pub const CHLD = 5;
    pub const ABRT = 6;
    pub const IOT = ABRT;
    pub const PIPE = 7;
    pub const FPE = 8;
    pub const KILL = 9;
    pub const STOP = 10;
    pub const SEGV = 11;
    pub const CONT = 12;
    pub const TSTP = 13;
    pub const ALRM = 14;
    pub const TERM = 15;
    pub const TTIN = 16;
    pub const TTOU = 17;
    pub const USR1 = 18;
    pub const USR2 = 19;
    pub const WINCH = 20;
    pub const KILLTHR = 21;
    pub const TRAP = 22;
    pub const POLL = 23;
    pub const PROF = 24;
    pub const SYS = 25;
    pub const URG = 26;
    pub const VTALRM = 27;
    pub const XCPU = 28;
    pub const XFSZ = 29;
    pub const BUS = 30;
    pub const RESERVED1 = 31;
    pub const RESERVED2 = 32;

    // TODO: check
    pub const RTMIN = 65;
    pub const RTMAX = 126;

    pub const BLOCK = 1;
    pub const UNBLOCK = 2;
    pub const SETMASK = 3;

    pub const WORDS = 4;
    pub const MAXSIG = 128;
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

// access function
pub const F_OK = 0; // test for existence of file
pub const X_OK = 1; // test for execute or search permission
pub const W_OK = 2; // test for write permission
pub const R_OK = 4; // test for read permission

pub const O = struct {
    pub const RDONLY = 0x0000;
    pub const WRONLY = 0x0001;
    pub const RDWR = 0x0002;
    pub const ACCMODE = 0x0003;

    pub const SHLOCK = 0x0010;
    pub const EXLOCK = 0x0020;

    pub const CREAT = 0x0200;
    pub const EXCL = 0x0800;
    pub const NOCTTY = 0x8000;
    pub const TRUNC = 0x0400;
    pub const APPEND = 0x0008;
    pub const NONBLOCK = 0x0004;
    pub const DSYNC = 0o10000;
    pub const SYNC = 0x0080;
    pub const RSYNC = 0o4010000;
    pub const DIRECTORY = 0x20000;
    pub const NOFOLLOW = 0x0100;
    pub const CLOEXEC = 0x00100000;

    pub const ASYNC = 0x0040;
    pub const DIRECT = 0x00010000;
    pub const NOATIME = 0o1000000;
    pub const PATH = 0o10000000;
    pub const TMPFILE = 0o20200000;
    pub const NDELAY = NONBLOCK;
};

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;

    pub const GETOWN = 5;
    pub const SETOWN = 6;

    pub const GETLK = 11;
    pub const SETLK = 12;
    pub const SETLKW = 13;

    pub const RDLCK = 1;
    pub const WRLCK = 3;
    pub const UNLCK = 2;

    pub const SETOWN_EX = 15;
    pub const GETOWN_EX = 16;

    pub const GETOWNER_UIDS = 17;
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const UN = 8;
    pub const NB = 4;
};

pub const FD_CLOEXEC = 1;

pub const SEEK = struct {
    pub const SET = 0;
    pub const CUR = 1;
    pub const END = 2;
};

pub const SOCK = struct {
    pub const STREAM = 1;
    pub const DGRAM = 2;
    pub const RAW = 3;
    pub const RDM = 4;
    pub const SEQPACKET = 5;

    pub const CLOEXEC = 0x10000000;
    pub const NONBLOCK = 0x20000000;
};

pub const SO = struct {
    pub const DEBUG = 0x00000001;
    pub const ACCEPTCONN = 0x00000002;
    pub const REUSEADDR = 0x00000004;
    pub const KEEPALIVE = 0x00000008;
    pub const DONTROUTE = 0x00000010;
    pub const BROADCAST = 0x00000020;
    pub const USELOOPBACK = 0x00000040;
    pub const LINGER = 0x00000080;
    pub const OOBINLINE = 0x00000100;
    pub const REUSEPORT = 0x00000200;
    pub const TIMESTAMP = 0x00000400;
    pub const NOSIGPIPE = 0x00000800;
    pub const ACCEPTFILTER = 0x00001000;
    pub const BINTIME = 0x00002000;
    pub const NO_OFFLOAD = 0x00004000;
    pub const NO_DDP = 0x00008000;
    pub const REUSEPORT_LB = 0x00010000;

    pub const SNDBUF = 0x1001;
    pub const RCVBUF = 0x1002;
    pub const SNDLOWAT = 0x1003;
    pub const RCVLOWAT = 0x1004;
    pub const SNDTIMEO = 0x1005;
    pub const RCVTIMEO = 0x1006;
    pub const ERROR = 0x1007;
    pub const TYPE = 0x1008;
    pub const LABEL = 0x1009;
    pub const PEERLABEL = 0x1010;
    pub const LISTENQLIMIT = 0x1011;
    pub const LISTENQLEN = 0x1012;
    pub const LISTENINCQLEN = 0x1013;
    pub const SETFIB = 0x1014;
    pub const USER_COOKIE = 0x1015;
    pub const PROTOCOL = 0x1016;
    pub const PROTOTYPE = PROTOCOL;
    pub const TS_CLOCK = 0x1017;
    pub const MAX_PACING_RATE = 0x1018;
    pub const DOMAIN = 0x1019;
};

pub const SOL = struct {
    pub const SOCKET = 0xffff;
};

pub const PF = struct {
    pub const UNSPEC = AF.UNSPEC;
    pub const LOCAL = AF.LOCAL;
    pub const UNIX = PF.LOCAL;
    pub const INET = AF.INET;
    pub const IMPLINK = AF.IMPLINK;
    pub const PUP = AF.PUP;
    pub const CHAOS = AF.CHAOS;
    pub const NETBIOS = AF.NETBIOS;
    pub const ISO = AF.ISO;
    pub const OSI = AF.ISO;
    pub const ECMA = AF.ECMA;
    pub const DATAKIT = AF.DATAKIT;
    pub const CCITT = AF.CCITT;
    pub const DECnet = AF.DECnet;
    pub const DLI = AF.DLI;
    pub const LAT = AF.LAT;
    pub const HYLINK = AF.HYLINK;
    pub const APPLETALK = AF.APPLETALK;
    pub const ROUTE = AF.ROUTE;
    pub const LINK = AF.LINK;
    pub const XTP = AF.pseudo_XTP;
    pub const COIP = AF.COIP;
    pub const CNT = AF.CNT;
    pub const SIP = AF.SIP;
    pub const IPX = AF.IPX;
    pub const RTIP = AF.pseudo_RTIP;
    pub const PIP = AF.pseudo_PIP;
    pub const ISDN = AF.ISDN;
    pub const KEY = AF.pseudo_KEY;
    pub const INET6 = AF.pseudo_INET6;
    pub const NATM = AF.NATM;
    pub const ATM = AF.ATM;
    pub const NETGRAPH = AF.NETGRAPH;
    pub const SLOW = AF.SLOW;
    pub const SCLUSTER = AF.SCLUSTER;
    pub const ARP = AF.ARP;
    pub const BLUETOOTH = AF.BLUETOOTH;
    pub const IEEE80211 = AF.IEEE80211;
    pub const INET_SDP = AF.INET_SDP;
    pub const INET6_SDP = AF.INET6_SDP;
    pub const MAX = AF.MAX;
};

pub const AF = struct {
    pub const UNSPEC = 0;
    pub const UNIX = 1;
    pub const LOCAL = UNIX;
    pub const FILE = LOCAL;
    pub const INET = 2;
    pub const IMPLINK = 3;
    pub const PUP = 4;
    pub const CHAOS = 5;
    pub const NETBIOS = 6;
    pub const ISO = 7;
    pub const OSI = ISO;
    pub const ECMA = 8;
    pub const DATAKIT = 9;
    pub const CCITT = 10;
    pub const SNA = 11;
    pub const DECnet = 12;
    pub const DLI = 13;
    pub const LAT = 14;
    pub const HYLINK = 15;
    pub const APPLETALK = 16;
    pub const ROUTE = 17;
    pub const LINK = 18;
    pub const pseudo_XTP = 19;
    pub const COIP = 20;
    pub const CNT = 21;
    pub const pseudo_RTIP = 22;
    pub const IPX = 23;
    pub const SIP = 24;
    pub const pseudo_PIP = 25;
    pub const ISDN = 26;
    pub const E164 = ISDN;
    pub const pseudo_KEY = 27;
    pub const INET6 = 28;
    pub const NATM = 29;
    pub const ATM = 30;
    pub const pseudo_HDRCMPLT = 31;
    pub const NETGRAPH = 32;
    pub const SLOW = 33;
    pub const SCLUSTER = 34;
    pub const ARP = 35;
    pub const BLUETOOTH = 36;
    pub const IEEE80211 = 37;
    pub const INET_SDP = 40;
    pub const INET6_SDP = 42;
    pub const MAX = 42;
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
};

/// add event to kq (implies enable)
pub const EV_ADD = 0x0001;

/// delete event from kq
pub const EV_DELETE = 0x0002;

/// enable event
pub const EV_ENABLE = 0x0004;

/// disable event (not reported)
pub const EV_DISABLE = 0x0008;

/// only report one occurrence
pub const EV_ONESHOT = 0x0010;

/// clear event state after reporting
pub const EV_CLEAR = 0x0020;

/// force immediate event output
/// ... with or without EV_ERROR
/// ... use KEVENT_FLAG_ERROR_EVENTS
///     on syscalls supporting flags
pub const EV_RECEIPT = 0x0040;

/// disable event after reporting
pub const EV_DISPATCH = 0x0080;

pub const EVFILT_READ = -1;
pub const EVFILT_WRITE = -2;

/// attached to aio requests
pub const EVFILT_AIO = -3;

/// attached to vnodes
pub const EVFILT_VNODE = -4;

/// attached to struct proc
pub const EVFILT_PROC = -5;

/// attached to struct proc
pub const EVFILT_SIGNAL = -6;

/// timers
pub const EVFILT_TIMER = -7;

/// Process descriptors
pub const EVFILT_PROCDESC = -8;

/// Filesystem events
pub const EVFILT_FS = -9;

pub const EVFILT_LIO = -10;

/// User events
pub const EVFILT_USER = -11;

/// Sendfile events
pub const EVFILT_SENDFILE = -12;

pub const EVFILT_EMPTY = -13;

pub const T = struct {
    pub const CGETA = 0x8000;
    pub const CSETA = 0x8001;
    pub const CSETAW = 0x8004;
    pub const CSETAF = 0x8003;
    pub const CSBRK = 08005;
    pub const CXONC = 0x8007;
    pub const CFLSH = 0x8006;

    pub const IOCSCTTY = 0x8017;
    pub const IOCGPGRP = 0x8015;
    pub const IOCSPGRP = 0x8016;
    pub const IOCGWINSZ = 0x8012;
    pub const IOCSWINSZ = 0x8013;
    pub const IOCMGET = 0x8018;
    pub const IOCMBIS = 0x8022;
    pub const IOCMBIC = 0x8023;
    pub const IOCMSET = 0x8019;
    pub const FIONREAD = 0xbe000001;
    pub const FIONBIO = 0xbe000000;
    pub const IOCSBRK = 0x8020;
    pub const IOCCBRK = 0x8021;
    pub const IOCGSID = 0x8024;
};

pub const winsize = extern struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

const NSIG = 32;

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = extern struct {
    /// signal handler
    __sigaction_u: extern union {
        __sa_handler: fn (i32) callconv(.C) void,
    },

    /// see signal options
    sa_flags: u32,

    /// signal mask to apply
    sa_mask: sigset_t,
};

pub const sigset_t = extern struct {
    __bits: [SIG.WORDS]u32,
};

pub const E = enum(i32) {
    /// No error occurred.
    SUCCESS = 0,
    PERM = -0x7ffffff1, // Operation not permitted
    NOENT = -0x7fff9ffd, // No such file or directory
    SRCH = -0x7fff8ff3, // No such process
    INTR = -0x7ffffff6, // Interrupted system call
    IO = -0x7fffffff, // Input/output error
    NXIO = -0x7fff8ff5, // Device not configured
    @"2BIG" = -0x7fff8fff, // Argument list too long
    NOEXEC = -0x7fffecfe, // Exec format error
    CHILD = -0x7fff8ffe, // No child processes
    DEADLK = -0x7fff8ffd, // Resource deadlock avoided
    NOMEM = -0x80000000, // Cannot allocate memory
    ACCES = -0x7ffffffe, // Permission denied
    FAULT = -0x7fffecff, // Bad address
    BUSY = -0x7ffffff2, // Device busy
    EXIST = -0x7fff9ffe, // File exists
    XDEV = -0x7fff9ff5, // Cross-device link
    NODEV = -0x7fff8ff9, // Operation not supported by device
    NOTDIR = -0x7fff9ffb, // Not a directory
    ISDIR = -0x7fff9ff7, // Is a directory
    INVAL = -0x7ffffffb, // Invalid argument
    NFILE = -0x7fff8ffa, // Too many open files in system
    MFILE = -0x7fff9ff6, // Too many open files
    NOTTY = -0x7fff8ff6, // Inappropriate ioctl for device
    TXTBSY = -0x7fff8fc5, // Text file busy
    FBIG = -0x7fff8ffc, // File too large
    NOSPC = -0x7fff9ff9, // No space left on device
    SPIPE = -0x7fff8ff4, // Illegal seek
    ROFS = -0x7fff9ff8, // Read-only filesystem
    MLINK = -0x7fff8ffb, // Too many links
    PIPE = -0x7fff9ff3, // Broken pipe
    BADF = -0x7fffa000, // Bad file descriptor

    // math software
    DOM = 33, // Numerical argument out of domain
    RANGE = 34, // Result too large

    // non-blocking and interrupt i/o

    /// Also used for `WOULDBLOCK`.
    AGAIN = -0x7ffffff5,
    INPROGRESS = -0x7fff8fdc,
    ALREADY = -0x7fff8fdb,

    // ipc/network software -- argument errors
    NOTSOCK = 38, // Socket operation on non-socket
    DESTADDRREQ = 39, // Destination address required
    MSGSIZE = 40, // Message too long
    PROTOTYPE = 41, // Protocol wrong type for socket
    NOPROTOOPT = 42, // Protocol not available
    PROTONOSUPPORT = 43, // Protocol not supported
    SOCKTNOSUPPORT = 44, // Socket type not supported
    /// Also used for `NOTSUP`.
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

    _,
};

pub const MINSIGSTKSZ = switch (builtin.cpu.arch) {
    .i386, .x86_64 => 2048,
    .arm, .aarch64 => 4096,
    else => @compileError("MINSIGSTKSZ not defined for this architecture"),
};
pub const SIGSTKSZ = MINSIGSTKSZ + 32768;

pub const SS_ONSTACK = 1;
pub const SS_DISABLE = 4;

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
    pub const IFWHT = 0o160000;

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

    pub fn IWHT(m: u32) bool {
        return m & IFMT == IFWHT;
    }
};

pub const HOST_NAME_MAX = 255;

pub const AT = struct {
    /// Magic value that specify the use of the current working directory
    /// to determine the target of relative file paths in the openat() and
    /// similar syscalls.
    pub const FDCWD = -100;
    /// Check access using effective user and group ID
    pub const EACCESS = 0x0100;
    /// Do not follow symbolic links
    pub const SYMLINK_NOFOLLOW = 0x0200;
    /// Follow symbolic link
    pub const SYMLINK_FOLLOW = 0x0400;
    /// Remove directory instead of file
    pub const REMOVEDIR = 0x0800;
    /// Fail if not under dirfd
    pub const BENEATH = 0x1000;
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
    /// dummy for IP
    pub const IP = 0;
    /// control message protocol
    pub const ICMP = 1;
    /// tcp
    pub const TCP = 6;
    /// user datagram protocol
    pub const UDP = 17;
    /// IP6 header
    pub const IPV6 = 41;
    /// raw IP packet
    pub const RAW = 255;
    /// IP6 hop-by-hop options
    pub const HOPOPTS = 0;
    /// group mgmt protocol
    pub const IGMP = 2;
    /// gateway^2 (deprecated)
    pub const GGP = 3;
    /// IPv4 encapsulation
    pub const IPV4 = 4;
    /// for compatibility
    pub const IPIP = IPV4;
    /// Stream protocol II
    pub const ST = 7;
    /// exterior gateway protocol
    pub const EGP = 8;
    /// private interior gateway
    pub const PIGP = 9;
    /// BBN RCC Monitoring
    pub const RCCMON = 10;
    /// network voice protocol
    pub const NVPII = 11;
    /// pup
    pub const PUP = 12;
    /// Argus
    pub const ARGUS = 13;
    /// EMCON
    pub const EMCON = 14;
    /// Cross Net Debugger
    pub const XNET = 15;
    /// Chaos
    pub const CHAOS = 16;
    /// Multiplexing
    pub const MUX = 18;
    /// DCN Measurement Subsystems
    pub const MEAS = 19;
    /// Host Monitoring
    pub const HMP = 20;
    /// Packet Radio Measurement
    pub const PRM = 21;
    /// xns idp
    pub const IDP = 22;
    /// Trunk-1
    pub const TRUNK1 = 23;
    /// Trunk-2
    pub const TRUNK2 = 24;
    /// Leaf-1
    pub const LEAF1 = 25;
    /// Leaf-2
    pub const LEAF2 = 26;
    /// Reliable Data
    pub const RDP = 27;
    /// Reliable Transaction
    pub const IRTP = 28;
    /// tp-4 w/ class negotiation
    pub const TP = 29;
    /// Bulk Data Transfer
    pub const BLT = 30;
    /// Network Services
    pub const NSP = 31;
    /// Merit Internodal
    pub const INP = 32;
    /// Datagram Congestion Control Protocol
    pub const DCCP = 33;
    /// Third Party Connect
    pub const @"3PC" = 34;
    /// InterDomain Policy Routing
    pub const IDPR = 35;
    /// XTP
    pub const XTP = 36;
    /// Datagram Delivery
    pub const DDP = 37;
    /// Control Message Transport
    pub const CMTP = 38;
    /// TP++ Transport
    pub const TPXX = 39;
    /// IL transport protocol
    pub const IL = 40;
    /// Source Demand Routing
    pub const SDRP = 42;
    /// IP6 routing header
    pub const ROUTING = 43;
    /// IP6 fragmentation header
    pub const FRAGMENT = 44;
    /// InterDomain Routing
    pub const IDRP = 45;
    /// resource reservation
    pub const RSVP = 46;
    /// General Routing Encap.
    pub const GRE = 47;
    /// Mobile Host Routing
    pub const MHRP = 48;
    /// BHA
    pub const BHA = 49;
    /// IP6 Encap Sec. Payload
    pub const ESP = 50;
    /// IP6 Auth Header
    pub const AH = 51;
    /// Integ. Net Layer Security
    pub const INLSP = 52;
    /// IP with encryption
    pub const SWIPE = 53;
    /// Next Hop Resolution
    pub const NHRP = 54;
    /// IP Mobility
    pub const MOBILE = 55;
    /// Transport Layer Security
    pub const TLSP = 56;
    /// SKIP
    pub const SKIP = 57;
    /// ICMP6
    pub const ICMPV6 = 58;
    /// IP6 no next header
    pub const NONE = 59;
    /// IP6 destination option
    pub const DSTOPTS = 60;
    /// any host internal protocol
    pub const AHIP = 61;
    /// CFTP
    pub const CFTP = 62;
    /// "hello" routing protocol
    pub const HELLO = 63;
    /// SATNET/Backroom EXPAK
    pub const SATEXPAK = 64;
    /// Kryptolan
    pub const KRYPTOLAN = 65;
    /// Remote Virtual Disk
    pub const RVD = 66;
    /// Pluribus Packet Core
    pub const IPPC = 67;
    /// Any distributed FS
    pub const ADFS = 68;
    /// Satnet Monitoring
    pub const SATMON = 69;
    /// VISA Protocol
    pub const VISA = 70;
    /// Packet Core Utility
    pub const IPCV = 71;
    /// Comp. Prot. Net. Executive
    pub const CPNX = 72;
    /// Comp. Prot. HeartBeat
    pub const CPHB = 73;
    /// Wang Span Network
    pub const WSN = 74;
    /// Packet Video Protocol
    pub const PVP = 75;
    /// BackRoom SATNET Monitoring
    pub const BRSATMON = 76;
    /// Sun net disk proto (temp.)
    pub const ND = 77;
    /// WIDEBAND Monitoring
    pub const WBMON = 78;
    /// WIDEBAND EXPAK
    pub const WBEXPAK = 79;
    /// ISO cnlp
    pub const EON = 80;
    /// VMTP
    pub const VMTP = 81;
    /// Secure VMTP
    pub const SVMTP = 82;
    /// Banyon VINES
    pub const VINES = 83;
    /// TTP
    pub const TTP = 84;
    /// NSFNET-IGP
    pub const IGP = 85;
    /// dissimilar gateway prot.
    pub const DGP = 86;
    /// TCF
    pub const TCF = 87;
    /// Cisco/GXS IGRP
    pub const IGRP = 88;
    /// OSPFIGP
    pub const OSPFIGP = 89;
    /// Strite RPC protocol
    pub const SRPC = 90;
    /// Locus Address Resoloution
    pub const LARP = 91;
    /// Multicast Transport
    pub const MTP = 92;
    /// AX.25 Frames
    pub const AX25 = 93;
    /// IP encapsulated in IP
    pub const IPEIP = 94;
    /// Mobile Int.ing control
    pub const MICP = 95;
    /// Semaphore Comm. security
    pub const SCCSP = 96;
    /// Ethernet IP encapsulation
    pub const ETHERIP = 97;
    /// encapsulation header
    pub const ENCAP = 98;
    /// any private encr. scheme
    pub const APES = 99;
    /// GMTP
    pub const GMTP = 100;
    /// payload compression (IPComp)
    pub const IPCOMP = 108;
    /// SCTP
    pub const SCTP = 132;
    /// IPv6 Mobility Header
    pub const MH = 135;
    /// UDP-Lite
    pub const UDPLITE = 136;
    /// IP6 Host Identity Protocol
    pub const HIP = 139;
    /// IP6 Shim6 Protocol
    pub const SHIM6 = 140;
    /// Protocol Independent Mcast
    pub const PIM = 103;
    /// CARP
    pub const CARP = 112;
    /// PGM
    pub const PGM = 113;
    /// MPLS-in-IP
    pub const MPLS = 137;
    /// PFSYNC
    pub const PFSYNC = 240;
    /// Reserved
    pub const RESERVED_253 = 253;
    /// Reserved
    pub const RESERVED_254 = 254;
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
    NPTS = 11,
    SWAP = 12,
    KQUEUES = 13,
    UMTXP = 14,
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

// TODO fill out if needed
pub const directory_which = enum(c_int) {
    B_USER_SETTINGS_DIRECTORY = 0xbbe,

    _,
};

pub const cc_t = u8;
pub const speed_t = u8;
pub const tcflag_t = u32;

pub const NCCS = 32;

pub const termios = extern struct {
    c_iflag: tcflag_t,
    c_oflag: tcflag_t,
    c_cflag: tcflag_t,
    c_lflag: tcflag_t,
    c_line: cc_t,
    c_ispeed: speed_t,
    c_ospeed: speed_t,
    cc_t: [NCCS]cc_t,
};
