const std = @import("std");
const http = std.http;
const mem = std.mem;
const testing = std.testing;
const assert = std.debug.assert;

const protocol = @import("../protocol.zig");
const Client = @import("../Client.zig");
const Response = @This();

headers: Headers,
state: State,
header_bytes_owned: bool,
/// This could either be a fixed buffer provided by the API user or it
/// could be our own array list.
header_bytes: std.ArrayListUnmanaged(u8),
max_header_bytes: usize,
next_chunk_length: u64,
done: bool = false,

compression: union(enum) {
    deflate: Client.DeflateDecompressor,
    gzip: Client.GzipDecompressor,
    zstd: Client.ZstdDecompressor,
    none: void,
} = .none,

pub const Headers = struct {
    status: http.Status,
    version: http.Version,
    location: ?[]const u8 = null,
    content_length: ?u64 = null,
    transfer_encoding: ?http.TransferEncoding = null,
    transfer_compression: ?http.ContentEncoding = null,
    connection: http.Connection = .close,
    upgrade: ?[]const u8 = null,

    number_of_headers: usize = 0,

    pub fn parse(bytes: []const u8) !Headers {
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

        var headers: Headers = .{
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
                // Transfer-Encoding: second, first
                // Transfer-Encoding: deflate, chunked
                var iter = std.mem.splitBackwards(u8, header_value, ",");

                if (iter.next()) |first| {
                    const trimmed = std.mem.trim(u8, first, " ");

                    if (std.meta.stringToEnum(http.TransferEncoding, trimmed)) |te| {
                        if (headers.transfer_encoding != null) return error.HttpHeadersInvalid;
                        headers.transfer_encoding = te;
                    } else if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                        if (headers.transfer_compression != null) return error.HttpHeadersInvalid;
                        headers.transfer_compression = ce;
                    } else {
                        return error.HttpTransferEncodingUnsupported;
                    }
                }

                if (iter.next()) |second| {
                    if (headers.transfer_compression != null) return error.HttpTransferEncodingUnsupported;

                    const trimmed = std.mem.trim(u8, second, " ");

                    if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                        headers.transfer_compression = ce;
                    } else {
                        return error.HttpTransferEncodingUnsupported;
                    }
                }

                if (iter.next()) |_| return error.HttpTransferEncodingUnsupported;
            } else if (std.ascii.eqlIgnoreCase(header_name, "content-encoding")) {
                if (headers.transfer_compression != null) return error.HttpHeadersInvalid;

                const trimmed = std.mem.trim(u8, header_value, " ");

                if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
                    headers.transfer_compression = ce;
                } else {
                    return error.HttpTransferEncodingUnsupported;
                }
            } else if (std.ascii.eqlIgnoreCase(header_name, "connection")) {
                if (std.ascii.eqlIgnoreCase(header_value, "keep-alive")) {
                    headers.connection = .keep_alive;
                } else if (std.ascii.eqlIgnoreCase(header_value, "close")) {
                    headers.connection = .close;
                } else {
                    return error.HttpConnectionHeaderUnsupported;
                }
            } else if (std.ascii.eqlIgnoreCase(header_name, "upgrade")) {
                headers.upgrade = header_value;
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
        const parsed = try Headers.parse(example);
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
            Headers.parse(example),
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
            Headers.parse(example),
        );
    }
};

inline fn int64(array: *const [8]u8) u64 {
    return @bitCast(u64, array.*);
}

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
