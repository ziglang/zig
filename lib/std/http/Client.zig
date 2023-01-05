//! This API is a barely-touched, barely-functional http client, just the
//! absolute minimum thing I needed in order to test `std.crypto.tls`. Bear
//! with me and I promise the API will become useful and streamlined.
//!
//! TODO: send connection: keep-alive and LRU cache a configurable number of
//! open connections to skip DNS and TLS handshake for subsequent requests.

const std = @import("../std.zig");
const mem = std.mem;
const assert = std.debug.assert;
const http = std.http;
const net = std.net;
const Client = @This();
const Url = std.Url;
const Allocator = std.mem.Allocator;
const testing = std.testing;

/// Used for tcpConnectToHost and storing HTTP headers when an externally
/// managed buffer is not provided.
allocator: Allocator,
ca_bundle: std.crypto.Certificate.Bundle = .{},

pub const Connection = struct {
    stream: net.Stream,
    /// undefined unless protocol is tls.
    tls_client: std.crypto.tls.Client,
    protocol: Protocol,

    pub const Protocol = enum { plain, tls };

    pub fn read(conn: *Connection, buffer: []u8) !usize {
        switch (conn.protocol) {
            .plain => return conn.stream.read(buffer),
            .tls => return conn.tls_client.read(conn.stream, buffer),
        }
    }

    pub fn readAtLeast(conn: *Connection, buffer: []u8, len: usize) !usize {
        switch (conn.protocol) {
            .plain => return conn.stream.readAtLeast(buffer, len),
            .tls => return conn.tls_client.readAtLeast(conn.stream, buffer, len),
        }
    }

    pub fn writeAll(conn: *Connection, buffer: []const u8) !void {
        switch (conn.protocol) {
            .plain => return conn.stream.writeAll(buffer),
            .tls => return conn.tls_client.writeAll(conn.stream, buffer),
        }
    }

    pub fn write(conn: *Connection, buffer: []const u8) !usize {
        switch (conn.protocol) {
            .plain => return conn.stream.write(buffer),
            .tls => return conn.tls_client.write(conn.stream, buffer),
        }
    }
};

/// TODO: emit error.UnexpectedEndOfStream or something like that when the read
/// data does not match the content length. This is necessary since HTTPS disables
/// close_notify protection on underlying TLS streams.
pub const Request = struct {
    client: *Client,
    connection: Connection,
    redirects_left: u32,
    response: Response,
    /// These are stored in Request so that they are available when following
    /// redirects.
    headers: Headers,

    pub const Response = struct {
        headers: Response.Headers,
        state: State,
        header_bytes_owned: bool,
        /// This could either be a fixed buffer provided by the API user or it
        /// could be our own array list.
        header_bytes: std.ArrayListUnmanaged(u8),
        max_header_bytes: usize,

        pub const Headers = struct {
            location: ?[]const u8 = null,
            status: http.Status,
            version: http.Version,
            content_length: ?u64 = null,

            pub fn parse(bytes: []const u8) !Response.Headers {
                var it = mem.split(u8, bytes[0 .. bytes.len - 4], "\r\n");

                const first_line = it.first();
                if (first_line.len < 12)
                    return error.ShortHttpStatusLine;

                const version: http.Version = switch (int64(first_line[0..8])) {
                    int64("HTTP/1.0") => .@"HTTP/1.0",
                    int64("HTTP/1.1") => .@"HTTP/1.1",
                    else => return error.BadHttpVersion,
                };
                if (first_line[8] != ' ') return error.InvalidHttpHeaders;
                const status = @intToEnum(http.Status, parseInt3(first_line[9..12].*));

                var headers: Response.Headers = .{
                    .version = version,
                    .status = status,
                };

                while (it.next()) |line| {
                    var line_it = mem.split(u8, line, ": ");
                    const header_name = line_it.first();
                    const header_value = line_it.rest();
                    if (std.ascii.eqlIgnoreCase(header_name, "location")) {
                        headers.location = header_value;
                    } else if (std.ascii.eqlIgnoreCase(header_name, "content-length")) {
                        headers.content_length = try std.fmt.parseInt(u64, header_value, 10);
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
                const parsed = try Response.Headers.parse(example);
                try testing.expectEqual(http.Version.@"HTTP/1.1", parsed.version);
                try testing.expectEqual(http.Status.moved_permanently, parsed.status);
                try testing.expectEqualStrings("https://www.example.com/", parsed.location orelse
                    return error.TestFailed);
                try testing.expectEqual(@as(?u64, 220), parsed.content_length);
            }
        };

        pub const State = enum {
            invalid,
            finished,
            start,
            seen_r,
            seen_rn,
            seen_rnr,
        };

        pub fn initDynamic(max: usize) Response {
            return .{
                .state = .start,
                .headers = undefined,
                .header_bytes = .{},
                .max_header_bytes = max,
                .header_bytes_owned = true,
            };
        }

        pub fn initStatic(buf: []u8) Response {
            return .{
                .state = .start,
                .headers = undefined,
                .header_bytes = .{ .items = buf[0..0], .capacity = buf.len },
                .max_header_bytes = buf.len,
                .header_bytes_owned = false,
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
                }

                return index;
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

        inline fn int16(array: *const [2]u8) u16 {
            return @bitCast(u16, array.*);
        }

        inline fn int32(array: *const [4]u8) u32 {
            return @bitCast(u32, array.*);
        }

        inline fn int64(array: *const [8]u8) u64 {
            return @bitCast(u64, array.*);
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
    };

    pub const Headers = struct {
        method: http.Method = .GET,
    };

    pub const Options = struct {
        max_redirects: u32 = 3,
        header_strategy: HeaderStrategy = .{ .dynamic = 16 * 1024 },

        pub const HeaderStrategy = union(enum) {
            /// In this case, the client's Allocator will be used to store the
            /// entire HTTP header. This value is the maximum total size of
            /// HTTP headers allowed, otherwise
            /// error.HttpHeadersExceededSizeLimit is returned from read().
            dynamic: usize,
            /// This is used to store the entire HTTP header. If the HTTP
            /// header is too big to fit, `error.HttpHeadersExceededSizeLimit`
            /// is returned from read(). When this is used, `error.OutOfMemory`
            /// cannot be returned from `read()`.
            static: []u8,
        };
    };

    /// May be skipped if header strategy is buffer.
    pub fn deinit(req: *Request) void {
        if (req.response.header_bytes_owned) {
            req.response.header_bytes.deinit(req.client.allocator);
        }
        req.* = undefined;
    }

    pub fn readAll(req: *Request, buffer: []u8) !usize {
        return readAtLeast(req, buffer, buffer.len);
    }

    pub fn read(req: *Request, buffer: []u8) !usize {
        return readAtLeast(req, buffer, 1);
    }

    pub fn readAtLeast(req: *Request, buffer: []u8, len: usize) !usize {
        assert(len <= buffer.len);
        var index: usize = 0;
        while (index < len) {
            const headers_finished = req.response.state == .finished;
            const amt = try readAdvanced(req, buffer[index..]);
            if (amt == 0 and headers_finished) break;
            index += amt;
        }
        return index;
    }

    /// This one can return 0 without meaning EOF.
    /// TODO change to readvAdvanced
    pub fn readAdvanced(req: *Request, buffer: []u8) !usize {
        if (req.response.state == .finished) return req.connection.read(buffer);

        const amt = try req.connection.read(buffer);
        const data = buffer[0..amt];
        const i = req.response.findHeadersEnd(data);
        if (req.response.state == .invalid) return error.InvalidHttpHeaders;

        const headers_data = data[0..i];
        if (req.response.header_bytes.items.len + headers_data.len > req.response.max_header_bytes) {
            return error.HttpHeadersExceededSizeLimit;
        }
        try req.response.header_bytes.appendSlice(req.client.allocator, headers_data);

        if (req.response.state == .finished) {
            req.response.headers = try Response.Headers.parse(req.response.header_bytes.items);
        }

        if (req.response.headers.status.class() == .redirect) {
            if (req.redirects_left == 0) return error.TooManyHttpRedirects;
            const location = req.response.headers.location orelse
                return error.HttpRedirectMissingLocation;
            const new_url = try std.Url.parse(location);
            const new_req = try req.client.request(new_url, req.headers, .{
                .max_redirects = req.redirects_left - 1,
                .header_strategy = if (req.response.header_bytes_owned) .{
                    .dynamic = req.response.max_header_bytes,
                } else .{
                    .static = req.response.header_bytes.unusedCapacitySlice(),
                },
            });
            req.deinit();
            req.* = new_req;
            return readAdvanced(req, buffer);
        }

        const body_data = data[i..];
        if (body_data.len > 0) {
            mem.copy(u8, buffer, body_data);
            return body_data.len;
        }
        return 0;
    }

    test {
        _ = Response;
    }
};

pub fn deinit(client: *Client, gpa: Allocator) void {
    client.ca_bundle.deinit(gpa);
    client.* = undefined;
}

pub fn connect(client: *Client, host: []const u8, port: u16, protocol: Connection.Protocol) !Connection {
    var conn: Connection = .{
        .stream = try net.tcpConnectToHost(client.allocator, host, port),
        .tls_client = undefined,
        .protocol = protocol,
    };

    switch (protocol) {
        .plain => {},
        .tls => {
            conn.tls_client = try std.crypto.tls.Client.init(conn.stream, client.ca_bundle, host);
            // This is appropriate for HTTPS because the HTTP headers contain
            // the content length which is used to detect truncation attacks.
            conn.tls_client.allow_truncation_attacks = true;
        },
    }

    return conn;
}

pub fn request(client: *Client, url: Url, headers: Request.Headers, options: Request.Options) !Request {
    const protocol: Connection.Protocol = if (mem.eql(u8, url.scheme, "http"))
        .plain
    else if (mem.eql(u8, url.scheme, "https"))
        .tls
    else
        return error.UnsupportedUrlScheme;

    const port: u16 = url.port orelse switch (protocol) {
        .plain => 80,
        .tls => 443,
    };

    var req: Request = .{
        .client = client,
        .headers = headers,
        .connection = try client.connect(url.host, port, protocol),
        .redirects_left = options.max_redirects,
        .response = switch (options.header_strategy) {
            .dynamic => |max| Request.Response.initDynamic(max),
            .static => |buf| Request.Response.initStatic(buf),
        },
    };

    {
        var h = try std.BoundedArray(u8, 1000).init(0);
        try h.appendSlice(@tagName(headers.method));
        try h.appendSlice(" ");
        try h.appendSlice(url.path);
        try h.appendSlice(" HTTP/1.1\r\nHost: ");
        try h.appendSlice(url.host);
        try h.appendSlice("\r\nConnection: close\r\n\r\n");

        const header_bytes = h.slice();
        try req.connection.writeAll(header_bytes);
    }

    return req;
}

test {
    _ = Request;
}
