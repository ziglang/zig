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
            // This functions has 3 steps:
            // 1- Dump the already buffered data onto the destination.
            // 2- Read from the unbuffered reader directly into the destination,
            //    until we are close the end.
            // 3- Read from the unbuffered reader into our own internal buffer,
            //    and dump the final data onto destination.

            // Step 1- Dump the already buffered data onto the destination.
            const current = self.buf[self.start..self.end];
            if (dest.len <= current.len) {
                // If we have enough buffered data to fulfill the request, we are done.
                @memcpy(dest, current[0..dest.len]);
                self.start += dest.len;
                return dest.len;
            }
            // Otherwise, dump whatever we have onto the destination and move on
            // to the next steps.
            @memcpy(dest[0..current.len], current[0..current.len]);

            // This marks that we don't have any buffered data. If we exit early,
            // the reader is in a valid state.
            self.start = self.end;

            // Step 2- Read from the unbuffered reader directly into the destination,
            //         until we are close the end.
            var remaining_dest = dest[current.len..];
            while (remaining_dest.len > buffer_size) {
                const n = self.unbuffered_reader.read(remaining_dest) catch |err| {
                    // If we already dumped something onto the destination, we are not going
                    // to report an error.
                    const bytes_read = dest.len - remaining_dest.len;

                    return if (bytes_read == 0)
                        err
                    else
                        bytes_read;
                };
                if (n == 0) {
                    // reading from the unbuffered stream returned nothing,
                    // so we have nothing left to read.
                    return dest.len - remaining_dest.len;
                }
                remaining_dest = remaining_dest[n..];
            }

            // Step 3- Read from the unbuffered reader into our own internal buffer,
            //         and dump the final data onto destination.
            // We are going to keep reading until we have at least fulfilled the request.
            // Hopefully we'll have something buffered for the next call.
            while (true) {
                self.end = self.unbuffered_reader.read(&self.buf) catch |err| {
                    // Since we have been using self.end, we need to reset the state
                    // of the buffer to indicate we have nothing buffered.
                    self.start = 0;
                    self.end = 0;

                    // If we already dumped something onto the destination, we are not going
                    // to report an error.
                    const bytes_read = dest.len - remaining_dest.len;
                    return if (bytes_read == 0)
                        err
                    else
                        bytes_read;
                };
                if (self.end == 0) {
                    // reading from the unbuffered stream returned nothing,
                    // so we have nothing left to read.
                    self.start = 0;
                    return dest.len - remaining_dest.len;
                } else if (self.end < remaining_dest.len) {
                    // We got some data, but no enough to fulfill the request.
                    @memcpy(remaining_dest[0..self.end], self.buf[0..self.end]);
                    remaining_dest = remaining_dest[self.end..];
                } else {
                    // We have enough data to fulfill the request, and we may have
                    // some buffered data left.
                    @memcpy(remaining_dest, self.buf[0..remaining_dest.len]);
                    self.start = remaining_dest.len;
                    return dest.len;
                }
            }
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
