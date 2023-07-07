const std = @import("../std.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;
const iovec = std.os.iovec;
const iovec_const = std.os.iovec_const;

extern "c" fn _errnop() *c_int;

pub const _errno = _errnop;

pub extern "c" fn find_directory(which: c_int, volume: i32, createIt: bool, path_ptr: [*]u8, length: i32) u64;

pub extern "c" fn find_thread(thread_name: ?*anyopaque) i32;

pub extern "c" fn get_system_info(system_info: *system_info) usize;

pub extern "c" fn _get_team_info(team: c_int, team_info: *team_info, size: usize) i32;

pub extern "c" fn _get_next_area_info(team: c_int, cookie: *i64, area_info: *area_info, size: usize) i32;

// TODO revisit if abi changes or better option becomes apparent
pub extern "c" fn _get_next_image_info(team: c_int, cookie: *i32, image_info: *image_info, size: usize) i32;

pub extern "c" fn _kern_read_dir(fd: c_int, buf_ptr: [*]u8, nbytes: usize, maxcount: u32) usize;

pub extern "c" fn _kern_read_stat(fd: c_int, path_ptr: [*]u8, traverse_link: bool, st: *Stat, stat_size: i32) usize;

pub extern "c" fn _kern_get_current_team() i32;

pub const sem_t = extern struct {
    type: i32,
    u: extern union {
        named_sem_id: i32,
        unnamed_sem: i32,
    },
    padding: [2]i32,
};

pub const pthread_attr_t = extern struct {
    __detach_state: i32,
    __sched_priority: i32,
    __stack_size: i32,
    __guard_size: i32,
    __stack_address: ?*anyopaque,
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
    mutex: ?*anyopaque = null,
    waiter_count: i32 = 0,
    lock: i32 = 0,
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

pub const AI = struct {
    pub const NUMERICSERV = 0x00000008;
};

pub const AI_NUMERICSERV = AI.NUMERICSERV;

pub const fd_t = c_int;
pub const pid_t = c_int;
pub const uid_t = u32;
pub const gid_t = u32;
pub const mode_t = c_uint;

pub const socklen_t = u32;

// Modes and flags for dlopen()
// include/dlfcn.h

pub const POLL = struct {
    /// input available
    pub const IN = 70;
    /// output available
    pub const OUT = 71;
    /// input message available
    pub const MSG = 72;
    /// I/O error
    pub const ERR = 73;
    /// high priority input available
    pub const PRI = 74;
    /// device disconnected
    pub const HUP = 75;
};

pub const RTLD = struct {
    /// relocations are performed as needed
    pub const LAZY = 0;
    /// the file gets relocated at load time
    pub const NOW = 1;
    /// all symbols are available
    pub const GLOBAL = 2;
    /// symbols are not available for relocating any other object
    pub const LOCAL = 0;
};

pub const dl_phdr_info = extern struct {
    dlpi_addr: usize,
    dlpi_name: ?[*:0]const u8,
    dlpi_phdr: [*]std.elf.Phdr,
    dlpi_phnum: u16,
};

pub const Flock = extern struct {
    type: c_short,
    whence: c_short,
    start: off_t,
    len: off_t,
    pid: pid_t,
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
    msg_control: ?*anyopaque,

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
    pub fn birthtime(self: @This()) timespec {
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

pub const B_OS_NAME_LENGTH = 32; // OS.h

pub const area_info = extern struct {
    area: u32,
    name: [B_OS_NAME_LENGTH]u8,
    size: usize,
    lock: u32,
    protection: u32,
    team_id: i32,
    ram_size: u32,
    copy_count: u32,
    in_count: u32,
    out_count: u32,
    address: *anyopaque,
};

pub const MAXPATHLEN = PATH_MAX;
pub const MAXNAMLEN = NAME_MAX;

pub const image_info = extern struct {
    id: u32,
    image_type: u32,
    sequence: i32,
    init_order: i32,
    init_routine: *anyopaque,
    term_routine: *anyopaque,
    device: i32,
    node: i64,
    name: [MAXPATHLEN]u8,
    text: *anyopaque,
    data: *anyopaque,
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

pub const team_info = extern struct {
    team_id: i32,
    thread_count: i32,
    image_count: i32,
    area_count: i32,
    debugger_nub_thread: i32,
    debugger_nub_port: i32,
    argc: i32,
    args: [64]u8,
    uid: uid_t,
    gid: gid_t,
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

    pub const un = extern struct {
        len: u8 = @sizeOf(un),
        family: sa_family_t = AF.UNIX,
        path: [104]u8,
    };
};

pub const CTL = struct {};

pub const KERN = struct {};

pub const IOV_MAX = 1024;

pub const PATH_MAX = 1024;
/// NOTE: Contains room for the terminating null character (despite the POSIX
/// definition saying that NAME_MAX does not include the terminating null).
pub const NAME_MAX = 256; // limits.h

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const PROT = struct {
    pub const READ = 0x01;
    pub const WRITE = 0x02;
    pub const EXEC = 0x04;
    pub const NONE = 0x00;
};

pub const CLOCK = struct {
    /// system-wide monotonic clock (aka system time)
    pub const MONOTONIC = 0;
    /// system-wide real time clock
    pub const REALTIME = -1;
    /// clock measuring the used CPU time of the current process
    pub const PROCESS_CPUTIME_ID = -2;
    /// clock measuring the used CPU time of the current thread
    pub const THREAD_CPUTIME_ID = -3;
};

pub const MAP = struct {
    /// mmap() error return code
    pub const FAILED = @as(*anyopaque, @ptrFromInt(maxInt(usize)));
    /// changes are seen by others
    pub const SHARED = 0x01;
    /// changes are only seen by caller
    pub const PRIVATE = 0x02;
    /// require mapping to specified addr
    pub const FIXED = 0x04;
    /// no underlying object
    pub const ANONYMOUS = 0x0008;
    pub const ANON = ANONYMOUS;
    /// don't commit memory
    pub const NORESERVE = 0x10;
};

pub const MSF = struct {
    pub const ASYNC = 1;
    pub const INVALIDATE = 2;
    pub const SYNC = 4;
};

pub const W = struct {
    pub const NOHANG = 0x1;
    pub const UNTRACED = 0x2;
    pub const CONTINUED = 0x4;
    pub const EXITED = 0x08;
    pub const STOPPED = 0x10;
    pub const NOWAIT = 0x20;

    pub fn EXITSTATUS(s: u32) u8 {
        return @as(u8, @intCast(s & 0xff));
    }

    pub fn TERMSIG(s: u32) u32 {
        return (s >> 8) & 0xff;
    }

    pub fn STOPSIG(s: u32) u32 {
        return (s >> 16) & 0xff;
    }

    pub fn IFEXITED(s: u32) bool {
        return (s & ~@as(u32, 0xff)) == 0;
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
    pub const ERR = @as(?Sigaction.handler_fn, @ptrFromInt(maxInt(usize)));
    pub const DFL = @as(?Sigaction.handler_fn, @ptrFromInt(0));
    pub const IGN = @as(?Sigaction.handler_fn, @ptrFromInt(1));

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

    pub const BLOCK = 1;
    pub const UNBLOCK = 2;
    pub const SETMASK = 3;
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
    pub const RWMASK = ACCMODE;

    pub const EXCL = 0x0100;
    pub const CREAT = 0x0200;
    pub const TRUNC = 0x0400;
    pub const NOCTTY = 0x1000;
    pub const NOTRAVERSE = 0x2000;

    pub const CLOEXEC = 0x00000040;
    pub const NONBLOCK = 0x00000080;
    pub const NDELAY = NONBLOCK;
    pub const APPEND = 0x00000800;
    pub const SYNC = 0x00010000;
    pub const RSYNC = 0x00020000;
    pub const DSYNC = 0x00040000;
    pub const NOFOLLOW = 0x00080000;
    pub const DIRECT = 0x00100000;
    pub const NOCACHE = DIRECT;
    pub const DIRECTORY = 0x00200000;
};

pub const F = struct {
    pub const DUPFD = 0x0001;
    pub const GETFD = 0x0002;
    pub const SETFD = 0x0004;
    pub const GETFL = 0x0008;
    pub const SETFL = 0x0010;

    pub const GETLK = 0x0020;
    pub const SETLK = 0x0080;
    pub const SETLKW = 0x0100;
    pub const DUPFD_CLOEXEC = 0x0200;

    pub const RDLCK = 0x0040;
    pub const UNLCK = 0x0200;
    pub const WRLCK = 0x0400;
};

pub const LOCK = struct {
    pub const SH = 0x01;
    pub const EX = 0x02;
    pub const NB = 0x04;
    pub const UN = 0x08;
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
    pub const SEQPACKET = 5;
};

pub const SO = struct {
    pub const ACCEPTCONN = 0x00000001;
    pub const BROADCAST = 0x00000002;
    pub const DEBUG = 0x00000004;
    pub const DONTROUTE = 0x00000008;
    pub const KEEPALIVE = 0x00000010;
    pub const OOBINLINE = 0x00000020;
    pub const REUSEADDR = 0x00000040;
    pub const REUSEPORT = 0x00000080;
    pub const USELOOPBACK = 0x00000100;
    pub const LINGER = 0x00000200;

    pub const SNDBUF = 0x40000001;
    pub const SNDLOWAT = 0x40000002;
    pub const SNDTIMEO = 0x40000003;
    pub const RCVBUF = 0x40000004;
    pub const RCVLOWAT = 0x40000005;
    pub const RCVTIMEO = 0x40000006;
    pub const ERROR = 0x40000007;
    pub const TYPE = 0x40000008;
    pub const NONBLOCK = 0x40000009;
    pub const BINDTODEVICE = 0x4000000a;
    pub const PEERCRED = 0x4000000b;
};

pub const SOL = struct {
    pub const SOCKET = -1;
};

pub const PF = struct {
    pub const UNSPEC = AF.UNSPEC;
    pub const INET = AF.INET;
    pub const ROUTE = AF.ROUTE;
    pub const LINK = AF.LINK;
    pub const INET6 = AF.INET6;
    pub const LOCAL = AF.LOCAL;
    pub const UNIX = AF.UNIX;
    pub const BLUETOOTH = AF.BLUETOOTH;
};

pub const AF = struct {
    pub const UNSPEC = 0;
    pub const INET = 1;
    pub const APPLETALK = 2;
    pub const ROUTE = 3;
    pub const LINK = 4;
    pub const INET6 = 5;
    pub const DLI = 6;
    pub const IPX = 7;
    pub const NOTIFY = 8;
    pub const LOCAL = 9;
    pub const UNIX = LOCAL;
    pub const BLUETOOTH = 10;
    pub const MAX = 11;
};

pub const DT = struct {};

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
    pub const CSETAF = 0x8002;
    pub const CSETAW = 0x8003;
    pub const CWAITEVENT = 0x8004;
    pub const CSBRK = 0x8005;
    pub const CFLSH = 0x8006;
    pub const CXONC = 0x8007;
    pub const CQUERYCONNECTED = 0x8008;
    pub const CGETBITS = 0x8009;
    pub const CSETDTR = 0x8010;
    pub const CSETRTS = 0x8011;
    pub const IOCGWINSZ = 0x8012;
    pub const IOCSWINSZ = 0x8013;
    pub const CVTIME = 0x8014;
    pub const IOCGPGRP = 0x8015;
    pub const IOCSPGRP = 0x8016;
    pub const IOCSCTTY = 0x8017;
    pub const IOCMGET = 0x8018;
    pub const IOCMSET = 0x8019;
    pub const IOCSBRK = 0x8020;
    pub const IOCCBRK = 0x8021;
    pub const IOCMBIS = 0x8022;
    pub const IOCMBIC = 0x8023;
    pub const IOCGSID = 0x8024;

    pub const FIONREAD = 0xbe000001;
    pub const FIONBIO = 0xbe000000;
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
    pub const handler_fn = *const fn (i32) align(1) callconv(.C) void;

    /// signal handler
    __sigaction_u: extern union {
        __sa_handler: handler_fn,
    },

    /// see signal options
    sa_flags: u32,

    /// signal mask to apply
    sa_mask: sigset_t,
};

pub const sigset_t = extern struct {
    __bits: [SIG.WORDS]u32,
};

const B_POSIX_ERROR_BASE = -2147454976;

pub const E = enum(i32) {
    @"2BIG" = B_POSIX_ERROR_BASE + 1,
    CHILD = B_POSIX_ERROR_BASE + 2,
    DEADLK = B_POSIX_ERROR_BASE + 3,
    FBIG = B_POSIX_ERROR_BASE + 4,
    MLINK = B_POSIX_ERROR_BASE + 5,
    NFILE = B_POSIX_ERROR_BASE + 6,
    NODEV = B_POSIX_ERROR_BASE + 7,
    NOLCK = B_POSIX_ERROR_BASE + 8,
    NOSYS = B_POSIX_ERROR_BASE + 9,
    NOTTY = B_POSIX_ERROR_BASE + 10,
    NXIO = B_POSIX_ERROR_BASE + 11,
    SPIPE = B_POSIX_ERROR_BASE + 12,
    SRCH = B_POSIX_ERROR_BASE + 13,
    FPOS = B_POSIX_ERROR_BASE + 14,
    SIGPARM = B_POSIX_ERROR_BASE + 15,
    DOM = B_POSIX_ERROR_BASE + 16,
    RANGE = B_POSIX_ERROR_BASE + 17,
    PROTOTYPE = B_POSIX_ERROR_BASE + 18,
    PROTONOSUPPORT = B_POSIX_ERROR_BASE + 19,
    PFNOSUPPORT = B_POSIX_ERROR_BASE + 20,
    AFNOSUPPORT = B_POSIX_ERROR_BASE + 21,
    ADDRINUSE = B_POSIX_ERROR_BASE + 22,
    ADDRNOTAVAIL = B_POSIX_ERROR_BASE + 23,
    NETDOWN = B_POSIX_ERROR_BASE + 24,
    NETUNREACH = B_POSIX_ERROR_BASE + 25,
    NETRESET = B_POSIX_ERROR_BASE + 26,
    CONNABORTED = B_POSIX_ERROR_BASE + 27,
    CONNRESET = B_POSIX_ERROR_BASE + 28,
    ISCONN = B_POSIX_ERROR_BASE + 29,
    NOTCONN = B_POSIX_ERROR_BASE + 30,
    SHUTDOWN = B_POSIX_ERROR_BASE + 31,
    CONNREFUSED = B_POSIX_ERROR_BASE + 32,
    HOSTUNREACH = B_POSIX_ERROR_BASE + 33,
    NOPROTOOPT = B_POSIX_ERROR_BASE + 34,
    NOBUFS = B_POSIX_ERROR_BASE + 35,
    INPROGRESS = B_POSIX_ERROR_BASE + 36,
    ALREADY = B_POSIX_ERROR_BASE + 37,
    ILSEQ = B_POSIX_ERROR_BASE + 38,
    NOMSG = B_POSIX_ERROR_BASE + 39,
    STALE = B_POSIX_ERROR_BASE + 40,
    OVERFLOW = B_POSIX_ERROR_BASE + 41,
    MSGSIZE = B_POSIX_ERROR_BASE + 42,
    OPNOTSUPP = B_POSIX_ERROR_BASE + 43,
    NOTSOCK = B_POSIX_ERROR_BASE + 44,
    HOSTDOWN = B_POSIX_ERROR_BASE + 45,
    BADMSG = B_POSIX_ERROR_BASE + 46,
    CANCELED = B_POSIX_ERROR_BASE + 47,
    DESTADDRREQ = B_POSIX_ERROR_BASE + 48,
    DQUOT = B_POSIX_ERROR_BASE + 49,
    IDRM = B_POSIX_ERROR_BASE + 50,
    MULTIHOP = B_POSIX_ERROR_BASE + 51,
    NODATA = B_POSIX_ERROR_BASE + 52,
    NOLINK = B_POSIX_ERROR_BASE + 53,
    NOSR = B_POSIX_ERROR_BASE + 54,
    NOSTR = B_POSIX_ERROR_BASE + 55,
    NOTSUP = B_POSIX_ERROR_BASE + 56,
    PROTO = B_POSIX_ERROR_BASE + 57,
    TIME = B_POSIX_ERROR_BASE + 58,
    TXTBSY = B_POSIX_ERROR_BASE + 59,
    NOATTR = B_POSIX_ERROR_BASE + 60,
    NOTRECOVERABLE = B_POSIX_ERROR_BASE + 61,
    OWNERDEAD = B_POSIX_ERROR_BASE + 62,

    ACCES = -0x7ffffffe, // Permission denied
    INTR = -0x7ffffff6, // Interrupted system call
    IO = -0x7fffffff, // Input/output error
    BUSY = -0x7ffffff2, // Device busy
    FAULT = -0x7fffecff, // Bad address
    TIMEDOUT = -2147483639, // Operation timed out
    AGAIN = -0x7ffffff5,
    BADF = -0x7fffa000, // Bad file descriptor
    EXIST = -0x7fff9ffe, // File exists
    INVAL = -0x7ffffffb, // Invalid argument
    NAMETOOLONG = -2147459068, // File name too long
    NOENT = -0x7fff9ffd, // No such file or directory
    PERM = -0x7ffffff1, // Operation not permitted
    NOTDIR = -0x7fff9ffb, // Not a directory
    ISDIR = -0x7fff9ff7, // Is a directory
    NOTEMPTY = -2147459066, // Directory not empty
    NOSPC = -0x7fff9ff9, // No space left on device
    ROFS = -0x7fff9ff8, // Read-only filesystem
    MFILE = -0x7fff9ff6, // Too many open files
    XDEV = -0x7fff9ff5, // Cross-device link
    NOEXEC = -0x7fffecfe, // Exec format error
    PIPE = -0x7fff9ff3, // Broken pipe
    NOMEM = -0x80000000, // Cannot allocate memory
    LOOP = -2147459060, // Too many levels of symbolic links
    SUCCESS = 0,
    _,
};

pub const MINSIGSTKSZ = 8192;
pub const SIGSTKSZ = 16384;

pub const SS_ONSTACK = 0x1;
pub const SS_DISABLE = 0x2;

pub const stack_t = extern struct {
    sp: [*]u8,
    size: isize,
    flags: i32,
};

pub const S = struct {
    pub const IFMT = 0o170000;
    pub const IFSOCK = 0o140000;
    pub const IFLNK = 0o120000;
    pub const IFREG = 0o100000;
    pub const IFBLK = 0o060000;
    pub const IFDIR = 0o040000;
    pub const IFCHR = 0o020000;
    pub const IFIFO = 0o010000;
    pub const INDEX_DIR = 0o4000000000;

    pub const IUMSK = 0o7777;
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

    pub fn ISREG(m: u32) bool {
        return m & IFMT == IFREG;
    }

    pub fn ISLNK(m: u32) bool {
        return m & IFMT == IFLNK;
    }

    pub fn ISBLK(m: u32) bool {
        return m & IFMT == IFBLK;
    }

    pub fn ISDIR(m: u32) bool {
        return m & IFMT == IFDIR;
    }

    pub fn ISCHR(m: u32) bool {
        return m & IFMT == IFCHR;
    }

    pub fn ISFIFO(m: u32) bool {
        return m & IFMT == IFIFO;
    }

    pub fn ISSOCK(m: u32) bool {
        return m & IFMT == IFSOCK;
    }

    pub fn ISINDEX(m: u32) bool {
        return m & INDEX_DIR == INDEX_DIR;
    }
};

pub const HOST_NAME_MAX = 255;

pub const AT = struct {
    pub const FDCWD = -1;
    pub const SYMLINK_NOFOLLOW = 0x01;
    pub const SYMLINK_FOLLOW = 0x02;
    pub const REMOVEDIR = 0x04;
    pub const EACCESS = 0x08;
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
    pub const HOPOPTS = 0;
    pub const ICMP = 1;
    pub const IGMP = 2;
    pub const TCP = 6;
    pub const UDP = 17;
    pub const IPV6 = 41;
    pub const ROUTING = 43;
    pub const FRAGMENT = 44;
    pub const ESP = 50;
    pub const AH = 51;
    pub const ICMPV6 = 58;
    pub const NONE = 59;
    pub const DSTOPTS = 60;
    pub const ETHERIP = 97;
    pub const RAW = 255;
    pub const MAX = 256;
};

pub const rlimit_resource = enum(c_int) {
    CORE = 0,
    CPU = 1,
    DATA = 2,
    FSIZE = 3,
    NOFILE = 4,
    STACK = 5,
    AS = 6,
    NOVMON = 7,
    _,
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

pub const NCCS = 11;

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

pub const MSG_NOSIGNAL = 0x0800;
