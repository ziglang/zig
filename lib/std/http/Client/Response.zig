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
/// This is a map of header names to header values. The header names
/// are lower case and the values are the original case.
headers_data: std.StringArrayHashMapUnmanaged([]const u8),
header_count: usize,
max_header_bytes: usize,
next_chunk_length: u64,
done: bool = false,

compression: union(enum) {
    deflate: Client.DeflateDecompressor,
    gzip: Client.GzipDecompressor,
    zstd: Client.ZstdDecompressor,
    none: void,
} = .none,

pub fn clearHeaders(self: *Response, allocator: std.mem.Allocator) void {
    for (self.headers_data.keys()) |key| {
        allocator.free(key);
    }
    self.headers_data.clearAndFree(allocator);
    self.header_count = 0;
}

pub fn parseHeaders(self: *Response, allocator: std.mem.Allocator) !void {
    var it = mem.split(u8, self.header_bytes.items[0 .. self.header_bytes.items.len - 4], "\r\n");

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

    var headers: Headers = .{ .version = version, .status = status };

    while (it.next()) |line| {
        if (line.len == 0) return error.HttpHeadersInvalid;
        switch (line[0]) {
            ' ', '\t' => return error.HttpHeaderContinuationsUnsupported,
            else => {},
        }
        var line_it = mem.split(u8, line, ": ");
        const header_name = line_it.first();
        const header_value = line_it.rest();

        const header_key_lower = try std.ascii.allocLowerString(allocator, header_name);
        errdefer allocator.free(header_key_lower);

        const getOrPut = try self.headers_data.getOrPut(allocator, header_key_lower);

        if (getOrPut.found_existing) {
            return error.HttpHeadersInvalid;
        } else {
            getOrPut.value_ptr.* = header_value;
        }
    }

    if (self.headers_data.get("location")) |header_value| {
        headers.location = header_value;
    }
    if (self.headers_data.get("content-length")) |header_value| {
        headers.content_length = try std.fmt.parseInt(u64, header_value, 10);
    }
    if (self.headers_data.get("transfer-encoding")) |header_value| {
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
    }
    if (self.headers_data.get("content-encoding")) |header_value| {
        const trimmed = std.mem.trim(u8, header_value, " ");

        if (std.meta.stringToEnum(http.ContentEncoding, trimmed)) |ce| {
            headers.transfer_compression = ce;
        } else {
            return error.HttpTransferEncodingUnsupported;
        }
    }
    if (self.headers_data.get("connection")) |header_value| {
        if (std.ascii.eqlIgnoreCase(header_value, "keep-alive")) {
            headers.connection = .keep_alive;
        } else if (std.ascii.eqlIgnoreCase(header_value, "close")) {
            headers.connection = .close;
        } else {
            return error.HttpConnectionHeaderUnsupported;
        }
    }
    if (self.headers_data.get("upgrade")) |header_value| {
        headers.upgrade = header_value;
    }

    self.headers = headers;
    self.header_count = self.headers_data.count();
}

inline fn isSliceUpper(slice: []const u8) bool {
    for (slice) |c| {
        if (std.ascii.isUpper(c)) return true;
    }
    return false;
}

/// Get a header value by name. The name must be lower case.
pub fn getHeader(self: *Response, name: []const u8) ?[]const u8 {
    // assert that the header name is lower case
    assert(!isSliceUpper(name));
    return self.headers_data.get(name);
}

pub fn getHeaderListIterator(self: *Response, name: []const u8) ?HeaderValuesIterator {
    // assert that the header name is lower case
    assert(!isSliceUpper(name));
    return HeaderValuesIterator{ .buffer = self.headers_data.get(name) orelse return null, .index = 0 };
}

test "parse headers" {
    const example =
        "HTTP/1.1 301 Moved Permanently\r\n" ++
        "Location: https://www.example.com/\r\n" ++
        "Content-Type: text/html; charset=UTF-8\r\n" ++
        "Content-Length: 220\r\n" ++
        "Date: Thu, 15 Feb 2007 12:34:56 JST\r\n" ++
        "Expires: Tue, 8 Jan 2013 02:20:09 JST\r\n" ++
        "Accept-Ranges: bytes\r\n" ++
        "Cache-Control: max-age=100000\r\n" ++
        "Transfer-Encoding: deflate, chunked\r\n\r\n";

    var resp = Response.initDynamic(example.len);
    try resp.header_bytes.appendSlice(testing.allocator, example);
    defer {
        resp.header_bytes.deinit(testing.allocator);
        resp.clearHeaders(testing.allocator);
        resp.headers_data.deinit(testing.allocator);
    }

    try resp.parseHeaders(testing.allocator);

    try testing.expectEqual(http.Version.@"HTTP/1.1", resp.headers.version);
    try testing.expectEqual(http.Status.moved_permanently, resp.headers.status);
    try testing.expectEqualStrings("https://www.example.com/", resp.headers.location orelse return error.TestFailed);
    try testing.expectEqualStrings("https://www.example.com/", resp.getHeader("location") orelse return error.TestFailed);

    try testing.expectEqual(@as(?u64, 220), resp.headers.content_length);
    try testing.expectEqualStrings("220", resp.getHeader("content-length") orelse return error.TestFailed);

    try testing.expectEqualStrings("Thu, 15 Feb 2007 12:34:56 JST", resp.getHeader("date") orelse return error.TestFailed);
    try testing.expectEqualStrings("Tue, 8 Jan 2013 02:20:09 JST", resp.getHeader("expires") orelse return error.TestFailed);
    try testing.expectEqualStrings("bytes", resp.getHeader("accept-ranges") orelse return error.TestFailed);
    try testing.expectEqualStrings("max-age=100000", resp.getHeader("cache-control") orelse return error.TestFailed);
    var iter = resp.getHeaderListIterator("transfer-encoding") orelse return error.TestFailed;
    try testing.expectEqualStrings("deflate", iter.next() orelse return error.TestFailed);
    try testing.expectEqualStrings("chunked", iter.next() orelse return error.TestFailed);
}

test "header continuation" {
    const example =
        "HTTP/1.0 200 OK\r\n" ++
        "Content-Type: text/html;\r\n charset=UTF-8\r\n" ++
        "Content-Length: 220\r\n\r\n";

    var resp = Response.initDynamic(example.len);
    try resp.header_bytes.appendSlice(testing.allocator, example);
    defer {
        resp.header_bytes.deinit(testing.allocator);
        resp.clearHeaders(testing.allocator);
        resp.headers_data.deinit(testing.allocator);
    }

    try testing.expectError(
        error.HttpHeaderContinuationsUnsupported,
        resp.parseHeaders(),
    );
}

test "duplicate content length header" {
    const example =
        "HTTP/1.0 200 OK\r\n" ++
        "Content-Length: 220\r\n" ++
        "Content-Type: text/html; charset=UTF-8\r\n" ++
        "content-length: 220\r\n\r\n";

    var resp = Response.initDynamic(example.len);
    try resp.header_bytes.appendSlice(testing.allocator, example);
    defer {
        resp.header_bytes.deinit(testing.allocator);
        resp.clearHeaders(testing.allocator);
        resp.headers_data.deinit(testing.allocator);
    }

    try testing.expectError(
        error.HttpHeadersInvalid,
        resp.parseHeaders(),
    );
}

pub const Headers = struct {
    status: http.Status,
    version: http.Version,
    location: ?[]const u8 = null,
    content_length: ?u64 = null,
    transfer_encoding: ?http.TransferEncoding = null,
    transfer_compression: ?http.ContentEncoding = null,
    connection: http.Connection = .close,
    upgrade: ?[]const u8 = null,
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
        .headers_data = .{},
        .header_count = 0,
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
        .headers_data = .{},
        .header_count = 0,
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

pub const HeaderValuesIterator = struct {
    buffer: []const u8,
    index: ?usize,

    const delimiter = ",";

    const Self = @This();

    /// Returns a slice of the first field. This never fails.
    /// Call this only to get the first field and then use `next` to get all subsequent fields.
    pub fn first(self: *Self) []const u8 {
        assert(self.index.? == 0);
        return self.next().?;
    }

    /// Returns a slice of the next field, or null if splitting is complete.
    pub fn next(self: *Self) ?[]const u8 {
        const start = self.index orelse return null;
        const end = if (std.mem.indexOfPos(u8, self.buffer, start, delimiter)) |delim_start| blk: {
            self.index = delim_start + delimiter.len;
            break :blk delim_start;
        } else blk: {
            self.index = null;
            break :blk self.buffer.len;
        };
        return std.mem.trim(u8, self.buffer[start..end], " ");
    }

    /// Returns a slice of the remaining bytes. Does not affect iterator state.
    pub fn rest(self: Self) []const u8 {
        const end = self.buffer.len;
        const start = self.index orelse end;
        return std.mem.trim(u8, self.buffer[start..end], " ");
    }

    /// Resets the iterator to the initial slice.
    pub fn reset(self: *Self) void {
        self.index = 0;
    }
};
