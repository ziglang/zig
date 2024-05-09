const std = @import("../std.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;

extern "c" fn __error() *c_int;
pub const _errno = __error;

pub extern "c" fn getdents(fd: c_int, buf_ptr: [*]u8, nbytes: usize) isize;
pub extern "c" fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) c_int;
pub extern "c" fn getrandom(buf_ptr: [*]u8, buf_len: usize, flags: c_uint) isize;

pub extern "c" fn pthread_getthreadid_np() c_int;
pub extern "c" fn pthread_set_name_np(thread: std.c.pthread_t, name: [*:0]const u8) void;
pub extern "c" fn pthread_get_name_np(thread: std.c.pthread_t, name: [*:0]u8, len: usize) void;
pub extern "c" fn pipe2(fds: *[2]fd_t, flags: std.c.O) c_int;
pub extern "c" fn arc4random_buf(buf: [*]u8, len: usize) void;

pub extern "c" fn posix_memalign(memptr: *?*anyopaque, alignment: usize, size: usize) c_int;
pub extern "c" fn malloc_usable_size(?*const anyopaque) usize;

pub extern "c" fn getpid() pid_t;

pub extern "c" fn kinfo_getfile(pid: pid_t, cntp: *c_int) ?[*]kinfo_file;

pub const sf_hdtr = extern struct {
    headers: [*]const iovec_const,
    hdr_cnt: c_int,
    trailers: [*]const iovec_const,
    trl_cnt: c_int,
};
pub extern "c" fn sendfile(
    in_fd: fd_t,
    out_fd: fd_t,
    offset: off_t,
    nbytes: usize,
    sf_hdtr: ?*sf_hdtr,
    sbytes: ?*off_t,
    flags: u32,
) c_int;

pub const dl_iterate_phdr_callback = *const fn (info: *dl_phdr_info, size: usize, data: ?*anyopaque) callconv(.C) c_int;
pub extern "c" fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*anyopaque) c_int;

pub const pthread_attr_t = extern struct {
    inner: ?*anyopaque = null,
};

pub const sem_t = extern struct {
    _magic: u32,
    _kern: extern struct {
        _count: u32,
        _flags: u32,
    },
    _padding: u32,
};

// https://github.com/freebsd/freebsd-src/blob/main/sys/sys/umtx.h
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
    _timeout: timespec,
    _flags: u32,
    _clockid: u32,
};

pub extern "c" fn _umtx_op(obj: usize, op: c_int, val: c_ulong, uaddr: usize, uaddr2: usize) c_int;

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

pub const IFNAMESIZE = 16;

pub const AI = struct {
    /// get address to use bind()
    pub const PASSIVE = 0x00000001;
    /// fill ai_canonname
    pub const CANONNAME = 0x00000002;
    /// prevent host name resolution
    pub const NUMERICHOST = 0x00000004;
    /// prevent service name resolution
    pub const NUMERICSERV = 0x00000008;
    /// valid flags for addrinfo (not a standard def, apps should not use it)
    pub const MASK = (PASSIVE | CANONNAME | NUMERICHOST | NUMERICSERV | ADDRCONFIG | ALL | V4MAPPED);
    /// IPv6 and IPv4-mapped (with V4MAPPED)
    pub const ALL = 0x00000100;
    /// accept IPv4-mapped if kernel supports
    pub const V4MAPPED_CFG = 0x00000200;
    /// only if any address is assigned
    pub const ADDRCONFIG = 0x00000400;
    /// accept IPv4-mapped IPv6 address
    pub const V4MAPPED = 0x00000800;
    /// special recommended flags for getipnodebyname
    pub const DEFAULT = (V4MAPPED_CFG | ADDRCONFIG);
};

pub const blksize_t = i32;
pub const blkcnt_t = i64;
pub const clockid_t = i32;
pub const fflags_t = u32;
pub const fsblkcnt_t = u64;
pub const fsfilcnt_t = u64;
pub const nlink_t = u64;
pub const fd_t = i32;
pub const pid_t = i32;
pub const uid_t = u32;
pub const gid_t = u32;
pub const mode_t = u16;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;
pub const time_t = i64;
// The signedness is not constant across different architectures.
pub const clock_t = isize;

pub const socklen_t = u32;
pub const suseconds_t = c_long;

/// Renamed from `kevent` to `Kevent` to avoid conflict with function name.
pub const Kevent = extern struct {
    /// Identifier for this event.
    ident: usize,
    /// Filter for event.
    filter: i16,
    /// Action flags for kqueue.
    flags: u16,
    /// Filter flag value.
    fflags: u32,
    /// Filter data value.
    data: i64,
    /// Opaque user data identifier.
    udata: usize,
    /// Future extensions.
    _ext: [4]u64 = [_]u64{0} ** 4,
};

// Modes and flags for dlopen()
// include/dlfcn.h

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
    /// Module relocation base.
    dlpi_addr: if (builtin.target.ptrBitWidth() == 32) std.elf.Elf32_Addr else std.elf.Elf64_Addr,
    /// Module name.
    dlpi_name: ?[*:0]const u8,
    /// Pointer to module's phdr.
    dlpi_phdr: [*]std.elf.Phdr,
    /// Number of entries in phdr.
    dlpi_phnum: u16,
    /// Total number of loads.
    dlpi_adds: u64,
    /// Total number of unloads.
    dlpi_subs: u64,
    dlpi_tls_modid: usize,
    dlpi_tls_data: ?*anyopaque,
};

pub const Flock = extern struct {
    /// Starting offset.
    start: off_t,
    /// Number of consecutive bytes to be locked.
    /// A value of 0 means to the end of the file.
    len: off_t,
    /// Lock owner.
    pid: pid_t,
    /// Lock type.
    type: i16,
    /// Type of the start member.
    whence: i16,
    /// Remote system id or zero for local.
    sysid: i32,
};

pub const msghdr = extern struct {
    /// Optional address.
    msg_name: ?*sockaddr,
    /// Size of address.
    msg_namelen: socklen_t,
    /// Scatter/gather array.
    msg_iov: [*]iovec,
    /// Number of elements in msg_iov.
    msg_iovlen: i32,
    /// Ancillary data.
    msg_control: ?*anyopaque,
    /// Ancillary data buffer length.
    msg_controllen: socklen_t,
    /// Flags on received message.
    msg_flags: i32,
};

pub const msghdr_const = extern struct {
    /// Optional address.
    msg_name: ?*const sockaddr,
    /// Size of address.
    msg_namelen: socklen_t,
    /// Scatter/gather array.
    msg_iov: [*]iovec_const,
    /// Number of elements in msg_iov.
    msg_iovlen: i32,
    /// Ancillary data.
    msg_control: ?*anyopaque,
    /// Ancillary data buffer length.
    msg_controllen: socklen_t,
    /// Flags on received message.
    msg_flags: i32,
};

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

pub const timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};

pub const timeval = extern struct {
    /// seconds
    tv_sec: time_t,
    /// microseconds
    tv_usec: suseconds_t,
};

pub const dirent = extern struct {
    /// File number of entry.
    fileno: ino_t,
    /// Directory offset of entry.
    off: off_t,
    /// Length of this record.
    reclen: u16,
    /// File type, one of DT_.
    type: u8,
    pad0: u8 = 0,
    /// Length of the name member.
    namlen: u16,
    pad1: u16 = 0,
    /// Name of entry.
    name: [255:0]u8,
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
};

pub const KINFO_FILE_SIZE = 1392;

comptime {
    std.debug.assert(@sizeOf(kinfo_file) == KINFO_FILE_SIZE);
    std.debug.assert(@alignOf(kinfo_file) == @sizeOf(u64));
}

pub const CTL = struct {
    pub const KERN = 1;
    pub const DEBUG = 5;
};

pub const KERN = struct {
    pub const PROC = 14; // struct: process entries
    pub const PROC_PATHNAME = 12; // path to executable
    pub const PROC_FILEDESC = 33; // file descriptors for process
    pub const IOV_MAX = 35;
};

pub const PATH_MAX = 1024;
pub const IOV_MAX = KERN.IOV_MAX;

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

pub const MADV = struct {
    pub const NORMAL = 0;
    pub const RANDOM = 1;
    pub const SEQUENTIAL = 2;
    pub const WILLNEED = 3;
    pub const DONTNEED = 4;
    pub const FREE = 5;
    pub const NOSYNC = 6;
    pub const AUTOSYNC = 7;
    pub const NOCORE = 8;
    pub const CORE = 9;
    pub const PROTECT = 10;
};

pub const MSF = struct {
    pub const ASYNC = 1;
    pub const INVALIDATE = 2;
    pub const SYNC = 4;
};

pub const W = struct {
    pub const NOHANG = 1;
    pub const UNTRACED = 2;
    pub const STOPPED = UNTRACED;
    pub const CONTINUED = 4;
    pub const NOWAIT = 8;
    pub const EXITED = 16;
    pub const TRAPPED = 32;

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
    pub const NOCLDSTOP = 0x0008;
    pub const NODEFER = 0x0010;
    pub const NOCLDWAIT = 0x0020;
    pub const SIGINFO = 0x0040;
};

pub const SIG = struct {
    pub const HUP = 1;
    pub const INT = 2;
    pub const QUIT = 3;
    pub const ILL = 4;
    pub const TRAP = 5;
    pub const ABRT = 6;
    pub const IOT = ABRT;
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
    pub const LWP = THR;
    pub const LIBRT = 33;

    pub const RTMIN = 65;
    pub const RTMAX = 126;

    pub const BLOCK = 1;
    pub const UNBLOCK = 2;
    pub const SETMASK = 3;

    pub const DFL: ?Sigaction.handler_fn = @ptrFromInt(0);
    pub const IGN: ?Sigaction.handler_fn = @ptrFromInt(1);
    pub const ERR: ?Sigaction.handler_fn = @ptrFromInt(maxInt(usize));

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
pub const sigval = extern union {
    int: c_int,
    ptr: ?*anyopaque,
};

pub const sigset_t = extern struct {
    __bits: [SIG.WORDS]u32,
};

pub const empty_sigset = sigset_t{ .__bits = [_]u32{0} ** SIG.WORDS };

// access function
pub const F_OK = 0; // test for existence of file
pub const X_OK = 1; // test for execute or search permission
pub const W_OK = 2; // test for write permission
pub const R_OK = 4; // test for read permission

/// Command flags for fcntl(2).
pub const F = struct {
    /// Duplicate file descriptor.
    pub const DUPFD = 0;
    /// Get file descriptor flags.
    pub const GETFD = 1;
    /// Set file descriptor flags.
    pub const SETFD = 2;
    /// Get file status flags.
    pub const GETFL = 3;
    /// Set file status flags.
    pub const SETFL = 4;

    /// Get SIGIO/SIGURG proc/pgrrp.
    pub const GETOWN = 5;
    /// Set SIGIO/SIGURG proc/pgrrp.
    pub const SETOWN = 6;

    /// Get record locking information.
    pub const GETLK = 11;
    /// Set record locking information.
    pub const SETLK = 12;
    /// Set record locking information and wait if blocked.
    pub const SETLKW = 13;

    /// Debugging support for remote locks.
    pub const SETLK_REMOTE = 14;
    /// Read ahead.
    pub const READAHEAD = 15;

    /// DUPFD with FD_CLOEXEC set.
    pub const DUPFD_CLOEXEC = 17;
    /// DUP2FD with FD_CLOEXEC set.
    pub const DUP2FD_CLOEXEC = 18;

    pub const ADD_SEALS = 19;
    pub const GET_SEALS = 20;
    /// Return `kinfo_file` for a file descriptor.
    pub const KINFO = 22;

    // Seals (ADD_SEALS, GET_SEALS)
    /// Prevent adding sealings.
    pub const SEAL_SEAL = 0x0001;
    /// May not shrink
    pub const SEAL_SHRINK = 0x0002;
    /// May not grow.
    pub const SEAL_GROW = 0x0004;
    /// May not write.
    pub const SEAL_WRITE = 0x0008;

    // Record locking flags (GETLK, SETLK, SETLKW).
    /// Shared or read lock.
    pub const RDLCK = 1;
    /// Unlock.
    pub const UNLCK = 2;
    /// Exclusive or write lock.
    pub const WRLCK = 3;
    /// Purge locks for a given system ID.
    pub const UNLCKSYS = 4;
    /// Cancel an async lock request.
    pub const CANCEL = 5;

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

/// error, event data contains errno
pub const EV_ERROR = 0x4000;

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

/// On input, NOTE_TRIGGER causes the event to be triggered for output.
pub const NOTE_TRIGGER = 0x01000000;

/// ignore input fflags
pub const NOTE_FFNOP = 0x00000000;

/// and fflags
pub const NOTE_FFAND = 0x40000000;

/// or fflags
pub const NOTE_FFOR = 0x80000000;

/// copy fflags
pub const NOTE_FFCOPY = 0xc0000000;

/// mask for operations
pub const NOTE_FFCTRLMASK = 0xc0000000;
pub const NOTE_FFLAGSMASK = 0x00ffffff;

/// low water mark
pub const NOTE_LOWAT = 0x00000001;

/// behave like poll()
pub const NOTE_FILE_POLL = 0x00000002;

/// vnode was removed
pub const NOTE_DELETE = 0x00000001;

/// data contents changed
pub const NOTE_WRITE = 0x00000002;

/// size increased
pub const NOTE_EXTEND = 0x00000004;

/// attributes changed
pub const NOTE_ATTRIB = 0x00000008;

/// link count changed
pub const NOTE_LINK = 0x00000010;

/// vnode was renamed
pub const NOTE_RENAME = 0x00000020;

/// vnode access was revoked
pub const NOTE_REVOKE = 0x00000040;

/// vnode was opened
pub const NOTE_OPEN = 0x00000080;

/// file closed, fd did not allow write
pub const NOTE_CLOSE = 0x00000100;

/// file closed, fd did allow write
pub const NOTE_CLOSE_WRITE = 0x00000200;

/// file was read
pub const NOTE_READ = 0x00000400;

/// process exited
pub const NOTE_EXIT = 0x80000000;

/// process forked
pub const NOTE_FORK = 0x40000000;

/// process exec'd
pub const NOTE_EXEC = 0x20000000;

/// mask for signal & exit status
pub const NOTE_PDATAMASK = 0x000fffff;
pub const NOTE_PCTRLMASK = (~NOTE_PDATAMASK);

/// data is seconds
pub const NOTE_SECONDS = 0x00000001;

/// data is milliseconds
pub const NOTE_MSECONDS = 0x00000002;

/// data is microseconds
pub const NOTE_USECONDS = 0x00000004;

/// data is nanoseconds
pub const NOTE_NSECONDS = 0x00000008;

/// timeout is absolute
pub const NOTE_ABSTIME = 0x00000010;

pub const T = struct {
    pub const IOCEXCL = 0x2000740d;
    pub const IOCNXCL = 0x2000740e;
    pub const IOCSCTTY = 0x20007461;
    pub const IOCGPGRP = 0x40047477;
    pub const IOCSPGRP = 0x80047476;
    pub const IOCOUTQ = 0x40047473;
    pub const IOCSTI = 0x80017472;
    pub const IOCGWINSZ = 0x40087468;
    pub const IOCSWINSZ = 0x80087467;
    pub const IOCMGET = 0x4004746a;
    pub const IOCMBIS = 0x8004746c;
    pub const IOCMBIC = 0x8004746b;
    pub const IOCMSET = 0x8004746d;
    pub const FIONREAD = 0x4004667f;
    pub const IOCCONS = 0x80047462;
    pub const IOCPKT = 0x80047470;
    pub const FIONBIO = 0x8004667e;
    pub const IOCNOTTY = 0x20007471;
    pub const IOCSETD = 0x8004741b;
    pub const IOCGETD = 0x4004741a;
    pub const IOCSBRK = 0x2000747b;
    pub const IOCCBRK = 0x2000747a;
    pub const IOCGSID = 0x40047463;
    pub const IOCGPTN = 0x4004740f;
    pub const IOCSIG = 0x2004745f;
};

pub const TCSA = enum(c_uint) {
    NOW,
    DRAIN,
    FLUSH,
    _,
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
    pub const handler_fn = *align(1) const fn (i32) callconv(.C) void;
    pub const sigaction_fn = *const fn (i32, *const siginfo_t, ?*anyopaque) callconv(.C) void;

    /// signal handler
    handler: extern union {
        handler: ?handler_fn,
        sigaction: ?sigaction_fn,
    },

    /// see signal options
    flags: c_uint,

    /// signal mask to apply
    mask: sigset_t,
};

pub const siginfo_t = extern struct {
    // Signal number.
    signo: c_int,
    // Errno association.
    errno: c_int,
    /// Signal code.
    ///
    /// Cause of signal, one of the SI_ macros or signal-specific values, i.e.
    /// one of the FPE_... values for SIGFPE.
    /// This value is equivalent to the second argument to an old-style FreeBSD
    /// signal handler.
    code: c_int,
    /// Sending process.
    pid: pid_t,
    /// Sender's ruid.
    uid: uid_t,
    /// Exit value.
    status: c_int,
    /// Faulting instruction.
    addr: *allowzero anyopaque,
    /// Signal value.
    value: sigval,
    reason: extern union {
        fault: extern struct {
            /// Machine specific trap code.
            trapno: c_int,
        },
        timer: extern struct {
            timerid: c_int,
            overrun: c_int,
        },
        mesgq: extern struct {
            mqd: c_int,
        },
        poll: extern struct {
            /// Band event for SIGPOLL. UNUSED.
            band: c_long,
        },
        spare: extern struct {
            spare1: c_long,
            spare2: [7]c_int,
        },
    },
};

pub const mcontext_t = switch (builtin.cpu.arch) {
    .x86_64 => extern struct {
        onstack: u64,
        rdi: u64,
        rsi: u64,
        rdx: u64,
        rcx: u64,
        r8: u64,
        r9: u64,
        rax: u64,
        rbx: u64,
        rbp: u64,
        r10: u64,
        r11: u64,
        r12: u64,
        r13: u64,
        r14: u64,
        r15: u64,
        trapno: u32,
        fs: u16,
        gs: u16,
        addr: u64,
        flags: u32,
        es: u16,
        ds: u16,
        err: u64,
        rip: u64,
        cs: u64,
        rflags: u64,
        rsp: u64,
        ss: u64,
        len: u64,
        fpformat: u64,
        ownedfp: u64,
        fpstate: [64]u64 align(16),
        fsbase: u64,
        gsbase: u64,
        xfpustate: u64,
        xfpustate_len: u64,
        spare: [4]u64,
    },
    .aarch64 => extern struct {
        gpregs: extern struct {
            x: [30]u64,
            lr: u64,
            sp: u64,
            elr: u64,
            spsr: u32,
            _pad: u32,
        },
        fpregs: extern struct {
            q: [32]u128,
            sr: u32,
            cr: u32,
            flags: u32,
            _pad: u32,
        },
        flags: u32,
        _pad: u32,
        _spare: [8]u64,
    },
    else => struct {},
};

pub const REG = switch (builtin.cpu.arch) {
    .aarch64 => struct {
        pub const FP = 29;
        pub const SP = 31;
        pub const PC = 32;
    },
    .arm => struct {
        pub const FP = 11;
        pub const SP = 13;
        pub const PC = 15;
    },
    .x86_64 => struct {
        pub const RBP = 12;
        pub const RIP = 21;
        pub const RSP = 24;
    },
    else => struct {},
};

pub const ucontext_t = extern struct {
    sigmask: sigset_t,
    mcontext: mcontext_t,
    link: ?*ucontext_t,
    stack: stack_t,
    flags: c_int,
    __spare__: [4]c_int,
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

pub const MINSIGSTKSZ = switch (builtin.cpu.arch) {
    .x86, .x86_64 => 2048,
    .arm, .aarch64 => 4096,
    else => @compileError("MINSIGSTKSZ not defined for this architecture"),
};
pub const SIGSTKSZ = MINSIGSTKSZ + 32768;

pub const SS_ONSTACK = 1;
pub const SS_DISABLE = 4;

pub const stack_t = extern struct {
    /// Signal stack base.
    sp: *anyopaque,
    /// Signal stack length.
    size: usize,
    /// SS_DISABLE and/or SS_ONSTACK.
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

pub const nfds_t = u32;

pub const pollfd = extern struct {
    fd: fd_t,
    events: i16,
    revents: i16,
};

pub const POLL = struct {
    /// any readable data available.
    pub const IN = 0x0001;
    /// OOB/Urgent readable data.
    pub const PRI = 0x0002;
    /// file descriptor is writeable.
    pub const OUT = 0x0004;
    /// non-OOB/URG data available.
    pub const RDNORM = 0x0040;
    /// no write type differentiation.
    pub const WRNORM = OUT;
    /// OOB/Urgent readable data.
    pub const RDBAND = 0x0080;
    /// OOB/Urgent data can be written.
    pub const WRBAND = 0x0100;
    /// like IN, except ignore EOF.
    pub const INIGNEOF = 0x2000;
    /// some poll error occurred.
    pub const ERR = 0x0008;
    /// file descriptor was "hung up".
    pub const HUP = 0x0010;
    /// requested events "invalid".
    pub const NVAL = 0x0020;

    pub const STANDARD = IN | PRI | OUT | RDNORM | RDBAND | WRBAND | ERR | HUP | NVAL;
};

pub const NAME_MAX = 255;

pub const MFD = struct {
    pub const CLOEXEC = 0x0001;
    pub const ALLOW_SEALING = 0x0002;
};

pub extern "c" fn memfd_create(name: [*:0]const u8, flags: c_uint) c_int;
pub extern "c" fn copy_file_range(fd_in: fd_t, off_in: ?*off_t, fd_out: fd_t, off_out: ?*off_t, len: usize, flags: u32) usize;
