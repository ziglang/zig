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

const ConnectionPool = std.TailQueue(Connection);
const ConnectionNode = ConnectionPool.Node;

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

const DeflateDecompressor = std.compress.zlib.ZlibStream(Request.ReaderRaw);
const GzipDecompressor = std.compress.gzip.Decompress(Request.ReaderRaw);

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

pub const Request = struct {
    const read_buffer_size = 8192;
    const ReadBufferIndex = std.math.IntFittingRange(0, read_buffer_size);

    uri: Uri,
    client: *Client,
    connection: *ConnectionNode,
    response: Response,
    /// These are stored in Request so that they are available when following
    /// redirects.
    headers: Headers,

    redirects_left: u32,
    handle_redirects: bool,
    compression_init: bool,

    /// Used as a allocator for resolving redirects locations.
    arena: std.heap.ArenaAllocator,

    /// Read buffer for the connection. This is used to pull in large amounts of data from the connection even if the user asks for a small amount. This can probably be removed with careful planning.
    read_buffer: [read_buffer_size]u8 = undefined,
    read_buffer_start: ReadBufferIndex = 0,
    read_buffer_len: ReadBufferIndex = 0,

    pub const Response = struct {
        headers: Response.Headers,
        state: State,
        header_bytes_owned: bool,
        /// This could either be a fixed buffer provided by the API user or it
        /// could be our own array list.
        header_bytes: std.ArrayListUnmanaged(u8),
        max_header_bytes: usize,
        next_chunk_length: u64,
        done: bool = false,

        compression: union(enum) {
            deflate: DeflateDecompressor,
            gzip: GzipDecompressor,
            none: void,
        } = .none,

        pub const Headers = struct {
            status: http.Status,
            version: http.Version,
            location: ?[]const u8 = null,
            content_length: ?u64 = null,
            transfer_encoding: ?http.TransferEncoding = null, // This should only ever be chunked, compression is handled separately.
            transfer_compression: ?http.TransferEncoding = null,
            connection: http.Connection = .close,

            number_of_headers: usize = 0,

            pub fn parse(bytes: []const u8) !Response.Headers {
                var it = mem.split(u8, bytes[0 .. bytes.len - 4], "\r\n");

                const first_line = it.first();
                if (first_line.len < 12)
                    return error.ShortHttpStatusLine;

                const version: http.Version = switch (int64(first_line[0..8])) {
                    int64("HTTP/1.0") => .@"HTTP/1.0",
                    int64("HTTP/1.1") => .@"HTTP/1.1",
                    else => return error.BadHttpVersion,
                };
                if (first_line[8] != ' ') return error.HttpHeadersInvalid;
                const status = @intToEnum(http.Status, parseInt3(first_line[9..12].*));

                var headers: Response.Headers = .{
                    .version = version,
                    .status = status,
                };

                while (it.next()) |line| {
                    headers.number_of_headers += 1;

                    if (line.len == 0) return error.HttpHeadersInvalid;
                    switch (line[0]) {
                        ' ', '\t' => return error.HttpHeaderContinuationsUnsupported,
                        else => {},
                    }
                    var line_it = mem.split(u8, line, ": ");
                    const header_name = line_it.first();
                    const header_value = line_it.rest();
                    if (std.ascii.eqlIgnoreCase(header_name, "location")) {
                        if (headers.location != null) return error.HttpHeadersInvalid;
                        headers.location = header_value;
                    } else if (std.ascii.eqlIgnoreCase(header_name, "content-length")) {
                        if (headers.content_length != null) return error.HttpHeadersInvalid;
                        headers.content_length = try std.fmt.parseInt(u64, header_value, 10);
                    } else if (std.ascii.eqlIgnoreCase(header_name, "transfer-encoding")) {
                        if (headers.transfer_encoding != null or headers.transfer_compression != null) return error.HttpHeadersInvalid;

                        // Transfer-Encoding: second, first
                        // Transfer-Encoding: deflate, chunked
                        var iter = std.mem.splitBackwards(u8, header_value, ",");

                        if (iter.next()) |first| {
                            const kind = std.meta.stringToEnum(
                                http.TransferEncoding,
                                std.mem.trim(u8, first, " "),
                            ) orelse
                                return error.HttpTransferEncodingUnsupported;

                            switch (kind) {
                                .chunked => headers.transfer_encoding = .chunked,
                                .compress => headers.transfer_compression = .compress,
                                .deflate => headers.transfer_compression = .deflate,
                                .gzip => headers.transfer_compression = .gzip,
                            }
                        }

                        if (iter.next()) |second| {
                            if (headers.transfer_compression != null) return error.HttpTransferEncodingUnsupported;

                            const kind = std.meta.stringToEnum(
                                http.TransferEncoding,
                                std.mem.trim(u8, second, " "),
                            ) orelse
                                return error.HttpTransferEncodingUnsupported;

                            switch (kind) {
                                .chunked => return error.HttpHeadersInvalid, // chunked must come last
                                .compress => return error.HttpTransferEncodingUnsupported, // compress not supported
                                .deflate => headers.transfer_compression = .deflate,
                                .gzip => headers.transfer_compression = .gzip,
                            }
                        }

                        if (iter.next()) |_| return error.HttpTransferEncodingUnsupported;
                    } else if (std.ascii.eqlIgnoreCase(header_name, "content-encoding")) {
                        if (headers.transfer_compression != null) return error.HttpHeadersInvalid;

                        const kind = std.meta.stringToEnum(
                            http.TransferEncoding,
                            std.mem.trim(u8, header_value, " "),
                        ) orelse
                            return error.HttpTransferEncodingUnsupported;

                        switch (kind) {
                            .chunked => return error.HttpHeadersInvalid, // not transfer encoding
                            .compress => return error.HttpTransferEncodingUnsupported, // compress not supported
                            .deflate => headers.transfer_compression = .deflate,
                            .gzip => headers.transfer_compression = .gzip,
                        }
                    } else if (std.ascii.eqlIgnoreCase(header_name, "connection")) {
                        if (std.ascii.eqlIgnoreCase(header_value, "keep-alive")) {
                            headers.connection = .keep_alive;
                        } else if (std.ascii.eqlIgnoreCase(header_value, "close")) {
                            headers.connection = .close;
                        } else {
                            return error.HttpConnectionHeaderUnsupported;
                        }
                    }
                }

                return headers;
            }

            test "parse headers" {
                const example =
                    "HTTP/1.1 301 Moved Permanently\r\n" ++
                    "Location: https://www.example.com/\r\n" ++
                    "Content-Type: text/html; charset=UTF-8\r\n" ++
                    "Content-Length: 220\r\n\r\n";
                const parsed = try Response.Headers.parse(example);
                try testing.expectEqual(http.Version.@"HTTP/1.1", parsed.version);
                try testing.expectEqual(http.Status.moved_permanently, parsed.status);
                try testing.expectEqualStrings("https://www.example.com/", parsed.location orelse
                    return error.TestFailed);
                try testing.expectEqual(@as(?u64, 220), parsed.content_length);
            }

            test "header continuation" {
                const example =
                    "HTTP/1.0 200 OK\r\n" ++
                    "Content-Type: text/html;\r\n charset=UTF-8\r\n" ++
                    "Content-Length: 220\r\n\r\n";
                try testing.expectError(
                    error.HttpHeaderContinuationsUnsupported,
                    Response.Headers.parse(example),
                );
            }

            test "extra content length" {
                const example =
                    "HTTP/1.0 200 OK\r\n" ++
                    "Content-Length: 220\r\n" ++
                    "Content-Type: text/html; charset=UTF-8\r\n" ++
                    "content-length: 220\r\n\r\n";
                try testing.expectError(
                    error.HttpHeadersInvalid,
                    Response.Headers.parse(example),
                );
            }
        };

        pub const State = enum {
            /// Begin header parsing states.
            invalid,
            start,
            seen_r,
            seen_rn,
            seen_rnr,
            finished,
            /// Begin transfer-encoding: chunked parsing states.
            chunk_size_prefix_r,
            chunk_size_prefix_n,
            chunk_size,
            chunk_r,
            chunk_data,

            pub fn isContent(self: State) bool {
                return switch (self) {
                    .invalid, .start, .seen_r, .seen_rn, .seen_rnr => false,
                    .finished, .chunk_size_prefix_r, .chunk_size_prefix_n, .chunk_size, .chunk_r, .chunk_data => true,
                };
            }
        };

        pub fn initDynamic(max: usize) Response {
            return .{
                .state = .start,
                .headers = undefined,
                .header_bytes = .{},
                .max_header_bytes = max,
                .header_bytes_owned = true,
                .next_chunk_length = undefined,
            };
        }

        pub fn initStatic(buf: []u8) Response {
            return .{
                .state = .start,
                .headers = undefined,
                .header_bytes = .{ .items = buf[0..0], .capacity = buf.len },
                .max_header_bytes = buf.len,
                .header_bytes_owned = false,
                .next_chunk_length = undefined,
            };
        }

        /// Returns how many bytes are part of HTTP headers. Always less than or
        /// equal to bytes.len. If the amount returned is less than bytes.len, it
        /// means the headers ended and the first byte after the double \r\n\r\n is
        /// located at `bytes[result]`.
        pub fn findHeadersEnd(r: *Response, bytes: []const u8) usize {
            var index: usize = 0;

            // TODO: https://github.com/ziglang/zig/issues/8220
            state: while (true) {
                switch (r.state) {
                    .invalid => unreachable,
                    .finished => unreachable,
                    .start => while (true) {
                        switch (bytes.len - index) {
                            0 => return index,
                            1 => {
                                if (bytes[index] == '\r')
                                    r.state = .seen_r;
                                return index + 1;
                            },
                            2 => {
                                if (int16(bytes[index..][0..2]) == int16("\r\n")) {
                                    r.state = .seen_rn;
                                } else if (bytes[index + 1] == '\r') {
                                    r.state = .seen_r;
                                }
                                return index + 2;
                            },
                            3 => {
                                if (int16(bytes[index..][0..2]) == int16("\r\n") and
                                    bytes[index + 2] == '\r')
                                {
                                    r.state = .seen_rnr;
                                } else if (int16(bytes[index + 1 ..][0..2]) == int16("\r\n")) {
                                    r.state = .seen_rn;
                                } else if (bytes[index + 2] == '\r') {
                                    r.state = .seen_r;
                                }
                                return index + 3;
                            },
                            4...15 => {
                                if (int32(bytes[index..][0..4]) == int32("\r\n\r\n")) {
                                    r.state = .finished;
                                    return index + 4;
                                } else if (int16(bytes[index + 1 ..][0..2]) == int16("\r\n") and
                                    bytes[index + 3] == '\r')
                                {
                                    r.state = .seen_rnr;
                                    index += 4;
                                    continue :state;
                                } else if (int16(bytes[index + 2 ..][0..2]) == int16("\r\n")) {
                                    r.state = .seen_rn;
                                    index += 4;
                                    continue :state;
                                } else if (bytes[index + 3] == '\r') {
                                    r.state = .seen_r;
                                    index += 4;
                                    continue :state;
                                }
                                index += 4;
                                continue;
                            },
                            else => {
                                const chunk = bytes[index..][0..16];
                                const v: @Vector(16, u8) = chunk.*;
                                const matches_r = v == @splat(16, @as(u8, '\r'));
                                const iota = std.simd.iota(u8, 16);
                                const default = @splat(16, @as(u8, 16));
                                const sub_index = @reduce(.Min, @select(u8, matches_r, iota, default));
                                switch (sub_index) {
                                    0...12 => {
                                        index += sub_index + 4;
                                        if (int32(chunk[sub_index..][0..4]) == int32("\r\n\r\n")) {
                                            r.state = .finished;
                                            return index;
                                        }
                                        continue;
                                    },
                                    13 => {
                                        index += 16;
                                        if (int16(chunk[14..][0..2]) == int16("\n\r")) {
                                            r.state = .seen_rnr;
                                            continue :state;
                                        }
                                        continue;
                                    },
                                    14 => {
                                        index += 16;
                                        if (chunk[15] == '\n') {
                                            r.state = .seen_rn;
                                            continue :state;
                                        }
                                        continue;
                                    },
                                    15 => {
                                        r.state = .seen_r;
                                        index += 16;
                                        continue :state;
                                    },
                                    16 => {
                                        index += 16;
                                        continue;
                                    },
                                    else => unreachable,
                                }
                            },
                        }
                    },

                    .seen_r => switch (bytes.len - index) {
                        0 => return index,
                        1 => {
                            switch (bytes[index]) {
                                '\n' => r.state = .seen_rn,
                                '\r' => r.state = .seen_r,
                                else => r.state = .start,
                            }
                            return index + 1;
                        },
                        2 => {
                            if (int16(bytes[index..][0..2]) == int16("\n\r")) {
                                r.state = .seen_rnr;
                                return index + 2;
                            }
                            r.state = .start;
                            return index + 2;
                        },
                        else => {
                            if (int16(bytes[index..][0..2]) == int16("\n\r") and
                                bytes[index + 2] == '\n')
                            {
                                r.state = .finished;
                                return index + 3;
                            }
                            index += 3;
                            r.state = .start;
                            continue :state;
                        },
                    },
                    .seen_rn => switch (bytes.len - index) {
                        0 => return index,
                        1 => {
                            switch (bytes[index]) {
                                '\r' => r.state = .seen_rnr,
                                else => r.state = .start,
                            }
                            return index + 1;
                        },
                        else => {
                            if (int16(bytes[index..][0..2]) == int16("\r\n")) {
                                r.state = .finished;
                                return index + 2;
                            }
                            index += 2;
                            r.state = .start;
                            continue :state;
                        },
                    },
                    .seen_rnr => switch (bytes.len - index) {
                        0 => return index,
                        else => {
                            if (bytes[index] == '\n') {
                                r.state = .finished;
                                return index + 1;
                            }
                            index += 1;
                            r.state = .start;
                            continue :state;
                        },
                    },
                    .chunk_size_prefix_r => unreachable,
                    .chunk_size_prefix_n => unreachable,
                    .chunk_size => unreachable,
                    .chunk_r => unreachable,
                    .chunk_data => unreachable,
                }

                return index;
            }
        }

        pub fn findChunkedLen(r: *Response, bytes: []const u8) usize {
            var i: usize = 0;
            if (r.state == .chunk_size) {
                while (i < bytes.len) : (i += 1) {
                    const digit = switch (bytes[i]) {
                        '0'...'9' => |b| b - '0',
                        'A'...'Z' => |b| b - 'A' + 10,
                        'a'...'z' => |b| b - 'a' + 10,
                        '\r' => {
                            r.state = .chunk_r;
                            i += 1;
                            break;
                        },
                        else => {
                            r.state = .invalid;
                            return i;
                        },
                    };
                    const mul = @mulWithOverflow(r.next_chunk_length, 16);
                    if (mul[1] != 0) {
                        r.state = .invalid;
                        return i;
                    }
                    const add = @addWithOverflow(mul[0], digit);
                    if (add[1] != 0) {
                        r.state = .invalid;
                        return i;
                    }
                    r.next_chunk_length = add[0];
                } else {
                    return i;
                }
            }
            assert(r.state == .chunk_r);
            if (i == bytes.len) return i;

            if (bytes[i] == '\n') {
                r.state = .chunk_data;
                return i + 1;
            } else {
                r.state = .invalid;
                return i;
            }
        }

        fn parseInt3(nnn: @Vector(3, u8)) u10 {
            const zero: @Vector(3, u8) = .{ '0', '0', '0' };
            const mmm: @Vector(3, u10) = .{ 100, 10, 1 };
            return @reduce(.Add, @as(@Vector(3, u10), nnn -% zero) *% mmm);
        }

        test parseInt3 {
            const expectEqual = std.testing.expectEqual;
            try expectEqual(@as(u10, 0), parseInt3("000".*));
            try expectEqual(@as(u10, 418), parseInt3("418".*));
            try expectEqual(@as(u10, 999), parseInt3("999".*));
        }

        test "find headers end basic" {
            var buffer: [1]u8 = undefined;
            var r = Response.initStatic(&buffer);
            try testing.expectEqual(@as(usize, 10), r.findHeadersEnd("HTTP/1.1 4"));
            try testing.expectEqual(@as(usize, 2), r.findHeadersEnd("18"));
            try testing.expectEqual(@as(usize, 8), r.findHeadersEnd(" lol\r\n\r\nblah blah"));
        }

        test "find headers end vectorized" {
            var buffer: [1]u8 = undefined;
            var r = Response.initStatic(&buffer);
            const example =
                "HTTP/1.1 301 Moved Permanently\r\n" ++
                "Location: https://www.example.com/\r\n" ++
                "Content-Type: text/html; charset=UTF-8\r\n" ++
                "Content-Length: 220\r\n" ++
                "\r\ncontent";
            try testing.expectEqual(@as(usize, 131), r.findHeadersEnd(example));
        }

        test "find headers end bug" {
            var buffer: [1]u8 = undefined;
            var r = Response.initStatic(&buffer);
            const trail = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
            const example =
                "HTTP/1.1 200 OK\r\n" ++
                "Access-Control-Allow-Origin: https://render.githubusercontent.com\r\n" ++
                "content-disposition: attachment; filename=zig-0.10.0.tar.gz\r\n" ++
                "Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; sandbox\r\n" ++
                "Content-Type: application/x-gzip\r\n" ++
                "ETag: \"bfae0af6b01c7c0d89eb667cb5f0e65265968aeebda2689177e6b26acd3155ca\"\r\n" ++
                "Strict-Transport-Security: max-age=31536000\r\n" ++
                "Vary: Authorization,Accept-Encoding,Origin\r\n" ++
                "X-Content-Type-Options: nosniff\r\n" ++
                "X-Frame-Options: deny\r\n" ++
                "X-XSS-Protection: 1; mode=block\r\n" ++
                "Date: Fri, 06 Jan 2023 22:26:22 GMT\r\n" ++
                "Transfer-Encoding: chunked\r\n" ++
                "X-GitHub-Request-Id: 89C6:17E9:A7C9E:124B51:63B8A00E\r\n" ++
                "connection: close\r\n\r\n" ++ trail;
            try testing.expectEqual(@as(usize, example.len - trail.len), r.findHeadersEnd(example));
        }
    };

    pub const RequestTransfer = union(enum) {
        content_length: u64,
        chunked: void,
        none: void,
    };

    pub const Headers = struct {
        version: http.Version = .@"HTTP/1.1",
        method: http.Method = .GET,
        user_agent: []const u8 = "Zig (std.http)",
        connection: http.Connection = .keep_alive,
        transfer_encoding: RequestTransfer = .none,

        custom: []const http.CustomHeader = &[_]http.CustomHeader{},
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

    /// Frees all resources associated with the request.
    pub fn deinit(req: *Request) void {
        switch (req.response.compression) {
            .none => {},
            .deflate => |*deflate| deflate.deinit(),
            .gzip => |*gzip| gzip.deinit(),
        }

        if (req.response.header_bytes_owned) {
            req.response.header_bytes.deinit(req.client.allocator);
        }

        if (!req.response.done) {
            // If the response wasn't fully read, then we need to close the connection.
            req.connection.data.closing = true;
            req.client.release(req.connection);
        }

        req.arena.deinit();
        req.* = undefined;
    }

    const ReadRawError = Connection.ReadError || Uri.ParseError || RequestError || error{
        UnexpectedEndOfStream,
        TooManyHttpRedirects,
        HttpRedirectMissingLocation,
        HttpHeadersInvalid,
    };

    const ReaderRaw = std.io.Reader(*Request, ReadRawError, readRaw);

    /// Read from the underlying stream, without decompressing or parsing the headers. Must be called
    /// after waitForCompleteHead() has returned successfully.
    pub fn readRaw(req: *Request, buffer: []u8) ReadRawError!usize {
        assert(req.response.state.isContent());

        var index: usize = 0;
        while (index == 0) {
            const amt = try req.readRawAdvanced(buffer[index..]);
            if (amt == 0 and req.response.done) break;
            index += amt;
        }

        return index;
    }

    fn checkForCompleteHead(req: *Request, buffer: []u8) !usize {
        switch (req.response.state) {
            .invalid => unreachable,
            .start, .seen_r, .seen_rn, .seen_rnr => {},
            else => return 0, // No more headers to read.
        }

        const i = req.response.findHeadersEnd(buffer[0..]);
        if (req.response.state == .invalid) return error.HttpHeadersInvalid;

        const headers_data = buffer[0..i];
        if (req.response.header_bytes.items.len + headers_data.len > req.response.max_header_bytes) {
            return error.HttpHeadersExceededSizeLimit;
        }
        try req.response.header_bytes.appendSlice(req.client.allocator, headers_data);

        if (req.response.state == .finished) {
            req.response.headers = try Response.Headers.parse(req.response.header_bytes.items);

            if (req.response.headers.connection == .keep_alive) {
                req.connection.data.closing = false;
            } else {
                req.connection.data.closing = true;
            }

            if (req.response.headers.transfer_encoding) |transfer_encoding| {
                switch (transfer_encoding) {
                    .chunked => {
                        req.response.next_chunk_length = 0;
                        req.response.state = .chunk_size;
                    },
                    .compress => unreachable,
                    .deflate => unreachable,
                    .gzip => unreachable,
                }
            } else if (req.response.headers.content_length) |content_length| {
                req.response.next_chunk_length = content_length;

                if (content_length == 0) req.response.done = true;
            } else {
                req.response.done = true;
            }

            return i;
        }

        return 0;
    }

    pub const WaitForCompleteHeadError = ReadRawError || error{
        UnexpectedEndOfStream,

        HttpHeadersExceededSizeLimit,
        ShortHttpStatusLine,
        BadHttpVersion,
        HttpHeaderContinuationsUnsupported,
        HttpTransferEncodingUnsupported,
        HttpConnectionHeaderUnsupported,
    };

    /// Reads a complete response head. Any leftover data is stored in the request. This function is idempotent.
    pub fn waitForCompleteHead(req: *Request) WaitForCompleteHeadError!void {
        if (req.response.state.isContent()) return;

        while (true) {
            const nread = try req.connection.data.read(req.read_buffer[0..]);
            const amt = try checkForCompleteHead(req, req.read_buffer[0..nread]);

            if (amt != 0) {
                req.read_buffer_start = @intCast(ReadBufferIndex, amt);
                req.read_buffer_len = @intCast(ReadBufferIndex, nread);
                return;
            } else if (nread == 0) {
                return error.UnexpectedEndOfStream;
            }
        }
    }

    /// This one can return 0 without meaning EOF.
    fn readRawAdvanced(req: *Request, buffer: []u8) !usize {
        assert(req.response.state.isContent());
        if (req.response.done) return 0;

        // var in: []const u8 = undefined;
        if (req.read_buffer_start == req.read_buffer_len) {
            const nread = try req.connection.data.read(req.read_buffer[0..]);
            if (nread == 0) return error.UnexpectedEndOfStream;

            req.read_buffer_start = 0;
            req.read_buffer_len = @intCast(ReadBufferIndex, nread);
        }

        var out_index: usize = 0;
        while (true) {
            switch (req.response.state) {
                .invalid, .start, .seen_r, .seen_rn, .seen_rnr => unreachable,
                .finished => {
                    // TODO https://github.com/ziglang/zig/issues/14039
                    const buf_avail = req.read_buffer_len - req.read_buffer_start;
                    const data_avail = req.response.next_chunk_length;
                    const out_avail = buffer.len;

                    if (req.handle_redirects and req.response.headers.status.class() == .redirect) {
                        const can_read = @intCast(usize, @min(buf_avail, data_avail));
                        req.response.next_chunk_length -= can_read;

                        if (req.response.next_chunk_length == 0) {
                            req.client.release(req.connection);
                            req.connection = undefined;
                            req.response.done = true;
                        }

                        return 0; // skip over as much data as possible
                    }

                    const can_read = @intCast(usize, @min(@min(buf_avail, data_avail), out_avail));
                    req.response.next_chunk_length -= can_read;

                    mem.copy(u8, buffer[0..], req.read_buffer[req.read_buffer_start..][0..can_read]);
                    req.read_buffer_start += @intCast(ReadBufferIndex, can_read);

                    if (req.response.next_chunk_length == 0) {
                        req.client.release(req.connection);
                        req.connection = undefined;
                        req.response.done = true;
                    }

                    return can_read;
                },
                .chunk_size_prefix_r => switch (req.read_buffer_len - req.read_buffer_start) {
                    0 => return out_index,
                    1 => switch (req.read_buffer[req.read_buffer_start]) {
                        '\r' => {
                            req.response.state = .chunk_size_prefix_n;
                            return out_index;
                        },
                        else => {
                            req.response.state = .invalid;
                            return error.HttpHeadersInvalid;
                        },
                    },
                    else => switch (int16(req.read_buffer[req.read_buffer_start..][0..2])) {
                        int16("\r\n") => {
                            req.read_buffer_start += 2;
                            req.response.state = .chunk_size;
                            continue;
                        },
                        else => {
                            req.response.state = .invalid;
                            return error.HttpHeadersInvalid;
                        },
                    },
                },
                .chunk_size_prefix_n => switch (req.read_buffer_len - req.read_buffer_start) {
                    0 => return out_index,
                    else => switch (req.read_buffer[req.read_buffer_start]) {
                        '\n' => {
                            req.read_buffer_start += 1;
                            req.response.state = .chunk_size;
                            continue;
                        },
                        else => {
                            req.response.state = .invalid;
                            return error.HttpHeadersInvalid;
                        },
                    },
                },
                .chunk_size, .chunk_r => {
                    const i = req.response.findChunkedLen(req.read_buffer[req.read_buffer_start..req.read_buffer_len]);
                    switch (req.response.state) {
                        .invalid => return error.HttpHeadersInvalid,
                        .chunk_data => {
                            if (req.response.next_chunk_length == 0) {
                                req.response.done = true;
                                req.client.release(req.connection);
                                req.connection = undefined;

                                return out_index;
                            }

                            req.read_buffer_start += @intCast(ReadBufferIndex, i);
                            continue;
                        },
                        .chunk_size => return out_index,
                        else => unreachable,
                    }
                },
                .chunk_data => {
                    // TODO https://github.com/ziglang/zig/issues/14039
                    const buf_avail = req.read_buffer_len - req.read_buffer_start;
                    const data_avail = req.response.next_chunk_length;
                    const out_avail = buffer.len - out_index;

                    if (req.handle_redirects and req.response.headers.status.class() == .redirect) {
                        const can_read = @intCast(usize, @min(buf_avail, data_avail));
                        req.response.next_chunk_length -= can_read;

                        if (req.response.next_chunk_length == 0) {
                            req.client.release(req.connection);
                            req.connection = undefined;
                            req.response.done = true;
                            continue;
                        }

                        return 0; // skip over as much data as possible
                    }

                    const can_read = @intCast(usize, @min(@min(buf_avail, data_avail), out_avail));
                    req.response.next_chunk_length -= can_read;

                    mem.copy(u8, buffer[out_index..], req.read_buffer[req.read_buffer_start..][0..can_read]);
                    req.read_buffer_start += @intCast(ReadBufferIndex, can_read);
                    out_index += can_read;

                    if (req.response.next_chunk_length == 0) {
                        req.response.state = .chunk_size_prefix_r;

                        continue;
                    }

                    return out_index;
                },
            }
        }
    }

    pub const ReadError = DeflateDecompressor.Error || GzipDecompressor.Error || WaitForCompleteHeadError || error{
        BadHeader,
        InvalidCompression,
        StreamTooLong,
        InvalidWindowSize,
    };

    pub const Reader = std.io.Reader(*Request, ReadError, read);

    pub fn reader(req: *Request) Reader {
        return .{ .context = req };
    }

    pub fn read(req: *Request, buffer: []u8) ReadError!usize {
        while (true) {
            if (!req.response.state.isContent()) try req.waitForCompleteHead();

            if (req.handle_redirects and req.response.headers.status.class() == .redirect) {
                assert(try req.readRaw(buffer) == 0);

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
                    .header_strategy = if (req.response.header_bytes_owned) .{
                        .dynamic = req.response.max_header_bytes,
                    } else .{
                        .static = req.response.header_bytes.unusedCapacitySlice(),
                    },
                });
                req.deinit();
                req.* = new_req;
            } else {
                break;
            }
        }

        if (req.response.compression == .none) {
            if (req.response.headers.transfer_compression) |compression| {
                switch (compression) {
                    .compress => unreachable,
                    .deflate => req.response.compression = .{
                        .deflate = try std.compress.zlib.zlibStream(req.client.allocator, ReaderRaw{ .context = req }),
                    },
                    .gzip => req.response.compression = .{
                        .gzip = try std.compress.gzip.decompress(req.client.allocator, ReaderRaw{ .context = req }),
                    },
                    .chunked => unreachable,
                }
            }
        }

        return switch (req.response.compression) {
            .deflate => |*deflate| try deflate.read(buffer),
            .gzip => |*gzip| try gzip.read(buffer),
            else => try req.readRaw(buffer),
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

    pub const WriteError = Connection.WriteError || error{MessageTooLong};

    pub const Writer = std.io.Writer(*Request, WriteError, write);

    pub fn writer(req: *Request) Writer {
        return .{ .context = req };
    }

    /// Write `bytes` to the server. The `transfer_encoding` request header determines how data will be sent.
    pub fn write(req: *Request, bytes: []const u8) !usize {
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

    inline fn int16(array: *const [2]u8) u16 {
        return @bitCast(u16, array.*);
    }

    inline fn int32(array: *const [4]u8) u32 {
        return @bitCast(u32, array.*);
    }

    inline fn int64(array: *const [8]u8) u64 {
        return @bitCast(u64, array.*);
    }

    test {
        const builtin = @import("builtin");

        if (builtin.os.tag == .wasi) return error.SkipZigTest;

        _ = Response;
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
            .dynamic => |max| Request.Response.initDynamic(max),
            .static => |buf| Request.Response.initStatic(buf),
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
        try writer.writeAll("\r\nAccept-Encoding: gzip, deflate");

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
