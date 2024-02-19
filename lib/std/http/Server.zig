version: http.Version,
status: http.Status,
reason: ?[]const u8,
transfer_encoding: ResponseTransfer,
keep_alive: bool,
connection: Connection,
connection_closing: bool,

/// Externally-owned; must outlive the Server.
extra_headers: []const http.Header,

/// The HTTP request that this response is responding to.
///
/// This field is only valid after calling `wait`.
request: Request,

state: State = .first,

/// Initialize an HTTP server that can respond to multiple requests on the same
/// connection.
/// The returned `Server` is ready for `reset` or `wait` to be called.
pub fn init(connection: std.net.Server.Connection, options: Server.Request.InitOptions) Server {
    return .{
        .transfer_encoding = .none,
        .keep_alive = true,
        .connection = .{
            .stream = connection.stream,
            .read_buf = undefined,
            .read_start = 0,
            .read_end = 0,
        },
        .connection_closing = true,
        .request = Server.Request.init(options),
        .version = .@"HTTP/1.1",
        .status = .ok,
        .reason = null,
        .extra_headers = &.{},
    };
}

pub const State = enum {
    first,
    start,
    waited,
    responded,
    finished,
};

pub const ResetState = enum { reset, closing };

pub const Connection = @import("Server/Connection.zig");

/// The mode of transport for responses.
pub const ResponseTransfer = union(enum) {
    content_length: u64,
    chunked: void,
    none: void,
};

/// The decompressor for request messages.
pub const Compression = union(enum) {
    pub const DeflateDecompressor = std.compress.zlib.Decompressor(Server.TransferReader);
    pub const GzipDecompressor = std.compress.gzip.Decompressor(Server.TransferReader);
    // https://github.com/ziglang/zig/issues/18937
    //pub const ZstdDecompressor = std.compress.zstd.DecompressStream(Server.TransferReader, .{});

    deflate: DeflateDecompressor,
    gzip: GzipDecompressor,
    // https://github.com/ziglang/zig/issues/18937
    //zstd: ZstdDecompressor,
    none: void,
};

/// A HTTP request originating from a client.
pub const Request = struct {
    method: http.Method,
    target: []const u8,
    version: http.Version,
    expect: ?[]const u8,
    content_type: ?[]const u8,
    content_length: ?u64,
    transfer_encoding: http.TransferEncoding,
    transfer_compression: http.ContentEncoding,
    keep_alive: bool,
    parser: proto.HeadersParser,
    compression: Compression,

    pub const InitOptions = struct {
        /// Externally-owned memory used to store the client's entire HTTP header.
        /// `error.HttpHeadersOversize` is returned from read() when a
        /// client sends too many bytes of HTTP headers.
        client_header_buffer: []u8,
    };

    pub fn init(options: InitOptions) Request {
        return .{
            .method = undefined,
            .target = undefined,
            .version = undefined,
            .expect = null,
            .content_type = null,
            .content_length = null,
            .transfer_encoding = .none,
            .transfer_compression = .identity,
            .keep_alive = false,
            .parser = proto.HeadersParser.init(options.client_header_buffer),
            .compression = .none,
        };
    }

    pub const ParseError = Allocator.Error || error{
        UnknownHttpMethod,
        HttpHeadersInvalid,
        HttpHeaderContinuationsUnsupported,
        HttpTransferEncodingUnsupported,
        HttpConnectionHeaderUnsupported,
        InvalidContentLength,
        CompressionUnsupported,
    };

    pub fn parse(req: *Request, bytes: []const u8) ParseError!void {
        var it = mem.splitSequence(u8, bytes, "\r\n");

        const first_line = it.next().?;
        if (first_line.len < 10)
            return error.HttpHeadersInvalid;

        const method_end = mem.indexOfScalar(u8, first_line, ' ') orelse
            return error.HttpHeadersInvalid;
        if (method_end > 24) return error.HttpHeadersInvalid;

        const method_str = first_line[0..method_end];
        const method: http.Method = @enumFromInt(http.Method.parse(method_str));

        const version_start = mem.lastIndexOfScalar(u8, first_line, ' ') orelse
            return error.HttpHeadersInvalid;
        if (version_start == method_end) return error.HttpHeadersInvalid;

        const version_str = first_line[version_start + 1 ..];
        if (version_str.len != 8) return error.HttpHeadersInvalid;
        const version: http.Version = switch (int64(version_str[0..8])) {
            int64("HTTP/1.0") => .@"HTTP/1.0",
            int64("HTTP/1.1") => .@"HTTP/1.1",
            else => return error.HttpHeadersInvalid,
        };

        const target = first_line[method_end + 1 .. version_start];

        req.method = method;
        req.target = target;
        req.version = version;

        while (it.next()) |line| {
            if (line.len == 0) return;
            switch (line[0]) {
                ' ', '\t' => return error.HttpHeaderContinuationsUnsupported,
                else => {},
            }

            var line_it = mem.splitSequence(u8, line, ": ");
            const header_name = line_it.next().?;
            const header_value = line_it.rest();
            if (header_value.len == 0) return error.HttpHeadersInvalid;

            if (std.ascii.eqlIgnoreCase(header_name, "connection")) {
                req.keep_alive = !std.ascii.eqlIgnoreCase(header_value, "close");
            } else if (std.ascii.eqlIgnoreCase(header_name, "expect")) {
                req.expect = header_value;
            } else if (std.ascii.eqlIgnoreCase(header_name, "content-type")) {
                req.content_type = header_value;
            } else if (std.ascii.eqlIgnoreCase(header_name, "content-length")) {
                if (req.content_length != null) return error.HttpHeadersInvalid;
                req.content_length = std.fmt.parseInt(u64, header_value, 10) catch
                    return error.InvalidContentLength;
            } else if (std.ascii.eqlIgnoreCase(header_name, "content-encoding")) {
                if (req.transfer_compression != .identity) return error.HttpHeadersInvalid;

                const trimmed = mem.trim(u8, header_value, " ");

                if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                    req.transfer_compression = ce;
                } else {
                    return error.HttpTransferEncodingUnsupported;
                }
            } else if (std.ascii.eqlIgnoreCase(header_name, "transfer-encoding")) {
                // Transfer-Encoding: second, first
                // Transfer-Encoding: deflate, chunked
                var iter = mem.splitBackwardsScalar(u8, header_value, ',');

                const first = iter.first();
                const trimmed_first = mem.trim(u8, first, " ");

                var next: ?[]const u8 = first;
                if (std.meta.stringToEnum(http.TransferEncoding, trimmed_first)) |transfer| {
                    if (req.transfer_encoding != .none)
                        return error.HttpHeadersInvalid; // we already have a transfer encoding
                    req.transfer_encoding = transfer;

                    next = iter.next();
                }

                if (next) |second| {
                    const trimmed_second = mem.trim(u8, second, " ");

                    if (std.meta.stringToEnum(http.ContentEncoding, trimmed_second)) |transfer| {
                        if (req.transfer_compression != .identity)
                            return error.HttpHeadersInvalid; // double compression is not supported
                        req.transfer_compression = transfer;
                    } else {
                        return error.HttpTransferEncodingUnsupported;
                    }
                }

                if (iter.next()) |_| return error.HttpTransferEncodingUnsupported;
            }
        }
        return error.HttpHeadersInvalid; // missing empty line
    }

    inline fn int64(array: *const [8]u8) u64 {
        return @bitCast(array.*);
    }
};

/// Reset this response to its initial state. This must be called before
/// handling a second request on the same connection.
pub fn reset(res: *Server) ResetState {
    if (res.state == .first) {
        res.state = .start;
        return .reset;
    }

    if (!res.request.parser.done) {
        // If the response wasn't fully read, then we need to close the connection.
        res.connection_closing = true;
        return .closing;
    }

    // A connection is only keep-alive if the Connection header is present
    // and its value is not "close". The server and client must both agree.
    //
    // send() defaults to using keep-alive if the client requests it.
    res.connection_closing = !res.keep_alive or !res.request.keep_alive;

    res.state = .start;
    res.version = .@"HTTP/1.1";
    res.status = .ok;
    res.reason = null;

    res.transfer_encoding = .none;

    res.request = Request.init(.{
        .client_header_buffer = res.request.parser.header_bytes_buffer,
    });

    return if (res.connection_closing) .closing else .reset;
}

pub const SendError = Connection.WriteError || error{
    UnsupportedTransferEncoding,
    InvalidContentLength,
};

/// Send the HTTP response headers to the client.
pub fn send(res: *Server) SendError!void {
    switch (res.state) {
        .waited => res.state = .responded,
        .first, .start, .responded, .finished => unreachable,
    }

    var buffered = std.io.bufferedWriter(res.connection.writer());
    const w = buffered.writer();

    try w.writeAll(@tagName(res.version));
    try w.writeByte(' ');
    try w.print("{d}", .{@intFromEnum(res.status)});
    try w.writeByte(' ');
    if (res.reason) |reason| {
        try w.writeAll(reason);
    } else if (res.status.phrase()) |phrase| {
        try w.writeAll(phrase);
    }
    try w.writeAll("\r\n");

    if (res.status == .@"continue") {
        res.state = .waited; // we still need to send another request after this
    } else {
        if (res.keep_alive and res.request.keep_alive) {
            try w.writeAll("connection: keep-alive\r\n");
        } else {
            try w.writeAll("connection: close\r\n");
        }

        switch (res.transfer_encoding) {
            .chunked => try w.writeAll("transfer-encoding: chunked\r\n"),
            .content_length => |content_length| try w.print("content-length: {d}\r\n", .{content_length}),
            .none => {},
        }

        for (res.extra_headers) |header| {
            try w.print("{s}: {s}\r\n", .{ header.name, header.value });
        }
    }

    if (res.request.method == .HEAD) {
        res.transfer_encoding = .none;
    }

    try w.writeAll("\r\n");

    try buffered.flush();
}

const TransferReadError = Connection.ReadError || proto.HeadersParser.ReadError;

const TransferReader = std.io.Reader(*Server, TransferReadError, transferRead);

fn transferReader(res: *Server) TransferReader {
    return .{ .context = res };
}

fn transferRead(res: *Server, buf: []u8) TransferReadError!usize {
    if (res.request.parser.done) return 0;

    var index: usize = 0;
    while (index == 0) {
        const amt = try res.request.parser.read(&res.connection, buf[index..], false);
        if (amt == 0 and res.request.parser.done) break;
        index += amt;
    }

    return index;
}

pub const WaitError = Connection.ReadError ||
    proto.HeadersParser.CheckCompleteHeadError || Request.ParseError ||
    error{CompressionUnsupported};

/// Wait for the client to send a complete request head.
///
/// For correct behavior, the following rules must be followed:
///
/// * If this returns any error in `Connection.ReadError`, you MUST
///   immediately close the connection by calling `deinit`.
/// * If this returns `error.HttpHeadersInvalid`, you MAY immediately close
///   the connection by calling `deinit`.
/// * If this returns `error.HttpHeadersOversize`, you MUST
///   respond with a 431 status code and then call `deinit`.
/// * If this returns any error in `Request.ParseError`, you MUST respond
///   with a 400 status code and then call `deinit`.
/// * If this returns any other error, you MUST respond with a 400 status
///   code and then call `deinit`.
/// * If the request has an Expect header containing 100-continue, you MUST either:
///   * Respond with a 100 status code, then call `wait` again.
///   * Respond with a 417 status code.
pub fn wait(res: *Server) WaitError!void {
    switch (res.state) {
        .first, .start => res.state = .waited,
        .waited, .responded, .finished => unreachable,
    }

    while (true) {
        try res.connection.fill();

        const nchecked = try res.request.parser.checkCompleteHead(res.connection.peek());
        res.connection.drop(@intCast(nchecked));

        if (res.request.parser.state.isContent()) break;
    }

    try res.request.parse(res.request.parser.get());

    switch (res.request.transfer_encoding) {
        .none => {
            if (res.request.content_length) |len| {
                res.request.parser.next_chunk_length = len;

                if (len == 0) res.request.parser.done = true;
            } else {
                res.request.parser.done = true;
            }
        },
        .chunked => {
            res.request.parser.next_chunk_length = 0;
            res.request.parser.state = .chunk_head_size;
        },
    }

    if (!res.request.parser.done) {
        switch (res.request.transfer_compression) {
            .identity => res.request.compression = .none,
            .compress, .@"x-compress" => return error.CompressionUnsupported,
            .deflate => res.request.compression = .{
                .deflate = std.compress.zlib.decompressor(res.transferReader()),
            },
            .gzip, .@"x-gzip" => res.request.compression = .{
                .gzip = std.compress.gzip.decompressor(res.transferReader()),
            },
            .zstd => {
                // https://github.com/ziglang/zig/issues/18937
                return error.CompressionUnsupported;
            },
        }
    }
}

pub const ReadError = TransferReadError || proto.HeadersParser.CheckCompleteHeadError || error{ DecompressionFailure, InvalidTrailers };

pub const Reader = std.io.Reader(*Server, ReadError, read);

pub fn reader(res: *Server) Reader {
    return .{ .context = res };
}

/// Reads data from the response body. Must be called after `wait`.
pub fn read(res: *Server, buffer: []u8) ReadError!usize {
    switch (res.state) {
        .waited, .responded, .finished => {},
        .first, .start => unreachable,
    }

    const out_index = switch (res.request.compression) {
        .deflate => |*deflate| deflate.read(buffer) catch return error.DecompressionFailure,
        .gzip => |*gzip| gzip.read(buffer) catch return error.DecompressionFailure,
        // https://github.com/ziglang/zig/issues/18937
        //.zstd => |*zstd| zstd.read(buffer) catch return error.DecompressionFailure,
        else => try res.transferRead(buffer),
    };

    if (out_index == 0) {
        const has_trail = !res.request.parser.state.isContent();

        while (!res.request.parser.state.isContent()) { // read trailing headers
            try res.connection.fill();

            const nchecked = try res.request.parser.checkCompleteHead(res.connection.peek());
            res.connection.drop(@intCast(nchecked));
        }

        if (has_trail) {
            // The response headers before the trailers are already
            // guaranteed to be valid, so they will always be parsed again
            // and cannot return an error.
            // This will *only* fail for a malformed trailer.
            res.request.parse(res.request.parser.get()) catch return error.InvalidTrailers;
        }
    }

    return out_index;
}

/// Reads data from the response body. Must be called after `wait`.
pub fn readAll(res: *Server, buffer: []u8) !usize {
    var index: usize = 0;
    while (index < buffer.len) {
        const amt = try read(res, buffer[index..]);
        if (amt == 0) break;
        index += amt;
    }
    return index;
}

pub const WriteError = Connection.WriteError || error{ NotWriteable, MessageTooLong };

pub const Writer = std.io.Writer(*Server, WriteError, write);

pub fn writer(res: *Server) Writer {
    return .{ .context = res };
}

/// Write `bytes` to the server. The `transfer_encoding` request header determines how data will be sent.
/// Must be called after `send` and before `finish`.
pub fn write(res: *Server, bytes: []const u8) WriteError!usize {
    switch (res.state) {
        .responded => {},
        .first, .waited, .start, .finished => unreachable,
    }

    switch (res.transfer_encoding) {
        .chunked => {
            if (bytes.len > 0) {
                try res.connection.writer().print("{x}\r\n", .{bytes.len});
                try res.connection.writeAll(bytes);
                try res.connection.writeAll("\r\n");
            }

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

/// Write `bytes` to the server. The `transfer_encoding` request header determines how data will be sent.
/// Must be called after `send` and before `finish`.
pub fn writeAll(req: *Server, bytes: []const u8) WriteError!void {
    var index: usize = 0;
    while (index < bytes.len) {
        index += try write(req, bytes[index..]);
    }
}

pub const FinishError = Connection.WriteError || error{MessageNotCompleted};

/// Finish the body of a request. This notifies the server that you have no more data to send.
/// Must be called after `send`.
pub fn finish(res: *Server) FinishError!void {
    switch (res.state) {
        .responded => res.state = .finished,
        .first, .waited, .start, .finished => unreachable,
    }

    switch (res.transfer_encoding) {
        .chunked => try res.connection.writeAll("0\r\n\r\n"),
        .content_length => |len| if (len != 0) return error.MessageNotCompleted,
        .none => {},
    }
}

const builtin = @import("builtin");
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
