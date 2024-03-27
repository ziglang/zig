const std = @import("../std.zig");
const builtin = @import("builtin");
const testing = std.testing;
const mem = std.mem;

const assert = std.debug.assert;
const use_vectors = builtin.zig_backend != .stage2_x86_64;

pub const State = enum {
    invalid,

    // Begin header and trailer parsing states.

    start,
    seen_n,
    seen_r,
    seen_rn,
    seen_rnr,
    finished,

    // Begin transfer-encoding: chunked parsing states.

    chunk_head_size,
    chunk_head_ext,
    chunk_head_r,
    chunk_data,
    chunk_data_suffix,
    chunk_data_suffix_r,

    /// Returns true if the parser is in a content state (ie. not waiting for more headers).
    pub fn isContent(self: State) bool {
        return switch (self) {
            .invalid, .start, .seen_n, .seen_r, .seen_rn, .seen_rnr => false,
            .finished, .chunk_head_size, .chunk_head_ext, .chunk_head_r, .chunk_data, .chunk_data_suffix, .chunk_data_suffix_r => true,
        };
    }
};

pub const HeadersParser = struct {
    state: State = .start,
    /// A fixed buffer of len `max_header_bytes`.
    /// Pointers into this buffer are not stable until after a message is complete.
    header_bytes_buffer: []u8,
    header_bytes_len: u32,
    next_chunk_length: u64,
    /// `false`: headers. `true`: trailers.
    done: bool,

    /// Initializes the parser with a provided buffer `buf`.
    pub fn init(buf: []u8) HeadersParser {
        return .{
            .header_bytes_buffer = buf,
            .header_bytes_len = 0,
            .done = false,
            .next_chunk_length = 0,
        };
    }

    /// Reinitialize the parser.
    /// Asserts the parser is in the "done" state.
    pub fn reset(hp: *HeadersParser) void {
        assert(hp.done);
        hp.* = .{
            .state = .start,
            .header_bytes_buffer = hp.header_bytes_buffer,
            .header_bytes_len = 0,
            .done = false,
            .next_chunk_length = 0,
        };
    }

    pub fn get(hp: HeadersParser) []u8 {
        return hp.header_bytes_buffer[0..hp.header_bytes_len];
    }

    pub fn findHeadersEnd(r: *HeadersParser, bytes: []const u8) u32 {
        var hp: std.http.HeadParser = .{
            .state = switch (r.state) {
                .start => .start,
                .seen_n => .seen_n,
                .seen_r => .seen_r,
                .seen_rn => .seen_rn,
                .seen_rnr => .seen_rnr,
                .finished => .finished,
                else => unreachable,
            },
        };
        const result = hp.feed(bytes);
        r.state = switch (hp.state) {
            .start => .start,
            .seen_n => .seen_n,
            .seen_r => .seen_r,
            .seen_rn => .seen_rn,
            .seen_rnr => .seen_rnr,
            .finished => .finished,
        };
        return @intCast(result);
    }

    pub fn findChunkedLen(r: *HeadersParser, bytes: []const u8) u32 {
        var cp: std.http.ChunkParser = .{
            .state = switch (r.state) {
                .chunk_head_size => .head_size,
                .chunk_head_ext => .head_ext,
                .chunk_head_r => .head_r,
                .chunk_data => .data,
                .chunk_data_suffix => .data_suffix,
                .chunk_data_suffix_r => .data_suffix_r,
                .invalid => .invalid,
                else => unreachable,
            },
            .chunk_len = r.next_chunk_length,
        };
        const result = cp.feed(bytes);
        r.state = switch (cp.state) {
            .head_size => .chunk_head_size,
            .head_ext => .chunk_head_ext,
            .head_r => .chunk_head_r,
            .data => .chunk_data,
            .data_suffix => .chunk_data_suffix,
            .data_suffix_r => .chunk_data_suffix_r,
            .invalid => .invalid,
        };
        r.next_chunk_length = cp.chunk_len;
        return @intCast(result);
    }

    /// Returns whether or not the parser has finished parsing a complete
    /// message. A message is only complete after the entire body has been read
    /// and any trailing headers have been parsed.
    pub fn isComplete(r: *HeadersParser) bool {
        return r.done and r.state == .finished;
    }

    pub const CheckCompleteHeadError = error{HttpHeadersOversize};

    /// Pushes `in` into the parser. Returns the number of bytes consumed by
    /// the header. Any header bytes are appended to `header_bytes_buffer`.
    pub fn checkCompleteHead(hp: *HeadersParser, in: []const u8) CheckCompleteHeadError!u32 {
        if (hp.state.isContent()) return 0;

        const i = hp.findHeadersEnd(in);
        const data = in[0..i];
        if (hp.header_bytes_len + data.len > hp.header_bytes_buffer.len)
            return error.HttpHeadersOversize;

        @memcpy(hp.header_bytes_buffer[hp.header_bytes_len..][0..data.len], data);
        hp.header_bytes_len += @intCast(data.len);

        return i;
    }

    pub const ReadError = error{
        HttpChunkInvalid,
    };

    /// Reads the body of the message into `buffer`. Returns the number of
    /// bytes placed in the buffer.
    ///
    /// If `skip` is true, the buffer will be unused and the body will be skipped.
    ///
    /// See `std.http.Client.Connection for an example of `conn`.
    pub fn read(r: *HeadersParser, conn: anytype, buffer: []u8, skip: bool) !usize {
        assert(r.state.isContent());
        if (r.done) return 0;

        var out_index: usize = 0;
        while (true) {
            switch (r.state) {
                .invalid, .start, .seen_n, .seen_r, .seen_rn, .seen_rnr => unreachable,
                .finished => {
                    const data_avail = r.next_chunk_length;

                    if (skip) {
                        try conn.fill();

                        const nread = @min(conn.peek().len, data_avail);
                        conn.drop(@intCast(nread));
                        r.next_chunk_length -= nread;

                        if (r.next_chunk_length == 0 or nread == 0) r.done = true;

                        return out_index;
                    } else if (out_index < buffer.len) {
                        const out_avail = buffer.len - out_index;

                        const can_read = @as(usize, @intCast(@min(data_avail, out_avail)));
                        const nread = try conn.read(buffer[0..can_read]);
                        r.next_chunk_length -= nread;

                        if (r.next_chunk_length == 0 or nread == 0) r.done = true;

                        return nread;
                    } else {
                        return out_index;
                    }
                },
                .chunk_data_suffix, .chunk_data_suffix_r, .chunk_head_size, .chunk_head_ext, .chunk_head_r => {
                    try conn.fill();

                    const i = r.findChunkedLen(conn.peek());
                    conn.drop(@intCast(i));

                    switch (r.state) {
                        .invalid => return error.HttpChunkInvalid,
                        .chunk_data => if (r.next_chunk_length == 0) {
                            if (std.mem.eql(u8, conn.peek(), "\r\n")) {
                                r.state = .finished;
                                conn.drop(2);
                            } else {
                                // The trailer section is formatted identically
                                // to the header section.
                                r.state = .seen_rn;
                            }
                            r.done = true;

                            return out_index;
                        },
                        else => return out_index,
                    }

                    continue;
                },
                .chunk_data => {
                    const data_avail = r.next_chunk_length;
                    const out_avail = buffer.len - out_index;

                    if (skip) {
                        try conn.fill();

                        const nread = @min(conn.peek().len, data_avail);
                        conn.drop(@intCast(nread));
                        r.next_chunk_length -= nread;
                    } else if (out_avail > 0) {
                        const can_read: usize = @intCast(@min(data_avail, out_avail));
                        const nread = try conn.read(buffer[out_index..][0..can_read]);
                        r.next_chunk_length -= nread;
                        out_index += nread;
                    }

                    if (r.next_chunk_length == 0) {
                        r.state = .chunk_data_suffix;
                        continue;
                    }

                    return out_index;
                },
            }
        }
    }
};

inline fn int16(array: *const [2]u8) u16 {
    return @as(u16, @bitCast(array.*));
}

inline fn int24(array: *const [3]u8) u24 {
    return @as(u24, @bitCast(array.*));
}

inline fn int32(array: *const [4]u8) u32 {
    return @as(u32, @bitCast(array.*));
}

inline fn intShift(comptime T: type, x: anytype) T {
    switch (@import("builtin").cpu.arch.endian()) {
        .little => return @as(T, @truncate(x >> (@bitSizeOf(@TypeOf(x)) - @bitSizeOf(T)))),
        .big => return @as(T, @truncate(x)),
    }
}

/// A buffered (and peekable) Connection.
const MockBufferedConnection = struct {
    pub const buffer_size = 0x2000;

    conn: std.io.FixedBufferStream([]const u8),
    buf: [buffer_size]u8 = undefined,
    start: u16 = 0,
    end: u16 = 0,

    pub fn fill(conn: *MockBufferedConnection) ReadError!void {
        if (conn.end != conn.start) return;

        const nread = try conn.conn.read(conn.buf[0..]);
        if (nread == 0) return error.EndOfStream;
        conn.start = 0;
        conn.end = @as(u16, @truncate(nread));
    }

    pub fn peek(conn: *MockBufferedConnection) []const u8 {
        return conn.buf[conn.start..conn.end];
    }

    pub fn drop(conn: *MockBufferedConnection, num: u16) void {
        conn.start += num;
    }

    pub fn readAtLeast(conn: *MockBufferedConnection, buffer: []u8, len: usize) ReadError!usize {
        var out_index: u16 = 0;
        while (out_index < len) {
            const available = conn.end - conn.start;
            const left = buffer.len - out_index;

            if (available > 0) {
                const can_read = @as(u16, @truncate(@min(available, left)));

                @memcpy(buffer[out_index..][0..can_read], conn.buf[conn.start..][0..can_read]);
                out_index += can_read;
                conn.start += can_read;

                continue;
            }

            if (left > conn.buf.len) {
                // skip the buffer if the output is large enough
                return conn.conn.read(buffer[out_index..]);
            }

            try conn.fill();
        }

        return out_index;
    }

    pub fn read(conn: *MockBufferedConnection, buffer: []u8) ReadError!usize {
        return conn.readAtLeast(buffer, 1);
    }

    pub const ReadError = std.io.FixedBufferStream([]const u8).ReadError || error{EndOfStream};
    pub const Reader = std.io.Reader(*MockBufferedConnection, ReadError, read);

    pub fn reader(conn: *MockBufferedConnection) Reader {
        return Reader{ .context = conn };
    }

    pub fn writeAll(conn: *MockBufferedConnection, buffer: []const u8) WriteError!void {
        return conn.conn.writeAll(buffer);
    }

    pub fn write(conn: *MockBufferedConnection, buffer: []const u8) WriteError!usize {
        return conn.conn.write(buffer);
    }

    pub const WriteError = std.io.FixedBufferStream([]const u8).WriteError;
    pub const Writer = std.io.Writer(*MockBufferedConnection, WriteError, write);

    pub fn writer(conn: *MockBufferedConnection) Writer {
        return Writer{ .context = conn };
    }
};

test "HeadersParser.read length" {
    // mock BufferedConnection for read
    var headers_buf: [256]u8 = undefined;

    var r = HeadersParser.init(&headers_buf);
    const data = "GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\n\r\nHello";

    var conn: MockBufferedConnection = .{
        .conn = std.io.fixedBufferStream(data),
    };

    while (true) { // read headers
        try conn.fill();

        const nchecked = try r.checkCompleteHead(conn.peek());
        conn.drop(@intCast(nchecked));

        if (r.state.isContent()) break;
    }

    var buf: [8]u8 = undefined;

    r.next_chunk_length = 5;
    const len = try r.read(&conn, &buf, false);
    try std.testing.expectEqual(@as(usize, 5), len);
    try std.testing.expectEqualStrings("Hello", buf[0..len]);

    try std.testing.expectEqualStrings("GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\n\r\n", r.get());
}

test "HeadersParser.read chunked" {
    // mock BufferedConnection for read

    var headers_buf: [256]u8 = undefined;
    var r = HeadersParser.init(&headers_buf);
    const data = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n2\r\nHe\r\n2\r\nll\r\n1\r\no\r\n0\r\n\r\n";

    var conn: MockBufferedConnection = .{
        .conn = std.io.fixedBufferStream(data),
    };

    while (true) { // read headers
        try conn.fill();

        const nchecked = try r.checkCompleteHead(conn.peek());
        conn.drop(@intCast(nchecked));

        if (r.state.isContent()) break;
    }
    var buf: [8]u8 = undefined;

    r.state = .chunk_head_size;
    const len = try r.read(&conn, &buf, false);
    try std.testing.expectEqual(@as(usize, 5), len);
    try std.testing.expectEqualStrings("Hello", buf[0..len]);

    try std.testing.expectEqualStrings("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n", r.get());
}

test "HeadersParser.read chunked trailer" {
    // mock BufferedConnection for read

    var headers_buf: [256]u8 = undefined;
    var r = HeadersParser.init(&headers_buf);
    const data = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n2\r\nHe\r\n2\r\nll\r\n1\r\no\r\n0\r\nContent-Type: text/plain\r\n\r\n";

    var conn: MockBufferedConnection = .{
        .conn = std.io.fixedBufferStream(data),
    };

    while (true) { // read headers
        try conn.fill();

        const nchecked = try r.checkCompleteHead(conn.peek());
        conn.drop(@intCast(nchecked));

        if (r.state.isContent()) break;
    }
    var buf: [8]u8 = undefined;

    r.state = .chunk_head_size;
    const len = try r.read(&conn, &buf, false);
    try std.testing.expectEqual(@as(usize, 5), len);
    try std.testing.expectEqualStrings("Hello", buf[0..len]);

    while (true) { // read headers
        try conn.fill();

        const nchecked = try r.checkCompleteHead(conn.peek());
        conn.drop(@intCast(nchecked));

        if (r.state.isContent()) break;
    }

    try std.testing.expectEqualStrings("GET / HTTP/1.1\r\nHost: localhost\r\n\r\nContent-Type: text/plain\r\n\r\n", r.get());
}
