pub use @import("wasi/core.zig");

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub fn getErrno(r: usize) usize {
    const signed_r = @bitCast(isize, r);
    return if (signed_r > -4096 and signed_r < 0) @intCast(usize, -signed_r) else 0;
}

pub fn write(fd: i32, buf: [*]const u8, count: usize) usize {
    var nwritten: usize = undefined;

    const ciovs = ciovec_t{
        .buf = buf,
        .buf_len = count,
    };

    const err = fd_write(@bitCast(fd_t, isize(fd)), &ciovs, 1, &nwritten);
    if (err == ESUCCESS) {
        return nwritten;
    } else {
        return @bitCast(usize, -isize(err));
    }
}

pub fn read(fd: i32, buf: [*]u8, nbyte: usize) usize {
    var nread: usize = undefined;

    const iovs = iovec_t{
        .buf = buf,
        .buf_len = nbyte,
    };

    const err = fd_read(@bitCast(fd_t, isize(fd)), &iovs, 1, &nread);
    if (err == ESUCCESS) {
        return nread;
    } else {
        return @bitCast(usize, -isize(err));
    }
}
