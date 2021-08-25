const std = @import("std");
const builtin = std.builtin;
const page_size = std.mem.page_size;
const iovec = std.os.iovec;
const iovec_const = std.os.iovec_const;

pub const tokenizer = @import("c/tokenizer.zig");
pub const Token = tokenizer.Token;
pub const Tokenizer = tokenizer.Tokenizer;

test {
    _ = tokenizer;
}

const generic = @import("c/generic.zig");
const system = switch (builtin.os.tag) {
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

pub const _errno = system._errno;
pub const copy_file_range = system.copy_file_range;
pub const fallocate64 = system.fallocate64;
pub const fopen64 = system.fopen64;
pub const fstat64 = system.fstat64;
pub const fstatat64 = system.fstatat64;
pub const ftruncate64 = system.ftruncate64;
pub const getrlimit64 = system.getrlimit64;
pub const lseek64 = system.lseek64;
pub const mmap64 = system.mmap64;
pub const open64 = system.open64;
pub const openat64 = system.openat64;
pub const pread64 = system.pread64;
pub const preadv64 = system.preadv64;
pub const pwrite64 = system.pwrite64;
pub const pwritev64 = system.pwritev64;
pub const sendfile64 = system.sendfile64;
pub const setrlimit64 = system.setrlimit64;

pub const AF = system.AF;
pub const AI = system.AI;
pub const AT = system.AT;
pub const CLOCK = system.CLOCK;
pub const CPU_COUNT = system.CPU_COUNT;
pub const E = system.E;
pub const EAI = system.EAI;
pub const F = system.F;
pub const FD_CLOEXEC = system.FD_CLOEXEC;
pub const F_OK = system.F_OK;
pub const HOST_NAME_MAX = system.HOST_NAME_MAX;
pub const IFNAMESIZE = system.IFNAMESIZE;
pub const IOV_MAX = system.IOV_MAX;
pub const IPPROTO = system.IPPROTO;
pub const LOCK = system.LOCK;
pub const MADV = system.MADV;
pub const MAP = system.MAP;
pub const NAME_MAX = system.NAME_MAX;
pub const NI = system.NI;
pub const O = system.O;
pub const PATH_MAX = system.PATH_MAX;
pub const POLL = system.POLL;
pub const PROT = system.PROT;
pub const REG = system.REG;
pub const RLIM = system.RLIM;
pub const RTLD = system.RTLD;
pub const R_OK = system.R_OK;
pub const S = system.S;
pub const SA = system.SA;
pub const SEEK = system.SEEK;
pub const SHUT = system.SHUT;
pub const SIG = system.SIG;
pub const SIOCGIFINDEX = system.SIOCGIFINDEX;
pub const SO = system.SO;
pub const SOCK = system.SOCK;
pub const SOL = system.SOL;
pub const STDERR_FILENO = system.STDERR_FILENO;
pub const STDIN_FILENO = system.STDIN_FILENO;
pub const STDOUT_FILENO = system.STDOUT_FILENO;
pub const Sigaction = system.Sigaction;
pub const Stat = system.Stat;
pub const W = system.W;
pub const W_OK = system.W_OK;
pub const X_OK = system.X_OK;
pub const addrinfo = system.addrinfo;
pub const cpu_set_t = system.cpu_set_t;
pub const dl_iterate_phdr = system.dl_iterate_phdr;
pub const dl_iterate_phdr_callback = system.dl_iterate_phdr_callback;
pub const dl_phdr_info = system.dl_phdr_info;
pub const empty_sigset = system.empty_sigset;
pub const epoll_create1 = system.epoll_create1;
pub const epoll_ctl = system.epoll_ctl;
pub const epoll_pwait = system.epoll_pwait;
pub const epoll_wait = system.epoll_wait;
pub const eventfd = system.eventfd;
pub const fallocate = system.fallocate;
pub const fd_t = system.fd_t;
pub const getauxval = system.getauxval;
pub const getdents = system.getdents;
pub const getrandom = system.getrandom;
pub const gid_t = system.gid_t;
pub const ifreq = system.ifreq;
pub const ino_t = system.ino_t;
pub const inotify_add_watch = system.inotify_add_watch;
pub const inotify_init1 = system.inotify_init1;
pub const inotify_rm_watch = system.inotify_rm_watch;
pub const madvise = system.madvise;
pub const malloc_usable_size = system.malloc_usable_size;
pub const memfd_create = system.memfd_create;
pub const mode_t = system.mode_t;
pub const nfds_t = system.nfds_t;
pub const off_t = system.off_t;
pub const pid_t = system.pid_t;
pub const pipe2 = system.pipe2;
pub const pollfd = system.pollfd;
pub const posix_memalign = system.posix_memalign;
pub const prlimit = system.prlimit;
pub const pthread_attr_t = system.pthread_attr_t;
pub const pthread_cond_t = system.pthread_cond_t;
pub const pthread_getname_np = system.pthread_getname_np;
pub const pthread_mutex_t = system.pthread_mutex_t;
pub const pthread_rwlock_t = system.pthread_rwlock_t;
pub const pthread_setname_np = system.pthread_setname_np;
pub const rlim_t = system.rlim_t;
pub const rlimit = system.rlimit;
pub const rlimit_resource = system.rlimit_resource;
pub const sched_getaffinity = system.sched_getaffinity;
pub const sem_t = system.sem_t;
pub const sendfile = system.sendfile;
pub const sigaltstack = system.sigaltstack;
pub const siginfo_t = system.siginfo_t;
pub const signalfd = system.signalfd;
pub const sigset_t = system.sigset_t;
pub const sockaddr = system.sockaddr;
pub const socklen_t = system.socklen_t;
pub const stack_t = system.stack_t;
pub const timespec = system.timespec;
pub const timeval = system.timeval;
pub const ucontext_t = system.ucontext_t;
pub const uid_t = system.uid_t;
pub const utsname = system.utsname;

pub const alarm = if (@hasDecl(system, "alarm")) system.alarm else generic.alarm;
pub const clock_getres = if (@hasDecl(system, "clock_getres")) system.clock_getres else generic.clock_getres;
pub const clock_gettime = if (@hasDecl(system, "clock_gettime")) system.clock_gettime else generic.clock_gettime;
pub const fstat = if (@hasDecl(system, "fstat")) system.fstat else generic.fstat;
pub const fstatat = if (@hasDecl(system, "fstatat")) system.fstatat else generic.fstatat;
pub const getrusage = if (@hasDecl(system, "getrusage")) system.getrusage else generic.getrusage;
pub const gettimeofday = if (@hasDecl(system, "gettimeofday")) system.gettimeofday else generic.gettimeofday;
pub const nanosleep = if (@hasDecl(system, "nanosleep")) system.nanosleep else generic.nanosleep;
pub const realpath = if (@hasDecl(system, "realpath")) system.realpath else generic.realpath;
pub const sched_yield = if (@hasDecl(system, "sched_yield")) system.sched_yield else generic.sched_yield;
pub const sigaction = if (@hasDecl(system, "sigaction")) system.sigaction else generic.sigaction;
pub const sigfillset = if (@hasDecl(system, "sigfillset")) system.sigfillset else generic.sigfillset;
pub const sigprocmask = if (@hasDecl(system, "sigprocmask")) system.sigprocmask else generic.sigprocmask;
pub const sigwait = if (@hasDecl(system, "sigwait")) system.sigwait else generic.sigwait;
pub const socket = if (@hasDecl(system, "socket")) system.socket else generic.socket;
pub const stat = if (@hasDecl(system, "stat")) system.stat else generic.stat;

pub fn getErrno(rc: anytype) E {
    if (rc == -1) {
        return @intToEnum(E, _errno().*);
    } else {
        return .SUCCESS;
    }
}

/// The return type is `type` to force comptime function call execution.
/// TODO: https://github.com/ziglang/zig/issues/425
/// If not linking libc, returns struct{pub const ok = false;}
/// If linking musl libc, returns struct{pub const ok = true;}
/// If linking gnu libc (glibc), the `ok` value will be true if the target
/// version is greater than or equal to `glibc_version`.
/// If linking a libc other than these, returns `false`.
pub fn versionCheck(glibc_version: builtin.Version) type {
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

pub extern "c" var environ: [*:null]?[*:0]u8;

pub extern "c" fn fopen(noalias filename: [*:0]const u8, noalias modes: [*:0]const u8) ?*FILE;
pub extern "c" fn fclose(stream: *FILE) c_int;
pub extern "c" fn fwrite(noalias ptr: [*]const u8, size_of_type: usize, item_count: usize, noalias stream: *FILE) usize;
pub extern "c" fn fread(noalias ptr: [*]u8, size_of_type: usize, item_count: usize, noalias stream: *FILE) usize;

pub extern "c" fn printf(format: [*:0]const u8, ...) c_int;
pub extern "c" fn abort() noreturn;
pub extern "c" fn exit(code: c_int) noreturn;
pub extern "c" fn _exit(code: c_int) noreturn;
pub extern "c" fn isatty(fd: fd_t) c_int;
pub extern "c" fn close(fd: fd_t) c_int;
pub extern "c" fn lseek(fd: fd_t, offset: off_t, whence: c_int) off_t;
pub extern "c" fn open(path: [*:0]const u8, oflag: c_uint, ...) c_int;
pub extern "c" fn openat(fd: c_int, path: [*:0]const u8, oflag: c_uint, ...) c_int;
pub extern "c" fn ftruncate(fd: c_int, length: off_t) c_int;
pub extern "c" fn raise(sig: c_int) c_int;
pub extern "c" fn read(fd: fd_t, buf: [*]u8, nbyte: usize) isize;
pub extern "c" fn readv(fd: c_int, iov: [*]const iovec, iovcnt: c_uint) isize;
pub extern "c" fn pread(fd: fd_t, buf: [*]u8, nbyte: usize, offset: off_t) isize;
pub extern "c" fn preadv(fd: c_int, iov: [*]const iovec, iovcnt: c_uint, offset: off_t) isize;
pub extern "c" fn writev(fd: c_int, iov: [*]const iovec_const, iovcnt: c_uint) isize;
pub extern "c" fn pwritev(fd: c_int, iov: [*]const iovec_const, iovcnt: c_uint, offset: off_t) isize;
pub extern "c" fn write(fd: fd_t, buf: [*]const u8, nbyte: usize) isize;
pub extern "c" fn pwrite(fd: fd_t, buf: [*]const u8, nbyte: usize, offset: off_t) isize;
pub extern "c" fn mmap(addr: ?*align(page_size) c_void, len: usize, prot: c_uint, flags: c_uint, fd: fd_t, offset: off_t) *c_void;
pub extern "c" fn munmap(addr: *align(page_size) const c_void, len: usize) c_int;
pub extern "c" fn mprotect(addr: *align(page_size) c_void, len: usize, prot: c_uint) c_int;
pub extern "c" fn link(oldpath: [*:0]const u8, newpath: [*:0]const u8, flags: c_int) c_int;
pub extern "c" fn linkat(oldfd: fd_t, oldpath: [*:0]const u8, newfd: fd_t, newpath: [*:0]const u8, flags: c_int) c_int;
pub extern "c" fn unlink(path: [*:0]const u8) c_int;
pub extern "c" fn unlinkat(dirfd: fd_t, path: [*:0]const u8, flags: c_uint) c_int;
pub extern "c" fn getcwd(buf: [*]u8, size: usize) ?[*]u8;
pub extern "c" fn waitpid(pid: pid_t, stat_loc: ?*c_int, options: c_int) pid_t;
pub extern "c" fn fork() c_int;
pub extern "c" fn access(path: [*:0]const u8, mode: c_uint) c_int;
pub extern "c" fn faccessat(dirfd: fd_t, path: [*:0]const u8, mode: c_uint, flags: c_uint) c_int;
pub extern "c" fn pipe(fds: *[2]fd_t) c_int;
pub extern "c" fn mkdir(path: [*:0]const u8, mode: c_uint) c_int;
pub extern "c" fn mkdirat(dirfd: fd_t, path: [*:0]const u8, mode: u32) c_int;
pub extern "c" fn symlink(existing: [*:0]const u8, new: [*:0]const u8) c_int;
pub extern "c" fn symlinkat(oldpath: [*:0]const u8, newdirfd: fd_t, newpath: [*:0]const u8) c_int;
pub extern "c" fn rename(old: [*:0]const u8, new: [*:0]const u8) c_int;
pub extern "c" fn renameat(olddirfd: fd_t, old: [*:0]const u8, newdirfd: fd_t, new: [*:0]const u8) c_int;
pub extern "c" fn chdir(path: [*:0]const u8) c_int;
pub extern "c" fn fchdir(fd: fd_t) c_int;
pub extern "c" fn execve(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) c_int;
pub extern "c" fn dup(fd: fd_t) c_int;
pub extern "c" fn dup2(old_fd: fd_t, new_fd: fd_t) c_int;
pub extern "c" fn readlink(noalias path: [*:0]const u8, noalias buf: [*]u8, bufsize: usize) isize;
pub extern "c" fn readlinkat(dirfd: fd_t, noalias path: [*:0]const u8, noalias buf: [*]u8, bufsize: usize) isize;

pub extern "c" fn rmdir(path: [*:0]const u8) c_int;
pub extern "c" fn getenv(name: [*:0]const u8) ?[*:0]u8;
pub extern "c" fn sysctl(name: [*]const c_int, namelen: c_uint, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) c_int;
pub extern "c" fn sysctlbyname(name: [*:0]const u8, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) c_int;
pub extern "c" fn sysctlnametomib(name: [*:0]const u8, mibp: ?*c_int, sizep: ?*usize) c_int;
pub extern "c" fn tcgetattr(fd: fd_t, termios_p: *termios) c_int;
pub extern "c" fn tcsetattr(fd: fd_t, optional_action: TCSA, termios_p: *const termios) c_int;
pub extern "c" fn fcntl(fd: fd_t, cmd: c_int, ...) c_int;
pub extern "c" fn flock(fd: fd_t, operation: c_int) c_int;
pub extern "c" fn ioctl(fd: fd_t, request: c_int, ...) c_int;
pub extern "c" fn uname(buf: *utsname) c_int;

pub extern "c" fn gethostname(name: [*]u8, len: usize) c_int;
pub extern "c" fn shutdown(socket: fd_t, how: c_int) c_int;
pub extern "c" fn bind(socket: fd_t, address: ?*const sockaddr, address_len: socklen_t) c_int;
pub extern "c" fn socketpair(domain: c_uint, sock_type: c_uint, protocol: c_uint, sv: *[2]fd_t) c_int;
pub extern "c" fn listen(sockfd: fd_t, backlog: c_uint) c_int;
pub extern "c" fn getsockname(sockfd: fd_t, noalias addr: *sockaddr, noalias addrlen: *socklen_t) c_int;
pub extern "c" fn getpeername(sockfd: fd_t, noalias addr: *sockaddr, noalias addrlen: *socklen_t) c_int;
pub extern "c" fn connect(sockfd: fd_t, sock_addr: *const sockaddr, addrlen: socklen_t) c_int;
pub extern "c" fn accept(sockfd: fd_t, noalias addr: ?*sockaddr, noalias addrlen: ?*socklen_t) c_int;
pub extern "c" fn accept4(sockfd: fd_t, noalias addr: ?*sockaddr, noalias addrlen: ?*socklen_t, flags: c_uint) c_int;
pub extern "c" fn getsockopt(sockfd: fd_t, level: u32, optname: u32, noalias optval: ?*c_void, noalias optlen: *socklen_t) c_int;
pub extern "c" fn setsockopt(sockfd: fd_t, level: u32, optname: u32, optval: ?*const c_void, optlen: socklen_t) c_int;
pub extern "c" fn send(sockfd: fd_t, buf: *const c_void, len: usize, flags: u32) isize;
pub extern "c" fn sendto(
    sockfd: fd_t,
    buf: *const c_void,
    len: usize,
    flags: u32,
    dest_addr: ?*const sockaddr,
    addrlen: socklen_t,
) isize;
pub extern "c" fn sendmsg(sockfd: fd_t, msg: *const std.x.os.Socket.Message, flags: c_int) isize;

pub extern "c" fn recv(sockfd: fd_t, arg1: ?*c_void, arg2: usize, arg3: c_int) isize;
pub extern "c" fn recvfrom(
    sockfd: fd_t,
    noalias buf: *c_void,
    len: usize,
    flags: u32,
    noalias src_addr: ?*sockaddr,
    noalias addrlen: ?*socklen_t,
) isize;
pub extern "c" fn recvmsg(sockfd: fd_t, msg: *std.x.os.Socket.Message, flags: c_int) isize;

pub extern "c" fn kill(pid: pid_t, sig: c_int) c_int;
pub extern "c" fn getdirentries(fd: fd_t, buf_ptr: [*]u8, nbytes: usize, basep: *i64) isize;

pub extern "c" fn setuid(uid: uid_t) c_int;
pub extern "c" fn setgid(gid: gid_t) c_int;
pub extern "c" fn seteuid(euid: uid_t) c_int;
pub extern "c" fn setegid(egid: gid_t) c_int;
pub extern "c" fn setreuid(ruid: uid_t, euid: uid_t) c_int;
pub extern "c" fn setregid(rgid: gid_t, egid: gid_t) c_int;
pub extern "c" fn setresuid(ruid: uid_t, euid: uid_t, suid: uid_t) c_int;
pub extern "c" fn setresgid(rgid: gid_t, egid: gid_t, sgid: gid_t) c_int;

pub extern "c" fn malloc(usize) ?*c_void;
pub extern "c" fn realloc(?*c_void, usize) ?*c_void;
pub extern "c" fn free(?*c_void) void;

pub extern "c" fn futimes(fd: fd_t, times: *[2]timeval) c_int;
pub extern "c" fn utimes(path: [*:0]const u8, times: *[2]timeval) c_int;

pub extern "c" fn utimensat(dirfd: fd_t, pathname: [*:0]const u8, times: *[2]timespec, flags: u32) c_int;
pub extern "c" fn futimens(fd: fd_t, times: *const [2]timespec) c_int;

pub extern "c" fn pthread_create(noalias newthread: *pthread_t, noalias attr: ?*const pthread_attr_t, start_routine: fn (?*c_void) callconv(.C) ?*c_void, noalias arg: ?*c_void) E;
pub extern "c" fn pthread_attr_init(attr: *pthread_attr_t) E;
pub extern "c" fn pthread_attr_setstack(attr: *pthread_attr_t, stackaddr: *c_void, stacksize: usize) E;
pub extern "c" fn pthread_attr_setstacksize(attr: *pthread_attr_t, stacksize: usize) E;
pub extern "c" fn pthread_attr_setguardsize(attr: *pthread_attr_t, guardsize: usize) E;
pub extern "c" fn pthread_attr_destroy(attr: *pthread_attr_t) E;
pub extern "c" fn pthread_self() pthread_t;
pub extern "c" fn pthread_join(thread: pthread_t, arg_return: ?*?*c_void) E;
pub extern "c" fn pthread_detach(thread: pthread_t) E;
pub extern "c" fn pthread_atfork(
    prepare: ?fn () callconv(.C) void,
    parent: ?fn () callconv(.C) void,
    child: ?fn () callconv(.C) void,
) c_int;
pub extern "c" fn pthread_key_create(key: *pthread_key_t, destructor: ?fn (value: *c_void) callconv(.C) void) E;
pub extern "c" fn pthread_key_delete(key: pthread_key_t) E;
pub extern "c" fn pthread_getspecific(key: pthread_key_t) ?*c_void;
pub extern "c" fn pthread_setspecific(key: pthread_key_t, value: ?*c_void) c_int;
pub extern "c" fn sem_init(sem: *sem_t, pshared: c_int, value: c_uint) c_int;
pub extern "c" fn sem_destroy(sem: *sem_t) c_int;
pub extern "c" fn sem_post(sem: *sem_t) c_int;
pub extern "c" fn sem_wait(sem: *sem_t) c_int;
pub extern "c" fn sem_trywait(sem: *sem_t) c_int;
pub extern "c" fn sem_timedwait(sem: *sem_t, abs_timeout: *const timespec) c_int;
pub extern "c" fn sem_getvalue(sem: *sem_t, sval: *c_int) c_int;

pub extern "c" fn kqueue() c_int;
pub extern "c" fn kevent(
    kq: c_int,
    changelist: [*]const Kevent,
    nchanges: c_int,
    eventlist: [*]Kevent,
    nevents: c_int,
    timeout: ?*const timespec,
) c_int;

pub extern "c" fn getaddrinfo(
    noalias node: ?[*:0]const u8,
    noalias service: ?[*:0]const u8,
    noalias hints: ?*const addrinfo,
    noalias res: **addrinfo,
) EAI;

pub extern "c" fn freeaddrinfo(res: *addrinfo) void;

pub extern "c" fn getnameinfo(
    noalias addr: *const sockaddr,
    addrlen: socklen_t,
    noalias host: [*]u8,
    hostlen: socklen_t,
    noalias serv: [*]u8,
    servlen: socklen_t,
    flags: u32,
) EAI;

pub extern "c" fn gai_strerror(errcode: EAI) [*:0]const u8;

pub extern "c" fn poll(fds: [*]pollfd, nfds: nfds_t, timeout: c_int) c_int;
pub extern "c" fn ppoll(fds: [*]pollfd, nfds: nfds_t, timeout: ?*const timespec, sigmask: ?*const sigset_t) c_int;

pub extern "c" fn dn_expand(
    msg: [*:0]const u8,
    eomorig: [*:0]const u8,
    comp_dn: [*:0]const u8,
    exp_dn: [*:0]u8,
    length: c_int,
) c_int;

pub const PTHREAD_MUTEX_INITIALIZER = pthread_mutex_t{};
pub extern "c" fn pthread_mutex_lock(mutex: *pthread_mutex_t) E;
pub extern "c" fn pthread_mutex_unlock(mutex: *pthread_mutex_t) E;
pub extern "c" fn pthread_mutex_trylock(mutex: *pthread_mutex_t) E;
pub extern "c" fn pthread_mutex_destroy(mutex: *pthread_mutex_t) E;

pub const PTHREAD_COND_INITIALIZER = pthread_cond_t{};
pub extern "c" fn pthread_cond_wait(noalias cond: *pthread_cond_t, noalias mutex: *pthread_mutex_t) E;
pub extern "c" fn pthread_cond_timedwait(noalias cond: *pthread_cond_t, noalias mutex: *pthread_mutex_t, noalias abstime: *const timespec) E;
pub extern "c" fn pthread_cond_signal(cond: *pthread_cond_t) E;
pub extern "c" fn pthread_cond_broadcast(cond: *pthread_cond_t) E;
pub extern "c" fn pthread_cond_destroy(cond: *pthread_cond_t) E;

pub extern "c" fn pthread_rwlock_destroy(rwl: *pthread_rwlock_t) callconv(.C) E;
pub extern "c" fn pthread_rwlock_rdlock(rwl: *pthread_rwlock_t) callconv(.C) E;
pub extern "c" fn pthread_rwlock_wrlock(rwl: *pthread_rwlock_t) callconv(.C) E;
pub extern "c" fn pthread_rwlock_tryrdlock(rwl: *pthread_rwlock_t) callconv(.C) E;
pub extern "c" fn pthread_rwlock_trywrlock(rwl: *pthread_rwlock_t) callconv(.C) E;
pub extern "c" fn pthread_rwlock_unlock(rwl: *pthread_rwlock_t) callconv(.C) E;

pub const pthread_t = *opaque {};
pub const FILE = opaque {};

pub extern "c" fn dlopen(path: [*:0]const u8, mode: c_int) ?*c_void;
pub extern "c" fn dlclose(handle: *c_void) c_int;
pub extern "c" fn dlsym(handle: ?*c_void, symbol: [*:0]const u8) ?*c_void;

pub extern "c" fn sync() void;
pub extern "c" fn syncfs(fd: c_int) c_int;
pub extern "c" fn fsync(fd: c_int) c_int;
pub extern "c" fn fdatasync(fd: c_int) c_int;

pub extern "c" fn prctl(option: c_int, ...) c_int;

pub extern "c" fn getrlimit(resource: rlimit_resource, rlim: *rlimit) c_int;
pub extern "c" fn setrlimit(resource: rlimit_resource, rlim: *const rlimit) c_int;

pub extern "c" fn fmemopen(noalias buf: ?*c_void, size: usize, noalias mode: [*:0]const u8) ?*FILE;

pub extern "c" fn syslog(priority: c_int, message: [*:0]const u8, ...) void;
pub extern "c" fn openlog(ident: [*:0]const u8, logopt: c_int, facility: c_int) void;
pub extern "c" fn closelog() void;
pub extern "c" fn setlogmask(maskpri: c_int) c_int;

pub const max_align_t = if (builtin.abi == .msvc)
    f64
else if (builtin.target.isDarwin())
    c_longdouble
else
    extern struct {
        a: c_longlong,
        b: c_longdouble,
    };
