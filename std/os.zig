const system = switch(@compileVar("os")) {
    Os.linux => @import("linux.zig"),
    Os.darwin => @import("darwin.zig"),
    else => @compileError("Unsupported OS"),
};
const errno = @import("errno.zig");

error Unexpected;

pub fn getRandomBytes(buf: []u8) -> %void {
    while (true) {
        const ret = switch (@compileVar("os")) {
            Os.linux => system.getrandom(buf.ptr, buf.len, 0),
            Os.darwin => system.getrandom(buf.ptr, buf.len),
            else => @compileError("unsupported os"),
        };
        const err = system.getErrno(ret);
        if (err > 0) {
            return switch (err) {
                errno.EINVAL => @unreachable(),
                errno.EFAULT => @unreachable(),
                errno.EINTR  => continue,
                else         => error.Unexpected,
            }
        }
        return;
    }
}

pub coldcc fn abort() -> unreachable {
    switch (@compileVar("os")) {
        Os.linux, Os.darwin => {
            _ = system.raise(system.SIGABRT);
            _ = system.raise(system.SIGKILL);
            while (true) {}
        },
        else => @compileError("unsupported os"),
    }
}
