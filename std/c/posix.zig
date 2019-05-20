// Declarations that are intended to be imported into the POSIX namespace.

const builtin = @import("builtin");

pub use switch (builtin.os) {
    .windows => @import("posix/windows.zig"),
    .macosx, .ios, .tvos, .watchos => @import("posix/darwin.zig"),
    .freebsd => @import("posix/freebsd.zig"),
    .netbsd => @import("posix/netbsd.zig"),
    else => struct {},
};

pub const fd_t = c_int;
pub const pid_t = c_int;
pub const pthread_t = *@OpaqueType();
pub const FILE = @OpaqueType();

pub const iovec = extern struct {
    iov_base: [*]u8,
    iov_len: usize,
};

pub const iovec_const = extern struct {
    iov_base: [*]const u8,
    iov_len: usize,
};
