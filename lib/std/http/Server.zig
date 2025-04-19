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
head_parse_err: Request.Head.ParseError,

/// being deleted...
next_request_start: usize = 0,

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
        .head_parse_err = undefined,
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
        if (head_end >= in.bufferContents().len) return error.HttpHeadersOversize;
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
    head: Head,
    reader_state: union {
        remaining_content_length: u64,
        chunk_parser: http.ChunkParser,
    },

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
            .in_err = undefined,
        };

        var request: Request = .{
            .server = &server,
            .head_end = request_bytes.len,
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

    /// The header is buffered but not sent until `Response.flush` is called.
    ///
    /// If the request contains a body and the connection is to be reused,
    /// discards the request body, leaving the Server in the `ready` state. If
    /// this discarding fails, the connection is marked as not to be reused and
    /// no error is surfaced.
    ///
    /// HEAD requests are handled transparently by setting a flag on the
    /// returned Response to omit the body. However it may be worth noticing
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

    pub const ReadError = net.Stream.ReadError || error{
        HttpChunkInvalid,
        HttpHeadersOversize,
    };

    fn contentLengthReader_read(
        ctx: ?*anyopaque,
        bw: *std.io.BufferedWriter,
        limit: std.io.Reader.Limit,
    ) std.io.Reader.Error!usize {
        const request: *Request = @alignCast(@ptrCast(ctx));
        _ = request;
        _ = bw;
        _ = limit;
        @panic("TODO");
    }

    fn contentLengthReader_readVec(ctx: ?*anyopaque, data: []const []u8) std.io.Reader.Error!usize {
        const request: *Request = @alignCast(@ptrCast(ctx));
        _ = request;
        _ = data;
        @panic("TODO");
    }

    fn contentLengthReader_discard(ctx: ?*anyopaque, limit: std.io.Reader.Limit) std.io.Reader.Error!usize {
        const request: *Request = @alignCast(@ptrCast(ctx));
        _ = request;
        _ = limit;
        @panic("TODO");
    }

    fn chunkedReader_read(
        ctx: ?*anyopaque,
        bw: *std.io.BufferedWriter,
        limit: std.io.Reader.Limit,
    ) std.io.Reader.Error!usize {
        const request: *Request = @alignCast(@ptrCast(ctx));
        _ = request;
        _ = bw;
        _ = limit;
        @panic("TODO");
    }

    fn chunkedReader_readVec(ctx: ?*anyopaque, data: []const []u8) std.io.Reader.Error!usize {
        const request: *Request = @alignCast(@ptrCast(ctx));
        _ = request;
        _ = data;
        @panic("TODO");
    }

    fn chunkedReader_discard(ctx: ?*anyopaque, limit: std.io.Reader.Limit) std.io.Reader.Error!usize {
        const request: *Request = @alignCast(@ptrCast(ctx));
        _ = request;
        _ = limit;
        @panic("TODO");
    }

    fn read_cl(context: *const anyopaque, buffer: []u8) ReadError!usize {
        const request: *Request = @alignCast(@ptrCast(context));
        const s = request.server;

        const remaining_content_length = &request.reader_state.remaining_content_length;
        if (remaining_content_length.* == 0) {
            s.state = .ready;
            return 0;
        }
        assert(s.state == .receiving_body);
        const available = try fill(s, request.head_end);
        const len = @min(remaining_content_length.*, available.len, buffer.len);
        @memcpy(buffer[0..len], available[0..len]);
        remaining_content_length.* -= len;
        s.next_request_start += len;
        if (remaining_content_length.* == 0)
            s.state = .ready;
        return len;
    }

    fn fill(s: *Server, head_end: usize) ReadError![]u8 {
        const available = s.read_buffer[s.next_request_start..s.read_buffer_len];
        if (available.len > 0) return available;
        s.next_request_start = head_end;
        s.read_buffer_len = head_end + try s.connection.stream.read(s.read_buffer[head_end..]);
        return s.read_buffer[head_end..s.read_buffer_len];
    }

    fn read_chunked(context: *const anyopaque, buffer: []u8) ReadError!usize {
        const request: *Request = @alignCast(@ptrCast(context));
        const s = request.server;

        const cp = &request.reader_state.chunk_parser;
        const head_end = request.head_end;

        // Protect against returning 0 before the end of stream.
        var out_end: usize = 0;
        while (out_end == 0) {
            switch (cp.state) {
                .invalid => return 0,
                .data => {
                    assert(s.state == .receiving_body);
                    const available = try fill(s, head_end);
                    const len = @min(cp.chunk_len, available.len, buffer.len);
                    @memcpy(buffer[0..len], available[0..len]);
                    cp.chunk_len -= len;
                    if (cp.chunk_len == 0)
                        cp.state = .data_suffix;
                    out_end += len;
                    s.next_request_start += len;
                    continue;
                },
                else => {
                    assert(s.state == .receiving_body);
                    const available = try fill(s, head_end);
                    const n = cp.feed(available);
                    switch (cp.state) {
                        .invalid => return error.HttpChunkInvalid,
                        .data => {
                            if (cp.chunk_len == 0) {
                                // The next bytes in the stream are trailers,
                                // or \r\n to indicate end of chunked body.
                                //
                                // This function must append the trailers at
                                // head_end so that headers and trailers are
                                // together.
                                //
                                // Since returning 0 would indicate end of
                                // stream, this function must read all the
                                // trailers before returning.
                                if (s.next_request_start > head_end) rebase(s, head_end);
                                var hp: http.HeadParser = .{};
                                {
                                    const bytes = s.read_buffer[head_end..s.read_buffer_len];
                                    const end = hp.feed(bytes);
                                    if (hp.state == .finished) {
                                        cp.state = .invalid;
                                        s.state = .ready;
                                        s.next_request_start = s.read_buffer_len - bytes.len + end;
                                        return out_end;
                                    }
                                }
                                while (true) {
                                    const buf = s.read_buffer[s.read_buffer_len..];
                                    if (buf.len == 0)
                                        return error.HttpHeadersOversize;
                                    const read_n = try s.connection.stream.read(buf);
                                    s.read_buffer_len += read_n;
                                    const bytes = buf[0..read_n];
                                    const end = hp.feed(bytes);
                                    if (hp.state == .finished) {
                                        cp.state = .invalid;
                                        s.state = .ready;
                                        s.next_request_start = s.read_buffer_len - bytes.len + end;
                                        return out_end;
                                    }
                                }
                            }
                            const data = available[n..];
                            const len = @min(cp.chunk_len, data.len, buffer.len);
                            @memcpy(buffer[0..len], data[0..len]);
                            cp.chunk_len -= len;
                            if (cp.chunk_len == 0)
                                cp.state = .data_suffix;
                            out_end += len;
                            s.next_request_start += n + len;
                            continue;
                        },
                        else => continue,
                    }
                },
            }
        }
        return out_end;
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
        s.next_request_start = request.head_end;

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
                request.reader_state = .{ .chunk_parser = http.ChunkParser.init };
                return .{
                    .context = request,
                    .vtable = &.{
                        .read = &chunkedReader_read,
                        .readVec = &chunkedReader_readVec,
                        .discard = &chunkedReader_discard,
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
                        .read = &contentLengthReader_read,
                        .readVec = &contentLengthReader_readVec,
                        .discard = &contentLengthReader_discard,
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
};

pub const Response = struct {
    /// HTTP protocol to the client.
    ///
    /// This is the underlying stream; use `buffered` to create a
    /// `BufferedWriter` for this `Response`.
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

    /// When using content-length, asserts that the amount of data sent matches
    /// the value sent in the header, then calls `flush`.
    /// Otherwise, transfer-encoding: chunked is being used, and it writes the
    /// end-of-stream message, then flushes the stream to the system.
    /// Respects the value of `elide_body` to omit all data after the headers.
    pub fn end(r: *Response) WriteError!void {
        switch (r.transfer_encoding) {
            .content_length => |len| {
                assert(len == 0); // Trips when end() called before all bytes written.
                try flushContentLength(r);
            },
            .none => {
                try flushContentLength(r);
            },
            .chunked => {
                try flushChunked(r, &.{});
            },
        }
        r.* = undefined;
    }

    pub const EndChunkedOptions = struct {
        trailers: []const http.Header = &.{},
    };

    /// Asserts that the Response is using transfer-encoding: chunked.
    /// Writes the end-of-stream message and any optional trailers, then
    /// flushes the stream to the system.
    /// Respects the value of `elide_body` to omit all data after the headers.
    /// Asserts there are at most 25 trailers.
    pub fn endChunked(r: *Response, options: EndChunkedOptions) WriteError!void {
        assert(r.transfer_encoding == .chunked);
        try flushChunked(r, options.trailers);
        r.* = undefined;
    }

    /// If using content-length, asserts that writing these bytes to the client
    /// would not exceed the content-length value sent in the HTTP header.
    /// May return 0, which does not indicate end of stream. The caller decides
    /// when the end of stream occurs by calling `end`.
    pub fn write(r: *Response, bytes: []const u8) WriteError!usize {
        switch (r.transfer_encoding) {
            .content_length, .none => return contentLengthWriteSplat(r, &.{bytes}, 1),
            .chunked => return chunkedWriteSplat(r, &.{bytes}, 1),
        }
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
            .chunk_len => |chunk_len| {
                l: switch (chunk_len) {
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
                }
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
            .chunk_len => |chunk_len| {
                l: switch (chunk_len) {
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
                }
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

    /// Sends all buffered data to the client.
    /// This is redundant after calling `end`.
    /// Respects the value of `elide_body` to omit all data after the headers.
    pub fn flush(r: *Response) Error!void {
        switch (r.transfer_encoding) {
            .none, .content_length => return flushContentLength(r),
            .chunked => return flushChunked(r, null),
        }
    }

    fn flushContentLength(r: *Response) Error!void {
        try r.out.writeAll(r.send_buffer[r.send_buffer_start..r.send_buffer_end]);
        r.send_buffer_start = 0;
        r.send_buffer_end = 0;
    }

    fn flushChunked(r: *Response, end_trailers: ?[]const http.Header) Error!void {
        const max_trailers = 25;
        if (end_trailers) |trailers| assert(trailers.len <= max_trailers);
        assert(r.transfer_encoding == .chunked);

        const http_headers = r.send_buffer[r.send_buffer_start .. r.send_buffer_end - r.chunk_len];

        if (r.elide_body) {
            try r.out.writeAll(http_headers);
            r.send_buffer_start = 0;
            r.send_buffer_end = 0;
            r.chunk_len = 0;
            return;
        }

        var header_buf: [18]u8 = undefined;
        const chunk_header = std.fmt.bufPrint(&header_buf, "{x}\r\n", .{r.chunk_len}) catch unreachable;

        var iovecs: [max_trailers * 4 + 5][]const u8 = undefined;
        var iovecs_len: usize = 0;

        iovecs[iovecs_len] = http_headers;
        iovecs_len += 1;

        if (r.chunk_len > 0) {
            iovecs[iovecs_len] = chunk_header;
            iovecs_len += 1;

            iovecs[iovecs_len] = r.send_buffer[r.send_buffer_end - r.chunk_len ..][0..r.chunk_len];
            iovecs_len += 1;

            iovecs[iovecs_len] = "\r\n";
            iovecs_len += 1;
        }

        if (end_trailers) |trailers| {
            iovecs[iovecs_len] = "0\r\n";
            iovecs_len += 1;

            for (trailers) |trailer| {
                iovecs[iovecs_len] = trailer.name;
                iovecs_len += 1;

                iovecs[iovecs_len] = ": ";
                iovecs_len += 1;

                if (trailer.value.len != 0) {
                    iovecs[iovecs_len] = trailer.value;
                    iovecs_len += 1;
                }

                iovecs[iovecs_len] = "\r\n";
                iovecs_len += 1;
            }

            iovecs[iovecs_len] = "\r\n";
            iovecs_len += 1;
        }

        try r.out.writeVecAll(iovecs[0..iovecs_len]);
        r.send_buffer_start = 0;
        r.send_buffer_end = 0;
        r.chunk_len = 0;
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

fn rebase(s: *Server, index: usize) void {
    const leftover = s.read_buffer[s.next_request_start..s.read_buffer_len];
    const dest = s.read_buffer[index..][0..leftover.len];
    if (leftover.len <= s.next_request_start - index) {
        @memcpy(dest, leftover);
    } else {
        mem.copyBackwards(u8, dest, leftover);
    }
    s.read_buffer_len = index + leftover.len;
}
