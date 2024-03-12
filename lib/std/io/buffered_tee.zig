const std = @import("std");
const io = std.io;
const assert = std.debug.assert;
const testing = std.testing;

/// BufferedTee provides reader interface to the consumer. Data read by consumer
/// is also written to the output. Output is hold lookahead_size bytes behind
/// consumer. Allowing consumer to put back some bytes to be read again. On flush
/// all consumed bytes are flushed to the output.
///
///       input   ->   tee   ->   consumer
///                     |
///                  output
///
/// input - underlying unbuffered reader
/// output - writer, receives data read by consumer
/// consumer - uses provided reader interface
///
/// If lookahead_size is zero output always has same bytes as consumer.
///
pub fn BufferedTee(
    comptime buffer_size: usize, // internal buffer size in bytes
    comptime lookahead_size: usize, // lookahead, number of bytes to hold output behind consumer
    comptime InputReaderType: type,
    comptime OutputWriterType: type,
) type {
    comptime assert(buffer_size > lookahead_size);

    return struct {
        input: InputReaderType,
        output: OutputWriterType,

        buf: [buffer_size]u8 = undefined, // internal buffer
        tail: usize = 0, // buffer is filled up to this position with bytes from input
        rp: usize = 0, // reader pointer; consumer has read up to this position
        wp: usize = 0, // writer pointer; data is sent to the output up to this position

        pub const Error = InputReaderType.Error || OutputWriterType.Error;
        pub const Reader = io.Reader(*Self, Error, read);

        const Self = @This();

        pub fn read(self: *Self, dest: []u8) Error!usize {
            var dest_index: usize = 0;

            while (dest_index < dest.len) {
                const written = @min(dest.len - dest_index, self.tail - self.rp);
                if (written == 0) {
                    try self.preserveLookahead();
                    // fill upper part of the buf
                    const n = try self.input.read(self.buf[self.tail..]);
                    if (n == 0) {
                        // reading from the unbuffered stream returned nothing
                        // so we have nothing left to read.
                        return dest_index;
                    }
                    self.tail += n;
                } else {
                    @memcpy(dest[dest_index..][0..written], self.buf[self.rp..][0..written]);
                    self.rp += written;
                    dest_index += written;
                    try self.flush_(lookahead_size);
                }
            }
            return dest.len;
        }

        /// Move lookahead_size bytes to the buffer start.
        fn preserveLookahead(self: *Self) !void {
            assert(self.tail == self.rp);
            if (lookahead_size == 0) {
                // Flush is called on each read so wp must follow rp when lookahead_size == 0.
                assert(self.wp == self.rp);
                // Nothing to preserve rewind pointer to the buffer start
                self.rp = 0;
                self.wp = 0;
                self.tail = 0;
                return;
            }
            if (self.tail <= lookahead_size) {
                // There is still palce in the buffer, append to buffer from tail position.
                return;
            }
            try self.flush_(lookahead_size);
            const head = self.tail - lookahead_size;
            // Preserve head..tail at the start of the buffer.
            std.mem.copyForwards(u8, self.buf[0..lookahead_size], self.buf[head..self.tail]);
            self.wp -= head;
            assert(self.wp <= lookahead_size);
            self.rp = lookahead_size;
            self.tail = lookahead_size;
        }

        /// Flush to the output all but lookahead size bytes.
        fn flush_(self: *Self, lookahead: usize) !void {
            if (self.rp <= self.wp + lookahead) return;
            const new_wp = self.rp - lookahead;
            try self.output.writeAll(self.buf[self.wp..new_wp]);
            self.wp = new_wp;
        }

        /// Flush to the output all consumed bytes.
        pub fn flush(self: *Self) !void {
            try self.flush_(0);
        }

        /// Put back some bytes to be consumed again. Usefull when we overshoot
        /// reading and want to return that overshoot bytes. Can return maximum
        /// of lookahead_size number of bytes.
        pub fn putBack(self: *Self, n: usize) void {
            assert(n <= lookahead_size and n <= self.rp);
            self.rp -= n;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

pub fn bufferedTee(
    comptime buffer_size: usize,
    comptime lookahead_size: usize,
    input: anytype,
    output: anytype,
) BufferedTee(
    buffer_size,
    lookahead_size,
    @TypeOf(input),
    @TypeOf(output),
) {
    return .{ .input = input, .output = output };
}

// Running test from std.io.BufferedReader on BufferedTee
// It should act as BufferedReader for consumer.

fn BufferedReader(comptime buffer_size: usize, comptime ReaderType: type) type {
    return BufferedTee(buffer_size, 0, ReaderType, @TypeOf(io.null_writer));
}

fn bufferedReader(reader: anytype) BufferedReader(4096, @TypeOf(reader)) {
    return .{
        .input = reader,
        .output = io.null_writer,
    };
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
            .input = BlockReader.init(block, 2),
            .output = io.null_writer,
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
            .input = BlockReader.init(block, 2),
            .output = io.null_writer,
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
            .input = BlockReader.init(block, 2),
            .output = io.null_writer,
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
            .input = BlockReader.init(block, 2),
            .output = io.null_writer,
        };
        var out_buf: [0]u8 = undefined;
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, "");
    }

    // len bufreader buf > block
    {
        var test_buf_reader: BufferedReader(5, BlockReader) = .{
            .input = BlockReader.init(block, 2),
            .output = io.null_writer,
        };
        var out_buf: [4]u8 = undefined;
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        try testing.expectEqual(try test_buf_reader.read(&out_buf), 0);
    }
}

test "with zero lookahead" {
    // output has same bytes as consumer
    const data = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 } ** 12;
    var in = io.fixedBufferStream(&data);
    var out = std.ArrayList(u8).init(testing.allocator);
    defer out.deinit();

    var bt = bufferedTee(8, 0, in.reader(), out.writer());

    var buf: [16]u8 = undefined;
    var read_len: usize = 0;
    for (0..buf.len) |i| {
        const n = try bt.read(buf[0..i]);
        try testing.expectEqual(i, n);
        read_len += i;
        try testing.expectEqual(read_len, out.items.len);
    }
}

test "with lookahead" {
    // output is lookahead bytes behind consumer
    inline for (1..8) |lookahead| {
        const data = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 } ** 12;
        var in = io.fixedBufferStream(&data);
        var out = std.ArrayList(u8).init(testing.allocator);
        defer out.deinit();

        var bt = bufferedTee(8, lookahead, in.reader(), out.writer());
        var buf: [16]u8 = undefined;

        var read_len: usize = 0;
        for (1..buf.len) |i| {
            const n = try bt.read(buf[0..i]);
            try testing.expectEqual(i, n);
            read_len += i;
            const out_len = if (read_len < lookahead) 0 else read_len - lookahead;
            try testing.expectEqual(out_len, out.items.len);
        }
        try testing.expectEqual(read_len, out.items.len + lookahead);
        try bt.flush();
        try testing.expectEqual(read_len, out.items.len);
    }
}

test "internal state" {
    const data = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 } ** 2;
    var in = io.fixedBufferStream(&data);
    var out = std.ArrayList(u8).init(testing.allocator);
    defer out.deinit();

    var bt = bufferedTee(8, 4, in.reader(), out.writer());

    var buf: [16]u8 = undefined;
    var n = try bt.read(buf[0..3]);
    try testing.expectEqual(3, n);
    try testing.expectEqualSlices(u8, data[0..3], buf[0..n]);
    try testing.expectEqual(8, bt.tail);
    try testing.expectEqual(3, bt.rp);
    try testing.expectEqual(0, out.items.len);

    n = try bt.read(buf[0..6]);
    try testing.expectEqual(6, n);
    try testing.expectEqualSlices(u8, data[3..9], buf[0..n]);
    try testing.expectEqual(8, bt.tail);
    try testing.expectEqual(5, bt.rp);
    try testing.expectEqualSlices(u8, data[4..12], &bt.buf);
    try testing.expectEqual(5, out.items.len);

    n = try bt.read(buf[0..9]);
    try testing.expectEqual(9, n);
    try testing.expectEqualSlices(u8, data[9..18], buf[0..n]);
    try testing.expectEqual(8, bt.tail);
    try testing.expectEqual(6, bt.rp);
    try testing.expectEqualSlices(u8, data[12..20], &bt.buf);
    try testing.expectEqual(14, out.items.len);

    try bt.flush();
    try testing.expectEqual(18, out.items.len);

    bt.putBack(4);
    n = try bt.read(buf[0..4]);
    try testing.expectEqual(4, n);
    try testing.expectEqualSlices(u8, data[14..18], buf[0..n]);

    try testing.expectEqual(18, out.items.len);
    try bt.flush();
    try testing.expectEqual(18, out.items.len);
}
