const std = @import("../std.zig");
const io = std.io;
const mem = std.mem;
const assert = std.debug.assert;
const testing = std.testing;

pub fn BufferedReader(comptime buffer_size: usize, comptime ReaderType: type) type {
    return struct {
        unbuffered_reader: ReaderType,
        buf: [buffer_size]u8 = undefined,
        start: usize = 0,
        end: usize = 0,

        pub const Error = ReaderType.Error;
        pub const Reader = io.Reader(*Self, Error, read);

        const Self = @This();

        pub fn read(self: *Self, dest: []u8) Error!usize {
            var dest_index: usize = 0;

            while (dest_index < dest.len) {
                const written = @min(dest.len - dest_index, self.end - self.start);
                @memcpy(dest[dest_index..][0..written], self.buf[self.start..][0..written]);
                if (written == 0) {
                    // buf empty, fill it
                    const n = try self.unbuffered_reader.read(self.buf[0..]);
                    if (n == 0) {
                        // reading from the unbuffered stream returned nothing
                        // so we have nothing left to read.
                        return dest_index;
                    }
                    self.start = 0;
                    self.end = n;
                }
                self.start += written;
                dest_index += written;
            }
            return dest.len;
        }

        pub const PeekError = Error || error{EndOfStream};

        /// Returns the next `n` bytes without advancing.
        ///
        /// The returned slice is a subslice of the buffer, which may or may not start
        /// from the beginning. The length of the returned slice is always `n`.
        ///
        /// Asserts that the number of requested bytes is less than or equal to the
        /// buffer size.
        pub fn peek(self: *Self, n: usize) PeekError![]u8 {
            assert(n <= buffer_size);
            if (n > self.end - self.start) {
                if (n > buffer_size - self.start) {
                    std.mem.copyForwards(u8, &self.buf, self.buf[self.start..self.end]);
                    self.end -= self.start;
                    self.start = 0;
                }
                self.end += try self.unbuffered_reader.read(self.buf[self.end..]);
            }
            return self.buf[self.start..][0..n];
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

pub fn bufferedReader(reader: anytype) BufferedReader(4096, @TypeOf(reader)) {
    return .{ .unbuffered_reader = reader };
}

pub fn bufferedReaderSize(comptime size: usize, reader: anytype) BufferedReader(size, @TypeOf(reader)) {
    return .{ .unbuffered_reader = reader };
}

test "OneByte" {
    const OneByteReadReader = struct {
        str: []const u8,
        curr: usize,

        const Error = error{NoError};
        const Self = @This();
        const Reader = io.Reader(*Self, Error, read);

        fn init(str: []const u8) Self {
            return Self{
                .str = str,
                .curr = 0,
            };
        }

        fn read(self: *Self, dest: []u8) Error!usize {
            if (self.str.len <= self.curr or dest.len == 0)
                return 0;

            dest[0] = self.str[self.curr];
            self.curr += 1;
            return 1;
        }

        fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };

    const str = "This is a test";
    var one_byte_stream = OneByteReadReader.init(str);
    var buf_reader = bufferedReader(one_byte_stream.reader());
    const stream = buf_reader.reader();

    const res = try stream.readAllAlloc(testing.allocator, str.len + 1);
    defer testing.allocator.free(res);
    try testing.expectEqualSlices(u8, str, res);
}

fn smallBufferedReader(underlying_stream: anytype) BufferedReader(8, @TypeOf(underlying_stream)) {
    return .{ .unbuffered_reader = underlying_stream };
}
test "Block" {
    const BlockReader = struct {
        block: []const u8,
        reads_allowed: usize,
        curr_read: usize,

        const Error = error{NoError};
        const Self = @This();
        const Reader = io.Reader(*Self, Error, read);

        fn init(block: []const u8, reads_allowed: usize) Self {
            return Self{
                .block = block,
                .reads_allowed = reads_allowed,
                .curr_read = 0,
            };
        }

        fn read(self: *Self, dest: []u8) Error!usize {
            if (self.curr_read >= self.reads_allowed) return 0;
            @memcpy(dest[0..self.block.len], self.block);

            self.curr_read += 1;
            return self.block.len;
        }

        fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };

    const block = "0123";

    // len out == block
    {
        var test_buf_reader: BufferedReader(4, BlockReader) = .{
            .unbuffered_reader = BlockReader.init(block, 2),
        };
        var out_buf: [4]u8 = undefined;
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        try testing.expectEqual(try test_buf_reader.read(&out_buf), 0);
    }

    // len out < block
    {
        var test_buf_reader: BufferedReader(4, BlockReader) = .{
            .unbuffered_reader = BlockReader.init(block, 2),
        };
        var out_buf: [3]u8 = undefined;
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, "012");
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, "301");
        const n = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, out_buf[0..n], "23");
        try testing.expectEqual(try test_buf_reader.read(&out_buf), 0);
    }

    // len out > block
    {
        var test_buf_reader: BufferedReader(4, BlockReader) = .{
            .unbuffered_reader = BlockReader.init(block, 2),
        };
        var out_buf: [5]u8 = undefined;
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, "01230");
        const n = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, out_buf[0..n], "123");
        try testing.expectEqual(try test_buf_reader.read(&out_buf), 0);
    }

    // len out == 0
    {
        var test_buf_reader: BufferedReader(4, BlockReader) = .{
            .unbuffered_reader = BlockReader.init(block, 2),
        };
        var out_buf: [0]u8 = undefined;
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, "");
    }

    // len bufreader buf > block
    {
        var test_buf_reader: BufferedReader(5, BlockReader) = .{
            .unbuffered_reader = BlockReader.init(block, 2),
        };
        var out_buf: [4]u8 = undefined;
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        try testing.expectEqual(try test_buf_reader.read(&out_buf), 0);
    }
}

test "BufferedReader.peek" {
    var fbs = io.fixedBufferStream("abcdefgh");
    const reader = fbs.reader();
    {
        // peek before read
        var br = bufferedReader(reader);

        const out = try br.peek(2);
        try testing.expectEqualSlices(u8, "ab", out);

        var buf: [2]u8 = undefined;
        _ = try br.read(&buf);
        try testing.expectEqualSlices(u8, "ab", &buf);
    }
    {
        // peek after read
        fbs.reset();
        var br = bufferedReader(reader);
        var buf: [2]u8 = undefined;

        _ = try br.read(&buf);

        const out = try br.peek(2);
        try testing.expectEqualSlices(u8, "cd", out);
    }
    {
        // peek after read with small buffer
        fbs.reset();
        var br = BufferedReader(4, @TypeOf(reader)){ .unbuffered_reader = reader };
        var buf: [2]u8 = undefined;

        _ = try br.read(&buf);

        const out = try br.peek(4);
        try testing.expectEqualSlices(u8, "cdef", out);
    }
    {
        // multiple peeks
        fbs.reset();
        var br = bufferedReader(reader);

        const out1 = try br.peek(2);
        try testing.expectEqualSlices(u8, "ab", out1);

        const out2 = try br.peek(4);
        try testing.expectEqualSlices(u8, "abcd", out2);

        const out3 = try br.peek(1);
        try testing.expectEqualSlices(u8, "a", out3);
    }
}
