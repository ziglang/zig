//! VLFTS - Very Large File and Time Symbols.
//! This file contains a list of symbols exported by glibc/musl that support using
//! 64-bit file offsets and 64-bit seconds in timestamps (or both!).
const std = @import("std");
const builtin = @import("builtin");
const c = std.c;

const clockid_t = c.clockid_t;
const DIR = c.DIR;
const dirent = c.dirent;
const E = c.E;
const fd_t = c.fd_t;
const FILE = c.FILE;
const iovec = c.iovec;
const iovec_const = c.iovec_const;
const itimerspec = c.itimerspec;
const MAP = c.MAP;
const msghdr = c.msghdr;
const O = c.O;
const off_t = c.off_t;
const page_size = std.mem.page_size;
const pid_t = c.pid_t;
const pthread_cond_t = c.pthread_cond_t;
const pthread_mutex_t = c.pthread_mutex_t;
const rlimit = c.rlimit;
const rlimit_resource = c.rlimit_resource;
const rusage = c.rusage;
const sem_t = c.sem_t;
const socklen_t = c.socklen_t;
const Stat = c.Stat;
const TFD = c.TFD;
const timespec = c.timespec;
const timeval = c.timeval;
const timezone = c.timezone;
const usize_bits = @typeInfo(usize).int.bits;

/// True if this target should use the "largefile" ABI.
/// This is only true when linking against glibc, as:
///  - musl always uses 64-bit file offsets.
///  - The largefile symbols are weakly linked to the normal symbols on 64-bit targets,
///    while musl defines them in the header files.
pub const largefile_abi = builtin.os.tag == .linux and
    builtin.link_libc and
    builtin.abi.isGnu();

/// True if this target should use the "time64" ABI.
pub const time64_abi = builtin.os.tag == .linux and
    builtin.link_libc and
    (builtin.abi.isGnu() or builtin.abi.isMusl()) and
    switch (builtin.cpu.arch) {
    // 32-bit targets.
    .arm,
    .armeb,
    .csky,
    .hexagon,
    .m68k,
    .mips,
    .mipsel,
    .powerpc,
    .powerpcle,
    .sparc,
    .thumb,
    .thumbeb,
    .xtensa,
    => true,
    // 64-bit targets.
    .aarch64_be,
    .aarch64,
    .loongarch64,
    .powerpc64,
    .powerpc64le,
    .riscv64,
    .s390x,
    .sparc64,
    .x86_64,
    => false,
    // Modern 32-bit targets with 64-bit time.
    // See the glibc headers <bits/timesize.h> and <features-time64.h>.
    .arc,
    .riscv32,
    .loongarch32,
    => false,
    // 64-bit targets running in a 32-bit mode.
    .mips64,
    .mips64el,
    => builtin.abi == .gnuabin32,
    .x86 => builtin.abi != .gnux32,
    else => @compileError("unsupported abi"),
};

// Symbols shared between both c libraries.
pub extern "c" fn __clock_gettime64(clk_id: clockid_t, tp: *timespec) c_int;
pub extern "c" fn __clock_nanosleep_time64(clockid: clockid_t, flags: u32, t: *const timespec, remain: ?*timespec) c_int;
pub extern "c" fn __clock_settime64(clk_id: clockid_t, tp: *const timespec) c_int;
pub extern "c" fn __ioctl_time64(fd: fd_t, request: c_int, ...) c_int;
pub extern "c" fn __sem_timedwait64(sem: *sem_t, abs_timeout: *const timespec) c_int;
pub extern "c" fn __timerfd_gettime64(fd: i32, curr_value: *itimerspec) c_int;
pub extern "c" fn __timerfd_settime64(fd: i32, flags: TFD.TIMER, noalias new_value: *const itimerspec, noalias old_value: ?*itimerspec) c_int;
pub extern "c" fn __wait4_time64(pid: pid_t, rstatus: ?*c_int, options: c_int, ru: ?*rusage) pid_t;
// glibc specific
pub extern "c" fn __adjtime64(delta: *const timeval, olddelta: *timeval) c_int;
pub extern "c" fn __clock_getres64(clk_id: clockid_t, tp: ?*timespec) c_int;
pub extern "c" fn __fcntl_time64(fd: fd_t, cmd: c_int, ...) c_int;
pub extern "c" fn __fstat64_time64(fd: fd_t, buf: *Stat) c_int;
pub extern "c" fn __fstatat64_time64(dirfd: fd_t, noalias path: [*:0]const u8, noalias buf: *Stat, flag: u32) c_int;
pub extern "c" fn __futimens64(fd: fd_t, times: ?*const [2]timespec) c_int;
pub extern "c" fn __futimes64(fd: fd_t, times: *[2]timeval) c_int;
pub extern "c" fn __getrusage64(who: c_int, usage: *rusage) c_int;
pub extern "c" fn __getsockopt64(sockfd: fd_t, level: i32, optname: u32, noalias optval: ?*anyopaque, noalias optlen: *socklen_t) c_int;
pub extern "c" fn __gettimeofday64(noalias tv: ?*timeval, noalias tz: ?*timezone) c_int;
pub extern "c" fn __nanosleep64(rqtp: *const timespec, rmtp: ?*timespec) c_int;
pub extern "c" fn __prctl_time64(option: c_int, ...) c_int;
pub extern "c" fn __pthread_cond_timedwait64(noalias cond: *pthread_cond_t, noalias mutex: *pthread_mutex_t, noalias abstime: *const timespec) E;
pub extern "c" fn __recvmsg64(sockfd: fd_t, msg: *msghdr, flags: u32) isize;
pub extern "c" fn __sendmsg64(sockfd: fd_t, msg: *const msghdr, flags: u32) c_int;
pub extern "c" fn __setsockopt64(sockfd: fd_t, level: i32, optname: u32, optval: ?*const anyopaque, optlen: socklen_t) c_int;
pub extern "c" fn __stat64_time64(noalias path: [*:0]const u8, noalias buf: *Stat) c_int;
pub extern "c" fn __utimensat64(dirfd: fd_t, pathname: [*:0]const u8, times: ?*const [2]timespec, flags: u32) c_int;
pub extern "c" fn __utimes64(path: [*:0]const u8, times: *[2]timeval) c_int;
pub extern "c" fn fallocate64(fd: fd_t, mode: c_int, offset: off_t, len: off_t) c_int;
pub extern "c" fn fopen64(noalias filename: [*:0]const u8, noalias modes: [*:0]const u8) ?*FILE;
pub extern "c" fn fstat64(fd: fd_t, buf: *Stat) c_int;
pub extern "c" fn fstatat64(dirfd: fd_t, noalias path: [*:0]const u8, noalias stat_buf: *Stat, flags: u32) c_int;
pub extern "c" fn ftruncate64(fd: c_int, length: off_t) c_int;
pub extern "c" fn getdents64(fd: c_int, buf_ptr: [*]u8, nbytes: usize) isize;
pub extern "c" fn getdirentries64(fd: fd_t, buf_ptr: [*]u8, nbytes: usize, basep: *i64) isize;
pub extern "c" fn getrlimit64(resource: rlimit_resource, rlim: *rlimit) c_int;
pub extern "c" fn lseek64(fd: fd_t, offset: i64, whence: c_int) i64;
pub extern "c" fn mmap64(addr: ?*align(page_size) anyopaque, len: usize, prot: c_uint, flags: c_uint, fd: fd_t, offset: i64) *anyopaque;
pub extern "c" fn open64(path: [*:0]const u8, oflag: O, ...) c_int;
pub extern "c" fn openat64(fd: c_int, path: [*:0]const u8, oflag: O, ...) c_int;
pub extern "c" fn pread64(fd: fd_t, buf: [*]u8, nbyte: usize, offset: i64) isize;
pub extern "c" fn preadv64(fd: c_int, iov: [*]const iovec, iovcnt: c_uint, offset: i64) isize;
pub extern "c" fn prlimit64(pid: pid_t, resource: rlimit_resource, new_limit: *const rlimit, old_limit: *rlimit) c_int;
pub extern "c" fn pwrite64(fd: fd_t, buf: [*]const u8, nbyte: usize, offset: i64) isize;
pub extern "c" fn pwritev64(fd: c_int, iov: [*]const iovec_const, iovcnt: c_uint, offset: i64) isize;
pub extern "c" fn readdir64(dir: *DIR) ?*dirent;
pub extern "c" fn sendfile64(out_fd: fd_t, in_fd: fd_t, offset: ?*i64, count: usize) isize;
pub extern "c" fn setrlimit64(resource: rlimit_resource, rlim: *const rlimit) c_int;
pub extern "c" fn stat64(noalias path: [*:0]const u8, noalias buf: *Stat) c_int;
pub extern "c" fn truncate64(path: [*:0]const u8, length: off_t) c_int;
// musl specific
pub extern "c" fn __clock_getres_time64(clk_id: clockid_t, tp: ?*timespec) c_int;
pub extern "c" fn __fstat_time64(fd: fd_t, buf: *Stat) c_int;
pub extern "c" fn __fstatat_time64(dirfd: fd_t, noalias path: [*:0]const u8, noalias buf: *Stat, flag: u32) c_int;
pub extern "c" fn __futimens_time64(fd: fd_t, times: ?*const [2]timespec) c_int;
pub extern "c" fn __futimes_time64(fd: fd_t, times: *[2]timeval) c_int;
pub extern "c" fn __getrusage_time64(who: c_int, usage: *rusage) c_int;
pub extern "c" fn __gettimeofday_time64(noalias tv: ?*timeval, noalias tz: ?*timezone) c_int;
pub extern "c" fn __nanosleep_time64(rqtp: *const timespec, rmtp: ?*timespec) c_int;
pub extern "c" fn __pthread_cond_timedwait_time64(noalias cond: *pthread_cond_t, noalias mutex: *pthread_mutex_t, noalias abstime: *const timespec) E;
pub extern "c" fn __stat_time64(noalias path: [*:0]const u8, noalias buf: *Stat) c_int;
pub extern "c" fn __utimensat_time64(dirfd: fd_t, pathname: [*:0]const u8, times: ?*const [2]timespec, flags: u32) c_int;
pub extern "c" fn __utimes_time64(path: [*:0]const u8, times: *[2]timeval) c_int;
