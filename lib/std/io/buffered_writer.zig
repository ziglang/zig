const std = @import("../std.zig");

const io = std.io;
const mem = std.mem;

pub fn BufferedWriter(comptime buffer_size: usize, comptime WriterType: type) type {
    return struct {
        unbuffered_writer: WriterType,
        buf: [buffer_size]u8 = undefined,
        end: usize = 0,
        filled: usize = 0,

        pub const Error = WriterType.Error;

        const Self = @This();

        pub usingnamespace if (@hasDecl(WriterType, "seek_interface_id")) struct {
            pub const SeekError = WriterType.SeekError || Error;
            pub const GetSeekPosError = WriterType.GetSeekPosError;
            pub const Writer = io.SeekableWriter(*Self, Error, write);

            pub fn seekTo(self: *Self, pos: u64) SeekError!void {
                try self.flush();
                return self.unbuffered_writer.seekTo(pos);
            }

            pub fn seekBy(self: *Self, amt: i64) SeekError!void {
                if (amt < 0) {
                    const abs_amt = std.math.absCast(amt);
                    const abs_amt_usize = std.math.cast(usize, abs_amt) orelse std.math.maxInt(usize);
                    if (abs_amt_usize > self.end) {
                        const diff = self.filled - self.end;
                        try self.flush();
                        try self.unbuffered_writer.seekBy(amt - @intCast(i64, diff));
                    } else {
                        self.end -= abs_amt_usize;
                    }
                } else {
                    try self.flush();
                    try self.unbuffered_writer.seekBy(@intCast(i64, amt));
                }
            }

            pub fn getEndPos(self: *Self) GetSeekPosError!u64 {
                return (try self.unbuffered_writer.getEndPos()) + self.end;
            }

            pub fn getPos(self: *Self) GetSeekPosError!u64 {
                return (try self.unbuffered_writer.getPos()) + self.end;
            }

            pub fn writer(self: *Self) Writer {
                return .{ .context = self };
            }
        } else struct {
            pub const Writer = io.Writer(*Self, Error, write);

            pub fn writer(self: *Self) Writer {
                return .{ .context = self };
            }
        };

        pub fn flush(self: *Self) Error!void {
            try self.unbuffered_writer.writeAll(self.buf[0..self.filled]);
            self.end = 0;
            self.filled = 0;
        }

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            if (self.end + bytes.len > self.buf.len) {
                try self.flush();
                if (bytes.len > self.buf.len)
                    return self.unbuffered_writer.write(bytes);
            }

            mem.copy(u8, self.buf[self.end..], bytes);
            self.end += bytes.len;
            if (self.filled < self.end) self.filled = self.end;
            return bytes.len;
        }
    };
}

pub fn bufferedWriter(underlying_stream: anytype) BufferedWriter(4096, @TypeOf(underlying_stream)) {
    return .{ .unbuffered_writer = underlying_stream };
}

test "io.SeekableBufferedWriter" {
    const testing = std.testing;
    var dest: [20]u8 = undefined;
    std.mem.set(u8, dest[0..], 'z');
    const str = "This is a test";
    var stream = io.fixedBufferStream(dest[0..]);

    var buf_writer = bufferedWriter(stream.writer());
    const writer = buf_writer.writer();

    try testing.expectEqual(@as(u64, 0), try writer.getPos());
    try writer.writeAll(str);
    try testing.expectEqual(@as(u64, str.len), try writer.getPos());
    try testing.expectEqualSlices(u8, "z" ** 20, dest[0..]);
    try writer.seekTo(0); // This should now flush the buffer also
    try testing.expectEqualSlices(u8, str, dest[0..str.len]);
    try testing.expectEqual(@as(u64, 0), try writer.getPos());
    std.mem.set(u8, dest[0..], 'z');
    try writer.seekBy(5);
    try writer.writeAll(str);
    try testing.expectEqual(@as(u64, 5 + str.len), try writer.getPos());
    try testing.expectEqualSlices(u8, "z" ** 20, dest[0..]);
    try writer.seekBy(-@as(i64, str.len)); // This is all that is in the buffer
    try testing.expectEqual(@as(u64, 5), try writer.getPos());
    try testing.expectEqualSlices(u8, "z" ** 20, dest[0..]);
    try writer.seekBy(-5); // Seeking bellow the buffer will do a flush
    try testing.expectEqual(@as(u64, 0), try writer.getPos());
    try testing.expectEqualSlices(u8, "zzzzz" ++ str, dest[0 .. str.len + 5]);
    try writer.writeAll(str[0..5]);
    try testing.expectEqual(@as(u64, 5), try writer.getPos());
    try testing.expectEqualSlices(u8, "zzzzz" ++ str, dest[0 .. str.len + 5]);
    try buf_writer.flush();
    try testing.expectEqualSlices(u8, "This " ++ str, dest[0 .. str.len + 5]);
}
