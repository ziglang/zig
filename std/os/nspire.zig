pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub use @import("linux/errno.zig");
const c = @import("../c.zig");

pub fn getErrno(r: usize) usize {
    const signed_r = @bitCast(isize, r);
    return if (signed_r > -4096 and signed_r < 0) @intCast(usize, -signed_r) else 0;
}

pub fn write(fd: i32, buf: [*]const u8, count: usize) usize {
    return @intCast(usize, c.write(fd, buf, count));
}

pub fn read(fd: i32, buf: *c_void, count: usize) usize {
    return @intCast(usize, c.read(fd, buf, count));
}

