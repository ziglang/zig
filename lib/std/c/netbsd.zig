const std = @import("../std.zig");
usingnamespace std.c;

extern "c" fn __errno() *c_int;
pub const _errno = __errno;

pub extern "c" fn getdents(fd: c_int, buf_ptr: [*]u8, nbytes: usize) usize;
pub extern "c" fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) c_int;

pub const pthread_mutex_t = extern struct {
    ptm_magic: c_uint = 0x33330003,
    ptm_errorcheck: padded_spin_t = 0,
    ptm_unused: padded_spin_t = 0,
    ptm_owner: usize = 0,
    ptm_waiters: ?*u8 = null,
    ptm_recursed: c_uint = 0,
    ptm_spare2: ?*c_void = null,
};
pub const pthread_cond_t = extern struct {
    ptc_magic: c_uint = 0x55550005,
    ptc_lock: pthread_spin_t = 0,
    ptc_waiters_first: ?*u8 = null,
    ptc_waiters_last: ?*u8 = null,
    ptc_mutex: ?*pthread_mutex_t = null,
    ptc_private: ?*c_void = null,
};
const pthread_spin_t = if (builtin.arch == .arm or .arch == .powerpc) c_int else u8;
const padded_spin_t = switch (builtin.arch) {
    .sparc, .sparcel, .sparcv9, .i386, .x86_64, .le64 => u32,
    else => spin_t,
};

pub const pthread_attr_t = extern struct {
    pta_magic: u32,
    pta_flags: c_int,
    pta_private: *c_void,
};
