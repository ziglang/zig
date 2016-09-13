const linux = @import("linux.zig");
const errno = @import("errno.zig");

pub error SigInterrupt;
pub error Unexpected;

pub fn getRandomBytes(buf: []u8) -> %void {
    switch (@compileVar("os")) {
        linux => {
            const ret = linux.getrandom(buf.ptr, buf.len, 0);
            const err = linux.getErrno(ret);
            if (err > 0) {
                return switch (err) {
                    errno.EINVAL => @unreachable(),
                    errno.EFAULT => @unreachable(),
                    errno.EINTR  => error.SigInterrupt,
                    else         => error.Unexpected,
                }
            }
        },
        else => @compileError("unsupported os"),
    }
}

#attribute("cold")
pub fn abort() -> unreachable {
    switch (@compileVar("os")) {
        linux => {
            linux.raise(linux.SIGABRT);
            linux.raise(linux.SIGKILL);
            while (true) {}
        },
        else => @compileError("unsupported os"),
    }
}
