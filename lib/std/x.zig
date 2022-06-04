const std = @import("std.zig");

pub const os = struct {
    pub const Socket = @import("x/os/socket.zig").Socket;
    pub usingnamespace @import("x/os/io.zig");
    pub usingnamespace @import("x/os/net.zig");
};

pub const net = struct {
    pub const ip = @import("x/net/ip.zig");
    pub const tcp = @import("x/net/tcp.zig");
    pub const bpf = @import("x/net/bpf.zig");
};

test {
    if (@import("builtin").zig_backend != .stage1) return error.SkipZigTest;
    inline for (.{ os, net }) |module| {
        std.testing.refAllDecls(module);
    }
}
