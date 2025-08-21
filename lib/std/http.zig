const builtin = @import("builtin");
const std = @import("std.zig");
const assert = std.debug.assert;
const Writer = std.Io.Writer;
const File = std.fs.File;

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
pub const Method = enum {
    GET,
    HEAD,
    POST,
    PUT,
    DELETE,
    CONNECT,
    OPTIONS,
    TRACE,
    PATCH,

    /// Returns true if a request of this method is allowed to have a body
    /// Actual behavior from servers may vary and should still be checked
    pub fn requestHasBody(m: Method) bool {
        return switch (m) {
            .POST, .PUT, .PATCH => true,
            .GET, .HEAD, .DELETE, .CONNECT, .OPTIONS, .TRACE => false,
        };
    }

    /// Returns true if a response to this method is allowed to have a body
    /// Actual behavior from clients may vary and should still be checked
    pub fn responseHasBody(m: Method) bool {
        return switch (m) {
            .GET, .POST, .DELETE, .CONNECT, .OPTIONS, .PATCH => true,
            .HEAD, .PUT, .TRACE => false,
        };
    }

    /// An HTTP method is safe if it doesn't alter the state of the server.
    ///
    /// https://developer.mozilla.org/en-US/docs/Glossary/Safe/HTTP
    ///
    /// https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.1
    pub fn safe(m: Method) bool {
        return switch (m) {
            .GET, .HEAD, .OPTIONS, .TRACE => true,
            .POST, .PUT, .DELETE, .CONNECT, .PATCH => false,
        };
    }

    /// An HTTP method is idempotent if an identical request can be made once
    /// or several times in a row with the same effect while leaving the server
    /// in the same state.
    ///
    /// https://developer.mozilla.org/en-US/docs/Glossary/Idempotent
    ///
    /// https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.2
    pub fn idempotent(m: Method) bool {
        return switch (m) {
            .GET, .HEAD, .PUT, .DELETE, .OPTIONS, .TRACE => true,
            .CONNECT, .POST, .PATCH => false,
        };
    }

    /// A cacheable response can be stored to be retrieved and used later,
    /// saving a new request to the server.
    ///
    /// https://developer.mozilla.org/en-US/docs/Glossary/cacheable
    ///
    /// https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.3
    pub fn cacheable(m: Method) bool {
        return switch (m) {
            .GET, .HEAD => true,
            .POST, .PUT, .DELETE, .CONNECT, .OPTIONS, .TRACE, .PATCH => false,
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

    pub fn minBufferCapacity(ce: ContentEncoding) usize {
        return switch (ce) {
            .zstd => std.compress.zstd.default_window_len,
            .gzip, .deflate => std.compress.flate.max_window_len,
            .compress, .identity => 0,
        };
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
    in: *std.Io.Reader,
    /// This is preallocated memory that might be used by `bodyReader`. That
    /// function might return a pointer to this field, or a different
    /// `*std.Io.Reader`. Advisable to not access this field directly.
    interface: std.Io.Reader,
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
    max_head_len: usize,

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

    /// Buffers the entire head inside `in`.
    ///
    /// The resulting memory is invalidated by any subsequent consumption of
    /// the input stream.
    pub fn receiveHead(reader: *Reader) HeadError![]const u8 {
        reader.trailers = &.{};
        const in = reader.in;
        const max_head_len = reader.max_head_len;
        var hp: HeadParser = .{};
        var head_len: usize = 0;
        while (true) {
            if (head_len >= max_head_len) return error.HttpHeadersOversize;
            const remaining = in.buffered()[head_len..];
            if (remaining.len == 0) {
                in.fillMore() catch |err| switch (err) {
                    error.EndOfStream => switch (head_len) {
                        0 => return error.HttpConnectionClosing,
                        else => return error.HttpRequestTruncated,
                    },
                    error.ReadFailed => return error.ReadFailed,
                };
                continue;
            }
            head_len += hp.feed(remaining);
            if (hp.state == .finished) {
                reader.state = .received_head;
                const head_buffer = in.buffered()[0..head_len];
                in.toss(head_len);
                return head_buffer;
            }
        }
    }

    /// If compressed body has been negotiated this will return compressed bytes.
    ///
    /// Asserts only called once and after `receiveHead`.
    ///
    /// See also:
    /// * `interfaceDecompressing`
    pub fn bodyReader(
        reader: *Reader,
        transfer_buffer: []u8,
        transfer_encoding: TransferEncoding,
        content_length: ?u64,
    ) *std.Io.Reader {
        assert(reader.state == .received_head);
        switch (transfer_encoding) {
            .chunked => {
                reader.state = .{ .body_remaining_chunk_len = .head };
                reader.interface = .{
                    .buffer = transfer_buffer,
                    .seek = 0,
                    .end = 0,
                    .vtable = &.{
                        .stream = chunkedStream,
                        .discard = chunkedDiscard,
                    },
                };
                return &reader.interface;
            },
            .none => {
                if (content_length) |len| {
                    reader.state = .{ .body_remaining_content_length = len };
                    reader.interface = .{
                        .buffer = transfer_buffer,
                        .seek = 0,
                        .end = 0,
                        .vtable = &.{
                            .stream = contentLengthStream,
                            .discard = contentLengthDiscard,
                        },
                    };
                    return &reader.interface;
                } else {
                    reader.state = .body_none;
                    return reader.in;
                }
            },
        }
    }

    /// If compressed body has been negotiated this will return decompressed bytes.
    ///
    /// Asserts only called once and after `receiveHead`.
    ///
    /// See also:
    /// * `interface`
    pub fn bodyReaderDecompressing(
        reader: *Reader,
        transfer_buffer: []u8,
        transfer_encoding: TransferEncoding,
        content_length: ?u64,
        content_encoding: ContentEncoding,
        decompress: *Decompress,
        decompress_buffer: []u8,
    ) *std.Io.Reader {
        if (transfer_encoding == .none and content_length == null) {
            assert(reader.state == .received_head);
            reader.state = .body_none;
            switch (content_encoding) {
                .identity => {
                    return reader.in;
                },
                .deflate => {
                    decompress.* = .{ .flate = .init(reader.in, .zlib, decompress_buffer) };
                    return &decompress.flate.reader;
                },
                .gzip => {
                    decompress.* = .{ .flate = .init(reader.in, .gzip, decompress_buffer) };
                    return &decompress.flate.reader;
                },
                .zstd => {
                    decompress.* = .{ .zstd = .init(reader.in, decompress_buffer, .{ .verify_checksum = false }) };
                    return &decompress.zstd.reader;
                },
                .compress => unreachable,
            }
        }
        const transfer_reader = bodyReader(reader, transfer_buffer, transfer_encoding, content_length);
        return decompress.init(transfer_reader, decompress_buffer, content_encoding);
    }

    fn contentLengthStream(
        io_r: *std.Io.Reader,
        w: *Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const reader: *Reader = @alignCast(@fieldParentPtr("interface", io_r));
        const remaining_content_length = &reader.state.body_remaining_content_length;
        const remaining = remaining_content_length.*;
        if (remaining == 0) {
            reader.state = .ready;
            return error.EndOfStream;
        }
        const n = try reader.in.stream(w, limit.min(.limited64(remaining)));
        remaining_content_length.* = remaining - n;
        return n;
    }

    fn contentLengthDiscard(io_r: *std.Io.Reader, limit: std.Io.Limit) std.Io.Reader.Error!usize {
        const reader: *Reader = @alignCast(@fieldParentPtr("interface", io_r));
        const remaining_content_length = &reader.state.body_remaining_content_length;
        const remaining = remaining_content_length.*;
        if (remaining == 0) {
            reader.state = .ready;
            return error.EndOfStream;
        }
        const n = try reader.in.discard(limit.min(.limited64(remaining)));
        remaining_content_length.* = remaining - n;
        return n;
    }

    fn chunkedStream(io_r: *std.Io.Reader, w: *Writer, limit: std.Io.Limit) std.Io.Reader.StreamError!usize {
        const reader: *Reader = @alignCast(@fieldParentPtr("interface", io_r));
        const chunk_len_ptr = switch (reader.state) {
            .ready => return error.EndOfStream,
            .body_remaining_chunk_len => |*x| x,
            else => unreachable,
        };
        return chunkedReadEndless(reader, w, limit, chunk_len_ptr) catch |err| switch (err) {
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
        w: *Writer,
        limit: std.Io.Limit,
        chunk_len_ptr: *RemainingChunkLen,
    ) (BodyError || std.Io.Reader.StreamError)!usize {
        const in = reader.in;
        len: switch (chunk_len_ptr.*) {
            .head => {
                var cp: ChunkParser = .init;
                while (true) {
                    const i = cp.feed(in.buffered());
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
                const n = try in.stream(w, limit.min(.limited64(cp.chunk_len)));
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
                const n = try in.stream(w, limit.min(.limited64(@intFromEnum(remaining_chunk_len) - 2)));
                chunk_len_ptr.* = .init(@intFromEnum(remaining_chunk_len) - n);
                return n;
            },
        }
    }

    fn chunkedDiscard(io_r: *std.Io.Reader, limit: std.Io.Limit) std.Io.Reader.Error!usize {
        const reader: *Reader = @alignCast(@fieldParentPtr("interface", io_r));
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
        limit: std.Io.Limit,
        chunk_len_ptr: *RemainingChunkLen,
    ) (BodyError || std.Io.Reader.Error)!usize {
        const in = reader.in;
        len: switch (chunk_len_ptr.*) {
            .head => {
                var cp: ChunkParser = .init;
                while (true) {
                    const i = cp.feed(in.buffered());
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
                const n = try in.discard(limit.min(.limited64(cp.chunk_len)));
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
                const n = try in.discard(limit.min(.limited64(remaining_chunk_len.int() - 2)));
                chunk_len_ptr.* = .init(remaining_chunk_len.int() - n);
                return n;
            },
        }
    }

    /// Called when next bytes in the stream are trailers, or "\r\n" to indicate
    /// end of chunked body.
    fn parseTrailers(reader: *Reader, amt_read: usize) (BodyError || std.Io.Reader.Error)!usize {
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
            if (in.buffer.len - trailers_len == 0) return error.HttpHeadersOversize;
            const remaining = in.buffered()[trailers_len..];
            if (remaining.len == 0) {
                try in.fillMore();
                continue;
            }
            trailers_len += hp.feed(remaining);
            if (hp.state == .finished) {
                reader.state = .ready;
                reader.trailers = in.buffered()[0..trailers_len];
                in.toss(trailers_len);
                return amt_read;
            }
        }
    }
};

pub const Decompress = union(enum) {
    flate: std.compress.flate.Decompress,
    zstd: std.compress.zstd.Decompress,
    none: *std.Io.Reader,

    pub fn init(
        decompress: *Decompress,
        transfer_reader: *std.Io.Reader,
        buffer: []u8,
        content_encoding: ContentEncoding,
    ) *std.Io.Reader {
        switch (content_encoding) {
            .identity => {
                decompress.* = .{ .none = transfer_reader };
                return transfer_reader;
            },
            .deflate => {
                decompress.* = .{ .flate = .init(transfer_reader, .zlib, buffer) };
                return &decompress.flate.reader;
            },
            .gzip => {
                decompress.* = .{ .flate = .init(transfer_reader, .gzip, buffer) };
                return &decompress.flate.reader;
            },
            .zstd => {
                decompress.* = .{ .zstd = .init(transfer_reader, buffer, .{ .verify_checksum = false }) };
                return &decompress.zstd.reader;
            },
            .compress => unreachable,
        }
    }
};

/// Request or response body.
pub const BodyWriter = struct {
    /// Until the lifetime of `BodyWriter` ends, it is illegal to modify the
    /// state of this other than via methods of `BodyWriter`.
    http_protocol_output: *Writer,
    state: State,
    writer: Writer,

    pub const Error = Writer.Error;

    /// How many zeroes to reserve for hex-encoded chunk length.
    const chunk_len_digits = 8;
    const max_chunk_len: usize = std.math.pow(u64, 16, chunk_len_digits) - 1;
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
        /// This length is the the number of bytes to be written before the
        /// next header. This includes +2 for the `\r\n` trailer and is zero
        /// for the beginning of the stream.
        chunk_len: usize,
        /// Cleanly finished stream; connection can be reused.
        end,

        pub const init_chunked: State = .{ .chunk_len = 0 };
    };

    pub fn isEliding(w: *const BodyWriter) bool {
        return w.writer.vtable.drain == elidingDrain;
    }

    /// Sends all buffered data across `BodyWriter.http_protocol_output`.
    pub fn flush(w: *BodyWriter) Error!void {
        const out = w.http_protocol_output;
        switch (w.state) {
            .end, .none, .content_length, .chunk_len => return out.flush(),
        }
    }

    /// When using content-length, asserts that the amount of data sent matches
    /// the value sent in the header, then flushes `http_protocol_output`.
    ///
    /// When using transfer-encoding: chunked, writes the end-of-stream message
    /// with empty trailers, then flushes the stream to the system. Asserts any
    /// started chunk has been completely finished.
    ///
    /// Respects the value of `isEliding` to omit all data after the headers.
    ///
    /// See also:
    /// * `endUnflushed`
    /// * `endChunked`
    pub fn end(w: *BodyWriter) Error!void {
        try endUnflushed(w);
        try w.http_protocol_output.flush();
    }

    /// When using content-length, asserts that the amount of data sent matches
    /// the value sent in the header.
    ///
    /// Otherwise, transfer-encoding: chunked is being used, and it writes the
    /// end-of-stream message with empty trailers.
    ///
    /// Respects the value of `isEliding` to omit all data after the headers.
    ///
    /// Does not flush `http_protocol_output`, but does flush `writer`.
    ///
    /// See also:
    /// * `end`
    /// * `endChunked`
    pub fn endUnflushed(w: *BodyWriter) Error!void {
        try w.writer.flush();
        switch (w.state) {
            .end => unreachable,
            .content_length => |len| {
                assert(len == 0); // Trips when end() called before all bytes written.
                w.state = .end;
            },
            .none => {},
            .chunk_len => return endChunkedUnflushed(w, .{}),
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
    /// Respects the value of `isEliding` to omit all data after the headers.
    ///
    /// See also:
    /// * `endChunkedUnflushed`
    /// * `end`
    pub fn endChunked(w: *BodyWriter, options: EndChunkedOptions) Error!void {
        try endChunkedUnflushed(w, options);
        try w.http_protocol_output.flush();
    }

    /// Writes the end-of-stream message and any optional trailers.
    ///
    /// Does not flush.
    ///
    /// Asserts that the BodyWriter is using transfer-encoding: chunked.
    ///
    /// Respects the value of `isEliding` to omit all data after the headers.
    ///
    /// See also:
    /// * `endChunked`
    /// * `endUnflushed`
    /// * `end`
    pub fn endChunkedUnflushed(w: *BodyWriter, options: EndChunkedOptions) Error!void {
        if (w.isEliding()) {
            w.state = .end;
            return;
        }
        const bw = w.http_protocol_output;
        switch (w.state.chunk_len) {
            0 => {},
            1 => unreachable, // Wrote more data than specified in chunk header.
            2 => try bw.writeAll("\r\n"),
            else => unreachable, // An earlier write call indicated more data would follow.
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

    pub fn contentLengthDrain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
        const bw: *BodyWriter = @alignCast(@fieldParentPtr("writer", w));
        assert(!bw.isEliding());
        const out = bw.http_protocol_output;
        const n = try out.writeSplatHeader(w.buffered(), data, splat);
        bw.state.content_length -= n;
        return w.consume(n);
    }

    pub fn noneDrain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
        const bw: *BodyWriter = @alignCast(@fieldParentPtr("writer", w));
        assert(!bw.isEliding());
        const out = bw.http_protocol_output;
        const n = try out.writeSplatHeader(w.buffered(), data, splat);
        return w.consume(n);
    }

    pub fn elidingDrain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
        const bw: *BodyWriter = @alignCast(@fieldParentPtr("writer", w));
        const slice = data[0 .. data.len - 1];
        const pattern = data[slice.len];
        var written: usize = pattern.len * splat;
        for (slice) |bytes| written += bytes.len;
        switch (bw.state) {
            .content_length => |*len| len.* -= written + w.end,
            else => {},
        }
        w.end = 0;
        return written;
    }

    pub fn elidingSendFile(w: *Writer, file_reader: *File.Reader, limit: std.Io.Limit) Writer.FileError!usize {
        const bw: *BodyWriter = @alignCast(@fieldParentPtr("writer", w));
        if (File.Handle == void) return error.Unimplemented;
        if (builtin.zig_backend == .stage2_aarch64) return error.Unimplemented;
        switch (bw.state) {
            .content_length => |*len| len.* -= w.end,
            else => {},
        }
        w.end = 0;
        if (limit == .nothing) return 0;
        if (file_reader.getSize()) |size| {
            const n = limit.minInt64(size - file_reader.pos);
            if (n == 0) return error.EndOfStream;
            file_reader.seekBy(@intCast(n)) catch return error.Unimplemented;
            switch (bw.state) {
                .content_length => |*len| len.* -= n,
                else => {},
            }
            return n;
        } else |_| {
            // Error is observable on `file_reader` instance, and it is better to
            // treat the file as a pipe.
            return error.Unimplemented;
        }
    }

    /// Returns `null` if size cannot be computed without making any syscalls.
    pub fn noneSendFile(w: *Writer, file_reader: *File.Reader, limit: std.Io.Limit) Writer.FileError!usize {
        const bw: *BodyWriter = @alignCast(@fieldParentPtr("writer", w));
        assert(!bw.isEliding());
        const out = bw.http_protocol_output;
        const n = try out.sendFileHeader(w.buffered(), file_reader, limit);
        return w.consume(n);
    }

    pub fn contentLengthSendFile(w: *Writer, file_reader: *File.Reader, limit: std.Io.Limit) Writer.FileError!usize {
        const bw: *BodyWriter = @alignCast(@fieldParentPtr("writer", w));
        assert(!bw.isEliding());
        const out = bw.http_protocol_output;
        const n = try out.sendFileHeader(w.buffered(), file_reader, limit);
        bw.state.content_length -= n;
        return w.consume(n);
    }

    pub fn chunkedSendFile(w: *Writer, file_reader: *File.Reader, limit: std.Io.Limit) Writer.FileError!usize {
        const bw: *BodyWriter = @alignCast(@fieldParentPtr("writer", w));
        assert(!bw.isEliding());
        const data_len = Writer.countSendFileLowerBound(w.end, file_reader, limit) orelse {
            // If the file size is unknown, we cannot lower to a `sendFile` since we would
            // have to flush the chunk header before knowing the chunk length.
            return error.Unimplemented;
        };
        const out = bw.http_protocol_output;
        l: switch (bw.state.chunk_len) {
            0 => {
                const header_buf = try out.writableArray(chunk_header_template.len);
                @memcpy(header_buf, chunk_header_template);
                writeHex(header_buf[0..chunk_len_digits], data_len);
                bw.state.chunk_len = data_len + 2;
                continue :l bw.state.chunk_len;
            },
            1 => unreachable, // Wrote more data than specified in chunk header.
            2 => {
                try out.writeAll("\r\n");
                bw.state.chunk_len = 0;
                assert(file_reader.atEnd());
                return error.EndOfStream;
            },
            else => {
                const chunk_limit: std.Io.Limit = .limited(bw.state.chunk_len - 2);
                const n = if (chunk_limit.subtract(w.buffered().len)) |sendfile_limit|
                    try out.sendFileHeader(w.buffered(), file_reader, sendfile_limit.min(limit))
                else
                    try out.write(chunk_limit.slice(w.buffered()));
                bw.state.chunk_len -= n;
                const ret = w.consume(n);
                return ret;
            },
        }
    }

    pub fn chunkedDrain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
        const bw: *BodyWriter = @alignCast(@fieldParentPtr("writer", w));
        assert(!bw.isEliding());
        const out = bw.http_protocol_output;
        const data_len = w.end + Writer.countSplat(data, splat);
        l: switch (bw.state.chunk_len) {
            0 => {
                const header_buf = try out.writableArray(chunk_header_template.len);
                @memcpy(header_buf, chunk_header_template);
                writeHex(header_buf[0..chunk_len_digits], data_len);
                bw.state.chunk_len = data_len + 2;
                continue :l bw.state.chunk_len;
            },
            1 => unreachable, // Wrote more data than specified in chunk header.
            2 => {
                try out.writeAll("\r\n");
                bw.state.chunk_len = 0;
                continue :l 0;
            },
            else => {
                const n = try out.writeSplatHeaderLimit(w.buffered(), data, splat, .limited(bw.state.chunk_len - 2));
                bw.state.chunk_len -= n;
                return w.consume(n);
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
