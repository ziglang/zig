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

/// Used for tcpConnectToHost and storing HTTP headers when an externally
/// managed buffer is not provided.
allocator: Allocator,
ca_bundle: std.crypto.Certificate.Bundle = .{},
ca_bundle_mutex: std.Thread.Mutex = .{},
/// When this is `true`, the next time this client performs an HTTPS request,
/// it will first rescan the system for root certificates.
next_https_rescan_certs: bool = true,

connection_pool: ConnectionPool = .{},

last_error: ?ExtraError = null,

pub const ExtraError = union(enum) {
    fn impliedErrorSet(comptime f: anytype) type {
        const set = @typeInfo(@typeInfo(@TypeOf(f)).Fn.return_type.?).ErrorUnion.error_set;
        if (@typeName(set)[0] != '@') @compileError(@typeName(f) ++ " doesn't have an implied error set any more.");
        return set;
    }

    // There's apparently a dependency loop with using Client.DeflateDecompressor.
    const FakeTransferError = proto.HeadersParser.ReadError || error{ReadFailed};
    const FakeTransferReader = std.io.Reader(void, FakeTransferError, fakeRead);
    fn fakeRead(ctx: void, buf: []u8) FakeTransferError!usize {
        _ = .{ buf, ctx };
        return 0;
    }

    const FakeDeflateDecompressor = std.compress.zlib.ZlibStream(FakeTransferReader);
    const FakeGzipDecompressor = std.compress.gzip.Decompress(FakeTransferReader);
    const FakeZstdDecompressor = std.compress.zstd.DecompressStream(FakeTransferReader, .{});

    pub const TcpConnectError = std.net.TcpConnectToHostError;
    pub const TlsError = std.crypto.tls.Client.InitError(net.Stream);
    pub const WriteError = BufferedConnection.WriteError;
    pub const ReadError = BufferedConnection.ReadError || error{HttpChunkInvalid};
    pub const CaBundleError = impliedErrorSet(std.crypto.Certificate.Bundle.rescan);

    pub const ZlibInitError = error{ BadHeader, InvalidCompression, InvalidWindowSize, Unsupported, EndOfStream, OutOfMemory } || Request.TransferReadError;
    pub const GzipInitError = error{ BadHeader, InvalidCompression, OutOfMemory, WrongChecksum, EndOfStream, StreamTooLong } || Request.TransferReadError;
    // pub const DecompressError = Client.DeflateDecompressor.Error || Client.GzipDecompressor.Error || Client.ZstdDecompressor.Error;
    pub const DecompressError = FakeDeflateDecompressor.Error || FakeGzipDecompressor.Error || FakeZstdDecompressor.Error;

    zlib_init: ZlibInitError, // error.CompressionInitializationFailed
    gzip_init: GzipInitError, // error.CompressionInitializationFailed
    connect: TcpConnectError, // error.ConnectionFailed
    ca_bundle: CaBundleError, // error.CertificateAuthorityBundleFailed
    tls: TlsError, // error.TlsInitializationFailed
    write: WriteError, // error.WriteFailed
    read: ReadError, // error.ReadFailed
    decompress: DecompressError, // error.ReadFailed
};

pub const ConnectionPool = struct {
    pub const Criteria = struct {
        host: []const u8,
        port: u16,
        is_tls: bool,
    };

    pub const StoredConnection = struct {
        buffered: BufferedConnection,
        host: []u8,
        port: u16,

        closing: bool = false,

        pub fn deinit(self: *StoredConnection, client: *Client) void {
            self.buffered.close(client);
            client.allocator.free(self.host);
        }
    };

    const Queue = std.TailQueue(StoredConnection);
    pub const Node = Queue.Node;

    mutex: std.Thread.Mutex = .{},
    used: Queue = .{},
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
            if ((node.data.buffered.conn.protocol == .tls) != criteria.is_tls) continue;
            if (node.data.port != criteria.port) continue;
            if (mem.eql(u8, node.data.host, criteria.host)) continue;

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

        if (pool.free_len + 1 >= pool.free_size) {
            const popped = pool.free.popFirst() orelse unreachable;

            popped.data.deinit(client);

            return client.allocator.destroy(popped);
        }

        pool.free.append(node);
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

pub const Connection = struct {
    stream: net.Stream,
    /// undefined unless protocol is tls.
    tls_client: *std.crypto.tls.Client,
    protocol: Protocol,

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
    }
};

pub const BufferedConnection = struct {
    pub const buffer_size = 0x2000;

    conn: Connection,
    buf: [buffer_size]u8 = undefined,
    start: u16 = 0,
    end: u16 = 0,

    pub fn fill(bconn: *BufferedConnection) ReadError!void {
        if (bconn.end != bconn.start) return;

        const nread = try bconn.conn.read(bconn.buf[0..]);
        if (nread == 0) return error.EndOfStream;
        bconn.start = 0;
        bconn.end = @truncate(u16, nread);
    }

    pub fn peek(bconn: *BufferedConnection) []const u8 {
        return bconn.buf[bconn.start..bconn.end];
    }

    pub fn clear(bconn: *BufferedConnection, num: u16) void {
        bconn.start += num;
    }

    pub fn readAtLeast(bconn: *BufferedConnection, buffer: []u8, len: usize) ReadError!usize {
        var out_index: u16 = 0;
        while (out_index < len) {
            const available = bconn.end - bconn.start;
            const left = buffer.len - out_index;

            if (available > 0) {
                const can_read = @truncate(u16, @min(available, left));

                std.mem.copy(u8, buffer[out_index..], bconn.buf[bconn.start..][0..can_read]);
                out_index += can_read;
                bconn.start += can_read;

                continue;
            }

            if (left > bconn.buf.len) {
                // skip the buffer if the output is large enough
                return bconn.conn.read(buffer[out_index..]);
            }

            try bconn.fill();
        }

        return out_index;
    }

    pub fn read(bconn: *BufferedConnection, buffer: []u8) ReadError!usize {
        return bconn.readAtLeast(buffer, 1);
    }

    pub const ReadError = Connection.ReadError || error{EndOfStream};
    pub const Reader = std.io.Reader(*BufferedConnection, ReadError, read);

    pub fn reader(bconn: *BufferedConnection) Reader {
        return Reader{ .context = bconn };
    }

    pub fn writeAll(bconn: *BufferedConnection, buffer: []const u8) WriteError!void {
        return bconn.conn.writeAll(buffer);
    }

    pub fn write(bconn: *BufferedConnection, buffer: []const u8) WriteError!usize {
        return bconn.conn.write(buffer);
    }

    pub const WriteError = Connection.WriteError;
    pub const Writer = std.io.Writer(*BufferedConnection, WriteError, write);

    pub fn writer(bconn: *BufferedConnection) Writer {
        return Writer{ .context = bconn };
    }

    pub fn close(bconn: *BufferedConnection, client: *const Client) void {
        bconn.conn.close(client);
    }
};

pub const RequestTransfer = union(enum) {
    content_length: u64,
    chunked: void,
    none: void,
};

pub const Compression = union(enum) {
    pub const DeflateDecompressor = std.compress.zlib.ZlibStream(Request.TransferReader);
    pub const GzipDecompressor = std.compress.gzip.Decompress(Request.TransferReader);
    pub const ZstdDecompressor = std.compress.zstd.DecompressStream(Request.TransferReader, .{});

    deflate: DeflateDecompressor,
    gzip: GzipDecompressor,
    zstd: ZstdDecompressor,
    none: void,
};

pub const Response = struct {
    pub const Headers = struct {
        status: http.Status,
        version: http.Version,
        location: ?[]const u8 = null,
        content_length: ?u64 = null,
        transfer_encoding: ?http.TransferEncoding = null,
        transfer_compression: ?http.ContentEncoding = null,
        connection: http.Connection = .close,
        upgrade: ?[]const u8 = null,

        pub const ParseError = error{
            ShortHttpStatusLine,
            BadHttpVersion,
            HttpHeadersInvalid,
            HttpHeaderContinuationsUnsupported,
            HttpTransferEncodingUnsupported,
            HttpConnectionHeaderUnsupported,
            InvalidContentLength,
            CompressionNotSupported,
        };

        pub fn parse(bytes: []const u8) ParseError!Headers {
            var it = mem.tokenize(u8, bytes[0 .. bytes.len - 4], "\r\n");

            const first_line = it.next() orelse return error.HttpHeadersInvalid;
            if (first_line.len < 12)
                return error.ShortHttpStatusLine;

            const version: http.Version = switch (int64(first_line[0..8])) {
                int64("HTTP/1.0") => .@"HTTP/1.0",
                int64("HTTP/1.1") => .@"HTTP/1.1",
                else => return error.BadHttpVersion,
            };
            if (first_line[8] != ' ') return error.HttpHeadersInvalid;
            const status = @intToEnum(http.Status, parseInt3(first_line[9..12].*));

            var headers: Headers = .{
                .version = version,
                .status = status,
            };

            while (it.next()) |line| {
                if (line.len == 0) return error.HttpHeadersInvalid;
                switch (line[0]) {
                    ' ', '\t' => return error.HttpHeaderContinuationsUnsupported,
                    else => {},
                }

                var line_it = mem.tokenize(u8, line, ": ");
                const header_name = line_it.next() orelse return error.HttpHeadersInvalid;
                const header_value = line_it.rest();
                if (std.ascii.eqlIgnoreCase(header_name, "location")) {
                    if (headers.location != null) return error.HttpHeadersInvalid;
                    headers.location = header_value;
                } else if (std.ascii.eqlIgnoreCase(header_name, "content-length")) {
                    if (headers.content_length != null) return error.HttpHeadersInvalid;
                    headers.content_length = std.fmt.parseInt(u64, header_value, 10) catch return error.InvalidContentLength;
                } else if (std.ascii.eqlIgnoreCase(header_name, "transfer-encoding")) {
                    // Transfer-Encoding: second, first
                    // Transfer-Encoding: deflate, chunked
                    var iter = mem.splitBackwards(u8, header_value, ",");

                    if (iter.next()) |first| {
                        const trimmed = mem.trim(u8, first, " ");

                        if (std.meta.stringToEnum(http.TransferEncoding, trimmed)) |te| {
                            if (headers.transfer_encoding != null) return error.HttpHeadersInvalid;
                            headers.transfer_encoding = te;
                        } else if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                            if (headers.transfer_compression != null) return error.HttpHeadersInvalid;
                            headers.transfer_compression = ce;
                        } else {
                            return error.HttpTransferEncodingUnsupported;
                        }
                    }

                    if (iter.next()) |second| {
                        if (headers.transfer_compression != null) return error.HttpTransferEncodingUnsupported;

                        const trimmed = mem.trim(u8, second, " ");

                        if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                            headers.transfer_compression = ce;
                        } else {
                            return error.HttpTransferEncodingUnsupported;
                        }
                    }

                    if (iter.next()) |_| return error.HttpTransferEncodingUnsupported;
                } else if (std.ascii.eqlIgnoreCase(header_name, "content-encoding")) {
                    if (headers.transfer_compression != null) return error.HttpHeadersInvalid;

                    const trimmed = mem.trim(u8, header_value, " ");

                    if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                        headers.transfer_compression = ce;
                    } else {
                        return error.HttpTransferEncodingUnsupported;
                    }
                } else if (std.ascii.eqlIgnoreCase(header_name, "connection")) {
                    if (std.ascii.eqlIgnoreCase(header_value, "keep-alive")) {
                        headers.connection = .keep_alive;
                    } else if (std.ascii.eqlIgnoreCase(header_value, "close")) {
                        headers.connection = .close;
                    } else {
                        return error.HttpConnectionHeaderUnsupported;
                    }
                } else if (std.ascii.eqlIgnoreCase(header_name, "upgrade")) {
                    headers.upgrade = header_value;
                }
            }

            return headers;
        }

        inline fn int64(array: *const [8]u8) u64 {
            return @bitCast(u64, array.*);
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
    };

    headers: Headers = undefined,
    parser: proto.HeadersParser,
    compression: Compression = .none,
    skip: bool = false,
};

/// A HTTP request.
///
/// Order of operations:
/// - request
/// - write
/// - finish
/// - do
/// - read
pub const Request = struct {
    pub const Headers = struct {
        version: http.Version = .@"HTTP/1.1",
        method: http.Method = .GET,
        user_agent: []const u8 = "zig (std.http)",
        connection: http.Connection = .keep_alive,
        transfer_encoding: RequestTransfer = .none,

        custom: []const http.CustomHeader = &[_]http.CustomHeader{},
    };

    uri: Uri,
    client: *Client,
    connection: *ConnectionPool.Node,
    /// These are stored in Request so that they are available when following
    /// redirects.
    headers: Headers,

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

        if (req.response.parser.header_bytes_owned) {
            req.response.parser.header_bytes.deinit(req.client.allocator);
        }

        if (!req.response.parser.done) {
            // If the response wasn't fully read, then we need to close the connection.
            req.connection.data.closing = true;
            req.client.connection_pool.release(req.client, req.connection);
        }

        req.arena.deinit();
        req.* = undefined;
    }

    pub fn start(req: *Request, uri: Uri, headers: Headers) !void {
        var buffered = std.io.bufferedWriter(req.connection.data.buffered.writer());
        const w = buffered.writer();

        const escaped_path = try Uri.escapePath(req.client.allocator, uri.path);
        defer req.client.allocator.free(escaped_path);

        const escaped_query = if (uri.query) |q| try Uri.escapeQuery(req.client.allocator, q) else null;
        defer if (escaped_query) |q| req.client.allocator.free(q);

        const escaped_fragment = if (uri.fragment) |f| try Uri.escapeQuery(req.client.allocator, f) else null;
        defer if (escaped_fragment) |f| req.client.allocator.free(f);

        try w.writeAll(@tagName(headers.method));
        try w.writeByte(' ');
        if (escaped_path.len == 0) {
            try w.writeByte('/');
        } else {
            try w.writeAll(escaped_path);
        }
        if (escaped_query) |q| {
            try w.writeByte('?');
            try w.writeAll(q);
        }
        if (escaped_fragment) |f| {
            try w.writeByte('#');
            try w.writeAll(f);
        }
        try w.writeByte(' ');
        try w.writeAll(@tagName(headers.version));
        try w.writeAll("\r\nHost: ");
        try w.writeAll(uri.host.?);
        try w.writeAll("\r\nUser-Agent: ");
        try w.writeAll(headers.user_agent);
        if (headers.connection == .close) {
            try w.writeAll("\r\nConnection: close");
        } else {
            try w.writeAll("\r\nConnection: keep-alive");
        }
        try w.writeAll("\r\nAccept-Encoding: gzip, deflate, zstd");
        try w.writeAll("\r\nTE: gzip, deflate"); // TODO: add trailers when someone finds a nice way to integrate them without completely invalidating all pointers to headers.

        switch (headers.transfer_encoding) {
            .chunked => try w.writeAll("\r\nTransfer-Encoding: chunked"),
            .content_length => |content_length| try w.print("\r\nContent-Length: {d}", .{content_length}),
            .none => {},
        }

        for (headers.custom) |header| {
            try w.writeAll("\r\n");
            try w.writeAll(header.name);
            try w.writeAll(": ");
            try w.writeAll(header.value);
        }

        try w.writeAll("\r\n\r\n");

        try buffered.flush();
    }

    pub const TransferReadError = proto.HeadersParser.ReadError || error{ReadFailed};

    pub const TransferReader = std.io.Reader(*Request, TransferReadError, transferRead);

    pub fn transferReader(req: *Request) TransferReader {
        return .{ .context = req };
    }

    pub fn transferRead(req: *Request, buf: []u8) TransferReadError!usize {
        if (req.response.parser.done) return 0;

        var index: usize = 0;
        while (index == 0) {
            const amt = req.response.parser.read(&req.connection.data.buffered, buf[index..], req.response.skip) catch |err| {
                req.client.last_error = .{ .read = err };
                return error.ReadFailed;
            };
            if (amt == 0 and req.response.parser.done) break;
            index += amt;
        }

        return index;
    }

    pub const DoError = RequestError || TransferReadError || proto.HeadersParser.CheckCompleteHeadError || Response.Headers.ParseError || Uri.ParseError || error{ TooManyHttpRedirects, HttpRedirectMissingLocation, CompressionInitializationFailed };

    /// Waits for a response from the server and parses any headers that are sent.
    /// This function will block until the final response is received.
    ///
    /// If `handle_redirects` is true, then this function will automatically follow
    /// redirects.
    pub fn do(req: *Request) DoError!void {
        while (true) { // handle redirects
            while (true) { // read headers
                req.connection.data.buffered.fill() catch |err| {
                    req.client.last_error = .{ .read = err };
                    return error.ReadFailed;
                };

                const nchecked = try req.response.parser.checkCompleteHead(req.client.allocator, req.connection.data.buffered.peek());
                req.connection.data.buffered.clear(@intCast(u16, nchecked));

                if (req.response.parser.state.isContent()) break;
            }

            req.response.headers = try Response.Headers.parse(req.response.parser.header_bytes.items);

            if (req.response.headers.status == .switching_protocols) {
                req.connection.data.closing = false;
                req.response.parser.done = true;
            }

            if (req.headers.connection == .keep_alive and req.response.headers.connection == .keep_alive) {
                req.connection.data.closing = false;
            } else {
                req.connection.data.closing = true;
            }

            if (req.response.headers.transfer_encoding) |te| {
                switch (te) {
                    .chunked => {
                        req.response.parser.next_chunk_length = 0;
                        req.response.parser.state = .chunk_head_size;
                    },
                }
            } else if (req.response.headers.content_length) |cl| {
                req.response.parser.next_chunk_length = cl;

                if (cl == 0) req.response.parser.done = true;
            } else {
                req.response.parser.done = true;
            }

            if (req.response.headers.status.class() == .redirect and req.handle_redirects) {
                req.response.skip = true;

                const empty = @as([*]u8, undefined)[0..0];
                assert(try req.transferRead(empty) == 0); // we're skipping, no buffer is necessary

                if (req.redirects_left == 0) return error.TooManyHttpRedirects;

                const location = req.response.headers.location orelse
                    return error.HttpRedirectMissingLocation;
                const new_url = Uri.parse(location) catch try Uri.parseWithoutScheme(location);

                var new_arena = std.heap.ArenaAllocator.init(req.client.allocator);
                const resolved_url = try req.uri.resolve(new_url, false, new_arena.allocator());
                errdefer new_arena.deinit();

                req.arena.deinit();
                req.arena = new_arena;

                const new_req = try req.client.request(resolved_url, req.headers, .{
                    .max_redirects = req.redirects_left - 1,
                    .header_strategy = if (req.response.parser.header_bytes_owned) .{
                        .dynamic = req.response.parser.max_header_bytes,
                    } else .{
                        .static = req.response.parser.header_bytes.items.ptr[0..req.response.parser.max_header_bytes],
                    },
                });
                req.deinit();
                req.* = new_req;
            } else {
                req.response.skip = false;
                if (!req.response.parser.done) {
                    if (req.response.headers.transfer_compression) |tc| switch (tc) {
                        .compress => return error.CompressionNotSupported,
                        .deflate => req.response.compression = .{
                            .deflate = std.compress.zlib.zlibStream(req.client.allocator, req.transferReader()) catch |err| {
                                req.client.last_error = .{ .zlib_init = err };
                                return error.CompressionInitializationFailed;
                            },
                        },
                        .gzip => req.response.compression = .{
                            .gzip = std.compress.gzip.decompress(req.client.allocator, req.transferReader()) catch |err| {
                                req.client.last_error = .{ .gzip_init = err };
                                return error.CompressionInitializationFailed;
                            },
                        },
                        .zstd => req.response.compression = .{
                            .zstd = std.compress.zstd.decompressStream(req.client.allocator, req.transferReader()),
                        },
                    };
                }

                break;
            }
        }
    }

    pub const ReadError = TransferReadError || proto.HeadersParser.CheckCompleteHeadError;

    pub const Reader = std.io.Reader(*Request, ReadError, read);

    pub fn reader(req: *Request) Reader {
        return .{ .context = req };
    }

    /// Reads data from the response body. Must be called after `do`.
    pub fn read(req: *Request, buffer: []u8) ReadError!usize {
        while (true) {
            const out_index = switch (req.response.compression) {
                .deflate => |*deflate| deflate.read(buffer) catch |err| {
                    req.client.last_error = .{ .decompress = err };
                    err catch {};
                    return error.ReadFailed;
                },
                .gzip => |*gzip| gzip.read(buffer) catch |err| {
                    req.client.last_error = .{ .decompress = err };
                    err catch {};
                    return error.ReadFailed;
                },
                .zstd => |*zstd| zstd.read(buffer) catch |err| {
                    req.client.last_error = .{ .decompress = err };
                    err catch {};
                    return error.ReadFailed;
                },
                else => try req.transferRead(buffer),
            };

            if (out_index == 0) {
                while (!req.response.parser.state.isContent()) { // read trailing headers
                    req.connection.data.buffered.fill() catch |err| {
                        req.client.last_error = .{ .read = err };
                        return error.ReadFailed;
                    };

                    const nchecked = try req.response.parser.checkCompleteHead(req.client.allocator, req.connection.data.buffered.peek());
                    req.connection.data.buffered.clear(@intCast(u16, nchecked));
                }
            }

            return out_index;
        }
    }

    /// Reads data from the response body. Must be called after `do`.
    pub fn readAll(req: *Request, buffer: []u8) !usize {
        var index: usize = 0;
        while (index < buffer.len) {
            const amt = read(req, buffer[index..]) catch |err| {
                req.client.last_error = .{ .read = err };
                return error.ReadFailed;
            };
            if (amt == 0) break;
            index += amt;
        }
        return index;
    }

    pub const WriteError = error{ WriteFailed, NotWriteable, MessageTooLong };

    pub const Writer = std.io.Writer(*Request, WriteError, write);

    pub fn writer(req: *Request) Writer {
        return .{ .context = req };
    }

    /// Write `bytes` to the server. The `transfer_encoding` request header determines how data will be sent.
    pub fn write(req: *Request, bytes: []const u8) WriteError!usize {
        switch (req.headers.transfer_encoding) {
            .chunked => {
                req.connection.data.conn.writer().print("{x}\r\n", .{bytes.len}) catch |err| {
                    req.client.last_error = .{ .write = err };
                    return error.WriteFailed;
                };
                req.connection.data.conn.writeAll(bytes) catch |err| {
                    req.client.last_error = .{ .write = err };
                    return error.WriteFailed;
                };
                req.connection.data.conn.writeAll("\r\n") catch |err| {
                    req.client.last_error = .{ .write = err };
                    return error.WriteFailed;
                };

                return bytes.len;
            },
            .content_length => |*len| {
                if (len.* < bytes.len) return error.MessageTooLong;

                const amt = req.connection.data.conn.write(bytes) catch |err| {
                    req.client.last_error = .{ .write = err };
                    return error.WriteFailed;
                };
                len.* -= amt;
                return amt;
            },
            .none => return error.NotWriteable,
        }
    }

    /// Finish the body of a request. This notifies the server that you have no more data to send.
    pub fn finish(req: *Request) !void {
        switch (req.headers.transfer_encoding) {
            .chunked => req.connection.data.conn.writeAll("0\r\n") catch |err| {
                req.client.last_error = .{ .write = err };
                return error.WriteFailed;
            },
            .content_length => |len| if (len != 0) return error.MessageNotCompleted,
            .none => {},
        }
    }
};

pub fn deinit(client: *Client) void {
    client.connection_pool.deinit(client);

    client.ca_bundle.deinit(client.allocator);
    client.* = undefined;
}

pub const ConnectError = Allocator.Error || error{ ConnectionFailed, TlsInitializationFailed };

pub fn connect(client: *Client, host: []const u8, port: u16, protocol: Connection.Protocol) ConnectError!*ConnectionPool.Node {
    if (client.connection_pool.findConnection(.{
        .host = host,
        .port = port,
        .is_tls = protocol == .tls,
    })) |node|
        return node;

    const conn = try client.allocator.create(ConnectionPool.Node);
    errdefer client.allocator.destroy(conn);
    conn.* = .{ .data = undefined };

    const stream = net.tcpConnectToHost(client.allocator, host, port) catch |err| {
        client.last_error = .{ .connect = err };
        return error.ConnectionFailed;
    };
    errdefer stream.close();

    conn.data = .{
        .buffered = .{ .conn = .{
            .stream = stream,
            .tls_client = undefined,
            .protocol = protocol,
        } },
        .host = try client.allocator.dupe(u8, host),
        .port = port,
    };
    errdefer client.allocator.free(conn.data.host);

    switch (protocol) {
        .plain => {},
        .tls => {
            conn.data.buffered.conn.tls_client = try client.allocator.create(std.crypto.tls.Client);
            errdefer client.allocator.destroy(conn.data.buffered.conn.tls_client);

            conn.data.buffered.conn.tls_client.* = std.crypto.tls.Client.init(stream, client.ca_bundle, host) catch |err| {
                client.last_error = .{ .tls = err };
                return error.TlsInitializationFailed;
            };
            // This is appropriate for HTTPS because the HTTP headers contain
            // the content length which is used to detect truncation attacks.
            conn.data.buffered.conn.tls_client.allow_truncation_attacks = true;
        },
    }

    client.connection_pool.addUsed(conn);

    return conn;
}

pub const RequestError = ConnectError || error{
    UnsupportedUrlScheme,
    UriMissingHost,

    CertificateAuthorityBundleFailed,
    WriteFailed,
};

pub const Options = struct {
    handle_redirects: bool = true,
    max_redirects: u32 = 3,
    header_strategy: HeaderStrategy = .{ .dynamic = 16 * 1024 },

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

pub fn request(client: *Client, uri: Uri, headers: Request.Headers, options: Options) RequestError!Request {
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
            client.ca_bundle.rescan(client.allocator) catch |err| {
                client.last_error = .{ .ca_bundle = err };
                return error.CertificateAuthorityBundleFailed;
            };
            @atomicStore(bool, &client.next_https_rescan_certs, false, .Release);
        }
    }

    var req: Request = .{
        .uri = uri,
        .client = client,
        .connection = try client.connect(host, port, protocol),
        .headers = headers,
        .redirects_left = options.max_redirects,
        .handle_redirects = options.handle_redirects,
        .response = .{
            .parser = switch (options.header_strategy) {
                .dynamic => |max| proto.HeadersParser.initDynamic(max),
                .static => |buf| proto.HeadersParser.initStatic(buf),
            },
        },
        .arena = undefined,
    };
    errdefer req.deinit();

    req.arena = std.heap.ArenaAllocator.init(client.allocator);

    req.start(uri, headers) catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        const err_casted = @errSetCast(BufferedConnection.WriteError, err);

        client.last_error = .{ .write = err_casted };
        return error.WriteFailed;
    };

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
