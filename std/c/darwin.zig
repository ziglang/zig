extern "c" fn __error() *c_int;
pub extern "c" fn _NSGetExecutablePath(buf: [*]u8, bufsize: *u32) c_int;

pub extern "c" fn __getdirentries64(fd: c_int, buf_ptr: [*]u8, buf_len: usize, basep: *i64) usize;

pub extern "c" fn mach_absolute_time() u64;
pub extern "c" fn mach_timebase_info(tinfo: ?*mach_timebase_info_data) void;

pub use @import("../os/darwin_errno.zig");

pub const _errno = __error;

pub const timeval = extern struct {
    tv_sec: isize,
    tv_usec: isize,
};

pub const timezone = extern struct {
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

pub const mach_timebase_info_data = struct {
    numer: u32,
    denom: u32,
};

/// Renamed to Stat to not conflict with the stat function.
pub const Stat = extern struct {
    dev: i32,
    mode: u16,
    nlink: u16,
    ino: u64,
    uid: u32,
    gid: u32,
    rdev: i32,
    atime: usize,
    atimensec: usize,
    mtime: usize,
    mtimensec: usize,
    ctime: usize,
    ctimensec: usize,
    birthtime: usize,
    birthtimensec: usize,
    size: i64,
    blocks: i64,
    blksize: i32,
    flags: u32,
    gen: u32,
    lspare: i32,
    qspare: [2]i64,
};

pub const timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};

pub const sigset_t = u32;

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with function name.
pub const Sigaction = extern struct {
    handler: extern fn (c_int) void,
    sa_mask: sigset_t,
    sa_flags: c_int,
};

pub const dirent = extern struct {
    d_ino: usize,
    d_seekoff: usize,
    d_reclen: u16,
    d_namlen: u16,
    d_type: u8,
    d_name: u8, // field address is address of first byte of name
};

pub const sockaddr = extern struct {
    sa_len: u8,
    sa_family: sa_family_t,
    sa_data: [14]u8,
};

pub const sa_family_t = u8;

pub const pthread_attr_t = extern struct {
    __sig: c_long,
    __opaque: [56]u8,
};
