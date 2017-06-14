pub extern "c" fn getrandom(buf_ptr: &u8, buf_len: usize) -> c_int;
fn extern "c" __error() -> &c_int;

pub const _errno = __error;
