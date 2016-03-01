const linux = @import("linux.zig");
const errno = @import("errno.zig");

pub error SigInterrupt;
pub error Unexpected;

pub fn get_random_bytes(buf: []u8) -> %void {
    switch (@compile_var("os")) {
        linux => {
            const amt_got = linux.getrandom(buf.ptr, buf.len, 0);
            if (amt_got < 0) {
                return switch (-amt_got) {
                    errno.EINVAL => unreachable{},
                    errno.EFAULT => unreachable{},
                    errno.EINTR  => error.SigInterrupt,
                    else         => error.Unexpected,
                }
            }
        },
        windows => {
            // TODO
            for (buf) |_, i| {
                buf[i] = 4;
            }
        },
        else => unreachable{},
    }
}
