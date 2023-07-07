//! Connecting and opening requests are threadsafe. Individual requests are not.

const std = @import("../std.zig");
const testing = std.testing;
const http = std.http;
const mem = std.mem;
const net = std.net;
const Uri = std.Uri;
const Allocator = mem.Allocator;
const assert = std.debug.assert;

const Client = @This();
const proto = @import("protocol.zig");

pub const default_connection_pool_size = 32;
pub const connection_pool_size = std.options.http_connection_pool_size;

allocator: Allocator,
ca_bundle: std.crypto.Certificate.Bundle = .{},
ca_bundle_mutex: std.Thread.Mutex = .{},
/// When this is `true`, the next time this client performs an HTTPS request,
/// it will first rescan the system for root certificates.
next_https_rescan_certs: bool = true,

/// The pool of connections that can be reused (and currently in use).
connection_pool: ConnectionPool = .{},

proxy: ?HttpProxy = null,

/// A set of linked lists of connections that can be reused.
pub const ConnectionPool = struct {
    /// The criteria for a connection to be considered a match.
    pub const Criteria = struct {
        host: []const u8,
        port: u16,
        is_tls: bool,
    };

    const Queue = std.TailQueue(Connection);
    pub const Node = Queue.Node;

    mutex: std.Thread.Mutex = .{},
    /// Open connections that are currently in use.
    used: Queue = .{},
    /// Open connections that are not currently in use.
    free: Queue = .{},
    free_len: usize = 0,
    free_size: usize = connection_pool_size,

    /// Finds and acquires a connection from the connection pool matching the criteria. This function is threadsafe.
    /// If no connection is found, null is returned.
    pub fn findConnection(pool: *ConnectionPool, criteria: Criteria) ?*Node {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        var next = pool.free.last;
        while (next) |node| : (next = node.prev) {
            if ((node.data.protocol == .tls) != criteria.is_tls) continue;
            if (node.data.port != criteria.port) continue;
            if (!mem.eql(u8, node.data.host, criteria.host)) continue;

            pool.acquireUnsafe(node);
            return node;
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
    pub fn release(pool: *ConnectionPool, client: *Client, node: *Node) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        pool.used.remove(node);

        if (node.data.closing) {
            node.data.deinit(client);
            return client.allocator.destroy(node);
        }

        if (pool.free_len >= pool.free_size) {
            const popped = pool.free.popFirst() orelse unreachable;
            pool.free_len -= 1;

            popped.data.deinit(client);
            client.allocator.destroy(popped);
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

    pub fn deinit(pool: *ConnectionPool, client: *Client) void {
        pool.mutex.lock();

        var next = pool.free.first;
        while (next) |node| {
            defer client.allocator.destroy(node);
            next = node.next;

            node.data.deinit(client);
        }

        next = pool.used.first;
        while (next) |node| {
            defer client.allocator.destroy(node);
            next = node.next;

            node.data.deinit(client);
        }

        pool.* = undefined;
    }
};

/// An interface to either a plain or TLS connection.
pub const Connection = struct {
    pub const buffer_size = std.crypto.tls.max_ciphertext_record_len;
    pub const Protocol = enum { plain, tls };

    stream: net.Stream,
    /// undefined unless protocol is tls.
    tls_client: *std.crypto.tls.Client,

    protocol: Protocol,
    host: []u8,
    port: u16,

    proxied: bool = false,
    closing: bool = false,

    read_start: u16 = 0,
    read_end: u16 = 0,
    read_buf: [buffer_size]u8 = undefined,

    pub fn rawReadAtLeast(conn: *Connection, buffer: []u8, len: usize) ReadError!usize {
        return switch (conn.protocol) {
            .plain => conn.stream.readAtLeast(buffer, len),
            .tls => conn.tls_client.readAtLeast(conn.stream, buffer, len),
        } catch |err| {
            // TODO: https://github.com/ziglang/zig/issues/2473
            if (mem.startsWith(u8, @errorName(err), "TlsAlert")) return error.TlsAlert;

            switch (err) {
                error.TlsConnectionTruncated, error.TlsRecordOverflow, error.TlsDecodeError, error.TlsBadRecordMac, error.TlsBadLength, error.TlsIllegalParameter, error.TlsUnexpectedMessage => return error.TlsFailure,
                error.ConnectionTimedOut => return error.ConnectionTimedOut,
                error.ConnectionResetByPeer, error.BrokenPipe => return error.ConnectionResetByPeer,
                else => return error.UnexpectedReadFailure,
            }
        };
    }

    pub fn fill(conn: *Connection) ReadError!void {
        if (conn.read_end != conn.read_start) return;

        const nread = try conn.rawReadAtLeast(conn.read_buf[0..], 1);
        if (nread == 0) return error.EndOfStream;
        conn.read_start = 0;
        conn.read_end = @as(u16, @intCast(nread));
    }

    pub fn peek(conn: *Connection) []const u8 {
        return conn.read_buf[conn.read_start..conn.read_end];
    }

    pub fn drop(conn: *Connection, num: u16) void {
        conn.read_start += num;
    }

    pub fn readAtLeast(conn: *Connection, buffer: []u8, len: usize) ReadError!usize {
        assert(len <= buffer.len);

        var out_index: u16 = 0;
        while (out_index < len) {
            const available_read = conn.read_end - conn.read_start;
            const available_buffer = buffer.len - out_index;

            if (available_read > available_buffer) { // partially read buffered data
                @memcpy(buffer[out_index..], conn.read_buf[conn.read_start..conn.read_end][0..available_buffer]);
                out_index += @as(u16, @intCast(available_buffer));
                conn.read_start += @as(u16, @intCast(available_buffer));

                break;
            } else if (available_read > 0) { // fully read buffered data
                @memcpy(buffer[out_index..][0..available_read], conn.read_buf[conn.read_start..conn.read_end]);
                out_index += available_read;
                conn.read_start += available_read;

                if (out_index >= len) break;
            }

            const leftover_buffer = available_buffer - available_read;
            const leftover_len = len - out_index;

            if (leftover_buffer > conn.read_buf.len) {
                // skip the buffer if the output is large enough
                return conn.rawReadAtLeast(buffer[out_index..], leftover_len);
            }

            try conn.fill();
        }

        return out_index;
    }

    pub fn read(conn: *Connection, buffer: []u8) ReadError!usize {
        return conn.readAtLeast(buffer, 1);
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

    pub fn writeAll(conn: *Connection, buffer: []const u8) !void {
        return switch (conn.protocol) {
            .plain => conn.stream.writeAll(buffer),
            .tls => conn.tls_client.writeAll(conn.stream, buffer),
        } catch |err| switch (err) {
            error.BrokenPipe, error.ConnectionResetByPeer => return error.ConnectionResetByPeer,
            else => return error.UnexpectedWriteFailure,
        };
    }

    pub fn write(conn: *Connection, buffer: []const u8) !usize {
        return switch (conn.protocol) {
            .plain => conn.stream.write(buffer),
            .tls => conn.tls_client.write(conn.stream, buffer),
        } catch |err| switch (err) {
            error.BrokenPipe, error.ConnectionResetByPeer => return error.ConnectionResetByPeer,
            else => return error.UnexpectedWriteFailure,
        };
    }

    pub const WriteError = error{
        ConnectionResetByPeer,
        UnexpectedWriteFailure,
    };

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
    }

    pub fn deinit(conn: *Connection, client: *const Client) void {
        conn.close(client);
        client.allocator.free(conn.host);
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
    pub const DeflateDecompressor = std.compress.zlib.DecompressStream(Request.TransferReader);
    pub const GzipDecompressor = std.compress.gzip.Decompress(Request.TransferReader);
    pub const ZstdDecompressor = std.compress.zstd.DecompressStream(Request.TransferReader, .{});

    deflate: DeflateDecompressor,
    gzip: GzipDecompressor,
    zstd: ZstdDecompressor,
    none: void,
};

/// A HTTP response originating from a server.
pub const Response = struct {
    pub const ParseError = Allocator.Error || error{
        HttpHeadersInvalid,
        HttpHeaderContinuationsUnsupported,
        HttpTransferEncodingUnsupported,
        HttpConnectionHeaderUnsupported,
        InvalidContentLength,
        CompressionNotSupported,
    };

    pub fn parse(res: *Response, bytes: []const u8, trailing: bool) ParseError!void {
        var it = mem.tokenizeAny(u8, bytes[0 .. bytes.len - 4], "\r\n");

        const first_line = it.next() orelse return error.HttpHeadersInvalid;
        if (first_line.len < 12)
            return error.HttpHeadersInvalid;

        const version: http.Version = switch (int64(first_line[0..8])) {
            int64("HTTP/1.0") => .@"HTTP/1.0",
            int64("HTTP/1.1") => .@"HTTP/1.1",
            else => return error.HttpHeadersInvalid,
        };
        if (first_line[8] != ' ') return error.HttpHeadersInvalid;
        const status = @as(http.Status, @enumFromInt(parseInt3(first_line[9..12].*)));
        const reason = mem.trimLeft(u8, first_line[12..], " ");

        res.version = version;
        res.status = status;
        res.reason = reason;

        while (it.next()) |line| {
            if (line.len == 0) return error.HttpHeadersInvalid;
            switch (line[0]) {
                ' ', '\t' => return error.HttpHeaderContinuationsUnsupported,
                else => {},
            }

            var line_it = mem.tokenizeAny(u8, line, ": ");
            const header_name = line_it.next() orelse return error.HttpHeadersInvalid;
            const header_value = line_it.rest();

            try res.headers.append(header_name, header_value);

            if (trailing) continue;

            if (std.ascii.eqlIgnoreCase(header_name, "content-length")) {
                if (res.content_length != null) return error.HttpHeadersInvalid;
                res.content_length = std.fmt.parseInt(u64, header_value, 10) catch return error.InvalidContentLength;
            } else if (std.ascii.eqlIgnoreCase(header_name, "transfer-encoding")) {
                // Transfer-Encoding: second, first
                // Transfer-Encoding: deflate, chunked
                var iter = mem.splitBackwardsScalar(u8, header_value, ',');

                if (iter.next()) |first| {
                    const trimmed = mem.trim(u8, first, " ");

                    if (std.meta.stringToEnum(http.TransferEncoding, trimmed)) |te| {
                        if (res.transfer_encoding != null) return error.HttpHeadersInvalid;
                        res.transfer_encoding = te;
                    } else if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                        if (res.transfer_compression != null) return error.HttpHeadersInvalid;
                        res.transfer_compression = ce;
                    } else {
                        return error.HttpTransferEncodingUnsupported;
                    }
                }

                if (iter.next()) |second| {
                    if (res.transfer_compression != null) return error.HttpTransferEncodingUnsupported;

                    const trimmed = mem.trim(u8, second, " ");

                    if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                        res.transfer_compression = ce;
                    } else {
                        return error.HttpTransferEncodingUnsupported;
                    }
                }

                if (iter.next()) |_| return error.HttpTransferEncodingUnsupported;
            } else if (std.ascii.eqlIgnoreCase(header_name, "content-encoding")) {
                if (res.transfer_compression != null) return error.HttpHeadersInvalid;

                const trimmed = mem.trim(u8, header_value, " ");

                if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                    res.transfer_compression = ce;
                } else {
                    return error.HttpTransferEncodingUnsupported;
                }
            }
        }
    }

    inline fn int64(array: *const [8]u8) u64 {
        return @as(u64, @bitCast(array.*));
    }

    fn parseInt3(nnn: @Vector(3, u8)) u10 {
        const zero: @Vector(3, u8) = .{ '0', '0', '0' };
        const mmm: @Vector(3, u10) = .{ 100, 10, 1 };
        return @reduce(.Add, @as(@Vector(3, u10), nnn -% zero) *% mmm);
    }

    test parseInt3 {
        const expectEqual = testing.expectEqual;
        try expectEqual(@as(u10, 0), parseInt3("000".*));
        try expectEqual(@as(u10, 418), parseInt3("418".*));
        try expectEqual(@as(u10, 999), parseInt3("999".*));
    }

    version: http.Version,
    status: http.Status,
    reason: []const u8,

    content_length: ?u64 = null,
    transfer_encoding: ?http.TransferEncoding = null,
    transfer_compression: ?http.ContentEncoding = null,

    headers: http.Headers,
    parser: proto.HeadersParser,
    compression: Compression = .none,
    skip: bool = false,
};

/// A HTTP request that has been sent.
///
/// Order of operations: request -> start[ -> write -> finish] -> wait -> read
pub const Request = struct {
    uri: Uri,
    client: *Client,
    /// is null when this connection is released
    connection: ?*ConnectionPool.Node,

    method: http.Method,
    version: http.Version = .@"HTTP/1.1",
    headers: http.Headers,
    transfer_encoding: RequestTransfer = .none,

    redirects_left: u32,
    handle_redirects: bool,

    response: Response,

    /// Used as a allocator for resolving redirects locations.
    arena: std.heap.ArenaAllocator,

    /// Frees all resources associated with the request.
    pub fn deinit(req: *Request) void {
        switch (req.response.compression) {
            .none => {},
            .deflate => |*deflate| deflate.deinit(),
            .gzip => |*gzip| gzip.deinit(),
            .zstd => |*zstd| zstd.deinit(),
        }

        req.response.headers.deinit();

        if (req.response.parser.header_bytes_owned) {
            req.response.parser.header_bytes.deinit(req.client.allocator);
        }

        if (req.connection) |connection| {
            if (!req.response.parser.done) {
                // If the response wasn't fully read, then we need to close the connection.
                connection.data.closing = true;
            }
            req.client.connection_pool.release(req.client, connection);
        }

        req.arena.deinit();
        req.* = undefined;
    }

    // This function must deallocate all resources associated with the request, or keep those which will be used
    // This needs to be kept in sync with deinit and request
    fn redirect(req: *Request, uri: Uri) !void {
        assert(req.response.parser.done);

        switch (req.response.compression) {
            .none => {},
            .deflate => |*deflate| deflate.deinit(),
            .gzip => |*gzip| gzip.deinit(),
            .zstd => |*zstd| zstd.deinit(),
        }

        req.client.connection_pool.release(req.client, req.connection.?);
        req.connection = null;

        const protocol = protocol_map.get(uri.scheme) orelse return error.UnsupportedUrlScheme;

        const port: u16 = uri.port orelse switch (protocol) {
            .plain => 80,
            .tls => 443,
        };

        const host = uri.host orelse return error.UriMissingHost;

        req.uri = uri;
        req.connection = try req.client.connect(host, port, protocol);
        req.redirects_left -= 1;
        req.response.headers.clearRetainingCapacity();
        req.response.parser.reset();

        req.response = .{
            .status = undefined,
            .reason = undefined,
            .version = undefined,
            .headers = req.response.headers,
            .parser = req.response.parser,
        };
    }

    pub const StartError = Connection.WriteError || error{ InvalidContentLength, UnsupportedTransferEncoding };

    /// Send the request to the server.
    pub fn start(req: *Request) StartError!void {
        var buffered = std.io.bufferedWriter(req.connection.?.data.writer());
        const w = buffered.writer();

        try w.writeAll(@tagName(req.method));
        try w.writeByte(' ');

        if (req.method == .CONNECT) {
            try w.writeAll(req.uri.host.?);
            try w.writeByte(':');
            try w.print("{}", .{req.uri.port.?});
        } else if (req.connection.?.data.proxied) {
            // proxied connections require the full uri
            try w.print("{+/}", .{req.uri});
        } else {
            try w.print("{/}", .{req.uri});
        }

        try w.writeByte(' ');
        try w.writeAll(@tagName(req.version));
        try w.writeAll("\r\n");

        if (!req.headers.contains("host")) {
            try w.writeAll("Host: ");
            try w.writeAll(req.uri.host.?);
            try w.writeAll("\r\n");
        }

        if (!req.headers.contains("user-agent")) {
            try w.writeAll("User-Agent: zig/");
            try w.writeAll(@import("builtin").zig_version_string);
            try w.writeAll(" (std.http)\r\n");
        }

        if (!req.headers.contains("connection")) {
            try w.writeAll("Connection: keep-alive\r\n");
        }

        if (!req.headers.contains("accept-encoding")) {
            try w.writeAll("Accept-Encoding: gzip, deflate, zstd\r\n");
        }

        if (!req.headers.contains("te")) {
            try w.writeAll("TE: gzip, deflate, trailers\r\n");
        }

        const has_transfer_encoding = req.headers.contains("transfer-encoding");
        const has_content_length = req.headers.contains("content-length");

        if (!has_transfer_encoding and !has_content_length) {
            switch (req.transfer_encoding) {
                .chunked => try w.writeAll("Transfer-Encoding: chunked\r\n"),
                .content_length => |content_length| try w.print("Content-Length: {d}\r\n", .{content_length}),
                .none => {},
            }
        } else {
            if (has_content_length) {
                const content_length = std.fmt.parseInt(u64, req.headers.getFirstValue("content-length").?, 10) catch return error.InvalidContentLength;

                req.transfer_encoding = .{ .content_length = content_length };
            } else if (has_transfer_encoding) {
                const transfer_encoding = req.headers.getFirstValue("transfer-encoding").?;
                if (std.mem.eql(u8, transfer_encoding, "chunked")) {
                    req.transfer_encoding = .chunked;
                } else {
                    return error.UnsupportedTransferEncoding;
                }
            } else {
                req.transfer_encoding = .none;
            }
        }

        try w.print("{}", .{req.headers});

        try w.writeAll("\r\n");

        try buffered.flush();
    }

    pub const TransferReadError = Connection.ReadError || proto.HeadersParser.ReadError;

    pub const TransferReader = std.io.Reader(*Request, TransferReadError, transferRead);

    pub fn transferReader(req: *Request) TransferReader {
        return .{ .context = req };
    }

    pub fn transferRead(req: *Request, buf: []u8) TransferReadError!usize {
        if (req.response.parser.done) return 0;

        var index: usize = 0;
        while (index == 0) {
            const amt = try req.response.parser.read(&req.connection.?.data, buf[index..], req.response.skip);
            if (amt == 0 and req.response.parser.done) break;
            index += amt;
        }

        return index;
    }

    pub const WaitError = RequestError || StartError || TransferReadError || proto.HeadersParser.CheckCompleteHeadError || Response.ParseError || Uri.ParseError || error{ TooManyHttpRedirects, CannotRedirect, HttpRedirectMissingLocation, CompressionInitializationFailed, CompressionNotSupported };

    /// Waits for a response from the server and parses any headers that are sent.
    /// This function will block until the final response is received.
    ///
    /// If `handle_redirects` is true and the request has no payload, then this function will automatically follow
    /// redirects. If a request payload is present, then this function will error with error.CannotRedirect.
    pub fn wait(req: *Request) WaitError!void {
        while (true) { // handle redirects
            while (true) { // read headers
                try req.connection.?.data.fill();

                const nchecked = try req.response.parser.checkCompleteHead(req.client.allocator, req.connection.?.data.peek());
                req.connection.?.data.drop(@as(u16, @intCast(nchecked)));

                if (req.response.parser.state.isContent()) break;
            }

            try req.response.parse(req.response.parser.header_bytes.items, false);

            if (req.response.status == .switching_protocols) {
                req.connection.?.data.closing = false;
                req.response.parser.done = true;
            }

            if (req.method == .CONNECT and req.response.status == .ok) {
                req.connection.?.data.closing = false;
                req.response.parser.done = true;
            }

            // we default to using keep-alive if not provided
            const req_connection = req.headers.getFirstValue("connection");
            const req_keepalive = req_connection != null and !std.ascii.eqlIgnoreCase("close", req_connection.?);

            const res_connection = req.response.headers.getFirstValue("connection");
            const res_keepalive = res_connection != null and !std.ascii.eqlIgnoreCase("close", res_connection.?);
            if (res_keepalive and (req_keepalive or req_connection == null)) {
                req.connection.?.data.closing = false;
            } else {
                req.connection.?.data.closing = true;
            }

            if (req.response.transfer_encoding) |te| {
                switch (te) {
                    .chunked => {
                        req.response.parser.next_chunk_length = 0;
                        req.response.parser.state = .chunk_head_size;
                    },
                }
            } else if (req.response.content_length) |cl| {
                req.response.parser.next_chunk_length = cl;

                if (cl == 0) req.response.parser.done = true;
            } else {
                req.response.parser.done = true;
            }

            // HEAD requests have no body
            if (req.method == .HEAD) {
                req.response.parser.done = true;
            }

            if (req.transfer_encoding == .none and req.response.status.class() == .redirect and req.handle_redirects) {
                req.response.skip = true;

                const empty = @as([*]u8, undefined)[0..0];
                assert(try req.transferRead(empty) == 0); // we're skipping, no buffer is necessary

                if (req.redirects_left == 0) return error.TooManyHttpRedirects;

                const location = req.response.headers.getFirstValue("location") orelse
                    return error.HttpRedirectMissingLocation;

                const arena = req.arena.allocator();

                const location_duped = try arena.dupe(u8, location);

                const new_url = Uri.parse(location_duped) catch try Uri.parseWithoutScheme(location_duped);
                const resolved_url = try req.uri.resolve(new_url, false, arena);

                try req.redirect(resolved_url);

                try req.start();
            } else {
                req.response.skip = false;
                if (!req.response.parser.done) {
                    if (req.response.transfer_compression) |tc| switch (tc) {
                        .compress => return error.CompressionNotSupported,
                        .deflate => req.response.compression = .{
                            .deflate = std.compress.zlib.decompressStream(req.client.allocator, req.transferReader()) catch return error.CompressionInitializationFailed,
                        },
                        .gzip => req.response.compression = .{
                            .gzip = std.compress.gzip.decompress(req.client.allocator, req.transferReader()) catch return error.CompressionInitializationFailed,
                        },
                        .zstd => req.response.compression = .{
                            .zstd = std.compress.zstd.decompressStream(req.client.allocator, req.transferReader()),
                        },
                    };
                }

                if (req.response.status.class() == .redirect and req.handle_redirects and req.transfer_encoding != .none)
                    return error.CannotRedirect; // The request body has already been sent. The request is still in a valid state, but the redirect must be handled manually.

                break;
            }
        }
    }

    pub const ReadError = TransferReadError || proto.HeadersParser.CheckCompleteHeadError || error{ DecompressionFailure, InvalidTrailers };

    pub const Reader = std.io.Reader(*Request, ReadError, read);

    pub fn reader(req: *Request) Reader {
        return .{ .context = req };
    }

    /// Reads data from the response body. Must be called after `do`.
    pub fn read(req: *Request, buffer: []u8) ReadError!usize {
        const out_index = switch (req.response.compression) {
            .deflate => |*deflate| deflate.read(buffer) catch return error.DecompressionFailure,
            .gzip => |*gzip| gzip.read(buffer) catch return error.DecompressionFailure,
            .zstd => |*zstd| zstd.read(buffer) catch return error.DecompressionFailure,
            else => try req.transferRead(buffer),
        };

        if (out_index == 0) {
            const has_trail = !req.response.parser.state.isContent();

            while (!req.response.parser.state.isContent()) { // read trailing headers
                try req.connection.?.data.fill();

                const nchecked = try req.response.parser.checkCompleteHead(req.client.allocator, req.connection.?.data.peek());
                req.connection.?.data.drop(@as(u16, @intCast(nchecked)));
            }

            if (has_trail) {
                req.response.headers.clearRetainingCapacity();

                // The response headers before the trailers are already guaranteed to be valid, so they will always be parsed again and cannot return an error.
                // This will *only* fail for a malformed trailer.
                req.response.parse(req.response.parser.header_bytes.items, true) catch return error.InvalidTrailers;
            }
        }

        return out_index;
    }

    /// Reads data from the response body. Must be called after `do`.
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

    /// Write `bytes` to the server. The `transfer_encoding` request header determines how data will be sent.
    pub fn write(req: *Request, bytes: []const u8) WriteError!usize {
        switch (req.transfer_encoding) {
            .chunked => {
                try req.connection.?.data.writer().print("{x}\r\n", .{bytes.len});
                try req.connection.?.data.writeAll(bytes);
                try req.connection.?.data.writeAll("\r\n");

                return bytes.len;
            },
            .content_length => |*len| {
                if (len.* < bytes.len) return error.MessageTooLong;

                const amt = try req.connection.?.data.write(bytes);
                len.* -= amt;
                return amt;
            },
            .none => return error.NotWriteable,
        }
    }

    pub fn writeAll(req: *Request, bytes: []const u8) WriteError!void {
        var index: usize = 0;
        while (index < bytes.len) {
            index += try write(req, bytes[index..]);
        }
    }

    pub const FinishError = WriteError || error{MessageNotCompleted};

    /// Finish the body of a request. This notifies the server that you have no more data to send.
    pub fn finish(req: *Request) FinishError!void {
        switch (req.transfer_encoding) {
            .chunked => try req.connection.?.data.writeAll("0\r\n\r\n"),
            .content_length => |len| if (len != 0) return error.MessageNotCompleted,
            .none => {},
        }
    }
};

pub const HttpProxy = struct {
    pub const ProxyAuthentication = union(enum) {
        basic: []const u8,
        custom: []const u8,
    };

    protocol: Connection.Protocol,
    host: []const u8,
    port: ?u16 = null,

    /// The value for the Proxy-Authorization header.
    auth: ?ProxyAuthentication = null,
};

/// Release all associated resources with the client.
/// TODO: currently leaks all request allocated data
pub fn deinit(client: *Client) void {
    client.connection_pool.deinit(client);

    client.ca_bundle.deinit(client.allocator);
    client.* = undefined;
}

pub const ConnectUnproxiedError = Allocator.Error || error{ ConnectionRefused, NetworkUnreachable, ConnectionTimedOut, ConnectionResetByPeer, TemporaryNameServerFailure, NameServerFailure, UnknownHostName, HostLacksNetworkAddresses, UnexpectedConnectFailure, TlsInitializationFailed };

/// Connect to `host:port` using the specified protocol. This will reuse a connection if one is already open.
/// This function is threadsafe.
pub fn connectUnproxied(client: *Client, host: []const u8, port: u16, protocol: Connection.Protocol) ConnectUnproxiedError!*ConnectionPool.Node {
    if (client.connection_pool.findConnection(.{
        .host = host,
        .port = port,
        .is_tls = protocol == .tls,
    })) |node|
        return node;

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

    switch (protocol) {
        .plain => {},
        .tls => {
            conn.data.tls_client = try client.allocator.create(std.crypto.tls.Client);
            errdefer client.allocator.destroy(conn.data.tls_client);

            conn.data.tls_client.* = std.crypto.tls.Client.init(stream, client.ca_bundle, host) catch return error.TlsInitializationFailed;
            // This is appropriate for HTTPS because the HTTP headers contain
            // the content length which is used to detect truncation attacks.
            conn.data.tls_client.allow_truncation_attacks = true;
        },
    }

    client.connection_pool.addUsed(conn);

    return conn;
}

// Prevents a dependency loop in request()
const ConnectErrorPartial = ConnectUnproxiedError || error{ UnsupportedUrlScheme, ConnectionRefused };
pub const ConnectError = ConnectErrorPartial || RequestError;

pub fn connect(client: *Client, host: []const u8, port: u16, protocol: Connection.Protocol) ConnectError!*ConnectionPool.Node {
    if (client.connection_pool.findConnection(.{
        .host = host,
        .port = port,
        .is_tls = protocol == .tls,
    })) |node|
        return node;

    if (client.proxy) |proxy| {
        const proxy_port: u16 = proxy.port orelse switch (proxy.protocol) {
            .plain => 80,
            .tls => 443,
        };

        const conn = try client.connectUnproxied(proxy.host, proxy_port, proxy.protocol);
        conn.data.proxied = true;

        return conn;
    } else {
        return client.connectUnproxied(host, port, protocol);
    }
}

pub const RequestError = ConnectUnproxiedError || ConnectErrorPartial || Request.StartError || std.fmt.ParseIntError || Connection.WriteError || error{
    UnsupportedUrlScheme,
    UriMissingHost,

    CertificateBundleLoadFailure,
    UnsupportedTransferEncoding,
};

pub const Options = struct {
    version: http.Version = .@"HTTP/1.1",

    handle_redirects: bool = true,
    max_redirects: u32 = 3,
    header_strategy: HeaderStrategy = .{ .dynamic = 16 * 1024 },

    /// Must be an already acquired connection.
    connection: ?*ConnectionPool.Node = null,

    pub const HeaderStrategy = union(enum) {
        /// In this case, the client's Allocator will be used to store the
        /// entire HTTP header. This value is the maximum total size of
        /// HTTP headers allowed, otherwise
        /// error.HttpHeadersExceededSizeLimit is returned from read().
        dynamic: usize,
        /// This is used to store the entire HTTP header. If the HTTP
        /// header is too big to fit, `error.HttpHeadersExceededSizeLimit`
        /// is returned from read(). When this is used, `error.OutOfMemory`
        /// cannot be returned from `read()`.
        static: []u8,
    };
};

pub const protocol_map = std.ComptimeStringMap(Connection.Protocol, .{
    .{ "http", .plain },
    .{ "ws", .plain },
    .{ "https", .tls },
    .{ "wss", .tls },
});

/// Form and send a http request to a server.
/// This function is threadsafe.
pub fn request(client: *Client, method: http.Method, uri: Uri, headers: http.Headers, options: Options) RequestError!Request {
    const protocol = protocol_map.get(uri.scheme) orelse return error.UnsupportedUrlScheme;

    const port: u16 = uri.port orelse switch (protocol) {
        .plain => 80,
        .tls => 443,
    };

    const host = uri.host orelse return error.UriMissingHost;

    if (protocol == .tls and @atomicLoad(bool, &client.next_https_rescan_certs, .Acquire)) {
        client.ca_bundle_mutex.lock();
        defer client.ca_bundle_mutex.unlock();

        if (client.next_https_rescan_certs) {
            client.ca_bundle.rescan(client.allocator) catch return error.CertificateBundleLoadFailure;
            @atomicStore(bool, &client.next_https_rescan_certs, false, .Release);
        }
    }

    const conn = options.connection orelse try client.connect(host, port, protocol);

    var req: Request = .{
        .uri = uri,
        .client = client,
        .connection = conn,
        .headers = headers,
        .method = method,
        .version = options.version,
        .redirects_left = options.max_redirects,
        .handle_redirects = options.handle_redirects,
        .response = .{
            .status = undefined,
            .reason = undefined,
            .version = undefined,
            .headers = http.Headers{ .allocator = client.allocator, .owned = false },
            .parser = switch (options.header_strategy) {
                .dynamic => |max| proto.HeadersParser.initDynamic(max),
                .static => |buf| proto.HeadersParser.initStatic(buf),
            },
        },
        .arena = undefined,
    };
    errdefer req.deinit();

    req.arena = std.heap.ArenaAllocator.init(client.allocator);

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

    std.testing.refAllDecls(@This());
}
