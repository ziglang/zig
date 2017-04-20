pub extern fn getrandom(buf_ptr: &u8, buf_len: usize) -> c_int;

extern fn __error() -> &c_int;
pub const _errno = __error;
