extern "c" fn __error() *c_int;
pub const _errno = __error;

pub extern "c" fn getdents(fd: c_int, buf_ptr: [*]u8, nbytes: usize) usize;
