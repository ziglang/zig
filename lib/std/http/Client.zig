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
/// When this is `true`, the next time this client performs an HTTPS request,
/// it will first rescan the system for root certificates.
next_https_rescan_certs: bool = true,

connection_pool: ConnectionPool = .{},

pub const ConnectionPool = struct {
    pub const Criteria = struct {
        host: []const u8,
        port: u16,
        is_tls: bool,
    };

    const Queue = std.TailQueue(Connection);
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
            if ((node.data.protocol == .tls) != criteria.is_tls) continue;
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
            node.data.close(client);

            return client.allocator.destroy(node);
        }

        if (pool.free_len + 1 >= pool.free_size) {
            const popped = pool.free.popFirst() orelse unreachable;

            popped.data.close(client);

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

            node.data.close(client);
        }

        next = pool.used.first;
        while (next) |node| {
            defer client.allocator.destroy(node);
            next = node.next;

            node.data.close(client);
        }

        pool.* = undefined;
    }
};

pub const DeflateDecompressor = std.compress.zlib.ZlibStream(Request.TransferReader);
pub const GzipDecompressor = std.compress.gzip.Decompress(Request.TransferReader);
pub const ZstdDecompressor = std.compress.zstd.DecompressStream(Request.TransferReader, .{});

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

pub const RequestTransfer = union(enum) {
    content_length: u64,
    chunked: void,
    none: void,
};

pub const Compression = union(enum) {
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
            InvalidCharacter,
        };

        pub fn parse(bytes: []const u8) !Headers {
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
                    headers.content_length = try std.fmt.parseInt(u64, header_value, 10);
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

    pub const TransferReadError = Connection.ReadError || proto.HeadersParser.ReadError;

    pub const TransferReader = std.io.Reader(*Request, TransferReadError, transferRead);

    pub fn transferReader(req: *Request) TransferReader {
        return .{ .context = req };
    }

    pub fn transferRead(req: *Request, buf: []u8) TransferReadError!usize {
        if (req.response.parser.isComplete()) return 0;

        var index: usize = 0;
        while (index == 0) {
            const amt = try req.response.parser.read(req.connection.data.reader(), buf[index..], req.response.skip);
            if (amt == 0 and req.response.parser.isComplete()) break;
            index += amt;
        }

        return index;
    }

    pub const WaitForCompleteHeadError = Connection.ReadError || proto.HeadersParser.WaitForCompleteHeadError || Response.Headers.ParseError || error{ BadHeader, InvalidCompression, StreamTooLong, InvalidWindowSize } || error{CompressionNotSupported};

    pub fn waitForCompleteHead(req: *Request) !void {
        try req.response.parser.waitForCompleteHead(req.connection.data.reader(), req.client.allocator);

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

        if (!req.response.parser.done) {
            if (req.response.headers.transfer_compression) |tc| switch (tc) {
                .compress => return error.CompressionNotSupported,
                .deflate => req.response.compression = .{
                    .deflate = try std.compress.zlib.zlibStream(req.client.allocator, req.transferReader()),
                },
                .gzip => req.response.compression = .{
                    .gzip = try std.compress.gzip.decompress(req.client.allocator, req.transferReader()),
                },
                .zstd => req.response.compression = .{
                    .zstd = std.compress.zstd.decompressStream(req.client.allocator, req.transferReader()),
                },
            };
        }

        if (req.response.headers.status.class() == .redirect and req.handle_redirects) req.response.skip = true;
    }

    pub const ReadError = RequestError || Client.DeflateDecompressor.Error || Client.GzipDecompressor.Error || Client.ZstdDecompressor.Error || WaitForCompleteHeadError || error{ TooManyHttpRedirects, HttpRedirectMissingLocation, InvalidFormat, InvalidPort, UnexpectedCharacter };

    pub const Reader = std.io.Reader(*Request, ReadError, read);

    pub fn reader(req: *Request) Reader {
        return .{ .context = req };
    }

    pub fn read(req: *Request, buffer: []u8) ReadError!usize {
        while (true) {
            if (!req.response.parser.state.isContent()) try req.waitForCompleteHead();

            if (req.handle_redirects and req.response.headers.status.class() == .redirect) {
                assert(try req.transferRead(buffer) == 0);

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
                break;
            }
        }

        return switch (req.response.compression) {
            .deflate => |*deflate| try deflate.read(buffer),
            .gzip => |*gzip| try gzip.read(buffer),
            .zstd => |*zstd| try zstd.read(buffer),
            else => try req.transferRead(buffer),
        };
    }

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
        switch (req.headers.transfer_encoding) {
            .chunked => {
                try req.connection.data.writer().print("{x}\r\n", .{bytes.len});
                try req.connection.data.writeAll(bytes);
                try req.connection.data.writeAll("\r\n");

                return bytes.len;
            },
            .content_length => |*len| {
                if (len.* < bytes.len) return error.MessageTooLong;

                const amt = try req.connection.data.write(bytes);
                len.* -= amt;
                return amt;
            },
            .none => return error.NotWriteable,
        }
    }

    /// Finish the body of a request. This notifies the server that you have no more data to send.
    pub fn finish(req: *Request) !void {
        switch (req.headers.transfer_encoding) {
            .chunked => try req.connection.data.writeAll("0\r\n"),
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

pub const ConnectError = Allocator.Error || net.TcpConnectToHostError || std.crypto.tls.Client.InitError(net.Stream);

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

    conn.data = .{
        .stream = try net.tcpConnectToHost(client.allocator, host, port),
        .tls_client = undefined,
        .protocol = protocol,
        .host = try client.allocator.dupe(u8, host),
        .port = port,
    };

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

    client.connection_pool.addUsed(conn);

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

pub fn request(client: *Client, uri: Uri, headers: Request.Headers, options: Options) RequestError!Request {
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
        client.connection_pool.mutex.lock(); // TODO: this could be so much better than reusing the connection pool mutex.
        defer client.connection_pool.mutex.unlock();

        if (client.next_https_rescan_certs) {
            try client.ca_bundle.rescan(client.allocator);
            client.next_https_rescan_certs = false;
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
        if (escaped_path.len == 0) {
            try writer.writeByte('/');
        } else {
            try writer.writeAll(escaped_path);
        }
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
        try writer.writeAll("\r\nTE: trailers, gzip, deflate");

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
