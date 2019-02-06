const builtin = @import("builtin");

pub use @import("errno.zig");
pub use @import("signal.zig");

const std = @import("../../index.zig");
const c = std.c;

const assert = std.debug.assert;
const maxInt = std.math.maxInt;

pub const PATH_MAX = 1024;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const PROT_READ = 1;
pub const PROT_WRITE = 2;

pub const MAP_FAILED = maxInt(usize);
pub const MAP_PRIVATE = 0x0002;
pub const MAP_ANON = 0x1000;
pub const MAP_ANONYMOUS = MAP_ANON;

pub const F_OK = 0;
pub const X_OK = 1;
pub const W_OK = 2;
pub const R_OK = 4;

pub const O_RDONLY = 0x0000;
pub const O_WRONLY = 0x0001;
pub const O_RDWR = 0x0002;

pub const O_CREAT = 0x0200;
pub const O_TRUNC = 0x0400;
pub const O_CLOEXEC = 0x00100000;

pub const SEEK_SET = 0;
pub const SEEK_CUR = 1;
pub const SEEK_END = 2;

fn unsigned(s: i32) u32 {
    return @bitCast(u32, s);
}
fn signed(s: u32) i32 {
    return @bitCast(i32, s);
}
pub fn WEXITSTATUS(s: i32) i32 {
    return signed((unsigned(s) & 0xff00) >> 8);
}
pub fn WTERMSIG(s: i32) i32 {
    return signed(unsigned(s) & 0177);
}
pub fn WSTOPSIG(s: i32) i32 {
    return WEXITSTATUS(s);
}
pub fn WIFEXITED(s: i32) bool {
    return WTERMSIG(s) == 0;
}
pub fn WIFSTOPPED(s: i32) bool {
    return @intCast(u16, (unsigned(s) & 0xff00)) == 0177;
}
pub fn WIFSIGNALED(s: i32) bool {
    return (@intCast(u16, WTERMSIG(s)) != 0177) and (@intCast(u16, WTERMSIG(s)) != 0);
}

pub fn pipe(fd: *[2]i32) usize {
    return errnoWrap(c.pipe(@ptrCast(*[2]c_int, fd)));
}

pub fn mkdir(path: [*]const u8, mode: u32) usize {
    return errnoWrap(c.mkdir(path, mode));
}

pub fn mmap(address: ?[*]u8, length: usize, prot: usize, flags: u32, fd: i32, offset: isize) usize {
    const ptr_result = c.mmap(
        @ptrCast(?*c_void, address),
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

pub fn isatty(fd: i32) bool {
    return c.isatty(fd) != 0;
}

pub fn lseek(fd: i32, offset: isize, whence: c_int) usize {
    return errnoWrap(c.lseek(fd, offset, whence));
}

pub fn read(fd: i32, buf: [*]u8, nbyte: usize) usize {
    return errnoWrap(c.read(fd, @ptrCast(*c_void, buf), nbyte));
}

pub fn symlink(existing: [*]const u8, new: [*]const u8) usize {
    return errnoWrap(c.symlink(existing, new));
}

pub fn write(fd: i32, buf: [*]const u8, nbyte: usize) usize {
    return errnoWrap(c.write(fd, @ptrCast(*const c_void, buf), nbyte));
}

pub fn raise(sig: i32) usize {
    return errnoWrap(c.raise(sig));
}

pub fn exit(code: i32) noreturn {
    c.exit(code);
}

pub fn unlink(path: [*]const u8) usize {
    return errnoWrap(c.unlink(path));
}

pub fn rename(old: [*]const u8, new: [*]const u8) usize {
    return errnoWrap(c.rename(old, new));
}

pub fn open(path: [*]const u8, flags: u32, mode: usize) usize {
    return errnoWrap(c.open(path, @bitCast(c_int, flags), mode));
}

pub fn close(fd: i32) usize {
    return errnoWrap(c.close(fd));
}

pub fn dup2(old: i32, new: i32) usize {
    return errnoWrap(c.dup2(old, new));
}

pub fn chdir(path: [*]const u8) usize {
    return errnoWrap(c.chdir(path));
}

pub fn waitpid(pid: i32, status: *i32, options: u32) usize {
    comptime assert(i32.bit_count == c_int.bit_count);
    return errnoWrap(c.waitpid(pid, @ptrCast(*c_int, status), @bitCast(c_int, options)));
}

pub fn setreuid(ruid: u32, euid: u32) usize {
    return errnoWrap(c.setreuid(ruid, euid));
}

pub fn setregid(rgid: u32, egid: u32) usize {
    return errnoWrap(c.setregid(rgid, egid));
}

pub fn execve(path: [*]const u8, argv: [*]const ?[*]const u8, envp: [*]const ?[*]const u8) usize {
    return errnoWrap(c.execve(path, argv, envp));
}

pub fn fork() usize {
    return errnoWrap(c.fork());
}

pub fn access(path: [*]const u8, mode: u32) usize {
    return errnoWrap(c.access(path, mode));
}

pub fn getcwd(buf: [*]u8, size: usize) usize {
    return @bitCast(usize, if (c.getcwd(buf, size) == null) isize(c._errno().*) else 0);
}

pub fn realpath(noalias filename: [*]const u8, noalias resolved_name: [*]u8) usize {
    return @bitCast(usize, if (c.realpath(filename, resolved_name) == null) isize(c._errno().*) else 0);
}

pub fn arc4random_buf(buf: [*]u8, nbytes: usize) void {
    c.arc4random_buf(buf, nbytes);
}

pub fn getErrno(r: usize) usize {
    return r;
}

fn errnoWrap(value: isize) usize {
    return @bitCast(usize, if (value == -1) c._errno().* else value);
}
