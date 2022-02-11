const std = @import("std");

const SerenityConstants = @import("serenity-constants.zig");

pub const PATH_MAX = SerenityConstants.PATH_MAX;

pub const fd_t = i32;
pub const dev_t = u32;
pub const ino_t = u64;
pub const mode_t = u16;
pub const uid_t = u32;
pub const gid_t = u32;
pub const nlink_t = u32;
pub const off_t = i64;
pub const blksize_t = u32;
pub const blkcnt_t = u32;
pub const pid_t = c_int;
pub const nfds_t = c_uint;
pub const time_t = i64;

pub const timespec = extern struct {
    tv_sec: time_t,
    tv_nsec: c_long,
};

pub const sem_t = extern struct {
    value: u32,
};

pub const pthread_mutex_t = extern struct {
    lock: u32 = 0,
    owner: i32 = 0,
    level: i32 = 0,
    type: i32 = SerenityConstants.__PTHREAD_MUTEX_NORMAL,
};

pub const pthread_attr_t = *anyopaque;

pub const pollfd = extern struct {
    fd: c_int,
    events: c_short,
    revents: c_short,
};

pub extern "c" fn __errno_location() *c_int;
pub const _errno = __errno_location;

pub const AT = struct {
    pub const FDCWD = SerenityConstants.AT_FDCWD;
    pub const SYMLINK_NOFOLLOW = SerenityConstants.AT_SYMLINK_NOFOLLOW;
    pub const REMOVEDIR = SerenityConstants.AT_REMOVEDIR;
};

pub const E = enum(i32) {
    SUCCESS = SerenityConstants.ESUCCESS,
    PERM = SerenityConstants.EPERM,
    NOENT = SerenityConstants.ENOENT,
    SRCH = SerenityConstants.ESRCH,
    INTR = SerenityConstants.EINTR,
    IO = SerenityConstants.EIO,
    NXIO = SerenityConstants.ENXIO,
    @"2BIG" = SerenityConstants.E2BIG,
    NOEXEC = SerenityConstants.ENOEXEC,
    BADF = SerenityConstants.EBADF,
    CHILD = SerenityConstants.ECHILD,
    AGAIN = SerenityConstants.EAGAIN,
    NOMEM = SerenityConstants.ENOMEM,
    ACCES = SerenityConstants.EACCES,
    FAULT = SerenityConstants.EFAULT,
    NOTBLK = SerenityConstants.ENOTBLK,
    BUSY = SerenityConstants.EBUSY,
    EXIST = SerenityConstants.EEXIST,
    XDEV = SerenityConstants.EXDEV,
    NODEV = SerenityConstants.ENODEV,
    NOTDIR = SerenityConstants.ENOTDIR,
    ISDIR = SerenityConstants.EISDIR,
    INVAL = SerenityConstants.EINVAL,
    NFILE = SerenityConstants.ENFILE,
    MFILE = SerenityConstants.EMFILE,
    NOTTY = SerenityConstants.ENOTTY,
    TXTBSY = SerenityConstants.ETXTBSY,
    FBIG = SerenityConstants.EFBIG,
    NOSPC = SerenityConstants.ENOSPC,
    SPIPE = SerenityConstants.ESPIPE,
    ROFS = SerenityConstants.EROFS,
    MLINK = SerenityConstants.EMLINK,
    PIPE = SerenityConstants.EPIPE,
    RANGE = SerenityConstants.ERANGE,
    NAMETOOLONG = SerenityConstants.ENAMETOOLONG,
    LOOP = SerenityConstants.ELOOP,
    OVERFLOW = SerenityConstants.EOVERFLOW,
    OPNOTSUPP = SerenityConstants.EOPNOTSUPP,
    NOSYS = SerenityConstants.ENOSYS,
    NOTIMPL = SerenityConstants.ENOTIMPL,
    AFNOSUPPORT = SerenityConstants.EAFNOSUPPORT,
    NOTSOCK = SerenityConstants.ENOTSOCK,
    ADDRINUSE = SerenityConstants.EADDRINUSE,
    NOTEMPTY = SerenityConstants.ENOTEMPTY,
    DOM = SerenityConstants.EDOM,
    CONNREFUSED = SerenityConstants.ECONNREFUSED,
    HOSTDOWN = SerenityConstants.EHOSTDOWN,
    ADDRNOTAVAIL = SerenityConstants.EADDRNOTAVAIL,
    ISCONN = SerenityConstants.EISCONN,
    CONNABORTED = SerenityConstants.ECONNABORTED,
    ALREADY = SerenityConstants.EALREADY,
    CONNRESET = SerenityConstants.ECONNRESET,
    DESTADDRREQ = SerenityConstants.EDESTADDRREQ,
    HOSTUNREACH = SerenityConstants.EHOSTUNREACH,
    ILSEQ = SerenityConstants.EILSEQ,
    MSGSIZE = SerenityConstants.EMSGSIZE,
    NETDOWN = SerenityConstants.ENETDOWN,
    NETUNREACH = SerenityConstants.ENETUNREACH,
    NETRESET = SerenityConstants.ENETRESET,
    NOBUFS = SerenityConstants.ENOBUFS,
    NOLCK = SerenityConstants.ENOLCK,
    NOMSG = SerenityConstants.ENOMSG,
    NOPROTOOPT = SerenityConstants.ENOPROTOOPT,
    NOTCONN = SerenityConstants.ENOTCONN,
    SHUTDOWN = SerenityConstants.ESHUTDOWN,
    TOOMANYREFS = SerenityConstants.ETOOMANYREFS,
    SOCKTNOSUPPORT = SerenityConstants.ESOCKTNOSUPPORT,
    PROTONOSUPPORT = SerenityConstants.EPROTONOSUPPORT,
    DEADLK = SerenityConstants.EDEADLK,
    TIMEDOUT = SerenityConstants.ETIMEDOUT,
    PROTOTYPE = SerenityConstants.EPROTOTYPE,
    INPROGRESS = SerenityConstants.EINPROGRESS,
    NOTHREAD = SerenityConstants.ENOTHREAD,
    PROTO = SerenityConstants.EPROTO,
    NOTSUP = SerenityConstants.ENOTSUP,
    PFNOSUPPORT = SerenityConstants.EPFNOSUPPORT,
    DIRINTOSELF = SerenityConstants.EDIRINTOSELF,
    DQUOT = SerenityConstants.EDQUOT,
    NOTRECOVERABLE = SerenityConstants.ENOTRECOVERABLE,
    CANCELED = SerenityConstants.ECANCELED,
    PROMISEVIOLATION = SerenityConstants.EPROMISEVIOLATION,
};

pub const Stat = struct {
    dev: dev_t,
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    size: off_t,
    blksize: blksize_t,
    blocks: blkcnt_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,

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

pub const LOCK = struct {
    pub const SH = SerenityConstants.LOCK_SH;
    pub const EX = SerenityConstants.LOCK_EX;
    pub const NB = SerenityConstants.LOCK_NB;
    pub const UN = SerenityConstants.LOCK_UN;
};

pub const STDIN_FILENO = SerenityConstants.STDIN_FILENO;
pub const STDOUT_FILENO = SerenityConstants.STDOUT_FILENO;
pub const STDERR_FILENO = SerenityConstants.STDERR_FILENO;

pub const O = struct {
    pub const RDONLY = @as(u32, SerenityConstants.O_RDONLY);
    pub const WRONLY = @as(u32, SerenityConstants.O_WRONLY);
    pub const RDWR = @as(u32, SerenityConstants.O_RDWR);
    pub const ACCMODE = @as(u32, SerenityConstants.O_ACCMODE);
    pub const EXEC = @as(u32, SerenityConstants.O_EXEC);
    pub const CREAT = @as(u32, SerenityConstants.O_CREAT);
    pub const EXCL = @as(u32, SerenityConstants.O_EXCL);
    pub const NOCTTY = @as(u32, SerenityConstants.O_NOCTTY);
    pub const TRUNC = @as(u32, SerenityConstants.O_TRUNC);
    pub const APPEND = @as(u32, SerenityConstants.O_APPEND);
    pub const NONBLOCK = @as(u32, SerenityConstants.O_NONBLOCK);
    pub const DIRECTORY = @as(u32, SerenityConstants.O_DIRECTORY);
    pub const NOFOLLOW = @as(u32, SerenityConstants.O_NOFOLLOW);
    pub const CLOEXEC = @as(u32, SerenityConstants.O_CLOEXEC);
    pub const DIRECT = @as(u32, SerenityConstants.O_DIRECT);
};

pub const R_OK = SerenityConstants.R_OK;
pub const W_OK = SerenityConstants.W_OK;
pub const X_OK = SerenityConstants.X_OK;
pub const F_OK = SerenityConstants.F_OK;

pub const S = struct {
    pub const IFMT = SerenityConstants.S_IFMT;
    pub const IFDIR = SerenityConstants.S_IFDIR;
    pub const IFCHR = SerenityConstants.S_IFCHR;
    pub const IFBLK = SerenityConstants.S_IFBLK;
    pub const IFREG = SerenityConstants.S_IFREG;
    pub const IFIFO = SerenityConstants.S_IFIFO;
    pub const IFLNK = SerenityConstants.S_IFLNK;
    pub const IFSOCK = SerenityConstants.S_IFSOCK;
    pub const ISUID = SerenityConstants.S_ISUID;
    pub const ISGID = SerenityConstants.S_ISGID;
    pub const ISVTX = SerenityConstants.S_ISVTX;
    pub const IRUSR = SerenityConstants.S_IRUSR;
    pub const IWUSR = SerenityConstants.S_IWUSR;
    pub const IXUSR = SerenityConstants.S_IXUSR;
    pub const IREAD = SerenityConstants.S_IREAD;
    pub const IWRITE = SerenityConstants.S_IWRITE;
    pub const IEXEC = SerenityConstants.S_IEXEC;
    pub const IRGRP = SerenityConstants.S_IRGRP;
    pub const IWGRP = SerenityConstants.S_IWGRP;
    pub const IXGRP = SerenityConstants.S_IXGRP;
    pub const IROTH = SerenityConstants.S_IROTH;
    pub const IWOTH = SerenityConstants.S_IWOTH;
    pub const IXOTH = SerenityConstants.S_IXOTH;

    pub fn ISDIR(m: u32) bool {
        return m & IFMT == IFDIR;
    }

    pub fn ISCHR(m: u32) bool {
        return m & IFMT == IFCHR;
    }

    pub fn ISBLK(m: u32) bool {
        return m & IFMT == IFBLK;
    }

    pub fn ISREG(m: u32) bool {
        return m & IFMT == IFREG;
    }

    pub fn ISFIFO(m: u32) bool {
        return m & IFMT == IFIFO;
    }

    pub fn ISLNK(m: u32) bool {
        return m & IFMT == IFLNK;
    }

    pub fn ISSOCK(m: u32) bool {
        return m & IFMT == IFSOCK;
    }
};

pub const POLL = struct {
    pub const IN = SerenityConstants.POLLIN;
    pub const RDNORM = SerenityConstants.POLLRDNORM;
    pub const PRI = SerenityConstants.POLLPRI;
    pub const OUT = SerenityConstants.POLLOUT;
    pub const WRNORM = SerenityConstants.POLLWRNORM;
    pub const ERR = SerenityConstants.POLLERR;
    pub const HUP = SerenityConstants.POLLHUP;
    pub const NVAL = SerenityConstants.POLLNVAL;
    pub const WRBAND = SerenityConstants.POLLWRBAND;
    pub const RDHUP = SerenityConstants.POLLRDHUP;
};

pub const SEEK = struct {
    pub const SET = SerenityConstants.SEEK_SET;
    pub const CUR = SerenityConstants.SEEK_CUR;
    pub const END = SerenityConstants.SEEK_END;
};

pub const F = struct {
    pub const DUPFD = SerenityConstants.F_DUPFD;
    pub const GETFD = SerenityConstants.F_GETFD;
    pub const SETFD = SerenityConstants.F_SETFD;
    pub const GETFL = SerenityConstants.F_GETFL;
    pub const SETFL = SerenityConstants.F_SETFL;
    pub const ISTTY = SerenityConstants.F_ISTTY;
    pub const GETLK = SerenityConstants.F_GETLK;
    pub const SETLK = SerenityConstants.F_SETLK;
    pub const SETLKW = SerenityConstants.F_SETLKW;
};

// FIXME: This value isn't defined on SerenityOS, so here's a random bogus value.
pub const IOV_MAX = 8;

pub const W = struct {
    pub const NOHANG = SerenityConstants.WNOHANG;
    pub const UNTRACED = SerenityConstants.WUNTRACED;
    pub const STOPPED = SerenityConstants.WSTOPPED;
    pub const EXITED = SerenityConstants.WEXITED;
    pub const CONTINUED = SerenityConstants.WCONTINUED;
    pub const NOWAIT = SerenityConstants.WNOWAIT;

    pub fn EXITSTATUS(s: u32) u8 {
        return @intCast(u8, (s & 0xff00) >> 8);
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
        return s & 0xff == 0x7f;
    }

    pub fn IFSIGNALED(s: u32) bool {
        return (@intCast(u8, ((s & 0x7f) + 1)) >> 1) > 0;
    }
};

pub const FD_CLOEXEC = SerenityConstants.FD_CLOEXEC;

pub const CLOCK = struct {
    pub const REALTIME = SerenityConstants.CLOCK_REALTIME;
    pub const MONOTONIC = SerenityConstants.CLOCK_MONOTONIC;
    pub const MONOTONIC_RAW = SerenityConstants.CLOCK_MONOTONIC_RAW;
    pub const REALTIME_COARSE = SerenityConstants.CLOCK_REALTIME_COARSE;
    pub const MONOTONIC_COARSE = SerenityConstants.CLOCK_MONOTONIC_COARSE;
};

pub const dirent = extern struct {
    d_ino: ino_t,
    d_off: off_t,
    d_reclen: c_ushort,
    d_type: u8,
    d_name: [256]u8,
};
pub const DIR = opaque {};

pub extern "c" fn fdopendir(fd: fd_t) *DIR;
pub extern "c" fn readdir_r(dir: *DIR, entry: *dirent, result: *?*dirent) i32;

pub extern "c" fn sysconf(sc: c_int) i64;
pub const _SC = struct {
    pub const NPROCESSORS_ONLN = SerenityConstants._SC_NPROCESSORS_ONLN;
};

pub const dl_phdr_info = extern struct {
    dlpi_addr: std.elf.Addr,
    dlpi_name: ?[*:0]const u8,
    dlpi_phdr: [*]std.elf.Phdr,
    dlpi_phnum: std.elf.Half,
};
pub const dl_iterate_phdr_callback = fn (info: *dl_phdr_info, size: usize, data: ?*anyopaque) callconv(.C) c_int;
pub extern "c" fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*anyopaque) c_int;

pub const PROT = struct {
    pub const READ = SerenityConstants.PROT_READ;
    pub const WRITE = SerenityConstants.PROT_WRITE;
    pub const EXEC = SerenityConstants.PROT_EXEC;
    pub const NONE = SerenityConstants.PROT_NONE;
};

pub const MAP = struct {
    pub const FILE = SerenityConstants.MAP_FILE;
    pub const SHARED = SerenityConstants.MAP_SHARED;
    pub const PRIVATE = SerenityConstants.MAP_PRIVATE;
    pub const FIXED = SerenityConstants.MAP_FIXED;
    pub const ANONYMOUS = SerenityConstants.MAP_ANONYMOUS;
    pub const ANON = SerenityConstants.MAP_ANON;
    pub const STACK = SerenityConstants.MAP_STACK;
    pub const NORESERVE = SerenityConstants.MAP_NORESERVE;
    pub const RANDOMIZED = SerenityConstants.MAP_RANDOMIZED;
    pub const PURGEABLE = SerenityConstants.MAP_PURGEABLE;
    pub const FIXED_NOREPLACE = SerenityConstants.MAP_FIXED_NOREPLACE;
    pub const FAILED = SerenityConstants.MAP_FAILED;
};
