//! Blocking HTTP server implementation.
//! Handles a single connection's lifecycle.

connection: net.Server.Connection,
/// Keeps track of whether the Server is ready to accept a new request on the
/// same connection, and makes invalid API usage cause assertion failures
/// rather than HTTP protocol violations.
state: State,
/// User-provided buffer that must outlive this Server.
/// Used to store the client's entire HTTP header.
read_buffer: []u8,
/// Amount of available data inside read_buffer.
read_buffer_len: usize,
/// Index into `read_buffer` of the first byte of the next HTTP request.
next_request_start: usize,

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
/// The returned `Server` is ready for `receiveHead` to be called.
pub fn init(connection: net.Server.Connection, read_buffer: []u8) Server {
    return .{
        .connection = connection,
        .state = .ready,
        .read_buffer = read_buffer,
        .read_buffer_len = 0,
        .next_request_start = 0,
    };
}

pub const ReceiveHeadError = error{
    /// Client sent too many bytes of HTTP headers.
    /// The HTTP specification suggests to respond with a 431 status code
    /// before closing the connection.
    HttpHeadersOversize,
    /// Client sent headers that did not conform to the HTTP protocol.
    HttpHeadersInvalid,
    /// A low level I/O error occurred trying to read the headers.
    HttpHeadersUnreadable,
    /// Partial HTTP request was received but the connection was closed before
    /// fully receiving the headers.
    HttpRequestTruncated,
    /// The client sent 0 bytes of headers before closing the stream.
    /// In other words, a keep-alive connection was finally closed.
    HttpConnectionClosing,
};

/// The header bytes reference the read buffer that Server was initialized with
/// and remain alive until the next call to receiveHead.
pub fn receiveHead(s: *Server) ReceiveHeadError!Request {
    assert(s.state == .ready);
    s.state = .received_head;
    errdefer s.state = .receiving_head;

    // In case of a reused connection, move the next request's bytes to the
    // beginning of the buffer.
    if (s.next_request_start > 0) {
        if (s.read_buffer_len > s.next_request_start) {
            rebase(s, 0);
        } else {
            s.read_buffer_len = 0;
        }
    }

    var hp: http.HeadParser = .{};

    if (s.read_buffer_len > 0) {
        const bytes = s.read_buffer[0..s.read_buffer_len];
        const end = hp.feed(bytes);
        if (hp.state == .finished)
            return finishReceivingHead(s, end);
    }

    while (true) {
        const buf = s.read_buffer[s.read_buffer_len..];
        if (buf.len == 0)
            return error.HttpHeadersOversize;
        const read_n = s.connection.stream.read(buf) catch
            return error.HttpHeadersUnreadable;
        if (read_n == 0) {
            if (s.read_buffer_len > 0) {
                return error.HttpRequestTruncated;
            } else {
                return error.HttpConnectionClosing;
            }
        }
        s.read_buffer_len += read_n;
        const bytes = buf[0..read_n];
        const end = hp.feed(bytes);
        if (hp.state == .finished)
            return finishReceivingHead(s, s.read_buffer_len - bytes.len + end);
    }
}

fn finishReceivingHead(s: *Server, head_end: usize) ReceiveHeadError!Request {
    return .{
        .server = s,
        .head_end = head_end,
        .head = Request.Head.parse(s.read_buffer[0..head_end]) catch
            return error.HttpHeadersInvalid,
        .reader_state = undefined,
    };
}

pub const Request = struct {
    server: *Server,
    /// Index into Server's read_buffer.
    head_end: usize,
    head: Head,
    reader_state: union {
        remaining_content_length: u64,
        chunk_parser: http.ChunkParser,
    },

    pub const Compression = union(enum) {
        pub const DeflateDecompressor = std.compress.zlib.Decompressor(std.io.AnyReader);
        pub const GzipDecompressor = std.compress.gzip.Decompressor(std.io.AnyReader);
        pub const ZstdDecompressor = std.compress.zstd.Decompressor(std.io.AnyReader);

        deflate: DeflateDecompressor,
        gzip: GzipDecompressor,
        zstd: ZstdDecompressor,
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
        return http.HeaderIterator.init(r.server.read_buffer[0..r.head_end]);
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

        var server: Server = .{
            .connection = undefined,
            .state = .ready,
            .read_buffer = &read_buffer,
            .read_buffer_len = request_bytes.len,
            .next_request_start = 0,
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
    ) Response.WriteError!void {
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
            try request.server.connection.stream.writeAll(h.items);
            return;
        }
        h.fixedWriter().print("{s} {d} {s}\r\n", .{
            @tagName(options.version), @intFromEnum(options.status), phrase,
        }) catch unreachable;

        switch (options.version) {
            .@"HTTP/1.0" => if (keep_alive) h.appendSliceAssumeCapacity("connection: keep-alive\r\n"),
            .@"HTTP/1.1" => if (!keep_alive) h.appendSliceAssumeCapacity("connection: close\r\n"),
        }

        if (options.transfer_encoding) |transfer_encoding| switch (transfer_encoding) {
            .none => {},
            .chunked => h.appendSliceAssumeCapacity("transfer-encoding: chunked\r\n"),
        } else {
            h.fixedWriter().print("content-length: {d}\r\n", .{content.len}) catch unreachable;
        }

        var chunk_header_buffer: [18]u8 = undefined;
        var iovecs: [max_extra_headers * 4 + 3]std.posix.iovec_const = undefined;
        var iovecs_len: usize = 0;

        iovecs[iovecs_len] = .{
            .iov_base = h.items.ptr,
            .iov_len = h.items.len,
        };
        iovecs_len += 1;

        for (options.extra_headers) |header| {
            iovecs[iovecs_len] = .{
                .iov_base = header.name.ptr,
                .iov_len = header.name.len,
            };
            iovecs_len += 1;

            iovecs[iovecs_len] = .{
                .iov_base = ": ",
                .iov_len = 2,
            };
            iovecs_len += 1;

            if (header.value.len != 0) {
                iovecs[iovecs_len] = .{
                    .iov_base = header.value.ptr,
                    .iov_len = header.value.len,
                };
                iovecs_len += 1;
            }

            iovecs[iovecs_len] = .{
                .iov_base = "\r\n",
                .iov_len = 2,
            };
            iovecs_len += 1;
        }

        iovecs[iovecs_len] = .{
            .iov_base = "\r\n",
            .iov_len = 2,
        };
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

                    iovecs[iovecs_len] = .{
                        .iov_base = chunk_header.ptr,
                        .iov_len = chunk_header.len,
                    };
                    iovecs_len += 1;

                    iovecs[iovecs_len] = .{
                        .iov_base = content.ptr,
                        .iov_len = content.len,
                    };
                    iovecs_len += 1;

                    iovecs[iovecs_len] = .{
                        .iov_base = "\r\n",
                        .iov_len = 2,
                    };
                    iovecs_len += 1;
                }

                iovecs[iovecs_len] = .{
                    .iov_base = "0\r\n\r\n",
                    .iov_len = 5,
                };
                iovecs_len += 1;
            } else if (content.len > 0) {
                iovecs[iovecs_len] = .{
                    .iov_base = content.ptr,
                    .iov_len = content.len,
                };
                iovecs_len += 1;
            }
        }

        try request.server.connection.stream.writevAll(iovecs[0..iovecs_len]);
    }

    pub const RespondStreamingOptions = struct {
        /// An externally managed slice of memory used to batch bytes before
        /// sending. `respondStreaming` asserts this is large enough to store
        /// the full HTTP response head.
        ///
        /// Must outlive the returned Response.
        send_buffer: []u8,
        /// If provided, the response will use the content-length header;
        /// otherwise it will use transfer-encoding: chunked.
        content_length: ?u64 = null,
        /// Options that are shared with the `respond` method.
        respond_options: RespondOptions = .{},
    };

    /// The header is buffered but not sent until Response.flush is called.
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
    /// Asserts `send_buffer` is large enough to store the entire response header.
    /// Asserts status is not `continue`.
    pub fn respondStreaming(request: *Request, options: RespondStreamingOptions) Response {
        const o = options.respond_options;
        assert(o.status != .@"continue");
        const transfer_encoding_none = (o.transfer_encoding orelse .chunked) == .none;
        const server_keep_alive = !transfer_encoding_none and o.keep_alive;
        const keep_alive = request.discardBody(server_keep_alive);
        const phrase = o.reason orelse o.status.phrase() orelse "";

        var h = std.ArrayListUnmanaged(u8).initBuffer(options.send_buffer);

        const elide_body = if (request.head.expect != null) eb: {
            // reader() and hence discardBody() above sets expect to null if it
            // is handled. So the fact that it is not null here means unhandled.
            h.appendSliceAssumeCapacity("HTTP/1.1 417 Expectation Failed\r\n");
            if (!keep_alive) h.appendSliceAssumeCapacity("connection: close\r\n");
            h.appendSliceAssumeCapacity("content-length: 0\r\n\r\n");
            break :eb true;
        } else eb: {
            h.fixedWriter().print("{s} {d} {s}\r\n", .{
                @tagName(o.version), @intFromEnum(o.status), phrase,
            }) catch unreachable;

            switch (o.version) {
                .@"HTTP/1.0" => if (keep_alive) h.appendSliceAssumeCapacity("connection: keep-alive\r\n"),
                .@"HTTP/1.1" => if (!keep_alive) h.appendSliceAssumeCapacity("connection: close\r\n"),
            }

            if (o.transfer_encoding) |transfer_encoding| switch (transfer_encoding) {
                .chunked => h.appendSliceAssumeCapacity("transfer-encoding: chunked\r\n"),
                .none => {},
            } else if (options.content_length) |len| {
                h.fixedWriter().print("content-length: {d}\r\n", .{len}) catch unreachable;
            } else {
                h.appendSliceAssumeCapacity("transfer-encoding: chunked\r\n");
            }

            for (o.extra_headers) |header| {
                assert(header.name.len != 0);
                h.appendSliceAssumeCapacity(header.name);
                h.appendSliceAssumeCapacity(": ");
                h.appendSliceAssumeCapacity(header.value);
                h.appendSliceAssumeCapacity("\r\n");
            }

            h.appendSliceAssumeCapacity("\r\n");
            break :eb request.head.method == .HEAD;
        };

        return .{
            .stream = request.server.connection.stream,
            .send_buffer = options.send_buffer,
            .send_buffer_start = 0,
            .send_buffer_end = h.items.len,
            .transfer_encoding = if (o.transfer_encoding) |te| switch (te) {
                .chunked => .chunked,
                .none => .none,
            } else if (options.content_length) |len| .{
                .content_length = len,
            } else .chunked,
            .elide_body = elide_body,
            .chunk_len = 0,
        };
    }

    pub const ReadError = net.Stream.ReadError || error{
        HttpChunkInvalid,
        HttpHeadersOversize,
    };

    fn read_cl(context: *const anyopaque, buffer: []u8) ReadError!usize {
        const request: *Request = @constCast(@alignCast(@ptrCast(context)));
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
        const request: *Request = @constCast(@alignCast(@ptrCast(context)));
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

    pub const ReaderError = Response.WriteError || error{
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
    pub fn reader(request: *Request) ReaderError!std.io.AnyReader {
        const s = request.server;
        assert(s.state == .received_head);
        s.state = .receiving_body;
        s.next_request_start = request.head_end;

        if (request.head.expect) |expect| {
            if (mem.eql(u8, expect, "100-continue")) {
                try request.server.connection.stream.writeAll("HTTP/1.1 100 Continue\r\n\r\n");
                request.head.expect = null;
            } else {
                return error.HttpExpectationFailed;
            }
        }

        switch (request.head.transfer_encoding) {
            .chunked => {
                request.reader_state = .{ .chunk_parser = http.ChunkParser.init };
                return .{
                    .readFn = read_chunked,
                    .context = request,
                };
            },
            .none => {
                request.reader_state = .{
                    .remaining_content_length = request.head.content_length orelse 0,
                };
                return .{
                    .readFn = read_cl,
                    .context = request,
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
                _ = r.discard() catch return false;
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
    stream: net.Stream,
    send_buffer: []u8,
    /// Index of the first byte in `send_buffer`.
    /// This is 0 unless a short write happens in `write`.
    send_buffer_start: usize,
    /// Index of the last byte + 1 in `send_buffer`.
    send_buffer_end: usize,
    /// `null` means transfer-encoding: chunked.
    /// As a debugging utility, counts down to zero as bytes are written.
    transfer_encoding: TransferEncoding,
    elide_body: bool,
    /// Indicates how much of the end of the `send_buffer` corresponds to a
    /// chunk. This amount of data will be wrapped by an HTTP chunk header.
    chunk_len: usize,

    pub const TransferEncoding = union(enum) {
        /// End of connection signals the end of the stream.
        none,
        /// As a debugging utility, counts down to zero as bytes are written.
        content_length: u64,
        /// Each chunk is wrapped in a header and trailer.
        chunked,
    };

    pub const WriteError = net.Stream.WriteError;

    /// When using content-length, asserts that the amount of data sent matches
    /// the value sent in the header, then calls `flush`.
    /// Otherwise, transfer-encoding: chunked is being used, and it writes the
    /// end-of-stream message, then flushes the stream to the system.
    /// Respects the value of `elide_body` to omit all data after the headers.
    pub fn end(r: *Response) WriteError!void {
        switch (r.transfer_encoding) {
            .content_length => |len| {
                assert(len == 0); // Trips when end() called before all bytes written.
                try flush_cl(r);
            },
            .none => {
                try flush_cl(r);
            },
            .chunked => {
                try flush_chunked(r, &.{});
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
        try flush_chunked(r, options.trailers);
        r.* = undefined;
    }

    /// If using content-length, asserts that writing these bytes to the client
    /// would not exceed the content-length value sent in the HTTP header.
    /// May return 0, which does not indicate end of stream. The caller decides
    /// when the end of stream occurs by calling `end`.
    pub fn write(r: *Response, bytes: []const u8) WriteError!usize {
        switch (r.transfer_encoding) {
            .content_length, .none => return write_cl(r, bytes),
            .chunked => return write_chunked(r, bytes),
        }
    }

    fn write_cl(context: *const anyopaque, bytes: []const u8) WriteError!usize {
        const r: *Response = @constCast(@alignCast(@ptrCast(context)));

        var trash: u64 = std.math.maxInt(u64);
        const len = switch (r.transfer_encoding) {
            .content_length => |*len| len,
            else => &trash,
        };

        if (r.elide_body) {
            len.* -= bytes.len;
            return bytes.len;
        }

        if (bytes.len + r.send_buffer_end > r.send_buffer.len) {
            const send_buffer_len = r.send_buffer_end - r.send_buffer_start;
            var iovecs: [2]std.posix.iovec_const = .{
                .{
                    .iov_base = r.send_buffer.ptr + r.send_buffer_start,
                    .iov_len = send_buffer_len,
                },
                .{
                    .iov_base = bytes.ptr,
                    .iov_len = bytes.len,
                },
            };
            const n = try r.stream.writev(&iovecs);

            if (n >= send_buffer_len) {
                // It was enough to reset the buffer.
                r.send_buffer_start = 0;
                r.send_buffer_end = 0;
                const bytes_n = n - send_buffer_len;
                len.* -= bytes_n;
                return bytes_n;
            }

            // It didn't even make it through the existing buffer, let
            // alone the new bytes provided.
            r.send_buffer_start += n;
            return 0;
        }

        // All bytes can be stored in the remaining space of the buffer.
        @memcpy(r.send_buffer[r.send_buffer_end..][0..bytes.len], bytes);
        r.send_buffer_end += bytes.len;
        len.* -= bytes.len;
        return bytes.len;
    }

    fn write_chunked(context: *const anyopaque, bytes: []const u8) WriteError!usize {
        const r: *Response = @constCast(@alignCast(@ptrCast(context)));
        assert(r.transfer_encoding == .chunked);

        if (r.elide_body)
            return bytes.len;

        if (bytes.len + r.send_buffer_end > r.send_buffer.len) {
            const send_buffer_len = r.send_buffer_end - r.send_buffer_start;
            const chunk_len = r.chunk_len + bytes.len;
            var header_buf: [18]u8 = undefined;
            const chunk_header = std.fmt.bufPrint(&header_buf, "{x}\r\n", .{chunk_len}) catch unreachable;

            var iovecs: [5]std.posix.iovec_const = .{
                .{
                    .iov_base = r.send_buffer.ptr + r.send_buffer_start,
                    .iov_len = send_buffer_len - r.chunk_len,
                },
                .{
                    .iov_base = chunk_header.ptr,
                    .iov_len = chunk_header.len,
                },
                .{
                    .iov_base = r.send_buffer.ptr + r.send_buffer_end - r.chunk_len,
                    .iov_len = r.chunk_len,
                },
                .{
                    .iov_base = bytes.ptr,
                    .iov_len = bytes.len,
                },
                .{
                    .iov_base = "\r\n",
                    .iov_len = 2,
                },
            };
            // TODO make this writev instead of writevAll, which involves
            // complicating the logic of this function.
            try r.stream.writevAll(&iovecs);
            r.send_buffer_start = 0;
            r.send_buffer_end = 0;
            r.chunk_len = 0;
            return bytes.len;
        }

        // All bytes can be stored in the remaining space of the buffer.
        @memcpy(r.send_buffer[r.send_buffer_end..][0..bytes.len], bytes);
        r.send_buffer_end += bytes.len;
        r.chunk_len += bytes.len;
        return bytes.len;
    }

    /// If using content-length, asserts that writing these bytes to the client
    /// would not exceed the content-length value sent in the HTTP header.
    pub fn writeAll(r: *Response, bytes: []const u8) WriteError!void {
        var index: usize = 0;
        while (index < bytes.len) {
            index += try write(r, bytes[index..]);
        }
    }

    /// Sends all buffered data to the client.
    /// This is redundant after calling `end`.
    /// Respects the value of `elide_body` to omit all data after the headers.
    pub fn flush(r: *Response) WriteError!void {
        switch (r.transfer_encoding) {
            .none, .content_length => return flush_cl(r),
            .chunked => return flush_chunked(r, null),
        }
    }

    fn flush_cl(r: *Response) WriteError!void {
        try r.stream.writeAll(r.send_buffer[r.send_buffer_start..r.send_buffer_end]);
        r.send_buffer_start = 0;
        r.send_buffer_end = 0;
    }

    fn flush_chunked(r: *Response, end_trailers: ?[]const http.Header) WriteError!void {
        const max_trailers = 25;
        if (end_trailers) |trailers| assert(trailers.len <= max_trailers);
        assert(r.transfer_encoding == .chunked);

        const http_headers = r.send_buffer[r.send_buffer_start .. r.send_buffer_end - r.chunk_len];

        if (r.elide_body) {
            try r.stream.writeAll(http_headers);
            r.send_buffer_start = 0;
            r.send_buffer_end = 0;
            r.chunk_len = 0;
            return;
        }

        var header_buf: [18]u8 = undefined;
        const chunk_header = std.fmt.bufPrint(&header_buf, "{x}\r\n", .{r.chunk_len}) catch unreachable;

        var iovecs: [max_trailers * 4 + 5]std.posix.iovec_const = undefined;
        var iovecs_len: usize = 0;

        iovecs[iovecs_len] = .{
            .iov_base = http_headers.ptr,
            .iov_len = http_headers.len,
        };
        iovecs_len += 1;

        if (r.chunk_len > 0) {
            iovecs[iovecs_len] = .{
                .iov_base = chunk_header.ptr,
                .iov_len = chunk_header.len,
            };
            iovecs_len += 1;

            iovecs[iovecs_len] = .{
                .iov_base = r.send_buffer.ptr + r.send_buffer_end - r.chunk_len,
                .iov_len = r.chunk_len,
            };
            iovecs_len += 1;

            iovecs[iovecs_len] = .{
                .iov_base = "\r\n",
                .iov_len = 2,
            };
            iovecs_len += 1;
        }

        if (end_trailers) |trailers| {
            iovecs[iovecs_len] = .{
                .iov_base = "0\r\n",
                .iov_len = 3,
            };
            iovecs_len += 1;

            for (trailers) |trailer| {
                iovecs[iovecs_len] = .{
                    .iov_base = trailer.name.ptr,
                    .iov_len = trailer.name.len,
                };
                iovecs_len += 1;

                iovecs[iovecs_len] = .{
                    .iov_base = ": ",
                    .iov_len = 2,
                };
                iovecs_len += 1;

                if (trailer.value.len != 0) {
                    iovecs[iovecs_len] = .{
                        .iov_base = trailer.value.ptr,
                        .iov_len = trailer.value.len,
                    };
                    iovecs_len += 1;
                }

                iovecs[iovecs_len] = .{
                    .iov_base = "\r\n",
                    .iov_len = 2,
                };
                iovecs_len += 1;
            }

            iovecs[iovecs_len] = .{
                .iov_base = "\r\n",
                .iov_len = 2,
            };
            iovecs_len += 1;
        }

        try r.stream.writevAll(iovecs[0..iovecs_len]);
        r.send_buffer_start = 0;
        r.send_buffer_end = 0;
        r.chunk_len = 0;
    }

    pub fn writer(r: *Response) std.io.AnyWriter {
        return .{
            .writeFn = switch (r.transfer_encoding) {
                .none, .content_length => write_cl,
                .chunked => write_chunked,
            },
            .context = r,
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

const std = @import("../std.zig");
const http = std.http;
const mem = std.mem;
const net = std.net;
const Uri = std.Uri;
const assert = std.debug.assert;
const testing = std.testing;

const Server = @This();
