pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const advice_t = u8;
pub const ADVICE_NORMAL: advice_t = 0;
pub const ADVICE_SEQUENTIAL: advice_t = 1;
pub const ADVICE_RANDOM: advice_t = 2;
pub const ADVICE_WILLNEED: advice_t = 3;
pub const ADVICE_DONTNEED: advice_t = 4;
pub const ADVICE_NOREUSE: advice_t = 5;

pub const clockid_t = u32;
pub const CLOCK_REALTIME: clockid_t = 0;
pub const CLOCK_MONOTONIC: clockid_t = 1;
pub const CLOCK_PROCESS_CPUTIME_ID: clockid_t = 2;
pub const CLOCK_THREAD_CPUTIME_ID: clockid_t = 3;

pub const device_t = u64;

pub const dircookie_t = u64;
pub const DIRCOOKIE_START: dircookie_t = 0;

pub const dirent_t = extern struct {
    d_next: dircookie_t,
    d_ino: inode_t,
    d_namlen: u32,
    d_type: filetype_t,
};

pub const errno_t = u16;

pub const Errno = extern enum(errno_t) {
    ESUCCESS = 0,
    E2BIG = 1,
    EACCES = 2,
    EADDRINUSE = 3,
    EADDRNOTAVAIL = 4,
    EAFNOSUPPORT = 5,
    EAGAIN = 6,
    EALREADY = 7,
    EBADF = 8,
    EBADMSG = 9,
    EBUSY = 10,
    ECANCELED = 11,
    ECHILD = 12,
    ECONNABORTED = 13,
    ECONNREFUSED = 14,
    ECONNRESET = 15,
    EDEADLK = 16,
    EDESTADDRREQ = 17,
    EDOM = 18,
    EDQUOT = 19,
    EEXIST = 20,
    EFAULT = 21,
    EFBIG = 22,
    EHOSTUNREACH = 23,
    EIDRM = 24,
    EILSEQ = 25,
    EINPROGRESS = 26,
    EINTR = 27,
    EINVAL = 28,
    EIO = 29,
    EISCONN = 30,
    EISDIR = 31,
    ELOOP = 32,
    EMFILE = 33,
    EMLINK = 34,
    EMSGSIZE = 35,
    EMULTIHOP = 36,
    ENAMETOOLONG = 37,
    ENETDOWN = 38,
    ENETRESET = 39,
    ENETUNREACH = 40,
    ENFILE = 41,
    ENOBUFS = 42,
    ENODEV = 43,
    ENOENT = 44,
    ENOEXEC = 45,
    ENOLCK = 46,
    ENOLINK = 47,
    ENOMEM = 48,
    ENOMSG = 49,
    ENOPROTOOPT = 50,
    ENOSPC = 51,
    ENOSYS = 52,
    ENOTCONN = 53,
    ENOTDIR = 54,
    ENOTEMPTY = 55,
    ENOTRECOVERABLE = 56,
    ENOTSOCK = 57,
    ENOTSUP = 58,
    ENOTTY = 59,
    ENXIO = 60,
    EOVERFLOW = 61,
    EOWNERDEAD = 62,
    EPERM = 63,
    EPIPE = 64,
    EPROTO = 65,
    EPROTONOSUPPORT = 66,
    EPROTOTYPE = 67,
    ERANGE = 68,
    EROFS = 69,
    ESPIPE = 70,
    ESRCH = 71,
    ESTALE = 72,
    ETIMEDOUT = 73,
    ETXTBSY = 74,
    EXDEV = 75,
    ENOTCAPABLE = 76,

    _,
};

pub const event_t = extern struct {
    userdata: userdata_t,
    @"error": errno_t,
    @"type": eventtype_t,
    u: extern union {
        fd_readwrite: extern struct {
            nbytes: filesize_t,
            flags: eventrwflags_t,
        },
    },
};

pub const eventrwflags_t = u16;
pub const EVENT_FD_READWRITE_HANGUP: eventrwflags_t = 0x0001;

pub const eventtype_t = u8;
pub const EVENTTYPE_CLOCK: eventtype_t = 0;
pub const EVENTTYPE_FD_READ: eventtype_t = 1;
pub const EVENTTYPE_FD_WRITE: eventtype_t = 2;

pub const exitcode_t = u32;

pub const fd_t = u32;

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
    st_dev: device_t,
    st_ino: inode_t,
    st_filetype: filetype_t,
    st_nlink: linkcount_t,
    st_size: filesize_t,
    st_atim: timestamp_t,
    st_mtim: timestamp_t,
    st_ctim: timestamp_t,
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

pub const linkcount_t = u32;

pub const lookupflags_t = u32;
pub const LOOKUP_SYMLINK_FOLLOW: lookupflags_t = 0x00000001;

pub const oflags_t = u16;
pub const O_CREAT: oflags_t = 0x0001;
pub const O_DIRECTORY: oflags_t = 0x0002;
pub const O_EXCL: oflags_t = 0x0004;
pub const O_TRUNC: oflags_t = 0x0008;

pub const preopentype_t = u8;
pub const PREOPENTYPE_DIR: preopentype_t = 0;

pub const prestat_t = extern struct {
    pr_type: preopentype_t,
    u: extern union {
        dir: extern struct {
            pr_name_len: usize,
        },
    },
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

pub const roflags_t = u16;
pub const SOCK_RECV_DATA_TRUNCATED: roflags_t = 0x0001;

pub const sdflags_t = u8;
pub const SHUT_RD: sdflags_t = 0x01;
pub const SHUT_WR: sdflags_t = 0x02;

pub const siflags_t = u16;

pub const signal_t = u8;
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
    @"type": eventtype_t,
    u: extern union {
        clock: extern struct {
            identifier: userdata_t,
            clock_id: clockid_t,
            timeout: timestamp_t,
            precision: timestamp_t,
            flags: subclockflags_t,
        },
        fd_readwrite: extern struct {
            fd: fd_t,
        },
    },
};

pub const timestamp_t = u64;
pub const time_t = i64; // match https://github.com/CraneStation/wasi-libc

pub const userdata_t = u64;

pub const whence_t = u8;
pub const WHENCE_CUR: whence_t = 0;
pub const WHENCE_END: whence_t = 1;
pub const WHENCE_SET: whence_t = 2;

pub const timespec = extern struct {
    tv_sec: time_t,
    tv_nsec: isize,
};
