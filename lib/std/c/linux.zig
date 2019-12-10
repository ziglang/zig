const builtin = @import("builtin");
const std = @import("../std.zig");
const maxInt = std.math.maxInt;
usingnamespace std.c;

pub const _errno = switch (builtin.abi) {
    .android => struct {
        extern "c" var __errno: c_int;
        fn getErrno() *c_int {
            return &__errno;
        }
    }.getErrno,
    else => struct {
        extern "c" fn __errno_location() *c_int;
    }.__errno_location,
};

pub const MAP_FAILED = @intToPtr(*c_void, maxInt(usize));

pub const AI_PASSIVE = 0x01;
pub const AI_CANONNAME = 0x02;
pub const AI_NUMERICHOST = 0x04;
pub const AI_V4MAPPED = 0x08;
pub const AI_ALL = 0x10;
pub const AI_ADDRCONFIG = 0x20;
pub const AI_NUMERICSERV = 0x400;

pub const NI_NUMERICHOST = 0x01;
pub const NI_NUMERICSERV = 0x02;
pub const NI_NOFQDN = 0x04;
pub const NI_NAMEREQD = 0x08;
pub const NI_DGRAM = 0x10;
pub const NI_NUMERICSCOPE = 0x100;

pub const EAI_BADFLAGS = -1;
pub const EAI_NONAME = -2;
pub const EAI_AGAIN = -3;
pub const EAI_FAIL = -4;
pub const EAI_FAMILY = -6;
pub const EAI_SOCKTYPE = -7;
pub const EAI_SERVICE = -8;
pub const EAI_MEMORY = -10;
pub const EAI_SYSTEM = -11;
pub const EAI_OVERFLOW = -12;

pub const EAI_NODATA = -5;
pub const EAI_ADDRFAMILY = -9;
pub const EAI_INPROGRESS = -100;
pub const EAI_CANCELED = -101;
pub const EAI_NOTCANCELED = -102;
pub const EAI_ALLDONE = -103;
pub const EAI_INTR = -104;
pub const EAI_IDN_ENCODE = -105;

pub extern "c" fn getrandom(buf_ptr: [*]u8, buf_len: usize, flags: c_uint) isize;
pub extern "c" fn sched_getaffinity(pid: c_int, size: usize, set: *cpu_set_t) c_int;
pub extern "c" fn eventfd(initval: c_uint, flags: c_uint) c_int;
pub extern "c" fn epoll_ctl(epfd: fd_t, op: c_uint, fd: fd_t, event: ?*epoll_event) c_int;
pub extern "c" fn epoll_create1(flags: c_uint) c_int;
pub extern "c" fn epoll_wait(epfd: fd_t, events: [*]epoll_event, maxevents: c_uint, timeout: c_int) c_int;
pub extern "c" fn epoll_pwait(
    epfd: fd_t,
    events: [*]epoll_event,
    maxevents: c_int,
    timeout: c_int,
    sigmask: *const sigset_t,
) c_int;
pub extern "c" fn inotify_init1(flags: c_uint) c_int;
pub extern "c" fn inotify_add_watch(fd: fd_t, pathname: [*]const u8, mask: u32) c_int;

/// See std.elf for constants for this
pub extern "c" fn getauxval(__type: c_ulong) c_ulong;

pub const dl_iterate_phdr_callback = extern fn (info: *dl_phdr_info, size: usize, data: ?*c_void) c_int;
pub extern "c" fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*c_void) c_int;

pub extern "c" fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) c_int;

pub const pthread_attr_t = extern struct {
    __size: [56]u8,
    __align: c_long,
};

pub const pthread_mutex_t = extern struct {
    size: [__SIZEOF_PTHREAD_MUTEX_T]u8 align(@alignOf(usize)) = [_]u8{0} ** __SIZEOF_PTHREAD_MUTEX_T,
};
pub const pthread_cond_t = extern struct {
    size: [__SIZEOF_PTHREAD_COND_T]u8 align(@alignOf(usize)) = [_]u8{0} ** __SIZEOF_PTHREAD_COND_T,
};
const __SIZEOF_PTHREAD_COND_T = 48;
const __SIZEOF_PTHREAD_MUTEX_T = if (builtin.os == .fuchsia) 40 else switch (builtin.abi) {
    .musl, .musleabi, .musleabihf => if (@sizeOf(usize) == 8) 40 else 24,
    .gnu, .gnuabin32, .gnuabi64, .gnueabi, .gnueabihf, .gnux32 => switch (builtin.arch) {
        .aarch64 => 48,
        .x86_64 => if (builtin.abi == .gnux32) 40 else 32,
        .mips64, .powerpc64, .powerpc64le, .sparcv9 => 40,
        else => if (@sizeOf(usize) == 8) 40 else 24,
    },
    else => unreachable,
};

pub const RTLD_LAZY = 1;
pub const RTLD_NOW = 2;
pub const RTLD_NOLOAD = 4;
pub const RTLD_NODELETE = 4096;
pub const RTLD_GLOBAL = 256;
pub const RTLD_LOCAL = 0;
