status: http.Status,
version: http.Version,

pub const Parser = struct {
    state: State,
    headers: Headers,
    buffer: [16]u8,
    buffer_index: u4,

    pub const init: Parser = .{
        .state = .start,
        .headers = .{
            .status = undefined,
            .version = undefined,
        },
        .buffer = undefined,
        .buffer_index = 0,
    };

    pub const State = enum {
        invalid,
        finished,
        start,
        expect_status,
        find_start_line_end,
        line,
        line_r,
    };

    /// Returns how many bytes are processed into headers. Always less than or
    /// equal to bytes.len. If the amount returned is less than bytes.len, it
    /// means the headers ended and the first byte after the double \r\n\r\n is
    /// located at `bytes[result]`.
    pub fn feed(p: *Parser, bytes: []const u8) usize {
        var index: usize = 0;

        while (bytes.len - index >= 16) {
            index += p.feed16(bytes[index..][0..16]);
            switch (p.state) {
                .invalid, .finished => return index,
                else => continue,
            }
        }

        while (index < bytes.len) {
            var buffer = [1]u8{0} ** 16;
            const src = bytes[index..bytes.len];
            std.mem.copy(u8, &buffer, src);
            index += p.feed16(&buffer);
            switch (p.state) {
                .invalid, .finished => return index,
                else => continue,
            }
        }

        return index;
    }

    pub fn feed16(p: *Parser, chunk: *const [16]u8) u8 {
        switch (p.state) {
            .invalid, .finished => return 0,
            .start => {
                p.headers.version = switch (std.mem.readIntNative(u64, chunk[0..8])) {
                    std.mem.readIntNative(u64, "HTTP/1.0") => .@"HTTP/1.0",
                    std.mem.readIntNative(u64, "HTTP/1.1") => .@"HTTP/1.1",
                    else => return invalid(p, 0),
                };
                p.state = .expect_status;
                return 8;
            },
            .expect_status => {
                // example: " 200 OK\r\n"
                // example; " 301 Moved Permanently\r\n"
                switch (std.mem.readIntNative(u64, chunk[0..8])) {
                    std.mem.readIntNative(u64, " 200 OK\r") => {
                        if (chunk[8] != '\n') return invalid(p, 8);
                        p.headers.status = .ok;
                        p.state = .line;
                        return 9;
                    },
                    std.mem.readIntNative(u64, " 301 Mov") => {
                        p.headers.status = .moved_permanently;
                        if (!std.mem.eql(u8, chunk[9..], "ed Perma"))
                            return invalid(p, 9);
                        p.state = .find_start_line_end;
                        return 16;
                    },
                    else => {
                        if (chunk[0] != ' ') return invalid(p, 0);
                        const status = std.fmt.parseInt(u10, chunk[1..][0..3], 10) catch
                            return invalid(p, 1);
                        p.headers.status = @intToEnum(http.Status, status);
                        const v: @Vector(12, u8) = chunk[4..16].*;
                        const matches_r = v == @splat(12, @as(u8, '\r'));
                        const iota = std.simd.iota(u8, 12);
                        const default = @splat(12, @as(u8, 12));
                        const index = 4 + @reduce(.Min, @select(u8, matches_r, iota, default));
                        if (index >= 15) {
                            p.state = .find_start_line_end;
                            return index;
                        }
                        if (chunk[index + 1] != '\n')
                            return invalid(p, index + 1);
                        p.state = .line;
                        return index + 2;
                    },
                }
            },
            .find_start_line_end => {
                const v: @Vector(16, u8) = chunk.*;
                const matches_r = v == @splat(16, @as(u8, '\r'));
                const iota = std.simd.iota(u8, 16);
                const default = @splat(16, @as(u8, 16));
                const index = @reduce(.Min, @select(u8, matches_r, iota, default));
                if (index >= 15) {
                    p.state = .find_start_line_end;
                    return index;
                }
                if (chunk[index + 1] != '\n')
                    return invalid(p, index + 1);
                p.state = .line;
                return index + 2;
            },
            .line => {
                const v: @Vector(16, u8) = chunk.*;
                const matches_r = v == @splat(16, @as(u8, '\r'));
                const iota = std.simd.iota(u8, 16);
                const default = @splat(16, @as(u8, 16));
                const index = @reduce(.Min, @select(u8, matches_r, iota, default));
                if (index >= 15) {
                    return index;
                }
                if (chunk[index + 1] != '\n')
                    return invalid(p, index + 1);
                if (index + 4 <= 16 and chunk[index + 2] == '\r') {
                    if (chunk[index + 3] != '\n') return invalid(p, index + 3);
                    p.state = .finished;
                    return index + 4;
                }
                p.state = .line_r;
                return index + 2;
            },
            .line_r => {
                if (chunk[0] == '\r') {
                    if (chunk[1] != '\n') return invalid(p, 1);
                    p.state = .finished;
                    return 2;
                }
                p.state = .line;
                // Here would be nice to use this proposal when it is implemented:
                // https://github.com/ziglang/zig/issues/8220
                return 0;
            },
        }
    }

    fn invalid(p: *Parser, i: u8) u8 {
        p.state = .invalid;
        return i;
    }
};

const std = @import("../std.zig");
const http = std.http;
const Headers = @This();
const testing = std.testing;

test "status line ok" {
    var p = Parser.init;
    const line = "HTTP/1.1 200 OK\r\n";
    try testing.expect(p.feed(line) == line.len);
    try testing.expectEqual(Parser.State.line, p.state);
    try testing.expect(p.headers.version == .@"HTTP/1.1");
    try testing.expect(p.headers.status == .ok);
}

test "status line non hot path long msg" {
    var p = Parser.init;
    const line = "HTTP/1.0 418 I'm a teapot\r\n";
    try testing.expect(p.feed(line) == line.len);
    try testing.expectEqual(Parser.State.line, p.state);
    try testing.expect(p.headers.version == .@"HTTP/1.0");
    try testing.expect(p.headers.status == .teapot);
}

test "status line non hot path short msg" {
    var p = Parser.init;
    const line = "HTTP/1.1 418 lol\r\n";
    try testing.expect(p.feed(line) == line.len);
    try testing.expectEqual(Parser.State.line, p.state);
    try testing.expect(p.headers.version == .@"HTTP/1.1");
    try testing.expect(p.headers.status == .teapot);
}
