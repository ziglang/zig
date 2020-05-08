const std = @import("../std.zig");
usingnamespace std.c;

extern "c" fn __errno() *c_int;
pub const _errno = __errno;

pub extern "c" fn arc4random_buf(buf: [*]u8, nbytes: usize) void;
pub extern "c" fn getdents(fd: c_int, buf_ptr: [*]u8, nbytes: usize) c_int;
pub extern "c" fn getpid() pid_t;

const dl_iterate_phdr_cb = fn (info: *dl_phdr_info, size: usize, data: ?*c_void) callconv(.C) c_int;
pub extern "c" fn dl_iterate_phdr(callback: dl_iterate_phdr_cb, data: ?*c_void) c_int;

// TODO
pub const pthread_mutex_t = extern struct {
    inner: ?*c_void = null,
};

// TODO
pub const pthread_cond_t = extern struct {
    inner: ?*c_void = null,
};

// TODO
pub const pthread_attr_t = extern struct {
    __size: [56]u8,
    __align: c_long,
};
