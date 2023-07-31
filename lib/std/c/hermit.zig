const std = @import("std");
const maxInt = std.math.maxInt;

// pub const _SC = struct {
//     pub const PAGESIZE = TODO;
// };

pub const pthread_mutex_t = extern struct {
    inner: usize = ~@as(usize, 0),
};
pub const pthread_cond_t = extern struct {
    inner: usize = ~@as(usize, 0),
};
pub const pthread_rwlock_t = extern struct {
    ptr: usize = maxInt(usize),
};
