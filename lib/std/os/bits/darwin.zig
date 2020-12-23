// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../../std.zig");
const assert = std.debug.assert;
const maxInt = std.math.maxInt;

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
};
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

/// UNIX domain socket
pub const sockaddr_un = extern struct {
    len: u8 = @sizeOf(sockaddr_un),
    family: sa_family_t = AF_UNIX,
    path: [104]u8,
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

pub const libc_stat = extern struct {
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

pub const SIG_ERR = @intToPtr(?Sigaction.sigaction_fn, maxInt(usize));
pub const SIG_DFL = @intToPtr(?Sigaction.sigaction_fn, 0);
pub const SIG_IGN = @intToPtr(?Sigaction.sigaction_fn, 1);
pub const SIG_HOLD = @intToPtr(?Sigaction.sigaction_fn, 5);

pub const siginfo_t = extern struct {
    signo: c_int,
    errno: c_int,
    code: c_int,
    pid: pid_t,
    uid: uid_t,
    status: c_int,
    addr: *c_void,
    value: extern union {
        int: c_int,
        ptr: *c_void,
    },
    si_band: c_long,
    _pad: [7]c_ulong,
};

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with function name.
pub const Sigaction = extern struct {
    pub const handler_fn = fn (c_int) callconv(.C) void;
    pub const sigaction_fn = fn (c_int, *const siginfo_t, ?*const c_void) callconv(.C) void;

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
    assert(@byteOffsetOf(Kevent, "ident") == 0);
    assert(@byteOffsetOf(Kevent, "filter") == 8);
    assert(@byteOffsetOf(Kevent, "flags") == 10);
    assert(@byteOffsetOf(Kevent, "fflags") == 12);
    assert(@byteOffsetOf(Kevent, "data") == 16);
    assert(@byteOffsetOf(Kevent, "udata") == 24);
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
    assert(@byteOffsetOf(kevent64_s, "ident") == 0);
    assert(@byteOffsetOf(kevent64_s, "filter") == 8);
    assert(@byteOffsetOf(kevent64_s, "flags") == 10);
    assert(@byteOffsetOf(kevent64_s, "fflags") == 12);
    assert(@byteOffsetOf(kevent64_s, "data") == 16);
    assert(@byteOffsetOf(kevent64_s, "udata") == 24);
    assert(@byteOffsetOf(kevent64_s, "ext") == 32);
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
pub const MAP_FAILED = @intToPtr(*c_void, maxInt(usize));

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

pub const AF_UNSPEC = 0;
pub const AF_LOCAL = 1;
pub const AF_UNIX = AF_LOCAL;
pub const AF_INET = 2;
pub const AF_SYS_CONTROL = 2;
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
pub const AF_XTP = 19;
pub const AF_COIP = 20;
pub const AF_CNT = 21;
pub const AF_RTIP = 22;
pub const AF_IPX = 23;
pub const AF_SIP = 24;
pub const AF_PIP = 25;
pub const AF_ISDN = 28;
pub const AF_E164 = AF_ISDN;
pub const AF_KEY = 29;
pub const AF_INET6 = 30;
pub const AF_NATM = 31;
pub const AF_SYSTEM = 32;
pub const AF_NETBIOS = 33;
pub const AF_PPP = 34;
pub const AF_MAX = 40;

pub const PF_UNSPEC = AF_UNSPEC;
pub const PF_LOCAL = AF_LOCAL;
pub const PF_UNIX = PF_LOCAL;
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
pub const PF_XTP = AF_XTP;
pub const PF_COIP = AF_COIP;
pub const PF_CNT = AF_CNT;
pub const PF_SIP = AF_SIP;
pub const PF_IPX = AF_IPX;
pub const PF_RTIP = AF_RTIP;
pub const PF_PIP = AF_PIP;
pub const PF_ISDN = AF_ISDN;
pub const PF_KEY = AF_KEY;
pub const PF_INET6 = AF_INET6;
pub const PF_NATM = AF_NATM;
pub const PF_SYSTEM = AF_SYSTEM;
pub const PF_NETBIOS = AF_NETBIOS;
pub const PF_PPP = AF_PPP;
pub const PF_MAX = AF_MAX;

pub const SYSPROTO_EVENT = 1;
pub const SYSPROTO_CONTROL = 2;

pub const SOCK_STREAM = 1;
pub const SOCK_DGRAM = 2;
pub const SOCK_RAW = 3;
pub const SOCK_RDM = 4;
pub const SOCK_SEQPACKET = 5;
pub const SOCK_MAXADDRLEN = 255;

/// Not actually supported by Darwin, but Zig supplies a shim.
/// This numerical value is not ABI-stable. It need only not conflict
/// with any other "SOCK_" bits.
pub const SOCK_CLOEXEC = 1 << 15;
/// Not actually supported by Darwin, but Zig supplies a shim.
/// This numerical value is not ABI-stable. It need only not conflict
/// with any other "SOCK_" bits.
pub const SOCK_NONBLOCK = 1 << 16;

pub const IPPROTO_ICMP = 1;
pub const IPPROTO_ICMPV6 = 58;
pub const IPPROTO_TCP = 6;
pub const IPPROTO_UDP = 17;
pub const IPPROTO_IP = 0;
pub const IPPROTO_IPV6 = 41;

pub const SOL_SOCKET = 0xffff;

pub const SO_DEBUG = 0x0001;
pub const SO_ACCEPTCONN = 0x0002;
pub const SO_REUSEADDR = 0x0004;
pub const SO_KEEPALIVE = 0x0008;
pub const SO_DONTROUTE = 0x0010;
pub const SO_BROADCAST = 0x0020;
pub const SO_USELOOPBACK = 0x0040;
pub const SO_LINGER = 0x1080;
pub const SO_OOBINLINE = 0x0100;
pub const SO_REUSEPORT = 0x0200;
pub const SO_ACCEPTFILTER = 0x1000;
pub const SO_SNDBUF = 0x1001;
pub const SO_RCVBUF = 0x1002;
pub const SO_SNDLOWAT = 0x1003;
pub const SO_RCVLOWAT = 0x1004;
pub const SO_SNDTIMEO = 0x1005;
pub const SO_RCVTIMEO = 0x1006;
pub const SO_ERROR = 0x1007;
pub const SO_TYPE = 0x1008;

fn wstatus(x: u32) u32 {
    return x & 0o177;
}
const wstopped = 0o177;
pub fn WEXITSTATUS(x: u32) u32 {
    return x >> 8;
}
pub fn WTERMSIG(x: u32) u32 {
    return wstatus(x);
}
pub fn WSTOPSIG(x: u32) u32 {
    return x >> 8;
}
pub fn WIFEXITED(x: u32) bool {
    return wstatus(x) == 0;
}
pub fn WIFSTOPPED(x: u32) bool {
    return wstatus(x) == wstopped and WSTOPSIG(x) != 0x13;
}
pub fn WIFSIGNALED(x: u32) bool {
    return wstatus(x) != wstopped and wstatus(x) != 0;
}

/// Operation not permitted
pub const EPERM = 1;

/// No such file or directory
pub const ENOENT = 2;

/// No such process
pub const ESRCH = 3;

/// Interrupted system call
pub const EINTR = 4;

/// Input/output error
pub const EIO = 5;

/// Device not configured
pub const ENXIO = 6;

/// Argument list too long
pub const E2BIG = 7;

/// Exec format error
pub const ENOEXEC = 8;

/// Bad file descriptor
pub const EBADF = 9;

/// No child processes
pub const ECHILD = 10;

/// Resource deadlock avoided
pub const EDEADLK = 11;

/// Cannot allocate memory
pub const ENOMEM = 12;

/// Permission denied
pub const EACCES = 13;

/// Bad address
pub const EFAULT = 14;

/// Block device required
pub const ENOTBLK = 15;

/// Device / Resource busy
pub const EBUSY = 16;

/// File exists
pub const EEXIST = 17;

/// Cross-device link
pub const EXDEV = 18;

/// Operation not supported by device
pub const ENODEV = 19;

/// Not a directory
pub const ENOTDIR = 20;

/// Is a directory
pub const EISDIR = 21;

/// Invalid argument
pub const EINVAL = 22;

/// Too many open files in system
pub const ENFILE = 23;

/// Too many open files
pub const EMFILE = 24;

/// Inappropriate ioctl for device
pub const ENOTTY = 25;

/// Text file busy
pub const ETXTBSY = 26;

/// File too large
pub const EFBIG = 27;

/// No space left on device
pub const ENOSPC = 28;

/// Illegal seek
pub const ESPIPE = 29;

/// Read-only file system
pub const EROFS = 30;

/// Too many links
pub const EMLINK = 31;
/// Broken pipe

// math software
pub const EPIPE = 32;

/// Numerical argument out of domain
pub const EDOM = 33;
/// Result too large

// non-blocking and interrupt i/o
pub const ERANGE = 34;

/// Resource temporarily unavailable
pub const EAGAIN = 35;

/// Operation would block
pub const EWOULDBLOCK = EAGAIN;

/// Operation now in progress
pub const EINPROGRESS = 36;
/// Operation already in progress

// ipc/network software -- argument errors
pub const EALREADY = 37;

/// Socket operation on non-socket
pub const ENOTSOCK = 38;

/// Destination address required
pub const EDESTADDRREQ = 39;

/// Message too long
pub const EMSGSIZE = 40;

/// Protocol wrong type for socket
pub const EPROTOTYPE = 41;

/// Protocol not available
pub const ENOPROTOOPT = 42;

/// Protocol not supported
pub const EPROTONOSUPPORT = 43;

/// Socket type not supported
pub const ESOCKTNOSUPPORT = 44;

/// Operation not supported
pub const ENOTSUP = 45;

/// Operation not supported. Alias of `ENOTSUP`.
pub const EOPNOTSUPP = ENOTSUP;

/// Protocol family not supported
pub const EPFNOSUPPORT = 46;

/// Address family not supported by protocol family
pub const EAFNOSUPPORT = 47;

/// Address already in use
pub const EADDRINUSE = 48;
/// Can't assign requested address

// ipc/network software -- operational errors
pub const EADDRNOTAVAIL = 49;

/// Network is down
pub const ENETDOWN = 50;

/// Network is unreachable
pub const ENETUNREACH = 51;

/// Network dropped connection on reset
pub const ENETRESET = 52;

/// Software caused connection abort
pub const ECONNABORTED = 53;

/// Connection reset by peer
pub const ECONNRESET = 54;

/// No buffer space available
pub const ENOBUFS = 55;

/// Socket is already connected
pub const EISCONN = 56;

/// Socket is not connected
pub const ENOTCONN = 57;

/// Can't send after socket shutdown
pub const ESHUTDOWN = 58;

/// Too many references: can't splice
pub const ETOOMANYREFS = 59;

/// Operation timed out
pub const ETIMEDOUT = 60;

/// Connection refused
pub const ECONNREFUSED = 61;

/// Too many levels of symbolic links
pub const ELOOP = 62;

/// File name too long
pub const ENAMETOOLONG = 63;

/// Host is down
pub const EHOSTDOWN = 64;

/// No route to host
pub const EHOSTUNREACH = 65;
/// Directory not empty

// quotas & mush
pub const ENOTEMPTY = 66;

/// Too many processes
pub const EPROCLIM = 67;

/// Too many users
pub const EUSERS = 68;
/// Disc quota exceeded

// Network File System
pub const EDQUOT = 69;

/// Stale NFS file handle
pub const ESTALE = 70;

/// Too many levels of remote in path
pub const EREMOTE = 71;

/// RPC struct is bad
pub const EBADRPC = 72;

/// RPC version wrong
pub const ERPCMISMATCH = 73;

/// RPC prog. not avail
pub const EPROGUNAVAIL = 74;

/// Program version wrong
pub const EPROGMISMATCH = 75;

/// Bad procedure for program
pub const EPROCUNAVAIL = 76;

/// No locks available
pub const ENOLCK = 77;

/// Function not implemented
pub const ENOSYS = 78;

/// Inappropriate file type or format
pub const EFTYPE = 79;

/// Authentication error
pub const EAUTH = 80;
/// Need authenticator

// Intelligent device errors
pub const ENEEDAUTH = 81;

/// Device power is off
pub const EPWROFF = 82;

/// Device error, e.g. paper out
pub const EDEVERR = 83;
/// Value too large to be stored in data type

// Program loading errors
pub const EOVERFLOW = 84;

/// Bad executable
pub const EBADEXEC = 85;

/// Bad CPU type in executable
pub const EBADARCH = 86;

/// Shared library version mismatch
pub const ESHLIBVERS = 87;

/// Malformed Macho file
pub const EBADMACHO = 88;

/// Operation canceled
pub const ECANCELED = 89;

/// Identifier removed
pub const EIDRM = 90;

/// No message of desired type
pub const ENOMSG = 91;

/// Illegal byte sequence
pub const EILSEQ = 92;

/// Attribute not found
pub const ENOATTR = 93;

/// Bad message
pub const EBADMSG = 94;

/// Reserved
pub const EMULTIHOP = 95;

/// No message available on STREAM
pub const ENODATA = 96;

/// Reserved
pub const ENOLINK = 97;

/// No STREAM resources
pub const ENOSR = 98;

/// Not a STREAM
pub const ENOSTR = 99;

/// Protocol error
pub const EPROTO = 100;

/// STREAM ioctl timeout
pub const ETIME = 101;

/// No such policy registered
pub const ENOPOLICY = 103;

/// State not recoverable
pub const ENOTRECOVERABLE = 104;

/// Previous owner died
pub const EOWNERDEAD = 105;

/// Interface output queue is full
pub const EQFULL = 106;

/// Must be equal largest errno
pub const ELAST = 106;

pub const SIGSTKSZ = 131072;
pub const MINSIGSTKSZ = 32768;

pub const SS_ONSTACK = 1;
pub const SS_DISABLE = 4;

pub const stack_t = extern struct {
    ss_sp: [*]u8,
    ss_size: isize,
    ss_flags: i32,
};

pub const S_IFMT = 0o170000;

pub const S_IFIFO = 0o010000;
pub const S_IFCHR = 0o020000;
pub const S_IFDIR = 0o040000;
pub const S_IFBLK = 0o060000;
pub const S_IFREG = 0o100000;
pub const S_IFLNK = 0o120000;
pub const S_IFSOCK = 0o140000;
pub const S_IFWHT = 0o160000;

pub const S_ISUID = 0o4000;
pub const S_ISGID = 0o2000;
pub const S_ISVTX = 0o1000;
pub const S_IRWXU = 0o700;
pub const S_IRUSR = 0o400;
pub const S_IWUSR = 0o200;
pub const S_IXUSR = 0o100;
pub const S_IRWXG = 0o070;
pub const S_IRGRP = 0o040;
pub const S_IWGRP = 0o020;
pub const S_IXGRP = 0o010;
pub const S_IRWXO = 0o007;
pub const S_IROTH = 0o004;
pub const S_IWOTH = 0o002;
pub const S_IXOTH = 0o001;

pub fn S_ISFIFO(m: u32) bool {
    return m & S_IFMT == S_IFIFO;
}

pub fn S_ISCHR(m: u32) bool {
    return m & S_IFMT == S_IFCHR;
}

pub fn S_ISDIR(m: u32) bool {
    return m & S_IFMT == S_IFDIR;
}

pub fn S_ISBLK(m: u32) bool {
    return m & S_IFMT == S_IFBLK;
}

pub fn S_ISREG(m: u32) bool {
    return m & S_IFMT == S_IFREG;
}

pub fn S_ISLNK(m: u32) bool {
    return m & S_IFMT == S_IFLNK;
}

pub fn S_ISSOCK(m: u32) bool {
    return m & S_IFMT == S_IFSOCK;
}

pub fn S_IWHT(m: u32) bool {
    return m & S_IFMT == S_IFWHT;
}

pub const HOST_NAME_MAX = 72;

pub const AT_FDCWD = -2;

/// Use effective ids in access check
pub const AT_EACCESS = 0x0010;

/// Act on the symlink itself not the target
pub const AT_SYMLINK_NOFOLLOW = 0x0020;

/// Act on target of symlink
pub const AT_SYMLINK_FOLLOW = 0x0040;

/// Path refers to directory
pub const AT_REMOVEDIR = 0x0080;

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

pub const RTLD_LAZY = 0x1;
pub const RTLD_NOW = 0x2;
pub const RTLD_LOCAL = 0x4;
pub const RTLD_GLOBAL = 0x8;
pub const RTLD_NOLOAD = 0x10;
pub const RTLD_NODELETE = 0x80;
pub const RTLD_FIRST = 0x100;

pub const RTLD_NEXT = @intToPtr(*c_void, @bitCast(usize, @as(isize, -1)));
pub const RTLD_DEFAULT = @intToPtr(*c_void, @bitCast(usize, @as(isize, -2)));
pub const RTLD_SELF = @intToPtr(*c_void, @bitCast(usize, @as(isize, -3)));
pub const RTLD_MAIN_ONLY = @intToPtr(*c_void, @bitCast(usize, @as(isize, -5)));

/// duplicate file descriptor
pub const F_DUPFD = 0;

/// get file descriptor flags
pub const F_GETFD = 1;

/// set file descriptor flags
pub const F_SETFD = 2;

/// get file status flags
pub const F_GETFL = 3;

/// set file status flags
pub const F_SETFL = 4;

/// get SIGIO/SIGURG proc/pgrp
pub const F_GETOWN = 5;

/// set SIGIO/SIGURG proc/pgrp
pub const F_SETOWN = 6;

/// get record locking information
pub const F_GETLK = 7;

/// set record locking information
pub const F_SETLK = 8;

/// F_SETLK; wait if blocked
pub const F_SETLKW = 9;

/// F_SETLK; wait if blocked, return on timeout
pub const F_SETLKWTIMEOUT = 10;
pub const F_FLUSH_DATA = 40;

/// Used for regression test
pub const F_CHKCLEAN = 41;

/// Preallocate storage
pub const F_PREALLOCATE = 42;

/// Truncate a file without zeroing space
pub const F_SETSIZE = 43;

/// Issue an advisory read async with no copy to user
pub const F_RDADVISE = 44;

/// turn read ahead off/on for this fd
pub const F_RDAHEAD = 45;

/// turn data caching off/on for this fd
pub const F_NOCACHE = 48;

/// file offset to device offset
pub const F_LOG2PHYS = 49;

/// return the full path of the fd
pub const F_GETPATH = 50;

/// fsync + ask the drive to flush to the media
pub const F_FULLFSYNC = 51;

/// find which component (if any) is a package
pub const F_PATHPKG_CHECK = 52;

/// "freeze" all fs operations
pub const F_FREEZE_FS = 53;

/// "thaw" all fs operations
pub const F_THAW_FS = 54;

/// turn data caching off/on (globally) for this file
pub const F_GLOBAL_NOCACHE = 55;

/// add detached signatures
pub const F_ADDSIGS = 59;

/// add signature from same file (used by dyld for shared libs)
pub const F_ADDFILESIGS = 61;

/// used in conjunction with F_NOCACHE to indicate that DIRECT, synchonous writes
/// should not be used (i.e. its ok to temporaily create cached pages)
pub const F_NODIRECT = 62;

///Get the protection class of a file from the EA, returns int
pub const F_GETPROTECTIONCLASS = 63;

///Set the protection class of a file for the EA, requires int
pub const F_SETPROTECTIONCLASS = 64;

///file offset to device offset, extended
pub const F_LOG2PHYS_EXT = 65;

///get record locking information, per-process
pub const F_GETLKPID = 66;

///Mark the file as being the backing store for another filesystem
pub const F_SETBACKINGSTORE = 70;

///return the full path of the FD, but error in specific mtmd circumstances
pub const F_GETPATH_MTMINFO = 71;

///Returns the code directory, with associated hashes, to the caller
pub const F_GETCODEDIR = 72;

///No SIGPIPE generated on EPIPE
pub const F_SETNOSIGPIPE = 73;

///Status of SIGPIPE for this fd
pub const F_GETNOSIGPIPE = 74;

///For some cases, we need to rewrap the key for AKS/MKB
pub const F_TRANSCODEKEY = 75;

///file being written to a by single writer... if throttling enabled, writes
///may be broken into smaller chunks with throttling in between
pub const F_SINGLE_WRITER = 76;

///Get the protection version number for this filesystem
pub const F_GETPROTECTIONLEVEL = 77;

///Add detached code signatures (used by dyld for shared libs)
pub const F_FINDSIGS = 78;

///Add signature from same file, only if it is signed by Apple (used by dyld for simulator)
pub const F_ADDFILESIGS_FOR_DYLD_SIM = 83;

///fsync + issue barrier to drive
pub const F_BARRIERFSYNC = 85;

///Add signature from same file, return end offset in structure on success
pub const F_ADDFILESIGS_RETURN = 97;

///Check if Library Validation allows this Mach-O file to be mapped into the calling process
pub const F_CHECK_LV = 98;

///Deallocate a range of the file
pub const F_PUNCHHOLE = 99;

///Trim an active file
pub const F_TRIM_ACTIVE_FILE = 100;

pub const FCNTL_FS_SPECIFIC_BASE = 0x00010000;

///mark the dup with FD_CLOEXEC
pub const F_DUPFD_CLOEXEC = 67;

///close-on-exec flag
pub const FD_CLOEXEC = 1;

/// shared or read lock
pub const F_RDLCK = 1;

/// unlock
pub const F_UNLCK = 2;

/// exclusive or write lock
pub const F_WRLCK = 3;

pub const LOCK_SH = 1;
pub const LOCK_EX = 2;
pub const LOCK_UN = 8;
pub const LOCK_NB = 4;

pub const nfds_t = usize;
pub const pollfd = extern struct {
    fd: fd_t,
    events: i16,
    revents: i16,
};

pub const POLLIN = 0x001;
pub const POLLPRI = 0x002;
pub const POLLOUT = 0x004;
pub const POLLRDNORM = 0x040;
pub const POLLWRNORM = POLLOUT;
pub const POLLRDBAND = 0x080;
pub const POLLWRBAND = 0x100;

pub const POLLEXTEND = 0x0200;
pub const POLLATTRIB = 0x0400;
pub const POLLNLINK = 0x0800;
pub const POLLWRITE = 0x1000;

pub const POLLERR = 0x008;
pub const POLLHUP = 0x010;
pub const POLLNVAL = 0x020;

pub const POLLSTANDARD = POLLIN | POLLPRI | POLLOUT | POLLRDNORM | POLLRDBAND | POLLWRBAND | POLLERR | POLLHUP | POLLNVAL;

pub const CLOCK_REALTIME = 0;
pub const CLOCK_MONOTONIC = 6;
pub const CLOCK_MONOTONIC_RAW = 4;
pub const CLOCK_MONOTONIC_RAW_APPROX = 5;
pub const CLOCK_UPTIME_RAW = 8;
pub const CLOCK_UPTIME_RAW_APPROX = 9;
pub const CLOCK_PROCESS_CPUTIME_ID = 12;
pub const CLOCK_THREAD_CPUTIME_ID = 16;

/// Max open files per process
/// https://opensource.apple.com/source/xnu/xnu-4903.221.2/bsd/sys/syslimits.h.auto.html
pub const OPEN_MAX = 10240;
pub const RUSAGE_SELF = 0;
pub const RUSAGE_CHILDREN = -1;

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
};

pub const rlimit_resource = extern enum(c_int) {
    CPU = 0,
    FSIZE = 1,
    DATA = 2,
    STACK = 3,
    CORE = 4,
    AS = 5,
    RSS = 5,
    MEMLOCK = 6,
    NPROC = 7,
    NOFILE = 8,

    _,
};

pub const rlim_t = u64;

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

// Term
pub const VEOF = 0;
pub const VEOL = 1;
pub const VEOL2 = 2;
pub const VERASE = 3;
pub const VWERASE = 4;
pub const VKILL = 5;
pub const VREPRINT = 6;
pub const VINTR = 8;
pub const VQUIT = 9;
pub const VSUSP = 10;
pub const VDSUSP = 11;
pub const VSTART = 12;
pub const VSTOP = 13;
pub const VLNEXT = 14;
pub const VDISCARD = 15;
pub const VMIN = 16;
pub const VTIME = 17;
pub const VSTATUS = 18;
pub const NCCS = 20; // 2 spares (7, 19)

pub const IGNBRK = 0x00000001; // ignore BREAK condition
pub const BRKINT = 0x00000002; // map BREAK to SIGINTR
pub const IGNPAR = 0x00000004; // ignore (discard) parity errors
pub const PARMRK = 0x00000008; // mark parity and framing errors
pub const INPCK = 0x00000010; // enable checking of parity errors
pub const ISTRIP = 0x00000020; // strip 8th bit off chars
pub const INLCR = 0x00000040; // map NL into CR
pub const IGNCR = 0x00000080; // ignore CR
pub const ICRNL = 0x00000100; // map CR to NL (ala CRMOD)
pub const IXON = 0x00000200; // enable output flow control
pub const IXOFF = 0x00000400; // enable input flow control
pub const IXANY = 0x00000800; // any char will restart after stop
pub const IMAXBEL = 0x00002000; // ring bell on input queue full
pub const IUTF8 = 0x00004000; // maintain state for UTF-8 VERASE

pub const OPOST = 0x00000001; //enable following output processing
pub const ONLCR = 0x00000002; // map NL to CR-NL (ala CRMOD)
pub const OXTABS = 0x00000004; // expand tabs to spaces
pub const ONOEOT = 0x00000008; // discard EOT's (^D) on output)

pub const OCRNL = 0x00000010; // map CR to NL on output
pub const ONOCR = 0x00000020; // no CR output at column 0
pub const ONLRET = 0x00000040; // NL performs CR function
pub const OFILL = 0x00000080; // use fill characters for delay
pub const NLDLY = 0x00000300; // \n delay
pub const TABDLY = 0x00000c04; // horizontal tab delay
pub const CRDLY = 0x00003000; // \r delay
pub const FFDLY = 0x00004000; // form feed delay
pub const BSDLY = 0x00008000; // \b delay
pub const VTDLY = 0x00010000; // vertical tab delay
pub const OFDEL = 0x00020000; // fill is DEL, else NUL

pub const NL0 = 0x00000000;
pub const NL1 = 0x00000100;
pub const NL2 = 0x00000200;
pub const NL3 = 0x00000300;
pub const TAB0 = 0x00000000;
pub const TAB1 = 0x00000400;
pub const TAB2 = 0x00000800;
pub const TAB3 = 0x00000004;
pub const CR0 = 0x00000000;
pub const CR1 = 0x00001000;
pub const CR2 = 0x00002000;
pub const CR3 = 0x00003000;
pub const FF0 = 0x00000000;
pub const FF1 = 0x00004000;
pub const BS0 = 0x00000000;
pub const BS1 = 0x00008000;
pub const VT0 = 0x00000000;
pub const VT1 = 0x00010000;

pub const CIGNORE = 0x00000001; // ignore control flags
pub const CSIZE = 0x00000300; // character size mask
pub const CS5 = 0x00000000; //    5 bits (pseudo)
pub const CS6 = 0x00000100; //    6 bits
pub const CS7 = 0x00000200; //    7 bits
pub const CS8 = 0x00000300; //    8 bits
pub const CSTOPB = 0x0000040; // send 2 stop bits
pub const CREAD = 0x00000800; // enable receiver
pub const PARENB = 0x00001000; // parity enable
pub const PARODD = 0x00002000; // odd parity, else even
pub const HUPCL = 0x00004000; // hang up on last close
pub const CLOCAL = 0x00008000; // ignore modem status lines
pub const CCTS_OFLOW = 0x00010000; // CTS flow control of output
pub const CRTSCTS = (CCTS_OFLOW | CRTS_IFLOW);
pub const CRTS_IFLOW = 0x00020000; // RTS flow control of input
pub const CDTR_IFLOW = 0x00040000; // DTR flow control of input
pub const CDSR_OFLOW = 0x00080000; // DSR flow control of output
pub const CCAR_OFLOW = 0x00100000; // DCD flow control of output
pub const MDMBUF = 0x00100000; // old name for CCAR_OFLOW

pub const ECHOKE = 0x00000001; // visual erase for line kill
pub const ECHOE = 0x00000002; // visually erase chars
pub const ECHOK = 0x00000004; // echo NL after line kill
pub const ECHO = 0x00000008; // enable echoing
pub const ECHONL = 0x00000010; // echo NL even if ECHO is off
pub const ECHOPRT = 0x00000020; // visual erase mode for hardcopy
pub const ECHOCTL = 0x00000040; // echo control chars as ^(Char)
pub const ISIG = 0x00000080; // enable signals INTR, QUIT, [D]SUSP
pub const ICANON = 0x00000100; // canonicalize input lines
pub const ALTWERASE = 0x00000200; // use alternate WERASE algorithm
pub const IEXTEN = 0x00000400; // enable DISCARD and LNEXT
pub const EXTPROC = 0x00000800; // external processing
pub const TOSTOP = 0x00400000; // stop background jobs from output
pub const FLUSHO = 0x00800000; // output being flushed (state)
pub const NOKERNINFO = 0x02000000; // no kernel output from VSTATUS
pub const PENDIN = 0x20000000; // XXX retype pending input (state)
pub const NOFLSH = 0x80000000; // don't flush after interrupt

pub const TCSANOW = 0; // make change immediate
pub const TCSADRAIN = 1; // drain output, then change
pub const TCSAFLUSH = 2; // drain output, flush input
pub const TCSASOFT = 0x10; // flag - don't alter h.w. state
pub const TCSA = extern enum(c_uint) {
    NOW,
    DRAIN,
    FLUSH,
    _,
};

pub const B0 = 0;
pub const B50 = 50;
pub const B75 = 75;
pub const B110 = 110;
pub const B134 = 134;
pub const B150 = 150;
pub const B200 = 200;
pub const B300 = 300;
pub const B600 = 600;
pub const B1200 = 1200;
pub const B1800 = 1800;
pub const B2400 = 2400;
pub const B4800 = 4800;
pub const B9600 = 9600;
pub const B19200 = 19200;
pub const B38400 = 38400;
pub const B7200 = 7200;
pub const B14400 = 14400;
pub const B28800 = 28800;
pub const B57600 = 57600;
pub const B76800 = 76800;
pub const B115200 = 115200;
pub const B230400 = 230400;
pub const EXTA = 19200;
pub const EXTB = 38400;

pub const TCIFLUSH = 1;
pub const TCOFLUSH = 2;
pub const TCIOFLUSH = 3;
pub const TCOOFF = 1;
pub const TCOON = 2;
pub const TCIOFF = 3;
pub const TCION = 4;

pub const cc_t = u8;
pub const speed_t = u64;
pub const tcflag_t = u64;

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

pub const TIOCGWINSZ = ior(0x40000000, 't', 104, @sizeOf(winsize));
pub const IOCPARM_MASK = 0x1fff;

fn ior(inout: u32, group: usize, num: usize, len: usize) usize {
    return (inout | ((len & IOCPARM_MASK) << 16) | ((group) << 8) | (num));
}
