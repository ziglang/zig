const std = @import("../std.zig");
const builtin = @import("builtin");

pub const fd_t = i32;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;
pub const PATH_MAX = 1023;
pub const syscall_bits = switch (builtin.cpu.arch) {
    .x86_64 => @import("plan9/x86_64.zig"),
    else => @compileError("more plan9 syscall implementations (needs more inline asm in stage2"),
};
/// Ported from /sys/include/ape/errno.h
pub const E = enum(u16) {
    SUCCESS = 0,
    DOM = 1000,
    RANGE = 1001,
    PLAN9 = 1002,

    @"2BIG" = 1,
    ACCES = 2,
    AGAIN = 3,
    // WOULDBLOCK = 3, // TODO errno.h has 2 names for 3
    BADF = 4,
    BUSY = 5,
    CHILD = 6,
    DEADLK = 7,
    EXIST = 8,
    FAULT = 9,
    FBIG = 10,
    INTR = 11,
    INVAL = 12,
    IO = 13,
    ISDIR = 14,
    MFILE = 15,
    MLINK = 16,
    NAMETOOLONG = 17,
    NFILE = 18,
    NODEV = 19,
    NOENT = 20,
    NOEXEC = 21,
    NOLCK = 22,
    NOMEM = 23,
    NOSPC = 24,
    NOSYS = 25,
    NOTDIR = 26,
    NOTEMPTY = 27,
    NOTTY = 28,
    NXIO = 29,
    PERM = 30,
    PIPE = 31,
    ROFS = 32,
    SPIPE = 33,
    SRCH = 34,
    XDEV = 35,

    // bsd networking software
    NOTSOCK = 36,
    PROTONOSUPPORT = 37,
    // PROTOTYPE = 37, // TODO errno.h has two names for 37
    CONNREFUSED = 38,
    AFNOSUPPORT = 39,
    NOBUFS = 40,
    OPNOTSUPP = 41,
    ADDRINUSE = 42,
    DESTADDRREQ = 43,
    MSGSIZE = 44,
    NOPROTOOPT = 45,
    SOCKTNOSUPPORT = 46,
    PFNOSUPPORT = 47,
    ADDRNOTAVAIL = 48,
    NETDOWN = 49,
    NETUNREACH = 50,
    NETRESET = 51,
    CONNABORTED = 52,
    ISCONN = 53,
    NOTCONN = 54,
    SHUTDOWN = 55,
    TOOMANYREFS = 56,
    TIMEDOUT = 57,
    HOSTDOWN = 58,
    HOSTUNREACH = 59,
    GREG = 60,

    // These added in 1003.1b-1993
    CANCELED = 61,
    INPROGRESS = 62,

    // We just add these to be compatible with std.os, which uses them,
    // They should never get used.
    DQUOT,
    CONNRESET,
    OVERFLOW,
    LOOP,
    TXTBSY,

    pub fn init(r: usize) E {
        const signed_r: isize = @bitCast(r);
        const int = if (signed_r > -4096 and signed_r < 0) -signed_r else 0;
        return @enumFromInt(int);
    }
};
// The max bytes that can be in the errstr buff
pub const ERRMAX = 128;
var errstr_buf: [ERRMAX]u8 = undefined;
/// Gets whatever the last errstr was
pub fn errstr() []const u8 {
    _ = syscall_bits.syscall2(.ERRSTR, @intFromPtr(&errstr_buf), ERRMAX);
    return std.mem.span(@as([*:0]u8, @ptrCast(&errstr_buf)));
}
pub const Plink = anyopaque;
pub const Tos = extern struct {
    /// Per process profiling
    prof: extern struct {
        /// known to be 0(ptr)
        pp: *Plink,
        /// known to be 4(ptr)
        next: *Plink,
        last: *Plink,
        first: *Plink,
        pid: u32,
        what: u32,
    },
    /// cycle clock frequency if there is one, 0 otherwise
    cyclefreq: u64,
    /// cycles spent in kernel
    kcycles: i64,
    /// cycles spent in process (kernel + user)
    pcycles: i64,
    /// might as well put the pid here
    pid: u32,
    clock: u32,
    // top of stack is here
};

pub var tos: *Tos = undefined; // set in start.zig
pub fn getpid() u32 {
    return tos.pid;
}
pub const SIG = struct {
    /// hangup
    pub const HUP = 1;
    /// interrupt
    pub const INT = 2;
    /// quit
    pub const QUIT = 3;
    /// illegal instruction (not reset when caught)
    pub const ILL = 4;
    /// used by abort
    pub const ABRT = 5;
    /// floating point exception
    pub const FPE = 6;
    /// kill (cannot be caught or ignored)
    pub const KILL = 7;
    /// segmentation violation
    pub const SEGV = 8;
    /// write on a pipe with no one to read it
    pub const PIPE = 9;
    /// alarm clock
    pub const ALRM = 10;
    /// software termination signal from kill
    pub const TERM = 11;
    /// user defined signal 1
    pub const USR1 = 12;
    /// user defined signal 2
    pub const USR2 = 13;
    /// bus error
    pub const BUS = 14;
    // The following symbols must be defined, but the signals needn't be supported
    /// child process terminated or stopped
    pub const CHLD = 15;
    /// continue if stopped
    pub const CONT = 16;
    /// stop
    pub const STOP = 17;
    /// interactive stop
    pub const TSTP = 18;
    /// read from ctl tty by member of background
    pub const TTIN = 19;
    /// write to ctl tty by member of background
    pub const TTOU = 20;
};
pub const sigset_t = c_long;
pub const empty_sigset = 0;
pub const siginfo_t = c_long;
// TODO plan9 doesn't have sigaction_fn. Sigaction is not a union, but we incude it here to be compatible.
pub const Sigaction = extern struct {
    pub const handler_fn = *const fn (i32) callconv(.C) void;
    pub const sigaction_fn = *const fn (i32, *const siginfo_t, ?*anyopaque) callconv(.C) void;

    handler: extern union {
        handler: ?handler_fn,
        sigaction: ?sigaction_fn,
    },
    mask: sigset_t,
    flags: c_int,
};
pub const AT = struct {
    pub const FDCWD = -100; // we just make up a constant; FDCWD and openat don't actually exist in plan9
};
// TODO implement sigaction
// right now it is just a shim to allow using start.zig code
pub fn sigaction(sig: u6, noalias act: ?*const Sigaction, noalias oact: ?*Sigaction) usize {
    _ = oact;
    _ = act;
    _ = sig;
    return 0;
}
pub const SYS = enum(usize) {
    SYSR1 = 0,
    _ERRSTR = 1,
    BIND = 2,
    CHDIR = 3,
    CLOSE = 4,
    DUP = 5,
    ALARM = 6,
    EXEC = 7,
    EXITS = 8,
    _FSESSION = 9,
    FAUTH = 10,
    _FSTAT = 11,
    SEGBRK = 12,
    _MOUNT = 13,
    OPEN = 14,
    _READ = 15,
    OSEEK = 16,
    SLEEP = 17,
    _STAT = 18,
    RFORK = 19,
    _WRITE = 20,
    PIPE = 21,
    CREATE = 22,
    FD2PATH = 23,
    BRK_ = 24,
    REMOVE = 25,
    _WSTAT = 26,
    _FWSTAT = 27,
    NOTIFY = 28,
    NOTED = 29,
    SEGATTACH = 30,
    SEGDETACH = 31,
    SEGFREE = 32,
    SEGFLUSH = 33,
    RENDEZVOUS = 34,
    UNMOUNT = 35,
    _WAIT = 36,
    SEMACQUIRE = 37,
    SEMRELEASE = 38,
    SEEK = 39,
    FVERSION = 40,
    ERRSTR = 41,
    STAT = 42,
    FSTAT = 43,
    WSTAT = 44,
    FWSTAT = 45,
    MOUNT = 46,
    AWAIT = 47,
    PREAD = 50,
    PWRITE = 51,
    TSEMACQUIRE = 52,
    _NSEC = 53,
};

pub fn write(fd: i32, buf: [*]const u8, count: usize) usize {
    return syscall_bits.syscall4(.PWRITE, @bitCast(@as(isize, fd)), @intFromPtr(buf), count, @bitCast(@as(isize, -1)));
}
pub fn pwrite(fd: i32, buf: [*]const u8, count: usize, offset: isize) usize {
    return syscall_bits.syscall4(.PWRITE, @bitCast(@as(isize, fd)), @intFromPtr(buf), count, @bitCast(offset));
}

pub fn read(fd: i32, buf: [*]const u8, count: usize) usize {
    return syscall_bits.syscall4(.PREAD, @bitCast(@as(isize, fd)), @intFromPtr(buf), count, @bitCast(@as(isize, -1)));
}
pub fn pread(fd: i32, buf: [*]const u8, count: usize, offset: isize) usize {
    return syscall_bits.syscall4(.PREAD, @bitCast(@as(isize, fd)), @intFromPtr(buf), count, @bitCast(offset));
}

pub fn open(path: [*:0]const u8, flags: u32) usize {
    return syscall_bits.syscall2(.OPEN, @intFromPtr(path), @bitCast(@as(isize, flags)));
}

pub fn openat(dirfd: i32, path: [*:0]const u8, flags: u32, _: mode_t) usize {
    // we skip perms because only create supports perms
    if (dirfd == AT.FDCWD) { // openat(AT_FDCWD, ...) == open(...)
        return open(path, flags);
    }
    var dir_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var total_path_buf: [std.fs.MAX_PATH_BYTES + 1]u8 = undefined;
    const rc = fd2path(dirfd, &dir_path_buf, std.fs.MAX_PATH_BYTES);
    if (rc != 0) return rc;
    var fba = std.heap.FixedBufferAllocator.init(&total_path_buf);
    var alloc = fba.allocator();
    const dir_path = std.mem.span(@as([*:0]u8, @ptrCast(&dir_path_buf)));
    const total_path = std.fs.path.join(alloc, &.{ dir_path, std.mem.span(path) }) catch unreachable; // the allocation shouldn't fail because it should not exceed MAX_PATH_BYTES
    fba.reset();
    const total_path_z = alloc.dupeZ(u8, total_path) catch unreachable; // should not exceed MAX_PATH_BYTES + 1
    return open(total_path_z.ptr, flags);
}

pub fn fd2path(fd: i32, buf: [*]u8, nbuf: usize) usize {
    return syscall_bits.syscall3(.FD2PATH, @bitCast(@as(isize, fd)), @intFromPtr(buf), nbuf);
}

pub fn create(path: [*:0]const u8, omode: mode_t, perms: usize) usize {
    return syscall_bits.syscall3(.CREATE, @intFromPtr(path), @bitCast(@as(isize, omode)), perms);
}

pub fn exit(status: u8) noreturn {
    if (status == 0) {
        exits(null);
    } else {
        // TODO plan9 does not have exit codes. You either exit with 0 or a string
        const arr: [1:0]u8 = .{status};
        exits(&arr);
    }
}

pub fn exits(status: ?[*:0]const u8) noreturn {
    _ = syscall_bits.syscall1(.EXITS, if (status) |s| @intFromPtr(s) else 0);
    unreachable;
}

pub fn close(fd: i32) usize {
    return syscall_bits.syscall1(.CLOSE, @bitCast(@as(isize, fd)));
}
pub const mode_t = i32;

pub const AccessMode = enum(u2) {
    RDONLY,
    WRONLY,
    RDWR,
    EXEC,
};

pub const O = packed struct(u32) {
    access: AccessMode,
    _2: u2 = 0,
    TRUNC: bool = false,
    CEXEC: bool = false,
    RCLOSE: bool = false,
    _7: u5 = 0,
    EXCL: bool = false,
    _: u19 = 0,
};

pub const ExecData = struct {
    pub extern const etext: anyopaque;
    pub extern const edata: anyopaque;
    pub extern const end: anyopaque;
};

/// Brk sets the system's idea of the lowest bss location not
/// used by the program (called the break) to addr rounded up to
/// the next multiple of 8 bytes.  Locations not less than addr
/// and below the stack pointer may cause a memory violation if
/// accessed. -9front brk(2)
pub fn brk_(addr: usize) i32 {
    return @intCast(syscall_bits.syscall1(.BRK_, addr));
}
var bloc: usize = 0;
var bloc_max: usize = 0;

pub fn sbrk(n: usize) usize {
    if (bloc == 0) {
        // we are at the start
        bloc = @intFromPtr(&ExecData.end);
        bloc_max = @intFromPtr(&ExecData.end);
    }
    const bl = std.mem.alignForward(usize, bloc, std.mem.page_size);
    const n_aligned = std.mem.alignForward(usize, n, std.mem.page_size);
    if (bl + n_aligned > bloc_max) {
        // we need to allocate
        if (brk_(bl + n_aligned) < 0) return 0;
        bloc_max = bl + n_aligned;
    }
    bloc = bloc + n_aligned;
    return bl;
}
