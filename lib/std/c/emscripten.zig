const std = @import("../std.zig");
const maxInt = std.math.maxInt;
const emscripten = std.os.emscripten;

pub const AF = emscripten.AF;
pub const CLOCK = emscripten.CLOCK;
pub const CPU_COUNT = emscripten.CPU_COUNT;
pub const E = emscripten.E;
pub const F = emscripten.F;
pub const FD_CLOEXEC = emscripten.FD_CLOEXEC;
pub const F_OK = emscripten.F_OK;
pub const Flock = emscripten.Flock;
pub const IFNAMESIZE = emscripten.IFNAMESIZE;
pub const IOV_MAX = emscripten.IOV_MAX;
pub const IPPROTO = emscripten.IPPROTO;
pub const LOCK = emscripten.LOCK;
pub const MADV = emscripten.MADV;
pub const MSF = emscripten.MSF;
pub const MSG = emscripten.MSG;
pub const NAME_MAX = emscripten.NAME_MAX;
pub const PATH_MAX = emscripten.PATH_MAX;
pub const POLL = emscripten.POLL;
pub const PROT = emscripten.PROT;
pub const REG = emscripten.REG;
pub const RLIM = emscripten.RLIM;
pub const R_OK = emscripten.R_OK;
pub const S = emscripten.S;
pub const SA = emscripten.SA;
pub const SEEK = emscripten.SEEK;
pub const SHUT = emscripten.SHUT;
pub const SIG = emscripten.SIG;
pub const SIOCGIFINDEX = emscripten.SIOCGIFINDEX;
pub const SO = emscripten.SO;
pub const SOCK = emscripten.SOCK;
pub const SOL = emscripten.SOL;
pub const STDERR_FILENO = emscripten.STDERR_FILENO;
pub const STDIN_FILENO = emscripten.STDIN_FILENO;
pub const STDOUT_FILENO = emscripten.STDOUT_FILENO;
pub const Sigaction = emscripten.Sigaction;
pub const TCP = emscripten.TCP;
pub const TCSA = emscripten.TCSA;
pub const W = emscripten.W;
pub const W_OK = emscripten.W_OK;
pub const X_OK = emscripten.X_OK;
pub const addrinfo = emscripten.addrinfo;
pub const blkcnt_t = emscripten.blkcnt_t;
pub const blksize_t = emscripten.blksize_t;
pub const clock_t = emscripten.clock_t;
pub const cpu_set_t = emscripten.cpu_set_t;
pub const dev_t = emscripten.dev_t;
pub const dl_phdr_info = emscripten.dl_phdr_info;
pub const empty_sigset = emscripten.empty_sigset;
pub const fd_t = emscripten.fd_t;
pub const gid_t = emscripten.gid_t;
pub const ifreq = emscripten.ifreq;
pub const ino_t = emscripten.ino_t;
pub const mcontext_t = emscripten.mcontext_t;
pub const mode_t = emscripten.mode_t;
pub const msghdr = emscripten.msghdr;
pub const msghdr_const = emscripten.msghdr_const;
pub const nfds_t = emscripten.nfds_t;
pub const nlink_t = emscripten.nlink_t;
pub const off_t = emscripten.off_t;
pub const pid_t = emscripten.pid_t;
pub const pollfd = emscripten.pollfd;
pub const rlim_t = emscripten.rlim_t;
pub const rlimit = emscripten.rlimit;
pub const rlimit_resource = emscripten.rlimit_resource;
pub const rusage = emscripten.rusage;
pub const siginfo_t = emscripten.siginfo_t;
pub const sigset_t = emscripten.sigset_t;
pub const sockaddr = emscripten.sockaddr;
pub const socklen_t = emscripten.socklen_t;
pub const stack_t = emscripten.stack_t;
pub const time_t = emscripten.time_t;
pub const timespec = emscripten.timespec;
pub const timeval = emscripten.timeval;
pub const timezone = emscripten.timezone;
pub const ucontext_t = emscripten.ucontext_t;
pub const uid_t = emscripten.uid_t;
pub const utsname = emscripten.utsname;

pub const _errno = struct {
    extern "c" fn __errno_location() *c_int;
}.__errno_location;

pub const Stat = emscripten.Stat;

pub const AI = struct {
    pub const PASSIVE = 0x01;
    pub const CANONNAME = 0x02;
    pub const NUMERICHOST = 0x04;
    pub const V4MAPPED = 0x08;
    pub const ALL = 0x10;
    pub const ADDRCONFIG = 0x20;
    pub const NUMERICSERV = 0x400;
};

pub const NI = struct {
    pub const NUMERICHOST = 0x01;
    pub const NUMERICSERV = 0x02;
    pub const NOFQDN = 0x04;
    pub const NAMEREQD = 0x08;
    pub const DGRAM = 0x10;
    pub const NUMERICSCOPE = 0x100;
    pub const MAXHOST = 255;
    pub const MAXSERV = 32;
};

pub const EAI = enum(c_int) {
    BADFLAGS = -1,
    NONAME = -2,
    AGAIN = -3,
    FAIL = -4,
    FAMILY = -6,
    SOCKTYPE = -7,
    SERVICE = -8,
    MEMORY = -10,
    SYSTEM = -11,
    OVERFLOW = -12,

    NODATA = -5,
    ADDRFAMILY = -9,
    INPROGRESS = -100,
    CANCELED = -101,
    NOTCANCELED = -102,
    ALLDONE = -103,
    INTR = -104,
    IDN_ENCODE = -105,

    _,
};

pub const fopen64 = std.c.fopen;
pub const fstat64 = std.c.fstat;
pub const fstatat64 = std.c.fstatat;
pub const ftruncate64 = std.c.ftruncate;
pub const getrlimit64 = std.c.getrlimit;
pub const lseek64 = std.c.lseek;
pub const mmap64 = std.c.mmap;
pub const open64 = std.c.open;
pub const openat64 = std.c.openat;
pub const pread64 = std.c.pread;
pub const preadv64 = std.c.preadv;
pub const pwrite64 = std.c.pwrite;
pub const pwritev64 = std.c.pwritev;
pub const setrlimit64 = std.c.setrlimit;

pub extern "c" fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) c_int;
pub extern "c" fn pipe2(fds: *[2]fd_t, flags: std.c.O) c_int;
pub extern "c" fn getentropy(buffer: [*]u8, size: usize) c_int;

pub const pthread_attr_t = extern struct {
    __size: [56]u8,
    __align: c_long,
};

pub const pthread_key_t = c_uint;
pub const sem_t = extern struct {
    __size: [__SIZEOF_SEM_T]u8 align(@alignOf(usize)),
};

const __SIZEOF_SEM_T = 4 * @sizeOf(usize);

pub const RTLD = struct {
    pub const LAZY = 1;
    pub const NOW = 2;
    pub const NOLOAD = 4;
    pub const NODELETE = 4096;
    pub const GLOBAL = 256;
    pub const LOCAL = 0;
};

pub const dirent = struct {
    ino: c_uint,
    off: c_uint,
    reclen: c_ushort,
    type: u8,
    name: [256]u8,
};
