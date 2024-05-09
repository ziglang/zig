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
const use_vectors = builtin.zig_backend != .stage2_x86_64;

const Client = @This();
const proto = @import("protocol.zig");

pub const disable_tls = std.options.http_disable_tls;

/// Used for all client allocations. Must be thread-safe.
allocator: Allocator,

ca_bundle: if (disable_tls) void else std.crypto.Certificate.Bundle = if (disable_tls) {} else .{},
ca_bundle_mutex: std.Thread.Mutex = .{},

/// When this is `true`, the next time this client performs an HTTPS request,
/// it will first rescan the system for root certificates.
next_https_rescan_certs: bool = true,

/// The pool of connections that can be reused (and currently in use).
connection_pool: ConnectionPool = .{},

/// If populated, all http traffic travels through this third party.
/// This field cannot be modified while the client has active connections.
/// Pointer to externally-owned memory.
http_proxy: ?*Proxy = null,
/// If populated, all https traffic travels through this third party.
/// This field cannot be modified while the client has active connections.
/// Pointer to externally-owned memory.
https_proxy: ?*Proxy = null,

/// A set of linked lists of connections that can be reused.
pub const ConnectionPool = struct {
    mutex: std.Thread.Mutex = .{},
    /// Open connections that are currently in use.
    used: Queue = .{},
    /// Open connections that are not currently in use.
    free: Queue = .{},
    free_len: usize = 0,
    free_size: usize = 32,

    /// The criteria for a connection to be considered a match.
    pub const Criteria = struct {
        host: []const u8,
        port: u16,
        protocol: Connection.Protocol,
    };

    const Queue = std.DoublyLinkedList(Connection);
    pub const Node = Queue.Node;

    /// Finds and acquires a connection from the connection pool matching the criteria. This function is threadsafe.
    /// If no connection is found, null is returned.
    pub fn findConnection(pool: *ConnectionPool, criteria: Criteria) ?*Connection {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        var next = pool.free.last;
        while (next) |node| : (next = node.prev) {
            if (node.data.protocol != criteria.protocol) continue;
            if (node.data.port != criteria.port) continue;

            // Domain names are case-insensitive (RFC 5890, Section 2.3.2.4)
            if (!std.ascii.eqlIgnoreCase(node.data.host, criteria.host)) continue;

            pool.acquireUnsafe(node);
            return &node.data;
        }

        return null;
    }

    /// Acquires an existing connection from the connection pool. This function is not threadsafe.
    pub fn acquireUnsafe(pool: *ConnectionPool, node: *Node) void {
        pool.free.remove(node);
        pool.free_len -= 1;

        pool.used.append(node);
    }

    /// Acquires an existing connection from the connection pool. This function is threadsafe.
    pub fn acquire(pool: *ConnectionPool, node: *Node) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        return pool.acquireUnsafe(node);
    }

    /// Tries to release a connection back to the connection pool. This function is threadsafe.
    /// If the connection is marked as closing, it will be closed instead.
    ///
    /// The allocator must be the owner of all nodes in this pool.
    /// The allocator must be the owner of all resources associated with the connection.
    pub fn release(pool: *ConnectionPool, allocator: Allocator, connection: *Connection) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        const node: *Node = @fieldParentPtr("data", connection);

        pool.used.remove(node);

        if (node.data.closing or pool.free_size == 0) {
            node.data.close(allocator);
            return allocator.destroy(node);
        }

        if (pool.free_len >= pool.free_size) {
            const popped = pool.free.popFirst() orelse unreachable;
            pool.free_len -= 1;

            popped.data.close(allocator);
            allocator.destroy(popped);
        }

        if (node.data.proxied) {
            pool.free.prepend(node); // proxied connections go to the end of the queue, always try direct connections first
        } else {
            pool.free.append(node);
        }

        pool.free_len += 1;
    }

    /// Adds a newly created node to the pool of used connections. This function is threadsafe.
    pub fn addUsed(pool: *ConnectionPool, node: *Node) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        pool.used.append(node);
    }

    /// Resizes the connection pool. This function is threadsafe.
    ///
    /// If the new size is smaller than the current size, then idle connections will be closed until the pool is the new size.
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

    /// Frees the connection pool and closes all connections within. This function is threadsafe.
    ///
    /// All future operations on the connection pool will deadlock.
    pub fn deinit(pool: *ConnectionPool, allocator: Allocator) void {
        pool.mutex.lock();

        var next = pool.free.first;
        while (next) |node| {
            defer allocator.destroy(node);
            next = node.next;

            node.data.close(allocator);
        }

        next = pool.used.first;
        while (next) |node| {
            defer allocator.destroy(node);
            next = node.next;

            node.data.close(allocator);
        }

        pool.* = undefined;
    }
};

/// An interface to either a plain or TLS connection.
pub const Connection = struct {
    stream: net.Stream,
    /// undefined unless protocol is tls.
    tls_client: if (!disable_tls) *std.crypto.tls.Client else void,

    /// The protocol that this connection is using.
    protocol: Protocol,

    /// The host that this connection is connected to.
    host: []u8,

    /// The port that this connection is connected to.
    port: u16,

    /// Whether this connection is proxied and is not directly connected.
    proxied: bool = false,

    /// Whether this connection is closing when we're done with it.
    closing: bool = false,

    read_start: BufferSize = 0,
    read_end: BufferSize = 0,
    write_end: BufferSize = 0,
    read_buf: [buffer_size]u8 = undefined,
    write_buf: [buffer_size]u8 = undefined,

    pub const buffer_size = std.crypto.tls.max_ciphertext_record_len;
    const BufferSize = std.math.IntFittingRange(0, buffer_size);

    pub const Protocol = enum { plain, tls };

    pub fn readvDirectTls(conn: *Connection, buffers: []std.posix.iovec) ReadError!usize {
        return conn.tls_client.readv(conn.stream, buffers) catch |err| {
            // https://github.com/ziglang/zig/issues/2473
            if (mem.startsWith(u8, @errorName(err), "TlsAlert")) return error.TlsAlert;

            switch (err) {
                error.TlsConnectionTruncated, error.TlsRecordOverflow, error.TlsDecodeError, error.TlsBadRecordMac, error.TlsBadLength, error.TlsIllegalParameter, error.TlsUnexpectedMessage => return error.TlsFailure,
                error.ConnectionTimedOut => return error.ConnectionTimedOut,
                error.ConnectionResetByPeer, error.BrokenPipe => return error.ConnectionResetByPeer,
                else => return error.UnexpectedReadFailure,
            }
        };
    }

    pub fn readvDirect(conn: *Connection, buffers: []std.posix.iovec) ReadError!usize {
        if (conn.protocol == .tls) {
            if (disable_tls) unreachable;

            return conn.readvDirectTls(buffers);
        }

        return conn.stream.readv(buffers) catch |err| switch (err) {
            error.ConnectionTimedOut => return error.ConnectionTimedOut,
            error.ConnectionResetByPeer, error.BrokenPipe => return error.ConnectionResetByPeer,
            else => return error.UnexpectedReadFailure,
        };
    }

    /// Refills the read buffer with data from the connection.
    pub fn fill(conn: *Connection) ReadError!void {
        if (conn.read_end != conn.read_start) return;

        var iovecs = [1]std.posix.iovec{
            .{ .base = &conn.read_buf, .len = conn.read_buf.len },
        };
        const nread = try conn.readvDirect(&iovecs);
        if (nread == 0) return error.EndOfStream;
        conn.read_start = 0;
        conn.read_end = @intCast(nread);
    }

    /// Returns the current slice of buffered data.
    pub fn peek(conn: *Connection) []const u8 {
        return conn.read_buf[conn.read_start..conn.read_end];
    }

    /// Discards the given number of bytes from the read buffer.
    pub fn drop(conn: *Connection, num: BufferSize) void {
        conn.read_start += num;
    }

    /// Reads data from the connection into the given buffer.
    pub fn read(conn: *Connection, buffer: []u8) ReadError!usize {
        const available_read = conn.read_end - conn.read_start;
        const available_buffer = buffer.len;

        if (available_read > available_buffer) { // partially read buffered data
            @memcpy(buffer[0..available_buffer], conn.read_buf[conn.read_start..conn.read_end][0..available_buffer]);
            conn.read_start += @intCast(available_buffer);

            return available_buffer;
        } else if (available_read > 0) { // fully read buffered data
            @memcpy(buffer[0..available_read], conn.read_buf[conn.read_start..conn.read_end]);
            conn.read_start += available_read;

            return available_read;
        }

        var iovecs = [2]std.posix.iovec{
            .{ .base = buffer.ptr, .len = buffer.len },
            .{ .base = &conn.read_buf, .len = conn.read_buf.len },
        };
        const nread = try conn.readvDirect(&iovecs);

        if (nread > buffer.len) {
            conn.read_start = 0;
            conn.read_end = @intCast(nread - buffer.len);
            return buffer.len;
        }

        return nread;
    }

    pub const ReadError = error{
        TlsFailure,
        TlsAlert,
        ConnectionTimedOut,
        ConnectionResetByPeer,
        UnexpectedReadFailure,
        EndOfStream,
    };

    pub const Reader = std.io.Reader(*Connection, ReadError, read);

    pub fn reader(conn: *Connection) Reader {
        return Reader{ .context = conn };
    }

    pub fn writeAllDirectTls(conn: *Connection, buffer: []const u8) WriteError!void {
        return conn.tls_client.writeAll(conn.stream, buffer) catch |err| switch (err) {
            error.BrokenPipe, error.ConnectionResetByPeer => return error.ConnectionResetByPeer,
            else => return error.UnexpectedWriteFailure,
        };
    }

    pub fn writeAllDirect(conn: *Connection, buffer: []const u8) WriteError!void {
        if (conn.protocol == .tls) {
            if (disable_tls) unreachable;

            return conn.writeAllDirectTls(buffer);
        }

        return conn.stream.writeAll(buffer) catch |err| switch (err) {
            error.BrokenPipe, error.ConnectionResetByPeer => return error.ConnectionResetByPeer,
            else => return error.UnexpectedWriteFailure,
        };
    }

    /// Writes the given buffer to the connection.
    pub fn write(conn: *Connection, buffer: []const u8) WriteError!usize {
        if (conn.write_buf.len - conn.write_end < buffer.len) {
            try conn.flush();

            if (buffer.len > conn.write_buf.len) {
                try conn.writeAllDirect(buffer);
                return buffer.len;
            }
        }

        @memcpy(conn.write_buf[conn.write_end..][0..buffer.len], buffer);
        conn.write_end += @intCast(buffer.len);

        return buffer.len;
    }

    /// Returns a buffer to be filled with exactly len bytes to write to the connection.
    pub fn allocWriteBuffer(conn: *Connection, len: BufferSize) WriteError![]u8 {
        if (conn.write_buf.len - conn.write_end < len) try conn.flush();
        defer conn.write_end += len;
        return conn.write_buf[conn.write_end..][0..len];
    }

    /// Flushes the write buffer to the connection.
    pub fn flush(conn: *Connection) WriteError!void {
        if (conn.write_end == 0) return;

        try conn.writeAllDirect(conn.write_buf[0..conn.write_end]);
        conn.write_end = 0;
    }

    pub const WriteError = error{
        ConnectionResetByPeer,
        UnexpectedWriteFailure,
    };

    pub const Writer = std.io.Writer(*Connection, WriteError, write);

    pub fn writer(conn: *Connection) Writer {
        return Writer{ .context = conn };
    }

    /// Closes the connection.
    pub fn close(conn: *Connection, allocator: Allocator) void {
        if (conn.protocol == .tls) {
            if (disable_tls) unreachable;

            // try to cleanly close the TLS connection, for any server that cares.
            _ = conn.tls_client.writeEnd(conn.stream, "", true) catch {};
            allocator.destroy(conn.tls_client);
        }

        conn.stream.close();
        allocator.free(conn.host);
    }
};

/// The mode of transport for requests.
pub const RequestTransfer = union(enum) {
    content_length: u64,
    chunked: void,
    none: void,
};

/// The decompressor for response messages.
pub const Compression = union(enum) {
    pub const DeflateDecompressor = std.compress.zlib.Decompressor(Request.TransferReader);
    pub const GzipDecompressor = std.compress.gzip.Decompressor(Request.TransferReader);
    // https://github.com/ziglang/zig/issues/18937
    //pub const ZstdDecompressor = std.compress.zstd.DecompressStream(Request.TransferReader, .{});

    deflate: DeflateDecompressor,
    gzip: GzipDecompressor,
    // https://github.com/ziglang/zig/issues/18937
    //zstd: ZstdDecompressor,
    none: void,
};

/// A HTTP response originating from a server.
pub const Response = struct {
    version: http.Version,
    status: http.Status,
    reason: []const u8,

    /// Points into the user-provided `server_header_buffer`.
    location: ?[]const u8 = null,
    /// Points into the user-provided `server_header_buffer`.
    content_type: ?[]const u8 = null,
    /// Points into the user-provided `server_header_buffer`.
    content_disposition: ?[]const u8 = null,

    keep_alive: bool,

    /// If present, the number of bytes in the response body.
    content_length: ?u64 = null,

    /// If present, the transfer encoding of the response body, otherwise none.
    transfer_encoding: http.TransferEncoding = .none,

    /// If present, the compression of the response body, otherwise identity (no compression).
    transfer_compression: http.ContentEncoding = .identity,

    parser: proto.HeadersParser,
    compression: Compression = .none,

    /// Whether the response body should be skipped. Any data read from the
    /// response body will be discarded.
    skip: bool = false,

    pub const ParseError = error{
        HttpHeadersInvalid,
        HttpHeaderContinuationsUnsupported,
        HttpTransferEncodingUnsupported,
        HttpConnectionHeaderUnsupported,
        InvalidContentLength,
        CompressionUnsupported,
    };

    pub fn parse(res: *Response, bytes: []const u8) ParseError!void {
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
            if (line.len == 0) return;
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

        var header_buffer: [1024]u8 = undefined;
        var res = Response{
            .status = undefined,
            .reason = undefined,
            .version = undefined,
            .keep_alive = false,
            .parser = proto.HeadersParser.init(&header_buffer),
        };

        @memcpy(header_buffer[0..response_bytes.len], response_bytes);
        res.parser.header_bytes_len = response_bytes.len;

        try res.parse(response_bytes);

        try testing.expectEqual(.@"HTTP/1.1", res.version);
        try testing.expectEqualStrings("OK", res.reason);
        try testing.expectEqual(.ok, res.status);

        try testing.expectEqualStrings("url", res.location.?);
        try testing.expectEqualStrings("text/plain", res.content_type.?);
        try testing.expectEqualStrings("attachment; filename=example.txt", res.content_disposition.?);

        try testing.expectEqual(true, res.keep_alive);
        try testing.expectEqual(10, res.content_length.?);
        try testing.expectEqual(.chunked, res.transfer_encoding);
        try testing.expectEqual(.deflate, res.transfer_compression);
    }

    inline fn int64(array: *const [8]u8) u64 {
        return @bitCast(array.*);
    }

    fn parseInt3(text: *const [3]u8) u10 {
        if (use_vectors) {
            const nnn: @Vector(3, u8) = text.*;
            const zero: @Vector(3, u8) = .{ '0', '0', '0' };
            const mmm: @Vector(3, u10) = .{ 100, 10, 1 };
            return @reduce(.Add, @as(@Vector(3, u10), nnn -% zero) *% mmm);
        }
        return std.fmt.parseInt(u10, text, 10) catch unreachable;
    }

    test parseInt3 {
        const expectEqual = testing.expectEqual;
        try expectEqual(@as(u10, 0), parseInt3("000"));
        try expectEqual(@as(u10, 418), parseInt3("418"));
        try expectEqual(@as(u10, 999), parseInt3("999"));
    }

    pub fn iterateHeaders(r: Response) http.HeaderIterator {
        return http.HeaderIterator.init(r.parser.get());
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
            .parser = proto.HeadersParser.init(&header_buffer),
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
};

/// A HTTP request that has been sent.
///
/// Order of operations: open -> send[ -> write -> finish] -> wait -> read
pub const Request = struct {
    uri: Uri,
    client: *Client,
    /// This is null when the connection is released.
    connection: ?*Connection,
    keep_alive: bool,

    method: http.Method,
    version: http.Version = .@"HTTP/1.1",
    transfer_encoding: RequestTransfer,
    redirect_behavior: RedirectBehavior,

    /// Whether the request should handle a 100-continue response before sending the request body.
    handle_continue: bool,

    /// The response associated with this request.
    ///
    /// This field is undefined until `wait` is called.
    response: Response,

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

    // This function must deallocate all resources associated with the request,
    // or keep those which will be used.
    // This needs to be kept in sync with deinit and request.
    fn redirect(req: *Request, uri: Uri) !void {
        assert(req.response.parser.done);

        req.client.connection_pool.release(req.client.allocator, req.connection.?);
        req.connection = null;

        var server_header = std.heap.FixedBufferAllocator.init(req.response.parser.header_bytes_buffer);
        defer req.response.parser.header_bytes_buffer = server_header.buffer[server_header.end_index..];
        const protocol, const valid_uri = try validateUri(uri, server_header.allocator());

        const new_host = valid_uri.host.?.raw;
        const prev_host = req.uri.host.?.raw;
        const keep_privileged_headers =
            std.ascii.eqlIgnoreCase(valid_uri.scheme, req.uri.scheme) and
            std.ascii.endsWithIgnoreCase(new_host, prev_host) and
            (new_host.len == prev_host.len or new_host[new_host.len - prev_host.len - 1] == '.');
        if (!keep_privileged_headers) {
            // When redirecting to a different domain, strip privileged headers.
            req.privileged_headers = &.{};
        }

        if (switch (req.response.status) {
            .see_other => true,
            .moved_permanently, .found => req.method == .POST,
            else => false,
        }) {
            // A redirect to a GET must change the method and remove the body.
            req.method = .GET;
            req.transfer_encoding = .none;
            req.headers.content_type = .omit;
        }

        if (req.transfer_encoding != .none) {
            // The request body has already been sent. The request is
            // still in a valid state, but the redirect must be handled
            // manually.
            return error.RedirectRequiresResend;
        }

        req.uri = valid_uri;
        req.connection = try req.client.connect(new_host, uriPort(valid_uri, protocol), protocol);
        req.redirect_behavior.subtractOne();
        req.response.parser.reset();

        req.response = .{
            .version = undefined,
            .status = undefined,
            .reason = undefined,
            .keep_alive = undefined,
            .parser = req.response.parser,
        };
    }

    pub const SendError = Connection.WriteError || error{ InvalidContentLength, UnsupportedTransferEncoding };

    /// Send the HTTP request headers to the server.
    pub fn send(req: *Request) SendError!void {
        if (!req.method.requestHasBody() and req.transfer_encoding != .none)
            return error.UnsupportedTransferEncoding;

        const connection = req.connection.?;
        const w = connection.writer();

        try req.method.write(w);
        try w.writeByte(' ');

        if (req.method == .CONNECT) {
            try req.uri.writeToStream(.{ .authority = true }, w);
        } else {
            try req.uri.writeToStream(.{
                .scheme = connection.proxied,
                .authentication = connection.proxied,
                .authority = connection.proxied,
                .path = true,
                .query = true,
            }, w);
        }
        try w.writeByte(' ');
        try w.writeAll(@tagName(req.version));
        try w.writeAll("\r\n");

        if (try emitOverridableHeader("host: ", req.headers.host, w)) {
            try w.writeAll("host: ");
            try req.uri.writeToStream(.{ .authority = true }, w);
            try w.writeAll("\r\n");
        }

        if (try emitOverridableHeader("authorization: ", req.headers.authorization, w)) {
            if (req.uri.user != null or req.uri.password != null) {
                try w.writeAll("authorization: ");
                const authorization = try connection.allocWriteBuffer(
                    @intCast(basic_authorization.valueLengthFromUri(req.uri)),
                );
                assert(basic_authorization.value(req.uri, authorization).len == authorization.len);
                try w.writeAll("\r\n");
            }
        }

        if (try emitOverridableHeader("user-agent: ", req.headers.user_agent, w)) {
            try w.writeAll("user-agent: zig/");
            try w.writeAll(builtin.zig_version_string);
            try w.writeAll(" (std.http)\r\n");
        }

        if (try emitOverridableHeader("connection: ", req.headers.connection, w)) {
            if (req.keep_alive) {
                try w.writeAll("connection: keep-alive\r\n");
            } else {
                try w.writeAll("connection: close\r\n");
            }
        }

        if (try emitOverridableHeader("accept-encoding: ", req.headers.accept_encoding, w)) {
            // https://github.com/ziglang/zig/issues/18937
            //try w.writeAll("accept-encoding: gzip, deflate, zstd\r\n");
            try w.writeAll("accept-encoding: gzip, deflate\r\n");
        }

        switch (req.transfer_encoding) {
            .chunked => try w.writeAll("transfer-encoding: chunked\r\n"),
            .content_length => |len| try w.print("content-length: {d}\r\n", .{len}),
            .none => {},
        }

        if (try emitOverridableHeader("content-type: ", req.headers.content_type, w)) {
            // The default is to omit content-type if not provided because
            // "application/octet-stream" is redundant.
        }

        for (req.extra_headers) |header| {
            assert(header.name.len != 0);

            try w.writeAll(header.name);
            try w.writeAll(": ");
            try w.writeAll(header.value);
            try w.writeAll("\r\n");
        }

        if (connection.proxied) proxy: {
            const proxy = switch (connection.protocol) {
                .plain => req.client.http_proxy,
                .tls => req.client.https_proxy,
            } orelse break :proxy;

            const authorization = proxy.authorization orelse break :proxy;
            try w.writeAll("proxy-authorization: ");
            try w.writeAll(authorization);
            try w.writeAll("\r\n");
        }

        try w.writeAll("\r\n");

        try connection.flush();
    }

    /// Returns true if the default behavior is required, otherwise handles
    /// writing (or not writing) the header.
    fn emitOverridableHeader(prefix: []const u8, v: Headers.Value, w: anytype) !bool {
        switch (v) {
            .default => return true,
            .omit => return false,
            .override => |x| {
                try w.writeAll(prefix);
                try w.writeAll(x);
                try w.writeAll("\r\n");
                return false;
            },
        }
    }

    const TransferReadError = Connection.ReadError || proto.HeadersParser.ReadError;

    const TransferReader = std.io.Reader(*Request, TransferReadError, transferRead);

    fn transferReader(req: *Request) TransferReader {
        return .{ .context = req };
    }

    fn transferRead(req: *Request, buf: []u8) TransferReadError!usize {
        if (req.response.parser.done) return 0;

        var index: usize = 0;
        while (index == 0) {
            const amt = try req.response.parser.read(req.connection.?, buf[index..], req.response.skip);
            if (amt == 0 and req.response.parser.done) break;
            index += amt;
        }

        return index;
    }

    pub const WaitError = RequestError || SendError || TransferReadError ||
        proto.HeadersParser.CheckCompleteHeadError || Response.ParseError ||
        error{ // TODO: file zig fmt issue for this bad indentation
        TooManyHttpRedirects,
        RedirectRequiresResend,
        HttpRedirectLocationMissing,
        HttpRedirectLocationInvalid,
        CompressionInitializationFailed,
        CompressionUnsupported,
    };

    /// Waits for a response from the server and parses any headers that are sent.
    /// This function will block until the final response is received.
    ///
    /// If handling redirects and the request has no payload, then this
    /// function will automatically follow redirects. If a request payload is
    /// present, then this function will error with
    /// error.RedirectRequiresResend.
    ///
    /// Must be called after `send` and, if any data was written to the request
    /// body, then also after `finish`.
    pub fn wait(req: *Request) WaitError!void {
        while (true) {
            // This while loop is for handling redirects, which means the request's
            // connection may be different than the previous iteration. However, it
            // is still guaranteed to be non-null with each iteration of this loop.
            const connection = req.connection.?;

            while (true) { // read headers
                try connection.fill();

                const nchecked = try req.response.parser.checkCompleteHead(connection.peek());
                connection.drop(@intCast(nchecked));

                if (req.response.parser.state.isContent()) break;
            }

            try req.response.parse(req.response.parser.get());

            if (req.response.status == .@"continue") {
                // We're done parsing the continue response; reset to prepare
                // for the real response.
                req.response.parser.done = true;
                req.response.parser.reset();

                if (req.handle_continue)
                    continue;

                return; // we're not handling the 100-continue
            }

            // we're switching protocols, so this connection is no longer doing http
            if (req.method == .CONNECT and req.response.status.class() == .success) {
                connection.closing = false;
                req.response.parser.done = true;
                return; // the connection is not HTTP past this point
            }

            connection.closing = !req.response.keep_alive or !req.keep_alive;

            // Any response to a HEAD request and any response with a 1xx
            // (Informational), 204 (No Content), or 304 (Not Modified) status
            // code is always terminated by the first empty line after the
            // header fields, regardless of the header fields present in the
            // message.
            if (req.method == .HEAD or req.response.status.class() == .informational or
                req.response.status == .no_content or req.response.status == .not_modified)
            {
                req.response.parser.done = true;
                return; // The response is empty; no further setup or redirection is necessary.
            }

            switch (req.response.transfer_encoding) {
                .none => {
                    if (req.response.content_length) |cl| {
                        req.response.parser.next_chunk_length = cl;

                        if (cl == 0) req.response.parser.done = true;
                    } else {
                        // read until the connection is closed
                        req.response.parser.next_chunk_length = std.math.maxInt(u64);
                    }
                },
                .chunked => {
                    req.response.parser.next_chunk_length = 0;
                    req.response.parser.state = .chunk_head_size;
                },
            }

            if (req.response.status.class() == .redirect and req.redirect_behavior != .unhandled) {
                // skip the body of the redirect response, this will at least
                // leave the connection in a known good state.
                req.response.skip = true;
                assert(try req.transferRead(&.{}) == 0); // we're skipping, no buffer is necessary

                if (req.redirect_behavior == .not_allowed) return error.TooManyHttpRedirects;

                const location = req.response.location orelse
                    return error.HttpRedirectLocationMissing;

                // This mutates the beginning of header_bytes_buffer and uses that
                // for the backing memory of the returned Uri.
                try req.redirect(req.uri.resolve_inplace(
                    location,
                    &req.response.parser.header_bytes_buffer,
                ) catch |err| switch (err) {
                    error.UnexpectedCharacter,
                    error.InvalidFormat,
                    error.InvalidPort,
                    => return error.HttpRedirectLocationInvalid,
                    error.NoSpaceLeft => return error.HttpHeadersOversize,
                });
                try req.send();
            } else {
                req.response.skip = false;
                if (!req.response.parser.done) {
                    switch (req.response.transfer_compression) {
                        .identity => req.response.compression = .none,
                        .compress, .@"x-compress" => return error.CompressionUnsupported,
                        .deflate => req.response.compression = .{
                            .deflate = std.compress.zlib.decompressor(req.transferReader()),
                        },
                        .gzip, .@"x-gzip" => req.response.compression = .{
                            .gzip = std.compress.gzip.decompressor(req.transferReader()),
                        },
                        // https://github.com/ziglang/zig/issues/18937
                        //.zstd => req.response.compression = .{
                        //    .zstd = std.compress.zstd.decompressStream(req.client.allocator, req.transferReader()),
                        //},
                        .zstd => return error.CompressionUnsupported,
                    }
                }

                break;
            }
        }
    }

    pub const ReadError = TransferReadError || proto.HeadersParser.CheckCompleteHeadError ||
        error{ DecompressionFailure, InvalidTrailers };

    pub const Reader = std.io.Reader(*Request, ReadError, read);

    pub fn reader(req: *Request) Reader {
        return .{ .context = req };
    }

    /// Reads data from the response body. Must be called after `wait`.
    pub fn read(req: *Request, buffer: []u8) ReadError!usize {
        const out_index = switch (req.response.compression) {
            .deflate => |*deflate| deflate.read(buffer) catch return error.DecompressionFailure,
            .gzip => |*gzip| gzip.read(buffer) catch return error.DecompressionFailure,
            // https://github.com/ziglang/zig/issues/18937
            //.zstd => |*zstd| zstd.read(buffer) catch return error.DecompressionFailure,
            else => try req.transferRead(buffer),
        };
        if (out_index > 0) return out_index;

        while (!req.response.parser.state.isContent()) { // read trailing headers
            try req.connection.?.fill();

            const nchecked = try req.response.parser.checkCompleteHead(req.connection.?.peek());
            req.connection.?.drop(@intCast(nchecked));
        }

        return 0;
    }

    /// Reads data from the response body. Must be called after `wait`.
    pub fn readAll(req: *Request, buffer: []u8) !usize {
        var index: usize = 0;
        while (index < buffer.len) {
            const amt = try read(req, buffer[index..]);
            if (amt == 0) break;
            index += amt;
        }
        return index;
    }

    pub const WriteError = Connection.WriteError || error{ NotWriteable, MessageTooLong };

    pub const Writer = std.io.Writer(*Request, WriteError, write);

    pub fn writer(req: *Request) Writer {
        return .{ .context = req };
    }

    /// Write `bytes` to the server. The `transfer_encoding` field determines how data will be sent.
    /// Must be called after `send` and before `finish`.
    pub fn write(req: *Request, bytes: []const u8) WriteError!usize {
        switch (req.transfer_encoding) {
            .chunked => {
                if (bytes.len > 0) {
                    try req.connection.?.writer().print("{x}\r\n", .{bytes.len});
                    try req.connection.?.writer().writeAll(bytes);
                    try req.connection.?.writer().writeAll("\r\n");
                }

                return bytes.len;
            },
            .content_length => |*len| {
                if (len.* < bytes.len) return error.MessageTooLong;

                const amt = try req.connection.?.write(bytes);
                len.* -= amt;
                return amt;
            },
            .none => return error.NotWriteable,
        }
    }

    /// Write `bytes` to the server. The `transfer_encoding` field determines how data will be sent.
    /// Must be called after `send` and before `finish`.
    pub fn writeAll(req: *Request, bytes: []const u8) WriteError!void {
        var index: usize = 0;
        while (index < bytes.len) {
            index += try write(req, bytes[index..]);
        }
    }

    pub const FinishError = WriteError || error{MessageNotCompleted};

    /// Finish the body of a request. This notifies the server that you have no more data to send.
    /// Must be called after `send`.
    pub fn finish(req: *Request) FinishError!void {
        switch (req.transfer_encoding) {
            .chunked => try req.connection.?.writer().writeAll("0\r\n\r\n"),
            .content_length => |len| if (len != 0) return error.MessageNotCompleted,
            .none => {},
        }

        try req.connection.?.flush();
    }
};

pub const Proxy = struct {
    protocol: Connection.Protocol,
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

    client.connection_pool.deinit(client.allocator);

    if (!disable_tls)
        client.ca_bundle.deinit(client.allocator);

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
        break std.process.getEnvVarOwned(arena, name) catch |err| switch (err) {
            error.EnvironmentVariableNotFound => continue,
            else => |e| return e,
        };
    } else return null;

    const uri = Uri.parse(content) catch try Uri.parseAfterScheme("http", content);
    const protocol, const valid_uri = validateUri(uri, arena) catch |err| switch (err) {
        error.UnsupportedUriScheme => return null,
        error.UriMissingHost => return error.HttpProxyMissingHost,
        error.OutOfMemory => |e| return e,
    };

    const authorization: ?[]const u8 = if (valid_uri.user != null or valid_uri.password != null) a: {
        const authorization = try arena.alloc(u8, basic_authorization.valueLengthFromUri(valid_uri));
        assert(basic_authorization.value(valid_uri, authorization).len == authorization.len);
        break :a authorization;
    } else null;

    const proxy = try arena.create(Proxy);
    proxy.* = .{
        .protocol = protocol,
        .host = valid_uri.host.?.raw,
        .authorization = authorization,
        .port = uriPort(valid_uri, protocol),
        .supports_connect = true,
    };
    return proxy;
}

pub const basic_authorization = struct {
    pub const max_user_len = 255;
    pub const max_password_len = 255;
    pub const max_value_len = valueLength(max_user_len, max_password_len);

    const prefix = "Basic ";

    pub fn valueLength(user_len: usize, password_len: usize) usize {
        return prefix.len + std.base64.standard.Encoder.calcSize(user_len + 1 + password_len);
    }

    pub fn valueLengthFromUri(uri: Uri) usize {
        var stream = std.io.countingWriter(std.io.null_writer);
        try stream.writer().print("{user}", .{uri.user orelse Uri.Component.empty});
        const user_len = stream.bytes_written;
        stream.bytes_written = 0;
        try stream.writer().print("{password}", .{uri.password orelse Uri.Component.empty});
        const password_len = stream.bytes_written;
        return valueLength(@intCast(user_len), @intCast(password_len));
    }

    pub fn value(uri: Uri, out: []u8) []u8 {
        var buf: [max_user_len + ":".len + max_password_len]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buf);
        stream.writer().print("{user}", .{uri.user orelse Uri.Component.empty}) catch
            unreachable;
        assert(stream.pos <= max_user_len);
        stream.writer().print(":{password}", .{uri.password orelse Uri.Component.empty}) catch
            unreachable;

        @memcpy(out[0..prefix.len], prefix);
        const base64 = std.base64.standard.Encoder.encode(out[prefix.len..], stream.getWritten());
        return out[0 .. prefix.len + base64.len];
    }
};

pub const ConnectTcpError = Allocator.Error || error{ ConnectionRefused, NetworkUnreachable, ConnectionTimedOut, ConnectionResetByPeer, TemporaryNameServerFailure, NameServerFailure, UnknownHostName, HostLacksNetworkAddresses, UnexpectedConnectFailure, TlsInitializationFailed };

/// Connect to `host:port` using the specified protocol. This will reuse a connection if one is already open.
///
/// This function is threadsafe.
pub fn connectTcp(client: *Client, host: []const u8, port: u16, protocol: Connection.Protocol) ConnectTcpError!*Connection {
    if (client.connection_pool.findConnection(.{
        .host = host,
        .port = port,
        .protocol = protocol,
    })) |node| return node;

    if (disable_tls and protocol == .tls)
        return error.TlsInitializationFailed;

    const conn = try client.allocator.create(ConnectionPool.Node);
    errdefer client.allocator.destroy(conn);
    conn.* = .{ .data = undefined };

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

    conn.data = .{
        .stream = stream,
        .tls_client = undefined,

        .protocol = protocol,
        .host = try client.allocator.dupe(u8, host),
        .port = port,
    };
    errdefer client.allocator.free(conn.data.host);

    if (protocol == .tls) {
        if (disable_tls) unreachable;

        conn.data.tls_client = try client.allocator.create(std.crypto.tls.Client);
        errdefer client.allocator.destroy(conn.data.tls_client);

        conn.data.tls_client.* = std.crypto.tls.Client.init(stream, client.ca_bundle, host) catch return error.TlsInitializationFailed;
        // This is appropriate for HTTPS because the HTTP headers contain
        // the content length which is used to detect truncation attacks.
        conn.data.tls_client.allow_truncation_attacks = true;
    }

    client.connection_pool.addUsed(conn);

    return &conn.data;
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
    protocol: Connection.Protocol,
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

pub const RequestError = ConnectTcpError || ConnectErrorPartial || Request.SendError ||
    std.fmt.ParseIntError || Connection.WriteError ||
    error{ // TODO: file a zig fmt issue for this bad indentation
    UnsupportedUriScheme,
    UriMissingHost,

    CertificateBundleLoadFailure,
    UnsupportedTransferEncoding,
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

    /// Externally-owned memory used to store the server's entire HTTP header.
    /// `error.HttpHeadersOversize` is returned from read() when a
    /// client sends too many bytes of HTTP headers.
    server_header_buffer: []u8,

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

fn validateUri(uri: Uri, arena: Allocator) !struct { Connection.Protocol, Uri } {
    const protocol_map = std.StaticStringMap(Connection.Protocol).initComptime(.{
        .{ "http", .plain },
        .{ "ws", .plain },
        .{ "https", .tls },
        .{ "wss", .tls },
    });
    const protocol = protocol_map.get(uri.scheme) orelse return error.UnsupportedUriScheme;
    var valid_uri = uri;
    // The host is always going to be needed as a raw string for hostname resolution anyway.
    valid_uri.host = .{
        .raw = try (uri.host orelse return error.UriMissingHost).toRawMaybeAlloc(arena),
    };
    return .{ protocol, valid_uri };
}

fn uriPort(uri: Uri, protocol: Connection.Protocol) u16 {
    return uri.port orelse switch (protocol) {
        .plain => 80,
        .tls => 443,
    };
}

/// Open a connection to the host specified by `uri` and prepare to send a HTTP request.
///
/// `uri` must remain alive during the entire request.
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

    var server_header = std.heap.FixedBufferAllocator.init(options.server_header_buffer);
    const protocol, const valid_uri = try validateUri(uri, server_header.allocator());

    if (protocol == .tls and @atomicLoad(bool, &client.next_https_rescan_certs, .acquire)) {
        if (disable_tls) unreachable;

        client.ca_bundle_mutex.lock();
        defer client.ca_bundle_mutex.unlock();

        if (client.next_https_rescan_certs) {
            client.ca_bundle.rescan(client.allocator) catch
                return error.CertificateBundleLoadFailure;
            @atomicStore(bool, &client.next_https_rescan_certs, false, .release);
        }
    }

    const conn = options.connection orelse
        try client.connect(valid_uri.host.?.raw, uriPort(valid_uri, protocol), protocol);

    var req: Request = .{
        .uri = valid_uri,
        .client = client,
        .connection = conn,
        .keep_alive = options.keep_alive,
        .method = method,
        .version = options.version,
        .transfer_encoding = .none,
        .redirect_behavior = options.redirect_behavior,
        .handle_continue = options.handle_continue,
        .response = .{
            .version = undefined,
            .status = undefined,
            .reason = undefined,
            .keep_alive = undefined,
            .parser = proto.HeadersParser.init(server_header.buffer[server_header.end_index..]),
        },
        .headers = options.headers,
        .extra_headers = options.extra_headers,
        .privileged_headers = options.privileged_headers,
    };
    errdefer req.deinit();

    return req;
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

    if (options.payload) |payload| try req.writeAll(payload);

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

test {
    _ = &initDefaultProxies;
}
