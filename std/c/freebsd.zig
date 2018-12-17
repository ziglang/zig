extern "c" fn __error() *c_int;
pub const _errno = __error;

pub extern "c" fn kqueue() c_int;
pub extern "c" fn kevent(
    kq: c_int,
    changelist: [*]const Kevent,
    nchanges: c_int,
    eventlist: [*]Kevent,
    nevents: c_int,
    timeout: ?*const timespec,
) c_int;
pub extern "c" fn sysctl(name: [*]c_int, namelen: c_uint, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) c_int;
pub extern "c" fn sysctlbyname(name: [*]const u8, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) c_int;
pub extern "c" fn sysctlnametomib(name: [*]const u8, mibp: ?*c_int, sizep: ?*usize) c_int;

/// Renamed from `kevent` to `Kevent` to avoid conflict with function name.
pub const Kevent = extern struct {
    ident: usize,
    filter: i16,
    flags: u16,
    fflags: u32,
    data: i64,
    udata: usize,
    // TODO ext
};

pub const pthread_attr_t = extern struct {
    __size: [56]u8,
    __align: c_long,
};

pub const msghdr = extern struct {
    msg_name: *u8,
    msg_namelen: socklen_t,
    msg_iov: *iovec,
    msg_iovlen: i32,
    __pad1: i32,
    msg_control: *u8,
    msg_controllen: socklen_t,
    __pad2: socklen_t,
    msg_flags: i32,
};

pub const Stat = extern struct {
    dev: u64,
    ino: u64,
    nlink: usize,

    mode: u32,
    uid: u32,
    gid: u32,
    __pad0: u32,
    rdev: u64,
    size: i64,
    blksize: isize,
    blocks: i64,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    __unused: [3]isize,
};

pub const timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};
