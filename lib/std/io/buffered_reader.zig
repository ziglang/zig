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

        pub usingnamespace if (@hasDecl(ReaderType, "seek_interface_id")) struct {
            pub const SeekError = ReaderType.SeekError;
            pub const GetSeekPosError = ReaderType.GetSeekPosError;
            pub const Reader = io.SeekableReader(*Self, Error, read);

            pub fn seekTo(self: *Self, pos: u64) SeekError!void {
                // We discard the buffer cause we can't know if we will end up within it
                self.start = 0;
                self.end = 0;
                return self.unbuffered_reader.seekTo(pos);
            }

            pub fn seekBy(self: *Self, amt: i64) SeekError!void {
                if (amt < 0) {
                    const abs_amt = std.math.absCast(amt);
                    const abs_amt_usize = std.math.cast(usize, abs_amt) orelse std.math.maxInt(usize);
                    if (abs_amt_usize > self.start) {
                        try self.unbuffered_reader.seekBy(amt + @intCast(i64, self.start));
                        self.start = 0;
                        self.end = 0;
                    } else {
                        self.start -= abs_amt_usize;
                    }
                } else {
                    const amt_usize = std.math.cast(usize, amt) orelse std.math.maxInt(usize);
                    const new_pos = self.start +| amt_usize;
                    if (new_pos > self.end) {
                        try self.unbuffered_reader.seekBy(@intCast(i64, new_pos - self.end));
                        self.start = 0;
                        self.end = 0;
                    } else {
                        self.start = new_pos;
                    }
                }
            }

            pub fn getEndPos(self: *Self) GetSeekPosError!u64 {
                return self.unbuffered_reader.getEndPos();
            }

            pub fn getPos(self: *Self) GetSeekPosError!u64 {
                return (try self.unbuffered_reader.getPos()) - (self.end - self.start);
            }

            pub fn reader(self: *Self) Reader {
                return .{ .context = self };
            }
        } else struct {
            pub const Reader = io.Reader(*Self, Error, read);

            pub fn reader(self: *Self) Reader {
                return .{ .context = self };
            }
        };

        const Self = @This();

        pub fn read(self: *Self, dest: []u8) Error!usize {
            const size = dest.len;
            const available = self.end - self.start;
            if (available >= size) {
                const endPos = self.start + size;
                std.mem.copy(u8, dest[0..], self.buf[self.start..endPos]);
                self.start = endPos;
                return size;
            }

            std.mem.copy(u8, dest[0..available], self.buf[self.start..self.end]);
            self.start = 0;
            self.end = 0;
            var remaining_size = size - available;
            if (remaining_size >= self.buf.len) {
                return available + try self.unbuffered_reader.read(dest[available..]);
            }

            self.end = try self.unbuffered_reader.read(self.buf[0..]);
            if (remaining_size > self.end) remaining_size = self.end;
            std.mem.copy(u8, dest[available .. available + remaining_size], self.buf[0..remaining_size]);
            self.start = remaining_size;
            return available + remaining_size;
        }
    };
}

pub fn bufferedReader(reader: anytype) BufferedReader(4096, @TypeOf(reader)) {
    return .{ .unbuffered_reader = reader };
}

pub fn bufferedReaderSize(comptime size: usize, reader: anytype) BufferedReader(size, @TypeOf(reader)) {
    return .{ .unbuffered_reader = reader };
}

test "io.BufferedReader OneByte" {
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
test "io.BufferedReader Block" {
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
            if (self.curr_read >= self.reads_allowed) {
                return 0;
            }
            std.debug.assert(dest.len >= self.block.len);
            std.mem.copy(u8, dest, self.block);

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
        var block_reader = BlockReader.init(block, 2);
        var test_buf_reader = BufferedReader(4, BlockReader){ .unbuffered_reader = block_reader };
        var out_buf: [4]u8 = undefined;
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        try testing.expectEqual(try test_buf_reader.read(&out_buf), 0);
    }

    // len out < block
    {
        var block_reader = BlockReader.init(block, 2);
        var test_buf_reader = BufferedReader(4, BlockReader){ .unbuffered_reader = block_reader };
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
        var block_reader = BlockReader.init(block, 2);
        var test_buf_reader = BufferedReader(4, BlockReader){ .unbuffered_reader = block_reader };
        var out_buf: [5]u8 = undefined;
        const n1 = try test_buf_reader.read(&out_buf);
        try testing.expectEqual(@as(usize, 4), n1);
        try testing.expectEqualSlices(u8, out_buf[0..n1], "0123");
        const n2 = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, out_buf[0..n2], "0123");
        try testing.expectEqual(try test_buf_reader.read(&out_buf), 0);
    }

    // len out == 0
    {
        var block_reader = BlockReader.init(block, 2);
        var test_buf_reader = BufferedReader(4, BlockReader){ .unbuffered_reader = block_reader };
        var out_buf: [0]u8 = undefined;
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, "");
    }

    // len bufreader buf > block
    {
        var block_reader = BlockReader.init(block, 2);
        var test_buf_reader = BufferedReader(5, BlockReader){ .unbuffered_reader = block_reader };
        var out_buf: [4]u8 = undefined;
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        try testing.expectEqual(try test_buf_reader.read(&out_buf), 0);
    }
}

test "io.SeekableBufferedReader" {
    const str = "This is a test";
    var stream = io.fixedBufferStream(str);

    var buf_reader = bufferedReader(stream.reader());
    const reader = buf_reader.reader();

    var buffer: [str.len]u8 = undefined;
    try testing.expectEqual(@as(u64, 0), try reader.getPos());
    var res = try reader.readAll(buffer[0..]);
    try testing.expectEqual(@as(u64, str.len), try reader.getPos());
    try testing.expectEqual(str.len, res);
    try testing.expectEqualSlices(u8, str, buffer[0..]);
    try reader.seekTo(0);
    try testing.expectEqual(@as(u64, 0), try reader.getPos());
    std.mem.set(u8, buffer[0..], 0);
    res = try reader.readAll(buffer[0..4]);
    try testing.expectEqual(@as(u64, 4), try reader.getPos());
    try testing.expectEqual(@as(usize, 4), res);
    try reader.seekBy(3);
    try testing.expectEqual(@as(u64, 7), try reader.getPos());
    res = try reader.readAll(buffer[4..]);
    try testing.expectEqual(@as(u64, 14), try reader.getPos());
    try testing.expectEqual(@as(usize, 7), res);
    try reader.seekBy(-10);
    try testing.expectEqual(@as(u64, 4), try reader.getPos());
    res = try reader.readAll(buffer[11..]);
    try testing.expectEqual(@as(u64, 7), try reader.getPos());
    try testing.expectEqual(@as(usize, 3), res);
    try testing.expectEqualSlices(u8, "This a test is", buffer[0..]);
}
