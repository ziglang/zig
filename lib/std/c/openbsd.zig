pub extern "c" fn arc4random_buf(buf: [*]u8, nbytes: usize) void;

pub const pthread_mutex_t = extern struct {
    inner: ?*c_void = null,
};
pub const pthread_cond_t = extern struct {
    inner: ?*c_void = null,
};
