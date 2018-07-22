const std = @import("../index.zig");
const c = std.c;
const assert = std.debug.assert;

pub use @import("darwin/errno.zig");

pub const PATH_MAX = 1024;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

/// [MC2] no permissions
pub const PROT_NONE = 0x00;

/// [MC2] pages can be read
pub const PROT_READ = 0x01;

/// [MC2] pages can be written
pub const PROT_WRITE = 0x02;

/// [MC2] pages can be executed
pub const PROT_EXEC = 0x04;

/// allocated from memory, swap space
pub const MAP_ANONYMOUS = 0x1000;

/// map from file (default)
pub const MAP_FILE = 0x0000;

/// interpret addr exactly
pub const MAP_FIXED = 0x0010;

/// region may contain semaphores
pub const MAP_HASSEMAPHORE = 0x0200;

/// changes are private
pub const MAP_PRIVATE = 0x0002;

/// share changes
pub const MAP_SHARED = 0x0001;

/// don't cache pages for this mapping
pub const MAP_NOCACHE = 0x0400;

/// don't reserve needed swap area
pub const MAP_NORESERVE = 0x0040;
pub const MAP_FAILED = @maxValue(usize);

/// [XSI] no hang in wait/no child to reap
pub const WNOHANG = 0x00000001;

/// [XSI] notify on stop, untraced child
pub const WUNTRACED = 0x00000002;

/// take signal on signal stack
pub const SA_ONSTACK = 0x0001;

/// restart system on signal return
pub const SA_RESTART = 0x0002;

/// reset to SIG_DFL when taking signal
pub const SA_RESETHAND = 0x0004;

/// do not generate SIGCHLD on child stop
pub const SA_NOCLDSTOP = 0x0008;

/// don't mask the signal we're delivering
pub const SA_NODEFER = 0x0010;

/// don't keep zombies around
pub const SA_NOCLDWAIT = 0x0020;

/// signal handler with SA_SIGINFO args
pub const SA_SIGINFO = 0x0040;

/// do not bounce off kernel's sigtramp
pub const SA_USERTRAMP = 0x0100;

/// signal handler with SA_SIGINFO args with 64bit   regs information
pub const SA_64REGSET = 0x0200;

pub const O_LARGEFILE = 0x0000;
pub const O_PATH = 0x0000;

pub const F_OK = 0;
pub const X_OK = 1;
pub const W_OK = 2;
pub const R_OK = 4;

/// open for reading only
pub const O_RDONLY = 0x0000;

/// open for writing only
pub const O_WRONLY = 0x0001;

/// open for reading and writing
pub const O_RDWR = 0x0002;

/// do not block on open or for data to become available
pub const O_NONBLOCK = 0x0004;

/// append on each write
pub const O_APPEND = 0x0008;

/// create file if it does not exist
pub const O_CREAT = 0x0200;

/// truncate size to 0
pub const O_TRUNC = 0x0400;

/// error if O_CREAT and the file exists
pub const O_EXCL = 0x0800;

/// atomically obtain a shared lock
pub const O_SHLOCK = 0x0010;

/// atomically obtain an exclusive lock
pub const O_EXLOCK = 0x0020;

/// do not follow symlinks
pub const O_NOFOLLOW = 0x0100;

/// allow open of symlinks
pub const O_SYMLINK = 0x200000;

/// descriptor requested for event notifications only
pub const O_EVTONLY = 0x8000;

/// mark as close-on-exec
pub const O_CLOEXEC = 0x1000000;

pub const O_ACCMODE = 3;
pub const O_ALERT = 536870912;
pub const O_ASYNC = 64;
pub const O_DIRECTORY = 1048576;
pub const O_DP_GETRAWENCRYPTED = 1;
pub const O_DP_GETRAWUNENCRYPTED = 2;
pub const O_DSYNC = 4194304;
pub const O_FSYNC = O_SYNC;
pub const O_NOCTTY = 131072;
pub const O_POPUP = 2147483648;
pub const O_SYNC = 128;

pub const SEEK_SET = 0x0;
pub const SEEK_CUR = 0x1;
pub const SEEK_END = 0x2;

pub const DT_UNKNOWN = 0;
pub const DT_FIFO = 1;
pub const DT_CHR = 2;
pub const DT_DIR = 4;
pub const DT_BLK = 6;
pub const DT_REG = 8;
pub const DT_LNK = 10;
pub const DT_SOCK = 12;
pub const DT_WHT = 14;

/// block specified signal set
pub const SIG_BLOCK = 1;

/// unblock specified signal set
pub const SIG_UNBLOCK = 2;

/// set specified signal set
pub const SIG_SETMASK = 3;

/// hangup
pub const SIGHUP = 1;

/// interrupt
pub const SIGINT = 2;

/// quit
pub const SIGQUIT = 3;

/// illegal instruction (not reset when caught)
pub const SIGILL = 4;

/// trace trap (not reset when caught)
pub const SIGTRAP = 5;

/// abort()
pub const SIGABRT = 6;

/// pollable event ([XSR] generated, not supported)
pub const SIGPOLL = 7;

/// compatibility
pub const SIGIOT = SIGABRT;

/// EMT instruction
pub const SIGEMT = 7;

/// floating point exception
pub const SIGFPE = 8;

/// kill (cannot be caught or ignored)
pub const SIGKILL = 9;

/// bus error
pub const SIGBUS = 10;

/// segmentation violation
pub const SIGSEGV = 11;

/// bad argument to system call
pub const SIGSYS = 12;

/// write on a pipe with no one to read it
pub const SIGPIPE = 13;

/// alarm clock
pub const SIGALRM = 14;

/// software termination signal from kill
pub const SIGTERM = 15;

/// urgent condition on IO channel
pub const SIGURG = 16;

/// sendable stop signal not from tty
pub const SIGSTOP = 17;

/// stop signal from tty
pub const SIGTSTP = 18;

/// continue a stopped process
pub const SIGCONT = 19;

/// to parent on child stop or exit
pub const SIGCHLD = 20;

/// to readers pgrp upon background tty read
pub const SIGTTIN = 21;

/// like TTIN for output if (tp->t_local&LTOSTOP)
pub const SIGTTOU = 22;

/// input/output possible signal
pub const SIGIO = 23;

/// exceeded CPU time limit
pub const SIGXCPU = 24;

/// exceeded file size limit
pub const SIGXFSZ = 25;

/// virtual time alarm
pub const SIGVTALRM = 26;

/// profiling time alarm
pub const SIGPROF = 27;

/// window size changes
pub const SIGWINCH = 28;

/// information request
pub const SIGINFO = 29;

/// user defined signal 1
pub const SIGUSR1 = 30;

/// user defined signal 2
pub const SIGUSR2 = 31;

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

pub const AF_UNSPEC: c_int = 0;
pub const AF_LOCAL: c_int = 1;
pub const AF_UNIX: c_int = AF_LOCAL;
pub const AF_INET: c_int = 2;
pub const AF_SYS_CONTROL: c_int = 2;
pub const AF_IMPLINK: c_int = 3;
pub const AF_PUP: c_int = 4;
pub const AF_CHAOS: c_int = 5;
pub const AF_NS: c_int = 6;
pub const AF_ISO: c_int = 7;
pub const AF_OSI: c_int = AF_ISO;
pub const AF_ECMA: c_int = 8;
pub const AF_DATAKIT: c_int = 9;
pub const AF_CCITT: c_int = 10;
pub const AF_SNA: c_int = 11;
pub const AF_DECnet: c_int = 12;
pub const AF_DLI: c_int = 13;
pub const AF_LAT: c_int = 14;
pub const AF_HYLINK: c_int = 15;
pub const AF_APPLETALK: c_int = 16;
pub const AF_ROUTE: c_int = 17;
pub const AF_LINK: c_int = 18;
pub const AF_XTP: c_int = 19;
pub const AF_COIP: c_int = 20;
pub const AF_CNT: c_int = 21;
pub const AF_RTIP: c_int = 22;
pub const AF_IPX: c_int = 23;
pub const AF_SIP: c_int = 24;
pub const AF_PIP: c_int = 25;
pub const AF_ISDN: c_int = 28;
pub const AF_E164: c_int = AF_ISDN;
pub const AF_KEY: c_int = 29;
pub const AF_INET6: c_int = 30;
pub const AF_NATM: c_int = 31;
pub const AF_SYSTEM: c_int = 32;
pub const AF_NETBIOS: c_int = 33;
pub const AF_PPP: c_int = 34;
pub const AF_MAX: c_int = 40;

pub const PF_UNSPEC: c_int = AF_UNSPEC;
pub const PF_LOCAL: c_int = AF_LOCAL;
pub const PF_UNIX: c_int = PF_LOCAL;
pub const PF_INET: c_int = AF_INET;
pub const PF_IMPLINK: c_int = AF_IMPLINK;
pub const PF_PUP: c_int = AF_PUP;
pub const PF_CHAOS: c_int = AF_CHAOS;
pub const PF_NS: c_int = AF_NS;
pub const PF_ISO: c_int = AF_ISO;
pub const PF_OSI: c_int = AF_ISO;
pub const PF_ECMA: c_int = AF_ECMA;
pub const PF_DATAKIT: c_int = AF_DATAKIT;
pub const PF_CCITT: c_int = AF_CCITT;
pub const PF_SNA: c_int = AF_SNA;
pub const PF_DECnet: c_int = AF_DECnet;
pub const PF_DLI: c_int = AF_DLI;
pub const PF_LAT: c_int = AF_LAT;
pub const PF_HYLINK: c_int = AF_HYLINK;
pub const PF_APPLETALK: c_int = AF_APPLETALK;
pub const PF_ROUTE: c_int = AF_ROUTE;
pub const PF_LINK: c_int = AF_LINK;
pub const PF_XTP: c_int = AF_XTP;
pub const PF_COIP: c_int = AF_COIP;
pub const PF_CNT: c_int = AF_CNT;
pub const PF_SIP: c_int = AF_SIP;
pub const PF_IPX: c_int = AF_IPX;
pub const PF_RTIP: c_int = AF_RTIP;
pub const PF_PIP: c_int = AF_PIP;
pub const PF_ISDN: c_int = AF_ISDN;
pub const PF_KEY: c_int = AF_KEY;
pub const PF_INET6: c_int = AF_INET6;
pub const PF_NATM: c_int = AF_NATM;
pub const PF_SYSTEM: c_int = AF_SYSTEM;
pub const PF_NETBIOS: c_int = AF_NETBIOS;
pub const PF_PPP: c_int = AF_PPP;
pub const PF_MAX: c_int = AF_MAX;

pub const SYSPROTO_EVENT: c_int = 1;
pub const SYSPROTO_CONTROL: c_int = 2;

pub const SOCK_STREAM: c_int = 1;
pub const SOCK_DGRAM: c_int = 2;
pub const SOCK_RAW: c_int = 3;
pub const SOCK_RDM: c_int = 4;
pub const SOCK_SEQPACKET: c_int = 5;
pub const SOCK_MAXADDRLEN: c_int = 255;

fn wstatus(x: i32) i32 {
    return x & 0o177;
}
const wstopped = 0o177;
pub fn WEXITSTATUS(x: i32) i32 {
    return x >> 8;
}
pub fn WTERMSIG(x: i32) i32 {
    return wstatus(x);
}
pub fn WSTOPSIG(x: i32) i32 {
    return x >> 8;
}
pub fn WIFEXITED(x: i32) bool {
    return wstatus(x) == 0;
}
pub fn WIFSTOPPED(x: i32) bool {
    return wstatus(x) == wstopped and WSTOPSIG(x) != 0x13;
}
pub fn WIFSIGNALED(x: i32) bool {
    return wstatus(x) != wstopped and wstatus(x) != 0;
}

/// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: usize) usize {
    const signed_r = @bitCast(isize, r);
    return if (signed_r > -4096 and signed_r < 0) @intCast(usize, -signed_r) else 0;
}

pub fn close(fd: i32) usize {
    return errnoWrap(c.close(fd));
}

pub fn abort() noreturn {
    c.abort();
}

pub fn exit(code: i32) noreturn {
    c.exit(code);
}

pub fn isatty(fd: i32) bool {
    return c.isatty(fd) != 0;
}

pub fn fstat(fd: i32, buf: *c.Stat) usize {
    return errnoWrap(c.@"fstat$INODE64"(fd, buf));
}

pub fn lseek(fd: i32, offset: isize, whence: c_int) usize {
    return errnoWrap(c.lseek(fd, offset, whence));
}

// TODO https://github.com/ziglang/zig/issues/265 on the whole file
pub fn open(path: [*]const u8, flags: u32, mode: usize) usize {
    return errnoWrap(c.open(path, @bitCast(c_int, flags), mode));
}

pub fn raise(sig: i32) usize {
    return errnoWrap(c.raise(sig));
}

pub fn read(fd: i32, buf: [*]u8, nbyte: usize) usize {
    return errnoWrap(c.read(fd, @ptrCast(*c_void, buf), nbyte));
}

pub fn stat(noalias path: [*]const u8, noalias buf: *stat) usize {
    return errnoWrap(c.stat(path, buf));
}

pub fn write(fd: i32, buf: [*]const u8, nbyte: usize) usize {
    return errnoWrap(c.write(fd, @ptrCast(*const c_void, buf), nbyte));
}

pub fn mmap(address: ?[*]u8, length: usize, prot: usize, flags: u32, fd: i32, offset: isize) usize {
    const ptr_result = c.mmap(
        @ptrCast(*c_void, address),
        length,
        @bitCast(c_int, @intCast(c_uint, prot)),
        @bitCast(c_int, c_uint(flags)),
        fd,
        offset,
    );
    const isize_result = @bitCast(isize, @ptrToInt(ptr_result));
    return errnoWrap(isize_result);
}

pub fn munmap(address: usize, length: usize) usize {
    return errnoWrap(c.munmap(@intToPtr(*c_void, address), length));
}

pub fn unlink(path: [*]const u8) usize {
    return errnoWrap(c.unlink(path));
}

pub fn getcwd(buf: [*]u8, size: usize) usize {
    return if (c.getcwd(buf, size) == null) @bitCast(usize, -isize(c._errno().*)) else 0;
}

pub fn waitpid(pid: i32, status: *i32, options: u32) usize {
    comptime assert(i32.bit_count == c_int.bit_count);
    return errnoWrap(c.waitpid(pid, @ptrCast(*c_int, status), @bitCast(c_int, options)));
}

pub fn fork() usize {
    return errnoWrap(c.fork());
}

pub fn access(path: [*]const u8, mode: u32) usize {
    return errnoWrap(c.access(path, mode));
}

pub fn pipe(fds: *[2]i32) usize {
    comptime assert(i32.bit_count == c_int.bit_count);
    return errnoWrap(c.pipe(@ptrCast(*[2]c_int, fds)));
}

pub fn getdirentries64(fd: i32, buf_ptr: [*]u8, buf_len: usize, basep: *i64) usize {
    return errnoWrap(@bitCast(isize, c.__getdirentries64(fd, buf_ptr, buf_len, basep)));
}

pub fn kqueue() usize {
    return errnoWrap(c.kqueue());
}

pub fn kevent(kq: i32, changelist: []const Kevent, eventlist: []Kevent, timeout: ?*const timespec) usize {
    return errnoWrap(c.kevent(
        kq,
        changelist.ptr,
        @intCast(c_int, changelist.len),
        eventlist.ptr,
        @intCast(c_int, eventlist.len),
        timeout,
    ));
}

pub fn kevent64(
    kq: i32,
    changelist: []const kevent64_s,
    eventlist: []kevent64_s,
    flags: u32,
    timeout: ?*const timespec,
) usize {
    return errnoWrap(c.kevent64(kq, changelist.ptr, changelist.len, eventlist.ptr, eventlist.len, flags, timeout));
}

pub fn mkdir(path: [*]const u8, mode: u32) usize {
    return errnoWrap(c.mkdir(path, mode));
}

pub fn symlink(existing: [*]const u8, new: [*]const u8) usize {
    return errnoWrap(c.symlink(existing, new));
}

pub fn sysctl(name: [*]c_int, namelen: c_uint, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) usize {
    return errnoWrap(c.sysctl(name, namelen, oldp, oldlenp, newp, newlen));
}

pub fn sysctlbyname(name: [*]const u8, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) usize {
    return errnoWrap(c.sysctlbyname(name, oldp, oldlenp, newp, newlen));
}

pub fn sysctlnametomib(name: [*]const u8, mibp: ?*c_int, sizep: ?*usize) usize {
    return errnoWrap(c.sysctlnametomib(name, wibp, sizep));
}

pub fn rename(old: [*]const u8, new: [*]const u8) usize {
    return errnoWrap(c.rename(old, new));
}

pub fn rmdir(path: [*]const u8) usize {
    return errnoWrap(c.rmdir(path));
}

pub fn chdir(path: [*]const u8) usize {
    return errnoWrap(c.chdir(path));
}

pub fn execve(path: [*]const u8, argv: [*]const ?[*]const u8, envp: [*]const ?[*]const u8) usize {
    return errnoWrap(c.execve(path, argv, envp));
}

pub fn dup2(old: i32, new: i32) usize {
    return errnoWrap(c.dup2(old, new));
}

pub fn readlink(noalias path: [*]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    return errnoWrap(c.readlink(path, buf_ptr, buf_len));
}

pub fn gettimeofday(tv: ?*timeval, tz: ?*timezone) usize {
    return errnoWrap(c.gettimeofday(tv, tz));
}

pub fn nanosleep(req: *const timespec, rem: ?*timespec) usize {
    return errnoWrap(c.nanosleep(req, rem));
}

pub fn realpath(noalias filename: [*]const u8, noalias resolved_name: [*]u8) usize {
    return if (c.realpath(filename, resolved_name) == null) @bitCast(usize, -isize(c._errno().*)) else 0;
}

pub fn setreuid(ruid: u32, euid: u32) usize {
    return errnoWrap(c.setreuid(ruid, euid));
}

pub fn setregid(rgid: u32, egid: u32) usize {
    return errnoWrap(c.setregid(rgid, egid));
}

pub fn sigprocmask(flags: u32, noalias set: *const sigset_t, noalias oldset: ?*sigset_t) usize {
    return errnoWrap(c.sigprocmask(@bitCast(c_int, flags), set, oldset));
}

pub fn sigaction(sig: u5, noalias act: *const Sigaction, noalias oact: ?*Sigaction) usize {
    assert(sig != SIGKILL);
    assert(sig != SIGSTOP);
    var cact = c.Sigaction{
        .handler = @ptrCast(extern fn (c_int) void, act.handler),
        .sa_flags = @bitCast(c_int, act.flags),
        .sa_mask = act.mask,
    };
    var coact: c.Sigaction = undefined;
    const result = errnoWrap(c.sigaction(sig, *cact, *coact));
    if (result != 0) {
        return result;
    }
    if (oact) |old| {
        old.* = Sigaction{
            .handler = @ptrCast(extern fn (i32) void, coact.handler),
            .flags = @bitCast(u32, coact.sa_flags),
            .mask = coact.sa_mask,
        };
    }
    return result;
}

pub const sigset_t = c.sigset_t;
pub const empty_sigset = sigset_t(0);

pub const timespec = c.timespec;
pub const Stat = c.Stat;
pub const dirent = c.dirent;

pub const sa_family_t = c.sa_family_t;
pub const sockaddr = c.sockaddr;

/// Renamed from `kevent` to `Kevent` to avoid conflict with the syscall.
pub const Kevent = c.Kevent;
pub const kevent64_s = c.kevent64_s;

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = struct {
    handler: extern fn (i32) void,
    mask: sigset_t,
    flags: u32,
};

pub fn sigaddset(set: *sigset_t, signo: u5) void {
    set.* |= u32(1) << (signo - 1);
}

/// Takes the return value from a syscall and formats it back in the way
/// that the kernel represents it to libc. Errno was a mistake, let's make
/// it go away forever.
fn errnoWrap(value: isize) usize {
    return @bitCast(usize, if (value == -1) -isize(c._errno().*) else value);
}

pub const timezone = c.timezone;
pub const timeval = c.timeval;
pub const mach_timebase_info_data = c.mach_timebase_info_data;

pub const mach_absolute_time = c.mach_absolute_time;
pub const mach_timebase_info = c.mach_timebase_info;
