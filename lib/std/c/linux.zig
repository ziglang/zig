const std = @import("../std.zig");
const builtin = @import("builtin");
const maxInt = std.math.maxInt;
const native_abi = builtin.abi;
const native_arch = builtin.cpu.arch;
const linux = std.os.linux;
const iovec = std.os.iovec;
const iovec_const = std.os.iovec_const;
const FILE = std.c.FILE;

pub const AF = linux.AF;
pub const ARCH = linux.ARCH;
pub const AT = linux.AT;
pub const CLOCK = linux.CLOCK;
pub const CPU_COUNT = linux.CPU_COUNT;
pub const E = linux.E;
pub const Elf_Symndx = linux.Elf_Symndx;
pub const F = linux.F;
pub const FD_CLOEXEC = linux.FD_CLOEXEC;
pub const F_OK = linux.F_OK;
pub const Flock = linux.Flock;
pub const HOST_NAME_MAX = linux.HOST_NAME_MAX;
pub const IFNAMESIZE = linux.IFNAMESIZE;
pub const IOV_MAX = linux.IOV_MAX;
pub const IPPROTO = linux.IPPROTO;
pub const LOCK = linux.LOCK;
pub const MADV = linux.MADV;
pub const MAP = struct {
    pub usingnamespace linux.MAP;
    /// Only used by libc to communicate failure.
    pub const FAILED = @as(*anyopaque, @ptrFromInt(maxInt(usize)));
};
pub const MSF = linux.MSF;
pub const MMAP2_UNIT = linux.MMAP2_UNIT;
pub const MSG = linux.MSG;
pub const NAME_MAX = linux.NAME_MAX;
pub const O = linux.O;
pub const PATH_MAX = linux.PATH_MAX;
pub const POLL = linux.POLL;
pub const PROT = linux.PROT;
pub const REG = linux.REG;
pub const RLIM = linux.RLIM;
pub const R_OK = linux.R_OK;
pub const S = linux.S;
pub const SA = linux.SA;
pub const SC = linux.SC;
pub const SEEK = linux.SEEK;
pub const SHUT = linux.SHUT;
pub const SIG = linux.SIG;
pub const SIOCGIFINDEX = linux.SIOCGIFINDEX;
pub const SO = linux.SO;
pub const SOCK = linux.SOCK;
pub const SOL = linux.SOL;
pub const STDERR_FILENO = linux.STDERR_FILENO;
pub const STDIN_FILENO = linux.STDIN_FILENO;
pub const STDOUT_FILENO = linux.STDOUT_FILENO;
pub const SYS = linux.SYS;
pub const Sigaction = linux.Sigaction;
pub const TCP = linux.TCP;
pub const TCSA = linux.TCSA;
pub const VDSO = linux.VDSO;
pub const W = linux.W;
pub const W_OK = linux.W_OK;
pub const X_OK = linux.X_OK;
pub const addrinfo = linux.addrinfo;
pub const blkcnt_t = linux.blkcnt_t;
pub const blksize_t = linux.blksize_t;
pub const clock_t = linux.clock_t;
pub const cpu_set_t = linux.cpu_set_t;
pub const dev_t = linux.dev_t;
pub const dl_phdr_info = linux.dl_phdr_info;
pub const empty_sigset = linux.empty_sigset;
pub const epoll_event = linux.epoll_event;
pub const fd_t = linux.fd_t;
pub const gid_t = linux.gid_t;
pub const ifreq = linux.ifreq;
pub const ino_t = linux.ino_t;
pub const mcontext_t = linux.mcontext_t;
pub const mode_t = linux.mode_t;
pub const msghdr = linux.msghdr;
pub const msghdr_const = linux.msghdr_const;
pub const nfds_t = linux.nfds_t;
pub const nlink_t = linux.nlink_t;
pub const off_t = linux.off_t;
pub const pid_t = linux.pid_t;
pub const pollfd = linux.pollfd;
pub const rlim_t = linux.rlim_t;
pub const rlimit = linux.rlimit;
pub const rlimit_resource = linux.rlimit_resource;
pub const rusage = linux.rusage;
pub const siginfo_t = linux.siginfo_t;
pub const sigset_t = linux.sigset_t;
pub const sockaddr = linux.sockaddr;
pub const socklen_t = linux.socklen_t;
pub const stack_t = linux.stack_t;
pub const tcflag_t = linux.tcflag_t;
pub const termios = linux.termios;
pub const time_t = linux.time_t;
pub const timespec = linux.timespec;
pub const timeval = linux.timeval;
pub const timezone = linux.timezone;
pub const ucontext_t = linux.ucontext_t;
pub const uid_t = linux.uid_t;
pub const user_desc = linux.user_desc;
pub const utsname = linux.utsname;
pub const PR = linux.PR;

pub const _errno = switch (native_abi) {
    .android => struct {
        extern fn __errno() *c_int;
    }.__errno,
    else => struct {
        extern "c" fn __errno_location() *c_int;
    }.__errno_location,
};

pub const Stat = switch (native_arch) {
    .sparc64 => extern struct {
        dev: u64,
        __pad1: u16,
        ino: ino_t,
        mode: u32,
        nlink: u32,

        uid: u32,
        gid: u32,
        rdev: u64,
        __pad2: u16,

        size: off_t,
        blksize: isize,
        blocks: i64,

        atim: timespec,
        mtim: timespec,
        ctim: timespec,
        __reserved: [2]usize,

        pub fn atime(self: @This()) timespec {
            return self.atim;
        }

        pub fn mtime(self: @This()) timespec {
            return self.mtim;
        }

        pub fn ctime(self: @This()) timespec {
            return self.ctim;
        }
    },
    .mips, .mipsel => extern struct {
        dev: dev_t,
        __pad0: [2]u32,
        ino: ino_t,
        mode: mode_t,
        nlink: nlink_t,
        uid: uid_t,
        gid: gid_t,
        rdev: dev_t,
        __pad1: [2]u32,
        size: off_t,
        atim: timespec,
        mtim: timespec,
        ctim: timespec,
        blksize: blksize_t,
        __pad3: u32,
        blocks: blkcnt_t,
        __pad4: [14]u32,

        pub fn atime(self: @This()) timespec {
            return self.atim;
        }

        pub fn mtime(self: @This()) timespec {
            return self.mtim;
        }

        pub fn ctime(self: @This()) timespec {
            return self.ctim;
        }
    },

    else => std.os.linux.Stat, // libc stat is the same as kernel stat.
};

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

pub extern "c" fn fallocate64(fd: fd_t, mode: c_int, offset: off_t, len: off_t) c_int;
pub extern "c" fn fopen64(noalias filename: [*:0]const u8, noalias modes: [*:0]const u8) ?*FILE;
pub extern "c" fn fstat64(fd: fd_t, buf: *Stat) c_int;
pub extern "c" fn fstatat64(dirfd: fd_t, noalias path: [*:0]const u8, noalias stat_buf: *Stat, flags: u32) c_int;
pub extern "c" fn ftruncate64(fd: c_int, length: off_t) c_int;
pub extern "c" fn getrlimit64(resource: rlimit_resource, rlim: *rlimit) c_int;
pub extern "c" fn lseek64(fd: fd_t, offset: i64, whence: c_int) i64;
pub extern "c" fn mmap64(addr: ?*align(std.mem.page_size) anyopaque, len: usize, prot: c_uint, flags: c_uint, fd: fd_t, offset: i64) *anyopaque;
pub extern "c" fn open64(path: [*:0]const u8, oflag: c_uint, ...) c_int;
pub extern "c" fn openat64(fd: c_int, path: [*:0]const u8, oflag: c_uint, ...) c_int;
pub extern "c" fn pread64(fd: fd_t, buf: [*]u8, nbyte: usize, offset: i64) isize;
pub extern "c" fn preadv64(fd: c_int, iov: [*]const iovec, iovcnt: c_uint, offset: i64) isize;
pub extern "c" fn pwrite64(fd: fd_t, buf: [*]const u8, nbyte: usize, offset: i64) isize;
pub extern "c" fn pwritev64(fd: c_int, iov: [*]const iovec_const, iovcnt: c_uint, offset: i64) isize;
pub extern "c" fn sendfile64(out_fd: fd_t, in_fd: fd_t, offset: ?*i64, count: usize) isize;
pub extern "c" fn setrlimit64(resource: rlimit_resource, rlim: *const rlimit) c_int;

pub extern "c" fn getrandom(buf_ptr: [*]u8, buf_len: usize, flags: c_uint) isize;
pub extern "c" fn sched_getaffinity(pid: c_int, size: usize, set: *cpu_set_t) c_int;
pub extern "c" fn eventfd(initval: c_uint, flags: c_uint) c_int;
pub extern "c" fn epoll_ctl(epfd: fd_t, op: c_uint, fd: fd_t, event: ?*epoll_event) c_int;
pub extern "c" fn epoll_create1(flags: c_uint) c_int;
pub extern "c" fn epoll_wait(epfd: fd_t, events: [*]epoll_event, maxevents: c_uint, timeout: c_int) c_int;
pub extern "c" fn epoll_pwait(
    epfd: fd_t,
    events: [*]epoll_event,
    maxevents: c_int,
    timeout: c_int,
    sigmask: *const sigset_t,
) c_int;
pub extern "c" fn inotify_init1(flags: c_uint) c_int;
pub extern "c" fn inotify_add_watch(fd: fd_t, pathname: [*:0]const u8, mask: u32) c_int;
pub extern "c" fn inotify_rm_watch(fd: fd_t, wd: c_int) c_int;

/// See std.elf for constants for this
pub extern "c" fn getauxval(__type: c_ulong) c_ulong;

pub const dl_iterate_phdr_callback = *const fn (info: *dl_phdr_info, size: usize, data: ?*anyopaque) callconv(.C) c_int;

pub extern "c" fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*anyopaque) c_int;

pub extern "c" fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) c_int;

pub extern "c" fn memfd_create(name: [*:0]const u8, flags: c_uint) c_int;
pub extern "c" fn pipe2(fds: *[2]fd_t, flags: u32) c_int;

pub extern "c" fn fallocate(fd: fd_t, mode: c_int, offset: off_t, len: off_t) c_int;

pub extern "c" fn sendfile(
    out_fd: fd_t,
    in_fd: fd_t,
    offset: ?*off_t,
    count: usize,
) isize;

pub extern "c" fn copy_file_range(fd_in: fd_t, off_in: ?*i64, fd_out: fd_t, off_out: ?*i64, len: usize, flags: c_uint) isize;

pub extern "c" fn signalfd(fd: fd_t, mask: *const sigset_t, flags: c_uint) c_int;

pub extern "c" fn prlimit(pid: pid_t, resource: rlimit_resource, new_limit: *const rlimit, old_limit: *rlimit) c_int;
pub extern "c" fn posix_memalign(memptr: *?*anyopaque, alignment: usize, size: usize) c_int;
pub extern "c" fn malloc_usable_size(?*const anyopaque) usize;

pub extern "c" fn mincore(
    addr: *align(std.mem.page_size) anyopaque,
    length: usize,
    vec: [*]u8,
) c_int;

pub extern "c" fn madvise(
    addr: *align(std.mem.page_size) anyopaque,
    length: usize,
    advice: c_uint,
) c_int;

pub const pthread_attr_t = extern struct {
    __size: [56]u8,
    __align: c_long,
};

pub const pthread_mutex_t = extern struct {
    size: [__SIZEOF_PTHREAD_MUTEX_T]u8 align(@alignOf(usize)) = [_]u8{0} ** __SIZEOF_PTHREAD_MUTEX_T,
};
pub const pthread_cond_t = extern struct {
    size: [__SIZEOF_PTHREAD_COND_T]u8 align(@alignOf(usize)) = [_]u8{0} ** __SIZEOF_PTHREAD_COND_T,
};
pub const pthread_rwlock_t = switch (native_abi) {
    .android => switch (@sizeOf(usize)) {
        4 => extern struct {
            size: [40]u8 align(@alignOf(usize)) = [_]u8{0} ** 40,
        },
        8 => extern struct {
            size: [56]u8 align(@alignOf(usize)) = [_]u8{0} ** 56,
        },
        else => @compileError("impossible pointer size"),
    },
    else => extern struct {
        size: [56]u8 align(@alignOf(usize)) = [_]u8{0} ** 56,
    },
};
pub const pthread_key_t = c_uint;
pub const sem_t = extern struct {
    __size: [__SIZEOF_SEM_T]u8 align(@alignOf(usize)),
};

const __SIZEOF_PTHREAD_COND_T = 48;
const __SIZEOF_PTHREAD_MUTEX_T = switch (native_abi) {
    .musl, .musleabi, .musleabihf => if (@sizeOf(usize) == 8) 40 else 24,
    .gnu, .gnuabin32, .gnuabi64, .gnueabi, .gnueabihf, .gnux32 => switch (native_arch) {
        .aarch64 => 48,
        .x86_64 => if (native_abi == .gnux32) 40 else 32,
        .mips64, .powerpc64, .powerpc64le, .sparc64 => 40,
        else => if (@sizeOf(usize) == 8) 40 else 24,
    },
    .android => if (@sizeOf(usize) == 8) 40 else 4,
    else => @compileError("unsupported ABI"),
};
const __SIZEOF_SEM_T = 4 * @sizeOf(usize);

pub extern "c" fn pthread_setname_np(thread: std.c.pthread_t, name: [*:0]const u8) E;
pub extern "c" fn pthread_getname_np(thread: std.c.pthread_t, name: [*:0]u8, len: usize) E;

pub const RTLD = struct {
    pub const LAZY = 1;
    pub const NOW = 2;
    pub const NOLOAD = 4;
    pub const NODELETE = 4096;
    pub const GLOBAL = 256;
    pub const LOCAL = 0;
};

pub const dirent = struct {
    d_ino: c_uint,
    d_off: c_uint,
    d_reclen: c_ushort,
    d_type: u8,
    d_name: [256]u8,
};
pub const dirent64 = struct {
    d_ino: c_ulong,
    d_off: c_ulong,
    d_reclen: c_ushort,
    d_type: u8,
    d_name: [256]u8,
};
