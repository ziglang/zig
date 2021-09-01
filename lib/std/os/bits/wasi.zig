// Convenience types and consts used by std.os module
const builtin = @import("builtin");
pub const iovec = posix.iovec;
pub const iovec_const = posix.iovec_const;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const mode_t = u32;

pub const time_t = i64; // match https://github.com/CraneStation/wasi-libc

pub const timespec = struct {
    tv_sec: time_t,
    tv_nsec: isize,

    pub fn fromTimestamp(tm: timestamp_t) timespec {
        const tv_sec: timestamp_t = tm / 1_000_000_000;
        const tv_nsec = tm - tv_sec * 1_000_000_000;
        return timespec{
            .tv_sec = @intCast(time_t, tv_sec),
            .tv_nsec = @intCast(isize, tv_nsec),
        };
    }

    pub fn toTimestamp(ts: timespec) timestamp_t {
        const tm = @intCast(timestamp_t, ts.tv_sec * 1_000_000_000) + @intCast(timestamp_t, ts.tv_nsec);
        return tm;
    }
};

pub const kernel_stat = struct {
    dev: device_t,
    ino: inode_t,
    mode: mode_t,
    filetype: filetype_t,
    nlink: linkcount_t,
    size: filesize_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,

    const Self = @This();

    pub fn fromFilestat(stat: filestat_t) Self {
        return Self{
            .dev = stat.dev,
            .ino = stat.ino,
            .mode = 0,
            .filetype = stat.filetype,
            .nlink = stat.nlink,
            .size = stat.size,
            .atim = stat.atime(),
            .mtim = stat.mtime(),
            .ctim = stat.ctime(),
        };
    }

    pub fn atime(self: Self) timespec {
        return self.atim;
    }

    pub fn mtime(self: Self) timespec {
        return self.mtim;
    }

    pub fn ctime(self: Self) timespec {
        return self.ctim;
    }
};

pub const IOV_MAX = 1024;

pub const AT_REMOVEDIR: u32 = 0x4;
pub const AT_FDCWD: fd_t = -2;

// As defined in the wasi_snapshot_preview1 spec file:
// https://github.com/WebAssembly/WASI/blob/master/phases/snapshot/witx/typenames.witx
pub const advice_t = u8;
pub const ADVICE_NORMAL: advice_t = 0;
pub const ADVICE_SEQUENTIAL: advice_t = 1;
pub const ADVICE_RANDOM: advice_t = 2;
pub const ADVICE_WILLNEED: advice_t = 3;
pub const ADVICE_DONTNEED: advice_t = 4;
pub const ADVICE_NOREUSE: advice_t = 5;

pub const clockid_t = u32;
pub const CLOCK = struct {
    pub const REALTIME: clockid_t = 0;
    pub const MONOTONIC: clockid_t = 1;
    pub const PROCESS_CPUTIME_ID: clockid_t = 2;
    pub const THREAD_CPUTIME_ID: clockid_t = 3;
};

pub const device_t = u64;

pub const dircookie_t = u64;
pub const DIRCOOKIE_START: dircookie_t = 0;

pub const dirnamlen_t = u32;

pub const dirent_t = extern struct {
    d_next: dircookie_t,
    d_ino: inode_t,
    d_namlen: dirnamlen_t,
    d_type: filetype_t,
};

pub const errno_t = enum(u16) {
    SUCCESS = 0,
    @"2BIG" = 1,
    ACCES = 2,
    ADDRINUSE = 3,
    ADDRNOTAVAIL = 4,
    AFNOSUPPORT = 5,
    /// This is also the error code used for `WOULDBLOCK`.
    AGAIN = 6,
    ALREADY = 7,
    BADF = 8,
    BADMSG = 9,
    BUSY = 10,
    CANCELED = 11,
    CHILD = 12,
    CONNABORTED = 13,
    CONNREFUSED = 14,
    CONNRESET = 15,
    DEADLK = 16,
    DESTADDRREQ = 17,
    DOM = 18,
    DQUOT = 19,
    EXIST = 20,
    FAULT = 21,
    FBIG = 22,
    HOSTUNREACH = 23,
    IDRM = 24,
    ILSEQ = 25,
    INPROGRESS = 26,
    INTR = 27,
    INVAL = 28,
    IO = 29,
    ISCONN = 30,
    ISDIR = 31,
    LOOP = 32,
    MFILE = 33,
    MLINK = 34,
    MSGSIZE = 35,
    MULTIHOP = 36,
    NAMETOOLONG = 37,
    NETDOWN = 38,
    NETRESET = 39,
    NETUNREACH = 40,
    NFILE = 41,
    NOBUFS = 42,
    NODEV = 43,
    NOENT = 44,
    NOEXEC = 45,
    NOLCK = 46,
    NOLINK = 47,
    NOMEM = 48,
    NOMSG = 49,
    NOPROTOOPT = 50,
    NOSPC = 51,
    NOSYS = 52,
    NOTCONN = 53,
    NOTDIR = 54,
    NOTEMPTY = 55,
    NOTRECOVERABLE = 56,
    NOTSOCK = 57,
    /// This is also the code used for `NOTSUP`.
    OPNOTSUPP = 58,
    NOTTY = 59,
    NXIO = 60,
    OVERFLOW = 61,
    OWNERDEAD = 62,
    PERM = 63,
    PIPE = 64,
    PROTO = 65,
    PROTONOSUPPORT = 66,
    PROTOTYPE = 67,
    RANGE = 68,
    ROFS = 69,
    SPIPE = 70,
    SRCH = 71,
    STALE = 72,
    TIMEDOUT = 73,
    TXTBSY = 74,
    XDEV = 75,
    NOTCAPABLE = 76,
    _,
};
pub const E = errno_t;

pub const event_t = extern struct {
    userdata: userdata_t,
    @"error": errno_t,
    @"type": eventtype_t,
    fd_readwrite: eventfdreadwrite_t,
};

pub const eventfdreadwrite_t = extern struct {
    nbytes: filesize_t,
    flags: eventrwflags_t,
};

pub const eventrwflags_t = u16;
pub const EVENT_FD_READWRITE_HANGUP: eventrwflags_t = 0x0001;

pub const eventtype_t = u8;
pub const EVENTTYPE_CLOCK: eventtype_t = 0;
pub const EVENTTYPE_FD_READ: eventtype_t = 1;
pub const EVENTTYPE_FD_WRITE: eventtype_t = 2;

pub const exitcode_t = u32;

pub const fd_t = if (builtin.link_libc) c_int else u32;

pub const fdflags_t = u16;
pub const FDFLAG_APPEND: fdflags_t = 0x0001;
pub const FDFLAG_DSYNC: fdflags_t = 0x0002;
pub const FDFLAG_NONBLOCK: fdflags_t = 0x0004;
pub const FDFLAG_RSYNC: fdflags_t = 0x0008;
pub const FDFLAG_SYNC: fdflags_t = 0x0010;

pub const fdstat_t = extern struct {
    fs_filetype: filetype_t,
    fs_flags: fdflags_t,
    fs_rights_base: rights_t,
    fs_rights_inheriting: rights_t,
};

pub const filedelta_t = i64;

pub const filesize_t = u64;

pub const filestat_t = extern struct {
    dev: device_t,
    ino: inode_t,
    filetype: filetype_t,
    nlink: linkcount_t,
    size: filesize_t,
    atim: timestamp_t,
    mtim: timestamp_t,
    ctim: timestamp_t,

    pub fn atime(self: filestat_t) timespec {
        return timespec.fromTimestamp(self.atim);
    }

    pub fn mtime(self: filestat_t) timespec {
        return timespec.fromTimestamp(self.mtim);
    }

    pub fn ctime(self: filestat_t) timespec {
        return timespec.fromTimestamp(self.ctim);
    }
};

pub const filetype_t = u8;
pub const FILETYPE_UNKNOWN: filetype_t = 0;
pub const FILETYPE_BLOCK_DEVICE: filetype_t = 1;
pub const FILETYPE_CHARACTER_DEVICE: filetype_t = 2;
pub const FILETYPE_DIRECTORY: filetype_t = 3;
pub const FILETYPE_REGULAR_FILE: filetype_t = 4;
pub const FILETYPE_SOCKET_DGRAM: filetype_t = 5;
pub const FILETYPE_SOCKET_STREAM: filetype_t = 6;
pub const FILETYPE_SYMBOLIC_LINK: filetype_t = 7;

pub const fstflags_t = u16;
pub const FILESTAT_SET_ATIM: fstflags_t = 0x0001;
pub const FILESTAT_SET_ATIM_NOW: fstflags_t = 0x0002;
pub const FILESTAT_SET_MTIM: fstflags_t = 0x0004;
pub const FILESTAT_SET_MTIM_NOW: fstflags_t = 0x0008;

pub const inode_t = u64;
pub const ino_t = inode_t;

pub const linkcount_t = u64;

pub const lookupflags_t = u32;
pub const LOOKUP_SYMLINK_FOLLOW: lookupflags_t = 0x00000001;

pub usingnamespace if (builtin.link_libc) struct {
    // Derived from https://github.com/WebAssembly/wasi-libc/blob/main/expected/wasm32-wasi/predefined-macros.txt
    pub const O_ACCMODE = (O_EXEC | O_RDWR | O_SEARCH);
    pub const O_APPEND = FDFLAG_APPEND;
    pub const O_CLOEXEC = (0);
    pub const O_CREAT = ((1 << 0) << 12); // = __WASI_OFLAGS_CREAT << 12
    pub const O_DIRECTORY = ((1 << 1) << 12); // = __WASI_OFLAGS_DIRECTORY << 12
    pub const O_DSYNC = FDFLAG_DSYNC;
    pub const O_EXCL = ((1 << 2) << 12); // = __WASI_OFLAGS_EXCL << 12
    pub const O_EXEC = (0x02000000);
    pub const O_NOCTTY = (0);
    pub const O_NOFOLLOW = (0x01000000);
    pub const O_NONBLOCK = (1 << FDFLAG_NONBLOCK);
    pub const O_RDONLY = (0x04000000);
    pub const O_RDWR = (O_RDONLY | O_WRONLY);
    pub const O_RSYNC = (1 << FDFLAG_RSYNC);
    pub const O_SEARCH = (0x08000000);
    pub const O_SYNC = (1 << FDFLAG_SYNC);
    pub const O_TRUNC = ((1 << 3) << 12); // = __WASI_OFLAGS_TRUNC << 12
    pub const O_TTY_INIT = (0);
    pub const O_WRONLY = (0x10000000);
} else struct {
    pub const oflags_t = u16;
    pub const O_CREAT: oflags_t = 0x0001;
    pub const O_DIRECTORY: oflags_t = 0x0002;
    pub const O_EXCL: oflags_t = 0x0004;
    pub const O_TRUNC: oflags_t = 0x0008;
};

pub const preopentype_t = u8;
pub const PREOPENTYPE_DIR: preopentype_t = 0;

pub const prestat_t = extern struct {
    pr_type: preopentype_t,
    u: prestat_u_t,
};

pub const prestat_dir_t = extern struct {
    pr_name_len: usize,
};

pub const prestat_u_t = extern union {
    dir: prestat_dir_t,
};

pub const riflags_t = u16;
pub const SOCK_RECV_PEEK: riflags_t = 0x0001;
pub const SOCK_RECV_WAITALL: riflags_t = 0x0002;

pub const rights_t = u64;
pub const RIGHT_FD_DATASYNC: rights_t = 0x0000000000000001;
pub const RIGHT_FD_READ: rights_t = 0x0000000000000002;
pub const RIGHT_FD_SEEK: rights_t = 0x0000000000000004;
pub const RIGHT_FD_FDSTAT_SET_FLAGS: rights_t = 0x0000000000000008;
pub const RIGHT_FD_SYNC: rights_t = 0x0000000000000010;
pub const RIGHT_FD_TELL: rights_t = 0x0000000000000020;
pub const RIGHT_FD_WRITE: rights_t = 0x0000000000000040;
pub const RIGHT_FD_ADVISE: rights_t = 0x0000000000000080;
pub const RIGHT_FD_ALLOCATE: rights_t = 0x0000000000000100;
pub const RIGHT_PATH_CREATE_DIRECTORY: rights_t = 0x0000000000000200;
pub const RIGHT_PATH_CREATE_FILE: rights_t = 0x0000000000000400;
pub const RIGHT_PATH_LINK_SOURCE: rights_t = 0x0000000000000800;
pub const RIGHT_PATH_LINK_TARGET: rights_t = 0x0000000000001000;
pub const RIGHT_PATH_OPEN: rights_t = 0x0000000000002000;
pub const RIGHT_FD_READDIR: rights_t = 0x0000000000004000;
pub const RIGHT_PATH_READLINK: rights_t = 0x0000000000008000;
pub const RIGHT_PATH_RENAME_SOURCE: rights_t = 0x0000000000010000;
pub const RIGHT_PATH_RENAME_TARGET: rights_t = 0x0000000000020000;
pub const RIGHT_PATH_FILESTAT_GET: rights_t = 0x0000000000040000;
pub const RIGHT_PATH_FILESTAT_SET_SIZE: rights_t = 0x0000000000080000;
pub const RIGHT_PATH_FILESTAT_SET_TIMES: rights_t = 0x0000000000100000;
pub const RIGHT_FD_FILESTAT_GET: rights_t = 0x0000000000200000;
pub const RIGHT_FD_FILESTAT_SET_SIZE: rights_t = 0x0000000000400000;
pub const RIGHT_FD_FILESTAT_SET_TIMES: rights_t = 0x0000000000800000;
pub const RIGHT_PATH_SYMLINK: rights_t = 0x0000000001000000;
pub const RIGHT_PATH_REMOVE_DIRECTORY: rights_t = 0x0000000002000000;
pub const RIGHT_PATH_UNLINK_FILE: rights_t = 0x0000000004000000;
pub const RIGHT_POLL_FD_READWRITE: rights_t = 0x0000000008000000;
pub const RIGHT_SOCK_SHUTDOWN: rights_t = 0x0000000010000000;
pub const RIGHT_ALL: rights_t = RIGHT_FD_DATASYNC |
    RIGHT_FD_READ |
    RIGHT_FD_SEEK |
    RIGHT_FD_FDSTAT_SET_FLAGS |
    RIGHT_FD_SYNC |
    RIGHT_FD_TELL |
    RIGHT_FD_WRITE |
    RIGHT_FD_ADVISE |
    RIGHT_FD_ALLOCATE |
    RIGHT_PATH_CREATE_DIRECTORY |
    RIGHT_PATH_CREATE_FILE |
    RIGHT_PATH_LINK_SOURCE |
    RIGHT_PATH_LINK_TARGET |
    RIGHT_PATH_OPEN |
    RIGHT_FD_READDIR |
    RIGHT_PATH_READLINK |
    RIGHT_PATH_RENAME_SOURCE |
    RIGHT_PATH_RENAME_TARGET |
    RIGHT_PATH_FILESTAT_GET |
    RIGHT_PATH_FILESTAT_SET_SIZE |
    RIGHT_PATH_FILESTAT_SET_TIMES |
    RIGHT_FD_FILESTAT_GET |
    RIGHT_FD_FILESTAT_SET_SIZE |
    RIGHT_FD_FILESTAT_SET_TIMES |
    RIGHT_PATH_SYMLINK |
    RIGHT_PATH_REMOVE_DIRECTORY |
    RIGHT_PATH_UNLINK_FILE |
    RIGHT_POLL_FD_READWRITE |
    RIGHT_SOCK_SHUTDOWN;

pub const roflags_t = u16;
pub const SOCK_RECV_DATA_TRUNCATED: roflags_t = 0x0001;

pub const sdflags_t = u8;
pub const SHUT_RD: sdflags_t = 0x01;
pub const SHUT_WR: sdflags_t = 0x02;

pub const siflags_t = u16;

pub const signal_t = u8;
pub const SIGNONE: signal_t = 0;
pub const SIGHUP: signal_t = 1;
pub const SIGINT: signal_t = 2;
pub const SIGQUIT: signal_t = 3;
pub const SIGILL: signal_t = 4;
pub const SIGTRAP: signal_t = 5;
pub const SIGABRT: signal_t = 6;
pub const SIGBUS: signal_t = 7;
pub const SIGFPE: signal_t = 8;
pub const SIGKILL: signal_t = 9;
pub const SIGUSR1: signal_t = 10;
pub const SIGSEGV: signal_t = 11;
pub const SIGUSR2: signal_t = 12;
pub const SIGPIPE: signal_t = 13;
pub const SIGALRM: signal_t = 14;
pub const SIGTERM: signal_t = 15;
pub const SIGCHLD: signal_t = 16;
pub const SIGCONT: signal_t = 17;
pub const SIGSTOP: signal_t = 18;
pub const SIGTSTP: signal_t = 19;
pub const SIGTTIN: signal_t = 20;
pub const SIGTTOU: signal_t = 21;
pub const SIGURG: signal_t = 22;
pub const SIGXCPU: signal_t = 23;
pub const SIGXFSZ: signal_t = 24;
pub const SIGVTALRM: signal_t = 25;
pub const SIGPROF: signal_t = 26;
pub const SIGWINCH: signal_t = 27;
pub const SIGPOLL: signal_t = 28;
pub const SIGPWR: signal_t = 29;
pub const SIGSYS: signal_t = 30;

pub const subclockflags_t = u16;
pub const SUBSCRIPTION_CLOCK_ABSTIME: subclockflags_t = 0x0001;

pub const subscription_t = extern struct {
    userdata: userdata_t,
    u: subscription_u_t,
};

pub const subscription_clock_t = extern struct {
    id: clockid_t,
    timeout: timestamp_t,
    precision: timestamp_t,
    flags: subclockflags_t,
};

pub const subscription_fd_readwrite_t = extern struct {
    fd: fd_t,
};

pub const subscription_u_t = extern struct {
    tag: eventtype_t,
    u: subscription_u_u_t,
};

pub const subscription_u_u_t = extern union {
    clock: subscription_clock_t,
    fd_read: subscription_fd_readwrite_t,
    fd_write: subscription_fd_readwrite_t,
};

pub const timestamp_t = u64;

pub const userdata_t = u64;

pub const whence_t = u8;
pub const WHENCE_SET: whence_t = 0;
pub const WHENCE_CUR: whence_t = 1;
pub const WHENCE_END: whence_t = 2;

pub const S_IEXEC = S_IXUSR;
pub const S_IFBLK = 0x6000;
pub const S_IFCHR = 0x2000;
pub const S_IFDIR = 0x4000;
pub const S_IFIFO = 0xc000;
pub const S_IFLNK = 0xa000;
pub const S_IFMT = S_IFBLK | S_IFCHR | S_IFDIR | S_IFIFO | S_IFLNK | S_IFREG | S_IFSOCK;
pub const S_IFREG = 0x8000;
// There's no concept of UNIX domain socket but we define this value here in order to line with other OSes.
pub const S_IFSOCK = 0x1;

pub const SEEK_SET = WHENCE_SET;
pub const SEEK_CUR = WHENCE_CUR;
pub const SEEK_END = WHENCE_END;

pub const LOCK_SH = 0x1;
pub const LOCK_EX = 0x2;
pub const LOCK_NB = 0x4;
pub const LOCK_UN = 0x8;
