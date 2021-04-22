const std = @import("../../std.zig");

const testing = std.testing;

pub const Socket = @import("Socket.zig");

test {
    testing.refAllDecls(@This());
}
