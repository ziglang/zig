extern "c" fn __errno() *c_int;
pub const _errno = __errno;

pub extern "c" fn getdents(fd: c_int, buf_ptr: [*]u8, nbytes: usize) usize;
