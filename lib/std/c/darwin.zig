const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const macho = std.macho;
const native_arch = builtin.target.cpu.arch;
const maxInt = std.math.maxInt;
const iovec_const = std.os.iovec_const;

extern "c" fn __error() *c_int;
pub extern "c" fn NSVersionOfRunTimeLibrary(library_name: [*:0]const u8) u32;
pub extern "c" fn _NSGetExecutablePath(buf: [*:0]u8, bufsize: *u32) c_int;
pub extern "c" fn _dyld_image_count() u32;
pub extern "c" fn _dyld_get_image_header(image_index: u32) ?*mach_header;
pub extern "c" fn _dyld_get_image_vmaddr_slide(image_index: u32) usize;
pub extern "c" fn _dyld_get_image_name(image_index: u32) [*:0]const u8;

pub const COPYFILE_ACL = 1 << 0;
pub const COPYFILE_STAT = 1 << 1;
pub const COPYFILE_XATTR = 1 << 2;
pub const COPYFILE_DATA = 1 << 3;

pub const copyfile_state_t = *opaque {};
pub extern "c" fn fcopyfile(from: fd_t, to: fd_t, state: ?copyfile_state_t, flags: u32) c_int;

pub extern "c" fn @"realpath$DARWIN_EXTSN"(noalias file_name: [*:0]const u8, noalias resolved_name: [*]u8) ?[*:0]u8;
pub const realpath = @"realpath$DARWIN_EXTSN";

pub extern "c" fn __getdirentries64(fd: c_int, buf_ptr: [*]u8, buf_len: usize, basep: *i64) isize;

const private = struct {
    extern "c" fn fstat(fd: fd_t, buf: *Stat) c_int;
    /// On x86_64 Darwin, fstat has to be manully linked with $INODE64 suffix to
    /// force 64bit version.
    /// Note that this is fixed on aarch64 and no longer necessary.
    extern "c" fn @"fstat$INODE64"(fd: fd_t, buf: *Stat) c_int;

    extern "c" fn fstatat(dirfd: fd_t, path: [*:0]const u8, stat_buf: *Stat, flags: u32) c_int;
    /// On x86_64 Darwin, fstatat has to be manully linked with $INODE64 suffix to
    /// force 64bit version.
    /// Note that this is fixed on aarch64 and no longer necessary.
    extern "c" fn @"fstatat$INODE64"(dirfd: fd_t, path_name: [*:0]const u8, buf: *Stat, flags: u32) c_int;
};
pub const fstat = if (native_arch == .aarch64) private.fstat else private.@"fstat$INODE64";
pub const fstatat = if (native_arch == .aarch64) private.fstatat else private.@"fstatat$INODE64";

pub extern "c" fn mach_absolute_time() u64;
pub extern "c" fn mach_timebase_info(tinfo: ?*mach_timebase_info_data) void;

pub extern "c" fn malloc_size(?*const anyopaque) usize;
pub extern "c" fn posix_memalign(memptr: *?*anyopaque, alignment: usize, size: usize) c_int;

pub extern "c" fn kevent64(
    kq: c_int,
    changelist: [*]const kevent64_s,
    nchanges: c_int,
    eventlist: [*]kevent64_s,
    nevents: c_int,
    flags: c_uint,
    timeout: ?*const timespec,
) c_int;

const mach_hdr = if (@sizeOf(usize) == 8) mach_header_64 else mach_header;

/// The value of the link editor defined symbol _MH_EXECUTE_SYM is the address
/// of the mach header in a Mach-O executable file type.  It does not appear in
/// any file type other than a MH_EXECUTE file type.  The type of the symbol is
/// absolute as the header is not part of any section.
/// This symbol is populated when linking the system's libc, which is guaranteed
/// on this operating system. However when building object files or libraries,
/// the system libc won't be linked until the final executable. So we
/// export a weak symbol here, to be overridden by the real one.
var dummy_execute_header: mach_hdr = undefined;
pub extern var _mh_execute_header: mach_hdr;
comptime {
    if (builtin.target.isDarwin()) {
        @export(dummy_execute_header, .{ .name = "_mh_execute_header", .linkage = .Weak });
    }
}

pub const mach_header_64 = macho.mach_header_64;
pub const mach_header = macho.mach_header;

pub const _errno = __error;

pub extern "c" fn @"close$NOCANCEL"(fd: fd_t) c_int;
pub extern "c" fn mach_host_self() mach_port_t;
pub extern "c" fn clock_get_time(clock_serv: clock_serv_t, cur_time: *mach_timespec_t) kern_return_t;

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
    len: *off_t,
    sf_hdtr: ?*sf_hdtr,
    flags: u32,
) c_int;

pub fn sigaddset(set: *sigset_t, signo: u5) void {
    set.* |= @as(u32, 1) << (signo - 1);
}

pub extern "c" fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) c_int;

pub const AI = struct {
    /// get address to use bind()
    pub const PASSIVE = 0x00000001;
    /// fill ai_canonname
    pub const CANONNAME = 0x00000002;
    /// prevent host name resolution
    pub const NUMERICHOST = 0x00000004;
    /// prevent service name resolution
    pub const NUMERICSERV = 0x00001000;
};

pub const EAI = enum(c_int) {
    /// address family for hostname not supported
    ADDRFAMILY = 1,

    /// temporary failure in name resolution
    AGAIN = 2,

    /// invalid value for ai_flags
    BADFLAGS = 3,

    /// non-recoverable failure in name resolution
    FAIL = 4,

    /// ai_family not supported
    FAMILY = 5,

    /// memory allocation failure
    MEMORY = 6,

    /// no address associated with hostname
    NODATA = 7,

    /// hostname nor servname provided, or not known
    NONAME = 8,

    /// servname not supported for ai_socktype
    SERVICE = 9,

    /// ai_socktype not supported
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

pub const pthread_mutex_t = extern struct {
    __sig: c_long = 0x32AAABA7,
    __opaque: [__PTHREAD_MUTEX_SIZE__]u8 = [_]u8{0} ** __PTHREAD_MUTEX_SIZE__,
};
pub const pthread_cond_t = extern struct {
    __sig: c_long = 0x3CB0B1BB,
    __opaque: [__PTHREAD_COND_SIZE__]u8 = [_]u8{0} ** __PTHREAD_COND_SIZE__,
};
pub const pthread_rwlock_t = extern struct {
    __sig: c_long = 0x2DA8B3B4,
    __opaque: [192]u8 = [_]u8{0} ** 192,
};
pub const sem_t = c_int;
const __PTHREAD_MUTEX_SIZE__ = if (@sizeOf(usize) == 8) 56 else 40;
const __PTHREAD_COND_SIZE__ = if (@sizeOf(usize) == 8) 40 else 24;

pub const pthread_attr_t = extern struct {
    __sig: c_long,
    __opaque: [56]u8,
};

const pthread_t = std.c.pthread_t;
pub extern "c" fn pthread_threadid_np(thread: ?pthread_t, thread_id: *u64) c_int;
pub extern "c" fn pthread_setname_np(name: [*:0]const u8) E;
pub extern "c" fn pthread_getname_np(thread: std.c.pthread_t, name: [*:0]u8, len: usize) E;

pub extern "c" fn arc4random_buf(buf: [*]u8, len: usize) void;

// Grand Central Dispatch is exposed by libSystem.
pub extern "c" fn dispatch_release(object: *anyopaque) void;

pub const dispatch_semaphore_t = *opaque {};
pub extern "c" fn dispatch_semaphore_create(value: isize) ?dispatch_semaphore_t;
pub extern "c" fn dispatch_semaphore_wait(dsema: dispatch_semaphore_t, timeout: dispatch_time_t) isize;
pub extern "c" fn dispatch_semaphore_signal(dsema: dispatch_semaphore_t) isize;

pub const dispatch_time_t = u64;
pub const DISPATCH_TIME_NOW = @as(dispatch_time_t, 0);
pub const DISPATCH_TIME_FOREVER = ~@as(dispatch_time_t, 0);
pub extern "c" fn dispatch_time(when: dispatch_time_t, delta: i64) dispatch_time_t;

const dispatch_once_t = usize;
const dispatch_function_t = fn (?*anyopaque) callconv(.C) void;
pub extern fn dispatch_once_f(
    predicate: *dispatch_once_t,
    context: ?*anyopaque,
    function: dispatch_function_t,
) void;

// Undocumented futex-like API available on darwin 16+
// (macOS 10.12+, iOS 10.0+, tvOS 10.0+, watchOS 3.0+, catalyst 13.0+).
//
// [ulock.h]: https://github.com/apple/darwin-xnu/blob/master/bsd/sys/ulock.h
// [sys_ulock.c]: https://github.com/apple/darwin-xnu/blob/master/bsd/kern/sys_ulock.c

pub const UL_COMPARE_AND_WAIT = 1;
pub const UL_UNFAIR_LOCK = 2;

// Obsolete/deprecated
pub const UL_OSSPINLOCK = UL_COMPARE_AND_WAIT;
pub const UL_HANDOFFLOCK = UL_UNFAIR_LOCK;

pub const ULF_WAKE_ALL = 0x100;
pub const ULF_WAKE_THREAD = 0x200;
pub const ULF_WAIT_WORKQ_DATA_CONTENTION = 0x10000;
pub const ULF_WAIT_CANCEL_POINT = 0x20000;
pub const ULF_NO_ERRNO = 0x1000000;

// The following are only supported on darwin 19+
// (macOS 10.15+, iOS 13.0+)
pub const UL_COMPARE_AND_WAIT_SHARED = 3;
pub const UL_UNFAIR_LOCK64_SHARED = 4;
pub const UL_COMPARE_AND_WAIT64 = 5;
pub const UL_COMPARE_AND_WAIT64_SHARED = 6;
pub const ULF_WAIT_ADAPTIVE_SPIN = 0x40000;

pub extern "c" fn __ulock_wait2(op: u32, addr: ?*const anyopaque, val: u64, timeout_ns: u64, val2: u64) c_int;
pub extern "c" fn __ulock_wait(op: u32, addr: ?*const anyopaque, val: u64, timeout_us: u32) c_int;
pub extern "c" fn __ulock_wake(op: u32, addr: ?*const anyopaque, val: u64) c_int;

pub const OS_UNFAIR_LOCK_INIT = os_unfair_lock{};
pub const os_unfair_lock_t = *os_unfair_lock;
pub const os_unfair_lock = extern struct {
    _os_unfair_lock_opaque: u32 = 0,
};

pub extern "c" fn os_unfair_lock_lock(o: os_unfair_lock_t) void;
pub extern "c" fn os_unfair_lock_unlock(o: os_unfair_lock_t) void;
pub extern "c" fn os_unfair_lock_trylock(o: os_unfair_lock_t) bool;
pub extern "c" fn os_unfair_lock_assert_owner(o: os_unfair_lock_t) void;
pub extern "c" fn os_unfair_lock_assert_not_owner(o: os_unfair_lock_t) void;

// XXX: close -> close$NOCANCEL
// XXX: getdirentries -> _getdirentries64
pub extern "c" fn clock_getres(clk_id: c_int, tp: *timespec) c_int;
pub extern "c" fn clock_gettime(clk_id: c_int, tp: *timespec) c_int;
pub extern "c" fn getrusage(who: c_int, usage: *rusage) c_int;
pub extern "c" fn gettimeofday(noalias tv: ?*timeval, noalias tz: ?*timezone) c_int;
pub extern "c" fn nanosleep(rqtp: *const timespec, rmtp: ?*timespec) c_int;
pub extern "c" fn sched_yield() c_int;
pub extern "c" fn sigaction(sig: c_int, noalias act: ?*const Sigaction, noalias oact: ?*Sigaction) c_int;
pub extern "c" fn sigprocmask(how: c_int, noalias set: ?*const sigset_t, noalias oset: ?*sigset_t) c_int;
pub extern "c" fn socket(domain: c_uint, sock_type: c_uint, protocol: c_uint) c_int;
pub extern "c" fn stat(noalias path: [*:0]const u8, noalias buf: *Stat) c_int;
pub extern "c" fn sigfillset(set: ?*sigset_t) void;
pub extern "c" fn alarm(seconds: c_uint) c_uint;
pub extern "c" fn sigwait(set: ?*sigset_t, sig: ?*c_int) c_int;

// See: https://opensource.apple.com/source/xnu/xnu-6153.141.1/bsd/sys/_types.h.auto.html
// TODO: audit mode_t/pid_t, should likely be u16/i32
pub const fd_t = c_int;
pub const pid_t = c_int;
pub const mode_t = c_uint;
pub const uid_t = u32;
pub const gid_t = u32;

pub const in_port_t = u16;
pub const sa_family_t = u8;
pub const socklen_t = u32;
pub const sockaddr = extern struct {
    len: u8,
    family: sa_family_t,
    data: [14]u8,

    pub const SS_MAXSIZE = 128;
    pub const storage = std.x.os.Socket.Address.Native.Storage;
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

    /// UNIX domain socket
    pub const un = extern struct {
        len: u8 = @sizeOf(un),
        family: sa_family_t = AF.UNIX,
        path: [104]u8,
    };
};
pub const timeval = extern struct {
    tv_sec: c_long,
    tv_usec: i32,
};

pub const timezone = extern struct {
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

pub const mach_timebase_info_data = extern struct {
    numer: u32,
    denom: u32,
};

pub const off_t = i64;
pub const ino_t = u64;

pub const Flock = extern struct {
    l_start: off_t,
    l_len: off_t,
    l_pid: pid_t,
    l_type: i16,
    l_whence: i16,
};

pub const Stat = extern struct {
    dev: i32,
    mode: u16,
    nlink: u16,
    ino: ino_t,
    uid: uid_t,
    gid: gid_t,
    rdev: i32,
    atimesec: isize,
    atimensec: isize,
    mtimesec: isize,
    mtimensec: isize,
    ctimesec: isize,
    ctimensec: isize,
    birthtimesec: isize,
    birthtimensec: isize,
    size: off_t,
    blocks: i64,
    blksize: i32,
    flags: u32,
    gen: u32,
    lspare: i32,
    qspare: [2]i64,

    pub fn atime(self: @This()) timespec {
        return timespec{
            .tv_sec = self.atimesec,
            .tv_nsec = self.atimensec,
        };
    }

    pub fn mtime(self: @This()) timespec {
        return timespec{
            .tv_sec = self.mtimesec,
            .tv_nsec = self.mtimensec,
        };
    }

    pub fn ctime(self: @This()) timespec {
        return timespec{
            .tv_sec = self.ctimesec,
            .tv_nsec = self.ctimensec,
        };
    }
};

pub const timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};

pub const sigset_t = u32;
pub const empty_sigset: sigset_t = 0;

pub const SIG = struct {
    pub const ERR = @intToPtr(?Sigaction.sigaction_fn, maxInt(usize));
    pub const DFL = @intToPtr(?Sigaction.sigaction_fn, 0);
    pub const IGN = @intToPtr(?Sigaction.sigaction_fn, 1);
    pub const HOLD = @intToPtr(?Sigaction.sigaction_fn, 5);

    /// block specified signal set
    pub const _BLOCK = 1;
    /// unblock specified signal set
    pub const _UNBLOCK = 2;
    /// set specified signal set
    pub const _SETMASK = 3;
    /// hangup
    pub const HUP = 1;
    /// interrupt
    pub const INT = 2;
    /// quit
    pub const QUIT = 3;
    /// illegal instruction (not reset when caught)
    pub const ILL = 4;
    /// trace trap (not reset when caught)
    pub const TRAP = 5;
    /// abort()
    pub const ABRT = 6;
    /// pollable event ([XSR] generated, not supported)
    pub const POLL = 7;
    /// compatibility
    pub const IOT = ABRT;
    /// EMT instruction
    pub const EMT = 7;
    /// floating point exception
    pub const FPE = 8;
    /// kill (cannot be caught or ignored)
    pub const KILL = 9;
    /// bus error
    pub const BUS = 10;
    /// segmentation violation
    pub const SEGV = 11;
    /// bad argument to system call
    pub const SYS = 12;
    /// write on a pipe with no one to read it
    pub const PIPE = 13;
    /// alarm clock
    pub const ALRM = 14;
    /// software termination signal from kill
    pub const TERM = 15;
    /// urgent condition on IO channel
    pub const URG = 16;
    /// sendable stop signal not from tty
    pub const STOP = 17;
    /// stop signal from tty
    pub const TSTP = 18;
    /// continue a stopped process
    pub const CONT = 19;
    /// to parent on child stop or exit
    pub const CHLD = 20;
    /// to readers pgrp upon background tty read
    pub const TTIN = 21;
    /// like TTIN for output if (tp->t_local&LTOSTOP)
    pub const TTOU = 22;
    /// input/output possible signal
    pub const IO = 23;
    /// exceeded CPU time limit
    pub const XCPU = 24;
    /// exceeded file size limit
    pub const XFSZ = 25;
    /// virtual time alarm
    pub const VTALRM = 26;
    /// profiling time alarm
    pub const PROF = 27;
    /// window size changes
    pub const WINCH = 28;
    /// information request
    pub const INFO = 29;
    /// user defined signal 1
    pub const USR1 = 30;
    /// user defined signal 2
    pub const USR2 = 31;
};

pub const siginfo_t = extern struct {
    signo: c_int,
    errno: c_int,
    code: c_int,
    pid: pid_t,
    uid: uid_t,
    status: c_int,
    addr: *anyopaque,
    value: extern union {
        int: c_int,
        ptr: *anyopaque,
    },
    si_band: c_long,
    _pad: [7]c_ulong,
};

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with function name.
pub const Sigaction = extern struct {
    pub const handler_fn = fn (c_int) callconv(.C) void;
    pub const sigaction_fn = fn (c_int, *const siginfo_t, ?*const anyopaque) callconv(.C) void;

    handler: extern union {
        handler: ?handler_fn,
        sigaction: ?sigaction_fn,
    },
    mask: sigset_t,
    flags: c_uint,
};

pub const dirent = extern struct {
    d_ino: usize,
    d_seekoff: usize,
    d_reclen: u16,
    d_namlen: u16,
    d_type: u8,
    d_name: u8, // field address is address of first byte of name

    pub fn reclen(self: dirent) u16 {
        return self.d_reclen;
    }
};

/// Renamed from `kevent` to `Kevent` to avoid conflict with function name.
pub const Kevent = extern struct {
    ident: usize,
    filter: i16,
    flags: u16,
    fflags: u32,
    data: isize,
    udata: usize,
};

// sys/types.h on macos uses #pragma pack(4) so these checks are
// to make sure the struct is laid out the same. These values were
// produced from C code using the offsetof macro.
comptime {
    assert(@offsetOf(Kevent, "ident") == 0);
    assert(@offsetOf(Kevent, "filter") == 8);
    assert(@offsetOf(Kevent, "flags") == 10);
    assert(@offsetOf(Kevent, "fflags") == 12);
    assert(@offsetOf(Kevent, "data") == 16);
    assert(@offsetOf(Kevent, "udata") == 24);
}

pub const kevent64_s = extern struct {
    ident: u64,
    filter: i16,
    flags: u16,
    fflags: u32,
    data: i64,
    udata: u64,
    ext: [2]u64,
};

// sys/types.h on macos uses #pragma pack() so these checks are
// to make sure the struct is laid out the same. These values were
// produced from C code using the offsetof macro.
comptime {
    assert(@offsetOf(kevent64_s, "ident") == 0);
    assert(@offsetOf(kevent64_s, "filter") == 8);
    assert(@offsetOf(kevent64_s, "flags") == 10);
    assert(@offsetOf(kevent64_s, "fflags") == 12);
    assert(@offsetOf(kevent64_s, "data") == 16);
    assert(@offsetOf(kevent64_s, "udata") == 24);
    assert(@offsetOf(kevent64_s, "ext") == 32);
}

pub const mach_port_t = c_uint;
pub const clock_serv_t = mach_port_t;
pub const clock_res_t = c_int;
pub const mach_port_name_t = natural_t;
pub const natural_t = c_uint;
pub const mach_timespec_t = extern struct {
    tv_sec: c_uint,
    tv_nsec: clock_res_t,
};
pub const kern_return_t = c_int;
pub const host_t = mach_port_t;
pub const CALENDAR_CLOCK = 1;

pub const PATH_MAX = 1024;
pub const IOV_MAX = 16;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const PROT = struct {
    /// [MC2] no permissions
    pub const NONE = 0x00;
    /// [MC2] pages can be read
    pub const READ = 0x01;
    /// [MC2] pages can be written
    pub const WRITE = 0x02;
    /// [MC2] pages can be executed
    pub const EXEC = 0x04;
};

pub const MAP = struct {
    /// allocated from memory, swap space
    pub const ANONYMOUS = 0x1000;
    /// map from file (default)
    pub const FILE = 0x0000;
    /// interpret addr exactly
    pub const FIXED = 0x0010;
    /// region may contain semaphores
    pub const HASSEMAPHORE = 0x0200;
    /// changes are private
    pub const PRIVATE = 0x0002;
    /// share changes
    pub const SHARED = 0x0001;
    /// don't cache pages for this mapping
    pub const NOCACHE = 0x0400;
    /// don't reserve needed swap area
    pub const NORESERVE = 0x0040;
    pub const FAILED = @intToPtr(*anyopaque, maxInt(usize));
};

pub const SA = struct {
    /// take signal on signal stack
    pub const ONSTACK = 0x0001;
    /// restart system on signal return
    pub const RESTART = 0x0002;
    /// reset to SIG.DFL when taking signal
    pub const RESETHAND = 0x0004;
    /// do not generate SIG.CHLD on child stop
    pub const NOCLDSTOP = 0x0008;
    /// don't mask the signal we're delivering
    pub const NODEFER = 0x0010;
    /// don't keep zombies around
    pub const NOCLDWAIT = 0x0020;
    /// signal handler with SIGINFO args
    pub const SIGINFO = 0x0040;
    /// do not bounce off kernel's sigtramp
    pub const USERTRAMP = 0x0100;
    /// signal handler with SIGINFO args with 64bit regs information
    pub const @"64REGSET" = 0x0200;
};

pub const F_OK = 0;
pub const X_OK = 1;
pub const W_OK = 2;
pub const R_OK = 4;

pub const O = struct {
    pub const PATH = 0x0000;
    /// open for reading only
    pub const RDONLY = 0x0000;
    /// open for writing only
    pub const WRONLY = 0x0001;
    /// open for reading and writing
    pub const RDWR = 0x0002;
    /// do not block on open or for data to become available
    pub const NONBLOCK = 0x0004;
    /// append on each write
    pub const APPEND = 0x0008;
    /// create file if it does not exist
    pub const CREAT = 0x0200;
    /// truncate size to 0
    pub const TRUNC = 0x0400;
    /// error if CREAT and the file exists
    pub const EXCL = 0x0800;
    /// atomically obtain a shared lock
    pub const SHLOCK = 0x0010;
    /// atomically obtain an exclusive lock
    pub const EXLOCK = 0x0020;
    /// do not follow symlinks
    pub const NOFOLLOW = 0x0100;
    /// allow open of symlinks
    pub const SYMLINK = 0x200000;
    /// descriptor requested for event notifications only
    pub const EVTONLY = 0x8000;
    /// mark as close-on-exec
    pub const CLOEXEC = 0x1000000;
    pub const ACCMODE = 3;
    pub const ALERT = 536870912;
    pub const ASYNC = 64;
    pub const DIRECTORY = 1048576;
    pub const DP_GETRAWENCRYPTED = 1;
    pub const DP_GETRAWUNENCRYPTED = 2;
    pub const DSYNC = 4194304;
    pub const FSYNC = SYNC;
    pub const NOCTTY = 131072;
    pub const POPUP = 2147483648;
    pub const SYNC = 128;
};

pub const SEEK = struct {
    pub const SET = 0x0;
    pub const CUR = 0x1;
    pub const END = 0x2;
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

/// no flag value
pub const KEVENT_FLAG_NONE = 0x000;

/// immediate timeout
pub const KEVENT_FLAG_IMMEDIATE = 0x001;

/// output events only include change
pub const KEVENT_FLAG_ERROR_EVENTS = 0x002;

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

/// unique kevent per udata value
pub const EV_UDATA_SPECIFIC = 0x0100;

/// ... in combination with EV_DELETE
/// will defer delete until udata-specific
/// event enabled. EINPROGRESS will be
/// returned to indicate the deferral
pub const EV_DISPATCH2 = EV_DISPATCH | EV_UDATA_SPECIFIC;

/// report that source has vanished
/// ... only valid with EV_DISPATCH2
pub const EV_VANISHED = 0x0200;

/// reserved by system
pub const EV_SYSFLAGS = 0xF000;

/// filter-specific flag
pub const EV_FLAG0 = 0x1000;

/// filter-specific flag
pub const EV_FLAG1 = 0x2000;

/// EOF detected
pub const EV_EOF = 0x8000;

/// error, data contains errno
pub const EV_ERROR = 0x4000;

pub const EV_POLL = EV_FLAG0;
pub const EV_OOBAND = EV_FLAG1;

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

/// Mach portsets
pub const EVFILT_MACHPORT = -8;

/// Filesystem events
pub const EVFILT_FS = -9;

/// User events
pub const EVFILT_USER = -10;

/// Virtual memory events
pub const EVFILT_VM = -12;

/// Exception events
pub const EVFILT_EXCEPT = -15;

pub const EVFILT_SYSCOUNT = 17;

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

/// OOB data
pub const NOTE_OOB = 0x00000002;

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

/// No specific vnode event: to test for EVFILT_READ      activation
pub const NOTE_NONE = 0x00000080;

/// vnode was unlocked by flock(2)
pub const NOTE_FUNLOCK = 0x00000100;

/// process exited
pub const NOTE_EXIT = 0x80000000;

/// process forked
pub const NOTE_FORK = 0x40000000;

/// process exec'd
pub const NOTE_EXEC = 0x20000000;

/// shared with EVFILT_SIGNAL
pub const NOTE_SIGNAL = 0x08000000;

/// exit status to be returned, valid for child       process only
pub const NOTE_EXITSTATUS = 0x04000000;

/// provide details on reasons for exit
pub const NOTE_EXIT_DETAIL = 0x02000000;

/// mask for signal & exit status
pub const NOTE_PDATAMASK = 0x000fffff;
pub const NOTE_PCTRLMASK = (~NOTE_PDATAMASK);

pub const NOTE_EXIT_DETAIL_MASK = 0x00070000;
pub const NOTE_EXIT_DECRYPTFAIL = 0x00010000;
pub const NOTE_EXIT_MEMORY = 0x00020000;
pub const NOTE_EXIT_CSERROR = 0x00040000;

/// will react on memory          pressure
pub const NOTE_VM_PRESSURE = 0x80000000;

/// will quit on memory       pressure, possibly after cleaning up dirty state
pub const NOTE_VM_PRESSURE_TERMINATE = 0x40000000;

/// will quit immediately on      memory pressure
pub const NOTE_VM_PRESSURE_SUDDEN_TERMINATE = 0x20000000;

/// there was an error
pub const NOTE_VM_ERROR = 0x10000000;

/// data is seconds
pub const NOTE_SECONDS = 0x00000001;

/// data is microseconds
pub const NOTE_USECONDS = 0x00000002;

/// data is nanoseconds
pub const NOTE_NSECONDS = 0x00000004;

/// absolute timeout
pub const NOTE_ABSOLUTE = 0x00000008;

/// ext[1] holds leeway for power aware timers
pub const NOTE_LEEWAY = 0x00000010;

/// system does minimal timer coalescing
pub const NOTE_CRITICAL = 0x00000020;

/// system does maximum timer coalescing
pub const NOTE_BACKGROUND = 0x00000040;
pub const NOTE_MACH_CONTINUOUS_TIME = 0x00000080;

/// data is mach absolute time units
pub const NOTE_MACHTIME = 0x00000100;

pub const AF = struct {
    pub const UNSPEC = 0;
    pub const LOCAL = 1;
    pub const UNIX = LOCAL;
    pub const INET = 2;
    pub const SYS_CONTROL = 2;
    pub const IMPLINK = 3;
    pub const PUP = 4;
    pub const CHAOS = 5;
    pub const NS = 6;
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
    pub const XTP = 19;
    pub const COIP = 20;
    pub const CNT = 21;
    pub const RTIP = 22;
    pub const IPX = 23;
    pub const SIP = 24;
    pub const PIP = 25;
    pub const ISDN = 28;
    pub const E164 = ISDN;
    pub const KEY = 29;
    pub const INET6 = 30;
    pub const NATM = 31;
    pub const SYSTEM = 32;
    pub const NETBIOS = 33;
    pub const PPP = 34;
    pub const MAX = 40;
};

pub const PF = struct {
    pub const UNSPEC = AF.UNSPEC;
    pub const LOCAL = AF.LOCAL;
    pub const UNIX = PF.LOCAL;
    pub const INET = AF.INET;
    pub const IMPLINK = AF.IMPLINK;
    pub const PUP = AF.PUP;
    pub const CHAOS = AF.CHAOS;
    pub const NS = AF.NS;
    pub const ISO = AF.ISO;
    pub const OSI = AF.ISO;
    pub const ECMA = AF.ECMA;
    pub const DATAKIT = AF.DATAKIT;
    pub const CCITT = AF.CCITT;
    pub const SNA = AF.SNA;
    pub const DECnet = AF.DECnet;
    pub const DLI = AF.DLI;
    pub const LAT = AF.LAT;
    pub const HYLINK = AF.HYLINK;
    pub const APPLETALK = AF.APPLETALK;
    pub const ROUTE = AF.ROUTE;
    pub const LINK = AF.LINK;
    pub const XTP = AF.XTP;
    pub const COIP = AF.COIP;
    pub const CNT = AF.CNT;
    pub const SIP = AF.SIP;
    pub const IPX = AF.IPX;
    pub const RTIP = AF.RTIP;
    pub const PIP = AF.PIP;
    pub const ISDN = AF.ISDN;
    pub const KEY = AF.KEY;
    pub const INET6 = AF.INET6;
    pub const NATM = AF.NATM;
    pub const SYSTEM = AF.SYSTEM;
    pub const NETBIOS = AF.NETBIOS;
    pub const PPP = AF.PPP;
    pub const MAX = AF.MAX;
};

pub const SYSPROTO_EVENT = 1;
pub const SYSPROTO_CONTROL = 2;

pub const SOCK = struct {
    pub const STREAM = 1;
    pub const DGRAM = 2;
    pub const RAW = 3;
    pub const RDM = 4;
    pub const SEQPACKET = 5;
    pub const MAXADDRLEN = 255;

    /// Not actually supported by Darwin, but Zig supplies a shim.
    /// This numerical value is not ABI-stable. It need only not conflict
    /// with any other `SOCK` bits.
    pub const CLOEXEC = 1 << 15;
    /// Not actually supported by Darwin, but Zig supplies a shim.
    /// This numerical value is not ABI-stable. It need only not conflict
    /// with any other `SOCK` bits.
    pub const NONBLOCK = 1 << 16;
};

pub const IPPROTO = struct {
    pub const ICMP = 1;
    pub const ICMPV6 = 58;
    pub const TCP = 6;
    pub const UDP = 17;
    pub const IP = 0;
    pub const IPV6 = 41;
};

pub const SOL = struct {
    pub const SOCKET = 0xffff;
};

pub const SO = struct {
    pub const DEBUG = 0x0001;
    pub const ACCEPTCONN = 0x0002;
    pub const REUSEADDR = 0x0004;
    pub const KEEPALIVE = 0x0008;
    pub const DONTROUTE = 0x0010;
    pub const BROADCAST = 0x0020;
    pub const USELOOPBACK = 0x0040;
    pub const LINGER = 0x1080;
    pub const OOBINLINE = 0x0100;
    pub const REUSEPORT = 0x0200;
    pub const ACCEPTFILTER = 0x1000;
    pub const SNDBUF = 0x1001;
    pub const RCVBUF = 0x1002;
    pub const SNDLOWAT = 0x1003;
    pub const RCVLOWAT = 0x1004;
    pub const SNDTIMEO = 0x1005;
    pub const RCVTIMEO = 0x1006;
    pub const ERROR = 0x1007;
    pub const TYPE = 0x1008;

    pub const NREAD = 0x1020;
    pub const NKE = 0x1021;
    pub const NOSIGPIPE = 0x1022;
    pub const NOADDRERR = 0x1023;
    pub const NWRITE = 0x1024;
    pub const REUSESHAREUID = 0x1025;
};

pub const W = struct {
    /// [XSI] no hang in wait/no child to reap
    pub const NOHANG = 0x00000001;
    /// [XSI] notify on stop, untraced child
    pub const UNTRACED = 0x00000002;

    pub fn EXITSTATUS(x: u32) u8 {
        return @intCast(u8, x >> 8);
    }
    pub fn TERMSIG(x: u32) u32 {
        return status(x);
    }
    pub fn STOPSIG(x: u32) u32 {
        return x >> 8;
    }
    pub fn IFEXITED(x: u32) bool {
        return status(x) == 0;
    }
    pub fn IFSTOPPED(x: u32) bool {
        return status(x) == stopped and STOPSIG(x) != 0x13;
    }
    pub fn IFSIGNALED(x: u32) bool {
        return status(x) != stopped and status(x) != 0;
    }

    fn status(x: u32) u32 {
        return x & 0o177;
    }
    const stopped = 0o177;
};

pub const E = enum(u16) {
    /// No error occurred.
    SUCCESS = 0,

    /// Operation not permitted
    PERM = 1,

    /// No such file or directory
    NOENT = 2,

    /// No such process
    SRCH = 3,

    /// Interrupted system call
    INTR = 4,

    /// Input/output error
    IO = 5,

    /// Device not configured
    NXIO = 6,

    /// Argument list too long
    @"2BIG" = 7,

    /// Exec format error
    NOEXEC = 8,

    /// Bad file descriptor
    BADF = 9,

    /// No child processes
    CHILD = 10,

    /// Resource deadlock avoided
    DEADLK = 11,

    /// Cannot allocate memory
    NOMEM = 12,

    /// Permission denied
    ACCES = 13,

    /// Bad address
    FAULT = 14,

    /// Block device required
    NOTBLK = 15,

    /// Device / Resource busy
    BUSY = 16,

    /// File exists
    EXIST = 17,

    /// Cross-device link
    XDEV = 18,

    /// Operation not supported by device
    NODEV = 19,

    /// Not a directory
    NOTDIR = 20,

    /// Is a directory
    ISDIR = 21,

    /// Invalid argument
    INVAL = 22,

    /// Too many open files in system
    NFILE = 23,

    /// Too many open files
    MFILE = 24,

    /// Inappropriate ioctl for device
    NOTTY = 25,

    /// Text file busy
    TXTBSY = 26,

    /// File too large
    FBIG = 27,

    /// No space left on device
    NOSPC = 28,

    /// Illegal seek
    SPIPE = 29,

    /// Read-only file system
    ROFS = 30,

    /// Too many links
    MLINK = 31,

    /// Broken pipe
    PIPE = 32,

    // math software

    /// Numerical argument out of domain
    DOM = 33,

    /// Result too large
    RANGE = 34,

    // non-blocking and interrupt i/o

    /// Resource temporarily unavailable
    /// This is the same code used for `WOULDBLOCK`.
    AGAIN = 35,

    /// Operation now in progress
    INPROGRESS = 36,

    /// Operation already in progress
    ALREADY = 37,

    // ipc/network software -- argument errors

    /// Socket operation on non-socket
    NOTSOCK = 38,

    /// Destination address required
    DESTADDRREQ = 39,

    /// Message too long
    MSGSIZE = 40,

    /// Protocol wrong type for socket
    PROTOTYPE = 41,

    /// Protocol not available
    NOPROTOOPT = 42,

    /// Protocol not supported
    PROTONOSUPPORT = 43,

    /// Socket type not supported
    SOCKTNOSUPPORT = 44,

    /// Operation not supported
    /// The same code is used for `NOTSUP`.
    OPNOTSUPP = 45,

    /// Protocol family not supported
    PFNOSUPPORT = 46,

    /// Address family not supported by protocol family
    AFNOSUPPORT = 47,

    /// Address already in use
    ADDRINUSE = 48,
    /// Can't assign requested address

    // ipc/network software -- operational errors
    ADDRNOTAVAIL = 49,

    /// Network is down
    NETDOWN = 50,

    /// Network is unreachable
    NETUNREACH = 51,

    /// Network dropped connection on reset
    NETRESET = 52,

    /// Software caused connection abort
    CONNABORTED = 53,

    /// Connection reset by peer
    CONNRESET = 54,

    /// No buffer space available
    NOBUFS = 55,

    /// Socket is already connected
    ISCONN = 56,

    /// Socket is not connected
    NOTCONN = 57,

    /// Can't send after socket shutdown
    SHUTDOWN = 58,

    /// Too many references: can't splice
    TOOMANYREFS = 59,

    /// Operation timed out
    TIMEDOUT = 60,

    /// Connection refused
    CONNREFUSED = 61,

    /// Too many levels of symbolic links
    LOOP = 62,

    /// File name too long
    NAMETOOLONG = 63,

    /// Host is down
    HOSTDOWN = 64,

    /// No route to host
    HOSTUNREACH = 65,
    /// Directory not empty

    // quotas & mush
    NOTEMPTY = 66,

    /// Too many processes
    PROCLIM = 67,

    /// Too many users
    USERS = 68,
    /// Disc quota exceeded

    // Network File System
    DQUOT = 69,

    /// Stale NFS file handle
    STALE = 70,

    /// Too many levels of remote in path
    REMOTE = 71,

    /// RPC struct is bad
    BADRPC = 72,

    /// RPC version wrong
    RPCMISMATCH = 73,

    /// RPC prog. not avail
    PROGUNAVAIL = 74,

    /// Program version wrong
    PROGMISMATCH = 75,

    /// Bad procedure for program
    PROCUNAVAIL = 76,

    /// No locks available
    NOLCK = 77,

    /// Function not implemented
    NOSYS = 78,

    /// Inappropriate file type or format
    FTYPE = 79,

    /// Authentication error
    AUTH = 80,

    /// Need authenticator
    NEEDAUTH = 81,

    // Intelligent device errors

    /// Device power is off
    PWROFF = 82,

    /// Device error, e.g. paper out
    DEVERR = 83,

    /// Value too large to be stored in data type
    OVERFLOW = 84,

    // Program loading errors

    /// Bad executable
    BADEXEC = 85,

    /// Bad CPU type in executable
    BADARCH = 86,

    /// Shared library version mismatch
    SHLIBVERS = 87,

    /// Malformed Macho file
    BADMACHO = 88,

    /// Operation canceled
    CANCELED = 89,

    /// Identifier removed
    IDRM = 90,

    /// No message of desired type
    NOMSG = 91,

    /// Illegal byte sequence
    ILSEQ = 92,

    /// Attribute not found
    NOATTR = 93,

    /// Bad message
    BADMSG = 94,

    /// Reserved
    MULTIHOP = 95,

    /// No message available on STREAM
    NODATA = 96,

    /// Reserved
    NOLINK = 97,

    /// No STREAM resources
    NOSR = 98,

    /// Not a STREAM
    NOSTR = 99,

    /// Protocol error
    PROTO = 100,

    /// STREAM ioctl timeout
    TIME = 101,

    /// No such policy registered
    NOPOLICY = 103,

    /// State not recoverable
    NOTRECOVERABLE = 104,

    /// Previous owner died
    OWNERDEAD = 105,

    /// Interface output queue is full
    QFULL = 106,

    _,
};

pub const SIGSTKSZ = 131072;
pub const MINSIGSTKSZ = 32768;

pub const SS_ONSTACK = 1;
pub const SS_DISABLE = 4;

pub const stack_t = extern struct {
    sp: [*]u8,
    size: isize,
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

pub const HOST_NAME_MAX = 72;

pub const AT = struct {
    pub const FDCWD = -2;
    /// Use effective ids in access check
    pub const EACCESS = 0x0010;
    /// Act on the symlink itself not the target
    pub const SYMLINK_NOFOLLOW = 0x0020;
    /// Act on target of symlink
    pub const SYMLINK_FOLLOW = 0x0040;
    /// Path refers to directory
    pub const REMOVEDIR = 0x0080;
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

pub const RTLD = struct {
    pub const LAZY = 0x1;
    pub const NOW = 0x2;
    pub const LOCAL = 0x4;
    pub const GLOBAL = 0x8;
    pub const NOLOAD = 0x10;
    pub const NODELETE = 0x80;
    pub const FIRST = 0x100;

    pub const NEXT = @intToPtr(*anyopaque, @bitCast(usize, @as(isize, -1)));
    pub const DEFAULT = @intToPtr(*anyopaque, @bitCast(usize, @as(isize, -2)));
    pub const SELF = @intToPtr(*anyopaque, @bitCast(usize, @as(isize, -3)));
    pub const MAIN_ONLY = @intToPtr(*anyopaque, @bitCast(usize, @as(isize, -5)));
};

pub const F = struct {
    /// duplicate file descriptor
    pub const DUPFD = 0;
    /// get file descriptor flags
    pub const GETFD = 1;
    /// set file descriptor flags
    pub const SETFD = 2;
    /// get file status flags
    pub const GETFL = 3;
    /// set file status flags
    pub const SETFL = 4;
    /// get SIGIO/SIGURG proc/pgrp
    pub const GETOWN = 5;
    /// set SIGIO/SIGURG proc/pgrp
    pub const SETOWN = 6;
    /// get record locking information
    pub const GETLK = 7;
    /// set record locking information
    pub const SETLK = 8;
    /// F.SETLK; wait if blocked
    pub const SETLKW = 9;
    /// F.SETLK; wait if blocked, return on timeout
    pub const SETLKWTIMEOUT = 10;
    pub const FLUSH_DATA = 40;
    /// Used for regression test
    pub const CHKCLEAN = 41;
    /// Preallocate storage
    pub const PREALLOCATE = 42;
    /// Truncate a file without zeroing space
    pub const SETSIZE = 43;
    /// Issue an advisory read async with no copy to user
    pub const RDADVISE = 44;
    /// turn read ahead off/on for this fd
    pub const RDAHEAD = 45;
    /// turn data caching off/on for this fd
    pub const NOCACHE = 48;
    /// file offset to device offset
    pub const LOG2PHYS = 49;
    /// return the full path of the fd
    pub const GETPATH = 50;
    /// fsync + ask the drive to flush to the media
    pub const FULLFSYNC = 51;
    /// find which component (if any) is a package
    pub const PATHPKG_CHECK = 52;
    /// "freeze" all fs operations
    pub const FREEZE_FS = 53;
    /// "thaw" all fs operations
    pub const THAW_FS = 54;
    /// turn data caching off/on (globally) for this file
    pub const GLOBAL_NOCACHE = 55;
    /// add detached signatures
    pub const ADDSIGS = 59;
    /// add signature from same file (used by dyld for shared libs)
    pub const ADDFILESIGS = 61;
    /// used in conjunction with F.NOCACHE to indicate that DIRECT, synchonous writes
    /// should not be used (i.e. its ok to temporaily create cached pages)
    pub const NODIRECT = 62;
    ///Get the protection class of a file from the EA, returns int
    pub const GETPROTECTIONCLASS = 63;
    ///Set the protection class of a file for the EA, requires int
    pub const SETPROTECTIONCLASS = 64;
    ///file offset to device offset, extended
    pub const LOG2PHYS_EXT = 65;
    ///get record locking information, per-process
    pub const GETLKPID = 66;
    ///Mark the file as being the backing store for another filesystem
    pub const SETBACKINGSTORE = 70;
    ///return the full path of the FD, but error in specific mtmd circumstances
    pub const GETPATH_MTMINFO = 71;
    ///Returns the code directory, with associated hashes, to the caller
    pub const GETCODEDIR = 72;
    ///No SIGPIPE generated on EPIPE
    pub const SETNOSIGPIPE = 73;
    ///Status of SIGPIPE for this fd
    pub const GETNOSIGPIPE = 74;
    ///For some cases, we need to rewrap the key for AKS/MKB
    pub const TRANSCODEKEY = 75;
    ///file being written to a by single writer... if throttling enabled, writes
    ///may be broken into smaller chunks with throttling in between
    pub const SINGLE_WRITER = 76;
    ///Get the protection version number for this filesystem
    pub const GETPROTECTIONLEVEL = 77;
    ///Add detached code signatures (used by dyld for shared libs)
    pub const FINDSIGS = 78;
    ///Add signature from same file, only if it is signed by Apple (used by dyld for simulator)
    pub const ADDFILESIGS_FOR_DYLD_SIM = 83;
    ///fsync + issue barrier to drive
    pub const BARRIERFSYNC = 85;
    ///Add signature from same file, return end offset in structure on success
    pub const ADDFILESIGS_RETURN = 97;
    ///Check if Library Validation allows this Mach-O file to be mapped into the calling process
    pub const CHECK_LV = 98;
    ///Deallocate a range of the file
    pub const PUNCHHOLE = 99;
    ///Trim an active file
    pub const TRIM_ACTIVE_FILE = 100;
    ///mark the dup with FD_CLOEXEC
    pub const DUPFD_CLOEXEC = 67;
    /// shared or read lock
    pub const RDLCK = 1;
    /// unlock
    pub const UNLCK = 2;
    /// exclusive or write lock
    pub const WRLCK = 3;
};

pub const FCNTL_FS_SPECIFIC_BASE = 0x00010000;

///close-on-exec flag
pub const FD_CLOEXEC = 1;

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const UN = 8;
    pub const NB = 4;
};

pub const nfds_t = u32;
pub const pollfd = extern struct {
    fd: fd_t,
    events: i16,
    revents: i16,
};

pub const POLL = struct {
    pub const IN = 0x001;
    pub const PRI = 0x002;
    pub const OUT = 0x004;
    pub const RDNORM = 0x040;
    pub const WRNORM = OUT;
    pub const RDBAND = 0x080;
    pub const WRBAND = 0x100;

    pub const EXTEND = 0x0200;
    pub const ATTRIB = 0x0400;
    pub const NLINK = 0x0800;
    pub const WRITE = 0x1000;

    pub const ERR = 0x008;
    pub const HUP = 0x010;
    pub const NVAL = 0x020;

    pub const STANDARD = IN | PRI | OUT | RDNORM | RDBAND | WRBAND | ERR | HUP | NVAL;
};

pub const CLOCK = struct {
    pub const REALTIME = 0;
    pub const MONOTONIC = 6;
    pub const MONOTONIC_RAW = 4;
    pub const MONOTONIC_RAW_APPROX = 5;
    pub const UPTIME_RAW = 8;
    pub const UPTIME_RAW_APPROX = 9;
    pub const PROCESS_CPUTIME_ID = 12;
    pub const THREAD_CPUTIME_ID = 16;
};

/// Max open files per process
/// https://opensource.apple.com/source/xnu/xnu-4903.221.2/bsd/sys/syslimits.h.auto.html
pub const OPEN_MAX = 10240;

pub const rusage = extern struct {
    utime: timeval,
    stime: timeval,
    maxrss: isize,
    ixrss: isize,
    idrss: isize,
    isrss: isize,
    minflt: isize,
    majflt: isize,
    nswap: isize,
    inblock: isize,
    oublock: isize,
    msgsnd: isize,
    msgrcv: isize,
    nsignals: isize,
    nvcsw: isize,
    nivcsw: isize,

    pub const SELF = 0;
    pub const CHILDREN = -1;
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
    _,

    pub const AS: rlimit_resource = .RSS;
};

pub const rlim_t = u64;

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

// Term
pub const V = struct {
    pub const EOF = 0;
    pub const EOL = 1;
    pub const EOL2 = 2;
    pub const ERASE = 3;
    pub const WERASE = 4;
    pub const KILL = 5;
    pub const REPRINT = 6;
    pub const INTR = 8;
    pub const QUIT = 9;
    pub const SUSP = 10;
    pub const DSUSP = 11;
    pub const START = 12;
    pub const STOP = 13;
    pub const LNEXT = 14;
    pub const DISCARD = 15;
    pub const MIN = 16;
    pub const TIME = 17;
    pub const STATUS = 18;
};

pub const NCCS = 20; // 2 spares (7, 19)

pub const cc_t = u8;
pub const speed_t = u64;
pub const tcflag_t = u64;

pub const IGNBRK: tcflag_t = 0x00000001; // ignore BREAK condition
pub const BRKINT: tcflag_t = 0x00000002; // map BREAK to SIGINTR
pub const IGNPAR: tcflag_t = 0x00000004; // ignore (discard) parity errors
pub const PARMRK: tcflag_t = 0x00000008; // mark parity and framing errors
pub const INPCK: tcflag_t = 0x00000010; // enable checking of parity errors
pub const ISTRIP: tcflag_t = 0x00000020; // strip 8th bit off chars
pub const INLCR: tcflag_t = 0x00000040; // map NL into CR
pub const IGNCR: tcflag_t = 0x00000080; // ignore CR
pub const ICRNL: tcflag_t = 0x00000100; // map CR to NL (ala CRMOD)
pub const IXON: tcflag_t = 0x00000200; // enable output flow control
pub const IXOFF: tcflag_t = 0x00000400; // enable input flow control
pub const IXANY: tcflag_t = 0x00000800; // any char will restart after stop
pub const IMAXBEL: tcflag_t = 0x00002000; // ring bell on input queue full
pub const IUTF8: tcflag_t = 0x00004000; // maintain state for UTF-8 VERASE

pub const OPOST: tcflag_t = 0x00000001; //enable following output processing
pub const ONLCR: tcflag_t = 0x00000002; // map NL to CR-NL (ala CRMOD)
pub const OXTABS: tcflag_t = 0x00000004; // expand tabs to spaces
pub const ONOEOT: tcflag_t = 0x00000008; // discard EOT's (^D) on output)

pub const OCRNL: tcflag_t = 0x00000010; // map CR to NL on output
pub const ONOCR: tcflag_t = 0x00000020; // no CR output at column 0
pub const ONLRET: tcflag_t = 0x00000040; // NL performs CR function
pub const OFILL: tcflag_t = 0x00000080; // use fill characters for delay
pub const NLDLY: tcflag_t = 0x00000300; // \n delay
pub const TABDLY: tcflag_t = 0x00000c04; // horizontal tab delay
pub const CRDLY: tcflag_t = 0x00003000; // \r delay
pub const FFDLY: tcflag_t = 0x00004000; // form feed delay
pub const BSDLY: tcflag_t = 0x00008000; // \b delay
pub const VTDLY: tcflag_t = 0x00010000; // vertical tab delay
pub const OFDEL: tcflag_t = 0x00020000; // fill is DEL, else NUL

pub const NL0: tcflag_t = 0x00000000;
pub const NL1: tcflag_t = 0x00000100;
pub const NL2: tcflag_t = 0x00000200;
pub const NL3: tcflag_t = 0x00000300;
pub const TAB0: tcflag_t = 0x00000000;
pub const TAB1: tcflag_t = 0x00000400;
pub const TAB2: tcflag_t = 0x00000800;
pub const TAB3: tcflag_t = 0x00000004;
pub const CR0: tcflag_t = 0x00000000;
pub const CR1: tcflag_t = 0x00001000;
pub const CR2: tcflag_t = 0x00002000;
pub const CR3: tcflag_t = 0x00003000;
pub const FF0: tcflag_t = 0x00000000;
pub const FF1: tcflag_t = 0x00004000;
pub const BS0: tcflag_t = 0x00000000;
pub const BS1: tcflag_t = 0x00008000;
pub const VT0: tcflag_t = 0x00000000;
pub const VT1: tcflag_t = 0x00010000;

pub const CIGNORE: tcflag_t = 0x00000001; // ignore control flags
pub const CSIZE: tcflag_t = 0x00000300; // character size mask
pub const CS5: tcflag_t = 0x00000000; //    5 bits (pseudo)
pub const CS6: tcflag_t = 0x00000100; //    6 bits
pub const CS7: tcflag_t = 0x00000200; //    7 bits
pub const CS8: tcflag_t = 0x00000300; //    8 bits
pub const CSTOPB: tcflag_t = 0x0000040; // send 2 stop bits
pub const CREAD: tcflag_t = 0x00000800; // enable receiver
pub const PARENB: tcflag_t = 0x00001000; // parity enable
pub const PARODD: tcflag_t = 0x00002000; // odd parity, else even
pub const HUPCL: tcflag_t = 0x00004000; // hang up on last close
pub const CLOCAL: tcflag_t = 0x00008000; // ignore modem status lines
pub const CCTS_OFLOW: tcflag_t = 0x00010000; // CTS flow control of output
pub const CRTSCTS: tcflag_t = (CCTS_OFLOW | CRTS_IFLOW);
pub const CRTS_IFLOW: tcflag_t = 0x00020000; // RTS flow control of input
pub const CDTR_IFLOW: tcflag_t = 0x00040000; // DTR flow control of input
pub const CDSR_OFLOW: tcflag_t = 0x00080000; // DSR flow control of output
pub const CCAR_OFLOW: tcflag_t = 0x00100000; // DCD flow control of output
pub const MDMBUF: tcflag_t = 0x00100000; // old name for CCAR_OFLOW

pub const ECHOKE: tcflag_t = 0x00000001; // visual erase for line kill
pub const ECHOE: tcflag_t = 0x00000002; // visually erase chars
pub const ECHOK: tcflag_t = 0x00000004; // echo NL after line kill
pub const ECHO: tcflag_t = 0x00000008; // enable echoing
pub const ECHONL: tcflag_t = 0x00000010; // echo NL even if ECHO is off
pub const ECHOPRT: tcflag_t = 0x00000020; // visual erase mode for hardcopy
pub const ECHOCTL: tcflag_t = 0x00000040; // echo control chars as ^(Char)
pub const ISIG: tcflag_t = 0x00000080; // enable signals INTR, QUIT, [D]SUSP
pub const ICANON: tcflag_t = 0x00000100; // canonicalize input lines
pub const ALTWERASE: tcflag_t = 0x00000200; // use alternate WERASE algorithm
pub const IEXTEN: tcflag_t = 0x00000400; // enable DISCARD and LNEXT
pub const EXTPROC: tcflag_t = 0x00000800; // external processing
pub const TOSTOP: tcflag_t = 0x00400000; // stop background jobs from output
pub const FLUSHO: tcflag_t = 0x00800000; // output being flushed (state)
pub const NOKERNINFO: tcflag_t = 0x02000000; // no kernel output from VSTATUS
pub const PENDIN: tcflag_t = 0x20000000; // XXX retype pending input (state)
pub const NOFLSH: tcflag_t = 0x80000000; // don't flush after interrupt

pub const TCSANOW: tcflag_t = 0; // make change immediate
pub const TCSADRAIN: tcflag_t = 1; // drain output, then change
pub const TCSAFLUSH: tcflag_t = 2; // drain output, flush input
pub const TCSASOFT: tcflag_t = 0x10; // flag - don't alter h.w. state
pub const TCSA = enum(c_uint) {
    NOW,
    DRAIN,
    FLUSH,
    _,
};

pub const B0: tcflag_t = 0;
pub const B50: tcflag_t = 50;
pub const B75: tcflag_t = 75;
pub const B110: tcflag_t = 110;
pub const B134: tcflag_t = 134;
pub const B150: tcflag_t = 150;
pub const B200: tcflag_t = 200;
pub const B300: tcflag_t = 300;
pub const B600: tcflag_t = 600;
pub const B1200: tcflag_t = 1200;
pub const B1800: tcflag_t = 1800;
pub const B2400: tcflag_t = 2400;
pub const B4800: tcflag_t = 4800;
pub const B9600: tcflag_t = 9600;
pub const B19200: tcflag_t = 19200;
pub const B38400: tcflag_t = 38400;
pub const B7200: tcflag_t = 7200;
pub const B14400: tcflag_t = 14400;
pub const B28800: tcflag_t = 28800;
pub const B57600: tcflag_t = 57600;
pub const B76800: tcflag_t = 76800;
pub const B115200: tcflag_t = 115200;
pub const B230400: tcflag_t = 230400;
pub const EXTA: tcflag_t = 19200;
pub const EXTB: tcflag_t = 38400;

pub const TCIFLUSH: tcflag_t = 1;
pub const TCOFLUSH: tcflag_t = 2;
pub const TCIOFLUSH: tcflag_t = 3;
pub const TCOOFF: tcflag_t = 1;
pub const TCOON: tcflag_t = 2;
pub const TCIOFF: tcflag_t = 3;
pub const TCION: tcflag_t = 4;

pub const termios = extern struct {
    iflag: tcflag_t, // input flags
    oflag: tcflag_t, // output flags
    cflag: tcflag_t, // control flags
    lflag: tcflag_t, // local flags
    cc: [NCCS]cc_t, // control chars
    ispeed: speed_t align(8), // input speed
    ospeed: speed_t, // output speed
};

pub const winsize = extern struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

pub const T = struct {
    pub const IOCGWINSZ = ior(0x40000000, 't', 104, @sizeOf(winsize));
};
pub const IOCPARM_MASK = 0x1fff;

fn ior(inout: u32, group: usize, num: usize, len: usize) usize {
    return (inout | ((len & IOCPARM_MASK) << 16) | ((group) << 8) | (num));
}

// CPU families mapping
pub const CPUFAMILY = enum(u32) {
    UNKNOWN = 0,
    POWERPC_G3 = 0xcee41549,
    POWERPC_G4 = 0x77c184ae,
    POWERPC_G5 = 0xed76d8aa,
    INTEL_6_13 = 0xaa33392b,
    INTEL_PENRYN = 0x78ea4fbc,
    INTEL_NEHALEM = 0x6b5a4cd2,
    INTEL_WESTMERE = 0x573b5eec,
    INTEL_SANDYBRIDGE = 0x5490b78c,
    INTEL_IVYBRIDGE = 0x1f65e835,
    INTEL_HASWELL = 0x10b282dc,
    INTEL_BROADWELL = 0x582ed09c,
    INTEL_SKYLAKE = 0x37fc219f,
    INTEL_KABYLAKE = 0x0f817246,
    ARM_9 = 0xe73283ae,
    ARM_11 = 0x8ff620d8,
    ARM_XSCALE = 0x53b005f5,
    ARM_12 = 0xbd1b0ae9,
    ARM_13 = 0x0cc90e64,
    ARM_14 = 0x96077ef1,
    ARM_15 = 0xa8511bca,
    ARM_SWIFT = 0x1e2d6381,
    ARM_CYCLONE = 0x37a09642,
    ARM_TYPHOON = 0x2c91a47e,
    ARM_TWISTER = 0x92fb37c8,
    ARM_HURRICANE = 0x67ceee93,
    ARM_MONSOON_MISTRAL = 0xe81e7ef6,
    ARM_VORTEX_TEMPEST = 0x07d34b9f,
    ARM_LIGHTNING_THUNDER = 0x462504d2,
    ARM_FIRESTORM_ICESTORM = 0x1b588bb3,
    _,
};
