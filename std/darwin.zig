
const arch = switch (@compileVar("arch")) {
    Arch.x86_64 => @import("darwin_x86_64.zig"),
    else => @compileError("unsupported arch"),
};

const errno = @import("errno.zig");

pub const O_LARGEFILE = 0x0000;
pub const O_RDONLY = 0x0000;

pub const SEEK_SET = 0x0;
pub const SEEK_CUR = 0x1;
pub const SEEK_END = 0x2;

pub const SIGHUP    = 1;
pub const SIGINT    = 2;
pub const SIGQUIT   = 3;
pub const SIGILL    = 4;
pub const SIGTRAP   = 5;
pub const SIGABRT   = 6;
pub const SIGIOT    = SIGABRT;
pub const SIGBUS    = 7;
pub const SIGFPE    = 8;
pub const SIGKILL   = 9;
pub const SIGUSR1   = 10;
pub const SIGSEGV   = 11;
pub const SIGUSR2   = 12;
pub const SIGPIPE   = 13;
pub const SIGALRM   = 14;
pub const SIGTERM   = 15;
pub const SIGSTKFLT = 16;
pub const SIGCHLD   = 17;
pub const SIGCONT   = 18;
pub const SIGSTOP   = 19;
pub const SIGTSTP   = 20;
pub const SIGTTIN   = 21;
pub const SIGTTOU   = 22;
pub const SIGURG    = 23;
pub const SIGXCPU   = 24;
pub const SIGXFSZ   = 25;
pub const SIGVTALRM = 26;
pub const SIGPROF   = 27;
pub const SIGWINCH  = 28;
pub const SIGIO     = 29;
pub const SIGPOLL   = 29;
pub const SIGPWR    = 30;
pub const SIGSYS    = 31;
pub const SIGUNUSED = SIGSYS;

pub fn exit(status: usize) -> noreturn {
    _ = arch.syscall1(arch.SYS_exit, status);
    unreachable
}

/// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: usize) -> usize {
    const signed_r = *(&isize)(&r);
    if (signed_r > -4096 && signed_r < 0) usize(-signed_r) else 0
}

pub fn write(fd: i32, buf: &const u8, count: usize) -> usize {
    arch.syscall3(arch.SYS_write, usize(fd), usize(buf), count)
}

pub fn close(fd: i32) -> usize {
    arch.syscall1(arch.SYS_close, usize(fd))
}

pub fn open_c(path: &const u8, flags: usize, perm: usize) -> usize {
    arch.syscall3(arch.SYS_open, usize(path), flags, perm)
}

pub fn open(path: []const u8, flags: usize, perm: usize) -> usize {
    const buf = @alloca(u8, path.len + 1);
    @memcpy(&buf[0], &path[0], path.len);
    buf[path.len] = 0;
    return open_c(buf.ptr, flags, perm);
}

pub fn read(fd: i32, buf: &u8, count: usize) -> usize {
    arch.syscall3(arch.SYS_read, usize(fd), usize(buf), count)
}

pub fn lseek(fd: i32, offset: usize, ref_pos: usize) -> usize {
    arch.syscall3(arch.SYS_lseek, usize(fd), offset, ref_pos)
}

pub const stat = arch.stat;
pub const timespec = arch.timespec;

pub fn fstat(fd: i32, stat_buf: &stat) -> usize {
    arch.syscall2(arch.SYS_fstat, usize(fd), usize(stat_buf))
}

error Unexpected;

pub fn getrandom(buf: &u8, count: usize) -> usize {
    const rr = open_c(c"/dev/urandom", O_LARGEFILE | O_RDONLY, 0);

    if(getErrno(rr) > 0) return rr;

    var fd: i32 = i32(rr);
    const readRes = read(fd, buf, count);
    readRes
}

pub fn raise(sig: i32) -> i32 {
    // TODO investigate whether we need to block signals before calling kill
    // like we do in the linux version of raise

    //var set: sigset_t = undefined;
    //blockAppSignals(&set);
    const pid = i32(arch.syscall0(arch.SYS_getpid));
    const ret = i32(arch.syscall2(arch.SYS_kill, usize(pid), usize(sig)));
    //restoreSignals(&set);
    return ret;
}
