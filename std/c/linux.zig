const linux = @import("../os/linux.zig");
pub use @import("../os/linux/errno.zig");

pub extern "c" fn getrandom(buf_ptr: [*]u8, buf_len: usize, flags: c_uint) c_int;
extern "c" fn __errno_location() *c_int;
pub const _errno = __errno_location;

pub const pthread_attr_t = extern struct {
    __size: [56]u8,
    __align: c_long,
};

/// See std.elf for constants for this
pub extern fn getauxval(__type: c_ulong) c_ulong;

pub const dl_iterate_phdr_callback = extern fn (info: *linux.dl_phdr_info, size: usize, data: ?*c_void) c_int;
pub extern fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*c_void) c_int;
