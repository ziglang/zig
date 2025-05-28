const builtin = @import("builtin");
const std = @import("std.zig");
const assert = std.debug.assert;

pub const Client = @import("http/Client.zig");
pub const Server = @import("http/Server.zig");
pub const HeadParser = @import("http/HeadParser.zig");
pub const ChunkParser = @import("http/ChunkParser.zig");
pub const HeaderIterator = @import("http/HeaderIterator.zig");

pub const Version = enum {
    @"HTTP/1.0",
    @"HTTP/1.1",
};

/// https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods
///
/// https://datatracker.ietf.org/doc/html/rfc7231#section-4 Initial definition
///
/// https://datatracker.ietf.org/doc/html/rfc5789#section-2 PATCH
pub const Method = enum(u64) {
    GET = parse("GET"),
    HEAD = parse("HEAD"),
    POST = parse("POST"),
    PUT = parse("PUT"),
    DELETE = parse("DELETE"),
    CONNECT = parse("CONNECT"),
    OPTIONS = parse("OPTIONS"),
    TRACE = parse("TRACE"),
    PATCH = parse("PATCH"),

    _,

    /// Converts `s` into a type that may be used as a `Method` field.
    /// Asserts that `s` is 24 or fewer bytes.
    pub fn parse(s: []const u8) u64 {
        var x: u64 = 0;
        const len = @min(s.len, @sizeOf(@TypeOf(x)));
        @memcpy(std.mem.asBytes(&x)[0..len], s[0..len]);
        return x;
    }

    pub fn write(self: Method, w: anytype) !void {
        const bytes = std.mem.asBytes(&@intFromEnum(self));
        const str = std.mem.sliceTo(bytes, 0);
        try w.writeAll(str);
    }

    /// Returns true if a request of this method is allowed to have a body
    /// Actual behavior from servers may vary and should still be checked
    pub fn requestHasBody(self: Method) bool {
        return switch (self) {
            .POST, .PUT, .PATCH => true,
            .GET, .HEAD, .DELETE, .CONNECT, .OPTIONS, .TRACE => false,
            else => true,
        };
    }

    /// Returns true if a response to this method is allowed to have a body
    /// Actual behavior from clients may vary and should still be checked
    pub fn responseHasBody(self: Method) bool {
        return switch (self) {
            .GET, .POST, .DELETE, .CONNECT, .OPTIONS, .PATCH => true,
            .HEAD, .PUT, .TRACE => false,
            else => true,
        };
    }

    /// An HTTP method is safe if it doesn't alter the state of the server.
    ///
    /// https://developer.mozilla.org/en-US/docs/Glossary/Safe/HTTP
    ///
    /// https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.1
    pub fn safe(self: Method) bool {
        return switch (self) {
            .GET, .HEAD, .OPTIONS, .TRACE => true,
            .POST, .PUT, .DELETE, .CONNECT, .PATCH => false,
            else => false,
        };
    }

    /// An HTTP method is idempotent if an identical request can be made once
    /// or several times in a row with the same effect while leaving the server
    /// in the same state.
    ///
    /// https://developer.mozilla.org/en-US/docs/Glossary/Idempotent
    ///
    /// https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.2
    pub fn idempotent(self: Method) bool {
        return switch (self) {
            .GET, .HEAD, .PUT, .DELETE, .OPTIONS, .TRACE => true,
            .CONNECT, .POST, .PATCH => false,
            else => false,
        };
    }

    /// A cacheable response can be stored to be retrieved and used later,
    /// saving a new request to the server.
    ///
    /// https://developer.mozilla.org/en-US/docs/Glossary/cacheable
    ///
    /// https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.3
    pub fn cacheable(self: Method) bool {
        return switch (self) {
            .GET, .HEAD => true,
            .POST, .PUT, .DELETE, .CONNECT, .OPTIONS, .TRACE, .PATCH => false,
            else => false,
        };
    }
};

/// https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
pub const Status = enum(u10) {
    @"continue" = 100, // RFC7231, Section 6.2.1
    switching_protocols = 101, // RFC7231, Section 6.2.2
    processing = 102, // RFC2518
    early_hints = 103, // RFC8297

    ok = 200, // RFC7231, Section 6.3.1
    created = 201, // RFC7231, Section 6.3.2
    accepted = 202, // RFC7231, Section 6.3.3
    non_authoritative_info = 203, // RFC7231, Section 6.3.4
    no_content = 204, // RFC7231, Section 6.3.5
    reset_content = 205, // RFC7231, Section 6.3.6
    partial_content = 206, // RFC7233, Section 4.1
    multi_status = 207, // RFC4918
    already_reported = 208, // RFC5842
    im_used = 226, // RFC3229

    multiple_choice = 300, // RFC7231, Section 6.4.1
    moved_permanently = 301, // RFC7231, Section 6.4.2
    found = 302, // RFC7231, Section 6.4.3
    see_other = 303, // RFC7231, Section 6.4.4
    not_modified = 304, // RFC7232, Section 4.1
    use_proxy = 305, // RFC7231, Section 6.4.5
    temporary_redirect = 307, // RFC7231, Section 6.4.7
    permanent_redirect = 308, // RFC7538

    bad_request = 400, // RFC7231, Section 6.5.1
    unauthorized = 401, // RFC7235, Section 3.1
    payment_required = 402, // RFC7231, Section 6.5.2
    forbidden = 403, // RFC7231, Section 6.5.3
    not_found = 404, // RFC7231, Section 6.5.4
    method_not_allowed = 405, // RFC7231, Section 6.5.5
    not_acceptable = 406, // RFC7231, Section 6.5.6
    proxy_auth_required = 407, // RFC7235, Section 3.2
    request_timeout = 408, // RFC7231, Section 6.5.7
    conflict = 409, // RFC7231, Section 6.5.8
    gone = 410, // RFC7231, Section 6.5.9
    length_required = 411, // RFC7231, Section 6.5.10
    precondition_failed = 412, // RFC7232, Section 4.2][RFC8144, Section 3.2
    payload_too_large = 413, // RFC7231, Section 6.5.11
    uri_too_long = 414, // RFC7231, Section 6.5.12
    unsupported_media_type = 415, // RFC7231, Section 6.5.13][RFC7694, Section 3
    range_not_satisfiable = 416, // RFC7233, Section 4.4
    expectation_failed = 417, // RFC7231, Section 6.5.14
    teapot = 418, // RFC 7168, 2.3.3
    misdirected_request = 421, // RFC7540, Section 9.1.2
    unprocessable_entity = 422, // RFC4918
    locked = 423, // RFC4918
    failed_dependency = 424, // RFC4918
    too_early = 425, // RFC8470
    upgrade_required = 426, // RFC7231, Section 6.5.15
    precondition_required = 428, // RFC6585
    too_many_requests = 429, // RFC6585
    request_header_fields_too_large = 431, // RFC6585
    unavailable_for_legal_reasons = 451, // RFC7725

    internal_server_error = 500, // RFC7231, Section 6.6.1
    not_implemented = 501, // RFC7231, Section 6.6.2
    bad_gateway = 502, // RFC7231, Section 6.6.3
    service_unavailable = 503, // RFC7231, Section 6.6.4
    gateway_timeout = 504, // RFC7231, Section 6.6.5
    http_version_not_supported = 505, // RFC7231, Section 6.6.6
    variant_also_negotiates = 506, // RFC2295
    insufficient_storage = 507, // RFC4918
    loop_detected = 508, // RFC5842
    not_extended = 510, // RFC2774
    network_authentication_required = 511, // RFC6585

    _,

    pub fn phrase(self: Status) ?[]const u8 {
        return switch (self) {
            // 1xx statuses
            .@"continue" => "Continue",
            .switching_protocols => "Switching Protocols",
            .processing => "Processing",
            .early_hints => "Early Hints",

            // 2xx statuses
            .ok => "OK",
            .created => "Created",
            .accepted => "Accepted",
            .non_authoritative_info => "Non-Authoritative Information",
            .no_content => "No Content",
            .reset_content => "Reset Content",
            .partial_content => "Partial Content",
            .multi_status => "Multi-Status",
            .already_reported => "Already Reported",
            .im_used => "IM Used",

            // 3xx statuses
            .multiple_choice => "Multiple Choice",
            .moved_permanently => "Moved Permanently",
            .found => "Found",
            .see_other => "See Other",
            .not_modified => "Not Modified",
            .use_proxy => "Use Proxy",
            .temporary_redirect => "Temporary Redirect",
            .permanent_redirect => "Permanent Redirect",

            // 4xx statuses
            .bad_request => "Bad Request",
            .unauthorized => "Unauthorized",
            .payment_required => "Payment Required",
            .forbidden => "Forbidden",
            .not_found => "Not Found",
            .method_not_allowed => "Method Not Allowed",
            .not_acceptable => "Not Acceptable",
            .proxy_auth_required => "Proxy Authentication Required",
            .request_timeout => "Request Timeout",
            .conflict => "Conflict",
            .gone => "Gone",
            .length_required => "Length Required",
            .precondition_failed => "Precondition Failed",
            .payload_too_large => "Payload Too Large",
            .uri_too_long => "URI Too Long",
            .unsupported_media_type => "Unsupported Media Type",
            .range_not_satisfiable => "Range Not Satisfiable",
            .expectation_failed => "Expectation Failed",
            .teapot => "I'm a teapot",
            .misdirected_request => "Misdirected Request",
            .unprocessable_entity => "Unprocessable Entity",
            .locked => "Locked",
            .failed_dependency => "Failed Dependency",
            .too_early => "Too Early",
            .upgrade_required => "Upgrade Required",
            .precondition_required => "Precondition Required",
            .too_many_requests => "Too Many Requests",
            .request_header_fields_too_large => "Request Header Fields Too Large",
            .unavailable_for_legal_reasons => "Unavailable For Legal Reasons",

            // 5xx statuses
            .internal_server_error => "Internal Server Error",
            .not_implemented => "Not Implemented",
            .bad_gateway => "Bad Gateway",
            .service_unavailable => "Service Unavailable",
            .gateway_timeout => "Gateway Timeout",
            .http_version_not_supported => "HTTP Version Not Supported",
            .variant_also_negotiates => "Variant Also Negotiates",
            .insufficient_storage => "Insufficient Storage",
            .loop_detected => "Loop Detected",
            .not_extended => "Not Extended",
            .network_authentication_required => "Network Authentication Required",

            else => return null,
        };
    }

    pub const Class = enum {
        informational,
        success,
        redirect,
        client_error,
        server_error,
    };

    pub fn class(self: Status) Class {
        return switch (@intFromEnum(self)) {
            100...199 => .informational,
            200...299 => .success,
            300...399 => .redirect,
            400...499 => .client_error,
            else => .server_error,
        };
    }

    test {
        try std.testing.expectEqualStrings("OK", Status.ok.phrase().?);
        try std.testing.expectEqualStrings("Not Found", Status.not_found.phrase().?);
    }

    test {
        try std.testing.expectEqual(Status.Class.success, Status.ok.class());
        try std.testing.expectEqual(Status.Class.client_error, Status.not_found.class());
    }
};

/// compression is intentionally omitted here since it is handled in `ContentEncoding`.
pub const TransferEncoding = enum {
    chunked,
    none,
};

pub const ContentEncoding = enum {
    zstd,
    gzip,
    deflate,
    compress,
    identity,

    pub fn fromString(s: []const u8) ?ContentEncoding {
        const map = std.StaticStringMap(ContentEncoding).initComptime(.{
            .{ "zstd", .zstd },
            .{ "gzip", .gzip },
            .{ "x-gzip", .gzip },
            .{ "deflate", .deflate },
            .{ "compress", .compress },
            .{ "x-compress", .compress },
            .{ "identity", .identity },
        });
        return map.get(s);
    }
};

pub const Connection = enum {
    keep_alive,
    close,
};

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const Reader = struct {
    in: *std.io.BufferedReader,
    /// Keeps track of whether the stream is ready to accept a new request,
    /// making invalid API usage cause assertion failures rather than HTTP
    /// protocol violations.
    state: State,
    /// HTTP trailer bytes. These are at the end of a transfer-encoding:
    /// chunked message. This data is available only after calling one of the
    /// "end" functions and points to data inside the buffer of `in`, and is
    /// therefore invalidated on the next call to `receiveHead`, or any other
    /// read from `in`.
    trailers: []const u8 = &.{},
    body_err: ?BodyError = null,
    /// Stolen from `in`.
    head_buffer: []u8 = &.{},

    pub const max_chunk_header_len = 22;

    pub const RemainingChunkLen = enum(u64) {
        head = 0,
        n = 1,
        rn = 2,
        _,

        pub fn init(integer: u64) RemainingChunkLen {
            return @enumFromInt(integer);
        }

        pub fn int(rcl: RemainingChunkLen) u64 {
            return @intFromEnum(rcl);
        }
    };

    pub const State = union(enum) {
        /// The stream is available to be used for the first time, or reused.
        ready,
        received_head,
        /// The stream goes until the connection is closed.
        body_none,
        body_remaining_content_length: u64,
        body_remaining_chunk_len: RemainingChunkLen,
        /// The stream would be eligible for another HTTP request, however the
        /// client and server did not negotiate a persistent connection.
        closing,
    };

    pub const BodyError = error{
        HttpChunkInvalid,
        HttpChunkTruncated,
        HttpHeadersOversize,
    };

    pub const HeadError = error{
        /// Too many bytes of HTTP headers.
        ///
        /// The HTTP specification suggests to respond with a 431 status code
        /// before closing the connection.
        HttpHeadersOversize,
        /// Partial HTTP request was received but the connection was closed
        /// before fully receiving the headers.
        HttpRequestTruncated,
        /// The client sent 0 bytes of headers before closing the stream. This
        /// happens when a keep-alive connection is finally closed.
        HttpConnectionClosing,
        /// Transitive error occurred reading from `in`.
        ReadFailed,
    };

    pub fn restituteHeadBuffer(reader: *Reader) void {
        reader.in.restitute(reader.head_buffer.len);
        reader.head_buffer.len = 0;
    }

    /// Buffers the entire head into `head_buffer`, invalidating the previous
    /// `head_buffer`, if any.
    pub fn receiveHead(reader: *Reader) HeadError!void {
        reader.trailers = &.{};
        const in = reader.in;
        in.restitute(reader.head_buffer.len);
        reader.head_buffer.len = 0;
        in.rebase();
        var hp: HeadParser = .{};
        var head_end: usize = 0;
        while (true) {
            if (head_end >= in.buffer.len) return error.HttpHeadersOversize;
            in.fillMore() catch |err| switch (err) {
                error.EndOfStream => switch (head_end) {
                    0 => return error.HttpConnectionClosing,
                    else => return error.HttpRequestTruncated,
                },
                error.ReadFailed => return error.ReadFailed,
            };
            head_end += hp.feed(in.bufferContents()[head_end..]);
            if (hp.state == .finished) {
                reader.head_buffer = in.steal(head_end);
                reader.state = .received_head;
                return;
            }
        }
    }

    /// If compressed body has been negotiated this will return compressed bytes.
    ///
    /// Asserts only called once and after `receiveHead`.
    ///
    /// See also:
    /// * `interfaceDecompressing`
    pub fn bodyReader(reader: *Reader, transfer_encoding: TransferEncoding, content_length: ?u64) std.io.Reader {
        assert(reader.state == .received_head);
        return switch (transfer_encoding) {
            .chunked => {
                reader.state = .{ .body_remaining_chunk_len = .head };
                return .{
                    .context = reader,
                    .vtable = &.{
                        .read = &chunkedRead,
                        .readVec = &chunkedReadVec,
                        .discard = &chunkedDiscard,
                    },
                };
            },
            .none => {
                if (content_length) |len| {
                    reader.state = .{ .body_remaining_content_length = len };
                    return .{
                        .context = reader,
                        .vtable = &.{
                            .read = &contentLengthRead,
                            .readVec = &contentLengthReadVec,
                            .discard = &contentLengthDiscard,
                        },
                    };
                } else {
                    reader.state = .body_none;
                    return reader.in.reader();
                }
            },
        };
    }

    /// If compressed body has been negotiated this will return decompressed bytes.
    ///
    /// Asserts only called once and after `receiveHead`.
    ///
    /// See also:
    /// * `interface`
    pub fn bodyReaderDecompressing(
        reader: *Reader,
        transfer_encoding: TransferEncoding,
        content_length: ?u64,
        content_encoding: ContentEncoding,
        decompressor: *Decompressor,
        decompression_buffer: []u8,
    ) std.io.Reader {
        if (transfer_encoding == .none and content_length == null) {
            assert(reader.state == .received_head);
            reader.state = .body_none;
            switch (content_encoding) {
                .identity => {
                    return reader.in.reader();
                },
                .deflate => {
                    decompressor.compression = .{ .deflate = .init(reader.in) };
                    return decompressor.compression.deflate.reader();
                },
                .gzip => {
                    decompressor.compression = .{ .gzip = .init(reader.in) };
                    return decompressor.compression.gzip.reader();
                },
                .zstd => {
                    decompressor.compression = .{ .zstd = .init(reader.in, .{ .verify_checksum = false }) };
                    return decompressor.compression.zstd.reader();
                },
                .compress => unreachable,
            }
        }
        const transfer_reader = bodyReader(reader, transfer_encoding, content_length);
        return decompressor.reader(transfer_reader, decompression_buffer, content_encoding);
    }

    fn contentLengthRead(
        ctx: ?*anyopaque,
        bw: *std.io.BufferedWriter,
        limit: std.io.Limit,
    ) std.io.Reader.StreamError!usize {
        const reader: *Reader = @alignCast(@ptrCast(ctx));
        const remaining_content_length = &reader.state.body_remaining_content_length;
        const remaining = remaining_content_length.*;
        if (remaining == 0) {
            reader.state = .ready;
            return error.EndOfStream;
        }
        const n = try reader.in.read(bw, limit.min(.limited(remaining)));
        remaining_content_length.* = remaining - n;
        return n;
    }

    fn contentLengthReadVec(context: ?*anyopaque, data: []const []u8) std.io.Reader.Error!usize {
        const reader: *Reader = @alignCast(@ptrCast(context));
        const remaining_content_length = &reader.state.body_remaining_content_length;
        const remaining = remaining_content_length.*;
        if (remaining == 0) {
            reader.state = .ready;
            return error.EndOfStream;
        }
        const n = try reader.in.readVecLimit(data, .limited(remaining));
        remaining_content_length.* = remaining - n;
        return n;
    }

    fn contentLengthDiscard(ctx: ?*anyopaque, limit: std.io.Limit) std.io.Reader.Error!usize {
        const reader: *Reader = @alignCast(@ptrCast(ctx));
        const remaining_content_length = &reader.state.body_remaining_content_length;
        const remaining = remaining_content_length.*;
        if (remaining == 0) {
            reader.state = .ready;
            return error.EndOfStream;
        }
        const n = try reader.in.discard(limit.min(.limited(remaining)));
        remaining_content_length.* = remaining - n;
        return n;
    }

    fn chunkedRead(
        ctx: ?*anyopaque,
        bw: *std.io.BufferedWriter,
        limit: std.io.Limit,
    ) std.io.Reader.StreamError!usize {
        const reader: *Reader = @alignCast(@ptrCast(ctx));
        const chunk_len_ptr = switch (reader.state) {
            .ready => return error.EndOfStream,
            .body_remaining_chunk_len => |*x| x,
            else => unreachable,
        };
        return chunkedReadEndless(reader, bw, limit, chunk_len_ptr) catch |err| switch (err) {
            error.ReadFailed => return error.ReadFailed,
            error.WriteFailed => return error.WriteFailed,
            error.EndOfStream => {
                reader.body_err = error.HttpChunkTruncated;
                return error.ReadFailed;
            },
            else => |e| {
                reader.body_err = e;
                return error.ReadFailed;
            },
        };
    }

    fn chunkedReadEndless(
        reader: *Reader,
        bw: *std.io.BufferedWriter,
        limit: std.io.Limit,
        chunk_len_ptr: *RemainingChunkLen,
    ) (BodyError || std.io.Reader.StreamError)!usize {
        const in = reader.in;
        len: switch (chunk_len_ptr.*) {
            .head => {
                var cp: ChunkParser = .init;
                while (true) {
                    const i = cp.feed(in.bufferContents());
                    switch (cp.state) {
                        .invalid => return error.HttpChunkInvalid,
                        .data => {
                            in.toss(i);
                            break;
                        },
                        else => {
                            in.toss(i);
                            try in.fillMore();
                            continue;
                        },
                    }
                }
                if (cp.chunk_len == 0) return parseTrailers(reader, 0);
                const n = try in.read(bw, limit.min(.limited(cp.chunk_len)));
                chunk_len_ptr.* = .init(cp.chunk_len + 2 - n);
                return n;
            },
            .n => {
                if ((try in.peekByte()) != '\n') return error.HttpChunkInvalid;
                in.toss(1);
                continue :len .head;
            },
            .rn => {
                const rn = try in.peekArray(2);
                if (rn[0] != '\r' or rn[1] != '\n') return error.HttpChunkInvalid;
                in.toss(2);
                continue :len .head;
            },
            else => |remaining_chunk_len| {
                const n = try in.read(bw, limit.min(.limited(@intFromEnum(remaining_chunk_len) - 2)));
                chunk_len_ptr.* = .init(@intFromEnum(remaining_chunk_len) - n);
                return n;
            },
        }
    }

    fn chunkedReadVec(ctx: ?*anyopaque, data: []const []u8) std.io.Reader.Error!usize {
        const reader: *Reader = @alignCast(@ptrCast(ctx));
        const chunk_len_ptr = switch (reader.state) {
            .ready => return error.EndOfStream,
            .body_remaining_chunk_len => |*x| x,
            else => unreachable,
        };
        return chunkedReadVecEndless(reader, data, chunk_len_ptr) catch |err| switch (err) {
            error.ReadFailed => return error.ReadFailed,
            error.EndOfStream => {
                reader.body_err = error.HttpChunkTruncated;
                return error.ReadFailed;
            },
            else => |e| {
                reader.body_err = e;
                return error.ReadFailed;
            },
        };
    }

    fn chunkedReadVecEndless(
        reader: *Reader,
        data: []const []u8,
        chunk_len_ptr: *RemainingChunkLen,
    ) (BodyError || std.io.Reader.Error)!usize {
        const in = reader.in;
        var already_requested_more = false;
        var amt_read: usize = 0;
        data: for (data) |d| {
            var d_i: usize = 0;
            len: switch (chunk_len_ptr.*) {
                .head => {
                    var cp: ChunkParser = .init;
                    while (true) {
                        const i = cp.feed(in.bufferContents());
                        switch (cp.state) {
                            .invalid => return error.HttpChunkInvalid,
                            .data => {
                                in.toss(i);
                                break;
                            },
                            else => {
                                in.toss(i);
                                already_requested_more = true;
                                try in.fillMore();
                                continue;
                            },
                        }
                    }
                    if (cp.chunk_len == 0) return parseTrailers(reader, amt_read);
                    continue :len .init(cp.chunk_len + 2);
                },
                .n => {
                    if (in.bufferContents().len < 1) already_requested_more = true;
                    if ((try in.takeByte()) != '\n') return error.HttpChunkInvalid;
                    continue :len .head;
                },
                .rn => {
                    if (in.bufferContents().len < 2) already_requested_more = true;
                    const rn = try in.takeArray(2);
                    if (rn[0] != '\r' or rn[1] != '\n') return error.HttpChunkInvalid;
                    continue :len .head;
                },
                else => |remaining_chunk_len| {
                    const available_buffer = in.bufferContents();
                    const copy_len = @min(available_buffer.len, d.len - d_i, remaining_chunk_len.int() - 2);
                    @memcpy(d[d_i..][0..copy_len], available_buffer[0..copy_len]);
                    d_i += copy_len;
                    amt_read += copy_len;
                    in.toss(copy_len);
                    const next_chunk_len: RemainingChunkLen = .init(remaining_chunk_len.int() - copy_len);
                    if (d.len - d_i == 0) {
                        chunk_len_ptr.* = next_chunk_len;
                        continue :data;
                    }
                    if (available_buffer.len - copy_len == 0) {
                        if (already_requested_more) {
                            chunk_len_ptr.* = next_chunk_len;
                            return amt_read;
                        }
                        already_requested_more = true;
                        try in.fillMore();
                    }
                    continue :len next_chunk_len;
                },
            }
        }
        return amt_read;
    }

    fn chunkedDiscard(ctx: ?*anyopaque, limit: std.io.Limit) std.io.Reader.Error!usize {
        const reader: *Reader = @alignCast(@ptrCast(ctx));
        const chunk_len_ptr = switch (reader.state) {
            .ready => return error.EndOfStream,
            .body_remaining_chunk_len => |*x| x,
            else => unreachable,
        };
        return chunkedDiscardEndless(reader, limit, chunk_len_ptr) catch |err| switch (err) {
            error.ReadFailed => return error.ReadFailed,
            error.EndOfStream => {
                reader.body_err = error.HttpChunkTruncated;
                return error.ReadFailed;
            },
            else => |e| {
                reader.body_err = e;
                return error.ReadFailed;
            },
        };
    }

    fn chunkedDiscardEndless(
        reader: *Reader,
        limit: std.io.Limit,
        chunk_len_ptr: *RemainingChunkLen,
    ) (BodyError || std.io.Reader.Error)!usize {
        const in = reader.in;
        len: switch (chunk_len_ptr.*) {
            .head => {
                var cp: ChunkParser = .init;
                while (true) {
                    const i = cp.feed(in.bufferContents());
                    switch (cp.state) {
                        .invalid => return error.HttpChunkInvalid,
                        .data => {
                            in.toss(i);
                            break;
                        },
                        else => {
                            in.toss(i);
                            try in.fillMore();
                            continue;
                        },
                    }
                }
                if (cp.chunk_len == 0) return parseTrailers(reader, 0);
                const n = try in.discard(limit.min(.limited(cp.chunk_len)));
                chunk_len_ptr.* = .init(cp.chunk_len + 2 - n);
                return n;
            },
            .n => {
                if ((try in.peekByte()) != '\n') return error.HttpChunkInvalid;
                in.toss(1);
                continue :len .head;
            },
            .rn => {
                const rn = try in.peekArray(2);
                if (rn[0] != '\r' or rn[1] != '\n') return error.HttpChunkInvalid;
                in.toss(2);
                continue :len .head;
            },
            else => |remaining_chunk_len| {
                const n = try in.discard(limit.min(.limited(remaining_chunk_len.int() - 2)));
                chunk_len_ptr.* = .init(remaining_chunk_len.int() - n);
                return n;
            },
        }
    }

    /// Called when next bytes in the stream are trailers, or "\r\n" to indicate
    /// end of chunked body.
    fn parseTrailers(reader: *Reader, amt_read: usize) (BodyError || std.io.Reader.Error)!usize {
        const in = reader.in;
        const rn = try in.peekArray(2);
        if (rn[0] == '\r' and rn[1] == '\n') {
            in.toss(2);
            reader.state = .ready;
            assert(reader.trailers.len == 0);
            return amt_read;
        }
        var hp: HeadParser = .{ .state = .seen_rn };
        var trailers_len: usize = 2;
        while (true) {
            if (trailers_len >= in.buffer.len) return error.HttpHeadersOversize;
            try in.fill(trailers_len + 1);
            trailers_len += hp.feed(in.bufferContents()[trailers_len..]);
            if (hp.state == .finished) {
                reader.state = .ready;
                reader.trailers = in.bufferContents()[0..trailers_len];
                in.toss(trailers_len);
                return amt_read;
            }
        }
    }
};

pub const Decompressor = struct {
    compression: Compression,
    buffered_reader: std.io.BufferedReader,

    pub const Compression = union(enum) {
        deflate: std.compress.flate.Decompressor,
        gzip: std.compress.flate.Decompressor,
        zstd: std.compress.zstd.Decompress,
        none: void,
    };

    pub fn reader(
        decompressor: *Decompressor,
        transfer_reader: std.io.Reader,
        buffer: []u8,
        content_encoding: ContentEncoding,
    ) std.io.Reader {
        switch (content_encoding) {
            .identity => {
                decompressor.compression = .none;
                return transfer_reader;
            },
            .deflate => {
                decompressor.buffered_reader = transfer_reader.buffered(buffer);
                decompressor.compression = .{ .deflate = .init(&decompressor.buffered_reader) };
                return decompressor.compression.deflate.reader();
            },
            .gzip => {
                decompressor.buffered_reader = transfer_reader.buffered(buffer);
                decompressor.compression = .{ .gzip = .init(&decompressor.buffered_reader) };
                return decompressor.compression.gzip.reader();
            },
            .zstd => {
                decompressor.buffered_reader = transfer_reader.buffered(buffer);
                decompressor.compression = .{ .zstd = .init(&decompressor.buffered_reader, .{}) };
                return decompressor.compression.gzip.reader();
            },
            .compress => unreachable,
        }
    }
};

/// Request or response body.
pub const BodyWriter = struct {
    /// Until the lifetime of `BodyWriter` ends, it is illegal to modify the
    /// state of this other than via methods of `BodyWriter`.
    http_protocol_output: *std.io.BufferedWriter,
    state: State,
    elide: bool,
    err: Error!void = {},

    pub const Error = error{
        /// Attempted to write a file to the stream, an expensive operation
        /// that should be avoided when `elide` is true.
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

    pub const State = union(enum) {
        /// End of connection signals the end of the stream.
        none,
        /// As a debugging utility, counts down to zero as bytes are written.
        content_length: u64,
        /// Each chunk is wrapped in a header and trailer.
        chunked: Chunked,
        /// Cleanly finished stream; connection can be reused.
        end,

        pub const Chunked = union(enum) {
            /// Index to the start of the hex-encoded chunk length in the chunk
            /// header within the buffer of `BodyWriter.http_protocol_output`.
            /// Buffered chunk data starts here plus length of `chunk_header_template`.
            offset: usize,
            /// We are in the middle of a chunk and this is how many bytes are
            /// left until the next header. This includes +2 for "\r"\n", and
            /// is zero for the beginning of the stream.
            chunk_len: usize,

            pub const init: Chunked = .{ .chunk_len = 0 };
        };
    };

    /// Sends all buffered data across `BodyWriter.http_protocol_output`.
    pub fn flush(w: *BodyWriter) WriteError!void {
        const out = w.http_protocol_output;
        switch (w.state) {
            .end, .none, .content_length => return out.flush(),
            .chunked => |*chunked| switch (chunked.*) {
                .offset => |offset| {
                    const chunk_len = out.end - offset - chunk_header_template.len;
                    if (chunk_len > 0) {
                        writeHex(out.buffer[offset..][0..chunk_len_digits], chunk_len);
                        chunked.* = .{ .chunk_len = 2 };
                    } else {
                        out.end = offset;
                        chunked.* = .{ .chunk_len = 0 };
                    }
                    try out.flush();
                },
                .chunk_len => return out.flush(),
            },
        }
    }

    /// When using content-length, asserts that the amount of data sent matches
    /// the value sent in the header, then flushes.
    ///
    /// When using transfer-encoding: chunked, writes the end-of-stream message
    /// with empty trailers, then flushes the stream to the system. Asserts any
    /// started chunk has been completely finished.
    ///
    /// Respects the value of `elide` to omit all data after the headers.
    ///
    /// See also:
    /// * `endUnflushed`
    /// * `endChunked`
    pub fn end(w: *BodyWriter) WriteError!void {
        try endUnflushed(w);
        try w.http_protocol_output.flush();
    }

    /// When using content-length, asserts that the amount of data sent matches
    /// the value sent in the header.
    ///
    /// Otherwise, transfer-encoding: chunked is being used, and it writes the
    /// end-of-stream message with empty trailers.
    ///
    /// Respects the value of `elide` to omit all data after the headers.
    ///
    /// See also:
    /// * `end`
    /// * `endChunked`
    pub fn endUnflushed(w: *BodyWriter) WriteError!void {
        switch (w.state) {
            .end => unreachable,
            .content_length => |len| {
                assert(len == 0); // Trips when end() called before all bytes written.
                w.state = .end;
            },
            .none => {},
            .chunked => return endChunkedUnflushed(w, .{}),
        }
    }

    pub const EndChunkedOptions = struct {
        trailers: []const Header = &.{},
    };

    /// Writes the end-of-stream message and any optional trailers, flushing
    /// the underlying stream.
    ///
    /// Asserts that the BodyWriter is using transfer-encoding: chunked.
    ///
    /// Respects the value of `elide` to omit all data after the headers.
    ///
    /// See also:
    /// * `endChunkedUnflushed`
    /// * `end`
    pub fn endChunked(w: *BodyWriter, options: EndChunkedOptions) WriteError!void {
        try endChunkedUnflushed(w, options);
        try w.http_protocol_output.flush();
    }

    /// Writes the end-of-stream message and any optional trailers.
    ///
    /// Does not flush.
    ///
    /// Asserts that the BodyWriter is using transfer-encoding: chunked.
    ///
    /// Respects the value of `elide` to omit all data after the headers.
    ///
    /// See also:
    /// * `endChunked`
    /// * `endUnflushed`
    /// * `end`
    pub fn endChunkedUnflushed(w: *BodyWriter, options: EndChunkedOptions) WriteError!void {
        const chunked = &w.state.chunked;
        if (w.elide) {
            w.state = .end;
            return;
        }
        const bw = w.http_protocol_output;
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
        try bw.writeAll("0\r\n");
        for (options.trailers) |trailer| {
            try bw.writeAll(trailer.name);
            try bw.writeAll(": ");
            try bw.writeAll(trailer.value);
            try bw.writeAll("\r\n");
        }
        try bw.writeAll("\r\n");
        w.state = .end;
    }

    fn contentLengthWriteSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) WriteError!usize {
        const w: *BodyWriter = @alignCast(@ptrCast(context));
        const n = if (w.elide) countSplat(data, splat) else try w.http_protocol_output.writeSplat(data, splat);
        w.state.content_length -= n;
        return n;
    }

    fn noneWriteSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) WriteError!usize {
        const w: *BodyWriter = @alignCast(@ptrCast(context));
        if (w.elide) return countSplat(data, splat);
        return w.http_protocol_output.writeSplat(data, splat);
    }

    fn countSplat(data: []const []const u8, splat: usize) usize {
        if (data.len == 0) return 0;
        var total: usize = 0;
        for (data[0 .. data.len - 1]) |buf| total += buf.len;
        total += data[data.len - 1].len * splat;
        return total;
    }

    fn elideWriteFile(
        w: *BodyWriter,
        offset: std.io.Writer.Offset,
        limit: std.io.Writer.Limit,
        headers_and_trailers: []const []const u8,
    ) WriteError!usize {
        if (offset != .none) {
            if (countWriteFile(limit, headers_and_trailers)) |n| {
                return n;
            }
        }
        w.err = error.UnableToElideBody;
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
        const w: *BodyWriter = @alignCast(@ptrCast(context));
        if (w.elide) return elideWriteFile(w, offset, limit, headers_and_trailers);
        return w.http_protocol_output.writeFile(file, offset, limit, headers_and_trailers, headers_len);
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
        const w: *BodyWriter = @alignCast(@ptrCast(context));
        if (w.elide) return elideWriteFile(w, offset, limit, headers_and_trailers);
        const n = try w.http_protocol_output.writeFile(file, offset, limit, headers_and_trailers, headers_len);
        w.state.content_length -= n;
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
        const w: *BodyWriter = @alignCast(@ptrCast(context));
        if (w.elide) return elideWriteFile(w, offset, limit, headers_and_trailers);
        const data_len = countWriteFile(limit, headers_and_trailers) orelse @panic("TODO");
        const bw = w.http_protocol_output;
        const chunked = &w.state.chunked;
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
                    const off = bw.end;
                    const header_buf = try bw.writableArray(chunk_header_template.len);
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
        const w: *BodyWriter = @alignCast(@ptrCast(context));
        const data_len = countSplat(data, splat);
        if (w.elide) return data_len;

        const bw = w.http_protocol_output;
        const chunked = &w.state.chunked;

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
                    const offset = bw.end;
                    const header_buf = try bw.writableArray(chunk_header_template.len);
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

    pub fn writer(w: *BodyWriter) std.io.Writer {
        return .{
            .context = w,
            .vtable = switch (w.state) {
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
                .end => unreachable,
            },
        };
    }
};

test {
    _ = Server;
    _ = Status;
    _ = Method;
    _ = ChunkParser;
    _ = HeadParser;

    if (builtin.os.tag != .wasi) {
        _ = Client;
        _ = @import("http/test.zig");
    }
}
