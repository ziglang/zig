//! TODO: send connection: keep-alive and LRU cache a configurable number of
//! open connections to skip DNS and TLS handshake for subsequent requests.
//!
//! This API is *not* thread safe.

const std = @import("../std.zig");
const mem = std.mem;
const assert = std.debug.assert;
const http = std.http;
const net = std.net;
const Client = @This();
const Uri = std.Uri;
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub const Request = @import("Client/Request.zig");
pub const Response = @import("Client/Response.zig");

/// Used for tcpConnectToHost and storing HTTP headers when an externally
/// managed buffer is not provided.
allocator: Allocator,
ca_bundle: std.crypto.Certificate.Bundle = .{},
/// When this is `true`, the next time this client performs an HTTPS request,
/// it will first rescan the system for root certificates.
next_https_rescan_certs: bool = true,

connection_mutex: std.Thread.Mutex = .{},
connection_pool: ConnectionPool = .{},
connection_used: ConnectionPool = .{},

pub const ConnectionPool = std.TailQueue(Connection);
pub const ConnectionNode = ConnectionPool.Node;

/// Acquires an existing connection from the connection pool. This function is threadsafe.
/// If the caller already holds the connection mutex, it should pass `true` for `held`.
pub fn acquire(client: *Client, node: *ConnectionNode, held: bool) void {
    if (!held) client.connection_mutex.lock();
    defer if (!held) client.connection_mutex.unlock();

    client.connection_pool.remove(node);
    client.connection_used.append(node);
}

/// Tries to release a connection back to the connection pool. This function is threadsafe.
/// If the connection is marked as closing, it will be closed instead.
pub fn release(client: *Client, node: *ConnectionNode) void {
    client.connection_mutex.lock();
    defer client.connection_mutex.unlock();

    client.connection_used.remove(node);

    if (node.data.closing) {
        node.data.close(client);

        return client.allocator.destroy(node);
    }

    client.connection_pool.append(node);
}

pub const DeflateDecompressor = std.compress.zlib.ZlibStream(Request.ReaderRaw);
pub const GzipDecompressor = std.compress.gzip.Decompress(Request.ReaderRaw);
pub const ZstdDecompressor = std.compress.zstd.DecompressStream(Request.ReaderRaw, .{});

pub const Connection = struct {
    stream: net.Stream,
    /// undefined unless protocol is tls.
    tls_client: *std.crypto.tls.Client, // TODO: allocate this, it's currently 16 KB.
    protocol: Protocol,
    host: []u8,
    port: u16,

    // This connection has been part of a non keepalive request and cannot be added to the pool.
    closing: bool = false,

    pub const Protocol = enum { plain, tls };

    pub fn read(conn: *Connection, buffer: []u8) !usize {
        switch (conn.protocol) {
            .plain => return conn.stream.read(buffer),
            .tls => return conn.tls_client.read(conn.stream, buffer),
        }
    }

    pub fn readAtLeast(conn: *Connection, buffer: []u8, len: usize) !usize {
        switch (conn.protocol) {
            .plain => return conn.stream.readAtLeast(buffer, len),
            .tls => return conn.tls_client.readAtLeast(conn.stream, buffer, len),
        }
    }

    pub const ReadError = net.Stream.ReadError || error{
        TlsConnectionTruncated,
        TlsRecordOverflow,
        TlsDecodeError,
        TlsAlert,
        TlsBadRecordMac,
        Overflow,
        TlsBadLength,
        TlsIllegalParameter,
        TlsUnexpectedMessage,
    };

    pub const Reader = std.io.Reader(*Connection, ReadError, read);

    pub fn reader(conn: *Connection) Reader {
        return Reader{ .context = conn };
    }

    pub fn writeAll(conn: *Connection, buffer: []const u8) !void {
        switch (conn.protocol) {
            .plain => return conn.stream.writeAll(buffer),
            .tls => return conn.tls_client.writeAll(conn.stream, buffer),
        }
    }

    pub fn write(conn: *Connection, buffer: []const u8) !usize {
        switch (conn.protocol) {
            .plain => return conn.stream.write(buffer),
            .tls => return conn.tls_client.write(conn.stream, buffer),
        }
    }

    pub const WriteError = net.Stream.WriteError || error{};
    pub const Writer = std.io.Writer(*Connection, WriteError, write);

    pub fn writer(conn: *Connection) Writer {
        return Writer{ .context = conn };
    }

    pub fn close(conn: *Connection, client: *const Client) void {
        if (conn.protocol == .tls) {
            // try to cleanly close the TLS connection, for any server that cares.
            _ = conn.tls_client.writeEnd(conn.stream, "", true) catch {};
            client.allocator.destroy(conn.tls_client);
        }

        conn.stream.close();

        client.allocator.free(conn.host);
    }
};

pub fn deinit(client: *Client) void {
    client.connection_mutex.lock();

    var next = client.connection_pool.first;
    while (next) |node| {
        next = node.next;

        node.data.close(client);

        client.allocator.destroy(node);
    }

    next = client.connection_used.first;
    while (next) |node| {
        next = node.next;

        node.data.close(client);

        client.allocator.destroy(node);
    }

    client.ca_bundle.deinit(client.allocator);
    client.* = undefined;
}

pub const ConnectError = std.mem.Allocator.Error || net.TcpConnectToHostError || std.crypto.tls.Client.InitError(net.Stream);

pub fn connect(client: *Client, host: []const u8, port: u16, protocol: Connection.Protocol) ConnectError!*ConnectionNode {
    { // Search through the connection pool for a potential connection.
        client.connection_mutex.lock();
        defer client.connection_mutex.unlock();

        var potential = client.connection_pool.last;
        while (potential) |node| {
            const same_host = mem.eql(u8, node.data.host, host);
            const same_port = node.data.port == port;
            const same_protocol = node.data.protocol == protocol;

            if (same_host and same_port and same_protocol) {
                client.acquire(node, true);
                return node;
            }

            potential = node.prev;
        }
    }

    const conn = try client.allocator.create(ConnectionNode);
    errdefer client.allocator.destroy(conn);

    conn.* = .{ .data = .{
        .stream = try net.tcpConnectToHost(client.allocator, host, port),
        .tls_client = undefined,
        .protocol = protocol,
        .host = try client.allocator.dupe(u8, host),
        .port = port,
    } };

    switch (protocol) {
        .plain => {},
        .tls => {
            conn.data.tls_client = try client.allocator.create(std.crypto.tls.Client);
            conn.data.tls_client.* = try std.crypto.tls.Client.init(conn.data.stream, client.ca_bundle, host);
            // This is appropriate for HTTPS because the HTTP headers contain
            // the content length which is used to detect truncation attacks.
            conn.data.tls_client.allow_truncation_attacks = true;
        },
    }

    {
        client.connection_mutex.lock();
        defer client.connection_mutex.unlock();

        client.connection_used.append(conn);
    }

    return conn;
}

pub const RequestError = ConnectError || Connection.WriteError || error{
    UnsupportedUrlScheme,
    UriMissingHost,

    CertificateAuthorityBundleTooBig,
    InvalidPadding,
    MissingEndCertificateMarker,
    Unseekable,
    EndOfStream,
};

pub fn request(client: *Client, uri: Uri, headers: Request.Headers, options: Request.Options) RequestError!Request {
    const protocol: Connection.Protocol = if (mem.eql(u8, uri.scheme, "http"))
        .plain
    else if (mem.eql(u8, uri.scheme, "https"))
        .tls
    else
        return error.UnsupportedUrlScheme;

    const port: u16 = uri.port orelse switch (protocol) {
        .plain => 80,
        .tls => 443,
    };

    const host = uri.host orelse return error.UriMissingHost;

    if (client.next_https_rescan_certs and protocol == .tls) {
        client.connection_mutex.lock(); // TODO: this could be so much better than reusing the connection pool mutex.
        defer client.connection_mutex.unlock();

        if (client.next_https_rescan_certs) {
            try client.ca_bundle.rescan(client.allocator);
            client.next_https_rescan_certs = false;
        }
    }

    var req: Request = .{
        .uri = uri,
        .client = client,
        .headers = headers,
        .connection = try client.connect(host, port, protocol),
        .redirects_left = options.max_redirects,
        .handle_redirects = options.handle_redirects,
        .compression_init = false,
        .response = switch (options.header_strategy) {
            .dynamic => |max| Response.initDynamic(max),
            .static => |buf| Response.initStatic(buf),
        },
        .arena = undefined,
    };

    req.arena = std.heap.ArenaAllocator.init(client.allocator);

    {
        var buffered = std.io.bufferedWriter(req.connection.data.writer());
        const writer = buffered.writer();

        const escaped_path = try Uri.escapePath(client.allocator, uri.path);
        defer client.allocator.free(escaped_path);

        const escaped_query = if (uri.query) |q| try Uri.escapeQuery(client.allocator, q) else null;
        defer if (escaped_query) |q| client.allocator.free(q);

        const escaped_fragment = if (uri.fragment) |f| try Uri.escapeQuery(client.allocator, f) else null;
        defer if (escaped_fragment) |f| client.allocator.free(f);

        try writer.writeAll(@tagName(headers.method));
        try writer.writeByte(' ');
        try writer.writeAll(escaped_path);
        if (escaped_query) |q| {
            try writer.writeByte('?');
            try writer.writeAll(q);
        }
        if (escaped_fragment) |f| {
            try writer.writeByte('#');
            try writer.writeAll(f);
        }
        try writer.writeByte(' ');
        try writer.writeAll(@tagName(headers.version));
        try writer.writeAll("\r\nHost: ");
        try writer.writeAll(host);
        try writer.writeAll("\r\nUser-Agent: ");
        try writer.writeAll(headers.user_agent);
        if (headers.connection == .close) {
            try writer.writeAll("\r\nConnection: close");
        } else {
            try writer.writeAll("\r\nConnection: keep-alive");
        }
        try writer.writeAll("\r\nAccept-Encoding: gzip, deflate, zstd");

        switch (headers.transfer_encoding) {
            .chunked => try writer.writeAll("\r\nTransfer-Encoding: chunked"),
            .content_length => |content_length| try writer.print("\r\nContent-Length: {d}", .{content_length}),
            .none => {},
        }

        for (headers.custom) |header| {
            try writer.writeAll("\r\n");
            try writer.writeAll(header.name);
            try writer.writeAll(": ");
            try writer.writeAll(header.value);
        }

        try writer.writeAll("\r\n\r\n");

        try buffered.flush();
    }

    return req;
}

test {
    const builtin = @import("builtin");
    const native_endian = comptime builtin.cpu.arch.endian();
    if (builtin.zig_backend == .stage2_llvm and native_endian == .Big) {
        // https://github.com/ziglang/zig/issues/13782
        return error.SkipZigTest;
    }

    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    _ = Request;
}
