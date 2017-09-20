const builtin = @import("builtin");
const Os = builtin.Os;

pub use switch(builtin.os) {
    Os.linux => @import("linux.zig"),
    Os.windows => @import("windows.zig"),
    Os.darwin, Os.macosx, Os.ios => @import("darwin.zig"),
    else => empty_import,
};
const empty_import = @import("../empty.zig");

pub extern "c" fn abort() -> noreturn;
pub extern "c" fn exit(code: c_int) -> noreturn;
pub extern "c" fn isatty(fd: c_int) -> c_int;
pub extern "c" fn close(fd: c_int) -> c_int;
pub extern "c" fn fstat(fd: c_int, buf: &stat) -> c_int;
pub extern "c" fn lseek(fd: c_int, offset: isize, whence: c_int) -> isize;
pub extern "c" fn open(path: &const u8, oflag: c_int, ...) -> c_int;
pub extern "c" fn raise(sig: c_int) -> c_int;
pub extern "c" fn read(fd: c_int, buf: &c_void, nbyte: usize) -> isize;
pub extern "c" fn stat(noalias path: &const u8, noalias buf: &Stat) -> c_int;
pub extern "c" fn write(fd: c_int, buf: &const c_void, nbyte: usize) -> c_int;
pub extern "c" fn mmap(addr: ?&c_void, len: usize, prot: c_int, flags: c_int,
    fd: c_int, offset: isize) -> ?&c_void;
pub extern "c" fn munmap(addr: &c_void, len: usize) -> c_int;
pub extern "c" fn unlink(path: &const u8) -> c_int;
pub extern "c" fn getcwd(buf: &u8, size: usize) -> ?&u8;
pub extern "c" fn waitpid(pid: c_int, stat_loc: &c_int, options: c_int) -> c_int;
pub extern "c" fn fork() -> c_int;
pub extern "c" fn pipe(fds: &c_int) -> c_int;
pub extern "c" fn mkdir(path: &const u8, mode: c_uint) -> c_int;
pub extern "c" fn symlink(existing: &const u8, new: &const u8) -> c_int;
pub extern "c" fn rename(old: &const u8, new: &const u8) -> c_int;
pub extern "c" fn chdir(path: &const u8) -> c_int;
pub extern "c" fn execve(path: &const u8, argv: &const ?&const u8,
    envp: &const ?&const u8) -> c_int;
pub extern "c" fn dup(fd: c_int) -> c_int;
pub extern "c" fn dup2(old_fd: c_int, new_fd: c_int) -> c_int;
pub extern "c" fn readlink(noalias path: &const u8, noalias buf: &u8, bufsize: usize) -> isize;
pub extern "c" fn realpath(noalias file_name: &const u8, noalias resolved_name: &u8) -> ?&u8;
pub extern "c" fn sigprocmask(how: c_int, noalias set: &const sigset_t, noalias oset: ?&sigset_t) -> c_int;
pub extern "c" fn sigaction(sig: c_int, noalias act: &const Sigaction, noalias oact: ?&Sigaction) -> c_int;
pub extern "c" fn nanosleep(rqtp: &const timespec, rmtp: ?&timespec) -> c_int;
