//! Handles a single connection lifecycle.

const std = @import("../std.zig");
const http = std.http;
const mem = std.mem;
const Uri = std.Uri;
const assert = std.debug.assert;
const testing = std.testing;

const Server = @This();

/// Data from the HTTP server to the HTTP client.
out: *std.io.BufferedWriter,
reader: http.Reader,

/// Initialize an HTTP server that can respond to multiple requests on the same
/// connection.
///
/// The buffer of `in` must be large enough to store the client's entire HTTP
/// header, otherwise `receiveHead` returns `error.HttpHeadersOversize`.
///
/// The returned `Server` is ready for `receiveHead` to be called.
pub fn init(in: *std.io.BufferedReader, out: *std.io.BufferedWriter) Server {
    return .{
        .reader = .{
            .in = in,
            .state = .ready,
        },
        .out = out,
    };
}

pub const ReceiveHeadError = http.Reader.HeadError || error{
    /// Client sent headers that did not conform to the HTTP protocol.
    ///
    /// To find out more detailed diagnostics, `http.Reader.head_buffer` can be
    /// passed directly to `Request.Head.parse`.
    HttpHeadersInvalid,
};

pub fn receiveHead(s: *Server) ReceiveHeadError!Request {
    try s.reader.receiveHead();
    return .{
        .server = s,
        // No need to track the returned error here since users can repeat the
        // parse with the header buffer to get detailed diagnostics.
        .head = Request.Head.parse(s.reader.head_buffer) catch return error.HttpHeadersInvalid,
    };
}

pub const Request = struct {
    server: *Server,
    /// Pointers in this struct are invalidated with the next call to
    /// `receiveHead`.
    head: Head,

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

                    if (http.ContentEncoding.fromString(trimmed)) |ce| {
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

                        if (http.ContentEncoding.fromString(trimmed_second)) |transfer| {
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
        return http.HeaderIterator.init(r.server.reader.head_buffer);
    }

    test iterateHeaders {
        const request_bytes = "GET /hi HTTP/1.0\r\n" ++
            "content-tYpe: text/plain\r\n" ++
            "content-Length:10\r\n" ++
            "expeCt:   100-continue \r\n" ++
            "TRansfer-encoding:\tdeflate, chunked \r\n" ++
            "connectioN:\t keep-alive \r\n\r\n";

        var br: std.io.BufferedReader = undefined;
        br.initFixed(@constCast(request_bytes));

        var server: Server = .{
            .reader = .{
                .in = &br,
                .state = .ready,
            },
            .out = undefined,
        };

        var request: Request = .{
            .server = &server,
            .head = undefined,
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

    /// The header is not guaranteed to be sent until `BodyWriter.flush` or
    /// `BodyWriter.end` is called.
    ///
    /// If the request contains a body and the connection is to be reused,
    /// discards the request body, leaving the Server in the `ready` state. If
    /// this discarding fails, the connection is marked as not to be reused and
    /// no error is surfaced.
    ///
    /// HEAD requests are handled transparently by setting the
    /// `BodyWriter.elide` flag on the returned `BodyWriter`, causing
    /// the response stream to omit the body. However, it may be worth noticing
    /// that flag and skipping any expensive work that would otherwise need to
    /// be done to satisfy the request.
    ///
    /// Asserts status is not `continue`.
    pub fn respondStreaming(request: *Request, options: RespondStreamingOptions) std.io.Writer.Error!http.BodyWriter {
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
            .http_protocol_output = request.server.out,
            .state = if (o.transfer_encoding) |te| switch (te) {
                .chunked => .{ .chunked = .init },
                .none => .none,
            } else if (options.content_length) |len| .{
                .content_length = len,
            } else .{ .chunked = .init },
            .elide = elide_body,
        };
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
        assert(request.server.reader.state == .received_head);
        if (request.head.expect) |expect| {
            if (mem.eql(u8, expect, "100-continue")) {
                try request.server.out.writeAll("HTTP/1.1 100 Continue\r\n\r\n");
                request.head.expect = null;
            } else {
                return error.HttpExpectationFailed;
            }
        }
        return request.server.reader.bodyReader(request.head.transfer_encoding, request.head.content_length);
    }

    /// Returns whether the connection should remain persistent.
    ///
    /// If it would fail, it instead sets the Server state to receiving body
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
        const r = &request.server.reader;
        if (keep_alive and request.head.keep_alive) switch (r.state) {
            .received_head => {
                if (request.head.method.requestHasBody()) {
                    assert(request.head.transfer_encoding != .none or request.head.content_length != null);
                    const reader_interface = request.reader() catch return false;
                    _ = reader_interface.discardRemaining() catch return false;
                    assert(r.state == .ready);
                } else {
                    r.state = .ready;
                }
                return true;
            },
            .body_remaining_content_length, .body_remaining_chunk_len, .body_none, .ready => return true,
            else => unreachable,
        };

        // Avoid clobbering the state in case a reading stream already exists.
        switch (r.state) {
            .received_head => r.state = .closing,
            else => {},
        }
        return false;
    }
};
