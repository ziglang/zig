const std = @import("../../std.zig");

pub const spin = @import("./spin.zig");

pub const event = @import("./event.zig");

pub const os = if (std.builtin.os.tag == .windows)
    @import("./windows.zig")
else if (std.builtin.os.tag == .linux)
    @import("./linux.zig")
else if (std.Target.current.isDarwin())
    @import("./darwin.zig")
else if (std.builtin.link_libc)
    @import("./posix.zig")
else
    spin;