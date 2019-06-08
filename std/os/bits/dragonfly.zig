const std = @import("../../std.zig");
const maxInt = std.math.maxInt;

pub const __sighandler_t = extern fn(c_int) void;
pub const fd_t = c_int;

pub extern "c" var optarg: [*c]u8;
pub extern "c" var optind: c_int;
pub extern "c" var opterr: c_int;
pub extern "c" var optopt: c_int;
pub extern "c" var optreset: c_int;
pub extern "c" var tzname: [*c]([*c]u8);
pub extern "c" var daylight: c_int;
pub extern "c" var timezone: c_long;

pub const locale_t = @OpaqueType();

pub const ENOTSUP = EOPNOTSUPP;
pub const EWOULDBLOCK = EAGAIN;
pub const EPERM = 1;
pub const unix = 1;
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

pub const PATH_MAX = 1024;

pub const Stat = extern struct {
    ino: c_ulong,
    nlink: c_uint,
    dev: c_uint,
    mode: c_ushort,
    padding1: u16,
    uid: c_uint,
    gid: c_uint,
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
};

pub const timespec = extern struct {
    tv_sec: c_long,
    tv_nsec: c_long,
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

pub const O_LARGEFILE = 0; // faked support // faked support
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

pub const pid_t = c_int;

pub const F_OK = 0;
pub const F_ULOCK = 0;
pub const F_LOCK = 1;
pub const F_TLOCK = 2;
pub const F_TEST = 3;

pub fn WEXITSTATUS(s: u32) u32 {
    return (s & 0xff00) >> 8;
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
    sa_len: u8,
    sa_family: u8,
    sa_data: [14]u8,
};

pub const Kevent = extern struct {
    ident: usize,
    filter: c_short,
    flags: c_ushort,
    fflags: c_uint,
    data: isize,
    udata: usize,
};

// copied from freebsd
pub const pthread_attr_t = extern struct {
    __size: [56]u8,
    __align: c_long,
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

pub const CPULOCK_EXCLBIT = 0;
pub const CPULOCK_EXCL = 1;
pub const CPULOCK_INCR = 2;
pub const CPULOCK_CNTMASK = 2147483646;

pub const L_INCR = SEEK_CUR;
pub const L_XTND = SEEK_END;
pub const L_SET = SEEK_SET;

pub const X_OK = 1;
pub const W_OK = 2;
pub const R_OK = 4;

pub const BIG_ENDIAN = 4321;
pub const LITTLE_ENDIAN = 1234;
pub const PDP_ENDIAN = 3412;

pub const vm_offset_t = c_ulong;
pub const vm_size_t = c_ulong;
pub const vm_pindex_t = c_ulong;
pub const vm_spindex_t = c_ulong;
pub const vm_ooffset_t = c_long;
pub const vm_poff_t = c_ulong;
pub const vm_paddr_t = c_ulong;

pub const register_t = c_long;
pub const u_register_t = c_ulong;
pub const pml4_entry_t = c_ulong;
pub const pdp_entry_t = c_ulong;
pub const pd_entry_t = c_ulong;
pub const pt_entry_t = c_ulong;
pub const cpulock_t = c_uint;
pub const cpumask_t = extern struct {
    ary: [4]u64,
};
pub const Pthread_once = extern struct {
    state: c_int,
    mutex: pthread_mutex_t,
};
pub const u_quad_t = c_ulong;
pub const quad_t = c_long;
pub const qaddr_t = [*c]quad_t;
pub const blkcnt_t = c_long;
pub const blksize_t = c_long;
pub const caddr_t = [*c]u8;
pub const c_caddr_t = [*c]const u8;
pub const v_caddr_t = [*c]volatile u8;
pub const daddr_t = c_int;
pub const u_daddr_t = c_uint;
pub const fixpt_t = c_uint;
pub const fsblkcnt_t = c_ulong;
pub const fsfilcnt_t = c_ulong;
pub const gid_t = c_uint;
pub const id_t = c_long;
pub const in_addr_t = c_uint;
pub const in_port_t = c_ushort;
pub const ino_t = c_ulong;
pub const key_t = c_long;
pub const mode_t = c_ushort;
pub const nlink_t = c_uint;
pub const off_t = c_long;
pub const rlim_t = c_long;
pub const segsz_t = c_long;
pub const suseconds_t = c_long;
pub const uid_t = c_uint;
pub const useconds_t = c_uint;
pub const mqd_t = c_int;
pub const dev_t = c_uint;
pub const clock_t = c_ulong;
pub const clockid_t = c_ulong;
pub const lwpid_t = c_int;
pub const time_t = c_long;
pub const timer_t = c_int;
pub const fd_set = extern struct {
    fds_bits: [16]fd_mask,
};
pub const timeval = extern struct {
    tv_sec: time_t,
    tv_usec: suseconds_t,
};

pub const SIG_ATOMIC_MAX = 2147483647;
pub const EXTEXIT_SIMPLE = 0;
pub const fd_mask = c_ulong;
pub const SIG_ATOMIC_MIN = if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Pointer) @ptrCast(-2147483647, -1) else if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Int) @intToPtr(-2147483647, -1) else (-2147483647)(-1);
pub const BYTE_ORDER = 1234;
pub const NULL = if (@typeId(@typeOf(0)) == @import("builtin").TypeId.Pointer) @ptrCast([*c]void, 0) else if (@typeId(@typeOf(0)) == @import("builtin").TypeId.Int) @intToPtr([*c]void, 0) else ([*c]void)(0);
pub const udev_t = dev_t;
pub const pthread = @OpaqueType();
pub const EXTEXIT_SETINT = 1;
pub const NBBY = 8;
pub const FD_SETSIZE = 1024;

pub const DTF_HIDEW = 1;
pub const DTF_NODUP = 2;
pub const DTF_REWIND = 4;

pub const DIR = @OpaqueType();
pub const DIRBLKSIZ = 1024;

pub const CTL_P1003_1B_ASYNCHRONOUS_IO = 1;
pub const CTL_P1003_1B_MAPPED_FILES = 2;
pub const CTL_P1003_1B_MEMLOCK = 3;
pub const CTL_P1003_1B_MEMLOCK_RANGE = 4;
pub const CTL_P1003_1B_MEMORY_PROTECTION = 5;
pub const CTL_P1003_1B_MESSAGE_PASSING = 6;
pub const CTL_P1003_1B_PRIORITIZED_IO = 7;
pub const CTL_P1003_1B_PRIORITY_SCHEDULING = 8;
pub const CTL_P1003_1B = 9;
pub const CTL_P1003_1B_REALTIME_SIGNALS = 9;
pub const CTL_P1003_1B_SEMAPHORES = 10;
pub const CTL_P1003_1B_FSYNC = 11;
pub const CTL_P1003_1B_SHARED_MEMORY_OBJECTS = 12;
pub const CTL_P1003_1B_SYNCHRONIZED_IO = 13;
pub const CTL_P1003_1B_TIMERS = 14;
pub const CTL_P1003_1B_AIO_LISTIO_MAX = 15;
pub const CTL_P1003_1B_AIO_MAX = 16;
pub const CTL_P1003_1B_AIO_PRIO_DELTA_MAX = 17;
pub const CTL_P1003_1B_DELAYTIMER_MAX = 18;
pub const CTL_P1003_1B_UNUSED1 = 19;
pub const CTL_P1003_1B_PAGESIZE = 20;
pub const CTL_P1003_1B_RTSIG_MAX = 21;
pub const CTL_P1003_1B_SEM_NSEMS_MAX = 22;
pub const CTL_P1003_1B_SEM_VALUE_MAX = 23;
pub const CTL_P1003_1B_SIGQUEUE_MAX = 24;
pub const CTL_P1003_1B_TIMER_MAX = 25;
pub const CTL_P1003_1B_MAXID = 26;

pub const CTLTYPE_UQUAD = CTLTYPE_U64;
pub const CTLTYPE_QUAD = CTLTYPE_S64;
pub const CTLTYPE_STRUCT = CTLTYPE_OPAQUE;
pub const CTLTYPE_NODE = 1;
pub const CTLTYPE_INT = 2;
pub const CTLTYPE_STRING = 3;
pub const CTLTYPE_S64 = 4;
pub const CTLTYPE_OPAQUE = 5;
pub const CTLTYPE_UINT = 6;
pub const CTLTYPE_LONG = 7;
pub const CTLTYPE_ULONG = 8;
pub const CTLTYPE_U64 = 9;
pub const CTLTYPE_U8 = 10;
pub const CTLTYPE_U16 = 11;
pub const CTLTYPE_S8 = 12;
pub const CTLTYPE_S16 = 13;
pub const CTLTYPE_S32 = 14;
pub const CTLTYPE = 15;
pub const CTLTYPE_U32 = 15;

pub const CTLFLAG_NOLOCK = 8192;
pub const CTLFLAG_EXLOCK = 16384;
pub const CTLFLAG_SHLOCK = 32768;
pub const CTLFLAG_DYING = 65536;
pub const CTLFLAG_SKIP = 16777216;
pub const CTLFLAG_DYN = 33554432;
pub const CTLFLAG_PRISON = 67108864;
pub const CTLFLAG_SECURE = 134217728;
pub const CTLFLAG_ANYBODY = 268435456;
pub const CTLFLAG_WR = 1073741824;
pub const CTLFLAG_RD = 2147483648;

pub const KIPC_MAXSOCKBUF = 1;
pub const KIPC_SOCKBUF_WASTE = 2;
pub const KIPC_SOMAXCONN = 3;
pub const KIPC_MAX_LINKHDR = 4;
pub const KIPC_MAX_PROTOHDR = 5;
pub const KIPC_MAX_HDR = 6;
pub const KIPC_MAX_DATALEN = 7;
pub const KIPC_MBSTAT = 8;
pub const KIPC_NMBCLUSTERS = 9;

pub const HW_MACHINE = 1;
pub const HW_MODEL = 2;
pub const HW_NCPU = 3;
pub const HW_BYTEORDER = 4;
pub const HW_PHYSMEM = 5;
pub const HW_USERMEM = 6;
pub const HW_PAGESIZE = 7;
pub const HW_DISKNAMES = 8;
pub const HW_DISKSTATS = 9;
pub const HW_FLOATINGPT = 10;
pub const HW_MACHINE_ARCH = 11;
pub const HW_MACHINE_PLATFORM = 12;
pub const HW_SENSORS = 13;
pub const HW_MAXID = 14;

pub const USER_CS_PATH = 1;
pub const USER_BC_BASE_MAX = 2;
pub const USER_BC_DIM_MAX = 3;
pub const USER_BC_SCALE_MAX = 4;
pub const USER_BC_STRING_MAX = 5;
pub const USER_COLL_WEIGHTS_MAX = 6;
pub const USER_EXPR_NEST_MAX = 7;
pub const USER_LINE_MAX = 8;
pub const USER_RE_DUP_MAX = 9;
pub const USER_POSIX2_VERSION = 10;
pub const USER_POSIX2_C_BIND = 11;
pub const USER_POSIX2_C_DEV = 12;
pub const USER_POSIX2_CHAR_TERM = 13;
pub const USER_POSIX2_FORT_DEV = 14;
pub const USER_POSIX2_FORT_RUN = 15;
pub const USER_POSIX2_LOCALEDEF = 16;
pub const USER_POSIX2_SW_DEV = 17;
pub const USER_POSIX2_UPE = 18;
pub const USER_STREAM_MAX = 19;
pub const USER_TZNAME_MAX = 20;
pub const USER_MAXID = 21;

pub const OID_AUTO = -1;
pub const ctlname = extern struct {
    ctl_name: [*c]u8,
    ctl_type: c_int,
};
pub const TRASHIT = x;
pub const CTLMASK_TYPE = 15;
pub const CTLMASK_SECURE = 15728640;

pub const CLD_EXITED = 1;
pub const CLD_KILLED = 2;
pub const CLD_DUMPED = 3;
pub const CLD_TRAPPED = 4;
pub const CLD_STOPPED = 5;
pub const CLD_CONTINUED = 6;

pub const DST_NONE = 0;
pub const DST_USA = 1;
pub const DST_AUST = 2;
pub const DST_WET = 3;
pub const DST_MET = 4;
pub const DST_EET = 5;
pub const DST_CAN = 6;

pub const POLL_IN = 1;
pub const POLL_OUT = 2;
pub const POLL_MSG = 3;
pub const POLL_ERR = 4;
pub const POLL_PRI = 5;
pub const POLL_HUP = 6;

pub const TRAP_BRKPT = 1;
pub const TRAP_TRACE = 2;

pub const FPE_INTOVF = 1;
pub const FPE_INTOVF_TRAP = 1;
pub const FPE_INTDIV_TRAP = 2;
pub const FPE_INTDIV = 2;
pub const FPE_FLTDIV_TRAP = 3;
pub const FPE_FLTDIV = 3;
pub const FPE_FLTOVF_TRAP = 4;
pub const FPE_FLTOVF = 4;
pub const FPE_FLTUND_TRAP = 5;
pub const FPE_FLTUND = 5;
pub const FPE_FLTRES = 6;
pub const FPE_FPU_NP_TRAP = 6;
pub const FPE_FLTINV = 7;
pub const FPE_SUBRNG_TRAP = 7;
pub const FPE_FLTSUB = 8;

pub const BUS_SEGM_FAULT = T_RESERVED;
pub const BUS_SEGNP_FAULT = T_SEGNPFLT;
pub const BUS_PAGE_FAULT = T_PAGEFLT;
pub const BUS_STK_FAULT = T_STKFLT;
pub const BUS_ADRALN = 1;
pub const BUS_ADRERR = 2;
pub const BUS_OBJERR = 3;

pub const SS_ONSTACK = 1;
pub const SS_DISABLE = 4;

pub const UF_NODUMP = 1;
pub const UF_IMMUTABLE = 2;
pub const UF_APPEND = 4;
pub const UF_OPAQUE = 8;
pub const UF_NOUNLINK = 16;
pub const UF_FBSDRSVD20 = 32;
pub const UF_NOHISTORY = 64;
pub const UF_CACHE = 128;
pub const UF_XLINK = 256;
pub const UF_SETTABLE = 65535;

pub const SF_ARCHIVED = 65536;
pub const SF_IMMUTABLE = 131072;
pub const SF_APPEND = 262144;
pub const SF_NOUNLINK = 1048576;
pub const SF_FBSDRSVD20 = 2097152;
pub const SF_NOHISTORY = 4194304;
pub const SF_NOCACHE = 8388608;
pub const SF_XLINK = 16777216;
pub const SF_SETTABLE = 4294901760;

pub const SV_ONSTACK = SA_ONSTACK;
pub const SV_INTERRUPT = SA_RESTART;
pub const SV_NOCLDSTOP = SA_NOCLDSTOP;
pub const SV_NODEFER = SA_NODEFER;
pub const SV_SIGINFO = SA_SIGINFO;
pub const SV_RESETHAND = SA_RESETHAND;

pub const SA_ONSTACK = 1;
pub const SA_RESTART = 2;
pub const SA_RESETHAND = 4;
pub const SA_NOCLDSTOP = 8;
pub const SA_NODEFER = 16;
pub const SA_NOCLDWAIT = 32;
pub const SA_SIGINFO = 64;

pub const T_PRIVINFLT = 1;
pub const T_BPTFLT = 3;
pub const T_ARITHTRAP = 6;
pub const T_ASTFLT = 7;
pub const T_PROTFLT = 9;
pub const T_TRCTRAP = 10;
pub const T_PAGEFLT = 12;
pub const T_ALIGNFLT = 14;
pub const T_DIVIDE = 18;
pub const T_NMI = 19;
pub const T_OFLOW = 20;
pub const T_BOUND = 21;
pub const T_DNA = 22;
pub const T_DOUBLEFLT = 23;
pub const T_FPOPFLT = 24;
pub const T_TSSFLT = 25;
pub const T_SEGNPFLT = 26;
pub const T_STKFLT = 27;
pub const T_MCHK = 28;
pub const T_XMMFLT = 29;
pub const T_RESERVED = 30;
pub const T_FAST_SYSCALL = 129;
pub const T_USER = 256;

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

pub const ILL_PRIVIN_FAULT = T_PRIVINFLT;
pub const ILL_ALIGN_FAULT = T_ALIGNFLT;
pub const ILL_FPOP_FAULT = T_FPOPFLT;
pub const ILL_ILLOPC = 1;
pub const ILL_ILLOPN = 2;
pub const ILL_ILLADR = 3;
pub const ILL_ILLTRP = 4;
pub const ILL_PRVOPC = 5;
pub const ILL_PRVREG = 6;
pub const ILL_COPROC = 7;
pub const ILL_BADSTK = 8;

pub const SIGEV_NONE = 0;
pub const SIGEV_SIGNAL = 1;
pub const SIGEV_THREAD = 2;
pub const SIGEV_KEVENT = 3;

pub const SIG_ERR = if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Pointer) @ptrCast([*c]__sighandler_t, -1) else if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Int) @intToPtr([*c]__sighandler_t, -1) else ([*c]__sighandler_t)(-1);
pub const SIG_IGN = if (@typeId(@typeOf(1)) == @import("builtin").TypeId.Pointer) @ptrCast([*c]__sighandler_t, 1) else if (@typeId(@typeOf(1)) == @import("builtin").TypeId.Int) @intToPtr([*c]__sighandler_t, 1) else ([*c]__sighandler_t)(1);
pub const BADSIG = SIG_ERR;
pub const SIG_DFL = if (@typeId(@typeOf(0)) == @import("builtin").TypeId.Pointer) @ptrCast([*c]__sighandler_t, 0) else if (@typeId(@typeOf(0)) == @import("builtin").TypeId.Int) @intToPtr([*c]__sighandler_t, 0) else ([*c]__sighandler_t)(0);
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

pub const SI_MESGQ = -4;
pub const SI_ASYNCIO = -3;
pub const SI_TIMER = -2;
pub const SI_QUEUE = -1;
pub const SI_UNDEFINED = 0;
pub const SI_USER = 0;

pub const UTIME_OMIT = -2;
pub const UTIME_NOW = -1;
pub const union_sigval = extern union {
    sival_int: c_int,
    sival_ptr: ?*c_void,
};
pub const sigevent = extern struct {
    sigev_notify: c_int,
    __sigev_u: extern union {
        __sigev_signo: c_int,
        __sigev_notify_kqueue: c_int,
        __sigev_notify_attributes: [*c]pthread_attr_t,
    },
    sigev_value: union_sigval,
    sigev_notify_function: ?extern fn(union_sigval) void,
};
pub const siginfo_t = extern struct {
    si_signo: c_int,
    si_errno: c_int,
    si_code: c_int,
    si_pid: c_int,
    si_uid: c_uint,
    si_status: c_int,
    si_addr: ?*c_void,
    si_value: union_sigval,
    si_band: c_long,
    __spare__: [7]c_int,
};
pub const sigset_t = extern struct {
    __bits: [4]c_uint,
};
pub const sig_atomic_t = c_int;
pub const sigcontext = extern struct {
    sc_mask: sigset_t,
    sc_onstack: c_long,
    sc_rdi: c_long,
    sc_rsi: c_long,
    sc_rdx: c_long,
    sc_rcx: c_long,
    sc_r8: c_long,
    sc_r9: c_long,
    sc_rax: c_long,
    sc_rbx: c_long,
    sc_rbp: c_long,
    sc_r10: c_long,
    sc_r11: c_long,
    sc_r12: c_long,
    sc_r13: c_long,
    sc_r14: c_long,
    sc_r15: c_long,
    sc_xflags: c_long,
    sc_trapno: c_long,
    sc_addr: c_long,
    sc_flags: c_long,
    sc_err: c_long,
    sc_rip: c_long,
    sc_cs: c_long,
    sc_rflags: c_long,
    sc_rsp: c_long,
    sc_ss: c_long,
    sc_len: c_uint,
    sc_fpformat: c_uint,
    sc_ownedfp: c_uint,
    sc_reserved: c_uint,
    sc_unused: [8]c_uint,
    sc_fpregs: [256]c_int,
};
pub const Sigaction = extern struct {
    __sigaction_u: extern union {
        __sa_handler: ?extern fn(c_int) void,
        __sa_sigaction: ?extern fn(c_int, [*c]siginfo_t, ?*c_void) void,
    },
    sa_flags: c_int,
    sa_mask: sigset_t,
};
pub const sig_t = [*c]extern fn(c_int) void;
pub const sigaltstack = extern struct {
    ss_sp: [*c]u8,
    ss_size: u64,
    ss_flags: c_int,
};
pub const stack_t = sigaltstack;
pub const mcontext_t = extern struct {
    mc_onstack: register_t,
    mc_rdi: register_t,
    mc_rsi: register_t,
    mc_rdx: register_t,
    mc_rcx: register_t,
    mc_r8: register_t,
    mc_r9: register_t,
    mc_rax: register_t,
    mc_rbx: register_t,
    mc_rbp: register_t,
    mc_r10: register_t,
    mc_r11: register_t,
    mc_r12: register_t,
    mc_r13: register_t,
    mc_r14: register_t,
    mc_r15: register_t,
    mc_xflags: register_t,
    mc_trapno: register_t,
    mc_addr: register_t,
    mc_flags: register_t,
    mc_err: register_t,
    mc_rip: register_t,
    mc_cs: register_t,
    mc_rflags: register_t,
    mc_rsp: register_t,
    mc_ss: register_t,
    mc_len: c_uint,
    mc_fpformat: c_uint,
    mc_ownedfp: c_uint,
    mc_reserved: c_uint,
    mc_unused: [8]c_uint,
    mc_fpregs: [256]c_int,
};
pub const ucontext_t = extern struct {
    uc_sigmask: sigset_t,
    uc_mcontext: mcontext_t,
    uc_link: [*c]ucontext_t,
    uc_stack: stack_t,
    uc_cofunc: ?extern fn([*c]ucontext_t, ?*c_void) void,
    uc_arg: ?*c_void,
    __spare__: [4]c_int,
};

pub const sigvec = extern struct {
    sv_handler: [*c]__sighandler_t,
    sv_mask: c_int,
    sv_flags: c_int,
};

pub const Timezone = extern struct {
    tz_minuteswest: c_int,
    tz_dsttime: c_int,
};
pub const itimerval = extern struct {
    it_interval: timeval,
    it_value: timeval,
};
pub const clockinfo = extern struct {
    hz: c_int,
    tick: c_int,
    tickadj: c_int,
    stathz: c_int,
    profhz: c_int,
};
pub const tm = extern struct {
    tm_sec: c_int,
    tm_min: c_int,
    tm_hour: c_int,
    tm_mday: c_int,
    tm_mon: c_int,
    tm_year: c_int,
    tm_wday: c_int,
    tm_yday: c_int,
    tm_isdst: c_int,
    tm_gmtoff: c_long,
    tm_zone: [*c]u8,
};

pub const ITIMER_REAL = 0;
pub const TIMER_RELTIME = 0;
pub const CLOCKS_PER_SEC = if (@typeId(@typeOf(128)) == @import("builtin").TypeId.Pointer) @ptrCast(clock_t, 128) else if (@typeId(@typeOf(128)) == @import("builtin").TypeId.Int) @intToPtr(clock_t, 128) else clock_t(128);
pub const sigval = union_sigval;
pub const TIMER_ABSTIME = 1;
pub const TIME_UTC = 1;
pub const SEGV_MAPERR = 1;
pub const ITIMER_VIRTUAL = 1;
pub const ITIMER_PROF = 2;
pub const SEGV_ACCERR = 2;
pub const NSIG = 64;
pub const CLK_TCK = 128;
pub const T_SYSCALL80 = 128;
pub const MINSIGSTKSZ = 8192;

pub const pseudo_AF_XTP = 19;
pub const pseudo_AF_RTIP = 22;
pub const pseudo_AF_PIP = 25;
pub const pseudo_AF_KEY = 27;
pub const pseudo_AF_HDRCMPLT = 31;

pub const SCM_RIGHTS = 1;
pub const SCM_TIMESTAMP = 2;
pub const SCM_CREDS = 3;

pub const SHUT_RD = 0;
pub const SHUT_WR = 1;
pub const SHUT_RDWR = 2;

pub const SOCK_STREAM = 1;
pub const SOCK_DGRAM = 2;
pub const SOCK_RAW = 3;
pub const SOCK_RDM = 4;
pub const SOCK_SEQPACKET = 5;
pub const SOCK_MAXADDRLEN = 255;
pub const SOCK_CLOEXEC = 268435456;
pub const SOCK_NONBLOCK = 536870912;

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
pub const AF_NATM = 29;
pub const AF_ATM = 30;
pub const AF_NETGRAPH = 32;
pub const AF_BLUETOOTH = 33;
pub const AF_MPLS = 34;
pub const AF_MAX = 36;

pub const NET_MAXID = AF_MAX;
pub const NET_RT_DUMP = 1;
pub const NET_RT_FLAGS = 2;
pub const NET_RT_IFLIST = 3;
pub const NET_RT_MAXID = 4;

pub const MSG_OOB = 1;
pub const MSG_PEEK = 2;
pub const MSG_DONTROUTE = 4;
pub const MSG_EOR = 8;
pub const MSG_TRUNC = 16;
pub const MSG_CTRUNC = 32;
pub const MSG_WAITALL = 64;
pub const MSG_DONTWAIT = 128;
pub const MSG_EOF = 256;
pub const MSG_UNUSED09 = 512;
pub const MSG_NOSIGNAL = 1024;
pub const MSG_SYNC = 2048;
pub const MSG_CMSG_CLOEXEC = 4096;
pub const MSG_FBLOCKING = 65536;
pub const MSG_FNONBLOCKING = 131072;
pub const MSG_FMASK = 4294901760;

pub const SO_DEBUG = 1;
pub const SO_ACCEPTCONN = 2;
pub const SO_REUSEADDR = 4;
pub const SO_KEEPALIVE = 8;
pub const SO_DONTROUTE = 16;
pub const SO_BROADCAST = 32;
pub const SO_USELOOPBACK = 64;
pub const SO_LINGER = 128;
pub const SO_OOBINLINE = 256;
pub const SO_REUSEPORT = 512;
pub const SO_TIMESTAMP = 1024;
pub const SO_NOSIGPIPE = 2048;
pub const SO_ACCEPTFILTER = 4096;
pub const SO_SNDBUF = 4097;
pub const SO_RCVBUF = 4098;
pub const SO_SNDLOWAT = 4099;
pub const SO_RCVLOWAT = 4100;
pub const SO_SNDTIMEO = 4101;
pub const SO_RCVTIMEO = 4102;
pub const SO_ERROR = 4103;
pub const SO_TYPE = 4104;
pub const SO_SNDSPACE = 4106;
pub const SO_CPUHINT = 4144;

pub const sa_family_t = u8;
pub const socklen_t = c_uint;
pub const linger = extern struct {
    l_onoff: c_int,
    l_linger: c_int,
};
pub const accept_filter_arg = extern struct {
    af_name: [16]u8,
    af_arg: [240]u8,
};
pub const sockproto = extern struct {
    sp_family: u16,
    sp_protocol: u16,
};
pub const sockaddr_storage = extern struct {
    ss_len: u8,
    ss_family: sa_family_t,
    __ss_pad1: [6]u8,
    __ss_align: i64,
    __ss_pad2: [112]u8,
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
pub const cmsghdr = extern struct {
    cmsg_len: socklen_t,
    cmsg_level: c_int,
    cmsg_type: c_int,
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

pub const AF_E164 = AF_ISDN;
pub const AF_DECnet = 12;
pub const CMGROUP_MAX = 16;
pub const AF_INET6 = 28;
pub const AF_IEEE80211 = 35;
pub const SOMAXCONN = 128;
pub const SOL_SOCKET = 65535;
pub const SOMAXOPT_SIZE = 65536;

pub const IN_CLASSC_NSHIFT = 8;
pub const IN_CLASSB_NSHIFT = 16;
pub const IN_CLASSA_NSHIFT = 24;
pub const IN_CLASSD_NSHIFT = 28;
pub const IN_LOOPBACKNET = 127;
pub const IN_CLASSA_MAX = 128;
pub const IN_CLASSC_HOST = 255;
pub const IN_CLASSB_HOST = 65535;
pub const IN_CLASSB_MAX = 65536;
pub const IN_CLASSA_HOST = 16777215;
pub const IN_CLASSD_HOST = 268435455;
pub const IN_CLASSD_NET = 4026531840;
pub const IN_CLASSA_NET = 4278190080;
pub const IN_CLASSB_NET = 4294901760;
pub const IN_CLASSC_NET = 4294967040;

pub const IPV6_RTHDR_TYPE_0 = 0;
pub const IPV6_BINDV6ONLY = IPV6_V6ONLY;
pub const IPV6_PORTRANGE_DEFAULT = 0;
pub const IPV6_RTHDR_LOOSE = 0;
pub const IPV6_DEFAULT_MULTICAST_HOPS = 1;
pub const IPV6_RTHDR_STRICT = 1;
pub const IPV6_DEFAULT_MULTICAST_LOOP = 1;
pub const IPV6_PORTRANGE_HIGH = 1;
pub const IPV6_PORTRANGE_LOW = 2;
pub const IPV6_SOCKOPT_RESERVED1 = 3;
pub const IPV6_UNICAST_HOPS = 4;
pub const IPV6_MULTICAST_IF = 9;
pub const IPV6_MULTICAST_HOPS = 10;
pub const IPV6_MULTICAST_LOOP = 11;
pub const IPV6_JOIN_GROUP = 12;
pub const IPV6_LEAVE_GROUP = 13;
pub const IPV6_PORTRANGE = 14;
pub const IPV6_CHECKSUM = 26;
pub const IPV6_V6ONLY = 27;
pub const IPV6_FW_ADD = 30;
pub const IPV6_FW_DEL = 31;
pub const IPV6_FW_FLUSH = 32;
pub const IPV6_FW_ZERO = 33;
pub const IPV6_FW_GET = 34;
pub const IPV6_RTHDRDSTOPTS = 35;
pub const IPV6_RECVPKTINFO = 36;
pub const IPV6_RECVHOPLIMIT = 37;
pub const IPV6_RECVRTHDR = 38;
pub const IPV6_RECVHOPOPTS = 39;
pub const IPV6_RECVDSTOPTS = 40;
pub const IPV6_USE_MIN_MTU = 42;
pub const IPV6_RECVPATHMTU = 43;
pub const IPV6_PATHMTU = 44;
pub const IPV6_PKTINFO = 46;
pub const IPV6_HOPLIMIT = 47;
pub const IPV6_NEXTHOP = 48;
pub const IPV6_HOPOPTS = 49;
pub const IPV6_DSTOPTS = 50;
pub const IPV6_RTHDR = 51;
pub const IPV6_PKTOPTIONS = 52;
pub const IPV6_RECVTCLASS = 57;
pub const IPV6_AUTOFLOWLABEL = 59;
pub const IPV6_TCLASS = 61;
pub const IPV6_DONTFRAG = 62;
pub const IPV6_PREFER_TEMPADDR = 63;
pub const IPV6_MSFILTER = 74;

pub const IPPROTO_HOPOPTS = 0;
pub const IPPROTO_IPIP = IPPROTO_IPV4;
pub const IPPROTO_IP = 0;
pub const IPPROTO_ICMP = 1;
pub const IPPROTO_IGMP = 2;
pub const IPPROTO_GGP = 3;
pub const IPPROTO_IPV4 = 4;
pub const IPPROTO_TCP = 6;
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
pub const IPPROTO_UDP = 17;
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
pub const IPPROTO_IPV6 = 41;
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
pub const IPPROTO_PIM = 103;
pub const IPPROTO_IPCOMP = 108;
pub const IPPROTO_CARP = 112;
pub const IPPROTO_PGM = 113;
pub const IPPROTO_PFSYNC = 240;
pub const IPPROTO_DIVERT = 254;
pub const IPPROTO_RAW = 255;
pub const IPPROTO_MAX = 256;
pub const IPPROTO_DONE = 257;
pub const IPPROTO_UNKNOWN = 258;

pub const IP_PORTRANGE_DEFAULT = 0;
pub const IP_DEFAULT_MULTICAST_TTL = 1;
pub const IP_DEFAULT_MULTICAST_LOOP = 1;
pub const IP_PORTRANGE_HIGH = 1;
pub const IP_OPTIONS = 1;
pub const IP_PORTRANGE_LOW = 2;
pub const IP_HDRINCL = 2;
pub const IP_TOS = 3;
pub const IP_TTL = 4;
pub const IP_RECVOPTS = 5;
pub const IP_RECVRETOPTS = 6;
pub const IP_RECVDSTADDR = 7;
pub const IP_RETOPTS = 8;
pub const IP_MULTICAST_IF = 9;
pub const IP_MULTICAST_TTL = 10;
pub const IP_MULTICAST_LOOP = 11;
pub const IP_ADD_MEMBERSHIP = 12;
pub const IP_DROP_MEMBERSHIP = 13;
pub const IP_MULTICAST_VIF = 14;
pub const IP_RSVP_ON = 15;
pub const IP_RSVP_OFF = 16;
pub const IP_RSVP_VIF_ON = 17;
pub const IP_RSVP_VIF_OFF = 18;
pub const IP_PORTRANGE = 19;
pub const IP_RECVIF = 20;
pub const IP_MAX_MEMBERSHIPS = 20;
pub const IP_FW_TBL_CREATE = 40;
pub const IP_FW_TBL_DESTROY = 41;
pub const IP_FW_TBL_ADD = 42;
pub const IP_FW_TBL_DEL = 43;
pub const IP_FW_TBL_FLUSH = 44;
pub const IP_FW_TBL_GET = 45;
pub const IP_FW_TBL_ZERO = 46;
pub const IP_FW_TBL_EXPIRE = 47;
pub const IP_FW_X = 49;
pub const IP_FW_ADD = 50;
pub const IP_FW_DEL = 51;
pub const IP_FW_FLUSH = 52;
pub const IP_FW_ZERO = 53;
pub const IP_FW_GET = 54;
pub const IP_FW_RESETLOG = 55;
pub const IP_DUMMYNET_CONFIGURE = 60;
pub const IP_DUMMYNET_DEL = 61;
pub const IP_DUMMYNET_FLUSH = 62;
pub const IP_DUMMYNET_GET = 64;
pub const IP_RECVTTL = 65;
pub const IP_MINTTL = 66;

pub const IPV6PORT_RESERVEDMAX = if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Pointer) @ptrCast(IPV6PORT_RESERVED, -1) else if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Int) @intToPtr(IPV6PORT_RESERVED, -1) else IPV6PORT_RESERVED(-1);
pub const IPV6PORT_RESERVEDMIN = 600;
pub const IPV6PORT_RESERVED = 1024;
pub const IPV6PORT_ANONMIN = 49152;
pub const IPV6PORT_ANONMAX = 65535;

pub const IPPORT_RESERVEDSTART = 600;
pub const IPPORT_RESERVED = 1024;
pub const IPPORT_USERRESERVED = 5000;
pub const IPPORT_HIFIRSTAUTO = 49152;
pub const IPPORT_HILASTAUTO = 65535;
pub const IPPORT_MAX = 65535;

pub const IPV6CTL_FORWARDING = 1;
pub const IPV6CTL_SENDREDIRECTS = 2;
pub const IPV6CTL_DEFHLIM = 3;
pub const IPV6CTL_FORWSRCRT = 5;
pub const IPV6CTL_STATS = 6;
pub const IPV6CTL_MRTSTATS = 7;
pub const IPV6CTL_MRTPROTO = 8;
pub const IPV6CTL_MAXFRAGPACKETS = 9;
pub const IPV6CTL_SOURCECHECK = 10;
pub const IPV6CTL_SOURCECHECK_LOGINT = 11;
pub const IPV6CTL_ACCEPT_RTADV = 12;
pub const IPV6CTL_LOG_INTERVAL = 14;
pub const IPV6CTL_HDRNESTLIMIT = 15;
pub const IPV6CTL_DAD_COUNT = 16;
pub const IPV6CTL_AUTO_FLOWLABEL = 17;
pub const IPV6CTL_DEFMCASTHLIM = 18;
pub const IPV6CTL_GIF_HLIM = 19;
pub const IPV6CTL_KAME_VERSION = 20;
pub const IPV6CTL_USE_DEPRECATED = 21;
pub const IPV6CTL_RR_PRUNE = 22;
pub const IPV6CTL_RTEXPIRE = 25;
pub const IPV6CTL_RTMINEXPIRE = 26;
pub const IPV6CTL_RTMAXCACHE = 27;
pub const IPV6CTL_USETEMPADDR = 32;
pub const IPV6CTL_TEMPPLTIME = 33;
pub const IPV6CTL_TEMPVLTIME = 34;
pub const IPV6CTL_AUTO_LINKLOCAL = 35;
pub const IPV6CTL_RIP6STATS = 36;
pub const IPV6CTL_ADDRCTLPOLICY = 38;
pub const IPV6CTL_MINHLIM = 39;
pub const IPV6CTL_MAXFRAGS = 41;
pub const IPV6CTL_MAXID = 48;

pub const IPCTL_FORWARDING = 1;
pub const IPCTL_SENDREDIRECTS = 2;
pub const IPCTL_DEFTTL = 3;
pub const IPCTL_RTEXPIRE = 5;
pub const IPCTL_RTMINEXPIRE = 6;
pub const IPCTL_RTMAXCACHE = 7;
pub const IPCTL_SOURCEROUTE = 8;
pub const IPCTL_DIRECTEDBROADCAST = 9;
pub const IPCTL_INTRQMAXLEN = 10;
pub const IPCTL_INTRQDROPS = 11;
pub const IPCTL_STATS = 12;
pub const IPCTL_ACCEPTSOURCEROUTE = 13;
pub const IPCTL_FASTFORWARDING = 14;
pub const IPCTL_GIF_TTL = 16;
pub const IPCTL_MAXID = 17;

pub const in_addr = extern struct {
    s_addr: in_addr_t,
};
pub const sockaddr_in = extern struct {
    sin_len: u8,
    sin_family: sa_family_t,
    sin_port: in_port_t,
    sin_addr: in_addr,
    sin_zero: [8]u8,
};
pub const ip_mreq = extern struct {
    imr_multiaddr: in_addr,
    imr_interface: in_addr,
};
pub const in6_addr = extern struct {
    __u6_addr: extern union {
        __u6_addr8: [16]u8,
        __u6_addr16: [8]u16,
        __u6_addr32: [4]u32,
    },
};
pub const sockaddr_in6 = extern struct {
    sin6_len: u8,
    sin6_family: sa_family_t,
    sin6_port: u16,
    sin6_flowinfo: u32,
    sin6_addr: in6_addr,
    sin6_scope_id: u32,
};
pub extern const in6addr_any: in6_addr;
pub extern const in6addr_loopback: in6_addr;
pub extern const in6addr_nodelocal_allnodes: in6_addr;
pub extern const in6addr_linklocal_allnodes: in6_addr;
pub const route_in6 = extern struct {
    ro_rt: ?*rtentry,
    ro_dst: sockaddr_in6,
};
pub const ipv6_mreq = extern struct {
    ipv6mr_multiaddr: in6_addr,
    ipv6mr_interface: c_uint,
};
pub const in6_pktinfo = extern struct {
    ipi6_addr: in6_addr,
    ipi6_ifindex: c_uint,
};
pub const ip6_mtuinfo = extern struct {
    ip6m_addr: sockaddr_in6,
    ip6m_mtu: u32,
};

pub const rtentry = @OpaqueType();
pub const INET_ADDRSTRLEN = 16;
pub const ICMP6_FILTER = 18;
pub const INET6_ADDRSTRLEN = 46;
pub const ICMPV6CTL_ND6_ONLINKNSRFC4861 = 47;
pub const INADDR_NONE = 4294967295;
pub const UIO_READ = enum_uio_rw.UIO_READ;
pub const UIO_WRITE = enum_uio_rw.UIO_WRITE;
pub const enum_uio_rw = extern enum {
    UIO_READ,
    UIO_WRITE,
};
pub const UIO_USERSPACE = enum_uio_seg.UIO_USERSPACE;
pub const UIO_SYSSPACE = enum_uio_seg.UIO_SYSSPACE;
pub const UIO_NOCOPY = enum_uio_seg.UIO_NOCOPY;
pub const enum_uio_seg = extern enum {
    UIO_USERSPACE,
    UIO_SYSSPACE,
    UIO_NOCOPY,
};

pub const VM_BCACHE_SIZE_MAX = 0;
pub const MAXUPRC = CHILD_MAX;
pub const DFLTPHYS = if (@typeId(@typeOf(1024)) == @import("builtin").TypeId.Pointer) @ptrCast([*c]64, 1024) else if (@typeId(@typeOf(1024)) == @import("builtin").TypeId.Int) @intToPtr([*c]64, 1024) else ([*c]64)(1024);
pub const PDPMASK = if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Pointer) @ptrCast(NBPDP, -1) else if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Int) @intToPtr(NBPDP, -1) else NBPDP(-1);
pub const QUAD_MIN = if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Pointer) @ptrCast(-c_longlong(9223372036854775807), -1) else if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Int) @intToPtr(-c_longlong(9223372036854775807), -1) else (-c_longlong(9223372036854775807))(-1);
pub const SIZE_T_MAX = c_ulong(18446744073709551615);
pub const SEG_MASK = if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Pointer) @ptrCast(SEG_SIZE, -1) else if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Int) @intToPtr(SEG_SIZE, -1) else SEG_SIZE(-1);
pub const MACHINE = c"x86_64";
pub const OFF_MIN = if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Pointer) @ptrCast(-c_long(9223372036854775807), -1) else if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Int) @intToPtr(-c_long(9223372036854775807), -1) else (-c_long(9223372036854775807))(-1);
pub const UID_MAX = c_uint(4294967295);
pub const MAXPATHLEN = PATH_MAX;
pub const PML4MASK = if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Pointer) @ptrCast(NPML4, -1) else if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Int) @intToPtr(NPML4, -1) else NPML4(-1);
pub const PML4_SIGNMASK = c_ulong(18446603336221196288);
pub const OFF_MAX = c_long(9223372036854775807);
pub const GID_MAX = c_uint(4294967295);
pub const QUAD_MAX = c_longlong(9223372036854775807);
pub const MAXCPU = SMP_MAXCPU;
pub const NCARGS = ARG_MAX;
pub const NZERO = 0;
pub const MCLOFSET = if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Pointer) @ptrCast(MCLBYTES, -1) else if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Int) @intToPtr(MCLBYTES, -1) else MCLBYTES(-1);
pub const UQUAD_MAX = c_ulonglong(18446744073709551615);
pub const MAXPHYS = if (@typeId(@typeOf(1024)) == @import("builtin").TypeId.Pointer) @ptrCast([*c]128, 1024) else if (@typeId(@typeOf(1024)) == @import("builtin").TypeId.Int) @intToPtr([*c]128, 1024) else ([*c]128)(1024);
pub const PDRMASK = if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Pointer) @ptrCast(NBPDR, -1) else if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Int) @intToPtr(NBPDR, -1) else NBPDR(-1);
pub const NGROUPS = NGROUPS_MAX;
pub const DEV_BMASK = if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Pointer) @ptrCast(DEV_BSIZE, -1) else if (@typeId(@typeOf(-1)) == @import("builtin").TypeId.Int) @intToPtr(DEV_BSIZE, -1) else DEV_BSIZE(-1);
pub const MJUM9BYTES = if (@typeId(@typeOf(1024)) == @import("builtin").TypeId.Pointer) @ptrCast([*c]9, 1024) else if (@typeId(@typeOf(1024)) == @import("builtin").TypeId.Int) @intToPtr([*c]9, 1024) else ([*c]9)(1024);
pub const NOFILE = OPEN_MAX;
pub const MJUM16BYTES = if (@typeId(@typeOf(1024)) == @import("builtin").TypeId.Pointer) @ptrCast([*c]16, 1024) else if (@typeId(@typeOf(1024)) == @import("builtin").TypeId.Int) @intToPtr([*c]16, 1024) else ([*c]16)(1024);
pub const uio_rw = enum_uio_rw;
pub const uio_seg = enum_uio_seg;
pub const CPU_MI_BZERONT = 1;
pub const IOPAGES = 2;
pub const UPAGES = 4;
pub const KSTACK_PAGES = 4;
pub const MINBUCKET = 4;
pub const MB_LEN_MAX = 6;
pub const MAXFRAG = 8;
pub const NPTEPGSHIFT = 9;
pub const NPDEPGSHIFT = 9;
pub const DEV_BSHIFT = 9;
pub const NPML4EPGSHIFT = 9;
pub const NPDPEPGSHIFT = 9;
pub const FSHIFT = 11;
pub const MCLSHIFT = 11;
pub const PAGE_SHIFT = 12;
pub const NGROUPS_MAX = 16;
pub const CPU_MI_MONITOR = 16;
pub const MAXCOMLEN = 16;
pub const MAXLOGNAME = 17;
pub const CMASK = 18;
pub const SEG_SHIFT = 21;
pub const PDRSHIFT = 21;
pub const PDPSHIFT = 30;
pub const MAXINTERP = 32;
pub const MAXSYMLINKS = 32;
pub const PML4SHIFT = 39;
pub const CHILD_MAX = 40;
pub const OPEN_MAX = 64;
pub const MAX_INPUT = 255;
pub const MAX_CANON = 255;
pub const NAME_MAX = 255;
pub const SMP_MAXCPU = 256;
pub const MAXHOSTNAMELEN = 256;
pub const PCATCH = 256;
pub const MSIZE = 512;
pub const PUSRFLAG1 = 512;
pub const PIPE_BUF = 512;
pub const IOV_MAX = 1024;
pub const PINTERLOCKED = 1024;
pub const PWAKEUP_CPUMASK = 16383;
pub const PWAKEUP_MYCPU = 16384;
pub const NBUFCALCSIZE = 16384;
pub const LINK_MAX = 32767;
pub const PWAKEUP_ONE = 32768;
pub const NOGROUP = 65535;
pub const MAXBSIZE = 65536;
pub const PDOMAIN_UMTX = 65536;
pub const PDOMAIN_XLOCK = 131072;
pub const ARG_MAX = 262144;
pub const PDOMAIN_MASK = 4294901760;

pub const INHERIT_SHARE = 0;
pub const INHERIT_COPY = 1;
pub const INHERIT_NONE = 2;

pub const MS_SYNC = 0;
pub const MS_ASYNC = 1;
pub const MS_INVALIDATE = 2;

pub const POSIX_MADV_SEQUENTIAL = 2;
pub const POSIX_MADV_RANDOM = 1;
pub const POSIX_MADV_DONTNEED = 4;
pub const POSIX_MADV_NORMAL = 0;
pub const POSIX_MADV_WILLNEED = 3;

pub const MINCORE_INCORE = 1;
pub const MINCORE_REFERENCED = 2;
pub const MINCORE_MODIFIED = 4;
pub const MINCORE_REFERENCED_OTHER = 8;
pub const MINCORE_MODIFIED_OTHER = 16;
pub const MINCORE_SUPER = 32;

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

pub const MCL_CURRENT = 1;
pub const MCL_FUTURE = 2;

pub const LOCK_SH = 1;
pub const LOCK_EX = 2;
pub const LOCK_NB = 4;
pub const LOCK_UN = 8;

pub const AT_SYMLINK_NOFOLLOW = 1;
pub const AT_REMOVEDIR = 2;
pub const AT_EACCESS = 4;
pub const AT_SYMLINK_FOLLOW = 8;
pub const AT_FDCWD = 4294639053;

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

pub const Flock = extern struct {
    l_start: off_t,
    l_len: off_t,
    l_pid: pid_t,
    l_type: c_short,
    l_whence: c_short,
};

pub const FAPPEND = O_APPEND;
pub const FNONBLOCK = O_NONBLOCK;
pub const FASYNC = O_ASYNC;
pub const FPOSIXSHM = O_NOFOLLOW;
pub const FFSYNC = O_FSYNC;
pub const FNDELAY = O_NONBLOCK;
pub const FREAD = 1;
pub const FD_CLOEXEC = 1;
pub const FWRITE = 2;

pub const PTHREAD_MUTEX_ERRORCHECK = enum_pthread_mutextype.PTHREAD_MUTEX_ERRORCHECK;
pub const PTHREAD_MUTEX_RECURSIVE = enum_pthread_mutextype.PTHREAD_MUTEX_RECURSIVE;
pub const PTHREAD_MUTEX_NORMAL = enum_pthread_mutextype.PTHREAD_MUTEX_NORMAL;
pub const PTHREAD_MUTEX_TYPE_MAX = enum_pthread_mutextype.PTHREAD_MUTEX_TYPE_MAX;
pub const PTHREAD_MUTEX_DEFAULT = PTHREAD_MUTEX_ERRORCHECK;
pub const PTHREAD_MUTEX_INITIALIZER = NULL;

pub const PTHREAD_PRIO_PROTECT = 2;
pub const PTHREAD_PRIO_INHERIT = 1;
pub const PTHREAD_PRIO_NONE = 0;

pub const PTHREAD_CANCELED = if (@typeId(@typeOf(1)) == @import("builtin").TypeId.Pointer) @ptrCast([*c]void, 1) else if (@typeId(@typeOf(1)) == @import("builtin").TypeId.Int) @intToPtr([*c]void, 1) else ([*c]void)(1);
pub const PTHREAD_CANCEL_DISABLE = 1;
pub const PTHREAD_CANCEL_ASYNCHRONOUS = 2;
pub const PTHREAD_CANCEL_ENABLE = 0;
pub const PTHREAD_CANCEL_DEFERRED = 0;

pub const PTHREAD_DONE_INIT = 1;
pub const PTHREAD_THREADS_MAX = c_ulong(18446744073709551615);
pub const PTHREAD_STACK_MIN = 16384;
pub const PTHREAD_COND_INITIALIZER = NULL;
pub const PTHREAD_EXPLICIT_SCHED = 0;
pub const PTHREAD_PROCESS_PRIVATE = 0;
pub const PTHREAD_CREATE_DETACHED = PTHREAD_DETACHED;
pub const PTHREAD_KEYS_MAX = 256;
pub const PTHREAD_RWLOCK_INITIALIZER = NULL;
pub const PTHREAD_SCOPE_PROCESS = 0;
pub const PTHREAD_DESTRUCTOR_ITERATIONS = 4;
pub const PTHREAD_NEEDS_INIT = 0;
pub const PTHREAD_DETACHED = 1;
pub const PTHREAD_PROCESS_SHARED = 1;
pub const PTHREAD_SCOPE_SYSTEM = 2;
pub const PTHREAD_NOFLOAT = 8;
pub const PTHREAD_INHERIT_SCHED = 4;
pub const PTHREAD_CREATE_JOINABLE = 0;
pub const PTHREAD_BARRIER_SERIAL_THREAD = -1;

pub const SCHED_OTHER = 2;
pub const SCHED_FIFO = 1;
pub const SCHED_RR = 3;

pub const sched_param = extern struct {
    sched_priority: c_int,
};
pub const cpu_set_t = cpumask_t;
pub const cpuset_t = cpumask_t;

pub const enum_pthread_mutextype = extern enum {
    PTHREAD_MUTEX_ERRORCHECK = 1,
    PTHREAD_MUTEX_RECURSIVE = 2,
    PTHREAD_MUTEX_NORMAL = 3,
    PTHREAD_MUTEX_TYPE_MAX = 4,
};
pub const pthread_mutex_t = @OpaqueType();
pub const pthread_mutexattr_t = @OpaqueType();
pub const pthread_cond_t = @OpaqueType();
pub const pthread_condattr_t = @OpaqueType();
pub const pthread_key_t = c_int;
pub const pthread_once_t = Pthread_once;
pub const pthread_rwlock_t = @OpaqueType();
pub const pthread_rwlockattr_t = @OpaqueType();
pub const pthread_barrier_t = @OpaqueType();
pub const pthread_barrierattr_t = @OpaqueType();
pub const pthread_spinlock_t = @OpaqueType();
pub const pthread_addr_t = ?*c_void;
pub const pthread_startroutine_t = ?extern fn(?*c_void) ?*c_void;
pub const pthread_attr = @OpaqueType();
pub const pthread_cond = @OpaqueType();
pub const pthread_cond_attr = @OpaqueType();
pub const pthread_mutex = @OpaqueType();
pub const pthread_mutex_attr = @OpaqueType();
pub const pthread_rwlock = @OpaqueType();
pub const pthread_rwlockattr = @OpaqueType();
pub const pthread_barrier = @OpaqueType();
pub const pthread_barrier_attr = @OpaqueType();
pub const pthread_spinlock = @OpaqueType();
pub const pthread_barrierattr = @OpaqueType();

pub const pthread_mutexattr_default = NULL;
pub const pthread_attr_default = NULL;
pub const pthread_condattr_default = NULL;
pub const pthread_mutextype = enum_pthread_mutextype;
