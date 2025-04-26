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
ssl_key_logger: ?*std.io.BufferedWriter = null,

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
            if (!std.ascii.eqlIgnoreCase(connection.host, criteria.host)) continue;

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
    pub fn release(pool: *ConnectionPool, allocator: Allocator, connection: *Connection) void {
        if (connection.closing) return connection.destroy();

        pool.mutex.lock();
        defer pool.mutex.unlock();

        pool.used.remove(&connection.pool_node);

        if (pool.free_size == 0) return connection.destroy();

        if (pool.free_len >= pool.free_size) {
            const popped: *Connection = @fieldParentPtr("pool_node", pool.free.popFirst().?);
            pool.free_len -= 1;

            popped.close(allocator);
            allocator.destroy(popped);
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
    stream: net.Stream,
    /// HTTP protocol from client to server.
    /// This either goes directly to `stream`, or to a TLS client.
    writer: std.io.BufferedWriter,
    /// Entry in `ConnectionPool.used` or `ConnectionPool.free`.
    pool_node: std.DoublyLinkedList.Node,
    port: u16,
    host_len: u8,
    proxied: bool,
    closing: bool,
    protocol: Protocol,

    const Plain = struct {
        /// Data from `Connection.stream`.
        reader: std.io.BufferedReader,
        connection: Connection,

        fn create(
            client: *Client,
            remote_host: []const u8,
            port: u16,
            stream: net.Stream,
        ) error{OutOfMemory}!*Connection {
            const gpa = client.allocator;
            const alloc_len = allocLen(client, remote_host.len);
            const base = try gpa.alignedAlloc(u8, .of(Plain), alloc_len);
            errdefer gpa.free(base);
            const host_buffer = base[@sizeOf(Plain)..][0..remote_host.len];
            const socket_read_buffer = host_buffer.ptr[host_buffer.len..][0..client.read_buffer_size];
            const socket_write_buffer = socket_read_buffer.ptr[socket_read_buffer.len..][0..client.write_buffer_size];
            assert(base.ptr + alloc_len == socket_read_buffer.ptr + socket_read_buffer.len);
            @memcpy(host_buffer, remote_host);
            const plain: *Plain = @ptrCast(base);
            plain.* = .{
                .connection = .{
                    .client = client,
                    .stream = stream,
                    .writer = stream.writer().buffered(socket_write_buffer),
                    .pool_node = .{},
                    .port = port,
                    .proxied = false,
                    .closing = false,
                    .protocol = .plain,
                },
                .reader = undefined,
            };
            plain.reader.init(stream.reader(), socket_read_buffer);
        }

        fn destroy(plain: *Plain) void {
            const c = &plain.connection;
            const gpa = c.client.allocator;
            const base: [*]u8 = @ptrCast(plain);
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
                    .stream = stream,
                    .writer = tls.client.writer().buffered(socket_write_buffer),
                    .pool_node = .{},
                    .port = port,
                    .proxied = false,
                    .closing = false,
                    .protocol = .tls,
                },
                .writer = stream.writer().buffered(tls_write_buffer),
                .reader = undefined,
                .client = undefined,
            };
            tls.reader.init(stream.reader(), tls_read_buffer);
            // TODO data race here on ca_bundle if the user sets next_https_rescan_certs to true
            tls.client.init(&tls.reader, &tls.writer, .{
                .host = .{ .explicit = remote_host },
                .ca = .{ .bundle = client.ca_bundle },
                .ssl_key_logger = client.ssl_key_logger,
            }) catch return error.TlsInitializationFailed;
            // This is appropriate for HTTPS because the HTTP headers contain
            // the content length which is used to detect truncation attacks.
            tls.client.allow_truncation_attacks = true;

            return tls;
        }

        fn destroy(tls: *Tls) void {
            const c = &tls.connection;
            const gpa = c.client.allocator;
            const base: [*]u8 = @ptrCast(tls);
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

    /// This is either data from `stream`, or `Tls.client`.
    fn reader(c: *Connection) *std.io.BufferedReader {
        return switch (c.protocol) {
            .tls => {
                if (disable_tls) unreachable;
                const tls: *Tls = @fieldParentPtr("connection", c);
                return &tls.client.reader;
            },
            .plain => {
                const plain: *Plain = @fieldParentPtr("connection", c);
                return &plain.reader;
            },
        };
    }

    /// If this is called without calling `flush` or `end`, data will be
    /// dropped unsent.
    pub fn destroy(c: *Connection) void {
        c.stream.close();
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

/// The decompressor for response messages.
pub const Compression = union(enum) {
    pub const DeflateDecompressor = std.compress.zlib.Decompressor;
    pub const GzipDecompressor = std.compress.gzip.Decompressor;
    // https://github.com/ziglang/zig/issues/18937
    //pub const ZstdDecompressor = std.compress.zstd.DecompressStream(.{});

    deflate: DeflateDecompressor,
    gzip: GzipDecompressor,
    // https://github.com/ziglang/zig/issues/18937
    //zstd: ZstdDecompressor,
    none: void,
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
        transfer_compression: http.ContentEncoding = .identity,

        compression: Compression = .none,

        pub const ParseError = error{
            HttpHeadersInvalid,
            HttpHeaderContinuationsUnsupported,
            HttpTransferEncodingUnsupported,
            HttpConnectionHeaderUnsupported,
            InvalidContentLength,
            CompressionUnsupported,
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

                        if (std.meta.stringToEnum(http.ContentEncoding, trimmed_second)) |transfer| {
                            if (res.transfer_compression != .identity) return error.HttpHeadersInvalid; // double compression is not supported
                            res.transfer_compression = transfer;
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
                    if (res.transfer_compression != .identity) return error.HttpHeadersInvalid;

                    const trimmed = mem.trim(u8, header_value, " ");

                    if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                        res.transfer_compression = ce;
                    } else {
                        return error.HttpTransferEncodingUnsupported;
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

            const head = Head.parse(response_bytes);

            try testing.expectEqual(.@"HTTP/1.1", head.version);
            try testing.expectEqualStrings("OK", head.reason);
            try testing.expectEqual(.ok, head.status);

            try testing.expectEqualStrings("url", head.location.?);
            try testing.expectEqualStrings("text/plain", head.content_type.?);
            try testing.expectEqualStrings("attachment; filename=example.txt", head.content_disposition.?);

            try testing.expectEqual(true, head.keep_alive);
            try testing.expectEqual(10, head.content_length.?);
            try testing.expectEqual(.chunked, head.transfer_encoding);
            try testing.expectEqual(.deflate, head.transfer_compression);
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

            var header_buffer: [1024]u8 = undefined;
            var res = Response{
                .status = undefined,
                .reason = undefined,
                .version = undefined,
                .keep_alive = false,
                .parser = .init(&header_buffer),
            };

            @memcpy(header_buffer[0..response_bytes.len], response_bytes);
            res.parser.header_bytes_len = response_bytes.len;

            var it = res.iterateHeaders();
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

    /// Asserts that this function is only called once.
    pub fn reader(response: *Response) std.io.Reader {
        const head = &response.head;
        return response.request.reader.interface(head.transfer_encoding, head.content_length);
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

    /// Frees all resources associated with the request.
    pub fn deinit(req: *Request) void {
        if (req.connection) |connection| {
            if (!req.response.parser.done) {
                // If the response wasn't fully read, then we need to close the connection.
                connection.closing = true;
            }
            req.client.connection_pool.release(req.client.allocator, connection);
        }
        req.* = undefined;
    }

    /// Sends and flushes a complete request as only HTTP head, no body.
    pub fn sendBodiless(r: *Request) std.io.Writer.Error!void {
        try sendBodilessUnflushed(r);
        try r.connection.?.writer.flush();
    }

    /// Sends but does not flush a complete request as only HTTP head, no body.
    pub fn sendBodilessUnflushed(r: *Request) std.io.Writer.Error!void {
        assert(r.transfer_encoding == .none);
        assert(!r.method.requestHasBody());
        try sendHead(r);
    }

    /// Transfers the HTTP head over the connection, which is not flushed until
    /// `BodyWriter.flush` or `BodyWriter.end` is called.
    pub fn sendBody(r: *Request) std.io.Writer.Error!http.BodyWriter {
        assert(r.method.requestHasBody());
        try sendHead(r);
        return .{
            .http_protocol_output = &r.connection.?.writer,
            .transfer_encoding = if (r.transfer_encoding) |te| switch (te) {
                .chunked => .{ .chunked = .init },
                .content_length => |len| .{ .content_length = len },
                .none => .none,
            } else .{ .chunked = .init },
            .elide_body = false,
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
            // https://github.com/ziglang/zig/issues/18937
            //try w.writeAll("accept-encoding: gzip, deflate, zstd\r\n");
            try w.writeAll("accept-encoding: gzip, deflate\r\n");
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

    pub const ReceiveHeadError = http.Reader.HeadError || error{
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
        CompressionInitializationFailed,
        CompressionUnsupported,
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
                return; // we're not handling the 100-continue
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
                if (r.redirect_behavior == .not_allowed) return error.TooManyHttpRedirects;
                const location = head.location orelse return error.HttpRedirectLocationMissing;
                try r.redirect(location, &aux_buf);
                try r.send();
                continue;
            }

            switch (head.transfer_compression) {
                .identity => response.compression = .none,
                .compress, .@"x-compress" => return error.CompressionUnsupported,
                .deflate => response.compression = .{
                    .deflate = std.compress.zlib.decompressor(r.transferReader()),
                },
                .gzip, .@"x-gzip" => response.compression = .{
                    .gzip = std.compress.gzip.decompressor(r.transferReader()),
                },
                // https://github.com/ziglang/zig/issues/18937
                //.zstd => response.compression = .{
                //    .zstd = std.compress.zstd.decompressStream(r.client.allocator, r.transferReader()),
                //},
                .zstd => return error.CompressionUnsupported,
            }
            return response;
        }
    }

    pub const RedirectError = error{
        HttpRedirectLocationOversize,
        HttpRedirectLocationInvalid,
    };

    /// This function takes an auxiliary buffer to store the arbitrarily large
    /// URI which may need to be merged with the previous URI, and that data
    /// needs to survive across different connections, which is where the input
    /// buffer lives.
    ///
    /// `aux_buf` must outlive accesses to `Request.uri`.
    fn redirect(r: *Request, new_location: []const u8, aux_buf: *[]u8) RedirectError!void {
        if (new_location.len > aux_buf.*.len) return error.HttpRedirectLocationOversize;
        const location = aux_buf.*[0..new_location.len];
        @memcpy(location, new_location);
        {
            // Skip the body of the redirect response to leave the connection in
            // the correct state. This causes `new_location` to be invalidated.
            var reader = r.reader.interface();
            _ = reader.discardRemaining() catch |err| switch (err) {
                error.ReadFailed => return r.reader.err.?,
            };
        }
        const new_uri = r.uri.resolveInPlace(location.len, aux_buf) catch |err| switch (err) {
            error.UnexpectedCharacter => return error.HttpRedirectLocationInvalid,
            error.InvalidFormat => return error.HttpRedirectLocationInvalid,
            error.InvalidPort => return error.HttpRedirectLocationInvalid,
            error.NoSpaceLeft => return error.HttpRedirectLocationOversize,
        };
        const resolved_len = location.len + (aux_buf.*.ptr - location.ptr);

        const protocol = Protocol.fromUri(new_uri) orelse return error.UnsupportedUriScheme;
        const old_connection = r.connection.?;
        const old_host = old_connection.host();
        var new_host_name_buffer: [Uri.host_name_max]u8 = undefined;
        const new_host = try new_uri.getHost(&new_host_name_buffer);
        const keep_privileged_headers =
            std.ascii.eqlIgnoreCase(r.uri.scheme, new_uri.scheme) and
            sameParentDomain(old_host, new_host);

        r.client.connection_pool.release(r.client.allocator, old_connection);
        r.connection = null;

        if (!keep_privileged_headers) {
            // When redirecting to a different domain, strip privileged headers.
            r.privileged_headers = &.{};
        }

        if (switch (r.response.status) {
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
        r.stolen_bytes_len = resolved_len;
        r.connection = new_connection;
        r.redirect_behavior.subtractOne();
    }

    /// Returns true if the default behavior is required, otherwise handles
    /// writing (or not writing) the header.
    fn emitOverridableHeader(prefix: []const u8, v: Headers.Value, bw: *std.io.BufferedWriter) std.io.Writer.Error!bool {
        switch (v) {
            .default => return true,
            .omit => return false,
            .override => |x| {
                try bw.writeAll(prefix);
                try bw.writeAll(x);
                try bw.writeAll("\r\n");
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
    if (client.connection_pool.findConnection(.{
        .host = host,
        .port = port,
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
            const tc = try Connection.Tls.create(client, host, port, stream);
            client.connection_pool.addUsed(&tc.connection);
            return &tc.connection;
        },
        .plain => {
            const pc = try Connection.Plain.create(client, host, port, stream);
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

/// Connect to `tunnel_host:tunnel_port` using the specified proxy with HTTP
/// CONNECT. This will reuse a connection if one is already open.
///
/// This function is threadsafe.
pub fn connectTunnel(
    client: *Client,
    proxy: *Proxy,
    tunnel_host: []const u8,
    tunnel_port: u16,
) !*Connection {
    if (!proxy.supports_connect) return error.TunnelNotSupported;

    if (client.connection_pool.findConnection(.{
        .host = tunnel_host,
        .port = tunnel_port,
        .protocol = proxy.protocol,
    })) |node|
        return node;

    var maybe_valid = false;
    (tunnel: {
        const conn = try client.connectTcp(proxy.host, proxy.port, proxy.protocol);
        errdefer {
            conn.closing = true;
            client.connection_pool.release(client.allocator, conn);
        }

        var buffer: [8096]u8 = undefined;
        var req = client.open(.CONNECT, .{
            .scheme = "http",
            .host = .{ .raw = tunnel_host },
            .port = tunnel_port,
        }, .{
            .redirect_behavior = .unhandled,
            .connection = conn,
            .server_header_buffer = &buffer,
        }) catch |err| {
            std.log.debug("err {}", .{err});
            break :tunnel err;
        };
        defer req.deinit();

        req.send() catch |err| break :tunnel err;
        req.wait() catch |err| break :tunnel err;

        if (req.response.status.class() == .server_error) {
            maybe_valid = true;
            break :tunnel error.ServerError;
        }

        if (req.response.status != .ok) break :tunnel error.ConnectionRefused;

        // this connection is now a tunnel, so we can't use it for anything else, it will only be released when the client is de-initialized.
        req.connection = null;

        client.allocator.free(conn.host);
        conn.host = try client.allocator.dupe(u8, tunnel_host);
        errdefer client.allocator.free(conn.host);

        conn.port = tunnel_port;
        conn.closing = false;

        return conn;
    }) catch {
        // something went wrong with the tunnel
        proxy.supports_connect = maybe_valid;
        return error.TunnelNotSupported;
    };
}

// Prevents a dependency loop in open()
const ConnectErrorPartial = ConnectTcpError || error{ UnsupportedUriScheme, ConnectionRefused };
pub const ConnectError = ConnectErrorPartial || RequestError;

/// Connect to `host:port` using the specified protocol. This will reuse a
/// connection if one is already open.
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
        return connectTunnel(client, proxy, host, port) catch |err| switch (err) {
            error.TunnelNotSupported => break :tunnel,
            else => |e| return e,
        };
    }

    // fall back to using the proxy as a normal http proxy
    const conn = try client.connectTcp(proxy.host, proxy.port, proxy.protocol);
    errdefer {
        conn.closing = true;
        client.connection_pool.release(conn);
    }

    conn.proxied = true;
    return conn;
}

/// TODO collapse each error set into its own meta error code, and store
/// the underlying error code as a field on Request
pub const RequestError = ConnectTcpError || ConnectErrorPartial || std.io.Writer.Error || std.fmt.ParseIntError ||
    error{
        UnsupportedUriScheme,
        UriMissingHost,
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
pub fn open(
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
    server_header_buffer: ?[]u8 = null,
    redirect_behavior: ?Request.RedirectBehavior = null,

    /// If the server sends a body, it will be appended to this ArrayList.
    /// `max_append_size` provides an upper limit for how much they can grow.
    response_storage: ResponseStorage = .ignore,
    max_append_size: ?usize = null,

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

    pub const ResponseStorage = union(enum) {
        ignore,
        /// Only the existing capacity will be used.
        static: *std.ArrayListUnmanaged(u8),
        dynamic: *std.ArrayList(u8),
    };
};

pub const FetchResult = struct {
    status: http.Status,
};

/// Perform a one-shot HTTP request with the provided options.
///
/// This function is threadsafe.
pub fn fetch(client: *Client, options: FetchOptions) !FetchResult {
    const uri = switch (options.location) {
        .url => |u| try Uri.parse(u),
        .uri => |u| u,
    };
    var server_header_buffer: [16 * 1024]u8 = undefined;

    const method: http.Method = options.method orelse
        if (options.payload != null) .POST else .GET;

    var req = try open(client, method, uri, .{
        .server_header_buffer = options.server_header_buffer orelse &server_header_buffer,
        .redirect_behavior = options.redirect_behavior orelse
            if (options.payload == null) @enumFromInt(3) else .unhandled,
        .headers = options.headers,
        .extra_headers = options.extra_headers,
        .privileged_headers = options.privileged_headers,
        .keep_alive = options.keep_alive,
    });
    defer req.deinit();

    if (options.payload) |payload| req.transfer_encoding = .{ .content_length = payload.len };

    try req.send();

    if (options.payload) |payload| {
        var w = req.writer().unbuffered();
        try w.writeAll(payload);
    }

    try req.finish();
    try req.wait();

    switch (options.response_storage) {
        .ignore => {
            // Take advantage of request internals to discard the response body
            // and make the connection available for another request.
            req.response.skip = true;
            assert(try req.transferRead(&.{}) == 0); // No buffer is necessary when skipping.
        },
        .dynamic => |list| {
            const max_append_size = options.max_append_size orelse 2 * 1024 * 1024;
            try req.reader().readAllArrayList(list, max_append_size);
        },
        .static => |list| {
            const buf = b: {
                const buf = list.unusedCapacitySlice();
                if (options.max_append_size) |len| {
                    if (len < buf.len) break :b buf[0..len];
                }
                break :b buf;
            };
            list.items.len += try req.reader().readAll(buf);
        },
    }

    return .{
        .status = req.response.status,
    };
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
