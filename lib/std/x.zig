pub const os = struct {
    pub const Socket = @import("x/os/Socket.zig");
    pub usingnamespace @import("x/os/net.zig");
};

pub const net = struct {
    pub const TCP = @import("x/net/TCP.zig");
};
