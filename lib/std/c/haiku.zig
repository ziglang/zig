const std = @import("../std.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;

pub extern "root" fn find_directory(which: directory_which, volume: i32, createIt: bool, path_ptr: [*]u8, length: i32) u64;

pub extern "root" fn find_thread(thread_name: ?*anyopaque) i32;

pub extern "root" fn get_system_info(system_info: *system_info) usize;

pub extern "root" fn _get_team_info(team: i32, team_info: *team_info, size: usize) i32;

pub extern "root" fn _get_next_area_info(team: i32, cookie: *i64, area_info: *area_info, size: usize) i32;

// TODO revisit if abi changes or better option becomes apparent
pub extern "root" fn _get_next_image_info(team: i32, cookie: *i32, image_info: *image_info, size: usize) i32;

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

pub const EAI = enum(i32) {
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

pub const fd_t = i32;

pub const socklen_t = u32;

// Modes and flags for dlopen()
// include/dlfcn.h

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
    type: i16,
    whence: i16,
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

// access function
pub const F_OK = 0; // test for existence of file
pub const X_OK = 1; // test for execute or search permission
pub const W_OK = 2; // test for write permission
pub const R_OK = 4; // test for read permission

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

    /// WARNING: this flag is not supported by windows socket functions directly,
    ///          it is only supported by std.os.socket. Be sure that this value does
    ///          not share any bits with any of the `SOCK` values.
    pub const CLOEXEC = 0x10000;
    /// WARNING: this flag is not supported by windows socket functions directly,
    ///          it is only supported by std.os.socket. Be sure that this value does
    ///          not share any bits with any of the `SOCK` values.
    pub const NONBLOCK = 0x20000;
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

pub const rlimit_resource = enum(i32) {
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
pub const directory_which = enum(i32) {
    B_USER_SETTINGS_DIRECTORY = 0xbbe,

    _,
};

pub const MSG_NOSIGNAL = 0x0800;

// /system/develop/headers/os/kernel/OS.h

pub const area_id = i32;
pub const port_id = i32;
pub const sem_id = i32;
pub const team_id = i32;
pub const thread_id = i32;

// /system/develop/headers/os/support/Errors.h

pub const E = enum(i32) {
    pub const B_GENERAL_ERROR_BASE: i32 = std.math.minInt(i32);
    pub const B_OS_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x1000;
    pub const B_APP_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x2000;
    pub const B_INTERFACE_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x3000;
    pub const B_MEDIA_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x4000;
    pub const B_TRANSLATION_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x4800;
    pub const B_MIDI_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x5000;
    pub const B_STORAGE_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x6000;
    pub const B_POSIX_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x7000;
    pub const B_MAIL_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x8000;
    pub const B_PRINT_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x9000;
    pub const B_DEVICE_ERROR_BASE = B_GENERAL_ERROR_BASE + 0xa000;

    pub const B_ERRORS_END = B_GENERAL_ERROR_BASE + 0xffff;

    pub const B_NO_MEMORY = B_GENERAL_ERROR_BASE + 0;
    pub const B_IO_ERROR = B_GENERAL_ERROR_BASE + 1;
    pub const B_PERMISSION_DENIED = B_GENERAL_ERROR_BASE + 2;
    pub const B_BAD_INDEX = B_GENERAL_ERROR_BASE + 3;
    pub const B_BAD_TYPE = B_GENERAL_ERROR_BASE + 4;
    pub const B_BAD_VALUE = B_GENERAL_ERROR_BASE + 5;
    pub const B_MISMATCHED_VALUES = B_GENERAL_ERROR_BASE + 6;
    pub const B_NAME_NOT_FOUND = B_GENERAL_ERROR_BASE + 7;
    pub const B_NAME_IN_USE = B_GENERAL_ERROR_BASE + 8;
    pub const B_TIMED_OUT = B_GENERAL_ERROR_BASE + 9;
    pub const B_INTERRUPTED = B_GENERAL_ERROR_BASE + 10;
    pub const B_WOULD_BLOCK = B_GENERAL_ERROR_BASE + 11;
    pub const B_CANCELED = B_GENERAL_ERROR_BASE + 12;
    pub const B_NO_INIT = B_GENERAL_ERROR_BASE + 13;
    pub const B_NOT_INITIALIZED = B_GENERAL_ERROR_BASE + 13;
    pub const B_BUSY = B_GENERAL_ERROR_BASE + 14;
    pub const B_NOT_ALLOWED = B_GENERAL_ERROR_BASE + 15;
    pub const B_BAD_DATA = B_GENERAL_ERROR_BASE + 16;
    pub const B_DONT_DO_THAT = B_GENERAL_ERROR_BASE + 17;

    pub const B_BAD_IMAGE_ID = B_OS_ERROR_BASE + 0x300;
    pub const B_BAD_ADDRESS = B_OS_ERROR_BASE + 0x301;
    pub const B_NOT_AN_EXECUTABLE = B_OS_ERROR_BASE + 0x302;
    pub const B_MISSING_LIBRARY = B_OS_ERROR_BASE + 0x303;
    pub const B_MISSING_SYMBOL = B_OS_ERROR_BASE + 0x304;
    pub const B_UNKNOWN_EXECUTABLE = B_OS_ERROR_BASE + 0x305;
    pub const B_LEGACY_EXECUTABLE = B_OS_ERROR_BASE + 0x306;

    pub const B_FILE_ERROR = B_STORAGE_ERROR_BASE + 0;
    pub const B_FILE_EXISTS = B_STORAGE_ERROR_BASE + 2;
    pub const B_ENTRY_NOT_FOUND = B_STORAGE_ERROR_BASE + 3;
    pub const B_NAME_TOO_LONG = B_STORAGE_ERROR_BASE + 4;
    pub const B_NOT_A_DIRECTORY = B_STORAGE_ERROR_BASE + 5;
    pub const B_DIRECTORY_NOT_EMPTY = B_STORAGE_ERROR_BASE + 6;
    pub const B_DEVICE_FULL = B_STORAGE_ERROR_BASE + 7;
    pub const B_READ_ONLY_DEVICE = B_STORAGE_ERROR_BASE + 8;
    pub const B_IS_A_DIRECTORY = B_STORAGE_ERROR_BASE + 9;
    pub const B_NO_MORE_FDS = B_STORAGE_ERROR_BASE + 10;
    pub const B_CROSS_DEVICE_LINK = B_STORAGE_ERROR_BASE + 11;
    pub const B_LINK_LIMIT = B_STORAGE_ERROR_BASE + 12;
    pub const B_BUSTED_PIPE = B_STORAGE_ERROR_BASE + 13;
    pub const B_UNSUPPORTED = B_STORAGE_ERROR_BASE + 14;
    pub const B_PARTITION_TOO_SMALL = B_STORAGE_ERROR_BASE + 15;
    pub const B_PARTIAL_READ = B_STORAGE_ERROR_BASE + 16;
    pub const B_PARTIAL_WRITE = B_STORAGE_ERROR_BASE + 17;

    SUCCESS = 0,

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

    NOMEM = B_NO_MEMORY,

    ACCES = B_PERMISSION_DENIED,
    INTR = B_INTERRUPTED,
    IO = B_IO_ERROR,
    BUSY = B_BUSY,
    FAULT = B_BAD_ADDRESS,
    TIMEDOUT = B_TIMED_OUT,
    /// Also used for WOULDBLOCK
    AGAIN = B_WOULD_BLOCK,
    BADF = B_FILE_ERROR,
    EXIST = B_FILE_EXISTS,
    INVAL = B_BAD_VALUE,
    NAMETOOLONG = B_NAME_TOO_LONG,
    NOENT = B_ENTRY_NOT_FOUND,
    PERM = B_NOT_ALLOWED,
    NOTDIR = B_NOT_A_DIRECTORY,
    ISDIR = B_IS_A_DIRECTORY,
    NOTEMPTY = B_DIRECTORY_NOT_EMPTY,
    NOSPC = B_DEVICE_FULL,
    ROFS = B_READ_ONLY_DEVICE,
    MFILE = B_NO_MORE_FDS,
    XDEV = B_CROSS_DEVICE_LINK,
    LOOP = B_LINK_LIMIT,
    NOEXEC = B_NOT_AN_EXECUTABLE,
    PIPE = B_BUSTED_PIPE,

    _,
};

// /system/develop/headers/os/support/SupportDefs.h

pub const status_t = i32;

// /system/develop/headers/posix/arch/*/signal.h

pub const vregs = switch (builtin.cpu.arch) {
    .arm, .thumb => extern struct {
        r0: u32,
        r1: u32,
        r2: u32,
        r3: u32,
        r4: u32,
        r5: u32,
        r6: u32,
        r7: u32,
        r8: u32,
        r9: u32,
        r10: u32,
        r11: u32,
        r12: u32,
        r13: u32,
        r14: u32,
        r15: u32,
        cpsr: u32,
    },
    .aarch64 => extern struct {
        x: [10]u64,
        lr: u64,
        sp: u64,
        elr: u64,
        spsr: u64,
        fp_q: [32]u128,
        fpsr: u32,
        fpcr: u32,
    },
    .m68k => extern struct {
        pc: u32,
        d0: u32,
        d1: u32,
        d2: u32,
        d3: u32,
        d4: u32,
        d5: u32,
        d6: u32,
        d7: u32,
        a0: u32,
        a1: u32,
        a2: u32,
        a3: u32,
        a4: u32,
        a5: u32,
        a6: u32,
        a7: u32,
        ccr: u8,
        f0: f64,
        f1: f64,
        f2: f64,
        f3: f64,
        f4: f64,
        f5: f64,
        f6: f64,
        f7: f64,
        f8: f64,
        f9: f64,
        f10: f64,
        f11: f64,
        f12: f64,
        f13: f64,
    },
    .mipsel => extern struct {
        r0: u32,
    },
    .powerpc => extern struct {
        pc: u32,
        r0: u32,
        r1: u32,
        r2: u32,
        r3: u32,
        r4: u32,
        r5: u32,
        r6: u32,
        r7: u32,
        r8: u32,
        r9: u32,
        r10: u32,
        r11: u32,
        r12: u32,
        f0: f64,
        f1: f64,
        f2: f64,
        f3: f64,
        f4: f64,
        f5: f64,
        f6: f64,
        f7: f64,
        f8: f64,
        f9: f64,
        f10: f64,
        f11: f64,
        f12: f64,
        f13: f64,
        reserved: u32,
        fpscr: u32,
        ctr: u32,
        xer: u32,
        cr: u32,
        msr: u32,
        lr: u32,
    },
    .riscv64 => extern struct {
        x: [31]u64,
        pc: u64,
        f: [32]f64,
        fcsr: u64,
    },
    .sparc64 => extern struct {
        g1: u64,
        g2: u64,
        g3: u64,
        g4: u64,
        g5: u64,
        g6: u64,
        g7: u64,
        o0: u64,
        o1: u64,
        o2: u64,
        o3: u64,
        o4: u64,
        o5: u64,
        sp: u64,
        o7: u64,
        l0: u64,
        l1: u64,
        l2: u64,
        l3: u64,
        l4: u64,
        l5: u64,
        l6: u64,
        l7: u64,
        i0: u64,
        i1: u64,
        i2: u64,
        i3: u64,
        i4: u64,
        i5: u64,
        fp: u64,
        i7: u64,
    },
    .x86 => extern struct {
        pub const old_extended_regs = extern struct {
            control: u16,
            reserved1: u16,
            status: u16,
            reserved2: u16,
            tag: u16,
            reserved3: u16,
            eip: u32,
            cs: u16,
            opcode: u16,
            datap: u32,
            ds: u16,
            reserved4: u16,
            fp_mmx: [8][10]u8,
        };

        pub const fp_register = extern struct { value: [10]u8, reserved: [6]u8 };

        pub const xmm_register = extern struct { value: [16]u8 };

        pub const new_extended_regs = extern struct {
            control: u16,
            status: u16,
            tag: u16,
            opcode: u16,
            eip: u32,
            cs: u16,
            reserved1: u16,
            datap: u32,
            ds: u16,
            reserved2: u16,
            mxcsr: u32,
            reserved3: u32,
            fp_mmx: [8]fp_register,
            xmmx: [8]xmm_register,
            reserved4: [224]u8,
        };

        pub const extended_regs = extern struct {
            state: extern union {
                old_format: old_extended_regs,
                new_format: new_extended_regs,
            },
            format: u32,
        };

        eip: u32,
        eflags: u32,
        eax: u32,
        ecx: u32,
        edx: u32,
        esp: u32,
        ebp: u32,
        reserved: u32,
        xregs: extended_regs,
        edi: u32,
        esi: u32,
        ebx: u32,
    },
    .x86_64 => extern struct {
        pub const fp_register = extern struct {
            value: [10]u8,
            reserved: [6]u8,
        };

        pub const xmm_register = extern struct {
            value: [16]u8,
        };

        pub const fpu_state = extern struct {
            control: u16,
            status: u16,
            tag: u16,
            opcode: u16,
            rip: u64,
            rdp: u64,
            mxcsr: u32,
            mscsr_mask: u32,

            fp_mmx: [8]fp_register,
            xmm: [16]xmm_register,
            reserved: [96]u8,
        };

        pub const xstate_hdr = extern struct {
            bv: u64,
            xcomp_bv: u64,
            reserved: [48]u8,
        };

        pub const savefpu = extern struct {
            fxsave: fpu_state,
            xstate: xstate_hdr,
            ymm: [16]xmm_register,
        };

        rax: u64,
        rbx: u64,
        rcx: u64,
        rdx: u64,
        rdi: u64,
        rsi: u64,
        rbp: u64,
        r8: u64,
        r9: u64,
        r10: u64,
        r11: u64,
        r12: u64,
        r13: u64,
        r14: u64,
        r15: u64,
        rsp: u64,
        rip: u64,
        rflags: u64,
        fpu: savefpu,
    },
    else => void,
};

// /system/develop/headers/posix/dirent.h

pub const DirEnt = extern struct {
    /// device
    dev: dev_t,
    /// parent device (only for queries)
    pdev: dev_t,
    /// inode number
    ino: ino_t,
    /// parent inode (only for queries)
    pino: ino_t,
    /// length of this record, not the name
    reclen: u16,
    /// name of the entry (null byte terminated)
    name: [0]u8,
    pub fn getName(dirent: *const DirEnt) [*:0]const u8 {
        return @ptrCast(&dirent.name);
    }
};

// /system/develop/headers/posix/errno.h

extern "root" fn _errnop() *i32;
pub const _errno = _errnop;

// /system/develop/headers/posix/poll.h

pub const nfds_t = usize;

pub const pollfd = extern struct {
    fd: i32,
    events: i16,
    revents: i16,
};

pub const POLL = struct {
    /// any readable data available
    pub const IN = 0x0001;
    /// file descriptor is writeable
    pub const OUT = 0x0002;
    pub const RDNORM = IN;
    pub const WRNORM = OUT;
    /// priority readable data
    pub const RDBAND = 0x0008;
    /// priority data can be written
    pub const WRBAND = 0x0010;
    /// high priority readable data
    pub const PRI = 0x0020;

    /// errors pending
    pub const ERR = 0x0004;
    /// disconnected
    pub const HUP = 0x0080;
    /// invalid file descriptor
    pub const NVAL = 0x1000;
};

// /system/develop/headers/posix/signal.h

pub const sigset_t = u64;
pub const empty_sigset: sigset_t = 0;
pub const filled_sigset = ~@as(sigset_t, 0);

pub const SIG = struct {
    pub const DFL: ?Sigaction.handler_fn = @ptrFromInt(0);
    pub const IGN: ?Sigaction.handler_fn = @ptrFromInt(1);
    pub const ERR: ?Sigaction.handler_fn = @ptrFromInt(maxInt(usize));

    pub const HOLD: ?Sigaction.handler_fn = @ptrFromInt(3);

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

pub const siginfo_t = extern struct {
    signo: i32,
    code: i32,
    errno: i32,

    pid: pid_t,
    uid: uid_t,
    addr: *allowzero anyopaque,
};

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = extern struct {
    pub const handler_fn = *align(1) const fn (i32) callconv(.C) void;
    pub const sigaction_fn = *const fn (i32, *const siginfo_t, ?*anyopaque) callconv(.C) void;

    /// signal handler
    handler: extern union {
        handler: handler_fn,
        sigaction: sigaction_fn,
    },

    /// signal mask to apply
    mask: sigset_t,

    /// see signal options
    flags: i32,

    /// will be passed to the signal handler, BeOS extension
    userdata: *allowzero anyopaque = undefined,
};

pub const SA = struct {
    pub const NOCLDSTOP = 0x01;
    pub const NOCLDWAIT = 0x02;
    pub const RESETHAND = 0x04;
    pub const NODEFER = 0x08;
    pub const RESTART = 0x10;
    pub const ONSTACK = 0x20;
    pub const SIGINFO = 0x40;
    pub const NOMASK = NODEFER;
    pub const STACK = ONSTACK;
    pub const ONESHOT = RESETHAND;
};

pub const SS = struct {
    pub const ONSTACK = 0x1;
    pub const DISABLE = 0x2;
};

pub const MINSIGSTKSZ = 8192;
pub const SIGSTKSZ = 16384;

pub const stack_t = extern struct {
    sp: [*]u8,
    size: isize,
    flags: i32,
};

pub const NSIG = 65;

pub const mcontext_t = vregs;

pub const ucontext_t = extern struct {
    link: ?*ucontext_t,
    sigmask: sigset_t,
    stack: stack_t,
    mcontext: mcontext_t,
};

// /system/develop/headers/posix/sys/stat.h

pub const Stat = extern struct {
    dev: dev_t,
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    size: off_t,
    rdev: dev_t,
    blksize: blksize_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    crtim: timespec,
    type: u32,
    blocks: blkcnt_t,

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

// /system/develop/headers/posix/sys/types.h

pub const blkcnt_t = i64;
pub const blksize_t = i32;
pub const fsblkcnt_t = i64;
pub const fsfilcnt_t = i64;
pub const off_t = i64;
pub const ino_t = i64;
pub const cnt_t = i32;
pub const dev_t = i32;
pub const pid_t = i32;
pub const id_t = i32;

pub const uid_t = u32;
pub const gid_t = u32;
pub const mode_t = u32;
pub const umode_t = u32;
pub const nlink_t = i32;

pub const clockid_t = i32;
pub const timer_t = *opaque {};

// /system/develop/headers/posix/time.h

pub const clock_t = i32;
pub const suseconds_t = i32;
pub const useconds_t = u32;

pub const time_t = isize;

pub const CLOCKS_PER_SEC = 1_000_000;
pub const CLK_TCK = CLOCKS_PER_SEC;
pub const TIME_UTC = 1;

pub const CLOCK = struct {
    /// system-wide monotonic clock (aka system time)
    pub const MONOTONIC: clockid_t = 0;
    /// system-wide real time clock
    pub const REALTIME: clockid_t = -1;
    /// clock measuring the used CPU time of the current process
    pub const PROCESS_CPUTIME_ID: clockid_t = -2;
    /// clock measuring the used CPU time of the current thread
    pub const THREAD_CPUTIME_ID: clockid_t = -3;
};

pub const timespec = extern struct {
    /// seconds
    tv_sec: time_t,
    /// and nanoseconds
    tv_nsec: isize,
};

pub const itimerspec = extern struct {
    interval: timespec,
    value: timespec,
};

// /system/develop/headers/private/system/syscalls.h

pub extern "root" fn _kern_get_current_team() team_id;
pub extern "root" fn _kern_open_dir(fd: fd_t, path: [*:0]const u8) fd_t;
pub extern "root" fn _kern_read_dir(fd: fd_t, buffer: [*]u8, bufferSize: usize, maxCount: u32) isize;
pub extern "root" fn _kern_rewind_dir(fd: fd_t) status_t;
pub extern "root" fn _kern_read_stat(fd: fd_t, path: [*:0]const u8, traverseLink: bool, stat: *Stat, statSize: usize) status_t;
