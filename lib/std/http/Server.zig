//! Blocking HTTP server implementation.
//! Handles a single connection's lifecycle.

const std = @import("../std.zig");
const http = std.http;
const mem = std.mem;
const net = std.net;
const Uri = std.Uri;
const assert = std.debug.assert;
const testing = std.testing;

const Server = @This();

/// The reader's buffer must be large enough to store the client's entire HTTP
/// header, otherwise `receiveHead` returns `error.HttpHeadersOversize`.
in: *std.io.BufferedReader,
/// Data from the HTTP server to the HTTP client.
out: *std.io.BufferedWriter,
/// Keeps track of whether the Server is ready to accept a new request on the
/// same connection, and makes invalid API usage cause assertion failures
/// rather than HTTP protocol violations.
state: State,
/// Populated when `receiveHead` returns `ReceiveHeadError.HttpHeadersInvalid`.
head_parse_err: ?Request.Head.ParseError = null,

pub const State = enum {
    /// The connection is available to be used for the first time, or reused.
    ready,
    /// An error occurred in `receiveHead`.
    receiving_head,
    /// A Request object has been obtained and from there a Response can be
    /// opened.
    received_head,
    /// The client is uploading something to this Server.
    receiving_body,
    /// The connection is eligible for another HTTP request, however the client
    /// and server did not negotiate a persistent connection.
    closing,
};

/// Initialize an HTTP server that can respond to multiple requests on the same
/// connection.
///
/// The returned `Server` is ready for `receiveHead` to be called.
pub fn init(in: *std.io.BufferedReader, out: *std.io.BufferedWriter) Server {
    return .{
        .in = in,
        .out = out,
        .state = .ready,
    };
}

pub const ReceiveHeadError = error{
    /// Client sent too many bytes of HTTP headers.
    /// The HTTP specification suggests to respond with a 431 status code
    /// before closing the connection.
    HttpHeadersOversize,
    /// Client sent headers that did not conform to the HTTP protocol;
    /// `head_parse_err` is populated.
    HttpHeadersInvalid,
    /// Partial HTTP request was received but the connection was closed before
    /// fully receiving the headers.
    HttpRequestTruncated,
    /// The client sent 0 bytes of headers before closing the stream.
    /// In other words, a keep-alive connection was finally closed.
    HttpConnectionClosing,
    /// Transitive error occurred reading from `in`.
    ReadFailed,
};

/// The header bytes reference the internal storage of `in`, which are
/// invalidated with the next call to `receiveHead`.
pub fn receiveHead(s: *Server) ReceiveHeadError!Request {
    assert(s.state == .ready);
    s.state = .received_head;
    errdefer s.state = .receiving_head;

    const in = s.in;
    var hp: http.HeadParser = .{};
    var head_end: usize = 0;

    while (true) {
        if (head_end >= in.buffer.len) return error.HttpHeadersOversize;
        const buf = in.peekGreedy(head_end + 1) catch |err| switch (err) {
            error.EndOfStream => switch (head_end) {
                0 => return error.HttpConnectionClosing,
                else => return error.HttpRequestTruncated,
            },
            error.ReadFailed => return error.ReadFailed,
        };
        head_end += hp.feed(buf[head_end..]);
        if (hp.state == .finished) return .{
            .server = s,
            .head_end = head_end,
            .head = Request.Head.parse(buf[0..head_end]) catch |err| {
                s.head_parse_err = err;
                return error.HttpHeadersInvalid;
            },
            .reader_state = undefined,
        };
    }
}

pub const Request = struct {
    server: *Server,
    /// Index into `Server.in` internal buffer.
    head_end: usize,
    /// Number of bytes of HTTP trailers. These are at the end of a
    /// transfer-encoding: chunked message.
    trailers_len: usize = 0,
    head: Head,
    reader_state: union {
        remaining_content_length: u64,
        remaining_chunk_len: RemainingChunkLen,
    },
    read_err: ?ReadError = null,

    pub const ReadError = error{
        HttpChunkInvalid,
        HttpHeadersOversize,
    };

    pub const max_chunk_header_len = 22;

    pub const RemainingChunkLen = enum(u64) {
        head = 0,
        n = 1,
        rn = 2,
        done = std.math.maxInt(u64),
        _,

        pub fn init(integer: u64) RemainingChunkLen {
            return @enumFromInt(integer);
        }

        pub fn int(rcl: RemainingChunkLen) u64 {
            return @intFromEnum(rcl);
        }
    };

    pub const Compression = union(enum) {
        deflate: std.compress.zlib.Decompressor,
        gzip: std.compress.gzip.Decompressor,
        zstd: std.compress.zstd.Decompressor,
        none: void,
    };

    pub const Head = struct {
        method: http.Method,
        target: []const u8,
        version: http.Version,
        expect: ?[]const u8,
        content_type: ?[]const u8,
        content_length: ?u64,
        transfer_encoding: http.TransferEncoding,
        transfer_compression: http.ContentEncoding,
        keep_alive: bool,
        compression: Compression,

        pub const ParseError = error{
            UnknownHttpMethod,
            HttpHeadersInvalid,
            HttpHeaderContinuationsUnsupported,
            HttpTransferEncodingUnsupported,
            HttpConnectionHeaderUnsupported,
            InvalidContentLength,
            CompressionUnsupported,
            MissingFinalNewline,
        };

        pub fn parse(bytes: []const u8) ParseError!Head {
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

            var head: Head = .{
                .method = method,
                .target = target,
                .version = version,
                .expect = null,
                .content_type = null,
                .content_length = null,
                .transfer_encoding = .none,
                .transfer_compression = .identity,
                .keep_alive = switch (version) {
                    .@"HTTP/1.0" => false,
                    .@"HTTP/1.1" => true,
                },
                .compression = .none,
            };

            while (it.next()) |line| {
                if (line.len == 0) return head;
                switch (line[0]) {
                    ' ', '\t' => return error.HttpHeaderContinuationsUnsupported,
                    else => {},
                }

                var line_it = mem.splitScalar(u8, line, ':');
                const header_name = line_it.next().?;
                const header_value = mem.trim(u8, line_it.rest(), " \t");
                if (header_name.len == 0) return error.HttpHeadersInvalid;

                if (std.ascii.eqlIgnoreCase(header_name, "connection")) {
                    head.keep_alive = !std.ascii.eqlIgnoreCase(header_value, "close");
                } else if (std.ascii.eqlIgnoreCase(header_name, "expect")) {
                    head.expect = header_value;
                } else if (std.ascii.eqlIgnoreCase(header_name, "content-type")) {
                    head.content_type = header_value;
                } else if (std.ascii.eqlIgnoreCase(header_name, "content-length")) {
                    if (head.content_length != null) return error.HttpHeadersInvalid;
                    head.content_length = std.fmt.parseInt(u64, header_value, 10) catch
                        return error.InvalidContentLength;
                } else if (std.ascii.eqlIgnoreCase(header_name, "content-encoding")) {
                    if (head.transfer_compression != .identity) return error.HttpHeadersInvalid;

                    const trimmed = mem.trim(u8, header_value, " ");

                    if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                        head.transfer_compression = ce;
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
                        if (head.transfer_encoding != .none)
                            return error.HttpHeadersInvalid; // we already have a transfer encoding
                        head.transfer_encoding = transfer;

                        next = iter.next();
                    }

                    if (next) |second| {
                        const trimmed_second = mem.trim(u8, second, " ");

                        if (std.meta.stringToEnum(http.ContentEncoding, trimmed_second)) |transfer| {
                            if (head.transfer_compression != .identity)
                                return error.HttpHeadersInvalid; // double compression is not supported
                            head.transfer_compression = transfer;
                        } else {
                            return error.HttpTransferEncodingUnsupported;
                        }
                    }

                    if (iter.next()) |_| return error.HttpTransferEncodingUnsupported;
                }
            }
            return error.MissingFinalNewline;
        }

        test parse {
            const request_bytes = "GET /hi HTTP/1.0\r\n" ++
                "content-tYpe: text/plain\r\n" ++
                "content-Length:10\r\n" ++
                "expeCt:   100-continue \r\n" ++
                "TRansfer-encoding:\tdeflate, chunked \r\n" ++
                "connectioN:\t keep-alive \r\n\r\n";

            const req = try parse(request_bytes);

            try testing.expectEqual(.GET, req.method);
            try testing.expectEqual(.@"HTTP/1.0", req.version);
            try testing.expectEqualStrings("/hi", req.target);

            try testing.expectEqualStrings("text/plain", req.content_type.?);
            try testing.expectEqualStrings("100-continue", req.expect.?);

            try testing.expectEqual(true, req.keep_alive);
            try testing.expectEqual(10, req.content_length.?);
            try testing.expectEqual(.chunked, req.transfer_encoding);
            try testing.expectEqual(.deflate, req.transfer_compression);
        }

        inline fn int64(array: *const [8]u8) u64 {
            return @bitCast(array.*);
        }
    };

    pub fn iterateHeaders(r: *Request) http.HeaderIterator {
        return http.HeaderIterator.init(r.server.in.bufferContents()[0..r.head_end]);
    }

    test iterateHeaders {
        const request_bytes = "GET /hi HTTP/1.0\r\n" ++
            "content-tYpe: text/plain\r\n" ++
            "content-Length:10\r\n" ++
            "expeCt:   100-continue \r\n" ++
            "TRansfer-encoding:\tdeflate, chunked \r\n" ++
            "connectioN:\t keep-alive \r\n\r\n";

        var read_buffer: [500]u8 = undefined;
        @memcpy(read_buffer[0..request_bytes.len], request_bytes);
        var br: std.io.BufferedReader = undefined;
        br.initFixed(&read_buffer);

        var server: Server = .{
            .in = &br,
            .out = undefined,
            .state = .ready,
        };

        var request: Request = .{
            .server = &server,
            .head_end = request_bytes.len,
            .trailers_len = 0,
            .head = undefined,
            .reader_state = undefined,
        };

        var it = request.iterateHeaders();
        {
            const header = it.next().?;
            try testing.expectEqualStrings("content-tYpe", header.name);
            try testing.expectEqualStrings("text/plain", header.value);
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
            try testing.expectEqualStrings("expeCt", header.name);
            try testing.expectEqualStrings("100-continue", header.value);
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

    pub const RespondOptions = struct {
        version: http.Version = .@"HTTP/1.1",
        status: http.Status = .ok,
        reason: ?[]const u8 = null,
        keep_alive: bool = true,
        extra_headers: []const http.Header = &.{},
        transfer_encoding: ?http.TransferEncoding = null,
    };

    /// Send an entire HTTP response to the client, including headers and body.
    ///
    /// Automatically handles HEAD requests by omitting the body.
    ///
    /// Unless `transfer_encoding` is specified, uses the "content-length"
    /// header.
    ///
    /// If the request contains a body and the connection is to be reused,
    /// discards the request body, leaving the Server in the `ready` state. If
    /// this discarding fails, the connection is marked as not to be reused and
    /// no error is surfaced.
    ///
    /// Asserts status is not `continue`.
    /// Asserts there are at most 25 extra_headers.
    /// Asserts that "\r\n" does not occur in any header name or value.
    pub fn respond(
        request: *Request,
        content: []const u8,
        options: RespondOptions,
    ) std.io.Writer.Error!void {
        const max_extra_headers = 25;
        assert(options.status != .@"continue");
        assert(options.extra_headers.len <= max_extra_headers);
        if (std.debug.runtime_safety) {
            for (options.extra_headers) |header| {
                assert(header.name.len != 0);
                assert(std.mem.indexOfScalar(u8, header.name, ':') == null);
                assert(std.mem.indexOfPosLinear(u8, header.name, 0, "\r\n") == null);
                assert(std.mem.indexOfPosLinear(u8, header.value, 0, "\r\n") == null);
            }
        }

        const transfer_encoding_none = (options.transfer_encoding orelse .chunked) == .none;
        const server_keep_alive = !transfer_encoding_none and options.keep_alive;
        const keep_alive = request.discardBody(server_keep_alive);

        const phrase = options.reason orelse options.status.phrase() orelse "";

        var first_buffer: [500]u8 = undefined;
        var h = std.ArrayListUnmanaged(u8).initBuffer(&first_buffer);
        if (request.head.expect != null) {
            // reader() and hence discardBody() above sets expect to null if it
            // is handled. So the fact that it is not null here means unhandled.
            h.appendSliceAssumeCapacity("HTTP/1.1 417 Expectation Failed\r\n");
            if (!keep_alive) h.appendSliceAssumeCapacity("connection: close\r\n");
            h.appendSliceAssumeCapacity("content-length: 0\r\n\r\n");
            try request.server.out.writeAll(h.items);
            return;
        }
        h.printAssumeCapacity("{s} {d} {s}\r\n", .{
            @tagName(options.version), @intFromEnum(options.status), phrase,
        });

        switch (options.version) {
            .@"HTTP/1.0" => if (keep_alive) h.appendSliceAssumeCapacity("connection: keep-alive\r\n"),
            .@"HTTP/1.1" => if (!keep_alive) h.appendSliceAssumeCapacity("connection: close\r\n"),
        }

        if (options.transfer_encoding) |transfer_encoding| switch (transfer_encoding) {
            .none => {},
            .chunked => h.appendSliceAssumeCapacity("transfer-encoding: chunked\r\n"),
        } else {
            h.printAssumeCapacity("content-length: {d}\r\n", .{content.len});
        }

        var chunk_header_buffer: [18]u8 = undefined;
        var iovecs: [max_extra_headers * 4 + 3][]const u8 = undefined;
        var iovecs_len: usize = 0;

        iovecs[iovecs_len] = h.items;
        iovecs_len += 1;

        for (options.extra_headers) |header| {
            iovecs[iovecs_len] = header.name;
            iovecs_len += 1;

            iovecs[iovecs_len] = ": ";
            iovecs_len += 1;

            if (header.value.len != 0) {
                iovecs[iovecs_len] = header.value;
                iovecs_len += 1;
            }

            iovecs[iovecs_len] = "\r\n";
            iovecs_len += 1;
        }

        iovecs[iovecs_len] = "\r\n";
        iovecs_len += 1;

        if (request.head.method != .HEAD) {
            const is_chunked = (options.transfer_encoding orelse .none) == .chunked;
            if (is_chunked) {
                if (content.len > 0) {
                    const chunk_header = std.fmt.bufPrint(
                        &chunk_header_buffer,
                        "{x}\r\n",
                        .{content.len},
                    ) catch unreachable;

                    iovecs[iovecs_len] = chunk_header;
                    iovecs_len += 1;

                    iovecs[iovecs_len] = content;
                    iovecs_len += 1;

                    iovecs[iovecs_len] = "\r\n";
                    iovecs_len += 1;
                }

                iovecs[iovecs_len] = "0\r\n\r\n";
                iovecs_len += 1;
            } else if (content.len > 0) {
                iovecs[iovecs_len] = content;
                iovecs_len += 1;
            }
        }

        try request.server.out.writeVecAll(iovecs[0..iovecs_len]);
    }

    pub const RespondStreamingOptions = struct {
        /// If provided, the response will use the content-length header;
        /// otherwise it will use transfer-encoding: chunked.
        content_length: ?u64 = null,
        /// Options that are shared with the `respond` method.
        respond_options: RespondOptions = .{},
    };

    /// The header is not guaranteed to be sent until `Response.flush` is called.
    ///
    /// If the request contains a body and the connection is to be reused,
    /// discards the request body, leaving the Server in the `ready` state. If
    /// this discarding fails, the connection is marked as not to be reused and
    /// no error is surfaced.
    ///
    /// HEAD requests are handled transparently by setting the
    /// `Response.elide_body` flag on the returned `Response`, causing
    /// the response stream to omit the body. However, it may be worth noticing
    /// that flag and skipping any expensive work that would otherwise need to
    /// be done to satisfy the request.
    ///
    /// Asserts status is not `continue`.
    pub fn respondStreaming(request: *Request, options: RespondStreamingOptions) std.io.Writer.Error!Response {
        const o = options.respond_options;
        assert(o.status != .@"continue");
        const transfer_encoding_none = (o.transfer_encoding orelse .chunked) == .none;
        const server_keep_alive = !transfer_encoding_none and o.keep_alive;
        const keep_alive = request.discardBody(server_keep_alive);
        const phrase = o.reason orelse o.status.phrase() orelse "";
        const out = request.server.out;

        const elide_body = if (request.head.expect != null) eb: {
            // reader() and hence discardBody() above sets expect to null if it
            // is handled. So the fact that it is not null here means unhandled.
            try out.writeAll("HTTP/1.1 417 Expectation Failed\r\n");
            if (!keep_alive) try out.writeAll("connection: close\r\n");
            try out.writeAll("content-length: 0\r\n\r\n");
            break :eb true;
        } else eb: {
            try out.print("{s} {d} {s}\r\n", .{
                @tagName(o.version), @intFromEnum(o.status), phrase,
            });

            switch (o.version) {
                .@"HTTP/1.0" => if (keep_alive) try out.writeAll("connection: keep-alive\r\n"),
                .@"HTTP/1.1" => if (!keep_alive) try out.writeAll("connection: close\r\n"),
            }

            if (o.transfer_encoding) |transfer_encoding| switch (transfer_encoding) {
                .chunked => try out.writeAll("transfer-encoding: chunked\r\n"),
                .none => {},
            } else if (options.content_length) |len| {
                try out.print("content-length: {d}\r\n", .{len});
            } else {
                try out.writeAll("transfer-encoding: chunked\r\n");
            }

            for (o.extra_headers) |header| {
                assert(header.name.len != 0);
                try out.writeAll(header.name);
                try out.writeAll(": ");
                try out.writeAll(header.value);
                try out.writeAll("\r\n");
            }

            try out.writeAll("\r\n");
            break :eb request.head.method == .HEAD;
        };

        return .{
            .server_output = request.server.out,
            .transfer_encoding = if (o.transfer_encoding) |te| switch (te) {
                .chunked => .{ .chunked = .init },
                .none => .none,
            } else if (options.content_length) |len| .{
                .content_length = len,
            } else .{ .chunked = .init },
            .elide_body = elide_body,
        };
    }

    fn contentLengthRead(
        ctx: ?*anyopaque,
        bw: *std.io.BufferedWriter,
        limit: std.io.Reader.Limit,
    ) std.io.Reader.RwError!usize {
        const request: *Request = @alignCast(@ptrCast(ctx));
        const remaining_content_length = &request.reader_state.remaining_content_length;
        const remaining = remaining_content_length.*;
        const server = request.server;
        if (remaining == 0) {
            server.state = .ready;
            return error.EndOfStream;
        }
        const n = try server.in.read(bw, limit.min(.limited(remaining)));
        const new_remaining = remaining - n;
        remaining_content_length.* = new_remaining;
        return n;
    }

    fn contentLengthReadVec(context: ?*anyopaque, data: []const []u8) std.io.Reader.Error!usize {
        const request: *Request = @alignCast(@ptrCast(context));
        const remaining_content_length = &request.reader_state.remaining_content_length;
        const server = request.server;
        const remaining = remaining_content_length.*;
        if (remaining == 0) {
            server.state = .ready;
            return error.EndOfStream;
        }
        const n = try server.in.readVecLimit(data, .limited(remaining));
        const new_remaining = remaining - n;
        remaining_content_length.* = new_remaining;
        return n;
    }

    fn contentLengthDiscard(ctx: ?*anyopaque, limit: std.io.Reader.Limit) std.io.Reader.Error!usize {
        const request: *Request = @alignCast(@ptrCast(ctx));
        const remaining_content_length = &request.reader_state.remaining_content_length;
        const server = request.server;
        const remaining = remaining_content_length.*;
        if (remaining == 0) {
            server.state = .ready;
            return error.EndOfStream;
        }
        const n = try server.in.discard(limit.min(.limited(remaining)));
        const new_remaining = remaining - n;
        remaining_content_length.* = new_remaining;
        return n;
    }

    fn chunkedRead(
        ctx: ?*anyopaque,
        bw: *std.io.BufferedWriter,
        limit: std.io.Reader.Limit,
    ) std.io.Reader.RwError!usize {
        const request: *Request = @alignCast(@ptrCast(ctx));
        const chunk_len_ptr = &request.reader_state.remaining_chunk_len;
        const in = request.server.in;
        len: switch (chunk_len_ptr.*) {
            .head => {
                var cp: http.ChunkParser = .init;
                const i = cp.feed(in.bufferContents());
                switch (cp.state) {
                    .invalid => return request.failRead(error.HttpChunkInvalid),
                    .data => {
                        if (i > max_chunk_header_len) return request.failRead(error.HttpChunkInvalid);
                        in.toss(i);
                    },
                    else => {
                        try in.fill(max_chunk_header_len);
                        const next_i = cp.feed(in.bufferContents()[i..]);
                        if (cp.state != .data) return request.failRead(error.HttpChunkInvalid);
                        const header_len = i + next_i;
                        if (header_len > max_chunk_header_len) return request.failRead(error.HttpChunkInvalid);
                        in.toss(header_len);
                    },
                }
                if (cp.chunk_len == 0) return parseTrailers(request, 0);
                const n = try in.read(bw, limit.min(.limited(cp.chunk_len)));
                chunk_len_ptr.* = .init(cp.chunk_len + 2 - n);
                return n;
            },
            .n => {
                if ((try in.peekByte()) != '\n') return request.failRead(error.HttpChunkInvalid);
                in.toss(1);
                continue :len .head;
            },
            .rn => {
                const rn = try in.peekArray(2);
                if (rn[0] != '\r' or rn[1] != '\n') return request.failRead(error.HttpChunkInvalid);
                in.toss(2);
                continue :len .head;
            },
            else => |remaining_chunk_len| {
                const n = try in.read(bw, limit.min(.limited(@intFromEnum(remaining_chunk_len) - 2)));
                chunk_len_ptr.* = .init(@intFromEnum(remaining_chunk_len) - n);
                return n;
            },
            .done => return error.EndOfStream,
        }
    }

    fn chunkedReadVec(ctx: ?*anyopaque, data: []const []u8) std.io.Reader.Error!usize {
        const request: *Request = @alignCast(@ptrCast(ctx));
        const chunk_len_ptr = &request.reader_state.remaining_chunk_len;
        const in = request.server.in;
        var already_requested_more = false;
        var amt_read: usize = 0;
        data: for (data) |d| {
            len: switch (chunk_len_ptr.*) {
                .head => {
                    var cp: http.ChunkParser = .init;
                    const available_buffer = in.bufferContents();
                    const i = cp.feed(available_buffer);
                    if (cp.state == .invalid) return request.failRead(error.HttpChunkInvalid);
                    if (i == available_buffer.len) {
                        if (already_requested_more) {
                            chunk_len_ptr.* = .head;
                            return amt_read;
                        }
                        already_requested_more = true;
                        try in.fill(max_chunk_header_len);
                        const next_i = cp.feed(in.bufferContents()[i..]);
                        if (cp.state != .data) return request.failRead(error.HttpChunkInvalid);
                        const header_len = i + next_i;
                        if (header_len > max_chunk_header_len) return request.failRead(error.HttpChunkInvalid);
                        in.toss(header_len);
                    } else {
                        if (i > max_chunk_header_len) return request.failRead(error.HttpChunkInvalid);
                        in.toss(i);
                    }
                    if (cp.chunk_len == 0) return parseTrailers(request, amt_read);
                    continue :len .init(cp.chunk_len + 2);
                },
                .n => {
                    if (in.bufferContents().len < 1) already_requested_more = true;
                    if ((try in.takeByte()) != '\n') return request.failRead(error.HttpChunkInvalid);
                    continue :len .head;
                },
                .rn => {
                    if (in.bufferContents().len < 2) already_requested_more = true;
                    const rn = try in.takeArray(2);
                    if (rn[0] != '\r' or rn[1] != '\n') return request.failRead(error.HttpChunkInvalid);
                    continue :len .head;
                },
                else => |remaining_chunk_len| {
                    const available_buffer = in.bufferContents();
                    const copy_len = @min(available_buffer.len, d.len, remaining_chunk_len.int() - 2);
                    @memcpy(d[0..copy_len], available_buffer[0..copy_len]);
                    amt_read += copy_len;
                    in.toss(copy_len);
                    const next_chunk_len: RemainingChunkLen = .init(remaining_chunk_len.int() - copy_len);
                    if (copy_len == d.len) {
                        chunk_len_ptr.* = next_chunk_len;
                        continue :data;
                    }
                    if (already_requested_more) {
                        chunk_len_ptr.* = next_chunk_len;
                        return amt_read;
                    }
                    already_requested_more = true;
                    try in.fill(3);
                    continue :len next_chunk_len;
                },
                .done => return error.EndOfStream,
            }
        }
        return amt_read;
    }

    fn chunkedDiscard(ctx: ?*anyopaque, limit: std.io.Reader.Limit) std.io.Reader.Error!usize {
        const request: *Request = @alignCast(@ptrCast(ctx));
        const chunk_len_ptr = &request.reader_state.remaining_chunk_len;
        const in = request.server.in;
        len: switch (chunk_len_ptr.*) {
            .head => {
                var cp: http.ChunkParser = .init;
                const i = cp.feed(in.bufferContents());
                switch (cp.state) {
                    .invalid => return request.failRead(error.HttpChunkInvalid),
                    .data => {
                        if (i > max_chunk_header_len) return request.failRead(error.HttpChunkInvalid);
                        in.toss(i);
                    },
                    else => {
                        try in.fill(max_chunk_header_len);
                        const next_i = cp.feed(in.bufferContents()[i..]);
                        if (cp.state != .data) return request.failRead(error.HttpChunkInvalid);
                        const header_len = i + next_i;
                        if (header_len > max_chunk_header_len) return request.failRead(error.HttpChunkInvalid);
                        in.toss(header_len);
                    },
                }
                if (cp.chunk_len == 0) return parseTrailers(request, 0);
                const n = try in.discard(limit.min(.limited(cp.chunk_len)));
                chunk_len_ptr.* = .init(cp.chunk_len + 2 - n);
                return n;
            },
            .n => {
                if ((try in.peekByte()) != '\n') return request.failRead(error.HttpChunkInvalid);
                in.toss(1);
                continue :len .head;
            },
            .rn => {
                const rn = try in.peekArray(2);
                if (rn[0] != '\r' or rn[1] != '\n') return request.failRead(error.HttpChunkInvalid);
                in.toss(2);
                continue :len .head;
            },
            else => |remaining_chunk_len| {
                const n = try in.discard(limit.min(.limited(remaining_chunk_len.int() - 2)));
                chunk_len_ptr.* = .init(remaining_chunk_len.int() - n);
                return n;
            },
            .done => return error.EndOfStream,
        }
    }

    /// Called when next bytes in the stream are trailers, or "\r\n" to indicate
    /// end of chunked body.
    fn parseTrailers(request: *Request, amt_read: usize) std.io.Reader.Error!usize {
        const in = request.server.in;
        var hp: http.HeadParser = .{};
        var trailers_len: usize = 0;
        while (true) {
            if (trailers_len >= in.buffer.len) return request.failRead(error.HttpHeadersOversize);
            try in.fill(trailers_len + 1);
            trailers_len += hp.feed(in.bufferContents()[trailers_len..]);
            if (hp.state == .finished) {
                request.reader_state.remaining_chunk_len = .done;
                request.server.state = .ready;
                request.trailers_len = trailers_len;
                return amt_read;
            }
        }
    }

    pub const ReaderError = error{
        /// Failed to write "100-continue" to the stream.
        WriteFailed,
        /// Failed to write "100-continue" to the stream because it ended.
        EndOfStream,
        /// The client sent an expect HTTP header value other than
        /// "100-continue".
        HttpExpectationFailed,
    };

    /// In the case that the request contains "expect: 100-continue", this
    /// function writes the continuation header, which means it can fail with a
    /// write error. After sending the continuation header, it sets the
    /// request's expect field to `null`.
    ///
    /// Asserts that this function is only called once.
    pub fn reader(request: *Request) ReaderError!std.io.Reader {
        const s = request.server;
        assert(s.state == .received_head);
        s.state = .receiving_body;

        if (request.head.expect) |expect| {
            if (mem.eql(u8, expect, "100-continue")) {
                try request.server.out.writeAll("HTTP/1.1 100 Continue\r\n\r\n");
                request.head.expect = null;
            } else {
                return error.HttpExpectationFailed;
            }
        }

        switch (request.head.transfer_encoding) {
            .chunked => {
                request.reader_state = .{ .remaining_chunk_len = .head };
                return .{
                    .context = request,
                    .vtable = &.{
                        .read = &chunkedRead,
                        .readVec = &chunkedReadVec,
                        .discard = &chunkedDiscard,
                    },
                };
            },
            .none => {
                request.reader_state = .{
                    .remaining_content_length = request.head.content_length orelse 0,
                };
                return .{
                    .context = request,
                    .vtable = &.{
                        .read = &contentLengthRead,
                        .readVec = &contentLengthReadVec,
                        .discard = &contentLengthDiscard,
                    },
                };
            },
        }
    }

    /// Returns whether the connection should remain persistent.
    /// If it would fail, it instead sets the Server state to `receiving_body`
    /// and returns false.
    fn discardBody(request: *Request, keep_alive: bool) bool {
        // Prepare to receive another request on the same connection.
        // There are two factors to consider:
        // * Any body the client sent must be discarded.
        // * The Server's read_buffer may already have some bytes in it from
        //   whatever came after the head, which may be the next HTTP request
        //   or the request body.
        // If the connection won't be kept alive, then none of this matters
        // because the connection will be severed after the response is sent.
        const s = request.server;
        if (keep_alive and request.head.keep_alive) switch (s.state) {
            .received_head => {
                const r = request.reader() catch return false;
                _ = r.discardRemaining() catch return false;
                assert(s.state == .ready);
                return true;
            },
            .receiving_body, .ready => return true,
            else => unreachable,
        };

        // Avoid clobbering the state in case a reading stream already exists.
        switch (s.state) {
            .received_head => s.state = .closing,
            else => {},
        }
        return false;
    }

    fn failRead(r: *Request, err: ReadError) error{ReadFailed} {
        r.read_err = err;
        return error.ReadFailed;
    }
};

pub const Response = struct {
    /// HTTP protocol to the client.
    ///
    /// This is the underlying stream; use `buffered` to create a
    /// `BufferedWriter` for this `Response`.
    ///
    /// Until the lifetime of `Response` ends, it is illegal to modify the
    /// state of this other than via methods of `Response`.
    server_output: *std.io.BufferedWriter,
    /// `null` means transfer-encoding: chunked.
    /// As a debugging utility, counts down to zero as bytes are written.
    transfer_encoding: TransferEncoding,
    elide_body: bool,
    err: Error!void = {},

    pub const Error = error{
        /// Attempted to write a file to the stream, an expensive operation
        /// that should be avoided when `elide_body` is true.
        UnableToElideBody,
    };
    pub const WriteError = std.io.Writer.Error;

    /// How many zeroes to reserve for hex-encoded chunk length.
    const chunk_len_digits = 8;
    const max_chunk_len: usize = std.math.pow(usize, 16, chunk_len_digits) - 1;
    const chunk_header_template = ("0" ** chunk_len_digits) ++ "\r\n";

    comptime {
        assert(max_chunk_len == std.math.maxInt(u32));
    }

    pub const TransferEncoding = union(enum) {
        /// End of connection signals the end of the stream.
        none,
        /// As a debugging utility, counts down to zero as bytes are written.
        content_length: u64,
        /// Each chunk is wrapped in a header and trailer.
        chunked: Chunked,

        pub const Chunked = union(enum) {
            /// Index of the hex-encoded chunk length in the chunk header
            /// within the buffer of `Response.server_output`.
            offset: usize,
            /// We are in the middle of a chunk and this is how many bytes are
            /// left until the next header. This includes +2 for "\r"\n", and
            /// is zero for the beginning of the stream.
            chunk_len: usize,

            pub const init: Chunked = .{ .chunk_len = 0 };
        };
    };

    /// Sends all buffered data across `Response.server_output`.
    ///
    /// Some buffered data will remain if transfer-encoding is chunked and the
    /// response is mid-chunk.
    pub fn flush(r: *Response) WriteError!void {
        switch (r.transfer_encoding) {
            .none, .content_length => return r.server_output.flush(),
            .chunked => |*chunked| switch (chunked.*) {
                .offset => |*offset| {
                    try r.server_output.flushLimit(.limited(r.server_output.end - offset.*));
                    offset.* = 0;
                },
                .chunk_len => return r.server_output.flush(),
            },
        }
    }

    /// When using content-length, asserts that the amount of data sent matches
    /// the value sent in the header, then flushes. Asserts the amount of bytes
    /// sent matches the content-length value provided in the HTTP header.
    ///
    /// When using transfer-encoding: chunked, writes the end-of-stream message
    /// with empty trailers, then flushes the stream to the system. Asserts any
    /// started chunk has been completely finished.
    ///
    /// Respects the value of `elide_body` to omit all data after the headers.
    ///
    /// Sets `r` to undefined.
    ///
    /// See also:
    /// * `endUnflushed`
    /// * `endChunked`
    pub fn end(r: *Response) WriteError!void {
        try endUnflushed(r);
        try r.server_output.flush();
        r.* = undefined;
    }

    /// When using content-length, asserts that the amount of data sent matches
    /// the value sent in the header.
    ///
    /// Otherwise, transfer-encoding: chunked is being used, and it writes the
    /// end-of-stream message with empty trailers.
    ///
    /// Respects the value of `elide_body` to omit all data after the headers.
    ///
    /// See also:
    /// * `end`
    /// * `endChunked`
    pub fn endUnflushed(r: *Response) WriteError!void {
        switch (r.transfer_encoding) {
            .content_length => |len| assert(len == 0), // Trips when end() called before all bytes written.
            .none => {},
            .chunked => try endChunked(r, .{}),
        }
    }

    pub const EndChunkedOptions = struct {
        trailers: []const http.Header = &.{},
    };

    /// Writes the end-of-stream message and any optional trailers.
    ///
    /// Does not flush.
    ///
    /// Asserts that the Response is using transfer-encoding: chunked.
    ///
    /// Respects the value of `elide_body` to omit all data after the headers.
    ///
    /// See also:
    /// * `end`
    /// * `endUnflushed`
    pub fn endChunked(r: *Response, options: EndChunkedOptions) WriteError!void {
        const chunked = &r.transfer_encoding.chunked;
        if (r.elide_body) return;
        const bw = r.server_output;
        switch (chunked.*) {
            .offset => |offset| {
                const chunk_len = bw.end - offset - chunk_header_template.len;
                writeHex(bw.buffer[offset..][0..chunk_len_digits], chunk_len);
                try bw.writeAll("\r\n");
            },
            .chunk_len => |chunk_len| switch (chunk_len) {
                0 => {},
                1 => try bw.writeByte('\n'),
                2 => try bw.writeAll("\r\n"),
                else => unreachable, // An earlier write call indicated more data would follow.
            },
        }
        if (options.trailers.len > 0) {
            try bw.writeAll("0\r\n");
            for (options.trailers) |trailer| {
                try bw.writeAll(trailer.name);
                try bw.writeAll(": ");
                try bw.writeAll(trailer.value);
                try bw.writeAll("\r\n");
            }
            try bw.writeAll("\r\n");
        }
        r.* = undefined;
    }

    fn contentLengthWriteSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) WriteError!usize {
        const r: *Response = @alignCast(@ptrCast(context));
        const n = if (r.elide_body) countSplat(data, splat) else try r.server_output.writeSplat(data, splat);
        r.transfer_encoding.content_length -= n;
        return n;
    }

    fn noneWriteSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) WriteError!usize {
        const r: *Response = @alignCast(@ptrCast(context));
        if (r.elide_body) return countSplat(data, splat);
        return r.server_output.writeSplat(data, splat);
    }

    fn countSplat(data: []const []const u8, splat: usize) usize {
        if (data.len == 0) return 0;
        var total: usize = 0;
        for (data[0 .. data.len - 1]) |buf| total += buf.len;
        total += data[data.len - 1].len * splat;
        return total;
    }

    fn elideWriteFile(
        r: *Response,
        offset: std.io.Writer.Offset,
        limit: std.io.Writer.Limit,
        headers_and_trailers: []const []const u8,
    ) WriteError!usize {
        if (offset != .none) {
            if (countWriteFile(limit, headers_and_trailers)) |n| {
                return n;
            }
        }
        r.err = error.UnableToElideBody;
        return error.WriteFailed;
    }

    /// Returns `null` if size cannot be computed without making any syscalls.
    fn countWriteFile(limit: std.io.Writer.Limit, headers_and_trailers: []const []const u8) ?usize {
        var total: usize = limit.toInt() orelse return null;
        for (headers_and_trailers) |buf| total += buf.len;
        return total;
    }

    fn noneWriteFile(
        context: ?*anyopaque,
        file: std.fs.File,
        offset: std.io.Writer.Offset,
        limit: std.io.Writer.Limit,
        headers_and_trailers: []const []const u8,
        headers_len: usize,
    ) std.io.Writer.FileError!usize {
        if (limit == .nothing) return noneWriteSplat(context, headers_and_trailers, 1);
        const r: *Response = @alignCast(@ptrCast(context));
        if (r.elide_body) return elideWriteFile(r, offset, limit, headers_and_trailers);
        return r.server_output.writeFile(file, offset, limit, headers_and_trailers, headers_len);
    }

    fn contentLengthWriteFile(
        context: ?*anyopaque,
        file: std.fs.File,
        offset: std.io.Writer.Offset,
        limit: std.io.Writer.Limit,
        headers_and_trailers: []const []const u8,
        headers_len: usize,
    ) std.io.Writer.FileError!usize {
        if (limit == .nothing) return contentLengthWriteSplat(context, headers_and_trailers, 1);
        const r: *Response = @alignCast(@ptrCast(context));
        if (r.elide_body) return elideWriteFile(r, offset, limit, headers_and_trailers);
        const n = try r.server_output.writeFile(file, offset, limit, headers_and_trailers, headers_len);
        r.transfer_encoding.content_length -= n;
        return n;
    }

    fn chunkedWriteFile(
        context: ?*anyopaque,
        file: std.fs.File,
        offset: std.io.Writer.Offset,
        limit: std.io.Writer.Limit,
        headers_and_trailers: []const []const u8,
        headers_len: usize,
    ) std.io.Writer.FileError!usize {
        if (limit == .nothing) return chunkedWriteSplat(context, headers_and_trailers, 1);
        const r: *Response = @alignCast(@ptrCast(context));
        if (r.elide_body) return elideWriteFile(r, offset, limit, headers_and_trailers);
        const data_len = countWriteFile(limit, headers_and_trailers) orelse @panic("TODO");
        const bw = r.server_output;
        const chunked = &r.transfer_encoding.chunked;
        state: switch (chunked.*) {
            .offset => |off| {
                // TODO: is it better perf to read small files into the buffer?
                const buffered_len = bw.end - off - chunk_header_template.len;
                const chunk_len = data_len + buffered_len;
                writeHex(bw.buffer[off..][0..chunk_len_digits], chunk_len);
                const n = try bw.writeFile(file, offset, limit, headers_and_trailers, headers_len);
                chunked.* = .{ .chunk_len = data_len + 2 - n };
                return n;
            },
            .chunk_len => |chunk_len| l: switch (chunk_len) {
                0 => {
                    const header_buf = try bw.writableArray(chunk_header_template.len);
                    const off = bw.end;
                    @memcpy(header_buf, chunk_header_template);
                    chunked.* = .{ .offset = off };
                    continue :state .{ .offset = off };
                },
                1 => {
                    try bw.writeByte('\n');
                    chunked.chunk_len = 0;
                    continue :l 0;
                },
                2 => {
                    try bw.writeByte('\r');
                    chunked.chunk_len = 1;
                    continue :l 1;
                },
                else => {
                    const new_limit = limit.min(.limited(chunk_len - 2));
                    const n = try bw.writeFile(file, offset, new_limit, headers_and_trailers, headers_len);
                    chunked.chunk_len = chunk_len - n;
                    return n;
                },
            },
        }
    }

    fn chunkedWriteSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) WriteError!usize {
        const r: *Response = @alignCast(@ptrCast(context));
        const data_len = countSplat(data, splat);
        if (r.elide_body) return data_len;

        const bw = r.server_output;
        const chunked = &r.transfer_encoding.chunked;

        state: switch (chunked.*) {
            .offset => |offset| {
                if (bw.unusedCapacitySlice().len >= data_len) {
                    assert(data_len == (bw.writeSplat(data, splat) catch unreachable));
                    return data_len;
                }
                const buffered_len = bw.end - offset - chunk_header_template.len;
                const chunk_len = data_len + buffered_len;
                writeHex(bw.buffer[offset..][0..chunk_len_digits], chunk_len);
                const n = try bw.writeSplat(data, splat);
                chunked.* = .{ .chunk_len = data_len + 2 - n };
                return n;
            },
            .chunk_len => |chunk_len| l: switch (chunk_len) {
                0 => {
                    const header_buf = try bw.writableArray(chunk_header_template.len);
                    const offset = bw.end;
                    @memcpy(header_buf, chunk_header_template);
                    chunked.* = .{ .offset = offset };
                    continue :state .{ .offset = offset };
                },
                1 => {
                    try bw.writeByte('\n');
                    chunked.chunk_len = 0;
                    continue :l 0;
                },
                2 => {
                    try bw.writeByte('\r');
                    chunked.chunk_len = 1;
                    continue :l 1;
                },
                else => {
                    const n = try bw.writeSplatLimit(data, splat, .limited(chunk_len - 2));
                    chunked.chunk_len = chunk_len - n;
                    return n;
                },
            },
        }
    }

    /// Writes an integer as base 16 to `buf`, right-aligned, assuming the
    /// buffer has already been filled with zeroes.
    fn writeHex(buf: []u8, x: usize) void {
        assert(std.mem.allEqual(u8, buf, '0'));
        const base = 16;
        var index: usize = buf.len;
        var a = x;
        while (a > 0) {
            const digit = a % base;
            index -= 1;
            buf[index] = std.fmt.digitToChar(@intCast(digit), .lower);
            a /= base;
        }
    }

    pub fn writer(r: *Response) std.io.Writer {
        return .{
            .context = r,
            .vtable = switch (r.transfer_encoding) {
                .none => &.{
                    .writeSplat = noneWriteSplat,
                    .writeFile = noneWriteFile,
                },
                .content_length => &.{
                    .writeSplat = contentLengthWriteSplat,
                    .writeFile = contentLengthWriteFile,
                },
                .chunked => &.{
                    .writeSplat = chunkedWriteSplat,
                    .writeFile = chunkedWriteFile,
                },
            },
        };
    }
};
