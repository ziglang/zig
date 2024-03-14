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

        /// Peek reads bytes into `dest` and returns the amount read without advancing the reader.
        /// If the `dest` size is too small for the desired peek amount, partially fill `dest`
        /// with as much data as fits.
        /// The minimum amount that will always be available for peeking is the BufferedReader's `buffer_size`.
        pub fn peek(self: *Self, dest: []u8) !usize {
            if (dest.len <= self.end - self.start) {
                // Already enough read.
                @memcpy(dest, self.buf[self.start..][0..dest.len]);
                return dest.len;
            }
            if (dest.len > self.buf.len - self.start) {
                // Shift buffer's data to free up as much room as available.
                std.mem.copyForwards(u8, &self.buf, self.buf[self.start..self.end]);
                self.end -= self.start;
                self.start = 0;
            }
            const n = try self.unbuffered_reader.read(self.buf[self.end..]);
            self.end += n;
            const peeked = @min(dest.len, self.end - self.start);
            @memcpy(dest[0..peeked], self.buf[self.start..][0..peeked]);
            return peeked;
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
    {
        // peek before read
        var br = bufferedReader(fbs.reader());
        var out: [2]u8 = undefined;

        const p = try br.peek(out[0..]);
        try testing.expectEqualSlices(u8, "ab", out[0..p]);

        const n = try br.read(out[0..]);
        try testing.expectEqualSlices(u8, "ab", out[0..n]);
    }
    {
        // peek after read
        fbs.reset();
        var br = bufferedReader(fbs.reader());
        var out: [2]u8 = undefined;

        _ = try br.read(out[0..]);

        const p = try br.peek(out[0..]);
        try testing.expectEqualSlices(u8, "cd", out[0..p]);
    }
    {
        // multiple peeks
        fbs.reset();
        var br = bufferedReader(fbs.reader());
        var out: [4]u8 = undefined;

        const p1 = try br.peek(out[0..2]);
        try testing.expectEqualSlices(u8, "ab", out[0..p1]);

        const p2 = try br.peek(out[0..4]);
        try testing.expectEqualSlices(u8, "abcd", out[0..p2]);

        const p3 = try br.peek(out[0..1]);
        try testing.expectEqualSlices(u8, "a", out[0..p3]);
    }

    {
        // over peek
        fbs.reset();
        var br = BufferedReader(8, @TypeOf(fbs.reader())){
            .unbuffered_reader = fbs.reader(),
        };
        var out: [8]u8 = undefined;

        _ = try br.read(out[0..2]);

        const p = try br.peek(out[0..]);
        try testing.expectEqualSlices(u8, "cdefgh", out[0..p]);
    }
}
