const std = @import("../std.zig");
use std.c;

pub extern "c" fn getrandom(buf_ptr: [*]u8, buf_len: usize, flags: c_uint) c_int;
pub extern "c" fn sched_getaffinity(pid: c_int, size: usize, set: *cpu_set_t) c_int;
extern "c" fn __errno_location() *c_int;
pub const _errno = __errno_location;

/// See std.elf for constants for this
pub extern fn getauxval(__type: c_ulong) c_ulong;

pub const dl_iterate_phdr_callback = extern fn (info: *dl_phdr_info, size: usize, data: ?*c_void) c_int;
pub extern fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*c_void) c_int;
