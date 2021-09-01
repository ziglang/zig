const std = @import("std");
const maxInt = std.math.maxInt;

pub const pthread_mutex_t = extern struct {
    inner: usize = ~@as(usize, 0),
};
pub const pthread_cond_t = extern struct {
    inner: usize = ~@as(usize, 0),
};
pub const pthread_rwlock_t = extern struct {
    ptr: usize = maxInt(usize),
};
pub const pthread_once_t = extern struct {
    state: c_int = 0,
    semaphore: ?*c_void = null,
    numSemaphoreUsers: c_int = 0,
    done: c_int = 0,  
};
