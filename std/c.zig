const builtin = @import("builtin");
const Os = builtin.Os;

pub use switch (builtin.os) {
    Os.linux => @import("c/linux.zig"),
    Os.windows => @import("c/windows.zig"),
    Os.macosx, Os.ios => @import("c/darwin.zig"),
    Os.freebsd => @import("c/freebsd.zig"),
    Os.netbsd => @import("c/netbsd.zig"),
    else => struct {},
};

// TODO https://github.com/ziglang/zig/issues/265 on this whole file

pub const FILE = @OpaqueType();
pub extern "c" fn fwrite(ptr: [*]const u8, size_of_type: usize, item_count: usize, stream: *FILE) usize;
pub extern "c" fn fread(ptr: [*]u8, size_of_type: usize, item_count: usize, stream: *FILE) usize;

pub extern "c" fn abort() noreturn;
pub extern "c" fn exit(code: c_int) noreturn;
pub extern "c" fn isatty(fd: c_int) c_int;
pub extern "c" fn close(fd: c_int) c_int;
pub extern "c" fn fstat(fd: c_int, buf: *Stat) c_int;
pub extern "c" fn @"fstat$INODE64"(fd: c_int, buf: *Stat) c_int;
pub extern "c" fn lseek(fd: c_int, offset: isize, whence: c_int) isize;
pub extern "c" fn open(path: [*]const u8, oflag: c_int, ...) c_int;
pub extern "c" fn raise(sig: c_int) c_int;
pub extern "c" fn read(fd: c_int, buf: *c_void, nbyte: usize) isize;
pub extern "c" fn pread(fd: c_int, buf: *c_void, nbyte: usize, offset: u64) isize;
pub extern "c" fn stat(noalias path: [*]const u8, noalias buf: *Stat) c_int;
pub extern "c" fn write(fd: c_int, buf: *const c_void, nbyte: usize) isize;
pub extern "c" fn pwrite(fd: c_int, buf: *const c_void, nbyte: usize, offset: u64) isize;
pub extern "c" fn mmap(addr: ?*c_void, len: usize, prot: c_int, flags: c_int, fd: c_int, offset: isize) ?*c_void;
pub extern "c" fn munmap(addr: ?*c_void, len: usize) c_int;
pub extern "c" fn unlink(path: [*]const u8) c_int;
pub extern "c" fn getcwd(buf: [*]u8, size: usize) ?[*]u8;
pub extern "c" fn waitpid(pid: c_int, stat_loc: *c_int, options: c_int) c_int;
pub extern "c" fn fork() c_int;
pub extern "c" fn access(path: [*]const u8, mode: c_uint) c_int;
pub extern "c" fn pipe(fds: *[2]c_int) c_int;
pub extern "c" fn mkdir(path: [*]const u8, mode: c_uint) c_int;
pub extern "c" fn symlink(existing: [*]const u8, new: [*]const u8) c_int;
pub extern "c" fn rename(old: [*]const u8, new: [*]const u8) c_int;
pub extern "c" fn chdir(path: [*]const u8) c_int;
pub extern "c" fn execve(path: [*]const u8, argv: [*]const ?[*]const u8, envp: [*]const ?[*]const u8) c_int;
pub extern "c" fn dup(fd: c_int) c_int;
pub extern "c" fn dup2(old_fd: c_int, new_fd: c_int) c_int;
pub extern "c" fn readlink(noalias path: [*]const u8, noalias buf: [*]u8, bufsize: usize) isize;
pub extern "c" fn realpath(noalias file_name: [*]const u8, noalias resolved_name: [*]u8) ?[*]u8;
pub extern "c" fn sigprocmask(how: c_int, noalias set: *const sigset_t, noalias oset: ?*sigset_t) c_int;
pub extern "c" fn gettimeofday(noalias tv: ?*timeval, noalias tz: ?*timezone) c_int;
pub extern "c" fn sigaction(sig: c_int, noalias act: *const Sigaction, noalias oact: ?*Sigaction) c_int;
pub extern "c" fn nanosleep(rqtp: *const timespec, rmtp: ?*timespec) c_int;
pub extern "c" fn setreuid(ruid: c_uint, euid: c_uint) c_int;
pub extern "c" fn setregid(rgid: c_uint, egid: c_uint) c_int;
pub extern "c" fn rmdir(path: [*]const u8) c_int;

pub extern "c" fn aligned_alloc(alignment: usize, size: usize) ?*c_void;
pub extern "c" fn malloc(usize) ?*c_void;
pub extern "c" fn realloc(?*c_void, usize) ?*c_void;
pub extern "c" fn free(*c_void) void;
pub extern "c" fn posix_memalign(memptr: **c_void, alignment: usize, size: usize) c_int;

pub extern "pthread" fn pthread_create(noalias newthread: *pthread_t, noalias attr: ?*const pthread_attr_t, start_routine: extern fn (?*c_void) ?*c_void, noalias arg: ?*c_void) c_int;
pub extern "pthread" fn pthread_attr_init(attr: *pthread_attr_t) c_int;
pub extern "pthread" fn pthread_attr_setstack(attr: *pthread_attr_t, stackaddr: *c_void, stacksize: usize) c_int;
pub extern "pthread" fn pthread_attr_destroy(attr: *pthread_attr_t) c_int;
pub extern "pthread" fn pthread_self() pthread_t;
pub extern "pthread" fn pthread_join(thread: pthread_t, arg_return: ?*?*c_void) c_int;

pub const pthread_t = *@OpaqueType();
