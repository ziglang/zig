pub extern fn getrandom(buf_ptr: &u8, buf_len: usize, flags: c_uint) -> c_int;

extern fn __errno_location() -> &c_int;
pub const _errno = __errno_location;
