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
pub fn init(in: *std.io.Reader, out: *std.io.BufferedWriter) Server {
    return .{
        .reader = .{
            .in = in,
            .state = .ready,
        },
        .out = out,
    };
}

pub fn deinit(s: *Server) void {
    s.reader.restituteHeadBuffer();
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
    respond_err: ?RespondError,

    pub const RespondError = error{
        /// The request contained an `expect` header with an unrecognized value.
        HttpExpectationFailed,
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
        assert(r.server.reader.state == .received_head);
        return http.HeaderIterator.init(r.server.reader.head_buffer);
    }

    test iterateHeaders {
        const request_bytes = "GET /hi HTTP/1.0\r\n" ++
            "content-tYpe: text/plain\r\n" ++
            "content-Length:10\r\n" ++
            "expeCt:   100-continue \r\n" ++
            "TRansfer-encoding:\tdeflate, chunked \r\n" ++
            "connectioN:\t keep-alive \r\n\r\n";

        var server: Server = .{
            .reader = .{
                .in = undefined,
                .state = .received_head,
                .head_buffer = @constCast(request_bytes),
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
    /// Asserts that "\r\n" does not occur in any header name or value.
    pub fn respond(
        request: *Request,
        content: []const u8,
        options: RespondOptions,
    ) ExpectContinueError!void {
        try respondUnflushed(request, content, options);
        try request.server.out.flush();
    }

    pub fn respondUnflushed(
        request: *Request,
        content: []const u8,
        options: RespondOptions,
    ) ExpectContinueError!void {
        assert(options.status != .@"continue");
        if (std.debug.runtime_safety) {
            for (options.extra_headers) |header| {
                assert(header.name.len != 0);
                assert(std.mem.indexOfScalar(u8, header.name, ':') == null);
                assert(std.mem.indexOfPosLinear(u8, header.name, 0, "\r\n") == null);
                assert(std.mem.indexOfPosLinear(u8, header.value, 0, "\r\n") == null);
            }
        }
        try writeExpectContinue(request);

        const transfer_encoding_none = (options.transfer_encoding orelse .chunked) == .none;
        const server_keep_alive = !transfer_encoding_none and options.keep_alive;
        const keep_alive = request.discardBody(server_keep_alive);

        const phrase = options.reason orelse options.status.phrase() orelse "";

        const out = request.server.out;
        try out.print("{s} {d} {s}\r\n", .{
            @tagName(options.version), @intFromEnum(options.status), phrase,
        });

        switch (options.version) {
            .@"HTTP/1.0" => if (keep_alive) try out.writeAll("connection: keep-alive\r\n"),
            .@"HTTP/1.1" => if (!keep_alive) try out.writeAll("connection: close\r\n"),
        }

        if (options.transfer_encoding) |transfer_encoding| switch (transfer_encoding) {
            .none => {},
            .chunked => try out.writeAll("transfer-encoding: chunked\r\n"),
        } else {
            try out.print("content-length: {d}\r\n", .{content.len});
        }

        for (options.extra_headers) |header| {
            var vecs: [4][]const u8 = .{ header.name, ": ", header.value, "\r\n" };
            try out.writeVecAll(&vecs);
        }

        try out.writeAll("\r\n");

        if (request.head.method != .HEAD) {
            const is_chunked = (options.transfer_encoding orelse .none) == .chunked;
            if (is_chunked) {
                if (content.len > 0) try out.print("{x}\r\n{s}\r\n", .{ content.len, content });
                try out.writeAll("0\r\n\r\n");
            } else if (content.len > 0) {
                try out.writeAll(content);
            }
        }
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
        try writeExpectContinue(request);
        const o = options.respond_options;
        assert(o.status != .@"continue");
        const transfer_encoding_none = (o.transfer_encoding orelse .chunked) == .none;
        const server_keep_alive = !transfer_encoding_none and o.keep_alive;
        const keep_alive = request.discardBody(server_keep_alive);
        const phrase = o.reason orelse o.status.phrase() orelse "";
        const out = request.server.out;

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
        const elide_body = request.head.method == .HEAD;

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

    pub const UpgradeRequest = union(enum) {
        websocket: ?[]const u8,
        other: []const u8,
        none,
    };

    pub fn upgradeRequested(request: *const Request) UpgradeRequest {
        switch (request.head.version) {
            .@"HTTP/1.0" => return null,
            .@"HTTP/1.1" => if (request.head.method != .GET) return null,
        }

        var sec_websocket_key: ?[]const u8 = null;
        var upgrade_name: ?[]const u8 = null;
        var it = request.iterateHeaders();
        while (it.next()) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "sec-websocket-key")) {
                sec_websocket_key = header.value;
            } else if (std.ascii.eqlIgnoreCase(header.name, "upgrade")) {
                upgrade_name = header.value;
            }
        }

        const name = upgrade_name orelse return .none;
        if (std.ascii.eqlIgnoreCase(name, "websocket")) return .{ .websocket = sec_websocket_key };
        return .{ .other = name };
    }

    pub const WebSocketOptions = struct {
        /// The value from `UpgradeRequest.websocket` (sec-websocket-key header value).
        key: []const u8,
        reason: ?[]const u8 = null,
        extra_headers: []const http.Header = &.{},
    };

    /// The header is not guaranteed to be sent until `WebSocket.flush` is
    /// called on the returned struct.
    pub fn respondWebSocket(request: *Request, options: WebSocketOptions) std.io.Writer.Error!WebSocket {
        if (request.head.expect != null) return error.HttpExpectationFailed;

        const out = request.server.out;
        const version: http.Version = .@"HTTP/1.1";
        const status: http.Status = .switching_protocols;
        const phrase = options.reason orelse status.phrase() orelse "";

        assert(request.head.version == version);
        assert(request.head.method == .GET);

        var sha1 = std.crypto.hash.Sha1.init(.{});
        sha1.update(options.key);
        sha1.update("258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
        var digest: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
        sha1.final(&digest);
        try out.print("{s} {d} {s}\r\n", .{ @tagName(version), @intFromEnum(status), phrase });
        try out.writeAll("connection: upgrade\r\nupgrade: websocket\r\nsec-websocket-accept: ");
        const base64_digest = try out.writableArray(28);
        assert(std.base64.standard.Encoder.encode(&base64_digest, &digest).len == base64_digest.len);
        out.advance(base64_digest.len);
        try out.writeAll("\r\n");

        for (options.extra_headers) |header| {
            assert(header.name.len != 0);
            try out.writeAll(header.name);
            try out.writeAll(": ");
            try out.writeAll(header.value);
            try out.writeAll("\r\n");
        }

        try out.writeAll("\r\n");

        return .{
            .input = request.server.reader.in,
            .output = request.server.out,
            .key = options.key,
        };
    }

    /// In the case that the request contains "expect: 100-continue", this
    /// function writes the continuation header, which means it can fail with a
    /// write error. After sending the continuation header, it sets the
    /// request's expect field to `null`.
    ///
    /// Asserts that this function is only called once.
    ///
    /// See `readerExpectNone` for an infallible alternative that cannot write
    /// to the server output stream.
    pub fn readerExpectContinue(request: *Request) ExpectContinueError!std.io.Reader {
        const flush = request.head.expect != null;
        try writeExpectContinue(request);
        if (flush) try request.server.out.flush();
        return readerExpectNone(request);
    }

    /// Asserts the expect header is `null`. The caller must handle the
    /// expectation manually and then set the value to `null` prior to calling
    /// this function.
    ///
    /// Asserts that this function is only called once.
    pub fn readerExpectNone(request: *Request) std.io.Reader {
        assert(request.server.reader.state == .received_head);
        assert(request.head.expect == null);
        if (!request.head.method.requestHasBody()) return .ending;
        return request.server.reader.bodyReader(request.head.transfer_encoding, request.head.content_length);
    }

    pub const ExpectContinueError = error{
        /// Failed to write "HTTP/1.1 100 Continue\r\n\r\n" to the stream.
        WriteFailed,
        /// The client sent an expect HTTP header value other than
        /// "100-continue".
        HttpExpectationFailed,
    };

    pub fn writeExpectContinue(request: *Request) ExpectContinueError!void {
        const expect = request.head.expect orelse return;
        if (!mem.eql(u8, expect, "100-continue")) return error.HttpExpectationFailed;
        try request.server.out.writeAll("HTTP/1.1 100 Continue\r\n\r\n");
        request.head.expect = null;
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

/// See https://tools.ietf.org/html/rfc6455
pub const WebSocket = struct {
    key: []const u8,
    input: *std.io.Reader,
    output: *std.io.BufferedWriter,

    pub const Header0 = packed struct(u8) {
        opcode: Opcode,
        rsv3: u1 = 0,
        rsv2: u1 = 0,
        rsv1: u1 = 0,
        fin: bool,
    };

    pub const Header1 = packed struct(u8) {
        payload_len: enum(u7) {
            len16 = 126,
            len64 = 127,
            _,
        },
        mask: bool,
    };

    pub const Opcode = enum(u4) {
        continuation = 0,
        text = 1,
        binary = 2,
        connection_close = 8,
        ping = 9,
        /// "A Pong frame MAY be sent unsolicited. This serves as a unidirectional
        /// heartbeat. A response to an unsolicited Pong frame is not expected."
        pong = 10,
        _,
    };

    pub const ReadSmallTextMessageError = error{
        ConnectionClose,
        UnexpectedOpCode,
        MessageTooBig,
        MissingMaskBit,
    };

    pub const SmallMessage = struct {
        /// Can be text, binary, or ping.
        opcode: Opcode,
        data: []u8,
    };

    /// Reads the next message from the WebSocket stream, failing if the
    /// message does not fit into the input buffer. The returned memory points
    /// into the input buffer and is invalidated on the next read.
    pub fn readSmallMessage(ws: *WebSocket) ReadSmallTextMessageError!SmallMessage {
        const in = ws.input;
        while (true) {
            const h0 = in.takeStruct(Header0);
            const h1 = in.takeStruct(Header1);

            switch (h0.opcode) {
                .text, .binary, .pong, .ping => {},
                .connection_close => return error.ConnectionClose,
                .continuation => return error.UnexpectedOpCode,
                _ => return error.UnexpectedOpCode,
            }

            if (!h0.fin) return error.MessageTooBig;
            if (!h1.mask) return error.MissingMaskBit;

            const len: usize = switch (h1.payload_len) {
                .len16 => try in.takeInt(u16, .big),
                .len64 => std.math.cast(usize, try in.takeInt(u64, .big)) orelse return error.MessageTooBig,
                else => @intFromEnum(h1.payload_len),
            };
            if (len > in.buffer.len) return error.MessageTooBig;
            const mask: u32 = @bitCast((try in.takeArray(4)).*);
            const payload = try in.take(len);

            // Skip pongs.
            if (h0.opcode == .pong) continue;

            // The last item may contain a partial word of unused data.
            const floored_len = (payload.len / 4) * 4;
            const u32_payload: []align(1) u32 = @ptrCast(payload[0..floored_len]);
            for (u32_payload) |*elem| elem.* ^= mask;
            const mask_bytes: []const u8 = @ptrCast(&mask);
            for (payload[floored_len..], mask_bytes[0 .. payload.len - floored_len]) |*leftover, m|
                leftover.* ^= m;

            return .{
                .opcode = h0.opcode,
                .data = payload,
            };
        }
    }

    pub fn writeMessage(ws: *WebSocket, data: []const u8, op: Opcode) std.io.Writer.Error!void {
        try writeMessageVecUnflushed(ws, &.{data}, op);
        try ws.output.flush();
    }

    pub fn writeMessageUnflushed(ws: *WebSocket, data: []const u8, op: Opcode) std.io.Writer.Error!void {
        try writeMessageVecUnflushed(ws, &.{data}, op);
    }

    pub fn writeMessageVec(ws: *WebSocket, data: []const []const u8, op: Opcode) std.io.Writer.Error!void {
        try writeMessageVecUnflushed(ws, data, op);
        try ws.output.flush();
    }

    pub fn writeMessageVecUnflushed(ws: *WebSocket, data: []const []const u8, op: Opcode) std.io.Writer.Error!void {
        const total_len = l: {
            var total_len: u64 = 0;
            for (data) |iovec| total_len += iovec.len;
            break :l total_len;
        };
        const out = ws.output;
        try out.writeStruct(@as(Header0, .{
            .opcode = op,
            .fin = true,
        }));
        switch (total_len) {
            0...125 => try out.writeStruct(@as(Header1, .{
                .payload_len = @enumFromInt(total_len),
                .mask = false,
            })),
            126...0xffff => {
                try out.writeStruct(@as(Header1, .{
                    .payload_len = .len16,
                    .mask = false,
                }));
                try out.writeInt(u16, @intCast(total_len), .big);
            },
            else => {
                try out.writeStruct(@as(Header1, .{
                    .payload_len = .len64,
                    .mask = false,
                }));
                try out.writeInt(u64, total_len, .big);
            },
        }
        try out.writeVecAll(data);
    }

    pub fn flush(ws: *WebSocket) std.io.Writer.Error!void {
        try ws.output.flush();
    }
};
