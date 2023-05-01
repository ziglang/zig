const std = @import("../std.zig");
const testing = std.testing;
const http = std.http;
const mem = std.mem;
const net = std.net;
const Uri = std.Uri;
const Allocator = mem.Allocator;
const assert = std.debug.assert;

const Server = @This();
const proto = @import("protocol.zig");

allocator: Allocator,

socket: net.StreamServer,

/// An interface to either a plain or TLS connection.
pub const Connection = struct {
    stream: net.Stream,
    protocol: Protocol,

    closing: bool = true,

    pub const Protocol = enum { plain };

    pub fn read(conn: *Connection, buffer: []u8) ReadError!usize {
        return switch (conn.protocol) {
            .plain => conn.stream.read(buffer),
            // .tls => return conn.tls_client.read(conn.stream, buffer),
        } catch |err| switch (err) {
            error.ConnectionTimedOut => return error.ConnectionTimedOut,
            error.ConnectionResetByPeer, error.BrokenPipe => return error.ConnectionResetByPeer,
            else => return error.UnexpectedReadFailure,
        };
    }

    pub fn readAtLeast(conn: *Connection, buffer: []u8, len: usize) ReadError!usize {
        return switch (conn.protocol) {
            .plain => conn.stream.readAtLeast(buffer, len),
            // .tls => return conn.tls_client.readAtLeast(conn.stream, buffer, len),
        } catch |err| switch (err) {
            error.ConnectionTimedOut => return error.ConnectionTimedOut,
            error.ConnectionResetByPeer, error.BrokenPipe => return error.ConnectionResetByPeer,
            else => return error.UnexpectedReadFailure,
        };
    }

    pub const ReadError = error{
        ConnectionTimedOut,
        ConnectionResetByPeer,
        UnexpectedReadFailure,
    };

    pub const Reader = std.io.Reader(*Connection, ReadError, read);

    pub fn reader(conn: *Connection) Reader {
        return Reader{ .context = conn };
    }

    pub fn writeAll(conn: *Connection, buffer: []const u8) WriteError!void {
        return switch (conn.protocol) {
            .plain => conn.stream.writeAll(buffer),
            // .tls => return conn.tls_client.writeAll(conn.stream, buffer),
        } catch |err| switch (err) {
            error.BrokenPipe, error.ConnectionResetByPeer => return error.ConnectionResetByPeer,
            else => return error.UnexpectedWriteFailure,
        };
    }

    pub fn write(conn: *Connection, buffer: []const u8) WriteError!usize {
        return switch (conn.protocol) {
            .plain => conn.stream.write(buffer),
            // .tls => return conn.tls_client.write(conn.stream, buffer),
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

    pub fn close(conn: *Connection) void {
        conn.stream.close();
    }
};

/// A buffered (and peekable) Connection.
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

                @memcpy(buffer[out_index..][0..can_read], bconn.buf[bconn.start..][0..can_read]);
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

    pub fn close(bconn: *BufferedConnection) void {
        bconn.conn.close();
    }
};

/// The mode of transport for responses.
pub const ResponseTransfer = union(enum) {
    content_length: u64,
    chunked: void,
    none: void,
};

/// The decompressor for request messages.
pub const Compression = union(enum) {
    pub const DeflateDecompressor = std.compress.zlib.ZlibStream(Response.TransferReader);
    pub const GzipDecompressor = std.compress.gzip.Decompress(Response.TransferReader);
    pub const ZstdDecompressor = std.compress.zstd.DecompressStream(Response.TransferReader, .{});

    deflate: DeflateDecompressor,
    gzip: GzipDecompressor,
    zstd: ZstdDecompressor,
    none: void,
};

/// A HTTP request originating from a client.
pub const Request = struct {
    pub const ParseError = Allocator.Error || error{
        ShortHttpStatusLine,
        BadHttpVersion,
        UnknownHttpMethod,
        HttpHeadersInvalid,
        HttpHeaderContinuationsUnsupported,
        HttpTransferEncodingUnsupported,
        HttpConnectionHeaderUnsupported,
        InvalidContentLength,
        CompressionNotSupported,
    };

    pub fn parse(req: *Request, bytes: []const u8) ParseError!void {
        var it = mem.tokenize(u8, bytes[0 .. bytes.len - 4], "\r\n");

        const first_line = it.next() orelse return error.HttpHeadersInvalid;
        if (first_line.len < 10)
            return error.ShortHttpStatusLine;

        const method_end = mem.indexOfScalar(u8, first_line, ' ') orelse return error.HttpHeadersInvalid;
        const method_str = first_line[0..method_end];
        const method = std.meta.stringToEnum(http.Method, method_str) orelse return error.UnknownHttpMethod;

        const version_start = mem.lastIndexOfScalar(u8, first_line, ' ') orelse return error.HttpHeadersInvalid;
        if (version_start == method_end) return error.HttpHeadersInvalid;

        const version_str = first_line[version_start + 1 ..];
        if (version_str.len != 8) return error.HttpHeadersInvalid;
        const version: http.Version = switch (int64(version_str[0..8])) {
            int64("HTTP/1.0") => .@"HTTP/1.0",
            int64("HTTP/1.1") => .@"HTTP/1.1",
            else => return error.BadHttpVersion,
        };

        const target = first_line[method_end + 1 .. version_start];

        req.method = method;
        req.target = target;
        req.version = version;

        while (it.next()) |line| {
            if (line.len == 0) return error.HttpHeadersInvalid;
            switch (line[0]) {
                ' ', '\t' => return error.HttpHeaderContinuationsUnsupported,
                else => {},
            }

            var line_it = mem.tokenize(u8, line, ": ");
            const header_name = line_it.next() orelse return error.HttpHeadersInvalid;
            const header_value = line_it.rest();

            try req.headers.append(header_name, header_value);

            if (std.ascii.eqlIgnoreCase(header_name, "content-length")) {
                if (req.content_length != null) return error.HttpHeadersInvalid;
                req.content_length = std.fmt.parseInt(u64, header_value, 10) catch return error.InvalidContentLength;
            } else if (std.ascii.eqlIgnoreCase(header_name, "transfer-encoding")) {
                // Transfer-Encoding: second, first
                // Transfer-Encoding: deflate, chunked
                var iter = mem.splitBackwards(u8, header_value, ",");

                if (iter.next()) |first| {
                    const trimmed = mem.trim(u8, first, " ");

                    if (std.meta.stringToEnum(http.TransferEncoding, trimmed)) |te| {
                        if (req.transfer_encoding != null) return error.HttpHeadersInvalid;
                        req.transfer_encoding = te;
                    } else if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                        if (req.transfer_compression != null) return error.HttpHeadersInvalid;
                        req.transfer_compression = ce;
                    } else {
                        return error.HttpTransferEncodingUnsupported;
                    }
                }

                if (iter.next()) |second| {
                    if (req.transfer_compression != null) return error.HttpTransferEncodingUnsupported;

                    const trimmed = mem.trim(u8, second, " ");

                    if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                        req.transfer_compression = ce;
                    } else {
                        return error.HttpTransferEncodingUnsupported;
                    }
                }

                if (iter.next()) |_| return error.HttpTransferEncodingUnsupported;
            } else if (std.ascii.eqlIgnoreCase(header_name, "content-encoding")) {
                if (req.transfer_compression != null) return error.HttpHeadersInvalid;

                const trimmed = mem.trim(u8, header_value, " ");

                if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                    req.transfer_compression = ce;
                } else {
                    return error.HttpTransferEncodingUnsupported;
                }
            }
        }
    }

    inline fn int64(array: *const [8]u8) u64 {
        return @bitCast(u64, array.*);
    }

    method: http.Method,
    target: []const u8,
    version: http.Version,

    content_length: ?u64 = null,
    transfer_encoding: ?http.TransferEncoding = null,
    transfer_compression: ?http.ContentEncoding = null,

    headers: http.Headers = undefined,
    parser: proto.HeadersParser,
    compression: Compression = .none,
};

/// A HTTP response waiting to be sent.
///
///                                  [/ <----------------------------------- \]
/// Order of operations: accept -> wait -> do  [ -> write -> finish][ -> reset /]
///                                   \ -> read /
pub const Response = struct {
    version: http.Version = .@"HTTP/1.1",
    status: http.Status = .ok,
    reason: ?[]const u8 = null,

    transfer_encoding: ResponseTransfer = .none,

    server: *Server,
    address: net.Address,
    connection: BufferedConnection,

    headers: http.Headers,
    request: Request,

    pub fn deinit(res: *Response) void {
        res.server.allocator.destroy(res);
    }

    /// Reset this response to its initial state. This must be called before handling a second request on the same connection.
    pub fn reset(res: *Response) void {
        res.request.headers.deinit();
        res.headers.deinit();

        switch (res.request.compression) {
            .none => {},
            .deflate => |*deflate| deflate.deinit(),
            .gzip => |*gzip| gzip.deinit(),
            .zstd => |*zstd| zstd.deinit(),
        }

        if (!res.request.parser.done) {
            // If the response wasn't fully read, then we need to close the connection.
            res.connection.conn.closing = true;
        }

        if (res.connection.conn.closing) {
            res.connection.close();

            if (res.request.parser.header_bytes_owned) {
                res.request.parser.header_bytes.deinit(res.server.allocator);
            }
        } else {
            res.request.parser.reset();
        }
    }

    pub const DoError = BufferedConnection.WriteError || error{ UnsupportedTransferEncoding, InvalidContentLength };

    /// Send the response headers.
    pub fn do(res: *Response) !void {
        var buffered = std.io.bufferedWriter(res.connection.writer());
        const w = buffered.writer();

        try w.writeAll(@tagName(res.version));
        try w.writeByte(' ');
        try w.print("{d}", .{@enumToInt(res.status)});
        try w.writeByte(' ');
        if (res.reason) |reason| {
            try w.writeAll(reason);
        } else if (res.status.phrase()) |phrase| {
            try w.writeAll(phrase);
        }
        try w.writeAll("\r\n");

        if (!res.headers.contains("server")) {
            try w.writeAll("Server: zig (std.http)\r\n");
        }

        if (!res.headers.contains("connection")) {
            try w.writeAll("Connection: keep-alive\r\n");
        }

        const has_transfer_encoding = res.headers.contains("transfer-encoding");
        const has_content_length = res.headers.contains("content-length");

        if (!has_transfer_encoding and !has_content_length) {
            switch (res.transfer_encoding) {
                .chunked => try w.writeAll("Transfer-Encoding: chunked\r\n"),
                .content_length => |content_length| try w.print("Content-Length: {d}\r\n", .{content_length}),
                .none => {},
            }
        } else {
            if (has_content_length) {
                const content_length = std.fmt.parseInt(u64, res.headers.getFirstValue("content-length").?, 10) catch return error.InvalidContentLength;

                res.transfer_encoding = .{ .content_length = content_length };
            } else if (has_transfer_encoding) {
                const transfer_encoding = res.headers.getFirstValue("content-length").?;
                if (std.mem.eql(u8, transfer_encoding, "chunked")) {
                    res.transfer_encoding = .chunked;
                } else {
                    return error.UnsupportedTransferEncoding;
                }
            } else {
                res.transfer_encoding = .none;
            }
        }

        try w.print("{}", .{res.headers});

        try w.writeAll("\r\n");

        try buffered.flush();
    }

    pub const TransferReadError = BufferedConnection.ReadError || proto.HeadersParser.ReadError;

    pub const TransferReader = std.io.Reader(*Response, TransferReadError, transferRead);

    pub fn transferReader(res: *Response) TransferReader {
        return .{ .context = res };
    }

    fn transferRead(res: *Response, buf: []u8) TransferReadError!usize {
        if (res.request.parser.done) return 0;

        var index: usize = 0;
        while (index == 0) {
            const amt = try res.request.parser.read(&res.connection, buf[index..], false);
            if (amt == 0 and res.request.parser.done) break;
            index += amt;
        }

        return index;
    }

    pub const WaitError = BufferedConnection.ReadError || proto.HeadersParser.CheckCompleteHeadError || Request.ParseError || error{ CompressionInitializationFailed, CompressionNotSupported };

    /// Wait for the client to send a complete request head.
    pub fn wait(res: *Response) WaitError!void {
        while (true) {
            try res.connection.fill();

            const nchecked = try res.request.parser.checkCompleteHead(res.server.allocator, res.connection.peek());
            res.connection.clear(@intCast(u16, nchecked));

            if (res.request.parser.state.isContent()) break;
        }

        res.request.headers = .{ .allocator = res.server.allocator, .owned = true };
        try res.request.parse(res.request.parser.header_bytes.items);

        const res_connection = res.headers.getFirstValue("connection");
        const res_keepalive = res_connection != null and !std.ascii.eqlIgnoreCase("close", res_connection.?);

        const req_connection = res.request.headers.getFirstValue("connection");
        const req_keepalive = req_connection != null and !std.ascii.eqlIgnoreCase("close", req_connection.?);
        if (res_keepalive and req_keepalive) {
            res.connection.conn.closing = false;
        } else {
            res.connection.conn.closing = true;
        }

        if (res.request.transfer_encoding) |te| {
            switch (te) {
                .chunked => {
                    res.request.parser.next_chunk_length = 0;
                    res.request.parser.state = .chunk_head_size;
                },
            }
        } else if (res.request.content_length) |cl| {
            res.request.parser.next_chunk_length = cl;

            if (cl == 0) res.request.parser.done = true;
        } else {
            res.request.parser.done = true;
        }

        if (!res.request.parser.done) {
            if (res.request.transfer_compression) |tc| switch (tc) {
                .compress => return error.CompressionNotSupported,
                .deflate => res.request.compression = .{
                    .deflate = std.compress.zlib.zlibStream(res.server.allocator, res.transferReader()) catch return error.CompressionInitializationFailed,
                },
                .gzip => res.request.compression = .{
                    .gzip = std.compress.gzip.decompress(res.server.allocator, res.transferReader()) catch return error.CompressionInitializationFailed,
                },
                .zstd => res.request.compression = .{
                    .zstd = std.compress.zstd.decompressStream(res.server.allocator, res.transferReader()),
                },
            };
        }
    }

    pub const ReadError = TransferReadError || proto.HeadersParser.CheckCompleteHeadError || error{ DecompressionFailure, InvalidTrailers };

    pub const Reader = std.io.Reader(*Response, ReadError, read);

    pub fn reader(res: *Response) Reader {
        return .{ .context = res };
    }

    pub fn read(res: *Response, buffer: []u8) ReadError!usize {
        const out_index = switch (res.request.compression) {
            .deflate => |*deflate| deflate.read(buffer) catch return error.DecompressionFailure,
            .gzip => |*gzip| gzip.read(buffer) catch return error.DecompressionFailure,
            .zstd => |*zstd| zstd.read(buffer) catch return error.DecompressionFailure,
            else => try res.transferRead(buffer),
        };

        if (out_index == 0) {
            const has_trail = !res.request.parser.state.isContent();

            while (!res.request.parser.state.isContent()) { // read trailing headers
                try res.connection.fill();

                const nchecked = try res.request.parser.checkCompleteHead(res.server.allocator, res.connection.peek());
                res.connection.clear(@intCast(u16, nchecked));
            }

            if (has_trail) {
                res.request.headers = http.Headers{ .allocator = res.server.allocator, .owned = false };

                // The response headers before the trailers are already guaranteed to be valid, so they will always be parsed again and cannot return an error.
                // This will *only* fail for a malformed trailer.
                res.request.parse(res.request.parser.header_bytes.items) catch return error.InvalidTrailers;
            }
        }

        return out_index;
    }

    pub fn readAll(res: *Response, buffer: []u8) !usize {
        var index: usize = 0;
        while (index < buffer.len) {
            const amt = try read(res, buffer[index..]);
            if (amt == 0) break;
            index += amt;
        }
        return index;
    }

    pub const WriteError = BufferedConnection.WriteError || error{ NotWriteable, MessageTooLong };

    pub const Writer = std.io.Writer(*Response, WriteError, write);

    pub fn writer(res: *Response) Writer {
        return .{ .context = res };
    }

    /// Write `bytes` to the server. The `transfer_encoding` request header determines how data will be sent.
    pub fn write(res: *Response, bytes: []const u8) WriteError!usize {
        switch (res.transfer_encoding) {
            .chunked => {
                try res.connection.writer().print("{x}\r\n", .{bytes.len});
                try res.connection.writeAll(bytes);
                try res.connection.writeAll("\r\n");

                return bytes.len;
            },
            .content_length => |*len| {
                if (len.* < bytes.len) return error.MessageTooLong;

                const amt = try res.connection.write(bytes);
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
    pub fn finish(res: *Response) FinishError!void {
        switch (res.transfer_encoding) {
            .chunked => try res.connection.writeAll("0\r\n\r\n"),
            .content_length => |len| if (len != 0) return error.MessageNotCompleted,
            .none => {},
        }
    }
};

pub fn init(allocator: Allocator, options: net.StreamServer.Options) Server {
    return .{
        .allocator = allocator,
        .socket = net.StreamServer.init(options),
    };
}

pub fn deinit(server: *Server) void {
    server.socket.deinit();
}

pub const ListenError = std.os.SocketError || std.os.BindError || std.os.ListenError || std.os.SetSockOptError || std.os.GetSockNameError;

/// Start the HTTP server listening on the given address.
pub fn listen(server: *Server, address: net.Address) !void {
    try server.socket.listen(address);
}

pub const AcceptError = net.StreamServer.AcceptError || Allocator.Error;

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

/// Accept a new connection and allocate a Response for it.
pub fn accept(server: *Server, options: HeaderStrategy) AcceptError!*Response {
    const in = try server.socket.accept();

    const res = try server.allocator.create(Response);
    res.* = .{
        .server = server,
        .address = in.address,
        .connection = .{ .conn = .{
            .stream = in.stream,
            .protocol = .plain,
        } },
        .headers = .{ .allocator = server.allocator },
        .request = .{
            .version = undefined,
            .method = undefined,
            .target = undefined,
            .parser = switch (options) {
                .dynamic => |max| proto.HeadersParser.initDynamic(max),
                .static => |buf| proto.HeadersParser.initStatic(buf),
            },
        },
    };

    return res;
}

test "HTTP server handles a chunked transfer coding request" {
    const builtin = @import("builtin");

    // This test requires spawning threads.
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    const native_endian = comptime builtin.cpu.arch.endian();
    if (builtin.zig_backend == .stage2_llvm and native_endian == .Big) {
        // https://github.com/ziglang/zig/issues/13782
        return error.SkipZigTest;
    }

    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    const max_header_size = 8192;
    var server = std.http.Server.init(allocator, .{ .reuse_address = true });
    defer server.deinit();

    const address = try std.net.Address.parseIp("127.0.0.1", 0);
    try server.listen(address);
    const server_port = server.socket.listen_address.in.getPort();

    const server_thread = try std.Thread.spawn(.{}, (struct {
        fn apply(s: *std.http.Server) !void {
            const res = try s.accept(.{ .dynamic = max_header_size });
            defer res.deinit();
            defer res.reset();
            try res.wait();

            try expect(res.request.transfer_encoding.? == .chunked);

            const server_body: []const u8 = "message from server!\n";
            res.transfer_encoding = .{ .content_length = server_body.len };
            try res.headers.append("content-type", "text/plain");
            try res.headers.append("connection", "close");
            try res.do();

            var buf: [128]u8 = undefined;
            const n = try res.readAll(&buf);
            try expect(std.mem.eql(u8, buf[0..n], "ABCD"));
            _ = try res.writer().writeAll(server_body);
            try res.finish();
        }
    }).apply, .{&server});

    const request_bytes =
        "POST / HTTP/1.1\r\n" ++
        "Content-Type: text/plain\r\n" ++
        "Transfer-Encoding: chunked\r\n" ++
        "\r\n" ++
        "1\r\n" ++
        "A\r\n" ++
        "1\r\n" ++
        "B\r\n" ++
        "2\r\n" ++
        "CD\r\n" ++
        "0\r\n" ++
        "\r\n";

    const stream = try std.net.tcpConnectToHost(allocator, "127.0.0.1", server_port);
    defer stream.close();
    _ = try stream.writeAll(request_bytes[0..]);

    server_thread.join();
}
