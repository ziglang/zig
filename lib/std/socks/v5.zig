//! SOCKS5 implementation (RFC1928).
//!
//! Getting started with the basic messages:
//! - `ClientGreeting` - the first message with client's supported authentication methods
//! - `ServerChoice` - the second message with server's choice of the authentication methods
//! - `ConnectRequest` - the RPC message to request specific feature
//! - `ConnectReply` - the RPC reply
const std = @import("../std.zig");

pub const password = @import("./v5/flow_password.zig");

pub const KnownAuthentication = enum(u8) {
    none = 0,
    gssapi = 1,
    password = 2,
    challenge_handshake = 3,
    challenge_response = 4,
    secure_socket_layer = 6,
    nds_auth = 7,
    multi_auth_framework = 8,
    json_parameter_block = 9,

    unavailable = 0xff,

    pub fn from(value: u8) ?KnownAuthentication {
        return switch (std.meta.intToEnum(KnownAuthentication, value)) {
            .unavailable => return null,
            else => |x| x,
        } catch return null;
    }
};

pub const ClientGreeting = struct {
    ver: u8 = 5,
    auth: []const u8,

    /// The biggest size for `auth`.
    pub const MAX_AUTH_SIZE = 255;

    /// Receive the whole message.
    ///
    /// If the `ClientGreeting.ver` is not `5`, no auth method will be read.
    ///
    /// You can provide a `auth_buf` that is smaller than `MAX_AUTH_SIZE`.
    /// The other methods will be dropped if the `auth_buf` is full.
    pub fn deserialize(auth_buf: []u8, reader: anytype) !ClientGreeting {
        const verOnly = try ClientGreeting.deserializeVer(reader);

        return try verOnly.deserializeAuth(auth_buf, reader);
    }

    pub fn deserializeVer(reader: anytype) !ClientGreeting {
        const ver = try reader.readByte();

        return .{ .ver = ver, .auth = &.{} };
    }

    /// Receive the authentication methods.
    ///
    /// You can provide a `src` that is smaller than `MAX_AUTH_SIZE`.
    /// The other methods will be dropped if the `src` is full.
    pub fn deserializeAuth(self: ClientGreeting, src: []u8, reader: anytype) !ClientGreeting {
        if (self.ver != 5) {
            return self;
        }

        const authSize = try reader.readByte();

        const readSize = @min(authSize, src.len);
        const skipSize = authSize - src.len;

        const auth = try reader.read(src[0..readSize]);
        try reader.skipBytes(skipSize);

        return .{
            .ver = self.ver,
            .auth = auth,
        };
    }

    pub const PickAuthError = error{NoMatchedAuthMethod};

    pub const DeserializeAndPickAuthError = error{UnknownVersion} || PickAuthError;

    /// Receive the message and pick one auth method. Return
    /// the picked method.
    ///
    /// If no method is picked, return `PickAuthError.NoMatchedAuthMethod`.
    pub fn deserializeAndPickAuth(reader: anytype, supported_methods: []const u8) !u8 {
        const verOnly = try ClientGreeting.deserializeVer(reader);

        if (verOnly.ver != 5) {
            return DeserializeAndPickAuthError.UnknownVersion;
        }

        var currentIdx: ?usize = null;

        var restAuthLen = try reader.readByte();

        while (restAuthLen > 0) : (restAuthLen -= 1) {
            const auth = try reader.readByte();
            if (std.mem.indexOfScalar(u8, supported_methods, auth)) |idx| {
                if (currentIdx) |cmpIdx| {
                    if (idx < cmpIdx) {
                        currentIdx = idx;
                    }
                } else {
                    currentIdx = idx;
                }
            }
        }

        const tableIdx = currentIdx orelse return PickAuthError.NoMatchedAuthMethod;

        return supported_methods[tableIdx];
    }

    /// Write the message into the `writer`.
    ///
    /// The `ClientGreeting.auth` length must be <= `MAX_AUTH_SIZE`, or a undefined
    /// behaviour will be triggered.
    pub fn serialize(self: ClientGreeting, writer: anytype) !usize {
        const authlen: u8 = @intCast(self.auth.len);

        var wsize: usize = 0;
        wsize += try writer.write(&.{ self.ver, authlen });
        wsize += try writer.write(self.auth);

        return wsize;
    }
};

pub const ServerChoice = struct {
    ver: u8,
    cauth: u8,

    /// Receive the server's authentication choice.
    ///
    /// The `ServerChoice.ver` may not be `5`. The other fields
    /// are undefined in this situtation.
    pub fn deserialize(reader: anytype) !ServerChoice {
        const ver = try reader.readByte();
        if (ver != 5) {
            return .{
                .ver = ver,
                .cauth = 0xff,
            };
        }

        const choice = try reader.readByte();
        return .{
            .ver = ver,
            .cauth = choice,
        };
    }
};

pub const AddressType = enum(u8) {
    ipv4 = 1,
    domain = 3,
    ipv6 = 4,
};

pub const Address = union(AddressType) {
    ipv4: [4]u8,
    domain: std.BoundedArray(u8, 255),
    ipv6: [16]u8,

    pub fn constSlice(self: *const Address) []const u8 {
        return switch (self.*) {
            .ipv4 => |*p| p,
            .ipv6 => |*p| p,
            .domain => |*arr| arr.constSlice(),
        };
    }

    pub fn serialize(self: Address, writer: anytype) !usize {
        var wsize: usize = 0;
        wsize += try writer.write(&.{@intFromEnum(self)});
        switch (self) {
            .domain => |arr| {
                wsize += try writer.write(&.{@intCast(arr.len)});
            },
            else => {},
        }
        wsize += try writer.write(self.constSlice());

        return wsize;
    }

    pub const ReceiveError = error{UnknownAddressType};

    pub fn deserialize(reader: anytype) !Address {
        const typ = std.meta.intToEnum(AddressType, try reader.readByte()) catch return ReceiveError.UnknownAddressType;

        switch (typ) {
            .ipv4 => {
                const bin = try reader.readBytesNoEof(4);
                return .{ .ipv4 = bin };
            },
            .ipv6 => {
                const bin = try reader.readBytesNoEof(16);
                return .{ .ipv6 = bin };
            },
            .domain => {
                const sz = try reader.readByte();
                var result = Address{ .domain = .{} };
                try reader.readNoEof(result.domain.unusedCapacitySlice()[0..sz]);
                result.domain.len = sz;
                return result;
            },
        }
    }

    pub fn fromIp4Address(addr: std.net.Ip4Address) Address {
        return .{
            .ipv4 = std.mem.toBytes(addr.sa.addr),
        };
    }

    pub fn fromIp6Address(addr: std.net.Ip6Address) Address {
        return .{
            .ipv6 = addr.sa.addr,
        };
    }

    /// Create address with the `domain` as the .domain.
    ///
    /// The `domain.len` must be <= 255, or the undefined behaviour will be triggered.
    pub fn domainFromSlice(domain: []const u8) Address {
        var result = Address{
            .domain = .{},
        };
        result.domain.appendSliceAssumeCapacity(domain);
        return result;
    }

    /// Create address from a buffer, auto detect its type.
    ///
    /// The `domainOrIp.len` must be <= 255, or the undefined behaviour will be
    /// triggered.
    pub fn fromSlice(domainOrIp: []const u8) Address {
        std.debug.assert(domainOrIp.len <= 255);

        if (std.net.Ip6Address.parse(domainOrIp, 0)) |ip6| {
            return fromIp6Address(ip6);
        } else |_| {}

        if (std.net.Ip4Address.parse(domainOrIp, 0)) |ip4| {
            return fromIp4Address(ip4);
        } else |_| {}

        return domainFromSlice(domainOrIp);
    }
};

pub const ConnectRequest = struct {
    ver: u8 = 5,
    cmd: u8,
    rsv: u8 = 0,
    dstaddr: Address,
    dstport: u16,

    pub const KnownCommand = enum(u8) {
        stream_connect = 1,
        stream_bind = 2,
        dgram_assoc = 3,

        pub fn from(code: u8) ?KnownCommand {
            return std.meta.intToEnum(KnownCommand, code) catch null;
        }
    };

    pub fn serialize(self: ConnectRequest, writer: anytype) !usize {
        var wsize: usize = 0;
        wsize += try writer.write(&.{ self.ver, self.cmd, self.rsv });
        wsize += try self.dstaddr.serialize(writer);
        try writer.writeInt(u16, self.dstport, .big);
        wsize += 2;
        return wsize;
    }
};

pub const ConnectReply = struct {
    ver: u8 = 5,
    rep: u8,
    rsv: u8 = 0,
    bind: Address,
    bind_port: u16,

    pub const KnownRep = enum(u8) {
        success = 0,
        general_failure = 1,
        ruleset_rejected = 2,
        network_unreachable = 3,
        host_unreachable = 4,
        connection_refused = 5,
        ttl_expired = 6,
        command_not_supported = 7,
        address_not_supported = 8,

        pub fn from(code: u8) ?KnownRep {
            return std.meta.intToEnum(KnownRep, code) catch null;
        }
    };

    pub fn deserializeVerOnly(reader: anytype) !ConnectReply {
        const ver = try reader.readByte();
        return .{
            .ver = ver,
            .rep = 0xff,
            .bind = .{ .domain = .{} },
            .bind_port = 0,
        };
    }

    /// Receive the reply message.
    ///
    /// The result `ConnectReply.ver` may not be `5`. In this situtation,
    /// the other fields' are undefined.
    pub fn deserialize(reader: anytype) !ConnectReply {
        var result = try ConnectReply.deserializeVerOnly(reader);
        if (result.ver != 5) {
            return result;
        }

        result.rep = try reader.readByte();
        result.rsv = try reader.readByte();
        result.bind = try Address.deserialize(reader);
        result.bind_port = try reader.readInt(u16, .big);

        return result;
    }
};
