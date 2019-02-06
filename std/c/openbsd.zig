extern "c" fn __errno() *c_int;
pub const _errno = __errno;

//pub extern "c" fn kqueue() c_int;
//pub extern "c" fn kevent(
//    kq: c_int,
//    changelist: [*]const Kevent,
//    nchanges: c_int,
//    eventlist: [*]Kevent,
//    nevents: c_int,
//    timeout: ?*const timespec,
//) c_int;
//pub extern "c" fn sysctl(name: [*]const c_int, namelen: c_uint, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) c_int;
//pub extern "c" fn getdirentries(fd: c_int, buf_ptr: [*]u8, nbytes: usize, basep: *i64) usize;
//pub extern "c" fn getdents(fd: c_int, buf_ptr: ?*c_void, nbytes: usize) c_int;

pub extern "c" fn arc4random_buf(buf: [*]u8, nbytes: usize) void;
