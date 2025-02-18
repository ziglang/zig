//! The SOCKS proxy protocol implementation
pub const v5 = @import("./socks/v5.zig");

pub const Client = @import("./socks/client.zig").SocksClient;
pub const ConnectError = @import("./socks/client.zig").ConnectError;
pub const ClientError = @import("./socks/client.zig").ClientError;
