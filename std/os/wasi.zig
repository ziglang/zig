pub use @import("wasi/core.zig");

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

// TODO: implement this like darwin does
pub fn getErrno(r: usize) usize {
    const signed_r = @bitCast(isize, r);
    return if (signed_r > -4096 and signed_r < 0) @intCast(usize, -signed_r) else 0;
}

pub fn write(fd: i32, buf: [*]const u8, count: usize) usize {
    var nwritten: usize = undefined;

    const iovs = []ciovec_t{ciovec_t{
        .buf = buf,
        .buf_len = count,
    }};

    _ = fd_write(@bitCast(fd_t, isize(fd)), &iovs[0], iovs.len, &nwritten);
    return nwritten;
}
