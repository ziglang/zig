// Platform-dependent types and values that are used along with OS-specific APIs.
// These are imported into `std.c`, `std.os`, and `std.os.linux`.

const builtin = @import("builtin");

pub usingnamespace switch (builtin.os) {
    .macosx, .ios, .tvos, .watchos => @import("bits/darwin.zig"),
    .freebsd => @import("bits/freebsd.zig"),
    .linux => @import("bits/linux.zig"),
    .netbsd => @import("bits/netbsd.zig"),
    .wasi => @import("bits/wasi.zig"),
    .windows => @import("bits/windows.zig"),
    else => struct {},
};

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
