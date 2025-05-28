//! HTTP(S) Client implementation.
//!
//! Connections are opened in a thread-safe manner, but individual Requests are not.
//!
//! TLS support may be disabled via `std.options.http_disable_tls`.

const std = @import("../std.zig");
const builtin = @import("builtin");
const testing = std.testing;
const http = std.http;
const mem = std.mem;
const net = std.net;
const Uri = std.Uri;
const Allocator = mem.Allocator;
const assert = std.debug.assert;

const Client = @This();

pub const disable_tls = std.options.http_disable_tls;

/// Used for all client allocations. Must be thread-safe.
allocator: Allocator,

ca_bundle: if (disable_tls) void else std.crypto.Certificate.Bundle = if (disable_tls) {} else .{},
ca_bundle_mutex: std.Thread.Mutex = .{},
/// Used both for the reader and writer buffers.
tls_buffer_size: if (disable_tls) u0 else usize = if (disable_tls) 0 else std.crypto.tls.Client.min_buffer_len,
/// If non-null, ssl secrets are logged to a stream. Creating such a stream
/// allows other processes with access to that stream to decrypt all
/// traffic over connections created with this `Client`.
ssl_key_log: ?*std.crypto.tls.Client.SslKeyLog = null,

/// When this is `true`, the next time this client performs an HTTPS request,
/// it will first rescan the system for root certificates.
next_https_rescan_certs: bool = true,

/// The pool of connections that can be reused (and currently in use).
connection_pool: ConnectionPool = .{},
/// Each `Connection` allocates this amount for the reader buffer.
///
/// If the entire HTTP header cannot fit in this amount of bytes,
/// `error.HttpHeadersOversize` will be returned from `Request.wait`.
read_buffer_size: usize = 4096,
/// Each `Connection` allocates this amount for the writer buffer.
write_buffer_size: usize = 1024,

/// If populated, all http traffic travels through this third party.
/// This field cannot be modified while the client has active connections.
/// Pointer to externally-owned memory.
http_proxy: ?*Proxy = null,
/// If populated, all https traffic travels through this third party.
/// This field cannot be modified while the client has active connections.
/// Pointer to externally-owned memory.
https_proxy: ?*Proxy = null,

/// A Least-Recently-Used cache of open connections to be reused.
pub const ConnectionPool = struct {
    mutex: std.Thread.Mutex = .{},
    /// Open connections that are currently in use.
    used: std.DoublyLinkedList = .{},
    /// Open connections that are not currently in use.
    free: std.DoublyLinkedList = .{},
    free_len: usize = 0,
    free_size: usize = 32,

    /// The criteria for a connection to be considered a match.
    pub const Criteria = struct {
        host: []const u8,
        port: u16,
        protocol: Protocol,
    };

    /// Finds and acquires a connection from the connection pool matching the criteria.
    /// If no connection is found, null is returned.
    ///
    /// Threadsafe.
    pub fn findConnection(pool: *ConnectionPool, criteria: Criteria) ?*Connection {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        var next = pool.free.last;
        while (next) |node| : (next = node.prev) {
            const connection: *Connection = @fieldParentPtr("pool_node", node);
            if (connection.protocol != criteria.protocol) continue;
            if (connection.port != criteria.port) continue;

            // Domain names are case-insensitive (RFC 5890, Section 2.3.2.4)
            if (!std.ascii.eqlIgnoreCase(connection.host(), criteria.host)) continue;

            pool.acquireUnsafe(connection);
            return connection;
        }

        return null;
    }

    /// Acquires an existing connection from the connection pool. This function is not threadsafe.
    pub fn acquireUnsafe(pool: *ConnectionPool, connection: *Connection) void {
        pool.free.remove(&connection.pool_node);
        pool.free_len -= 1;

        pool.used.append(&connection.pool_node);
    }

    /// Acquires an existing connection from the connection pool. This function is threadsafe.
    pub fn acquire(pool: *ConnectionPool, connection: *Connection) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        return pool.acquireUnsafe(connection);
    }

    /// Tries to release a connection back to the connection pool.
    /// If the connection is marked as closing, it will be closed instead.
    ///
    /// `allocator` must be the same one used to create `connection`.
    ///
    /// Threadsafe.
    pub fn release(pool: *ConnectionPool, connection: *Connection) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        pool.used.remove(&connection.pool_node);

        if (connection.closing or pool.free_size == 0) return connection.destroy();

        if (pool.free_len >= pool.free_size) {
            const popped: *Connection = @fieldParentPtr("pool_node", pool.free.popFirst().?);
            pool.free_len -= 1;

            popped.destroy();
        }

        if (connection.proxied) {
            // proxied connections go to the end of the queue, always try direct connections first
            pool.free.prepend(&connection.pool_node);
        } else {
            pool.free.append(&connection.pool_node);
        }

        pool.free_len += 1;
    }

    /// Adds a newly created node to the pool of used connections. This function is threadsafe.
    pub fn addUsed(pool: *ConnectionPool, connection: *Connection) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        pool.used.append(&connection.pool_node);
    }

    /// Resizes the connection pool.
    ///
    /// If the new size is smaller than the current size, then idle connections will be closed until the pool is the new size.
    ///
    /// Threadsafe.
    pub fn resize(pool: *ConnectionPool, allocator: Allocator, new_size: usize) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        const next = pool.free.first;
        _ = next;
        while (pool.free_len > new_size) {
            const popped = pool.free.popFirst() orelse unreachable;
            pool.free_len -= 1;

            popped.data.close(allocator);
            allocator.destroy(popped);
        }

        pool.free_size = new_size;
    }

    /// Frees the connection pool and closes all connections within.
    ///
    /// All future operations on the connection pool will deadlock.
    ///
    /// Threadsafe.
    pub fn deinit(pool: *ConnectionPool) void {
        pool.mutex.lock();

        var next = pool.free.first;
        while (next) |node| {
            const connection: *Connection = @fieldParentPtr("pool_node", node);
            next = node.next;
            connection.destroy();
        }

        next = pool.used.first;
        while (next) |node| {
            const connection: *Connection = @fieldParentPtr("pool_node", node);
            next = node.next;
            connection.destroy();
        }

        pool.* = undefined;
    }
};

pub const Protocol = enum {
    plain,
    tls,

    fn port(protocol: Protocol) u16 {
        return switch (protocol) {
            .plain => 80,
            .tls => 443,
        };
    }

    pub fn fromScheme(scheme: []const u8) ?Protocol {
        const protocol_map = std.StaticStringMap(Protocol).initComptime(.{
            .{ "http", .plain },
            .{ "ws", .plain },
            .{ "https", .tls },
            .{ "wss", .tls },
        });
        return protocol_map.get(scheme);
    }

    pub fn fromUri(uri: Uri) ?Protocol {
        return fromScheme(uri.scheme);
    }
};

pub const Connection = struct {
    client: *Client,
    stream_writer: net.Stream.Writer,
    stream_reader: net.Stream.Reader,
    /// HTTP protocol from client to server.
    /// This either goes directly to `stream_writer`, or to a TLS client.
    writer: std.io.BufferedWriter,
    /// HTTP protocol from server to client.
    /// This either comes directly from `stream_reader`, or from a TLS client.
    reader: std.io.BufferedReader,
    /// Entry in `ConnectionPool.used` or `ConnectionPool.free`.
    pool_node: std.DoublyLinkedList.Node,
    port: u16,
    host_len: u8,
    proxied: bool,
    closing: bool,
    protocol: Protocol,

    const Plain = struct {
        connection: Connection,

        fn create(
            client: *Client,
            remote_host: []const u8,
            port: u16,
            stream: net.Stream,
        ) error{OutOfMemory}!*Plain {
            const gpa = client.allocator;
            const alloc_len = allocLen(client, remote_host.len);
            const base = try gpa.alignedAlloc(u8, .of(Plain), alloc_len);
            errdefer gpa.free(base);
            const host_buffer = base[@sizeOf(Plain)..][0..remote_host.len];
            const socket_read_buffer = host_buffer.ptr[host_buffer.len..][0..client.read_buffer_size];
            const socket_write_buffer = socket_read_buffer.ptr[socket_read_buffer.len..][0..client.write_buffer_size];
            assert(base.ptr + alloc_len == socket_write_buffer.ptr + socket_write_buffer.len);
            @memcpy(host_buffer, remote_host);
            const plain: *Plain = @ptrCast(base);
            plain.* = .{
                .connection = .{
                    .client = client,
                    .stream_writer = stream.writer(),
                    .stream_reader = stream.reader(),
                    .writer = plain.connection.stream_writer.interface().buffered(socket_write_buffer),
                    .reader = plain.connection.stream_reader.interface().buffered(socket_read_buffer),
                    .pool_node = .{},
                    .port = port,
                    .host_len = @intCast(remote_host.len),
                    .proxied = false,
                    .closing = false,
                    .protocol = .plain,
                },
            };
            return plain;
        }

        fn destroy(plain: *Plain) void {
            const c = &plain.connection;
            const gpa = c.client.allocator;
            const base: [*]align(@alignOf(Plain)) u8 = @ptrCast(plain);
            gpa.free(base[0..allocLen(c.client, c.host_len)]);
        }

        fn allocLen(client: *Client, host_len: usize) usize {
            return @sizeOf(Plain) + host_len + client.read_buffer_size + client.write_buffer_size;
        }

        fn host(plain: *Plain) []u8 {
            const base: [*]u8 = @ptrCast(plain);
            return base[@sizeOf(Plain)..][0..plain.connection.host_len];
        }
    };

    const Tls = struct {
        /// Data from `client` to `Connection.stream`.
        writer: std.io.BufferedWriter,
        /// Data from `Connection.stream` to `client`.
        reader: std.io.BufferedReader,
        client: std.crypto.tls.Client,
        connection: Connection,

        fn create(
            client: *Client,
            remote_host: []const u8,
            port: u16,
            stream: net.Stream,
        ) error{ OutOfMemory, TlsInitializationFailed }!*Tls {
            const gpa = client.allocator;
            const alloc_len = allocLen(client, remote_host.len);
            const base = try gpa.alignedAlloc(u8, .of(Tls), alloc_len);
            errdefer gpa.free(base);
            const host_buffer = base[@sizeOf(Tls)..][0..remote_host.len];
            const tls_read_buffer = host_buffer.ptr[host_buffer.len..][0..client.tls_buffer_size];
            const tls_write_buffer = tls_read_buffer.ptr[tls_read_buffer.len..][0..client.tls_buffer_size];
            const socket_write_buffer = tls_write_buffer.ptr[tls_write_buffer.len..][0..client.write_buffer_size];
            assert(base.ptr + alloc_len == socket_write_buffer.ptr + socket_write_buffer.len);
            @memcpy(host_buffer, remote_host);
            const tls: *Tls = @ptrCast(base);
            tls.* = .{
                .connection = .{
                    .client = client,
                    .stream_writer = stream.writer(),
                    .stream_reader = stream.reader(),
                    .writer = tls.client.writer().buffered(socket_write_buffer),
                    .reader = tls.client.reader().unbuffered(),
                    .pool_node = .{},
                    .port = port,
                    .host_len = @intCast(remote_host.len),
                    .proxied = false,
                    .closing = false,
                    .protocol = .tls,
                },
                .writer = tls.connection.stream_writer.interface().buffered(tls_write_buffer),
                .reader = tls.connection.stream_reader.interface().buffered(tls_read_buffer),
                .client = undefined,
            };
            // TODO data race here on ca_bundle if the user sets next_https_rescan_certs to true
            tls.client.init(&tls.reader, &tls.writer, .{
                .host = .{ .explicit = remote_host },
                .ca = .{ .bundle = client.ca_bundle },
                .ssl_key_log = client.ssl_key_log,
            }) catch return error.TlsInitializationFailed;
            // This is appropriate for HTTPS because the HTTP headers contain
            // the content length which is used to detect truncation attacks.
            tls.client.allow_truncation_attacks = true;

            return tls;
        }

        fn destroy(tls: *Tls) void {
            const c = &tls.connection;
            const gpa = c.client.allocator;
            const base: [*]align(@alignOf(Tls)) u8 = @ptrCast(tls);
            gpa.free(base[0..allocLen(c.client, c.host_len)]);
        }

        fn allocLen(client: *Client, host_len: usize) usize {
            return @sizeOf(Tls) + host_len + client.tls_buffer_size + client.tls_buffer_size + client.write_buffer_size;
        }

        fn host(tls: *Tls) []u8 {
            const base: [*]u8 = @ptrCast(tls);
            return base[@sizeOf(Tls)..][0..tls.connection.host_len];
        }
    };

    fn getStream(c: *Connection) net.Stream {
        return c.stream_reader.getStream();
    }

    fn host(c: *Connection) []u8 {
        return switch (c.protocol) {
            .tls => {
                if (disable_tls) unreachable;
                const tls: *Tls = @fieldParentPtr("connection", c);
                return tls.host();
            },
            .plain => {
                const plain: *Plain = @fieldParentPtr("connection", c);
                return plain.host();
            },
        };
    }

    /// If this is called without calling `flush` or `end`, data will be
    /// dropped unsent.
    pub fn destroy(c: *Connection) void {
        c.getStream().close();
        switch (c.protocol) {
            .tls => {
                if (disable_tls) unreachable;
                const tls: *Tls = @fieldParentPtr("connection", c);
                tls.destroy();
            },
            .plain => {
                const plain: *Plain = @fieldParentPtr("connection", c);
                plain.destroy();
            },
        }
    }

    pub fn flush(c: *Connection) std.io.Writer.Error!void {
        try c.writer.flush();
        if (c.protocol == .tls) {
            if (disable_tls) unreachable;
            const tls: *Tls = @fieldParentPtr("connection", c);
            try tls.writer.flush();
        }
    }

    /// If the connection is a TLS connection, sends the close_notify alert.
    ///
    /// Flushes all buffers.
    pub fn end(c: *Connection) std.io.Writer.Error!void {
        try c.writer.flush();
        if (c.protocol == .tls) {
            if (disable_tls) unreachable;
            const tls: *Tls = @fieldParentPtr("connection", c);
            try tls.client.end();
            try tls.writer.flush();
        }
    }
};

pub const Response = struct {
    request: *Request,
    /// Pointers in this struct are invalidated with the next call to
    /// `receiveHead`.
    head: Head,

    pub const Head = struct {
        bytes: []const u8,
        version: http.Version,
        status: http.Status,
        reason: []const u8,
        location: ?[]const u8 = null,
        content_type: ?[]const u8 = null,
        content_disposition: ?[]const u8 = null,

        keep_alive: bool,

        /// If present, the number of bytes in the response body.
        content_length: ?u64 = null,

        transfer_encoding: http.TransferEncoding = .none,
        content_encoding: http.ContentEncoding = .identity,

        pub const ParseError = error{
            HttpConnectionHeaderUnsupported,
            HttpContentEncodingUnsupported,
            HttpHeaderContinuationsUnsupported,
            HttpHeadersInvalid,
            HttpTransferEncodingUnsupported,
            InvalidContentLength,
        };

        pub fn parse(bytes: []const u8) ParseError!Head {
            var res: Head = .{
                .bytes = bytes,
                .status = undefined,
                .reason = undefined,
                .version = undefined,
                .keep_alive = false,
            };
            var it = mem.splitSequence(u8, bytes, "\r\n");

            const first_line = it.next().?;
            if (first_line.len < 12) {
                return error.HttpHeadersInvalid;
            }

            const version: http.Version = switch (int64(first_line[0..8])) {
                int64("HTTP/1.0") => .@"HTTP/1.0",
                int64("HTTP/1.1") => .@"HTTP/1.1",
                else => return error.HttpHeadersInvalid,
            };
            if (first_line[8] != ' ') return error.HttpHeadersInvalid;
            const status: http.Status = @enumFromInt(parseInt3(first_line[9..12]));
            const reason = mem.trimLeft(u8, first_line[12..], " ");

            res.version = version;
            res.status = status;
            res.reason = reason;
            res.keep_alive = switch (version) {
                .@"HTTP/1.0" => false,
                .@"HTTP/1.1" => true,
            };

            while (it.next()) |line| {
                if (line.len == 0) return res;
                switch (line[0]) {
                    ' ', '\t' => return error.HttpHeaderContinuationsUnsupported,
                    else => {},
                }

                var line_it = mem.splitScalar(u8, line, ':');
                const header_name = line_it.next().?;
                const header_value = mem.trim(u8, line_it.rest(), " \t");
                if (header_name.len == 0) return error.HttpHeadersInvalid;

                if (std.ascii.eqlIgnoreCase(header_name, "connection")) {
                    res.keep_alive = !std.ascii.eqlIgnoreCase(header_value, "close");
                } else if (std.ascii.eqlIgnoreCase(header_name, "content-type")) {
                    res.content_type = header_value;
                } else if (std.ascii.eqlIgnoreCase(header_name, "location")) {
                    res.location = header_value;
                } else if (std.ascii.eqlIgnoreCase(header_name, "content-disposition")) {
                    res.content_disposition = header_value;
                } else if (std.ascii.eqlIgnoreCase(header_name, "transfer-encoding")) {
                    // Transfer-Encoding: second, first
                    // Transfer-Encoding: deflate, chunked
                    var iter = mem.splitBackwardsScalar(u8, header_value, ',');

                    const first = iter.first();
                    const trimmed_first = mem.trim(u8, first, " ");

                    var next: ?[]const u8 = first;
                    if (std.meta.stringToEnum(http.TransferEncoding, trimmed_first)) |transfer| {
                        if (res.transfer_encoding != .none) return error.HttpHeadersInvalid; // we already have a transfer encoding
                        res.transfer_encoding = transfer;

                        next = iter.next();
                    }

                    if (next) |second| {
                        const trimmed_second = mem.trim(u8, second, " ");

                        if (http.ContentEncoding.fromString(trimmed_second)) |transfer| {
                            if (res.content_encoding != .identity) return error.HttpHeadersInvalid; // double compression is not supported
                            res.content_encoding = transfer;
                        } else {
                            return error.HttpTransferEncodingUnsupported;
                        }
                    }

                    if (iter.next()) |_| return error.HttpTransferEncodingUnsupported;
                } else if (std.ascii.eqlIgnoreCase(header_name, "content-length")) {
                    const content_length = std.fmt.parseInt(u64, header_value, 10) catch return error.InvalidContentLength;

                    if (res.content_length != null and res.content_length != content_length) return error.HttpHeadersInvalid;

                    res.content_length = content_length;
                } else if (std.ascii.eqlIgnoreCase(header_name, "content-encoding")) {
                    if (res.content_encoding != .identity) return error.HttpHeadersInvalid;

                    const trimmed = mem.trim(u8, header_value, " ");

                    if (http.ContentEncoding.fromString(trimmed)) |ce| {
                        res.content_encoding = ce;
                    } else {
                        return error.HttpContentEncodingUnsupported;
                    }
                }
            }
            return error.HttpHeadersInvalid; // missing empty line
        }

        test parse {
            const response_bytes = "HTTP/1.1 200 OK\r\n" ++
                "LOcation:url\r\n" ++
                "content-tYpe: text/plain\r\n" ++
                "content-disposition:attachment; filename=example.txt \r\n" ++
                "content-Length:10\r\n" ++
                "TRansfer-encoding:\tdeflate, chunked \r\n" ++
                "connectioN:\t keep-alive \r\n\r\n";

            const head = try Head.parse(response_bytes);

            try testing.expectEqual(.@"HTTP/1.1", head.version);
            try testing.expectEqualStrings("OK", head.reason);
            try testing.expectEqual(.ok, head.status);

            try testing.expectEqualStrings("url", head.location.?);
            try testing.expectEqualStrings("text/plain", head.content_type.?);
            try testing.expectEqualStrings("attachment; filename=example.txt", head.content_disposition.?);

            try testing.expectEqual(true, head.keep_alive);
            try testing.expectEqual(10, head.content_length.?);
            try testing.expectEqual(.chunked, head.transfer_encoding);
            try testing.expectEqual(.deflate, head.content_encoding);
        }

        pub fn iterateHeaders(h: Head) http.HeaderIterator {
            return .init(h.bytes);
        }

        test iterateHeaders {
            const response_bytes = "HTTP/1.1 200 OK\r\n" ++
                "LOcation:url\r\n" ++
                "content-tYpe: text/plain\r\n" ++
                "content-disposition:attachment; filename=example.txt \r\n" ++
                "content-Length:10\r\n" ++
                "TRansfer-encoding:\tdeflate, chunked \r\n" ++
                "connectioN:\t keep-alive \r\n\r\n";

            const head = try Head.parse(response_bytes);
            var it = head.iterateHeaders();
            {
                const header = it.next().?;
                try testing.expectEqualStrings("LOcation", header.name);
                try testing.expectEqualStrings("url", header.value);
                try testing.expect(!it.is_trailer);
            }
            {
                const header = it.next().?;
                try testing.expectEqualStrings("content-tYpe", header.name);
                try testing.expectEqualStrings("text/plain", header.value);
                try testing.expect(!it.is_trailer);
            }
            {
                const header = it.next().?;
                try testing.expectEqualStrings("content-disposition", header.name);
                try testing.expectEqualStrings("attachment; filename=example.txt", header.value);
                try testing.expect(!it.is_trailer);
            }
            {
                const header = it.next().?;
                try testing.expectEqualStrings("content-Length", header.name);
                try testing.expectEqualStrings("10", header.value);
                try testing.expect(!it.is_trailer);
            }
            {
                const header = it.next().?;
                try testing.expectEqualStrings("TRansfer-encoding", header.name);
                try testing.expectEqualStrings("deflate, chunked", header.value);
                try testing.expect(!it.is_trailer);
            }
            {
                const header = it.next().?;
                try testing.expectEqualStrings("connectioN", header.name);
                try testing.expectEqualStrings("keep-alive", header.value);
                try testing.expect(!it.is_trailer);
            }
            try testing.expectEqual(null, it.next());
        }

        inline fn int64(array: *const [8]u8) u64 {
            return @bitCast(array.*);
        }

        fn parseInt3(text: *const [3]u8) u10 {
            const nnn: @Vector(3, u8) = text.*;
            const zero: @Vector(3, u8) = .{ '0', '0', '0' };
            const mmm: @Vector(3, u10) = .{ 100, 10, 1 };
            return @reduce(.Add, (nnn -% zero) *% mmm);
        }

        test parseInt3 {
            const expectEqual = testing.expectEqual;
            try expectEqual(@as(u10, 0), parseInt3("000"));
            try expectEqual(@as(u10, 418), parseInt3("418"));
            try expectEqual(@as(u10, 999), parseInt3("999"));
        }
    };

    /// If compressed body has been negotiated this will return compressed bytes.
    ///
    /// If the returned `std.io.Reader` returns `error.ReadFailed` the error is
    /// available via `bodyErr`.
    ///
    /// Asserts that this function is only called once.
    ///
    /// See also:
    /// * `readerDecompressing`
    pub fn reader(response: *Response) std.io.Reader {
        const req = response.request;
        if (!req.method.responseHasBody()) return .ending;
        const head = &response.head;
        return req.reader.bodyReader(head.transfer_encoding, head.content_length);
    }

    /// If compressed body has been negotiated this will return decompressed bytes.
    ///
    /// If the returned `std.io.Reader` returns `error.ReadFailed` the error is
    /// available via `bodyErr`.
    ///
    /// Asserts that this function is only called once.
    ///
    /// See also:
    /// * `reader`
    pub fn readerDecompressing(
        response: *Response,
        decompressor: *http.Decompressor,
        decompression_buffer: []u8,
    ) std.io.Reader {
        const head = &response.head;
        return response.request.reader.bodyReaderDecompressing(
            head.transfer_encoding,
            head.content_length,
            head.content_encoding,
            decompressor,
            decompression_buffer,
        );
    }

    /// After receiving `error.ReadFailed` from the `std.io.Reader` returned by
    /// `reader` or `readerDecompressing`, this function accesses the
    /// more specific error code.
    pub fn bodyErr(response: *const Response) ?http.Reader.BodyError {
        return response.request.reader.body_err;
    }

    pub fn iterateTrailers(response: *const Response) http.HeaderIterator {
        const r = &response.request.reader;
        assert(r.state == .ready);
        return .{
            .bytes = r.trailers,
            .index = 0,
            .is_trailer = true,
        };
    }
};

pub const Request = struct {
    /// This field is provided so that clients can observe redirected URIs.
    ///
    /// Its backing memory is externally provided by API users when creating a
    /// request, and then again provided externally via `redirect_buffer` to
    /// `receiveHead`.
    uri: Uri,
    client: *Client,
    /// This is null when the connection is released.
    connection: ?*Connection,
    reader: http.Reader,
    keep_alive: bool,

    method: http.Method,
    version: http.Version = .@"HTTP/1.1",
    transfer_encoding: TransferEncoding,
    redirect_behavior: RedirectBehavior,
    accept_encoding: @TypeOf(default_accept_encoding) = default_accept_encoding,

    /// Whether the request should handle a 100-continue response before sending the request body.
    handle_continue: bool,

    /// Standard headers that have default, but overridable, behavior.
    headers: Headers,

    /// These headers are kept including when following a redirect to a
    /// different domain.
    /// Externally-owned; must outlive the Request.
    extra_headers: []const http.Header,

    /// These headers are stripped when following a redirect to a different
    /// domain.
    /// Externally-owned; must outlive the Request.
    privileged_headers: []const http.Header,

    pub const default_accept_encoding: [@typeInfo(http.ContentEncoding).@"enum".fields.len]bool = b: {
        var result: [@typeInfo(http.ContentEncoding).@"enum".fields.len]bool = @splat(false);
        result[@intFromEnum(http.ContentEncoding.gzip)] = true;
        result[@intFromEnum(http.ContentEncoding.deflate)] = true;
        result[@intFromEnum(http.ContentEncoding.identity)] = true;
        break :b result;
    };

    pub const TransferEncoding = union(enum) {
        content_length: u64,
        chunked: void,
        none: void,
    };

    pub const Headers = struct {
        host: Value = .default,
        authorization: Value = .default,
        user_agent: Value = .default,
        connection: Value = .default,
        accept_encoding: Value = .default,
        content_type: Value = .default,

        pub const Value = union(enum) {
            default,
            omit,
            override: []const u8,
        };
    };

    /// Any value other than `not_allowed` or `unhandled` means that integer represents
    /// how many remaining redirects are allowed.
    pub const RedirectBehavior = enum(u16) {
        /// The next redirect will cause an error.
        not_allowed = 0,
        /// Redirects are passed to the client to analyze the redirect response
        /// directly.
        unhandled = std.math.maxInt(u16),
        _,

        pub fn subtractOne(rb: *RedirectBehavior) void {
            switch (rb.*) {
                .not_allowed => unreachable,
                .unhandled => unreachable,
                _ => rb.* = @enumFromInt(@intFromEnum(rb.*) - 1),
            }
        }

        pub fn remaining(rb: RedirectBehavior) u16 {
            assert(rb != .unhandled);
            return @intFromEnum(rb);
        }
    };

    /// Returns the request's `Connection` back to the pool of the `Client`.
    pub fn deinit(r: *Request) void {
        r.reader.restituteHeadBuffer();
        if (r.connection) |connection| {
            connection.closing = connection.closing or switch (r.reader.state) {
                .ready => false,
                .received_head => r.method.requestHasBody(),
                else => true,
            };
            r.client.connection_pool.release(connection);
        }
        r.* = undefined;
    }

    /// Sends and flushes a complete request as only HTTP head, no body.
    pub fn sendBodiless(r: *Request) std.io.Writer.Error!void {
        try sendBodilessUnflushed(r);
        try r.connection.?.flush();
    }

    /// Sends but does not flush a complete request as only HTTP head, no body.
    pub fn sendBodilessUnflushed(r: *Request) std.io.Writer.Error!void {
        assert(r.transfer_encoding == .none);
        assert(!r.method.requestHasBody());
        try sendHead(r);
    }

    /// Transfers the HTTP head over the connection and flushes.
    ///
    /// See also:
    /// * `sendBodyUnflushed`
    pub fn sendBody(r: *Request) std.io.Writer.Error!http.BodyWriter {
        const result = try sendBodyUnflushed(r);
        try r.connection.?.flush();
        return result;
    }

    /// Transfers the HTTP head over the connection, which is not flushed until
    /// `BodyWriter.flush` or `BodyWriter.end` is called.
    ///
    /// See also:
    /// * `sendBody`
    pub fn sendBodyUnflushed(r: *Request) std.io.Writer.Error!http.BodyWriter {
        assert(r.method.requestHasBody());
        try sendHead(r);
        return .{
            .http_protocol_output = &r.connection.?.writer,
            .state = switch (r.transfer_encoding) {
                .chunked => .{ .chunked = .init },
                .content_length => |len| .{ .content_length = len },
                .none => .none,
            },
            .elide = false,
        };
    }

    /// Sends HTTP headers without flushing.
    fn sendHead(r: *Request) std.io.Writer.Error!void {
        const uri = r.uri;
        const connection = r.connection.?;
        const w = &connection.writer;

        try r.method.write(w);
        try w.writeByte(' ');

        if (r.method == .CONNECT) {
            try uri.writeToStream(.{ .authority = true }, w);
        } else {
            try uri.writeToStream(.{
                .scheme = connection.proxied,
                .authentication = connection.proxied,
                .authority = connection.proxied,
                .path = true,
                .query = true,
            }, w);
        }
        try w.writeByte(' ');
        try w.writeAll(@tagName(r.version));
        try w.writeAll("\r\n");

        if (try emitOverridableHeader("host: ", r.headers.host, w)) {
            try w.writeAll("host: ");
            try uri.writeToStream(.{ .authority = true }, w);
            try w.writeAll("\r\n");
        }

        if (try emitOverridableHeader("authorization: ", r.headers.authorization, w)) {
            if (uri.user != null or uri.password != null) {
                try w.writeAll("authorization: ");
                try basic_authorization.write(uri, w);
                try w.writeAll("\r\n");
            }
        }

        if (try emitOverridableHeader("user-agent: ", r.headers.user_agent, w)) {
            try w.writeAll("user-agent: zig/");
            try w.writeAll(builtin.zig_version_string);
            try w.writeAll(" (std.http)\r\n");
        }

        if (try emitOverridableHeader("connection: ", r.headers.connection, w)) {
            if (r.keep_alive) {
                try w.writeAll("connection: keep-alive\r\n");
            } else {
                try w.writeAll("connection: close\r\n");
            }
        }

        if (try emitOverridableHeader("accept-encoding: ", r.headers.accept_encoding, w)) {
            try w.writeAll("accept-encoding: ");
            for (r.accept_encoding, 0..) |enabled, i| {
                if (!enabled) continue;
                const tag: http.ContentEncoding = @enumFromInt(i);
                if (tag == .identity) continue;
                const tag_name = @tagName(tag);
                try w.ensureUnusedCapacity(tag_name.len + 2);
                try w.writeAll(tag_name);
                try w.writeAll(", ");
            }
            w.undo(2);
            try w.writeAll("\r\n");
        }

        switch (r.transfer_encoding) {
            .chunked => try w.writeAll("transfer-encoding: chunked\r\n"),
            .content_length => |len| try w.print("content-length: {d}\r\n", .{len}),
            .none => {},
        }

        if (try emitOverridableHeader("content-type: ", r.headers.content_type, w)) {
            // The default is to omit content-type if not provided because
            // "application/octet-stream" is redundant.
        }

        for (r.extra_headers) |header| {
            assert(header.name.len != 0);

            try w.writeAll(header.name);
            try w.writeAll(": ");
            try w.writeAll(header.value);
            try w.writeAll("\r\n");
        }

        if (connection.proxied) proxy: {
            const proxy = switch (connection.protocol) {
                .plain => r.client.http_proxy,
                .tls => r.client.https_proxy,
            } orelse break :proxy;

            const authorization = proxy.authorization orelse break :proxy;
            try w.writeAll("proxy-authorization: ");
            try w.writeAll(authorization);
            try w.writeAll("\r\n");
        }

        try w.writeAll("\r\n");
    }

    pub const ReceiveHeadError = http.Reader.HeadError || ConnectError || error{
        /// Server sent headers that did not conform to the HTTP protocol.
        ///
        /// To find out more detailed diagnostics, `http.Reader.head_buffer` can be
        /// passed directly to `Request.Head.parse`.
        HttpHeadersInvalid,
        TooManyHttpRedirects,
        /// This can be avoided by calling `receiveHead` before sending the
        /// request body.
        RedirectRequiresResend,
        HttpRedirectLocationMissing,
        HttpRedirectLocationOversize,
        HttpRedirectLocationInvalid,
        HttpContentEncodingUnsupported,
        HttpChunkInvalid,
        HttpChunkTruncated,
        HttpHeadersOversize,
        UnsupportedUriScheme,

        /// Sending the request failed. Error code can be found on the
        /// `Connection` object.
        WriteFailed,
    };

    /// If handling redirects and the request has no payload, then this
    /// function will automatically follow redirects.
    ///
    /// If a request payload is present, then this function will error with
    /// `error.RedirectRequiresResend`.
    ///
    /// This function takes an auxiliary buffer to store the arbitrarily large
    /// URI which may need to be merged with the previous URI, and that data
    /// needs to survive across different connections, which is where the input
    /// buffer lives.
    ///
    /// `redirect_buffer` must outlive accesses to `Request.uri`. If this
    /// buffer capacity would be exceeded, `error.HttpRedirectLocationOversize`
    /// is returned instead. This buffer may be empty if no redirects are to be
    /// handled.
    pub fn receiveHead(r: *Request, redirect_buffer: []u8) ReceiveHeadError!Response {
        var aux_buf = redirect_buffer;
        while (true) {
            try r.reader.receiveHead();
            const response: Response = .{
                .request = r,
                .head = Response.Head.parse(r.reader.head_buffer) catch return error.HttpHeadersInvalid,
            };
            const head = &response.head;

            if (head.status == .@"continue") {
                if (r.handle_continue) continue;
                return response; // we're not handling the 100-continue
            }

            // This while loop is for handling redirects, which means the request's
            // connection may be different than the previous iteration. However, it
            // is still guaranteed to be non-null with each iteration of this loop.
            const connection = r.connection.?;

            if (r.method == .CONNECT and head.status.class() == .success) {
                // This connection is no longer doing HTTP.
                connection.closing = false;
                return response;
            }

            connection.closing = !head.keep_alive or !r.keep_alive;

            // Any response to a HEAD request and any response with a 1xx
            // (Informational), 204 (No Content), or 304 (Not Modified) status
            // code is always terminated by the first empty line after the
            // header fields, regardless of the header fields present in the
            // message.
            if (r.method == .HEAD or head.status.class() == .informational or
                head.status == .no_content or head.status == .not_modified)
            {
                return response;
            }

            if (head.status.class() == .redirect and r.redirect_behavior != .unhandled) {
                if (r.redirect_behavior == .not_allowed) {
                    // Connection can still be reused by skipping the body.
                    var reader = r.reader.bodyReader(head.transfer_encoding, head.content_length);
                    _ = reader.discardRemaining() catch |err| switch (err) {
                        error.ReadFailed => connection.closing = true,
                    };
                    return error.TooManyHttpRedirects;
                }
                try r.redirect(head, &aux_buf);
                try r.sendBodiless();
                continue;
            }

            if (!r.accept_encoding[@intFromEnum(head.content_encoding)])
                return error.HttpContentEncodingUnsupported;

            return response;
        }
    }

    /// This function takes an auxiliary buffer to store the arbitrarily large
    /// URI which may need to be merged with the previous URI, and that data
    /// needs to survive across different connections, which is where the input
    /// buffer lives.
    ///
    /// `aux_buf` must outlive accesses to `Request.uri`.
    fn redirect(r: *Request, head: *const Response.Head, aux_buf: *[]u8) !void {
        const new_location = head.location orelse return error.HttpRedirectLocationMissing;
        if (new_location.len > aux_buf.*.len) return error.HttpRedirectLocationOversize;
        const location = aux_buf.*[0..new_location.len];
        @memcpy(location, new_location);
        {
            // Skip the body of the redirect response to leave the connection in
            // the correct state. This causes `new_location` to be invalidated.
            var reader = r.reader.bodyReader(head.transfer_encoding, head.content_length);
            _ = reader.discardRemaining() catch |err| switch (err) {
                error.ReadFailed => return r.reader.body_err.?,
            };
            r.reader.restituteHeadBuffer();
        }
        const new_uri = r.uri.resolveInPlace(location.len, aux_buf) catch |err| switch (err) {
            error.UnexpectedCharacter => return error.HttpRedirectLocationInvalid,
            error.InvalidFormat => return error.HttpRedirectLocationInvalid,
            error.InvalidPort => return error.HttpRedirectLocationInvalid,
            error.NoSpaceLeft => return error.HttpRedirectLocationOversize,
        };

        const protocol = Protocol.fromUri(new_uri) orelse return error.UnsupportedUriScheme;
        const old_connection = r.connection.?;
        const old_host = old_connection.host();
        var new_host_name_buffer: [Uri.host_name_max]u8 = undefined;
        const new_host = try new_uri.getHost(&new_host_name_buffer);
        const keep_privileged_headers =
            std.ascii.eqlIgnoreCase(r.uri.scheme, new_uri.scheme) and
            sameParentDomain(old_host, new_host);

        r.client.connection_pool.release(old_connection);
        r.connection = null;

        if (!keep_privileged_headers) {
            // When redirecting to a different domain, strip privileged headers.
            r.privileged_headers = &.{};
        }

        if (switch (head.status) {
            .see_other => true,
            .moved_permanently, .found => r.method == .POST,
            else => false,
        }) {
            // A redirect to a GET must change the method and remove the body.
            r.method = .GET;
            r.transfer_encoding = .none;
            r.headers.content_type = .omit;
        }

        if (r.transfer_encoding != .none) {
            // The request body has already been sent. The request is
            // still in a valid state, but the redirect must be handled
            // manually.
            return error.RedirectRequiresResend;
        }

        const new_connection = try r.client.connect(new_host, uriPort(new_uri, protocol), protocol);
        r.uri = new_uri;
        r.connection = new_connection;
        r.reader = .{
            .in = &new_connection.reader,
            .state = .ready,
        };
        r.redirect_behavior.subtractOne();
    }

    /// Returns true if the default behavior is required, otherwise handles
    /// writing (or not writing) the header.
    fn emitOverridableHeader(prefix: []const u8, v: Headers.Value, bw: *std.io.BufferedWriter) std.io.Writer.Error!bool {
        switch (v) {
            .default => return true,
            .omit => return false,
            .override => |x| {
                var vecs: [3][]const u8 = .{ prefix, x, "\r\n" };
                try bw.writeVecAll(&vecs);
                return false;
            },
        }
    }
};

pub const Proxy = struct {
    protocol: Protocol,
    host: []const u8,
    authorization: ?[]const u8,
    port: u16,
    supports_connect: bool,
};

/// Release all associated resources with the client.
///
/// All pending requests must be de-initialized and all active connections released
/// before calling this function.
pub fn deinit(client: *Client) void {
    assert(client.connection_pool.used.first == null); // There are still active requests.

    client.connection_pool.deinit();
    if (!disable_tls) client.ca_bundle.deinit(client.allocator);

    client.* = undefined;
}

/// Populates `http_proxy` and `https_proxy` via standard proxy environment variables.
/// Asserts the client has no active connections.
/// Uses `arena` for a few small allocations that must outlive the client, or
/// at least until those fields are set to different values.
pub fn initDefaultProxies(client: *Client, arena: Allocator) !void {
    // Prevent any new connections from being created.
    client.connection_pool.mutex.lock();
    defer client.connection_pool.mutex.unlock();

    assert(client.connection_pool.used.first == null); // There are active requests.

    if (client.http_proxy == null) {
        client.http_proxy = try createProxyFromEnvVar(arena, &.{
            "http_proxy", "HTTP_PROXY", "all_proxy", "ALL_PROXY",
        });
    }

    if (client.https_proxy == null) {
        client.https_proxy = try createProxyFromEnvVar(arena, &.{
            "https_proxy", "HTTPS_PROXY", "all_proxy", "ALL_PROXY",
        });
    }
}

fn createProxyFromEnvVar(arena: Allocator, env_var_names: []const []const u8) !?*Proxy {
    const content = for (env_var_names) |name| {
        const content = std.process.getEnvVarOwned(arena, name) catch |err| switch (err) {
            error.EnvironmentVariableNotFound => continue,
            else => |e| return e,
        };

        if (content.len == 0) continue;

        break content;
    } else return null;

    const uri = Uri.parse(content) catch try Uri.parseAfterScheme("http", content);
    const protocol = Protocol.fromUri(uri) orelse return null;
    const raw_host = try uri.getHostAlloc(arena);

    const authorization: ?[]const u8 = if (uri.user != null or uri.password != null) a: {
        const authorization = try arena.alloc(u8, basic_authorization.valueLengthFromUri(uri));
        assert(basic_authorization.value(uri, authorization).len == authorization.len);
        break :a authorization;
    } else null;

    const proxy = try arena.create(Proxy);
    proxy.* = .{
        .protocol = protocol,
        .host = raw_host,
        .authorization = authorization,
        .port = uriPort(uri, protocol),
        .supports_connect = true,
    };
    return proxy;
}

pub const basic_authorization = struct {
    pub const max_user_len = 255;
    pub const max_password_len = 255;
    pub const max_value_len = valueLength(max_user_len, max_password_len);

    pub fn valueLength(user_len: usize, password_len: usize) usize {
        return "Basic ".len + std.base64.standard.Encoder.calcSize(user_len + 1 + password_len);
    }

    pub fn valueLengthFromUri(uri: Uri) usize {
        // TODO don't abuse formatted printing to count percent encoded characters
        const user_len = std.fmt.count("{fuser}", .{uri.user orelse Uri.Component.empty});
        const password_len = std.fmt.count("{fpassword}", .{uri.password orelse Uri.Component.empty});
        return valueLength(@intCast(user_len), @intCast(password_len));
    }

    pub fn value(uri: Uri, out: []u8) []u8 {
        var bw: std.io.BufferedWriter = undefined;
        bw.initFixed(out);
        write(uri, &bw) catch unreachable;
        return bw.getWritten();
    }

    pub fn write(uri: Uri, out: *std.io.BufferedWriter) std.io.Writer.Error!void {
        var buf: [max_user_len + ":".len + max_password_len]u8 = undefined;
        var bw: std.io.BufferedWriter = undefined;
        bw.initFixed(&buf);
        bw.print("{fuser}:{fpassword}", .{
            uri.user orelse Uri.Component.empty,
            uri.password orelse Uri.Component.empty,
        }) catch unreachable;
        try out.print("Basic {b64}", .{bw.getWritten()});
    }
};

pub const ConnectTcpError = Allocator.Error || error{
    ConnectionRefused,
    NetworkUnreachable,
    ConnectionTimedOut,
    ConnectionResetByPeer,
    TemporaryNameServerFailure,
    NameServerFailure,
    UnknownHostName,
    HostLacksNetworkAddresses,
    UnexpectedConnectFailure,
    TlsInitializationFailed,
};

/// Reuses a `Connection` if one matching `host` and `port` is already open.
///
/// Threadsafe.
pub fn connectTcp(
    client: *Client,
    host: []const u8,
    port: u16,
    protocol: Protocol,
) ConnectTcpError!*Connection {
    return connectTcpOptions(client, .{ .host = host, .port = port, .protocol = protocol });
}

pub const ConnectTcpOptions = struct {
    host: []const u8,
    port: u16,
    protocol: Protocol,

    proxied_host: ?[]const u8 = null,
    proxied_port: ?u16 = null,
};

pub fn connectTcpOptions(client: *Client, options: ConnectTcpOptions) ConnectTcpError!*Connection {
    const host = options.host;
    const port = options.port;
    const protocol = options.protocol;

    const proxied_host = options.proxied_host orelse host;
    const proxied_port = options.proxied_port orelse port;

    if (client.connection_pool.findConnection(.{
        .host = proxied_host,
        .port = proxied_port,
        .protocol = protocol,
    })) |conn| return conn;

    const stream = net.tcpConnectToHost(client.allocator, host, port) catch |err| switch (err) {
        error.ConnectionRefused => return error.ConnectionRefused,
        error.NetworkUnreachable => return error.NetworkUnreachable,
        error.ConnectionTimedOut => return error.ConnectionTimedOut,
        error.ConnectionResetByPeer => return error.ConnectionResetByPeer,
        error.TemporaryNameServerFailure => return error.TemporaryNameServerFailure,
        error.NameServerFailure => return error.NameServerFailure,
        error.UnknownHostName => return error.UnknownHostName,
        error.HostLacksNetworkAddresses => return error.HostLacksNetworkAddresses,
        else => return error.UnexpectedConnectFailure,
    };
    errdefer stream.close();

    switch (protocol) {
        .tls => {
            if (disable_tls) return error.TlsInitializationFailed;
            const tc = try Connection.Tls.create(client, proxied_host, proxied_port, stream);
            client.connection_pool.addUsed(&tc.connection);
            return &tc.connection;
        },
        .plain => {
            const pc = try Connection.Plain.create(client, proxied_host, proxied_port, stream);
            client.connection_pool.addUsed(&pc.connection);
            return &pc.connection;
        },
    }
}

pub const ConnectUnixError = Allocator.Error || std.posix.SocketError || error{NameTooLong} || std.posix.ConnectError;

/// Connect to `path` as a unix domain socket. This will reuse a connection if one is already open.
///
/// This function is threadsafe.
pub fn connectUnix(client: *Client, path: []const u8) ConnectUnixError!*Connection {
    if (client.connection_pool.findConnection(.{
        .host = path,
        .port = 0,
        .protocol = .plain,
    })) |node|
        return node;

    const conn = try client.allocator.create(ConnectionPool.Node);
    errdefer client.allocator.destroy(conn);
    conn.* = .{ .data = undefined };

    const stream = try std.net.connectUnixSocket(path);
    errdefer stream.close();

    conn.data = .{
        .stream = stream,
        .tls_client = undefined,
        .protocol = .plain,

        .host = try client.allocator.dupe(u8, path),
        .port = 0,
    };
    errdefer client.allocator.free(conn.data.host);

    client.connection_pool.addUsed(conn);

    return &conn.data;
}

/// Connect to `proxied_host:proxied_port` using the specified proxy with HTTP
/// CONNECT. This will reuse a connection if one is already open.
///
/// This function is threadsafe.
pub fn connectProxied(
    client: *Client,
    proxy: *Proxy,
    proxied_host: []const u8,
    proxied_port: u16,
) !*Connection {
    if (!proxy.supports_connect) return error.TunnelNotSupported;

    if (client.connection_pool.findConnection(.{
        .host = proxied_host,
        .port = proxied_port,
        .protocol = proxy.protocol,
    })) |node| return node;

    var maybe_valid = false;
    (tunnel: {
        const connection = try client.connectTcpOptions(.{
            .host = proxy.host,
            .port = proxy.port,
            .protocol = proxy.protocol,
            .proxied_host = proxied_host,
            .proxied_port = proxied_port,
        });
        errdefer {
            connection.closing = true;
            client.connection_pool.release(connection);
        }

        var req = client.request(.CONNECT, .{
            .scheme = "http",
            .host = .{ .raw = proxied_host },
            .port = proxied_port,
        }, .{
            .redirect_behavior = .unhandled,
            .connection = connection,
        }) catch |err| {
            break :tunnel err;
        };
        defer req.deinit();

        req.sendBodiless() catch |err| break :tunnel err;
        const response = req.receiveHead(&.{}) catch |err| break :tunnel err;

        if (response.head.status.class() == .server_error) {
            maybe_valid = true;
            break :tunnel error.ServerError;
        }

        if (response.head.status != .ok) break :tunnel error.ConnectionRefused;

        // this connection is now a tunnel, so we can't use it for anything
        // else, it will only be released when the client is de-initialized.
        req.connection = null;

        connection.closing = false;

        return connection;
    }) catch {
        // something went wrong with the tunnel
        proxy.supports_connect = maybe_valid;
        return error.TunnelNotSupported;
    };
}

pub const ConnectError = ConnectTcpError || RequestError;

/// Connect to `host:port` using the specified protocol. This will reuse a
/// connection if one is already open.
///
/// If a proxy is configured for the client, then the proxy will be used to
/// connect to the host.
///
/// This function is threadsafe.
pub fn connect(
    client: *Client,
    host: []const u8,
    port: u16,
    protocol: Protocol,
) ConnectError!*Connection {
    const proxy = switch (protocol) {
        .plain => client.http_proxy,
        .tls => client.https_proxy,
    } orelse return client.connectTcp(host, port, protocol);

    // Prevent proxying through itself.
    if (std.ascii.eqlIgnoreCase(proxy.host, host) and
        proxy.port == port and proxy.protocol == protocol)
    {
        return client.connectTcp(host, port, protocol);
    }

    if (proxy.supports_connect) tunnel: {
        return connectProxied(client, proxy, host, port) catch |err| switch (err) {
            error.TunnelNotSupported => break :tunnel,
            else => |e| return e,
        };
    }

    // fall back to using the proxy as a normal http proxy
    const connection = try client.connectTcp(proxy.host, proxy.port, proxy.protocol);
    connection.proxied = true;
    return connection;
}

pub const RequestError = ConnectTcpError || error{
    UnsupportedUriScheme,
    UriMissingHost,
    UriHostTooLong,
    CertificateBundleLoadFailure,
};

pub const RequestOptions = struct {
    version: http.Version = .@"HTTP/1.1",

    /// Automatically ignore 100 Continue responses. This assumes you don't
    /// care, and will have sent the body before you wait for the response.
    ///
    /// If this is not the case AND you know the server will send a 100
    /// Continue, set this to false and wait for a response before sending the
    /// body. If you wait AND the server does not send a 100 Continue before
    /// you finish the request, then the request *will* deadlock.
    handle_continue: bool = true,

    /// If false, close the connection after the one request. If true,
    /// participate in the client connection pool.
    keep_alive: bool = true,

    /// This field specifies whether to automatically follow redirects, and if
    /// so, how many redirects to follow before returning an error.
    ///
    /// This will only follow redirects for repeatable requests (ie. with no
    /// payload or the server has acknowledged the payload).
    redirect_behavior: Request.RedirectBehavior = @enumFromInt(3),

    /// Must be an already acquired connection.
    connection: ?*Connection = null,

    /// Standard headers that have default, but overridable, behavior.
    headers: Request.Headers = .{},
    /// These headers are kept including when following a redirect to a
    /// different domain.
    /// Externally-owned; must outlive the Request.
    extra_headers: []const http.Header = &.{},
    /// These headers are stripped when following a redirect to a different
    /// domain.
    /// Externally-owned; must outlive the Request.
    privileged_headers: []const http.Header = &.{},
};

fn uriPort(uri: Uri, protocol: Protocol) u16 {
    return uri.port orelse protocol.port();
}

/// Open a connection to the host specified by `uri` and prepare to send a HTTP request.
///
/// The caller is responsible for calling `deinit()` on the `Request`.
/// This function is threadsafe.
///
/// Asserts that "\r\n" does not occur in any header name or value.
pub fn request(
    client: *Client,
    method: http.Method,
    uri: Uri,
    options: RequestOptions,
) RequestError!Request {
    if (std.debug.runtime_safety) {
        for (options.extra_headers) |header| {
            assert(header.name.len != 0);
            assert(std.mem.indexOfScalar(u8, header.name, ':') == null);
            assert(std.mem.indexOfPosLinear(u8, header.name, 0, "\r\n") == null);
            assert(std.mem.indexOfPosLinear(u8, header.value, 0, "\r\n") == null);
        }
        for (options.privileged_headers) |header| {
            assert(header.name.len != 0);
            assert(std.mem.indexOfPosLinear(u8, header.name, 0, "\r\n") == null);
            assert(std.mem.indexOfPosLinear(u8, header.value, 0, "\r\n") == null);
        }
    }

    const protocol = Protocol.fromUri(uri) orelse return error.UnsupportedUriScheme;

    if (protocol == .tls) {
        if (disable_tls) unreachable;
        if (@atomicLoad(bool, &client.next_https_rescan_certs, .acquire)) {
            client.ca_bundle_mutex.lock();
            defer client.ca_bundle_mutex.unlock();

            if (client.next_https_rescan_certs) {
                client.ca_bundle.rescan(client.allocator) catch
                    return error.CertificateBundleLoadFailure;
                @atomicStore(bool, &client.next_https_rescan_certs, false, .release);
            }
        }
    }

    const connection = options.connection orelse c: {
        var host_name_buffer: [Uri.host_name_max]u8 = undefined;
        const host_name = try uri.getHost(&host_name_buffer);
        break :c try client.connect(host_name, uriPort(uri, protocol), protocol);
    };

    return .{
        .uri = uri,
        .client = client,
        .connection = connection,
        .reader = .{
            .in = &connection.reader,
            .state = .ready,
        },
        .keep_alive = options.keep_alive,
        .method = method,
        .version = options.version,
        .transfer_encoding = .none,
        .redirect_behavior = options.redirect_behavior,
        .handle_continue = options.handle_continue,
        .headers = options.headers,
        .extra_headers = options.extra_headers,
        .privileged_headers = options.privileged_headers,
    };
}

pub const FetchOptions = struct {
    /// `null` means it will be heap-allocated.
    redirect_buffer: ?[]u8 = null,
    /// `null` means it will be heap-allocated.
    decompress_buffer: ?[]u8 = null,
    redirect_behavior: ?Request.RedirectBehavior = null,
    /// If the server sends a body, it will be stored here.
    response_storage: ?ResponseStorage = null,

    location: Location,
    method: ?http.Method = null,
    payload: ?[]const u8 = null,
    raw_uri: bool = false,
    keep_alive: bool = true,

    /// Standard headers that have default, but overridable, behavior.
    headers: Request.Headers = .{},
    /// These headers are kept including when following a redirect to a
    /// different domain.
    /// Externally-owned; must outlive the Request.
    extra_headers: []const http.Header = &.{},
    /// These headers are stripped when following a redirect to a different
    /// domain.
    /// Externally-owned; must outlive the Request.
    privileged_headers: []const http.Header = &.{},

    pub const Location = union(enum) {
        url: []const u8,
        uri: Uri,
    };

    pub const ResponseStorage = struct {
        list: *std.ArrayListUnmanaged(u8),
        /// If null then only the existing capacity will be used.
        allocator: ?Allocator = null,
        append_limit: std.io.Limit = .unlimited,
    };
};

pub const FetchResult = struct {
    status: http.Status,
};

pub const FetchError = Uri.ParseError || RequestError || Request.ReceiveHeadError || error{
    StreamTooLong,
    /// TODO provide optional diagnostics when this occurs or break into more error codes
    WriteFailed,
};

/// Perform a one-shot HTTP request with the provided options.
///
/// This function is threadsafe.
pub fn fetch(client: *Client, options: FetchOptions) FetchError!FetchResult {
    const uri = switch (options.location) {
        .url => |u| try Uri.parse(u),
        .uri => |u| u,
    };
    const method: http.Method = options.method orelse
        if (options.payload != null) .POST else .GET;

    const redirect_behavior: Request.RedirectBehavior = options.redirect_behavior orelse
        if (options.payload == null) @enumFromInt(3) else .unhandled;

    var req = try request(client, method, uri, .{
        .redirect_behavior = redirect_behavior,
        .headers = options.headers,
        .extra_headers = options.extra_headers,
        .privileged_headers = options.privileged_headers,
        .keep_alive = options.keep_alive,
    });
    defer req.deinit();

    if (options.payload) |payload| {
        req.transfer_encoding = .{ .content_length = payload.len };
        var body = try req.sendBody();
        var bw = body.writer().unbuffered();
        try bw.writeAll(payload);
        try body.end();
    } else {
        try req.sendBodiless();
    }

    const redirect_buffer: []u8 = if (redirect_behavior == .unhandled) &.{} else options.redirect_buffer orelse
        try client.allocator.alloc(u8, 8 * 1024);
    defer if (options.redirect_buffer == null) client.allocator.free(redirect_buffer);

    var response = try req.receiveHead(redirect_buffer);

    const storage = options.response_storage orelse {
        var reader = response.reader();
        _ = reader.discardRemaining() catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
        };
        return .{ .status = response.head.status };
    };

    const decompress_buffer: []u8 = switch (response.head.content_encoding) {
        .identity => &.{},
        .zstd => options.decompress_buffer orelse try client.allocator.alloc(u8, std.compress.zstd.default_window_len),
        else => options.decompress_buffer orelse try client.allocator.alloc(u8, 8 * 1024),
    };
    defer if (options.decompress_buffer == null) client.allocator.free(decompress_buffer);

    var decompressor: http.Decompressor = undefined;
    var reader = response.readerDecompressing(&decompressor, decompress_buffer);
    const list = storage.list;

    if (storage.allocator) |allocator| {
        reader.readRemainingArrayList(allocator, null, list, storage.append_limit, 128) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
            else => |e| return e,
        };
    } else {
        var br = reader.unbuffered();
        const buf = storage.append_limit.slice(list.unusedCapacitySlice());
        list.items.len += br.readSliceShort(buf) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
        };
    }

    return .{ .status = response.head.status };
}

pub fn sameParentDomain(parent_host: []const u8, child_host: []const u8) bool {
    if (!std.ascii.endsWithIgnoreCase(child_host, parent_host)) return false;
    if (child_host.len == parent_host.len) return true;
    if (parent_host.len > child_host.len) return false;
    return child_host[child_host.len - parent_host.len - 1] == '.';
}

test sameParentDomain {
    try testing.expect(!sameParentDomain("foo.com", "bar.com"));
    try testing.expect(sameParentDomain("foo.com", "foo.com"));
    try testing.expect(sameParentDomain("foo.com", "bar.foo.com"));
    try testing.expect(!sameParentDomain("bar.foo.com", "foo.com"));
}

test {
    _ = Response;
}
