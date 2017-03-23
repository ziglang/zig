pub use @import("errno.zig");

pub use switch(@compileVar("os")) {
    Os.linux => @import("c/linux.zig"),
    Os.windows => @import("c/windows.zig"),
    Os.darwin, Os.macosx, Os.ios => @import("c/darwin.zig"),
    else => empty_import,
};

pub extern fn abort() -> unreachable;


const empty_import = @import("empty.zig");
