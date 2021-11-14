const std = @import("../std.zig");
const builtin = @import("builtin");

pub const syscall_bits = switch (builtin.stage2_arch) {
    .x86_64 => @import("plan9/x86_64.zig"),
    else => @compileError("more plan9 syscall implementations (needs more inline asm in stage2"),
};
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
    return syscall_bits.syscall4(.PWRITE, fd, @ptrToInt(buf), count, offset);
}

pub fn open(path: [*:0]const u8, omode: OpenMode) usize {
    return syscall_bits.syscall2(.OPEN, @ptrToInt(path), @enumToInt(omode));
}

pub fn create(path: [*:0]const u8, omode: OpenMode, perms: usize) usize {
    return syscall_bits.syscall3(.CREATE, @ptrToInt(path), @enumToInt(omode), perms);
}

pub fn exits(status: ?[*:0]const u8) void {
    _ = syscall_bits.syscall1(.EXITS, if (status) |s| @ptrToInt(s) else 0);
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
