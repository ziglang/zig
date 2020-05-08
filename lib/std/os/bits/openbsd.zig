const std = @import("../../std.zig");
const maxInt = std.math.maxInt;

// Extracted from sys/sys/_types.h
pub const blkcnt_t = i64;
pub const blksize_t = i32;
pub const clock_t = i64;
pub const clockid_t = i32;
pub const cpuid_t = c_ulong;
pub const dev_t = i32;
pub const fixpt_t = u32;
pub const fsblkcnt_t = u64;
pub const fsfilcnt_t = u64;
pub const gid_t = u32;
pub const id_t = u32;
pub const in_addr_t = u32;
pub const in_port_t = u16;
pub const ino_t = u64;
pub const key_t = c_long;
pub const mode_t = u32;
pub const nlink_t = u32;
pub const off_t = i64;
pub const pid_t = i32;
pub const rlim_t = u64;
pub const sa_family_t = u8;
pub const segsz_t = i32;
pub const socklen_t = u32;
pub const suseconds_t = c_long;
pub const swblk_t = i32;
pub const time_t = i64;
pub const timer_t = i32;
pub const uid_t = u32;
pub const useconds_t = u32;

// Extracted from sys/sys/event.h
/// Renamed from `kevent` to `Kevent` to avoid conflict with function name.
pub const Kevent = extern struct {
    ident: usize,
    filter: c_short,
    flags: c_ushort,
    fflags: c_uint,
    data: i64,
    udata: ?*c_void,
};

// Extracted from include/dlfcn.h
pub const RTLD_LAZY = 1;
pub const RTLD_NOW = 2;
pub const RTLD_GLOBAL = 0x100;
pub const RTLD_LOCAL = 0x000;
pub const RTLD_TRACE = 0x200;

// Extracted from include/link_elf.h
pub const dl_phdr_info = extern struct {
    dlpi_addr: usize,
    dlpi_name: ?[*:0]const u8,
    dlpi_phdr: [*]std.elf.Phdr,
    dlpi_phnum: u16,
};

// Extracted from sys/sys/fcntl.h
/// Renamed from `flock` to `Flock` to avoid conflict with function name.
pub const Flock = extern struct {
    l_start: off_t,
    l_len: off_t,
    l_pid: pid_t,
    l_type: c_short,
    l_whence: c_short,
};

// Extracted from sys/sys/socket.h
pub const msghdr = extern struct {
    msg_name: ?*c_void,
    msg_namelen: socklen_t,
    msg_iov: [*]iovec,
    msg_iovlen: c_uint,
    msg_control: ?*c_void,
    msg_controllen: socklen_t,
    msg_flags: c_int,
};

pub const cmsghdr = extern struct {
    cmsg_len: socklen_t,
    cmsg_level: c_int,
    cmsg_type: c_int,
};

// Extract from sys/sys/mman.h
pub const MS_ASYNC = 0x01;
pub const MS_SYNC = 0x02;
pub const MS_INVALIDATE = 0x04;

pub const POSIX_MADV_NORMAL = 0;
pub const POSIX_MADV_RANDOM = 1;
pub const POSIX_MADV_SEQUENTIAL = 2;
pub const POSIX_MADV_WILLNEED = 3;
pub const POSIX_MADV_DONTNEED = 4;

pub const MADV_NORMAL = POSIX_MADV_NORMAL;
pub const MADV_RANDOM = POSIX_MADV_RANDOM;
pub const MADV_SEQUENTIAL = POSIX_MADV_SEQUENTIAL;
pub const MADV_WILLNEED = POSIX_MADV_WILLNEED;
pub const MADV_DONTNEED = POSIX_MADV_DONTNEED;
pub const MADV_SPACEAVAIL = 5;
pub const MADV_FREE = 6;

// Extracted from include/time.h
pub const timespec = extern struct {
    tv_sec: time_t,
    tv_nsec: c_long,
};

// Extracted from sys/sys/stat.h
/// Renamed from `stat` to `Stat` to avoid conflict with function name.
pub const Stat = extern struct {
    mode: mode_t,
    dev: dev_t,
    ino: ino_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,

    size: off_t,
    blocks: blkcnt_t,
    blksize: blksize_t,
    flags: u32,
    gen: u32,

    birthtim: timespec,

    pub fn atime(self: Stat) timespec {
        return self.atim;
    }

    pub fn mtime(self: Stat) timespec {
        return self.mtim;
    }

    pub fn ctime(self: Stat) timespec {
        return self.ctim;
    }
};

// Extracted from sys/sys/dirent.h
const MAXNAMLEN = 255;

pub const dirent = extern struct {
    d_fileno: ino_t,
    d_off: off_t,
    d_reclen: u16,
    d_type: u8,
    d_namlen: u8,
    d_padding: [4]u8,
    d_name: [MAXNAMLEN + 1]u8,

    pub fn reclen(self: dirent) u16 {
        return self.d_reclen;
    }
};

// Extracted from sys/sys/socket.h
pub const sockaddr = extern struct {
    len: u8,
    family: sa_family_t,
    data: [14]u8,
};

// Extracted from sys/netinet/in.h
const in_addr = extern struct {
    s_addr: in_addr_t,
};

pub const sockaddr_in = extern struct {
    len: u8,
    family: sa_family_t,
    port: in_port_t,
    addr: in_addr,
    zero: [8]i8,
};

// Extracted from sys/netinet6/in6.h
const in6_addr = extern struct {
    u6_addr: extern union {
        u6_addr8: [16]u8,
        u6_addr16: [8]u16,
        u6_addr32: [4]u32,
    },
};

pub const sockaddr_in6 = extern struct {
    len: u8,
    family: sa_family_t,
    port: in_port_t,
    flowinfo: u32,
    addr: in6_addr,
    scope_id: u32,
};

// Extracted from sys/sys/un.h
pub const sockaddr_un = extern struct {
    len: u8,
    family: sa_family_t,
    path: [104]u8,
};

// Extracted from include/netdb.h
pub const AI_PASSIVE = 1;
pub const AI_CANONNAME = 2;
pub const AI_NUMERICHOST = 4;
pub const AI_EXT = 8;
pub const AI_NUMERICSERV = 16;
pub const AI_FQDN = 32;
pub const AI_ADDRCONFIG = 64;

// Extracted from sys/sys/sysctl.h
pub const CTL_UNSPEC = 0;
pub const CTL_KERN = 1;
pub const CTL_VM = 2;
pub const CTL_FS = 3;
pub const CTL_NET = 4;
pub const CTL_DEBUG = 5;
pub const CTL_HW = 6;
pub const CTL_MACHDEP = 7;
pub const CTL_DDB = 9;
pub const CTL_VFS = 10;
pub const CTL_MAXID = 11;

pub const KERN_OSTYPE = 1;
pub const KERN_OSRELEASE = 2;
pub const KERN_OSREV = 3;
pub const KERN_VERSION = 4;
pub const KERN_MAXVNODES = 5;
pub const KERN_MAXPROC = 6;
pub const KERN_MAXFILES = 7;
pub const KERN_ARGMAX = 8;
pub const KERN_SECURELVL = 9;
pub const KERN_HOSTNAME = 10;
pub const KERN_HOSTID = 11;
pub const KERN_CLOCKRATE = 12;
pub const KERN_PROF = 16;
pub const KERN_POSIX1 = 17;
pub const KERN_NGROUPS = 18;
pub const KERN_JOB_CONTROL = 19;
pub const KERN_SAVED_IDS = 20;
pub const KERN_BOOTTIME = 21;
pub const KERN_DOMAINNAME = 22;
pub const KERN_MAXPARTITIONS = 23;
pub const KERN_RAWPARTITION = 24;
pub const KERN_MAXTHREAD = 25;
pub const KERN_NTHREADS = 26;
pub const KERN_OSVERSION = 27;
pub const KERN_SOMAXCONN = 28;
pub const KERN_SOMINCONN = 29;
pub const KERN_NOSUIDCOREDUMP = 32;
pub const KERN_FSYNC = 33;
pub const KERN_SYSVMSG = 34;
pub const KERN_SYSVSEM = 35;
pub const KERN_SYSVSHM = 36;
pub const KERN_MSGBUFSIZE = 38;
pub const KERN_MALLOCSTATS = 39;
pub const KERN_CPTIME = 40;
pub const KERN_NCHSTATS = 41;
pub const KERN_FORKSTAT = 42;
pub const KERN_NSELCOLL = 43;
pub const KERN_TTY = 44;
pub const KERN_CCPU = 45;
pub const KERN_FSCALE = 46;
pub const KERN_NPROCS = 47;
pub const KERN_MSGBUF = 48;
pub const KERN_POOL = 49;
pub const KERN_STACKGAPRANDOM = 50;
pub const KERN_SYSVIPC_INFO = 51;
pub const KERN_ALLOWKMEM = 52;
pub const KERN_WITNESSWATCH = 53;
pub const KERN_SPLASSERT = 54;
pub const KERN_PROC_ARGS = 55;
pub const KERN_NFILES = 56;
pub const KERN_TTYCOUNT = 57;
pub const KERN_NUMVNODES = 58;
pub const KERN_MBSTAT = 59;
pub const KERN_WITNESS = 60;
pub const KERN_SEMINFO = 61;
pub const KERN_SHMINFO = 62;
pub const KERN_INTRCNT = 63;
pub const KERN_WATCHDOG = 64;
pub const KERN_ALLOWDT = 65;
pub const KERN_PROC = 66;
pub const KERN_MAXCLUSTERS = 67;
pub const KERN_EVCOUNT = 68;
pub const KERN_TIMECOUNTER = 69;
pub const KERN_MAXLOCKSPERUID = 70;
pub const KERN_CPTIME2 = 71;
pub const KERN_CACHEPCT = 72;
pub const KERN_FILE = 73;
pub const KERN_WXABORT = 74;
pub const KERN_CONSDEV = 75;
pub const KERN_NETLIVELOCKS = 76;
pub const KERN_POOL_DEBUG = 77;
pub const KERN_PROC_CWD = 78;
pub const KERN_PROC_NOBROADCASTKILL = 79;
pub const KERN_PROC_VMMAP = 80;
pub const KERN_GLOBAL_PTRACE = 81;
pub const KERN_CONSBUFSIZE = 82;
pub const KERN_CONSBUF = 83;
pub const KERN_AUDIO = 84;
pub const KERN_CPUSTATS = 85;
pub const KERN_PFSTATUS = 86;
pub const KERN_TIMEOUT_STATS = 87;
pub const KERN_UTC_OFFSET = 88;
pub const KERN_MAXID = 89;

pub const KERN_PROC_ARGV = 1;
pub const KERN_PROC_NARGV = 2;
pub const KERN_PROC_ENV = 3;
pub const KERN_PROC_NENV = 4;

// Extracted from include/unistd.h
pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

// Extracted from sys/sys/mman.h
pub const PROT_NONE = 0x00;
pub const PROT_READ = 0x01;
pub const PROT_WRITE = 0x02;
pub const PROT_EXEC = 0x04;

// Extracted from sys/sys/_time.h
pub const CLOCK_REALTIME = 0;
pub const CLOCK_PROCESS_CPUTIME_ID = 2;
pub const CLOCK_MONOTONIC = 3;
pub const CLOCK_THREAD_CPUTIME_ID = 4;
pub const CLOCK_UPTIME = 5;
pub const CLOCK_BOOTTIME = 6;

// Extracted from sys/sys/mman.h
pub const MAP_SHARED = 0x0001;
pub const MAP_PRIVATE = 0x0002;

pub const MAP_FIXED = 0x0010;
pub const MAP_NOREPLACE = 0x0800;
pub const MAP_ANON = 0x1000;
pub const MAP_ANONYMOUS = MAP_ANON;
pub const MAP_NOFAULT = 0x2000;
pub const MAP_STACK = 0x4000;
pub const MAP_CONCEAL = 0x8000;

pub const MAP_FAILED = @intToPtr(*c_void, maxInt(usize));

// Extracted from sys/sys/wait.h
pub const WNOHANG = 1;
pub const WUNTRACED = 2;
pub const WCONTINUED = 8;

// Extracted from sys/sys/signal.h
pub const SA_ONSTACK = 0x0001;
pub const SA_RESTART = 0x0002;
pub const SA_RESETHAND = 0x0004;
pub const SA_NODEFER = 0x0010;
pub const SA_NOCLDWAIT = 0x0020;
pub const SA_NOCLDSTOP = 0x0008;
pub const SA_SIGINFO = 0x0040;

pub const SIGHUP = 1;
pub const SIGINT = 2;
pub const SIGQUIT = 3;
pub const SIGILL = 4;
pub const SIGTRAP = 5;
pub const SIGABRT = 6;
pub const SIGIOT = SIGABRT;
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

// Extracted from sys/sys/unistd.h
pub const F_OK = 0x00;
pub const X_OK = 0x01;
pub const W_OK = 0x02;
pub const R_OK = 0x04;

// Extracted from sys/sys/fcntl.h
pub const O_RDONLY = 0x0000;
pub const O_WRONLY = 0x0001;
pub const O_RDWR = 0x0002;
pub const O_ACCMODE = 0x0003;

pub const O_NONBLOCK = 0x0004;
pub const O_APPEND = 0x0008;
pub const O_SHLOCK = 0x0010;
pub const O_EXLOCK = 0x0020;
pub const O_ASYNC = 0x0040;
pub const O_FSYNC = 0x0080;
pub const O_NOFOLLOW = 0x0100;
pub const O_SYNC = 0x0080;
pub const O_CREAT = 0x0200;
pub const O_TRUNC = 0x0400;
pub const O_EXCL = 0x0800;

pub const O_DSYNC = O_SYNC;
pub const O_RSYNC = O_SYNC;

pub const O_NOCTTY = 0x8000;

pub const O_CLOEXEC = 0x10000;
pub const O_DIRECTORY = 0x20000;

pub const O_NDELAY = O_NONBLOCK;

pub const F_DUPFD = 0;
pub const F_GETFD = 1;
pub const F_SETFD = 2;
pub const F_GETFL = 3;
pub const F_SETFL = 4;
pub const F_GETOWN = 5;
pub const F_SETOWN = 6;
pub const F_GETLK = 7;
pub const F_SETLK = 8;
pub const F_SETLKW = 9;
pub const F_DUPFD_CLOEXEC = 10;
pub const F_ISATTY = 11;

pub const FD_CLOEXEC = 1;

pub const F_RDLCK = 1;
pub const F_UNLCK = 2;
pub const F_WRLCK = 3;

pub const LOCK_SH = 0x01;
pub const LOCK_EX = 0x02;
pub const LOCK_NB = 0x04;
pub const LOCK_UN = 0x08;

// Extracted from sys/sys/unistd.h
pub const SEEK_SET = 0;
pub const SEEK_CUR = 1;
pub const SEEK_END = 2;

// Extracted from sys/sys/signal.h
pub const SIG_BLOCK = 1;
pub const SIG_UNBLOCK = 2;
pub const SIG_SETMASK = 3;

// Extracted from sys/sys/socket.h
pub const SOCK_STREAM = 1;
pub const SOCK_DGRAM = 2;
pub const SOCK_RAW = 3;
pub const SOCK_RDM = 4;
pub const SOCK_SEQPACKET = 5;
pub const SOCK_TYPE_MASK = 0x000F;

pub const SOCK_CLOEXEC = 0x8000;
pub const SOCK_NONBLOCK = 0x4000;
pub const SOCK_NONBLOCK_INHERIT = 0x2000;
pub const SOCK_DNS = 0x1000;

pub const PF_UNSPEC = AF_UNSPEC;
pub const PF_LOCAL = AF_LOCAL;
pub const PF_UNIX = AF_UNIX;
pub const PF_INET = AF_INET;
pub const PF_IMPLINK = AF_IMPLINK;
pub const PF_PUP = AF_PUP;
pub const PF_CHAOS = AF_CHAOS;
pub const PF_NS = AF_NS;
pub const PF_ISO = AF_ISO;
pub const PF_OSI = AF_ISO;
pub const PF_ECMA = AF_ECMA;
pub const PF_DATAKIT = AF_DATAKIT;
pub const PF_CCITT = AF_CCITT;
pub const PF_SNA = AF_SNA;
pub const PF_DECnet = AF_DECnet;
pub const PF_DLI = AF_DLI;
pub const PF_LAT = AF_LAT;
pub const PF_HYLINK = AF_HYLINK;
pub const PF_APPLETALK = AF_APPLETALK;
pub const PF_ROUTE = AF_ROUTE;
pub const PF_LINK = AF_LINK;
pub const PF_XTP = pseudo_AF_XTP;
pub const PF_COIP = AF_COIP;
pub const PF_CNT = AF_CNT;
pub const PF_IPX = AF_IPX;
pub const PF_INET6 = AF_INET6;
pub const PF_RTIP = pseudo_AF_RTIP;
pub const PF_PIP = pseudo_AF_PIP;
pub const PF_ISDN = AF_ISDN;
pub const PF_NATM = AF_NATM;
pub const PF_ENCAP = AF_ENCAP;
pub const PF_SIP = AF_SIP;
pub const PF_KEY = AF_KEY;
pub const PF_BPF = pseudo_AF_HDRCMPLT;
pub const PF_BLUETOOTH = AF_BLUETOOTH;
pub const PF_MPLS = AF_MPLS;
pub const PF_PFLOW = pseudo_AF_PFLOW;
pub const PF_PIPEX = pseudo_AF_PIPEX;
pub const PF_MAX = AF_MAX;

pub const AF_UNSPEC = 0;
pub const AF_UNIX = 1;
pub const AF_LOCAL = AF_UNIX;
pub const AF_INET = 2;
pub const AF_IMPLINK = 3;
pub const AF_PUP = 4;
pub const AF_CHAOS = 5;
pub const AF_NS = 6;
pub const AF_ISO = 7;
pub const AF_OSI = AF_ISO;
pub const AF_ECMA = 8;
pub const AF_DATAKIT = 9;
pub const AF_CCITT = 10;
pub const AF_SNA = 11;
pub const AF_DECnet = 12;
pub const AF_DLI = 13;
pub const AF_LAT = 14;
pub const AF_HYLINK = 15;
pub const AF_APPLETALK = 16;
pub const AF_ROUTE = 17;
pub const AF_LINK = 18;
pub const pseudo_AF_XTP = 19;
pub const AF_COIP = 20;
pub const AF_CNT = 21;
pub const pseudo_AF_RTIP = 22;
pub const AF_IPX = 23;
pub const AF_INET6 = 24;
pub const pseudo_AF_PIP = 25;
pub const AF_ISDN = 26;
pub const AF_E164 = AF_ISDN;
pub const AF_NATM = 27;
pub const AF_ENCAP = 28;
pub const AF_SIP = 29;
pub const AF_KEY = 30;
pub const pseudo_AF_HDRCMPLT = 31;
pub const AF_BLUETOOTH = 32;
pub const AF_MPLS = 33;
pub const pseudo_AF_PFLOW = 34;
pub const pseudo_AF_PIPEX = 35;
pub const AF_MAX = 36;

pub const sockaddr_storage = extern struct {
    ss_len: u8,
    ss_family: sa_family_t,
    __ss_pad1: [6]u8,
    __ss_pad2: u64,
    __ss_pad3: [240]u8,
};

// Extracted from sys/sys/dirent.h
pub const DT_UNKNOWN = 0;
pub const DT_FIFO = 1;
pub const DT_CHR = 2;
pub const DT_DIR = 4;
pub const DT_BLK = 6;
pub const DT_REG = 8;
pub const DT_LNK = 10;
pub const DT_SOCK = 12;

// Extracted from sys/sys/event.h
pub const EV_ADD = 0x0001;
pub const EV_DELETE = 0x0002;
pub const EV_ENABLE = 0x0004;
pub const EV_DISABLE = 0x0008;

pub const EV_ONESHOT = 0x0010;
pub const EV_CLEAR = 0x0020;
pub const EV_RECEIPT = 0x0040;
pub const EV_DISPATCH = 0x0080;
pub const EV_SYSFLAGS = 0xF000;
pub const EV_FLAG1 = 0x2000;

pub const EV_EOF = 0x8000;
pub const EV_ERROR = 0x4000;

pub const EVFILT_READ = -1;
pub const EVFILT_WRITE = -2;
pub const EVFILT_AIO = -3;
pub const EVFILT_VNODE = -4;
pub const EVFILT_PROC = -5;
pub const EVFILT_SIGNAL = -6;
pub const EVFILT_TIMER = -7;
pub const EVFILT_DEVICE = -8;

pub const NOTE_DELETE = 0x0001;
pub const NOTE_WRITE = 0x0002;
pub const NOTE_EXTEND = 0x0004;
pub const NOTE_ATTRIB = 0x0008;
pub const NOTE_LINK = 0x0010;
pub const NOTE_RENAME = 0x0020;
pub const NOTE_REVOKE = 0x0040;
pub const NOTE_TRUNCATE = 0x0080;

pub const NOTE_EXIT = 0x80000000;
pub const NOTE_FORK = 0x40000000;
pub const NOTE_EXEC = 0x20000000;
pub const NOTE_PCTRLMASK = 0xf0000000;
pub const NOTE_PDATAMASK = 0x000fffff;

// Extracted from sys/sys/ttycom.h
pub const TIOCM_LE = 0001;
pub const TIOCM_DTR = 0002;
pub const TIOCM_RTS = 0004;
pub const TIOCM_ST = 0010;
pub const TIOCM_SR = 0020;
pub const TIOCM_CTS = 0040;
pub const TIOCM_CAR = 0100;
pub const TIOCM_CD = TIOCM_CAR;
pub const TIOCM_RNG = 0200;
pub const TIOCM_RI = TIOCM_RNG;
pub const TIOCM_DSR = 0400;

// Extracted from sys/sys/wait.h
pub fn WIFSTOPPED(x: u32) bool {
    return (x & 0xff) == 0177;
}

pub fn WSTOPSIG(x: u32) u32 {
    return WEXITSTATUS(x);
}

pub fn WIFSIGNALED(x: u32) bool {
    return WTERMSIG(x) != 0177 and WTERMSIG(x) != 0;
}

pub fn WTERMSIG(x: u32) u32 {
    return x & 0177;
}

pub fn WIFEXITED(x: u32) bool {
    return WTERMSIG(x) == 0;
}

pub fn WEXITSTATUS(x: u32) u32 {
    return (x >> 8) & 0xff;
}

pub fn WIFCONTINUED(x: u32) bool {
    return (x & 0177777) == 0177777;
}

// Extracted from sys/sys/ttycom.h
pub const winsize = extern struct {
    ws_row: c_ushort,
    ws_col: c_ushort,
    ws_xpixel: c_ushort,
    ws_ypixel: c_ushort,
};

// Extracted from sys/sys/signal.h
pub const SIG_DFL = @intToPtr(fn (c_int) callconv(.C) void, 0);
pub const SIG_IGN = @intToPtr(fn (c_int) callconv(.C) void, 1);
pub const SIG_ERR = @intToPtr(fn (c_int) callconv(.C) void, maxInt(usize));

pub const BADSIG = SIG_ERR;

// Extracted from sys/sys/signal.h
pub const sigset_t = c_uint;

// Extracted from sys/sys/siginfo
const sigval = extern union {
    sival_int: c_int,
    sival_ptr: ?*c_void,
};

const SI_MAXSZ = 128;
const SI_PAD = (SI_MAXSZ / @sizeOf(c_int)) - 3;

pub const siginfo_t = extern struct {
    signo: c_int,
    code: c_int,
    errno: c_int,
    data: extern union {
        pad: [SI_PAD]i32,
        proc: extern struct {
            pid: pid_t,
            pdata: extern union {
                kill: extern struct {
                    uid: uid_t,
                    value: sigval,
                },
                cld: extern struct {
                    utime: clock_t,
                    stime: clock_t,
                    status: c_int,
                },
            },
        },
        fault: extern struct {
            addr: ?*c_void,
            trapno: c_int,
        },
    },
};

// Extracted from sys/sys/signal.h
/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = extern struct {
    __sigaction_u: extern union {
        __sa_handler: fn (c_int) callconv(.C) void,
        __sa_sigaction: fn (c_int, *siginfo_t, ?*c_void) callconv(.C) void,
    },
    sa_mask: sigset_t,
    sa_flags: c_int,
};

// Extracted from sys/sys/errno.h
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
pub const EWOULDBLOCK = EAGAIN;
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
pub const EIPSEC = 82;
pub const ENOATTR = 83;
pub const EILSEQ = 84;
pub const ENOMEDIUM = 85;
pub const EMEDIUMTYPE = 86;
pub const EOVERFLOW = 87;
pub const ECANCELED = 88;
pub const EIDRM = 89;
pub const ENOMSG = 90;
pub const ENOTSUP = 91;
pub const EBADMSG = 92;
pub const ENOTRECOVERABLE = 93;
pub const EOWNERDEAD = 94;
pub const EPROTO = 95;
pub const ELAST = 95;

// TODO MINSIGSTKSZ, SIGSTKSZ

// Extracted from sys/sys/signal.h
pub const SS_ONSTACK = 0x0001;
pub const SS_DISABLE = 0x0004;

pub const stack_t = extern struct {
    ss_sp: ?*c_void,
    ss_size: usize,
    ss_flags: c_int,
};

// Extracted from sys/sys/stat.h
pub const S_ISUID = 0004000;
pub const S_ISGID = 0002000;
pub const S_ISTXT = 0001000;

pub const S_IRWXU = 0000700;
pub const S_IRUSR = 0000400;
pub const S_IWUSR = 0000200;
pub const S_IXUSR = 0000100;

pub const S_IREAD = S_IRUSR;
pub const S_IWRITE = S_IWUSR;
pub const S_IEXEC = S_IXUSR;

pub const S_IRWXG = 0000070;
pub const S_IRGRP = 0000040;
pub const S_IWGRP = 0000020;
pub const S_IXGRP = 0000010;

pub const S_IRWXO = 0000007;
pub const S_IROTH = 0000004;
pub const S_IWOTH = 0000002;
pub const S_IXOTH = 0000001;

pub const S_IFMT = 0170000;
pub const S_IFIFO = 0010000;
pub const S_IFCHR = 0020000;
pub const S_IFDIR = 0040000;
pub const S_IFBLK = 0060000;
pub const S_IFREG = 0100000;
pub const S_IFLNK = 0120000;
pub const S_IFSOCK = 0140000;
pub const S_ISVTX = 0001000;

pub fn S_ISDIR(m: u32) bool {
    (m & S_IFMT) == S_IFDIR;
}

pub fn S_ISCHR(m: u32) bool {
    (m & S_IFMT) == S_IFCHR;
}

pub fn S_ISBLK(m: u32) bool {
    (m & S_IFMT) == S_IFBLK;
}

pub fn S_ISREG(m: u32) bool {
    (m & S_IFMT) == S_IFREG;
}

pub fn S_ISFIFO(m: u32) bool {
    (m & S_IFMT) == S_IFIFO;
}

pub fn S_ISLNK(m: u32) bool {
    (m & S_IFMT) == S_IFLNK;
}

pub fn S_ISSOCK(m: u32) bool {
    (m & S_IFMT) == S_IFSOCK;
}

pub const S_BLKSIZE = 512;

// Extracted from include/limits.h
pub const HOST_NAME_MAX = 255;

// Extracted from sys/sys/fcntl.h
pub const AT_FDCWD = -100;
pub const AT_EACCESS = 0x01;
pub const AT_SYMLINK_NOFOLLOW = 0x02;
pub const AT_SYMLINK_FOLLOW = 0x04;
pub const AT_REMOVEDIR = 0x08;

// Extracted from include/netdb.h
pub const addrinfo = extern struct {
    flags: c_int,
    family: c_int,
    socktype: c_int,
    protocol: c_int,
    addrlen: socklen_t,
    addr: ?*sockaddr,
    canonname: ?[*:0]u8,
    next: ?*addrinfo,
};

pub const EAI = extern enum(c_int) {
    BADFLAGS = -1,
    NONAME = -2,
    AGAIN = -3,
    FAIL = -4,
    NODATA = -5,
    FAMILY = -6,
    SOCKTYPE = -7,
    SERVICE = -8,
    ADDRFAMILY = -9,
    MEMORY = -10,
    SYSTEM = -11,
    BADHINTS = -12,
    PROTOCOL = -13,
    OVERFLOW = -14,
    _,
};

// Extracted from sys/netinet/in.h
pub const IPPROTO_IP = 0;
pub const IPPROTO_HOPOPTS = IPPROTO_IP;
pub const IPPROTO_ICMP = 1;
pub const IPPROTO_IGMP = 2;
pub const IPPROTO_GGP = 3;
pub const IPPROTO_IPIP = 4;
pub const IPPROTO_IPV4 = IPPROTO_IPIP;
pub const IPPROTO_TCP = 6;
pub const IPPROTO_EGP = 8;
pub const IPPROTO_PUP = 12;
pub const IPPROTO_UDP = 17;
pub const IPPROTO_IDP = 22;
pub const IPPROTO_TP = 29;
pub const IPPROTO_IPV6 = 41;
pub const IPPROTO_ROUTING = 43;
pub const IPPROTO_FRAGMENT = 44;
pub const IPPROTO_RSVP = 46;
pub const IPPROTO_GRE = 47;
pub const IPPROTO_ESP = 50;
pub const IPPROTO_AH = 51;
pub const IPPROTO_MOBILE = 55;
pub const IPPROTO_ICMPV6 = 58;
pub const IPPROTO_NONE = 59;
pub const IPPROTO_DSTOPTS = 60;
pub const IPPROTO_EON = 80;
pub const IPPROTO_ETHERIP = 97;
pub const IPPROTO_ENCAP = 98;
pub const IPPROTO_PIM = 103;
pub const IPPROTO_IPCOMP = 108;
pub const IPPROTO_CARP = 112;
pub const IPPROTO_UDPLITE = 136;
pub const IPPROTO_MPLS = 137;
pub const IPPROTO_PFSYNC = 240;
pub const IPPROTO_RAW = 255;

// TODO Miscellaneous
pub const fd_t = c_int;
pub const ARG_MAX = 512 * 1024;
pub const PATH_MAX = 1024;
