const std = @import("std");
const mem = std.mem;

const proto = @import("tls/protocol.zig");
const common = @import("tls/handshake_common.zig");

const record = @import("tls/record.zig");
const connection = @import("tls/connection.zig").connection;
pub const max_ciphertext_record_len = @import("tls/cipher.zig").max_ciphertext_record_len;
const HandshakeServer = @import("tls/handshake_server.zig").Handshake;
const HandshakeClient = @import("tls/handshake_client.zig").Handshake;
pub const Connection = @import("tls/connection.zig").Connection;

pub fn client(stream: anytype, opt: config.Client) !Connection(@TypeOf(stream)) {
    const Stream = @TypeOf(stream);
    var conn = connection(stream);
    var write_buf: [max_ciphertext_record_len]u8 = undefined;
    var h = HandshakeClient(Stream).init(&write_buf, &conn.rec_rdr);
    conn.cipher = try h.handshake(conn.stream, opt);
    return conn;
}

pub fn server(stream: anytype, opt: config.Server) !Connection(@TypeOf(stream)) {
    const Stream = @TypeOf(stream);
    var conn = connection(stream);
    var write_buf: [max_ciphertext_record_len]u8 = undefined;
    var h = HandshakeServer(Stream).init(&write_buf, &conn.rec_rdr);
    conn.cipher = try h.handshake(conn.stream, opt);
    return conn;
}

pub const config = struct {
    pub const CipherSuite = @import("tls/cipher.zig").CipherSuite;
    pub const PrivateKey = @import("tls/PrivateKey.zig");
    pub const NamedGroup = proto.NamedGroup;
    pub const Version = proto.Version;
    pub const CertBundle = common.CertBundle;
    pub const CertKeyPair = common.CertKeyPair;

    pub const cipher_suites = @import("tls/cipher.zig").cipher_suites;
    pub const key_log = @import("tls/key_log.zig");

    pub const Client = @import("tls/handshake_client.zig").Options;
    pub const Server = @import("tls/handshake_server.zig").Options;
};

test {
    _ = @import("tls/handshake_common.zig");
    _ = @import("tls/handshake_server.zig");
    _ = @import("tls/handshake_client.zig");

    _ = @import("tls/connection.zig");
    _ = @import("tls/cipher.zig");
    _ = @import("tls/record.zig");
    _ = @import("tls/transcript.zig");
    _ = @import("tls/PrivateKey.zig");
}

pub fn hkdfExpandLabel(
    comptime Hkdf: type,
    key: [Hkdf.prk_length]u8,
    label: []const u8,
    context: []const u8,
    comptime len: usize,
) [len]u8 {
    const max_label_len = 255;
    const max_context_len = 255;
    const tls13 = "tls13 ";
    var buf: [2 + 1 + tls13.len + max_label_len + 1 + max_context_len]u8 = undefined;
    mem.writeInt(u16, buf[0..2], len, .big);
    buf[2] = @as(u8, @intCast(tls13.len + label.len));
    buf[3..][0..tls13.len].* = tls13.*;
    var i: usize = 3 + tls13.len;
    @memcpy(buf[i..][0..label.len], label);
    i += label.len;
    buf[i] = @as(u8, @intCast(context.len));
    i += 1;
    @memcpy(buf[i..][0..context.len], context);
    i += context.len;

    var result: [len]u8 = undefined;
    Hkdf.expand(&result, buf[0..i], key);
    return result;
}

pub fn emptyHash(comptime Hash: type) [Hash.digest_length]u8 {
    var result: [Hash.digest_length]u8 = undefined;
    Hash.hash(&.{}, &result, .{});
    return result;
}
