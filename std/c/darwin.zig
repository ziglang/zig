extern "c" fn __error() -> &c_int;

pub use @import("../os/darwin_errno.zig");

pub const _errno = __error;

/// Renamed to Stat to not conflict with the stat function.
pub const Stat = extern struct {
    dev: u32,
    mode: u16,
    nlink: u16,
    ino: u64,
    uid: u32,
    gid: u32,
    rdev: u64,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,

    size: u64,
    blocks: u64,
    blksize: u32,
    flags: u32,
    gen: u32,
    lspare: i32,
    qspare: [2]u64,

};

pub const timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};

pub const sigset_t = u32;

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with function name.
pub const Sigaction = extern struct {
    handler: extern fn(c_int),
    sa_mask: sigset_t,
    sa_flags: c_int,
};
