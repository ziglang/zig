pub const pthread_mutex_t = extern struct {
    inner: usize = ~@as(usize, 0),
};
pub const pthread_cond_t = extern struct {
    inner: usize = ~@as(usize, 0),
};
pub const pthread_rwlock_t = extern struct {
    ptr: usize = std.math.maxInt(usize),
};
