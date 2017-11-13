const std = @import("std");
const net = std.net;

pub const NetworkEvent = struct {
    os: event_os.NetworkEvent,

    const Self = this;

    pub fn init() -> %Self {

    }
};

pub const StreamListener = struct {
    os: event_os.StreamListener,

    const Self = this;

    pub fn init_tcp(hostname: []const u8, port: u16) -> %Self {
    }
};
