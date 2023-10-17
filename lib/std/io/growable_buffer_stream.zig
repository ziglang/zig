const std = @import("../std.zig");
const io = std.io;
const testing = std.testing;
const mem = std.mem;
const assert = std.debug.assert;

/// This turns a `std.ArrayList` of bytes into an `io.Writer`, `io.Reader`, or `io.SeekableStream`.
pub const GrowableBufferStream = struct {
    buffer: *std.ArrayList(u8),
    pos: usize,
    config: Config,

    pub const ReadError = error{};
    pub const WriteError = error{NoSpaceLeft};
    pub const SeekError = error{};
    pub const GetSeekPosError = error{};

    pub const Reader = io.Reader(*Self, ReadError, read);
    pub const Writer = io.Writer(*Self, WriteError, write);

    pub const SeekableStream = io.SeekableStream(
        *Self,
        SeekError,
        GetSeekPosError,
        seekTo,
        seekBy,
        getPos,
        getEndPos,
    );

    pub const Config = struct {
        /// Value used to fill uninitialized bytes when resizing.
        /// By default `fill` is `0`, mimicking POSIX behavior when seeking past the end of a file.
        /// When null, bytes are left uninitialized.
        fill: ?u8 = 0,
    };

    const Self = @This();

    pub fn init(buffer: *std.ArrayList(u8), config: Config) Self {
        return .{ .buffer = buffer, .pos = 0, .config = config };
    }

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *Self) Writer {
        return .{ .context = self };
    }

    pub fn seekableStream(self: *Self) SeekableStream {
        return .{ .context = self };
    }

    pub fn read(self: *Self, dest: []u8) ReadError!usize {
        if (self.pos >= self.buffer.items.len) return 0;
        const size = @min(dest.len, self.buffer.items.len - self.pos);
        const end = self.pos + size;

        @memcpy(dest[0..size], self.buffer.items[self.pos..end]);
        self.pos = end;

        return size;
    }

    /// If the returned number of bytes written is less than requested, the
    /// buffer failed to resize to fit the new data. Returns
    /// `error.NoSpaceLeft` when no bytes would be written.
    /// Note: `error.NoSpaceLeft` matches the corresponding error from
    /// `std.fs.File.WriteError`.
    pub fn write(self: *Self, bytes: []const u8) WriteError!usize {
        if (bytes.len == 0) return 0;
        if (self.pos >= self.buffer.items.len) {
            const prev_len = self.buffer.items.len;
            self.buffer.resize(self.pos + bytes.len) catch {};

            if (self.config.fill) |fill| {
                const uninit_end = @min(self.pos, self.buffer.items.len);
                @memset(self.buffer.items[prev_len..uninit_end], fill);
            }
        }

        const n = if (self.pos + bytes.len <= self.buffer.items.len)
            bytes.len
        else
            self.buffer.items.len - self.pos;

        @memcpy(self.buffer.items[self.pos..][0..n], bytes[0..n]);
        self.pos += n;

        if (n == 0) return error.NoSpaceLeft;

        return n;
    }

    pub fn seekTo(self: *Self, pos: u64) SeekError!void {
        self.pos = if (std.math.cast(usize, pos)) |x| x else std.math.maxInt(usize);
    }

    pub fn seekBy(self: *Self, amt: i64) SeekError!void {
        if (amt < 0) {
            const abs_amt = @abs(amt);
            const abs_amt_usize = std.math.cast(usize, abs_amt) orelse std.math.maxInt(usize);
            if (abs_amt_usize > self.pos) {
                self.pos = 0;
            } else {
                self.pos -= abs_amt_usize;
            }
        } else {
            const amt_usize = std.math.cast(usize, amt) orelse std.math.maxInt(usize);
            const new_pos = std.math.add(usize, self.pos, amt_usize) catch std.math.maxInt(usize);
            self.pos = new_pos;
        }
    }

    pub fn getEndPos(self: *Self) GetSeekPosError!u64 {
        return self.buffer.items.len;
    }

    pub fn getPos(self: *Self) GetSeekPosError!u64 {
        return self.pos;
    }

    pub fn getWritten(self: Self) []u8 {
        return self.buffer.items[0..self.pos];
    }

    pub fn reset(self: *Self) void {
        self.pos = 0;
    }
};

test "GrowableBufferStream output" {
    var buf = std.ArrayList(u8).init(testing.allocator);
    defer buf.deinit();

    var gbs = GrowableBufferStream.init(&buf, .{});
    const stream = gbs.writer();

    try stream.print("{s}{s}!", .{ "Hello", "World" });
    try testing.expectEqualSlices(u8, "HelloWorld!", gbs.getWritten());
}

test "GrowableBufferStream output 2" {
    var failing_allocator = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 2 });
    var buffer = std.ArrayList(u8).init(failing_allocator.allocator());
    defer buffer.deinit();

    var gbs = GrowableBufferStream.init(&buffer, .{});

    try gbs.writer().writeAll("Hello");
    try testing.expect(mem.eql(u8, gbs.getWritten(), "Hello"));

    try gbs.writer().writeAll("world");
    try testing.expect(mem.eql(u8, gbs.getWritten(), "Helloworld"));

    const len = buffer.items.len;
    const long_message = "Hello world" ++ "!" ** 32;

    gbs.reset();
    try testing.expect(gbs.getWritten().len == 0);

    try testing.expectError(error.NoSpaceLeft, gbs.writer().writeAll(long_message));
    try testing.expect(mem.eql(u8, gbs.getWritten(), long_message[0..len]));
}

test "GrowableBufferStream output past stream" {
    var buf = std.ArrayList(u8).init(testing.allocator);
    defer buf.deinit();

    inline for (.{ 0, 0x69 }) |fill| {
        buf.clearRetainingCapacity();
        var gbs = GrowableBufferStream.init(&buf, .{ .fill = fill });
        const stream = gbs.writer();

        try stream.writeAll(&[_]u8{ 1, 2, 3, 4 });
        try gbs.seekTo(8);
        try stream.writeByte(0xDE);

        const expected = [_]u8{ 1, 2, 3, 4 } ++ [_]u8{fill} ** 4 ++ [_]u8{0xDE};
        try testing.expectEqualSlices(u8, &expected, gbs.getWritten());
    }
}

test "GrowableBufferStream input" {
    var bytes = std.ArrayList(u8).init(testing.allocator);
    defer bytes.deinit();

    try bytes.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6, 7 });
    var gbs = GrowableBufferStream.init(&bytes, .{});

    var dest: [4]u8 = undefined;

    var read = try gbs.reader().read(&dest);
    try testing.expect(read == 4);
    try testing.expect(mem.eql(u8, dest[0..4], bytes.items[0..4]));

    read = try gbs.reader().read(&dest);
    try testing.expect(read == 3);
    try testing.expect(mem.eql(u8, dest[0..3], bytes.items[4..7]));

    read = try gbs.reader().read(&dest);
    try testing.expect(read == 0);

    try gbs.seekTo((try gbs.getEndPos()) + 1);
    read = try gbs.reader().read(&dest);
    try testing.expect(read == 0);
}
