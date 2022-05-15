const std = @import("std.zig");

pub const Method = @import("http/method.zig").Method;
pub const Status = @import("http/status.zig").Status;

test {
    std.testing.refAllDecls(@This());
}
