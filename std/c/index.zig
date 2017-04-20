pub use @import("../os/errno.zig");

pub use switch(@compileVar("os")) {
    Os.linux => @import("linux.zig"),
    Os.windows => @import("windows.zig"),
    Os.darwin, Os.macosx, Os.ios => @import("darwin.zig"),
    else => empty_import,
};

pub extern fn abort() -> noreturn;


const empty_import = @import("../empty.zig");
