const std = @import("std");
const http = std.http;
const mem = std.mem;
const testing = std.testing;
const assert = std.debug.assert;

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
                if (headers.transfer_encoding != null or headers.transfer_compression != null) return error.HttpHeadersInvalid;

                // Transfer-Encoding: second, first
                // Transfer-Encoding: deflate, chunked
                var iter = std.mem.splitBackwards(u8, header_value, ",");

                if (iter.next()) |first| {
                    const trimmed = std.mem.trim(u8, first, " ");

                    if (std.meta.stringToEnum(http.TransferEncoding, trimmed)) |te| {
                        headers.transfer_encoding = te;
                    } else if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
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

inline fn int16(array: *const [2]u8) u16 {
    return @bitCast(u16, array.*);
}

inline fn int32(array: *const [4]u8) u32 {
    return @bitCast(u32, array.*);
}

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

/// Returns how many bytes are part of HTTP headers. Always less than or
/// equal to bytes.len. If the amount returned is less than bytes.len, it
/// means the headers ended and the first byte after the double \r\n\r\n is
/// located at `bytes[result]`.
pub fn findHeadersEnd(r: *Response, bytes: []const u8) usize {
    var index: usize = 0;

    // TODO: https://github.com/ziglang/zig/issues/8220
    state: while (true) {
        switch (r.state) {
            .invalid => unreachable,
            .finished => unreachable,
            .start => while (true) {
                switch (bytes.len - index) {
                    0 => return index,
                    1 => {
                        if (bytes[index] == '\r')
                            r.state = .seen_r;
                        return index + 1;
                    },
                    2 => {
                        if (int16(bytes[index..][0..2]) == int16("\r\n")) {
                            r.state = .seen_rn;
                        } else if (bytes[index + 1] == '\r') {
                            r.state = .seen_r;
                        }
                        return index + 2;
                    },
                    3 => {
                        if (int16(bytes[index..][0..2]) == int16("\r\n") and
                            bytes[index + 2] == '\r')
                        {
                            r.state = .seen_rnr;
                        } else if (int16(bytes[index + 1 ..][0..2]) == int16("\r\n")) {
                            r.state = .seen_rn;
                        } else if (bytes[index + 2] == '\r') {
                            r.state = .seen_r;
                        }
                        return index + 3;
                    },
                    4...15 => {
                        if (int32(bytes[index..][0..4]) == int32("\r\n\r\n")) {
                            r.state = .finished;
                            return index + 4;
                        } else if (int16(bytes[index + 1 ..][0..2]) == int16("\r\n") and
                            bytes[index + 3] == '\r')
                        {
                            r.state = .seen_rnr;
                            index += 4;
                            continue :state;
                        } else if (int16(bytes[index + 2 ..][0..2]) == int16("\r\n")) {
                            r.state = .seen_rn;
                            index += 4;
                            continue :state;
                        } else if (bytes[index + 3] == '\r') {
                            r.state = .seen_r;
                            index += 4;
                            continue :state;
                        }
                        index += 4;
                        continue;
                    },
                    else => {
                        const chunk = bytes[index..][0..16];
                        const v: @Vector(16, u8) = chunk.*;
                        const matches_r = v == @splat(16, @as(u8, '\r'));
                        const iota = std.simd.iota(u8, 16);
                        const default = @splat(16, @as(u8, 16));
                        const sub_index = @reduce(.Min, @select(u8, matches_r, iota, default));
                        switch (sub_index) {
                            0...12 => {
                                index += sub_index + 4;
                                if (int32(chunk[sub_index..][0..4]) == int32("\r\n\r\n")) {
                                    r.state = .finished;
                                    return index;
                                }
                                continue;
                            },
                            13 => {
                                index += 16;
                                if (int16(chunk[14..][0..2]) == int16("\n\r")) {
                                    r.state = .seen_rnr;
                                    continue :state;
                                }
                                continue;
                            },
                            14 => {
                                index += 16;
                                if (chunk[15] == '\n') {
                                    r.state = .seen_rn;
                                    continue :state;
                                }
                                continue;
                            },
                            15 => {
                                r.state = .seen_r;
                                index += 16;
                                continue :state;
                            },
                            16 => {
                                index += 16;
                                continue;
                            },
                            else => unreachable,
                        }
                    },
                }
            },

            .seen_r => switch (bytes.len - index) {
                0 => return index,
                1 => {
                    switch (bytes[index]) {
                        '\n' => r.state = .seen_rn,
                        '\r' => r.state = .seen_r,
                        else => r.state = .start,
                    }
                    return index + 1;
                },
                2 => {
                    if (int16(bytes[index..][0..2]) == int16("\n\r")) {
                        r.state = .seen_rnr;
                        return index + 2;
                    }
                    r.state = .start;
                    return index + 2;
                },
                else => {
                    if (int16(bytes[index..][0..2]) == int16("\n\r") and
                        bytes[index + 2] == '\n')
                    {
                        r.state = .finished;
                        return index + 3;
                    }
                    index += 3;
                    r.state = .start;
                    continue :state;
                },
            },
            .seen_rn => switch (bytes.len - index) {
                0 => return index,
                1 => {
                    switch (bytes[index]) {
                        '\r' => r.state = .seen_rnr,
                        else => r.state = .start,
                    }
                    return index + 1;
                },
                else => {
                    if (int16(bytes[index..][0..2]) == int16("\r\n")) {
                        r.state = .finished;
                        return index + 2;
                    }
                    index += 2;
                    r.state = .start;
                    continue :state;
                },
            },
            .seen_rnr => switch (bytes.len - index) {
                0 => return index,
                else => {
                    if (bytes[index] == '\n') {
                        r.state = .finished;
                        return index + 1;
                    }
                    index += 1;
                    r.state = .start;
                    continue :state;
                },
            },
            .chunk_size_prefix_r => unreachable,
            .chunk_size_prefix_n => unreachable,
            .chunk_size => unreachable,
            .chunk_r => unreachable,
            .chunk_data => unreachable,
        }

        return index;
    }
}

pub fn findChunkedLen(r: *Response, bytes: []const u8) usize {
    var i: usize = 0;
    if (r.state == .chunk_size) {
        while (i < bytes.len) : (i += 1) {
            const digit = switch (bytes[i]) {
                '0'...'9' => |b| b - '0',
                'A'...'Z' => |b| b - 'A' + 10,
                'a'...'z' => |b| b - 'a' + 10,
                '\r' => {
                    r.state = .chunk_r;
                    i += 1;
                    break;
                },
                else => {
                    r.state = .invalid;
                    return i;
                },
            };
            const mul = @mulWithOverflow(r.next_chunk_length, 16);
            if (mul[1] != 0) {
                r.state = .invalid;
                return i;
            }
            const add = @addWithOverflow(mul[0], digit);
            if (add[1] != 0) {
                r.state = .invalid;
                return i;
            }
            r.next_chunk_length = add[0];
        } else {
            return i;
        }
    }
    assert(r.state == .chunk_r);
    if (i == bytes.len) return i;

    if (bytes[i] == '\n') {
        r.state = .chunk_data;
        return i + 1;
    } else {
        r.state = .invalid;
        return i;
    }
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
