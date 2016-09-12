const system = switch(@compileVar("os")) {
    linux => @import("linux.zig"),
    darwin => @import("darwin.zig"),
    else => @compileError("Unsupported OS"),
};
const errno = @import("errno.zig");

pub error SigInterrupt;
pub error Unexpected;

pub fn getRandomBytes(buf: []u8) -> %void {
    switch (@compileVar("os")) {
        linux => {
            const ret = system.getrandom(buf.ptr, buf.len, 0);
            const err = system.getErrno(ret);
            if (err > 0) {
                return switch (err) {
                    errno.EINVAL => unreachable{},
                    errno.EFAULT => unreachable{},
                    errno.EINTR  => error.SigInterrupt,
                    else         => error.Unexpected,
                }
            }
        },
        darwin => {
            const ret = system.getrandom(buf.ptr, buf.len);
            const err = system.getErrno(ret);
            if(err > 0) {
                return switch(err) {
                    errno.EINVAL => unreachable{},
                    errno.EFAULT => unreachable{},
                    errno.EINTR  => error.SigInterrupt,
                    else => error.Unexpected,
                }
            }
        },
        else => @compileError("unsupported os"),
    }
}

#attribute("cold")
pub fn abort() -> unreachable {
    switch (@compileVar("os")) {
        linux, darwin => {
            system.raise(system.SIGABRT);
            system.raise(system.SIGKILL);
            while (true) {}
        },
        else => @compileError("unsupported os"),
    }
}
