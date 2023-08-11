const std = @import("std");
const builtin = @import("builtin");
const c = @This();
const page_size = std.mem.page_size;
const iovec = std.os.iovec;
const iovec_const = std.os.iovec_const;

test {
    _ = tokenizer;
}

pub const tokenizer = @import("c/tokenizer.zig");
pub const Token = tokenizer.Token;
pub const Tokenizer = tokenizer.Tokenizer;

/// The return type is `type` to force comptime function call execution.
/// TODO: https://github.com/ziglang/zig/issues/425
/// If not linking libc, returns struct{pub const ok = false;}
/// If linking musl libc, returns struct{pub const ok = true;}
/// If linking gnu libc (glibc), the `ok` value will be true if the target
/// version is greater than or equal to `glibc_version`.
/// If linking a libc other than these, returns `false`.
pub fn versionCheck(comptime glibc_version: std.SemanticVersion) type {
    return struct {
        pub const ok = blk: {
            if (!builtin.link_libc) break :blk false;
            if (builtin.abi.isMusl()) break :blk true;
            if (builtin.target.isGnuLibC()) {
                const ver = builtin.os.version_range.linux.glibc;
                const order = ver.order(glibc_version);
                break :blk switch (order) {
                    .gt, .eq => true,
                    .lt => false,
                };
            } else {
                break :blk false;
            }
        };
    };
}

pub usingnamespace switch (builtin.os.tag) {
    .linux => @import("c/linux.zig"),
    .windows => @import("c/windows.zig"),
    .macos, .ios, .tvos, .watchos => @import("c/darwin.zig"),
    .freebsd, .kfreebsd => @import("c/freebsd.zig"),
    .netbsd => @import("c/netbsd.zig"),
    .dragonfly => @import("c/dragonfly.zig"),
    .openbsd => @import("c/openbsd.zig"),
    .haiku => @import("c/haiku.zig"),
    .hermit => @import("c/hermit.zig"),
    .solaris => @import("c/solaris.zig"),
    .fuchsia => @import("c/fuchsia.zig"),
    .minix => @import("c/minix.zig"),
    .emscripten => @import("c/emscripten.zig"),
    .wasi => @import("c/wasi.zig"),
    else => struct {},
};

pub const whence_t = if (builtin.os.tag == .wasi) std.os.wasi.whence_t else c_int;

// Unix-like systems
pub usingnamespace switch (builtin.os.tag) {
    .netbsd, .windows => struct {},
    else => struct {
        pub const DIR = opaque {};
        pub extern "c" fn opendir(pathname: [*:0]const u8) ?*DIR;
        pub extern "c" fn fdopendir(fd: c_int) ?*DIR;
        pub extern "c" fn rewinddir(dp: *DIR) void;
        pub extern "c" fn closedir(dp: *DIR) c_int;
        pub extern "c" fn telldir(dp: *DIR) c_long;
        pub extern "c" fn seekdir(dp: *DIR, loc: c_long) void;

        pub extern "c" fn clock_gettime(clk_id: c_int, tp: *c.timespec) c_int;
        pub extern "c" fn clock_getres(clk_id: c_int, tp: *c.timespec) c_int;
        pub extern "c" fn gettimeofday(noalias tv: ?*c.timeval, noalias tz: ?*c.timezone) c_int;
        pub extern "c" fn nanosleep(rqtp: *const c.timespec, rmtp: ?*c.timespec) c_int;

        pub extern "c" fn getrusage(who: c_int, usage: *c.rusage) c_int;

        pub extern "c" fn sched_yield() c_int;

        pub extern "c" fn sigaction(sig: c_int, noalias act: ?*const c.Sigaction, noalias oact: ?*c.Sigaction) c_int;
        pub extern "c" fn sigprocmask(how: c_int, noalias set: ?*const c.sigset_t, noalias oset: ?*c.sigset_t) c_int;
        pub extern "c" fn sigfillset(set: ?*c.sigset_t) void;
        pub extern "c" fn sigwait(set: ?*c.sigset_t, sig: ?*c_int) c_int;

        pub extern "c" fn socket(domain: c_uint, sock_type: c_uint, protocol: c_uint) c_int;

        pub extern "c" fn stat(noalias path: [*:0]const u8, noalias buf: *c.Stat) c_int;

        pub extern "c" fn alarm(seconds: c_uint) c_uint;

        pub extern "c" fn msync(addr: *align(page_size) const anyopaque, len: usize, flags: c_int) c_int;
    },
};

pub usingnamespace switch (builtin.os.tag) {
    .netbsd, .macos, .ios, .watchos, .tvos, .windows => struct {},
    else => struct {
        pub extern "c" fn fstat(fd: c.fd_t, buf: *c.Stat) c_int;
        pub extern "c" fn readdir(dp: *c.DIR) ?*c.dirent;
    },
};

pub usingnamespace switch (builtin.os.tag) {
    .macos, .ios, .watchos, .tvos => struct {},
    else => struct {
        pub extern "c" fn realpath(noalias file_name: [*:0]const u8, noalias resolved_name: [*]u8) ?[*:0]u8;
        pub extern "c" fn fstatat(dirfd: c.fd_t, path: [*:0]const u8, stat_buf: *c.Stat, flags: u32) c_int;
    },
};

pub fn getErrno(rc: anytype) c.E {
    if (rc == -1) {
        return @as(c.E, @enumFromInt(c._errno().*));
    } else {
        return .SUCCESS;
    }
}

pub extern "c" var environ: [*:null]?[*:0]u8;

pub extern "c" fn fopen(noalias filename: [*:0]const u8, noalias modes: [*:0]const u8) ?*FILE;
pub extern "c" fn fclose(stream: *FILE) c_int;
pub extern "c" fn fwrite(noalias ptr: [*]const u8, size_of_type: usize, item_count: usize, noalias stream: *FILE) usize;
pub extern "c" fn fread(noalias ptr: [*]u8, size_of_type: usize, item_count: usize, noalias stream: *FILE) usize;

pub extern "c" fn printf(format: [*:0]const u8, ...) c_int;
pub extern "c" fn abort() noreturn;
pub extern "c" fn exit(code: c_int) noreturn;
pub extern "c" fn _exit(code: c_int) noreturn;
pub extern "c" fn isatty(fd: c.fd_t) c_int;
pub extern "c" fn close(fd: c.fd_t) c_int;
pub extern "c" fn lseek(fd: c.fd_t, offset: c.off_t, whence: whence_t) c.off_t;
pub extern "c" fn open(path: [*:0]const u8, oflag: c_uint, ...) c_int;
pub extern "c" fn openat(fd: c_int, path: [*:0]const u8, oflag: c_uint, ...) c_int;
pub extern "c" fn ftruncate(fd: c_int, length: c.off_t) c_int;
pub extern "c" fn raise(sig: c_int) c_int;
pub extern "c" fn read(fd: c.fd_t, buf: [*]u8, nbyte: usize) isize;
pub extern "c" fn readv(fd: c_int, iov: [*]const iovec, iovcnt: c_uint) isize;
pub extern "c" fn pread(fd: c.fd_t, buf: [*]u8, nbyte: usize, offset: c.off_t) isize;
pub extern "c" fn preadv(fd: c_int, iov: [*]const iovec, iovcnt: c_uint, offset: c.off_t) isize;
pub extern "c" fn writev(fd: c_int, iov: [*]const iovec_const, iovcnt: c_uint) isize;
pub extern "c" fn pwritev(fd: c_int, iov: [*]const iovec_const, iovcnt: c_uint, offset: c.off_t) isize;
pub extern "c" fn write(fd: c.fd_t, buf: [*]const u8, nbyte: usize) isize;
pub extern "c" fn pwrite(fd: c.fd_t, buf: [*]const u8, nbyte: usize, offset: c.off_t) isize;
pub extern "c" fn mmap(addr: ?*align(page_size) anyopaque, len: usize, prot: c_uint, flags: c_uint, fd: c.fd_t, offset: c.off_t) *anyopaque;
pub extern "c" fn munmap(addr: *align(page_size) const anyopaque, len: usize) c_int;
pub extern "c" fn mprotect(addr: *align(page_size) anyopaque, len: usize, prot: c_uint) c_int;
pub extern "c" fn link(oldpath: [*:0]const u8, newpath: [*:0]const u8, flags: c_int) c_int;
pub extern "c" fn linkat(oldfd: c.fd_t, oldpath: [*:0]const u8, newfd: c.fd_t, newpath: [*:0]const u8, flags: c_int) c_int;
pub extern "c" fn unlink(path: [*:0]const u8) c_int;
pub extern "c" fn unlinkat(dirfd: c.fd_t, path: [*:0]const u8, flags: c_uint) c_int;
pub extern "c" fn getcwd(buf: [*]u8, size: usize) ?[*]u8;
pub extern "c" fn waitpid(pid: c.pid_t, status: ?*c_int, options: c_int) c.pid_t;
pub extern "c" fn wait4(pid: c.pid_t, status: ?*c_int, options: c_int, ru: ?*c.rusage) c.pid_t;
pub extern "c" fn fork() c_int;
pub extern "c" fn access(path: [*:0]const u8, mode: c_uint) c_int;
pub extern "c" fn faccessat(dirfd: c.fd_t, path: [*:0]const u8, mode: c_uint, flags: c_uint) c_int;
pub extern "c" fn pipe(fds: *[2]c.fd_t) c_int;
pub extern "c" fn mkdir(path: [*:0]const u8, mode: c_uint) c_int;
pub extern "c" fn mkdirat(dirfd: c.fd_t, path: [*:0]const u8, mode: u32) c_int;
pub extern "c" fn symlink(existing: [*:0]const u8, new: [*:0]const u8) c_int;
pub extern "c" fn symlinkat(oldpath: [*:0]const u8, newdirfd: c.fd_t, newpath: [*:0]const u8) c_int;
pub extern "c" fn rename(old: [*:0]const u8, new: [*:0]const u8) c_int;
pub extern "c" fn renameat(olddirfd: c.fd_t, old: [*:0]const u8, newdirfd: c.fd_t, new: [*:0]const u8) c_int;
pub extern "c" fn chdir(path: [*:0]const u8) c_int;
pub extern "c" fn fchdir(fd: c.fd_t) c_int;
pub extern "c" fn execve(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) c_int;
pub extern "c" fn dup(fd: c.fd_t) c_int;
pub extern "c" fn dup2(old_fd: c.fd_t, new_fd: c.fd_t) c_int;
pub extern "c" fn readlink(noalias path: [*:0]const u8, noalias buf: [*]u8, bufsize: usize) isize;
pub extern "c" fn readlinkat(dirfd: c.fd_t, noalias path: [*:0]const u8, noalias buf: [*]u8, bufsize: usize) isize;
pub extern "c" fn chmod(path: [*:0]const u8, mode: c.mode_t) c_int;
pub extern "c" fn fchmod(fd: c.fd_t, mode: c.mode_t) c_int;
pub extern "c" fn fchmodat(fd: c.fd_t, path: [*:0]const u8, mode: c.mode_t, flags: c_uint) c_int;
pub extern "c" fn fchown(fd: c.fd_t, owner: c.uid_t, group: c.gid_t) c_int;
pub extern "c" fn umask(mode: c.mode_t) c.mode_t;

pub extern "c" fn rmdir(path: [*:0]const u8) c_int;
pub extern "c" fn getenv(name: [*:0]const u8) ?[*:0]u8;
pub extern "c" fn sysctl(name: [*]const c_int, namelen: c_uint, oldp: ?*anyopaque, oldlenp: ?*usize, newp: ?*anyopaque, newlen: usize) c_int;
pub extern "c" fn sysctlbyname(name: [*:0]const u8, oldp: ?*anyopaque, oldlenp: ?*usize, newp: ?*anyopaque, newlen: usize) c_int;
pub extern "c" fn sysctlnametomib(name: [*:0]const u8, mibp: ?*c_int, sizep: ?*usize) c_int;
pub extern "c" fn tcgetattr(fd: c.fd_t, termios_p: *c.termios) c_int;
pub extern "c" fn tcsetattr(fd: c.fd_t, optional_action: c.TCSA, termios_p: *const c.termios) c_int;
pub extern "c" fn fcntl(fd: c.fd_t, cmd: c_int, ...) c_int;
pub extern "c" fn flock(fd: c.fd_t, operation: c_int) c_int;
pub extern "c" fn ioctl(fd: c.fd_t, request: c_int, ...) c_int;
pub extern "c" fn uname(buf: *c.utsname) c_int;

pub extern "c" fn gethostname(name: [*]u8, len: usize) c_int;
pub extern "c" fn shutdown(socket: c.fd_t, how: c_int) c_int;
pub extern "c" fn bind(socket: c.fd_t, address: ?*const c.sockaddr, address_len: c.socklen_t) c_int;
pub extern "c" fn socketpair(domain: c_uint, sock_type: c_uint, protocol: c_uint, sv: *[2]c.fd_t) c_int;
pub extern "c" fn listen(sockfd: c.fd_t, backlog: c_uint) c_int;
pub extern "c" fn getsockname(sockfd: c.fd_t, noalias addr: *c.sockaddr, noalias addrlen: *c.socklen_t) c_int;
pub extern "c" fn getpeername(sockfd: c.fd_t, noalias addr: *c.sockaddr, noalias addrlen: *c.socklen_t) c_int;
pub extern "c" fn connect(sockfd: c.fd_t, sock_addr: *const c.sockaddr, addrlen: c.socklen_t) c_int;
pub extern "c" fn accept(sockfd: c.fd_t, noalias addr: ?*c.sockaddr, noalias addrlen: ?*c.socklen_t) c_int;
pub extern "c" fn accept4(sockfd: c.fd_t, noalias addr: ?*c.sockaddr, noalias addrlen: ?*c.socklen_t, flags: c_uint) c_int;
pub extern "c" fn getsockopt(sockfd: c.fd_t, level: u32, optname: u32, noalias optval: ?*anyopaque, noalias optlen: *c.socklen_t) c_int;
pub extern "c" fn setsockopt(sockfd: c.fd_t, level: u32, optname: u32, optval: ?*const anyopaque, optlen: c.socklen_t) c_int;
pub extern "c" fn send(sockfd: c.fd_t, buf: *const anyopaque, len: usize, flags: u32) isize;
pub extern "c" fn sendto(
    sockfd: c.fd_t,
    buf: *const anyopaque,
    len: usize,
    flags: u32,
    dest_addr: ?*const c.sockaddr,
    addrlen: c.socklen_t,
) isize;
pub extern "c" fn sendmsg(sockfd: c.fd_t, msg: *const c.msghdr_const, flags: u32) isize;

pub extern "c" fn recv(
    sockfd: c.fd_t,
    arg1: ?*anyopaque,
    arg2: usize,
    arg3: c_int,
) if (builtin.os.tag == .windows) c_int else isize;
pub extern "c" fn recvfrom(
    sockfd: c.fd_t,
    noalias buf: *anyopaque,
    len: usize,
    flags: u32,
    noalias src_addr: ?*c.sockaddr,
    noalias addrlen: ?*c.socklen_t,
) if (builtin.os.tag == .windows) c_int else isize;
pub extern "c" fn recvmsg(sockfd: c.fd_t, msg: *c.msghdr, flags: u32) isize;

pub extern "c" fn kill(pid: c.pid_t, sig: c_int) c_int;
pub extern "c" fn getdirentries(fd: c.fd_t, buf_ptr: [*]u8, nbytes: usize, basep: *i64) isize;

pub extern "c" fn setuid(uid: c.uid_t) c_int;
pub extern "c" fn setgid(gid: c.gid_t) c_int;
pub extern "c" fn seteuid(euid: c.uid_t) c_int;
pub extern "c" fn setegid(egid: c.gid_t) c_int;
pub extern "c" fn setreuid(ruid: c.uid_t, euid: c.uid_t) c_int;
pub extern "c" fn setregid(rgid: c.gid_t, egid: c.gid_t) c_int;
pub extern "c" fn setresuid(ruid: c.uid_t, euid: c.uid_t, suid: c.uid_t) c_int;
pub extern "c" fn setresgid(rgid: c.gid_t, egid: c.gid_t, sgid: c.gid_t) c_int;

pub extern "c" fn malloc(usize) ?*anyopaque;
pub extern "c" fn realloc(?*anyopaque, usize) ?*anyopaque;
pub extern "c" fn free(?*anyopaque) void;

pub extern "c" fn futimes(fd: c.fd_t, times: *[2]c.timeval) c_int;
pub extern "c" fn utimes(path: [*:0]const u8, times: *[2]c.timeval) c_int;

pub extern "c" fn utimensat(dirfd: c.fd_t, pathname: [*:0]const u8, times: *[2]c.timespec, flags: u32) c_int;
pub extern "c" fn futimens(fd: c.fd_t, times: *const [2]c.timespec) c_int;

pub extern "c" fn pthread_create(
    noalias newthread: *pthread_t,
    noalias attr: ?*const c.pthread_attr_t,
    start_routine: *const fn (?*anyopaque) callconv(.C) ?*anyopaque,
    noalias arg: ?*anyopaque,
) c.E;
pub extern "c" fn pthread_attr_init(attr: *c.pthread_attr_t) c.E;
pub extern "c" fn pthread_attr_setstack(attr: *c.pthread_attr_t, stackaddr: *anyopaque, stacksize: usize) c.E;
pub extern "c" fn pthread_attr_setstacksize(attr: *c.pthread_attr_t, stacksize: usize) c.E;
pub extern "c" fn pthread_attr_setguardsize(attr: *c.pthread_attr_t, guardsize: usize) c.E;
pub extern "c" fn pthread_attr_destroy(attr: *c.pthread_attr_t) c.E;
pub extern "c" fn pthread_self() pthread_t;
pub extern "c" fn pthread_join(thread: pthread_t, arg_return: ?*?*anyopaque) c.E;
pub extern "c" fn pthread_detach(thread: pthread_t) c.E;
pub extern "c" fn pthread_atfork(
    prepare: ?*const fn () callconv(.C) void,
    parent: ?*const fn () callconv(.C) void,
    child: ?*const fn () callconv(.C) void,
) c_int;
pub extern "c" fn pthread_key_create(
    key: *c.pthread_key_t,
    destructor: ?*const fn (value: *anyopaque) callconv(.C) void,
) c.E;
pub extern "c" fn pthread_key_delete(key: c.pthread_key_t) c.E;
pub extern "c" fn pthread_getspecific(key: c.pthread_key_t) ?*anyopaque;
pub extern "c" fn pthread_setspecific(key: c.pthread_key_t, value: ?*anyopaque) c_int;
pub extern "c" fn pthread_sigmask(how: c_int, set: *const c.sigset_t, oldset: *c.sigset_t) c_int;
pub extern "c" fn sem_init(sem: *c.sem_t, pshared: c_int, value: c_uint) c_int;
pub extern "c" fn sem_destroy(sem: *c.sem_t) c_int;
pub extern "c" fn sem_open(name: [*:0]const u8, flag: c_int, mode: c.mode_t, value: c_uint) *c.sem_t;
pub extern "c" fn sem_close(sem: *c.sem_t) c_int;
pub extern "c" fn sem_post(sem: *c.sem_t) c_int;
pub extern "c" fn sem_wait(sem: *c.sem_t) c_int;
pub extern "c" fn sem_trywait(sem: *c.sem_t) c_int;
pub extern "c" fn sem_timedwait(sem: *c.sem_t, abs_timeout: *const c.timespec) c_int;
pub extern "c" fn sem_getvalue(sem: *c.sem_t, sval: *c_int) c_int;

pub extern "c" fn shm_open(name: [*:0]const u8, flag: c_int, mode: c.mode_t) c_int;
pub extern "c" fn shm_unlink(name: [*:0]const u8) c_int;

pub extern "c" fn kqueue() c_int;
pub extern "c" fn kevent(
    kq: c_int,
    changelist: [*]const c.Kevent,
    nchanges: c_int,
    eventlist: [*]c.Kevent,
    nevents: c_int,
    timeout: ?*const c.timespec,
) c_int;

pub extern "c" fn port_create() c.port_t;
pub extern "c" fn port_associate(
    port: c.port_t,
    source: u32,
    object: usize,
    events: u32,
    user_var: ?*anyopaque,
) c_int;
pub extern "c" fn port_dissociate(port: c.port_t, source: u32, object: usize) c_int;
pub extern "c" fn port_send(port: c.port_t, events: u32, user_var: ?*anyopaque) c_int;
pub extern "c" fn port_sendn(
    ports: [*]c.port_t,
    errors: []u32,
    num_ports: u32,
    events: u32,
    user_var: ?*anyopaque,
) c_int;
pub extern "c" fn port_get(port: c.port_t, event: *c.port_event, timeout: ?*c.timespec) c_int;
pub extern "c" fn port_getn(
    port: c.port_t,
    event_list: []c.port_event,
    max_events: u32,
    events_retrieved: *u32,
    timeout: ?*c.timespec,
) c_int;
pub extern "c" fn port_alert(port: c.port_t, flags: u32, events: u32, user_var: ?*anyopaque) c_int;

pub extern "c" fn getaddrinfo(
    noalias node: ?[*:0]const u8,
    noalias service: ?[*:0]const u8,
    noalias hints: ?*const c.addrinfo,
    /// On Linux, `res` will not be modified on error and `freeaddrinfo` will
    /// potentially crash if you pass it an undefined pointer
    noalias res: *?*c.addrinfo,
) c.EAI;

pub extern "c" fn freeaddrinfo(res: *c.addrinfo) void;

pub extern "c" fn getnameinfo(
    noalias addr: *const c.sockaddr,
    addrlen: c.socklen_t,
    noalias host: [*]u8,
    hostlen: c.socklen_t,
    noalias serv: [*]u8,
    servlen: c.socklen_t,
    flags: u32,
) c.EAI;

pub extern "c" fn gai_strerror(errcode: c.EAI) [*:0]const u8;

pub extern "c" fn poll(fds: [*]c.pollfd, nfds: c.nfds_t, timeout: c_int) c_int;
pub extern "c" fn ppoll(fds: [*]c.pollfd, nfds: c.nfds_t, timeout: ?*const c.timespec, sigmask: ?*const c.sigset_t) c_int;

pub extern "c" fn dn_expand(
    msg: [*:0]const u8,
    eomorig: [*:0]const u8,
    comp_dn: [*:0]const u8,
    exp_dn: [*:0]u8,
    length: c_int,
) c_int;

pub const PTHREAD_MUTEX_INITIALIZER = c.pthread_mutex_t{};
pub extern "c" fn pthread_mutex_lock(mutex: *c.pthread_mutex_t) c.E;
pub extern "c" fn pthread_mutex_unlock(mutex: *c.pthread_mutex_t) c.E;
pub extern "c" fn pthread_mutex_trylock(mutex: *c.pthread_mutex_t) c.E;
pub extern "c" fn pthread_mutex_destroy(mutex: *c.pthread_mutex_t) c.E;

pub const PTHREAD_COND_INITIALIZER = c.pthread_cond_t{};
pub extern "c" fn pthread_cond_wait(noalias cond: *c.pthread_cond_t, noalias mutex: *c.pthread_mutex_t) c.E;
pub extern "c" fn pthread_cond_timedwait(noalias cond: *c.pthread_cond_t, noalias mutex: *c.pthread_mutex_t, noalias abstime: *const c.timespec) c.E;
pub extern "c" fn pthread_cond_signal(cond: *c.pthread_cond_t) c.E;
pub extern "c" fn pthread_cond_broadcast(cond: *c.pthread_cond_t) c.E;
pub extern "c" fn pthread_cond_destroy(cond: *c.pthread_cond_t) c.E;

pub extern "c" fn pthread_rwlock_destroy(rwl: *c.pthread_rwlock_t) callconv(.C) c.E;
pub extern "c" fn pthread_rwlock_rdlock(rwl: *c.pthread_rwlock_t) callconv(.C) c.E;
pub extern "c" fn pthread_rwlock_wrlock(rwl: *c.pthread_rwlock_t) callconv(.C) c.E;
pub extern "c" fn pthread_rwlock_tryrdlock(rwl: *c.pthread_rwlock_t) callconv(.C) c.E;
pub extern "c" fn pthread_rwlock_trywrlock(rwl: *c.pthread_rwlock_t) callconv(.C) c.E;
pub extern "c" fn pthread_rwlock_unlock(rwl: *c.pthread_rwlock_t) callconv(.C) c.E;

pub const pthread_t = *opaque {};
pub const FILE = opaque {};

pub extern "c" fn dlopen(path: [*:0]const u8, mode: c_int) ?*anyopaque;
pub extern "c" fn dlclose(handle: *anyopaque) c_int;
pub extern "c" fn dlsym(handle: ?*anyopaque, symbol: [*:0]const u8) ?*anyopaque;

pub extern "c" fn sync() void;
pub extern "c" fn syncfs(fd: c_int) c_int;
pub extern "c" fn fsync(fd: c_int) c_int;
pub extern "c" fn fdatasync(fd: c_int) c_int;

pub extern "c" fn prctl(option: c_int, ...) c_int;

pub extern "c" fn getrlimit(resource: c.rlimit_resource, rlim: *c.rlimit) c_int;
pub extern "c" fn setrlimit(resource: c.rlimit_resource, rlim: *const c.rlimit) c_int;

pub extern "c" fn fmemopen(noalias buf: ?*anyopaque, size: usize, noalias mode: [*:0]const u8) ?*FILE;

pub extern "c" fn syslog(priority: c_int, message: [*:0]const u8, ...) void;
pub extern "c" fn openlog(ident: [*:0]const u8, logopt: c_int, facility: c_int) void;
pub extern "c" fn closelog() void;
pub extern "c" fn setlogmask(maskpri: c_int) c_int;

pub extern "c" fn if_nametoindex([*:0]const u8) c_int;

pub usingnamespace if (builtin.os.tag == .linux and builtin.target.isMusl()) struct {
    // musl does not implement getcontext
    pub const getcontext = std.os.linux.getcontext;
} else struct {
    pub extern "c" fn getcontext(ucp: *std.os.ucontext_t) c_int;
};

pub const max_align_t = if (builtin.abi == .msvc)
    f64
else if (builtin.target.isDarwin())
    c_longdouble
else
    extern struct {
        a: c_longlong,
        b: c_longdouble,
    };
