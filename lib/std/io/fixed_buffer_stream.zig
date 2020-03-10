const std = @import("../std.zig");
const io = std.io;
const testing = std.testing;
const mem = std.mem;
const assert = std.debug.assert;

/// This turns a byte buffer into an `io.OutStream`, `io.InStream`, or `io.SeekableStream`.
/// If the supplied byte buffer is const, then `io.OutStream` is not available.
pub fn FixedBufferStream(comptime Buffer: type) type {
    return struct {
        /// `Buffer` is either a `[]u8` or `[]const u8`.
        buffer: Buffer,
        pos: usize,

        pub const ReadError = error{EndOfStream};
        pub const WriteError = error{OutOfMemory};
        pub const SeekError = error{EndOfStream};
        pub const GetSeekPosError = error{};

        pub const InStream = io.InStream(*Self, ReadError, read);
        pub const OutStream = io.OutStream(*Self, WriteError, write);

        pub const SeekableStream = io.SeekableStream(
            *Self,
            SeekError,
            GetSeekPosError,
            seekTo,
            seekBy,
            getPos,
            getEndPos,
        );

        const Self = @This();

        pub fn inStream(self: *Self) InStream {
            return .{ .context = self };
        }

        pub fn outStream(self: *Self) OutStream {
            return .{ .context = self };
        }

        pub fn seekableStream(self: *Self) SeekableStream {
            return .{ .context = self };
        }

        pub fn read(self: *Self, dest: []u8) ReadError!usize {
            const size = std.math.min(dest.len, self.buffer.len - self.pos);
            const end = self.pos + size;

            mem.copy(u8, dest[0..size], self.buffer[self.pos..end]);
            self.pos = end;

            if (size == 0) return error.EndOfStream;
            return size;
        }

        /// If the returned number of bytes written is less than requested, the
        /// buffer is full. Returns `error.OutOfMemory` when no bytes would be written.
        pub fn write(self: *Self, bytes: []const u8) WriteError!usize {
            if (bytes.len == 0) return 0;

            assert(self.pos <= self.buffer.len);

            const n = if (self.pos + bytes.len <= self.buffer.len)
                bytes.len
            else
                self.buffer.len - self.pos;

            mem.copy(u8, self.buffer[self.pos .. self.pos + n], bytes[0..n]);
            self.pos += n;

            if (n == 0) return error.OutOfMemory;

            return n;
        }

        pub fn seekTo(self: *Self, pos: u64) SeekError!void {
            const usize_pos = std.math.cast(usize, pos) catch return error.EndOfStream;
            if (usize_pos > self.buffer.len) return error.EndOfStream;
            self.pos = usize_pos;
        }

        pub fn seekBy(self: *Self, amt: i64) SeekError!void {
            if (amt < 0) {
                const abs_amt = std.math.cast(usize, -amt) catch return error.EndOfStream;
                if (abs_amt > self.pos) return error.EndOfStream;
                self.pos -= abs_amt;
            } else {
                const usize_amt = std.math.cast(usize, amt) catch return error.EndOfStream;
                if (self.pos + usize_amt > self.buffer.len) return error.EndOfStream;
                self.pos += usize_amt;
            }
        }

        pub fn getEndPos(self: *Self) GetSeekPosError!u64 {
            return self.buffer.len;
        }

        pub fn getPos(self: *Self) GetSeekPosError!u64 {
            return self.pos;
        }

        pub fn getWritten(self: Self) []const u8 {
            return self.buffer[0..self.pos];
        }

        pub fn reset(self: *Self) void {
            self.pos = 0;
        }
    };
}

pub fn fixedBufferStream(buffer: var) FixedBufferStream(NonSentinelSpan(@TypeOf(buffer))) {
    return .{ .buffer = mem.span(buffer), .pos = 0 };
}

fn NonSentinelSpan(comptime T: type) type {
    var ptr_info = @typeInfo(mem.Span(T)).Pointer;
    ptr_info.sentinel = null;
    return @Type(std.builtin.TypeInfo{ .Pointer = ptr_info });
}

test "FixedBufferStream output" {
    var buf: [255]u8 = undefined;
    var fbs = fixedBufferStream(&buf);
    const stream = fbs.outStream();

    try stream.print("{}{}!", .{ "Hello", "World" });
    testing.expectEqualSlices(u8, "HelloWorld!", fbs.getWritten());
}

test "FixedBufferStream output 2" {
    var buffer: [10]u8 = undefined;
    var fbs = fixedBufferStream(&buffer);

    try fbs.outStream().writeAll("Hello");
    testing.expect(mem.eql(u8, fbs.getWritten(), "Hello"));

    try fbs.outStream().writeAll("world");
    testing.expect(mem.eql(u8, fbs.getWritten(), "Helloworld"));

    testing.expectError(error.OutOfMemory, fbs.outStream().writeAll("!"));
    testing.expect(mem.eql(u8, fbs.getWritten(), "Helloworld"));

    fbs.reset();
    testing.expect(fbs.getWritten().len == 0);

    testing.expectError(error.OutOfMemory, fbs.outStream().writeAll("Hello world!"));
    testing.expect(mem.eql(u8, fbs.getWritten(), "Hello worl"));
}

test "FixedBufferStream input" {
    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6, 7 };
    var fbs = fixedBufferStream(&bytes);

    var dest: [4]u8 = undefined;

    var read = try fbs.inStream().read(dest[0..4]);
    testing.expect(read == 4);
    testing.expect(mem.eql(u8, dest[0..4], bytes[0..4]));

    read = try fbs.inStream().read(dest[0..4]);
    testing.expect(read == 3);
    testing.expect(mem.eql(u8, dest[0..3], bytes[4..7]));

    testing.expectError(error.EndOfStream, fbs.inStream().read(dest[0..4]));
}
