const linux = @import("linux.zig");
const errno = @import("errno.zig");

pub error SigInterrupt;
pub error Unexpected;

pub fn get_random_bytes(buf: []u8) -> %void {
    switch (@compileVar("os")) {
        linux => {
            const ret = linux.getrandom(buf.ptr, buf.len, 0);
            const err = linux.getErrno(ret);
            if (err > 0) {
                return switch (err) {
                    errno.EINVAL => unreachable{},
                    errno.EFAULT => unreachable{},
                    errno.EINTR  => error.SigInterrupt,
                    else         => error.Unexpected,
                }
            }
        },
        else => @compile_err("unsupported os"),
    }
}

#attribute("cold")
pub fn abort() -> unreachable {
    linux.raise(linux.SIGABRT);
    linux.raise(linux.SIGKILL);
    while (true) {}
}

