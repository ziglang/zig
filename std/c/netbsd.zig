const std = @import("../std.zig");
usingnamespace std.c;

extern "c" fn __errno() *c_int;
pub const _errno = __errno;

pub extern "c" fn getdents(fd: c_int, buf_ptr: [*]u8, nbytes: usize) usize;
pub extern "c" fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) c_int;
