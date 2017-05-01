pub use @import("../os/errno.zig");
const builtin = @import("builtin");
const Os = builtin.Os;

pub use switch(builtin.os) {
    Os.linux => @import("linux.zig"),
    Os.windows => @import("windows.zig"),
    Os.darwin, Os.macosx, Os.ios => @import("darwin.zig"),
    else => empty_import,
};

pub extern fn abort() -> noreturn;


const empty_import = @import("../empty.zig");
