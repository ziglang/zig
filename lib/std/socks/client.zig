const std = @import("../std.zig");
const socks = std.socks;

pub const ClientError = error{
    UnsupportedProtocol,
};

pub const ConnectError = ClientError || std.net.Stream.ReadError || std.net.Stream.WriteError || error{
    NetworkUnreachable,
};

/// Socks proxy client.
///
/// This client stores authentication information. `U` is the
/// userdata type for `authenticateFn`. `E` is the error returned from
/// `authenticateFn`.
///
/// This type is a wrapper of implementations from `std.socks`.
pub fn SocksClient(U: type, E: type) type {
    return struct {
        /// The authenticating routine.
        ///
        /// Return error to indicate a failed authentication.
        authenticateFn: *const fn (self: *const Client, stream: std.net.Stream, choice: u8) E!void,
        /// Supported authentications.
        ///
        /// For unauthenticated flow, includes `sockss.v5.KnownAuthentication.none`.
        supported_authenticates: []const u8,
        /// User data.
        udata: U,

        const Client = @This();

        /// Connect `host`:`port` through socks5 proxy `stream`.
        ///
        /// The `stream` is configured sending to the destination if this function
        /// returned successfully.
        ///
        /// If any error returned, the `stream` could not be reused.
        /// Possible errors: `ConnectError` and `E`.
        pub fn connect5(self: Client, stream: std.net.Stream, host: socks.v5.Address, port: u16) !void {
            const hello = socks.v5.ClientGreeting{
                .auth = self.supported_authenticates,
            };
            _ = try hello.serialize(stream.writer());

            const server_choice = try socks.v5.ServerChoice.deserialize(stream.reader());
            if (server_choice.ver != 5) {
                return ClientError.UnsupportedProtocol;
            }

            try self.authenticateFn(&self, stream, server_choice.cauth);

            const request = socks.v5.ConnectRequest{
                .cmd = @intFromEnum(socks.v5.ConnectRequest.KnownCommand.stream_connect),
                .dstaddr = host,
                .dstport = port,
            };

            _ = try request.serialize(stream.writer());

            const reply = try socks.v5.ConnectReply.deserialize(stream.reader());

            if (reply.ver != 5) {
                return ClientError.UnsupportedProtocol;
            }

            const reply_code = socks.v5.ConnectReply.KnownRep.from(reply.rep) orelse return ClientError.UnsupportedProtocol;
            switch (reply_code) {
                .success => {},
                .general_failure => return ConnectError.ConnectionResetByPeer,
                .ruleset_rejected => return ConnectError.ConnectionResetByPeer,
                .network_unreachable => return ConnectError.NetworkUnreachable,
                .host_unreachable => return ConnectError.NetworkUnreachable,
                .ttl_expired => return ConnectError.NetworkUnreachable,
                .address_not_supported => return ConnectError.UnsupportedProtocol,
                .command_not_supported => return ConnectError.UnsupportedProtocol,
                .connection_refused => return ConnectError.ConnectionResetByPeer,
            }
        }
    };
}
