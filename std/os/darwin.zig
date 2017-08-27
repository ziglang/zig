const c = @import("../c/index.zig");
const assert = @import("../debug.zig").assert;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const PROT_NONE   = 0x00; /// [MC2] no permissions
pub const PROT_READ   = 0x01; /// [MC2] pages can be read
pub const PROT_WRITE  = 0x02; /// [MC2] pages can be written
pub const PROT_EXEC   = 0x04; /// [MC2] pages can be executed

pub const MAP_ANONYMOUS = 0x1000; /// allocated from memory, swap space
pub const MAP_FILE = 0x0000; /// map from file (default)
pub const MAP_FIXED = 0x0010; /// interpret addr exactly
pub const MAP_HASSEMAPHORE = 0x0200; /// region may contain semaphores
pub const MAP_PRIVATE = 0x0002; /// changes are private
pub const MAP_SHARED = 0x0001; /// share changes
pub const MAP_NOCACHE = 0x0400; /// don't cache pages for this mapping
pub const MAP_NORESERVE = 0x0040; /// don't reserve needed swap area
pub const MAP_FAILED = @maxValue(usize);

pub const O_LARGEFILE = 0x0000;

pub const O_RDONLY   = 0x0000; /// open for reading only
pub const O_WRONLY   = 0x0001; /// open for writing only
pub const O_RDWR     = 0x0002; /// open for reading and writing
pub const O_NONBLOCK = 0x0004; /// do not block on open or for data to become available
pub const O_APPEND   = 0x0008; /// append on each write
pub const O_CREAT    = 0x0200; /// create file if it does not exist
pub const O_TRUNC    = 0x0400; /// truncate size to 0
pub const O_EXCL     = 0x0800; /// error if O_CREAT and the file exists
pub const O_SHLOCK   = 0x0010; /// atomically obtain a shared lock
pub const O_EXLOCK   = 0x0020; /// atomically obtain an exclusive lock
pub const O_NOFOLLOW = 0x0100; /// do not follow symlinks
pub const O_SYMLINK  = 0x200000; /// allow open of symlinks
pub const O_EVTONLY  = 0x8000; /// descriptor requested for event notifications only
pub const O_CLOEXEC  = 0x1000000; /// mark as close-on-exec

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

fn wstatus(x: i32) -> i32 { x & 0o177 }
const wstopped = 0o177;
pub fn WEXITSTATUS(x: i32) -> i32 { x >> 8 }
pub fn WTERMSIG(x: i32) -> i32 { wstatus(x) }
pub fn WSTOPSIG(x: i32) -> i32 { x >> 8 }
pub fn WIFEXITED(x: i32) -> bool { wstatus(x) == 0 }
pub fn WIFSTOPPED(x: i32) -> bool { wstatus(x) == wstopped and WSTOPSIG(x) != 0x13 }
pub fn WIFSIGNALED(x: i32) -> bool { wstatus(x) != wstopped and wstatus(x) != 0 }

/// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: usize) -> usize {
    const signed_r = @bitCast(isize, r);
    if (signed_r > -4096 and signed_r < 0) usize(-signed_r) else 0
}

pub fn close(fd: i32) -> usize {
    errnoWrap(c.close(fd))
}

pub fn abort() -> noreturn {
    c.abort()
}

pub fn exit(code: i32) -> noreturn {
    c.exit(code)
}

pub fn isatty(fd: i32) -> bool {
    c.isatty(fd) == 0
}

pub fn fstat(fd: i32, buf: &c.stat) -> usize {
    errnoWrap(c.fstat(fd, buf))
}

pub fn lseek(fd: i32, offset: isize, whence: c_int) -> usize {
    errnoWrap(c.lseek(fd, buf, whence))
}

pub fn open(path: &const u8, flags: u32, mode: usize) -> usize {
    errnoWrap(c.open(path, @bitCast(c_int, flags), mode))
}

pub fn raise(sig: i32) -> usize {
    errnoWrap(c.raise(sig))
}

pub fn read(fd: i32, buf: &u8, nbyte: usize) -> usize {
    errnoWrap(c.read(fd, @ptrCast(&c_void, buf), nbyte))
}

pub fn stat(noalias path: &const u8, noalias buf: &stat) -> usize {
    errnoWrap(c.stat(path, buf))
}

pub fn write(fd: i32, buf: &const u8, nbyte: usize) -> usize {
    errnoWrap(c.write(fd, @ptrCast(&const c_void, buf), nbyte))
}

pub fn mmap(address: ?&u8, length: usize, prot: usize, flags: usize, fd: i32,
    offset: isize) -> usize
{
    const ptr_result = c.mmap(@ptrCast(&c_void, address), length,
        @bitCast(c_int, c_uint(prot)), @bitCast(c_int, c_uint(flags)), fd, offset);
    const isize_result = @bitCast(isize, @ptrToInt(ptr_result));
    return errnoWrap(isize_result);
}

pub fn munmap(address: &u8, length: usize) -> usize {
    errnoWrap(c.munmap(@ptrCast(&c_void, address), length))
}

pub fn unlink(path: &const u8) -> usize {
    errnoWrap(c.unlink(path))
}

pub fn getcwd(buf: &u8, size: usize) -> usize {
    if (c.getcwd(buf, size) == null) @bitCast(usize, -isize(*c._errno())) else 0
}

pub fn waitpid(pid: i32, status: &i32, options: u32) -> usize {
    comptime assert(i32.bit_count == c_int.bit_count);
    errnoWrap(c.waitpid(pid, @ptrCast(&c_int, status), @bitCast(c_int, options)))
}

pub fn fork() -> usize {
    errnoWrap(c.fork())
}

pub fn pipe(fds: &[2]i32) -> usize {
    comptime assert(i32.bit_count == c_int.bit_count);
    errnoWrap(c.pipe(@ptrCast(&c_int, &(*fds)[0])))
}

pub fn mkdir(path: &const u8, mode: u32) -> usize {
    errnoWrap(c.mkdir(path, mode))
}

pub fn symlink(existing: &const u8, new: &const u8) -> usize {
    errnoWrap(c.symlink(existing, new))
}

pub fn rename(old: &const u8, new: &const u8) -> usize {
    errnoWrap(c.rename(old, new))
}

pub fn chdir(path: &const u8) -> usize {
    errnoWrap(c.chdir(path))
}

pub fn execve(path: &const u8, argv: &const ?&const u8, envp: &const ?&const u8)
    -> usize
{
    errnoWrap(c.execve(path, argv, envp))
}

pub fn dup2(old: i32, new: i32) -> usize {
    errnoWrap(c.dup2(old, new))
}

/// Takes the return value from a syscall and formats it back in the way
/// that the kernel represents it to libc. Errno was a mistake, let's make
/// it go away forever.
fn errnoWrap(value: isize) -> usize {
    @bitCast(usize, if (value == -1) {
        -isize(*c._errno())
    } else {
        value
    })
}
