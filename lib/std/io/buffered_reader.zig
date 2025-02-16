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
        pub const GenericPeeker = io.GenericPeeker(*Self, Error, peek);

        const Self = @This();

        pub fn read(self: *Self, dest: []u8) Error!usize {
            // First try reading from the already buffered data onto the destination.
            const current = self.buf[self.start..self.end];
            if (current.len != 0) {
                const to_transfer = @min(current.len, dest.len);
                @memcpy(dest[0..to_transfer], current[0..to_transfer]);
                self.start += to_transfer;
                return to_transfer;
            }

            // If dest is large, read from the unbuffered reader directly into the destination.
            if (dest.len >= buffer_size) {
                return self.unbuffered_reader.read(dest);
            }

            // If dest is small, read from the unbuffered reader into our own internal buffer,
            // and then transfer to destination.
            self.end = try self.unbuffered_reader.read(&self.buf);
            const to_transfer = @min(self.end, dest.len);
            @memcpy(dest[0..to_transfer], self.buf[0..to_transfer]);
            self.start = to_transfer;
            return to_transfer;
        }

        /// Returns at most `buffer_size` bytes of data into `dest` without advancing the stream
        /// pointer, the data read is still available in the stream. Returning fewer than `dest.len`
        /// bytes is not an error. `0` is returned if the end of the stream has been reached.
        pub fn peek(self: *Self, dest: []u8) Error!usize {
            const nb_buffered_bytes = self.end - self.start;

            if (dest.len <= nb_buffered_bytes) {
                // Fulfill the peek from the buffer.
                @memcpy(dest, self.buf[self.start..self.end][0..dest.len]);
                return dest.len;
            }

            // Trying to fulfill the peek by reading more into the buffer without moving is not a
            // worthwhile tradeoff. This always leads to more calls to `read`, in the worst case,
            // syscalls, which we would like to avoid. `copyForwards` is cheap in comparison. In the
            // best case, read doesn't require a syscall, and most likely, peek is already
            // implemented by the unbuffered reader.

            // Move the available data to the start of the buffer.
            if (self.start != 0)
                std.mem.copyForwards(u8, self.buf[0..nb_buffered_bytes], self.buf[self.start..self.end]);

            self.end = nb_buffered_bytes;
            self.start = 0;

            // Because peeking isn't a stream, we can't simply ask the user to re-peek if `read`
            // returns fewer bytes than is required for `dest` to be filled, so, we always try to
            // read repeatedly for `dest` to be full. However, in line with `read`, we do not try to
            // fill the buffer completely by calling read repeatedly.

            const desired_minimum_nb_bytes_read = dest.len - nb_buffered_bytes;

            while (self.end - nb_buffered_bytes < desired_minimum_nb_bytes_read) {
                const nb_bytes_read = try self.unbuffered_reader.read(self.buf[self.end..]);

                if (nb_bytes_read == 0)
                    break; // EOS

                self.end += nb_bytes_read;
            }

            const nb_bytes_result = @min(self.end, dest.len);
            @memcpy(dest[0..nb_bytes_result], self.buf[0..nb_bytes_result]);
            return nb_bytes_result;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn peeker(self: *Self) GenericPeeker {
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
        const reader = test_buf_reader.reader();
        var out_buf: [4]u8 = undefined;
        _ = try reader.readAll(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        _ = try reader.readAll(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        try testing.expectEqual(try reader.readAll(&out_buf), 0);
    }

    // len out < block
    {
        var test_buf_reader: BufferedReader(4, BlockReader) = .{
            .unbuffered_reader = BlockReader.init(block, 2),
        };
        const reader = test_buf_reader.reader();
        var out_buf: [3]u8 = undefined;
        _ = try reader.readAll(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, "012");
        _ = try reader.readAll(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, "301");
        const n = try reader.readAll(&out_buf);
        try testing.expectEqualSlices(u8, out_buf[0..n], "23");
        try testing.expectEqual(try reader.readAll(&out_buf), 0);
    }

    // len out > block
    {
        var test_buf_reader: BufferedReader(4, BlockReader) = .{
            .unbuffered_reader = BlockReader.init(block, 2),
        };
        const reader = test_buf_reader.reader();
        var out_buf: [5]u8 = undefined;
        _ = try reader.readAll(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, "01230");
        const n = try reader.readAll(&out_buf);
        try testing.expectEqualSlices(u8, out_buf[0..n], "123");
        try testing.expectEqual(try reader.readAll(&out_buf), 0);
    }

    // len out == 0
    {
        var test_buf_reader: BufferedReader(4, BlockReader) = .{
            .unbuffered_reader = BlockReader.init(block, 2),
        };
        const reader = test_buf_reader.reader();
        var out_buf: [0]u8 = undefined;
        _ = try reader.readAll(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, "");
    }

    // len bufreader buf > block
    {
        var test_buf_reader: BufferedReader(5, BlockReader) = .{
            .unbuffered_reader = BlockReader.init(block, 2),
        };
        const reader = test_buf_reader.reader();
        var out_buf: [4]u8 = undefined;
        _ = try reader.readAll(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        _ = try reader.readAll(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        try testing.expectEqual(try reader.readAll(&out_buf), 0);
    }
}

test "peek BufferedReader with FixedBufferStream" {
    var fbs = io.fixedBufferStream("meow mrow grrr");
    var test_buf = bufferedReaderSize(5, fbs.reader());
    var tmp: [5]u8 = undefined;

    try std.testing.expectEqual(try test_buf.peek(tmp[0..1]), 1);
    try std.testing.expectEqualStrings(tmp[0..1], "m");

    try std.testing.expectEqual(try test_buf.peek(tmp[0..2]), 2);
    try std.testing.expectEqualStrings(tmp[0..2], "me");

    try std.testing.expectEqual(try test_buf.peek(tmp[0..5]), 5);
    try std.testing.expectEqualStrings(tmp[0..5], "meow ");

    try std.testing.expectEqual(try test_buf.read(tmp[0..1]), 1);
    try std.testing.expectEqualStrings(tmp[0..1], "m");

    try std.testing.expectEqual(try test_buf.peek(tmp[0..4]), 4);
    try std.testing.expectEqualStrings(tmp[0..4], "eow ");

    // requires move and read
    try std.testing.expectEqual(try test_buf.peek(tmp[0..5]), 5);
    try std.testing.expectEqualStrings(tmp[0..5], "eow m");

    // clear buffer completely
    try std.testing.expectEqual(try test_buf.read(tmp[0..5]), 5);
    try std.testing.expectEqualStrings(tmp[0..5], "eow m");

    try std.testing.expectEqual(try test_buf.peek(tmp[0..5]), 5);
    try std.testing.expectEqualStrings(tmp[0..5], "row g");
}
