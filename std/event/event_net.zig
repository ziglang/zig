//const builtin = @import("builtin");
//const std = @import("std");
//const net = std.net;
//
//use @import("event_common.zig");
//
//const event_os = switch (builtin.os) {
//    builtin.Os.linux => @import("event_linux.zig"),
//    else => @compileError("unsupported event os"),
//};
//
//pub const NetworkEvent = struct {
//    os: event_os.NetworkEvent,
//
//    const Self = this;
//
//    pub fn init() -> %Self {
//
//    }
//};
//
//pub const StreamListener = struct {
//    os: event_os.StreamListener,
//
//    const Self = this;
//
//    pub fn init(context: var, comptime read_context_type: type,
//            conn_handler: &const fn(@typeOf(context)) -> read_context_type,
//            read_handler: &const fn(&const []u8, &read_context_type) -> void) -> Self {
//        Self {
//            .os = event_os.StreamListener.init(
//                @ptrToInt(context),
//                @ptrToInt(conn_handler),
//                @ptrToInt(read_handler))
//        }
//    }
//
//    pub fn listen_tcp(listener: &Self, hostname: []const u8, port: u16) -> %void {
//        listener.os.listen_tcp(hostname, port)
//    }
//
//    pub fn register(listener: &Self, loop: &Loop) -> void {
//
//    }
//};
