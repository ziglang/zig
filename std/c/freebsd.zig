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
pub extern "c" fn getdirentries(fd: c_int, buf_ptr: [*]u8, nbytes: usize, basep: *i64) usize;
pub extern "c" fn getdents(fd: c_int, buf_ptr: [*]u8, nbytes: usize) usize;
pub extern "c" fn pipe2(arg0: *[2]c_int, arg1: u32) c_int;
pub extern "c" fn preadv(fd: c_int, iov: *const c_void, iovcnt: c_int, offset: usize) isize;
pub extern "c" fn pwritev(fd: c_int, iov: *const c_void, iovcnt: c_int, offset: usize) isize;
pub extern "c" fn openat(fd: c_int, path: ?[*]const u8, flags: c_int) c_int;
pub extern "c" fn setgid(ruid: c_uint, euid: c_uint) c_int;
pub extern "c" fn setuid(uid: c_uint) c_int;
pub extern "c" fn kill(pid: c_int, sig: c_int) c_int;
pub extern "c" fn clock_gettime(clk_id: c_int, tp: *timespec) c_int;
pub extern "c" fn clock_getres(clk_id: c_int, tp: *timespec) c_int;

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
    /// optional address
    msg_name: ?*sockaddr,

    /// size of address
    msg_namelen: socklen_t,

    /// scatter/gather array
    msg_iov: [*]iovec,

    /// # elements in msg_iov
    msg_iovlen: i32,

    /// ancillary data
    msg_control: ?*c_void,

    /// ancillary data buffer len
    msg_controllen: socklen_t,

    /// flags on received message
    msg_flags: i32,
};

pub const msghdr_const = extern struct {
    /// optional address
    msg_name: ?*const sockaddr,

    /// size of address
    msg_namelen: socklen_t,

    /// scatter/gather array
    msg_iov: [*]iovec_const,

    /// # elements in msg_iov
    msg_iovlen: i32,

    /// ancillary data
    msg_control: ?*c_void,

    /// ancillary data buffer len
    msg_controllen: socklen_t,

    /// flags on received message
    msg_flags: i32,
};

pub const Stat = extern struct {
    dev: u64,
    ino: u64,
    nlink: usize,

    mode: u16,
    __pad0: u16,
    uid: u32,
    gid: u32,
    __pad1: u32,
    rdev: u64,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    birthtim: timespec,

    size: i64,
    blocks: i64,
    blksize: isize,
    flags: u32,
    gen: u64,
    __spare: [10]u64,
};

pub const timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};

pub const dirent = extern struct {
    d_fileno: usize,
    d_off: i64,
    d_reclen: u16,
    d_type: u8,
    d_pad0: u8,
    d_namlen: u16,
    d_pad1: u16,
    d_name: [256]u8,
};

pub const in_port_t = u16;
pub const sa_family_t = u16;

pub const sockaddr = extern union {
    in: sockaddr_in,
    in6: sockaddr_in6,
};

pub const sockaddr_in = extern struct {
    len: u8,
    family: sa_family_t,
    port: in_port_t,
    addr: [16]u8,
    zero: [8]u8,
};

pub const sockaddr_in6 = extern struct {
    len: u8,
    family: sa_family_t,
    port: in_port_t,
    flowinfo: u32,
    addr: [16]u8,
    scope_id: u32,
};
