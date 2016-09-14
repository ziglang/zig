const system = switch(@compileVar("os")) {
    linux => @import("linux.zig"),
    darwin => @import("darwin.zig"),
    else => @compileError("Unsupported OS"),
};
const errno = @import("errno.zig");

pub error Unexpected;

pub fn getRandomBytes(buf: []u8) -> %void {
    while (true) {
        const ret = switch (@compileVar("os")) {
            linux => system.getrandom(buf.ptr, buf.len, 0),
            darwin => system.getrandom(buf.ptr, buf.len),
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
