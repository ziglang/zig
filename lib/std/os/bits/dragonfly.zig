// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../../std.zig");
const maxInt = std.math.maxInt;

pub fn S_ISCHR(m: u32) bool {
    return m & S_IFMT == S_IFCHR;
}

// See:
// - https://gitweb.dragonflybsd.org/dragonfly.git/blob/HEAD:/include/unistd.h
// - https://gitweb.dragonflybsd.org/dragonfly.git/blob/HEAD:/sys/sys/types.h
// TODO: mode_t should probably be changed to a u16, audit pid_t/off_t as well
pub const fd_t = c_int;
pub const pid_t = c_int;
pub const off_t = c_long;
pub const mode_t = c_uint;
pub const uid_t = u32;
pub const gid_t = u32;
pub const time_t = isize;
pub const suseconds_t = c_long;

pub const ENOTSUP = EOPNOTSUPP;
pub const EWOULDBLOCK = EAGAIN;
pub const EPERM = 1;
pub const ENOENT = 2;
pub const ESRCH = 3;
pub const EINTR = 4;
pub const EIO = 5;
pub const ENXIO = 6;
pub const E2BIG = 7;
pub const ENOEXEC = 8;
pub const EBADF = 9;
pub const ECHILD = 10;
pub const EDEADLK = 11;
pub const ENOMEM = 12;
pub const EACCES = 13;
pub const EFAULT = 14;
pub const ENOTBLK = 15;
pub const EBUSY = 16;
pub const EEXIST = 17;
pub const EXDEV = 18;
pub const ENODEV = 19;
pub const ENOTDIR = 20;
pub const EISDIR = 21;
pub const EINVAL = 22;
pub const ENFILE = 23;
pub const EMFILE = 24;
pub const ENOTTY = 25;
pub const ETXTBSY = 26;
pub const EFBIG = 27;
pub const ENOSPC = 28;
pub const ESPIPE = 29;
pub const EROFS = 30;
pub const EMLINK = 31;
pub const EPIPE = 32;
pub const EDOM = 33;
pub const ERANGE = 34;
pub const EAGAIN = 35;
pub const EINPROGRESS = 36;
pub const EALREADY = 37;
pub const ENOTSOCK = 38;
pub const EDESTADDRREQ = 39;
pub const EMSGSIZE = 40;
pub const EPROTOTYPE = 41;
pub const ENOPROTOOPT = 42;
pub const EPROTONOSUPPORT = 43;
pub const ESOCKTNOSUPPORT = 44;
pub const EOPNOTSUPP = 45;
pub const EPFNOSUPPORT = 46;
pub const EAFNOSUPPORT = 47;
pub const EADDRINUSE = 48;
pub const EADDRNOTAVAIL = 49;
pub const ENETDOWN = 50;
pub const ENETUNREACH = 51;
pub const ENETRESET = 52;
pub const ECONNABORTED = 53;
pub const ECONNRESET = 54;
pub const ENOBUFS = 55;
pub const EISCONN = 56;
pub const ENOTCONN = 57;
pub const ESHUTDOWN = 58;
pub const ETOOMANYREFS = 59;
pub const ETIMEDOUT = 60;
pub const ECONNREFUSED = 61;
pub const ELOOP = 62;
pub const ENAMETOOLONG = 63;
pub const EHOSTDOWN = 64;
pub const EHOSTUNREACH = 65;
pub const ENOTEMPTY = 66;
pub const EPROCLIM = 67;
pub const EUSERS = 68;
pub const EDQUOT = 69;
pub const ESTALE = 70;
pub const EREMOTE = 71;
pub const EBADRPC = 72;
pub const ERPCMISMATCH = 73;
pub const EPROGUNAVAIL = 74;
pub const EPROGMISMATCH = 75;
pub const EPROCUNAVAIL = 76;
pub const ENOLCK = 77;
pub const ENOSYS = 78;
pub const EFTYPE = 79;
pub const EAUTH = 80;
pub const ENEEDAUTH = 81;
pub const EIDRM = 82;
pub const ENOMSG = 83;
pub const EOVERFLOW = 84;
pub const ECANCELED = 85;
pub const EILSEQ = 86;
pub const ENOATTR = 87;
pub const EDOOFUS = 88;
pub const EBADMSG = 89;
pub const EMULTIHOP = 90;
pub const ENOLINK = 91;
pub const EPROTO = 92;
pub const ENOMEDIUM = 93;
pub const ELAST = 99;
pub const EASYNC = 99;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const PROT_NONE = 0;
pub const PROT_READ = 1;
pub const PROT_WRITE = 2;
pub const PROT_EXEC = 4;

pub const MAP_FILE = 0;
pub const MAP_FAILED = @intToPtr(*c_void, maxInt(usize));
pub const MAP_ANONYMOUS = MAP_ANON;
pub const MAP_COPY = MAP_PRIVATE;
pub const MAP_SHARED = 1;
pub const MAP_PRIVATE = 2;
pub const MAP_FIXED = 16;
pub const MAP_RENAME = 32;
pub const MAP_NORESERVE = 64;
pub const MAP_INHERIT = 128;
pub const MAP_NOEXTEND = 256;
pub const MAP_HASSEMAPHORE = 512;
pub const MAP_STACK = 1024;
pub const MAP_NOSYNC = 2048;
pub const MAP_ANON = 4096;
pub const MAP_VPAGETABLE = 8192;
pub const MAP_TRYFIXED = 65536;
pub const MAP_NOCORE = 131072;
pub const MAP_SIZEALIGN = 262144;

pub const WNOHANG = 0x0001;
pub const WUNTRACED = 0x0002;
pub const WCONTINUED = 0x0004;
pub const WSTOPPED = WUNTRACED;
pub const WNOWAIT = 0x0008;
pub const WEXITED = 0x0010;
pub const WTRAPPED = 0x0020;

pub const SA_ONSTACK = 0x0001;
pub const SA_RESTART = 0x0002;
pub const SA_RESETHAND = 0x0004;
pub const SA_NODEFER = 0x0010;
pub const SA_NOCLDWAIT = 0x0020;
pub const SA_SIGINFO = 0x0040;

pub const PATH_MAX = 1024;

pub const ino_t = c_ulong;

pub const libc_stat = extern struct {
    ino: ino_t,
    nlink: c_uint,
    dev: c_uint,
    mode: c_ushort,
    padding1: u16,
    uid: uid_t,
    gid: gid_t,
    rdev: c_uint,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    size: c_ulong,
    blocks: i64,
    blksize: u32,
    flags: u32,
    gen: u32,
    lspare: i32,
    qspare1: i64,
    qspare2: i64,
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
    tv_sec: c_long,
    tv_nsec: c_long,
};

pub const timeval = extern struct {
    /// seconds
    tv_sec: time_t,
    /// microseconds
    tv_usec: suseconds_t,
};

pub const CTL_UNSPEC = 0;
pub const CTL_KERN = 1;
pub const CTL_VM = 2;
pub const CTL_VFS = 3;
pub const CTL_NET = 4;
pub const CTL_DEBUG = 5;
pub const CTL_HW = 6;
pub const CTL_MACHDEP = 7;
pub const CTL_USER = 8;
pub const CTL_LWKT = 10;
pub const CTL_MAXID = 11;
pub const CTL_MAXNAME = 12;

pub const KERN_PROC_ALL = 0;
pub const KERN_OSTYPE = 1;
pub const KERN_PROC_PID = 1;
pub const KERN_OSRELEASE = 2;
pub const KERN_PROC_PGRP = 2;
pub const KERN_OSREV = 3;
pub const KERN_PROC_SESSION = 3;
pub const KERN_VERSION = 4;
pub const KERN_PROC_TTY = 4;
pub const KERN_MAXVNODES = 5;
pub const KERN_PROC_UID = 5;
pub const KERN_MAXPROC = 6;
pub const KERN_PROC_RUID = 6;
pub const KERN_MAXFILES = 7;
pub const KERN_PROC_ARGS = 7;
pub const KERN_ARGMAX = 8;
pub const KERN_PROC_CWD = 8;
pub const KERN_PROC_PATHNAME = 9;
pub const KERN_SECURELVL = 9;
pub const KERN_PROC_SIGTRAMP = 10;
pub const KERN_HOSTNAME = 10;
pub const KERN_HOSTID = 11;
pub const KERN_CLOCKRATE = 12;
pub const KERN_VNODE = 13;
pub const KERN_PROC = 14;
pub const KERN_FILE = 15;
pub const KERN_PROC_FLAGMASK = 16;
pub const KERN_PROF = 16;
pub const KERN_PROC_FLAG_LWP = 16;
pub const KERN_POSIX1 = 17;
pub const KERN_NGROUPS = 18;
pub const KERN_JOB_CONTROL = 19;
pub const KERN_SAVED_IDS = 20;
pub const KERN_BOOTTIME = 21;
pub const KERN_NISDOMAINNAME = 22;
pub const KERN_UPDATEINTERVAL = 23;
pub const KERN_OSRELDATE = 24;
pub const KERN_NTP_PLL = 25;
pub const KERN_BOOTFILE = 26;
pub const KERN_MAXFILESPERPROC = 27;
pub const KERN_MAXPROCPERUID = 28;
pub const KERN_DUMPDEV = 29;
pub const KERN_IPC = 30;
pub const KERN_DUMMY = 31;
pub const KERN_PS_STRINGS = 32;
pub const KERN_USRSTACK = 33;
pub const KERN_LOGSIGEXIT = 34;
pub const KERN_IOV_MAX = 35;
pub const KERN_MAXPOSIXLOCKSPERUID = 36;
pub const KERN_MAXID = 37;

pub const HOST_NAME_MAX = 255;

// access function
pub const F_OK = 0; // test for existence of file
pub const X_OK = 1; // test for execute or search permission
pub const W_OK = 2; // test for write permission
pub const R_OK = 4; // test for read permission

pub const O_RDONLY = 0;
pub const O_NDELAY = O_NONBLOCK;
pub const O_WRONLY = 1;
pub const O_RDWR = 2;
pub const O_ACCMODE = 3;
pub const O_NONBLOCK = 4;
pub const O_APPEND = 8;
pub const O_SHLOCK = 16;
pub const O_EXLOCK = 32;
pub const O_ASYNC = 64;
pub const O_FSYNC = 128;
pub const O_SYNC = 128;
pub const O_NOFOLLOW = 256;
pub const O_CREAT = 512;
pub const O_TRUNC = 1024;
pub const O_EXCL = 2048;
pub const O_NOCTTY = 32768;
pub const O_DIRECT = 65536;
pub const O_CLOEXEC = 131072;
pub const O_FBLOCKING = 262144;
pub const O_FNONBLOCKING = 524288;
pub const O_FAPPEND = 1048576;
pub const O_FOFFSET = 2097152;
pub const O_FSYNCWRITE = 4194304;
pub const O_FASYNCWRITE = 8388608;
pub const O_DIRECTORY = 134217728;

pub const SEEK_SET = 0;
pub const SEEK_CUR = 1;
pub const SEEK_END = 2;
pub const SEEK_DATA = 3;
pub const SEEK_HOLE = 4;

pub const F_ULOCK = 0;
pub const F_LOCK = 1;
pub const F_TLOCK = 2;
pub const F_TEST = 3;

pub const FD_CLOEXEC = 1;

pub const AT_FDCWD = -328243;
pub const AT_SYMLINK_NOFOLLOW = 1;
pub const AT_REMOVEDIR = 2;
pub const AT_EACCESS = 4;
pub const AT_SYMLINK_FOLLOW = 8;

pub fn WEXITSTATUS(s: u32) u8 {
    return @intCast(u8, (s & 0xff00) >> 8);
}
pub fn WTERMSIG(s: u32) u32 {
    return s & 0x7f;
}
pub fn WSTOPSIG(s: u32) u32 {
    return WEXITSTATUS(s);
}
pub fn WIFEXITED(s: u32) bool {
    return WTERMSIG(s) == 0;
}
pub fn WIFSTOPPED(s: u32) bool {
    return @intCast(u16, (((s & 0xffff) *% 0x10001) >> 8)) > 0x7f00;
}
pub fn WIFSIGNALED(s: u32) bool {
    return (s & 0xffff) -% 1 < 0xff;
}

pub const dirent = extern struct {
    d_fileno: c_ulong,
    d_namlen: u16,
    d_type: u8,
    d_unused1: u8,
    d_unused2: u32,
    d_name: [256]u8,

    pub fn reclen(self: dirent) u16 {
        return (@offsetOf(dirent, "d_name") + self.d_namlen + 1 + 7) & ~@as(u16, 7);
    }
};

pub const DT_UNKNOWN = 0;
pub const DT_FIFO = 1;
pub const DT_CHR = 2;
pub const DT_DIR = 4;
pub const DT_BLK = 6;
pub const DT_REG = 8;
pub const DT_LNK = 10;
pub const DT_SOCK = 12;
pub const DT_WHT = 14;
pub const DT_DBF = 15;

pub const CLOCK_REALTIME = 0;
pub const CLOCK_VIRTUAL = 1;
pub const CLOCK_PROF = 2;
pub const CLOCK_MONOTONIC = 4;
pub const CLOCK_UPTIME = 5;
pub const CLOCK_UPTIME_PRECISE = 7;
pub const CLOCK_UPTIME_FAST = 8;
pub const CLOCK_REALTIME_PRECISE = 9;
pub const CLOCK_REALTIME_FAST = 10;
pub const CLOCK_MONOTONIC_PRECISE = 11;
pub const CLOCK_MONOTONIC_FAST = 12;
pub const CLOCK_SECOND = 13;
pub const CLOCK_THREAD_CPUTIME_ID = 14;
pub const CLOCK_PROCESS_CPUTIME_ID = 15;

pub const sockaddr = extern struct {
    len: u8,
    family: u8,
    data: [14]u8,
};

pub const sockaddr_storage = std.x.os.Socket.Address.Native.Storage;

pub const Kevent = extern struct {
    ident: usize,
    filter: c_short,
    flags: c_ushort,
    fflags: c_uint,
    data: isize,
    udata: usize,
};

pub const EVFILT_FS = -10;
pub const EVFILT_USER = -9;
pub const EVFILT_EXCEPT = -8;
pub const EVFILT_TIMER = -7;
pub const EVFILT_SIGNAL = -6;
pub const EVFILT_PROC = -5;
pub const EVFILT_VNODE = -4;
pub const EVFILT_AIO = -3;
pub const EVFILT_WRITE = -2;
pub const EVFILT_READ = -1;
pub const EVFILT_SYSCOUNT = 10;
pub const EVFILT_MARKER = 15;

pub const EV_ADD = 1;
pub const EV_DELETE = 2;
pub const EV_ENABLE = 4;
pub const EV_DISABLE = 8;
pub const EV_ONESHOT = 16;
pub const EV_CLEAR = 32;
pub const EV_RECEIPT = 64;
pub const EV_DISPATCH = 128;
pub const EV_NODATA = 4096;
pub const EV_FLAG1 = 8192;
pub const EV_ERROR = 16384;
pub const EV_EOF = 32768;
pub const EV_SYSFLAGS = 61440;

pub const NOTE_FFNOP = 0;
pub const NOTE_TRACK = 1;
pub const NOTE_DELETE = 1;
pub const NOTE_LOWAT = 1;
pub const NOTE_TRACKERR = 2;
pub const NOTE_OOB = 2;
pub const NOTE_WRITE = 2;
pub const NOTE_EXTEND = 4;
pub const NOTE_CHILD = 4;
pub const NOTE_ATTRIB = 8;
pub const NOTE_LINK = 16;
pub const NOTE_RENAME = 32;
pub const NOTE_REVOKE = 64;
pub const NOTE_PDATAMASK = 1048575;
pub const NOTE_FFLAGSMASK = 16777215;
pub const NOTE_TRIGGER = 16777216;
pub const NOTE_EXEC = 536870912;
pub const NOTE_FFAND = 1073741824;
pub const NOTE_FORK = 1073741824;
pub const NOTE_EXIT = 2147483648;
pub const NOTE_FFOR = 2147483648;
pub const NOTE_FFCTRLMASK = 3221225472;
pub const NOTE_FFCOPY = 3221225472;
pub const NOTE_PCTRLMASK = 4026531840;

pub const stack_t = extern struct {
    ss_sp: [*]u8,
    ss_size: isize,
    ss_flags: i32,
};

pub const S_IREAD = S_IRUSR;
pub const S_IEXEC = S_IXUSR;
pub const S_IWRITE = S_IWUSR;
pub const S_IXOTH = 1;
pub const S_IWOTH = 2;
pub const S_IROTH = 4;
pub const S_IRWXO = 7;
pub const S_IXGRP = 8;
pub const S_IWGRP = 16;
pub const S_IRGRP = 32;
pub const S_IRWXG = 56;
pub const S_IXUSR = 64;
pub const S_IWUSR = 128;
pub const S_IRUSR = 256;
pub const S_IRWXU = 448;
pub const S_ISTXT = 512;
pub const S_BLKSIZE = 512;
pub const S_ISVTX = 512;
pub const S_ISGID = 1024;
pub const S_ISUID = 2048;
pub const S_IFIFO = 4096;
pub const S_IFCHR = 8192;
pub const S_IFDIR = 16384;
pub const S_IFBLK = 24576;
pub const S_IFREG = 32768;
pub const S_IFDB = 36864;
pub const S_IFLNK = 40960;
pub const S_IFSOCK = 49152;
pub const S_IFWHT = 57344;
pub const S_IFMT = 61440;

pub const SIG_DFL = @intToPtr(?Sigaction.sigaction_fn, 0);
pub const SIG_IGN = @intToPtr(?Sigaction.sigaction_fn, 1);
pub const SIG_ERR = @intToPtr(?Sigaction.sigaction_fn, maxInt(usize));
pub const BADSIG = SIG_ERR;

pub const SIG_BLOCK = 1;
pub const SIG_UNBLOCK = 2;
pub const SIG_SETMASK = 3;

pub const SIGIOT = SIGABRT;
pub const SIGHUP = 1;
pub const SIGINT = 2;
pub const SIGQUIT = 3;
pub const SIGILL = 4;
pub const SIGTRAP = 5;
pub const SIGABRT = 6;
pub const SIGEMT = 7;
pub const SIGFPE = 8;
pub const SIGKILL = 9;
pub const SIGBUS = 10;
pub const SIGSEGV = 11;
pub const SIGSYS = 12;
pub const SIGPIPE = 13;
pub const SIGALRM = 14;
pub const SIGTERM = 15;
pub const SIGURG = 16;
pub const SIGSTOP = 17;
pub const SIGTSTP = 18;
pub const SIGCONT = 19;
pub const SIGCHLD = 20;
pub const SIGTTIN = 21;
pub const SIGTTOU = 22;
pub const SIGIO = 23;
pub const SIGXCPU = 24;
pub const SIGXFSZ = 25;
pub const SIGVTALRM = 26;
pub const SIGPROF = 27;
pub const SIGWINCH = 28;
pub const SIGINFO = 29;
pub const SIGUSR1 = 30;
pub const SIGUSR2 = 31;
pub const SIGTHR = 32;
pub const SIGCKPT = 33;
pub const SIGCKPTEXIT = 34;

pub const siginfo_t = extern struct {
    signo: c_int,
    errno: c_int,
    code: c_int,
    pid: c_int,
    uid: uid_t,
    status: c_int,
    addr: ?*c_void,
    value: sigval,
    band: c_long,
    __spare__: [7]c_int,
};

pub const sigval = extern union {
    sival_int: c_int,
    sival_ptr: ?*c_void,
};

pub const _SIG_WORDS = 4;

pub const sigset_t = extern struct {
    __bits: [_SIG_WORDS]c_uint,
};

pub const empty_sigset = sigset_t{ .__bits = [_]c_uint{0} ** _SIG_WORDS };

pub const sig_atomic_t = c_int;

pub const Sigaction = extern struct {
    pub const handler_fn = fn (c_int) callconv(.C) void;
    pub const sigaction_fn = fn (c_int, *const siginfo_t, ?*const c_void) callconv(.C) void;

    /// signal handler
    handler: extern union {
        handler: ?handler_fn,
        sigaction: ?sigaction_fn,
    },
    flags: c_uint,
    mask: sigset_t,
};

pub const sig_t = [*c]fn (c_int) callconv(.C) void;

pub const SOCK_STREAM = 1;
pub const SOCK_DGRAM = 2;
pub const SOCK_RAW = 3;
pub const SOCK_RDM = 4;
pub const SOCK_SEQPACKET = 5;
pub const SOCK_MAXADDRLEN = 255;
pub const SOCK_CLOEXEC = 0x10000000;
pub const SOCK_NONBLOCK = 0x20000000;

pub const SO_DEBUG = 0x0001;
pub const SO_ACCEPTCONN = 0x0002;
pub const SO_REUSEADDR = 0x0004;
pub const SO_KEEPALIVE = 0x0008;
pub const SO_DONTROUTE = 0x0010;
pub const SO_BROADCAST = 0x0020;
pub const SO_USELOOPBACK = 0x0040;
pub const SO_LINGER = 0x0080;
pub const SO_OOBINLINE = 0x0100;
pub const SO_REUSEPORT = 0x0200;
pub const SO_TIMESTAMP = 0x0400;
pub const SO_NOSIGPIPE = 0x0800;
pub const SO_ACCEPTFILTER = 0x1000;
pub const SO_RERROR = 0x2000;
pub const SO_PASSCRED = 0x4000;

pub const SO_SNDBUF = 0x1001;
pub const SO_RCVBUF = 0x1002;
pub const SO_SNDLOWAT = 0x1003;
pub const SO_RCVLOWAT = 0x1004;
pub const SO_SNDTIMEO = 0x1005;
pub const SO_RCVTIMEO = 0x1006;
pub const SO_ERROR = 0x1007;
pub const SO_TYPE = 0x1008;
pub const SO_SNDSPACE = 0x100a;
pub const SO_CPUHINT = 0x1030;

pub const SOL_SOCKET = 0xffff;

pub const PF_INET6 = AF_INET6;
pub const PF_IMPLINK = AF_IMPLINK;
pub const PF_ROUTE = AF_ROUTE;
pub const PF_ISO = AF_ISO;
pub const PF_PIP = pseudo_AF_PIP;
pub const PF_CHAOS = AF_CHAOS;
pub const PF_DATAKIT = AF_DATAKIT;
pub const PF_INET = AF_INET;
pub const PF_APPLETALK = AF_APPLETALK;
pub const PF_SIP = AF_SIP;
pub const PF_OSI = AF_ISO;
pub const PF_CNT = AF_CNT;
pub const PF_LINK = AF_LINK;
pub const PF_HYLINK = AF_HYLINK;
pub const PF_MAX = AF_MAX;
pub const PF_KEY = pseudo_AF_KEY;
pub const PF_PUP = AF_PUP;
pub const PF_COIP = AF_COIP;
pub const PF_SNA = AF_SNA;
pub const PF_LOCAL = AF_LOCAL;
pub const PF_NETBIOS = AF_NETBIOS;
pub const PF_NATM = AF_NATM;
pub const PF_BLUETOOTH = AF_BLUETOOTH;
pub const PF_UNSPEC = AF_UNSPEC;
pub const PF_NETGRAPH = AF_NETGRAPH;
pub const PF_ECMA = AF_ECMA;
pub const PF_IPX = AF_IPX;
pub const PF_DLI = AF_DLI;
pub const PF_ATM = AF_ATM;
pub const PF_CCITT = AF_CCITT;
pub const PF_ISDN = AF_ISDN;
pub const PF_RTIP = pseudo_AF_RTIP;
pub const PF_LAT = AF_LAT;
pub const PF_UNIX = PF_LOCAL;
pub const PF_XTP = pseudo_AF_XTP;
pub const PF_DECnet = AF_DECnet;

pub const AF_UNSPEC = 0;
pub const AF_OSI = AF_ISO;
pub const AF_UNIX = AF_LOCAL;
pub const AF_LOCAL = 1;
pub const AF_INET = 2;
pub const AF_IMPLINK = 3;
pub const AF_PUP = 4;
pub const AF_CHAOS = 5;
pub const AF_NETBIOS = 6;
pub const AF_ISO = 7;
pub const AF_ECMA = 8;
pub const AF_DATAKIT = 9;
pub const AF_CCITT = 10;
pub const AF_SNA = 11;
pub const AF_DLI = 13;
pub const AF_LAT = 14;
pub const AF_HYLINK = 15;
pub const AF_APPLETALK = 16;
pub const AF_ROUTE = 17;
pub const AF_LINK = 18;
pub const AF_COIP = 20;
pub const AF_CNT = 21;
pub const AF_IPX = 23;
pub const AF_SIP = 24;
pub const AF_ISDN = 26;
pub const AF_INET6 = 28;
pub const AF_NATM = 29;
pub const AF_ATM = 30;
pub const AF_NETGRAPH = 32;
pub const AF_BLUETOOTH = 33;
pub const AF_MPLS = 34;
pub const AF_MAX = 36;

pub const in_port_t = u16;
pub const sa_family_t = u8;
pub const socklen_t = u32;

pub const sockaddr_in = extern struct {
    len: u8 = @sizeOf(sockaddr_in),
    family: sa_family_t = AF_INET,
    port: in_port_t,
    addr: u32,
    zero: [8]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
};

pub const sockaddr_in6 = extern struct {
    len: u8 = @sizeOf(sockaddr_in6),
    family: sa_family_t = AF_INET6,
    port: in_port_t,
    flowinfo: u32,
    addr: [16]u8,
    scope_id: u32,
};

pub const EAI = enum(c_int) {
    ADDRFAMILY = 1,
    AGAIN = 2,
    BADFLAGS = 3,
    FAIL = 4,
    FAMILY = 5,
    MEMORY = 6,
    NODATA = 7,
    NONAME = 8,
    SERVICE = 9,
    SOCKTYPE = 10,
    SYSTEM = 11,
    BADHINTS = 12,
    PROTOCOL = 13,
    OVERFLOW = 14,
    _,
};

pub const AI_PASSIVE = 0x00000001;
pub const AI_CANONNAME = 0x00000002;
pub const AI_NUMERICHOST = 0x00000004;
pub const AI_NUMERICSERV = 0x00000008;
pub const AI_MASK = AI_PASSIVE | AI_CANONNAME | AI_NUMERICHOST | AI_NUMERICSERV | AI_ADDRCONFIG;
pub const AI_ALL = 0x00000100;
pub const AI_V4MAPPED_CFG = 0x00000200;
pub const AI_ADDRCONFIG = 0x00000400;
pub const AI_V4MAPPED = 0x00000800;
pub const AI_DEFAULT = AI_V4MAPPED_CFG | AI_ADDRCONFIG;

pub const RTLD_LAZY = 1;
pub const RTLD_NOW = 2;
pub const RTLD_MODEMASK = 0x3;
pub const RTLD_GLOBAL = 0x100;
pub const RTLD_LOCAL = 0;
pub const RTLD_TRACE = 0x200;
pub const RTLD_NODELETE = 0x01000;
pub const RTLD_NOLOAD = 0x02000;

pub const RTLD_NEXT = @intToPtr(*c_void, @bitCast(usize, @as(isize, -1)));
pub const RTLD_DEFAULT = @intToPtr(*c_void, @bitCast(usize, @as(isize, -2)));
pub const RTLD_SELF = @intToPtr(*c_void, @bitCast(usize, @as(isize, -3)));
pub const RTLD_ALL = @intToPtr(*c_void, @bitCast(usize, @as(isize, -4)));

pub const dl_phdr_info = extern struct {
    dlpi_addr: usize,
    dlpi_name: ?[*:0]const u8,
    dlpi_phdr: [*]std.elf.Phdr,
    dlpi_phnum: u16,
};
pub const cmsghdr = extern struct {
    cmsg_len: socklen_t,
    cmsg_level: c_int,
    cmsg_type: c_int,
};
pub const msghdr = extern struct {
    msg_name: ?*c_void,
    msg_namelen: socklen_t,
    msg_iov: [*c]iovec,
    msg_iovlen: c_int,
    msg_control: ?*c_void,
    msg_controllen: socklen_t,
    msg_flags: c_int,
};
pub const cmsgcred = extern struct {
    cmcred_pid: pid_t,
    cmcred_uid: uid_t,
    cmcred_euid: uid_t,
    cmcred_gid: gid_t,
    cmcred_ngroups: c_short,
    cmcred_groups: [16]gid_t,
};
pub const sf_hdtr = extern struct {
    headers: [*c]iovec,
    hdr_cnt: c_int,
    trailers: [*c]iovec,
    trl_cnt: c_int,
};

pub const MS_SYNC = 0;
pub const MS_ASYNC = 1;
pub const MS_INVALIDATE = 2;

pub const POSIX_MADV_SEQUENTIAL = 2;
pub const POSIX_MADV_RANDOM = 1;
pub const POSIX_MADV_DONTNEED = 4;
pub const POSIX_MADV_NORMAL = 0;
pub const POSIX_MADV_WILLNEED = 3;

pub const MADV_SEQUENTIAL = 2;
pub const MADV_CONTROL_END = MADV_SETMAP;
pub const MADV_DONTNEED = 4;
pub const MADV_RANDOM = 1;
pub const MADV_WILLNEED = 3;
pub const MADV_NORMAL = 0;
pub const MADV_CONTROL_START = MADV_INVAL;
pub const MADV_FREE = 5;
pub const MADV_NOSYNC = 6;
pub const MADV_AUTOSYNC = 7;
pub const MADV_NOCORE = 8;
pub const MADV_CORE = 9;
pub const MADV_INVAL = 10;
pub const MADV_SETMAP = 11;

pub const F_DUPFD = 0;
pub const F_GETFD = 1;
pub const F_RDLCK = 1;
pub const F_SETFD = 2;
pub const F_UNLCK = 2;
pub const F_WRLCK = 3;
pub const F_GETFL = 3;
pub const F_SETFL = 4;
pub const F_GETOWN = 5;
pub const F_SETOWN = 6;
pub const F_GETLK = 7;
pub const F_SETLK = 8;
pub const F_SETLKW = 9;
pub const F_DUP2FD = 10;
pub const F_DUPFD_CLOEXEC = 17;
pub const F_DUP2FD_CLOEXEC = 18;

pub const LOCK_SH = 1;
pub const LOCK_EX = 2;
pub const LOCK_UN = 8;
pub const LOCK_NB = 4;

pub const Flock = extern struct {
    l_start: off_t,
    l_len: off_t,
    l_pid: pid_t,
    l_type: c_short,
    l_whence: c_short,
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

pub const IPPROTO_IP = 0;
pub const IPPROTO_ICMP = 1;
pub const IPPROTO_TCP = 6;
pub const IPPROTO_UDP = 17;
pub const IPPROTO_IPV6 = 41;
pub const IPPROTO_RAW = 255;
pub const IPPROTO_HOPOPTS = 0;
pub const IPPROTO_IGMP = 2;
pub const IPPROTO_GGP = 3;
pub const IPPROTO_IPV4 = 4;
pub const IPPROTO_IPIP = IPPROTO_IPV4;
pub const IPPROTO_ST = 7;
pub const IPPROTO_EGP = 8;
pub const IPPROTO_PIGP = 9;
pub const IPPROTO_RCCMON = 10;
pub const IPPROTO_NVPII = 11;
pub const IPPROTO_PUP = 12;
pub const IPPROTO_ARGUS = 13;
pub const IPPROTO_EMCON = 14;
pub const IPPROTO_XNET = 15;
pub const IPPROTO_CHAOS = 16;
pub const IPPROTO_MUX = 18;
pub const IPPROTO_MEAS = 19;
pub const IPPROTO_HMP = 20;
pub const IPPROTO_PRM = 21;
pub const IPPROTO_IDP = 22;
pub const IPPROTO_TRUNK1 = 23;
pub const IPPROTO_TRUNK2 = 24;
pub const IPPROTO_LEAF1 = 25;
pub const IPPROTO_LEAF2 = 26;
pub const IPPROTO_RDP = 27;
pub const IPPROTO_IRTP = 28;
pub const IPPROTO_TP = 29;
pub const IPPROTO_BLT = 30;
pub const IPPROTO_NSP = 31;
pub const IPPROTO_INP = 32;
pub const IPPROTO_SEP = 33;
pub const IPPROTO_3PC = 34;
pub const IPPROTO_IDPR = 35;
pub const IPPROTO_XTP = 36;
pub const IPPROTO_DDP = 37;
pub const IPPROTO_CMTP = 38;
pub const IPPROTO_TPXX = 39;
pub const IPPROTO_IL = 40;
pub const IPPROTO_SDRP = 42;
pub const IPPROTO_ROUTING = 43;
pub const IPPROTO_FRAGMENT = 44;
pub const IPPROTO_IDRP = 45;
pub const IPPROTO_RSVP = 46;
pub const IPPROTO_GRE = 47;
pub const IPPROTO_MHRP = 48;
pub const IPPROTO_BHA = 49;
pub const IPPROTO_ESP = 50;
pub const IPPROTO_AH = 51;
pub const IPPROTO_INLSP = 52;
pub const IPPROTO_SWIPE = 53;
pub const IPPROTO_NHRP = 54;
pub const IPPROTO_MOBILE = 55;
pub const IPPROTO_TLSP = 56;
pub const IPPROTO_SKIP = 57;
pub const IPPROTO_ICMPV6 = 58;
pub const IPPROTO_NONE = 59;
pub const IPPROTO_DSTOPTS = 60;
pub const IPPROTO_AHIP = 61;
pub const IPPROTO_CFTP = 62;
pub const IPPROTO_HELLO = 63;
pub const IPPROTO_SATEXPAK = 64;
pub const IPPROTO_KRYPTOLAN = 65;
pub const IPPROTO_RVD = 66;
pub const IPPROTO_IPPC = 67;
pub const IPPROTO_ADFS = 68;
pub const IPPROTO_SATMON = 69;
pub const IPPROTO_VISA = 70;
pub const IPPROTO_IPCV = 71;
pub const IPPROTO_CPNX = 72;
pub const IPPROTO_CPHB = 73;
pub const IPPROTO_WSN = 74;
pub const IPPROTO_PVP = 75;
pub const IPPROTO_BRSATMON = 76;
pub const IPPROTO_ND = 77;
pub const IPPROTO_WBMON = 78;
pub const IPPROTO_WBEXPAK = 79;
pub const IPPROTO_EON = 80;
pub const IPPROTO_VMTP = 81;
pub const IPPROTO_SVMTP = 82;
pub const IPPROTO_VINES = 83;
pub const IPPROTO_TTP = 84;
pub const IPPROTO_IGP = 85;
pub const IPPROTO_DGP = 86;
pub const IPPROTO_TCF = 87;
pub const IPPROTO_IGRP = 88;
pub const IPPROTO_OSPFIGP = 89;
pub const IPPROTO_SRPC = 90;
pub const IPPROTO_LARP = 91;
pub const IPPROTO_MTP = 92;
pub const IPPROTO_AX25 = 93;
pub const IPPROTO_IPEIP = 94;
pub const IPPROTO_MICP = 95;
pub const IPPROTO_SCCSP = 96;
pub const IPPROTO_ETHERIP = 97;
pub const IPPROTO_ENCAP = 98;
pub const IPPROTO_APES = 99;
pub const IPPROTO_GMTP = 100;
pub const IPPROTO_IPCOMP = 108;
pub const IPPROTO_PIM = 103;
pub const IPPROTO_CARP = 112;
pub const IPPROTO_PGM = 113;
pub const IPPROTO_PFSYNC = 240;
pub const IPPROTO_DIVERT = 254;
pub const IPPROTO_MAX = 256;
pub const IPPROTO_DONE = 257;
pub const IPPROTO_UNKNOWN = 258;

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
    POSIXLOCKS = 11,
    _,

    pub const AS: rlimit_resource = .VMEM;
};

pub const rlim_t = i64;

/// No limit
pub const RLIM_INFINITY: rlim_t = (1 << 63) - 1;

pub const RLIM_SAVED_MAX = RLIM_INFINITY;
pub const RLIM_SAVED_CUR = RLIM_INFINITY;

pub const rlimit = extern struct {
    /// Soft limit
    cur: rlim_t,
    /// Hard limit
    max: rlim_t,
};

pub const SHUT_RD = 0;
pub const SHUT_WR = 1;
pub const SHUT_RDWR = 2;

pub const nfds_t = u32;

pub const pollfd = extern struct {
    fd: fd_t,
    events: i16,
    revents: i16,
};

/// Requestable events.
pub const POLLIN = 0x0001;
pub const POLLPRI = 0x0002;
pub const POLLOUT = 0x0004;
pub const POLLRDNORM = 0x0040;
pub const POLLWRNORM = POLLOUT;
pub const POLLRDBAND = 0x0080;
pub const POLLWRBAND = 0x0100;

/// These events are set if they occur regardless of whether they were requested.
pub const POLLERR = 0x0008;
pub const POLLHUP = 0x0010;
pub const POLLNVAL = 0x0020;
