extern "c" fn __errno() *c_int;
pub const _errno = __errno;

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
    filter: i32,
    flags: u32,
    fflags: u32,
    data: i64,
    udata: usize,
};

pub const pthread_attr_t = extern struct {
    pta_magic: u32,
    pta_flags: c_int,
    pta_private: *c_void,
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
    mode: u32,
    ino: u64,
    nlink: usize,

    uid: u32,
    gid: u32,
    rdev: u64,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    birthtim: timespec,

    size: i64,
    blocks: i64,
    blksize: isize,
    flags: u32,
    gen: u32,
    __spare: [2]u32,
};

pub const timespec = extern struct {
    tv_sec: i64,
    tv_nsec: isize,
};

pub const dirent = extern struct {
    d_fileno: u64,
    d_reclen: u16,
    d_namlen: u16,
    d_type: u8,
    d_off: i64,
    d_name: [512]u8,
};

pub const in_port_t = u16;
pub const sa_family_t = u8;

pub const sockaddr = extern union {
    in: sockaddr_in,
    in6: sockaddr_in6,
};

pub const sockaddr_in = extern struct {
    len: u8,
    family: sa_family_t,
    port: in_port_t,
    addr: u32,
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
