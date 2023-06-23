const std = @import("../std.zig");
const builtin = @import("builtin");

pub const syscall_bits = switch (builtin.cpu.arch) {
    .x86_64 => @import("plan9/x86_64.zig"),
    else => @compileError("more plan9 syscall implementations (needs more inline asm in stage2"),
};
pub const E = @import("plan9/errno.zig").E;
/// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: usize) E {
    const signed_r = @bitCast(isize, r);
    const int = if (signed_r > -4096 and signed_r < 0) -signed_r else 0;
    return @enumFromInt(E, int);
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
pub const siginfo_t = c_long; // TODO plan9 doesn't have sigaction_fn. Sigaction is not a union, but we incude it here to be compatible.
pub const Sigaction = extern struct {
    pub const handler_fn = *const fn (c_int) callconv(.C) void;
    pub const sigaction_fn = *const fn (c_int, *const siginfo_t, ?*const anyopaque) callconv(.C) void;

    handler: extern union {
        handler: ?handler_fn,
        sigaction: ?sigaction_fn,
    },
    mask: sigset_t,
    flags: c_int,
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

pub fn pwrite(fd: usize, buf: [*]const u8, count: usize, offset: usize) usize {
    return syscall_bits.syscall4(.PWRITE, fd, @intFromPtr(buf), count, offset);
}

pub fn pread(fd: usize, buf: [*]const u8, count: usize, offset: usize) usize {
    return syscall_bits.syscall4(.PREAD, fd, @intFromPtr(buf), count, offset);
}

pub fn open(path: [*:0]const u8, omode: OpenMode) usize {
    return syscall_bits.syscall2(.OPEN, @intFromPtr(path), @intFromEnum(omode));
}

pub fn create(path: [*:0]const u8, omode: OpenMode, perms: usize) usize {
    return syscall_bits.syscall3(.CREATE, @intFromPtr(path), @intFromEnum(omode), perms);
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

pub fn close(fd: usize) usize {
    return syscall_bits.syscall1(.CLOSE, fd);
}
pub const OpenMode = enum(usize) {
    OREAD = 0, //* open for read
    OWRITE = 1, //* write
    ORDWR = 2, //* read and write
    OEXEC = 3, //* execute, == read but check execute permission
    OTRUNC = 16, //* or'ed in (except for exec), truncate file first
    OCEXEC = 32, //* or'ed in (per file descriptor), close on exec
    ORCLOSE = 64, //* or'ed in, remove on close
    OEXCL = 0x1000, //* or'ed in, exclusive create
};
