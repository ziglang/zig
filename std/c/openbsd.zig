pub use @import("../os/openbsd_errno.zig");

pub extern "c" fn getentropy(buf_ptr: &u8, buf_len: usize) -> c_int;
extern "c" fn __errno() -> &c_int;
pub const _errno = __errno;
