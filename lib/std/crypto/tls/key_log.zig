//! Exporting tls key so we can share them with Wireshark and analyze decrypted
//! traffic in Wireshark.
//! To configure Wireshark to use exprted keys see curl reference.
//!
//! References:
//! curl: https://everything.curl.dev/usingcurl/tls/sslkeylogfile.html
//! openssl: https://www.openssl.org/docs/manmaster/man3/SSL_CTX_set_keylog_callback.html
//! https://udn.realityripple.com/docs/Mozilla/Projects/NSS/Key_Log_Format

const std = @import("std");

const key_log_file_env = "SSLKEYLOGFILE";

pub const label = struct {
    // tls 1.3
    pub const client_handshake_traffic_secret: []const u8 = "CLIENT_HANDSHAKE_TRAFFIC_SECRET";
    pub const server_handshake_traffic_secret: []const u8 = "SERVER_HANDSHAKE_TRAFFIC_SECRET";
    pub const client_traffic_secret_0: []const u8 = "CLIENT_TRAFFIC_SECRET_0";
    pub const server_traffic_secret_0: []const u8 = "SERVER_TRAFFIC_SECRET_0";
    // tls 1.2
    pub const client_random: []const u8 = "CLIENT_RANDOM";
};

pub const Callback = *const fn (label: []const u8, client_random: []const u8, secret: []const u8) void;

/// Writes tls keys to the file pointed by SSLKEYLOGFILE environment variable.
pub fn callback(label_: []const u8, client_random: []const u8, secret: []const u8) void {
    if (std.posix.getenv(key_log_file_env)) |file_name| {
        fileAppend(file_name, label_, client_random, secret) catch return;
    }
}

pub fn fileAppend(file_name: []const u8, label_: []const u8, client_random: []const u8, secret: []const u8) !void {
    var buf: [1024]u8 = undefined;
    const line = try formatLine(&buf, label_, client_random, secret);
    try fileWrite(file_name, line);
}

fn fileWrite(file_name: []const u8, line: []const u8) !void {
    var file = try std.fs.createFileAbsolute(file_name, .{ .truncate = false });
    defer file.close();
    const stat = try file.stat();
    try file.seekTo(stat.size);
    try file.writeAll(line);
}

pub fn formatLine(buf: []u8, label_: []const u8, client_random: []const u8, secret: []const u8) ![]const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    const w = fbs.writer();
    try w.print("{s} ", .{label_});
    for (client_random) |b| {
        try std.fmt.formatInt(b, 16, .lower, .{ .width = 2, .fill = '0' }, w);
    }
    try w.writeByte(' ');
    for (secret) |b| {
        try std.fmt.formatInt(b, 16, .lower, .{ .width = 2, .fill = '0' }, w);
    }
    try w.writeByte('\n');
    return fbs.getWritten();
}
