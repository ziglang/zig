const std = @import("../std.zig");
const io = std.io;
const mem = std.mem;
const meta = std.meta;
const assert = std.debug.assert;
const testing = std.testing;

pub fn TokenIterator(comptime Context: type, comptime delimiter_type: mem.DelimiterType) type {
    return struct {
        context: Context,
        delimiter: switch (delimiter_type) {
            .sequence, .any => []const u8,
            .scalar => u8,
        },
        lastpos: usize,

        const Self = @This();

        /// Returns a slice of the current token, or null if tokenization is
        /// complete, and advances to the next token.
        /// If the underlying buffer is smaller than the token length,
        /// token will be truncated to buffer length each time `next` called.
        pub fn next(self: *Self) ?[]const u8 {
            if (self.lastpos > self.context.start) {
                self.context.discard(self.lastpos - self.context.start) catch return null;
            }

            const delimiter_len = switch (delimiter_type) {
                .sequence => self.delimiter.len,
                .any, .scalar => 1,
            };

            var start: usize = 0;
            var end: usize = 0;
            var buffer: []const u8 = undefined;
            while (true) {
                var index: usize = 0;
                buffer = self.context.peek(0) catch return null;
                while (index < buffer.len and self.isDelimiter(buffer, index)) {
                    index += delimiter_len;
                    if (index >= buffer.len) {
                        self.context.discard(buffer.len) catch return null;
                        buffer = self.context.peek(0) catch return null;
                        index = 0;
                    }
                }

                start = index;
                if (start == buffer.len) {
                    self.context.discard(buffer.len) catch return null;
                    return null;
                }

                // move to end of token
                end = start;
                while (end < buffer.len and !self.isDelimiter(buffer, end)) : (end += 1) {}

                if (end < buffer.len) {
                    break;
                }

                // Grab one more byte
                const newbuf = self.context.peek(buffer.len + 1) catch return null;
                if (newbuf.len == buffer.len) {
                    break;
                }
            }

            self.lastpos = self.context.start + end;
            return buffer[start..end];
        }

        fn isDelimiter(self: Self, buffer: []const u8, index: usize) bool {
            switch (delimiter_type) {
                .sequence => return mem.startsWith(u8, buffer[index..], self.delimiter),
                .any => {
                    return mem.indexOfScalar(u8, self.delimiter, buffer[index]) != null;
                },
                .scalar => return buffer[index] == self.delimiter,
            }
        }
    };
}

/// A Reader that has a buffer to cache the underlying reader data,
/// and may have an extra buffer to push back previous read data.
/// Application can inspect the buffer directly to eliminate data copy.
pub fn BufferedReader(comptime buffer_size: usize, comptime pushback_size: usize, comptime ReaderType: type) type {
    return struct {
        unbuffered_reader: ReaderType,
        buf: [mem.alignForward(usize, pushback_size + buffer_size, @sizeOf(usize))]u8 = undefined,
        pushback: usize = 0,
        start: usize = 0,
        end: usize = 0,

        pub const ReaderContainer = if (meta.trait.isContainer(ReaderType)) ReaderType else meta.Child(ReaderType);
        pub const Error = if (@hasDecl(ReaderContainer, "ReadError")) ReaderContainer.ReadError else ReaderContainer.Error;
        pub const Reader = io.Reader(*Self, Error, read);

        const Self = @This();

        /// Returns the buffered data slice to application directly. Application can later
        /// read the data again by `read`, or forward the buffered data cursor by `discard`.
        ///
        /// If the `least` param is zero, it will return the entire buffered data slice.
        /// If the returned slice length is lesser than `least`, it means the reader had reached end.
        /// It will automatically fill buffer if buffer is empty or buffered data
        /// is less than the request `least` length.
        /// If peek bytes length is zero, it returns `error.EndOfStream`.
        ///
        /// If this method was used with pushback buffer, data move may occur
        /// when there is a hole in the buffer.
        pub fn peek(self: *Self, least: usize) ![]const u8 {
            if (self.start == self.end) {
                self.start = 0;
                self.end = 0;
                const n = try self.unbuffered_reader.read(self.buf[pushback_size..]);
                self.end += n;
            }
            var remain = self.end - self.start;
            if (least > remain) {
                const delta = least - remain;
                if (self.start > 0 and (self.buf.len - self.end < delta)) {
                    std.mem.copyForwards(u8, self.buf[pushback_size..][0..remain], self.buf[pushback_size..][self.start..self.end]);
                    self.start = 0;
                    self.end = remain;
                }
                var nread: usize = 0;
                while (nread < delta) {
                    const n = try self.unbuffered_reader.read(self.buf[pushback_size..][self.end..]);
                    if (n == 0) break;
                    self.end += n;
                    nread += n;
                }
                remain = self.end - self.start;
            }

            var nsize: usize = if (least > 0) @min(least, remain) else remain;
            if (pushback_size == 0 or self.pushback == 0) {
                if (nsize == 0) {
                    return error.EndOfStream;
                }
                return self.buf[pushback_size..][self.start..(self.start + nsize)];
            }

            if (remain == 0 and self.end > 0) {
                self.start = 0;
                self.end = 0;
            } else if (self.start > 0 and remain > 0) {
                std.mem.copyForwards(u8, self.buf[pushback_size..][0..remain], self.buf[pushback_size..][self.start..self.end]);
                self.start = 0;
                self.end = remain;
            }
            remain += self.pushback;
            nsize = if (least > 0) @min(least, remain) else remain;
            if (nsize == 0) {
                return error.EndOfStream;
            }
            return self.buf[@intCast(pushback_size - self.pushback)..][0..nsize];
        }

        /// Discards the next `num` bytes in buffer, if the buffer bytes is less than `num`,
        /// it will fill the buffer at first.
        /// If discarded bytes is fewer than `num` bytes, it returns `error.EndOfStream`.
        pub fn discard(self: *Self, num: usize) (Error || error{EndOfStream})!void {
            var amt = num;
            while (amt > 0) {
                if (pushback_size > 0 and self.pushback > 0) {
                    const delta = @min(self.pushback, amt);
                    if (delta > 0) {
                        self.pushback -= delta;
                        amt -= delta;
                    }
                    if (amt == 0) return;
                }
                const delta = @min(self.end - self.start, amt);
                self.start += delta;
                amt -= delta;
                if (self.start == self.end and amt > 0) {
                    const n = try self.unbuffered_reader.read(self.buf[pushback_size..]);
                    if (n == 0) return error.EndOfStream;
                    self.start = 0;
                    self.end = n;
                }
            }
        }

        /// Pushes multiple byte `bytes` data back to buffer, then application can read this `bytes` agian.
        pub fn push(self: *Self, bytes: []const u8) error{NoSpaceLeft}!void {
            if (comptime pushback_size == 0) {
                @compileError("pushback buffer is empty, initialize BufferedReader with pushback_size greater than zero");
            }

            const avail: usize = @intCast(pushback_size - self.pushback);
            if (avail < bytes.len) {
                return error.NoSpaceLeft;
            }
            const written = @min(bytes.len, avail);
            @memcpy(self.buf[avail - written .. avail], bytes[bytes.len - written ..]);
            self.pushback += written;
            assert(self.pushback <= pushback_size);
        }

        /// Pushes single `byte` data back to buffer, then application can read this `byte` agian.
        pub fn pushByte(self: *Self, byte: u8) error{NoSpaceLeft}!void {
            try self.push(&[_]u8{byte});
        }

        pub fn read(self: *Self, dest: []u8) Error!usize {
            return self.readAtLeast(dest, 1);
        }

        /// Reads data from reader into `dest` buffer and returns bytes read, it will buffer data when needed.
        /// If read bytes returns 0, it means the reader had reached end.
        pub fn readAtLeast(self: *Self, dest: []u8, len: usize) Error!usize {
            var dest_index: usize = 0;
            var least = len;
            if (comptime pushback_size > 0) {
                if (self.pushback > 0) {
                    const written = @min(dest.len, self.pushback);
                    @memcpy(dest[dest_index..][0..written], self.buf[pushback_size - self.pushback .. pushback_size][0..written]);
                    if (len <= written) {
                        least = written + len;
                    }
                    dest_index = written;
                    self.pushback -= written;
                    assert(self.pushback >= 0);
                }
            }

            while (dest_index < least) {
                const written = @min(dest.len - dest_index, self.end - self.start);
                if (written > 0) {
                    @memcpy(dest[dest_index..][0..written], self.buf[pushback_size..][self.start..][0..written]);
                    self.start += written;
                    dest_index += written;
                    if (dest_index == dest.len) {
                        break;
                    }
                }

                assert(dest.len == 0 or self.end == self.start);

                var n: usize = 0;
                const remain = dest.len - dest_index;
                if (remain > 8 and remain > comptime (buffer_size >> 3)) {
                    // skip the buffer if the output is large enough, default 512 bytes
                    n = try self.unbuffered_reader.read(dest[dest_index..]);
                    dest_index += n;
                } else {
                    // buffer empty, fill it
                    n = try self.unbuffered_reader.read(self.buf[pushback_size..]);
                    self.start = 0;
                    self.end = n;
                    // least is 1 when used with read, try another fill
                    if (least == 1) least += dest_index;
                }
                if (n == 0) {
                    // reading from the unbuffered stream returned nothing
                    // so we have nothing left to read.
                    break;
                }
            }
            return dest_index;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        /// Returns an iterator that iterates over the reader buffer that are not
        /// any of the items in `delimiters`.
        pub fn tokenizeAny(self: *Self, delimiter: []const u8) TokenIterator(*Self, .any) {
            return .{ .context = self, .delimiter = delimiter, .lastpos = 0 };
        }

        /// Returns an iterator that iterates over the reader buffer that are not
        /// the sequence in `delimiter`.
        pub fn tokenizeSequence(self: *Self, delimiter: []const u8) TokenIterator(*Self, .sequence) {
            return .{ .context = self, .delimiter = delimiter, .lastpos = 0 };
        }

        /// Returns an iterator that iterates over the reader buffer that are not
        /// `delimiter`.
        pub fn tokenizeScalar(self: *Self, delimiter: u8) TokenIterator(*Self, .scalar) {
            return .{ .context = self, .delimiter = delimiter, .lastpos = 0 };
        }

        /// Returns an iterator that iterates over the reader buffer line after line.
        pub fn lines(self: *Self) TokenIterator(*Self, .any) {
            return self.tokenizeAny("\r\n");
        }

        /// Pump data from reader and pour into a writer,
        /// stops when reader returns 0 bytes (EOF).
        pub fn toWriter(self: *Self, writer: anytype) !void {
            while (true) {
                const buffer = self.peek(0) catch |err| switch (err) {
                    error.EndOfStream => return,
                    else => return err,
                };
                if (buffer.len == 0) return;
                var index: usize = 0;
                while (index < buffer.len) {
                    const n = try writer.write(buffer);
                    try self.discard(n);
                    index += n;
                }
            }
        }
    };
}

/// Creates a reader which buffer size is 4096, push back buffer size is 0.
pub fn bufferedReader(reader: anytype) BufferedReader(4096, 0, @TypeOf(reader)) {
    return .{ .unbuffered_reader = reader };
}

/// Creates a user custom buffer size reader, push back buffer size is 0.
pub fn bufferedReaderSize(comptime size: usize, reader: anytype) BufferedReader(size, 0, @TypeOf(reader)) {
    return .{ .unbuffered_reader = reader };
}

/// Creates a push back reader, so that the push back data can be read again.
/// It can at most push back size byte data.
/// This makes look-ahead style parsing much easier.
pub fn pushbackReader(comptime size: usize, reader: anytype) BufferedReader(4096, size, @TypeOf(reader)) {
    return .{ .unbuffered_reader = reader };
}

test "peek" {
    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var fbs = io.fixedBufferStream(&bytes);
    var reader = bufferedReader(fbs.reader());
    const dest = try reader.peek(0);
    try testing.expect(mem.eql(u8, dest[0..], bytes[0..]));

    try reader.discard(bytes.len);
    var buf: [4]u8 = undefined;
    var read = try reader.read(buf[0..]);
    try testing.expect(read == 0);
    try testing.expectError(error.EndOfStream, reader.peek(0));
    try testing.expectError(error.EndOfStream, reader.discard(bytes.len));
}

test "tokenize" {
    const gpa = std.testing.allocator;
    const data = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n2\r\nHe\r\n2\r\nll\r\n1\r\no\r\n0\r\n\r\n";
    var br = try gpa.create(BufferedReader(4096, 0, std.io.FixedBufferStream([]const u8)));
    br.* = .{ .unbuffered_reader = std.io.fixedBufferStream(data) };

    defer gpa.destroy(br);

    var single = br.tokenizeScalar('/');
    try testing.expectEqualSlices(u8, single.next().?, "GET ");
    try testing.expectEqualSlices(u8, single.next().?, " HTTP");
    try testing.expectEqualSlices(u8, single.next().?, "1.1\r\nHost: localhost\r\n\r\n2\r\nHe\r\n2\r\nll\r\n1\r\no\r\n0\r\n\r\n");
    try testing.expect(single.next() == null);

    br.unbuffered_reader.reset();

    var seq = br.tokenizeSequence("\r\n");
    try testing.expectEqualSlices(u8, seq.next().?, "GET / HTTP/1.1");
    try testing.expectEqualSlices(u8, seq.next().?, "Host: localhost");
    try testing.expectEqualSlices(u8, seq.next().?, "2");
    try testing.expectEqualSlices(u8, seq.next().?, "He");
    try testing.expectEqualSlices(u8, seq.next().?, "2");
    try testing.expectEqualSlices(u8, seq.next().?, "ll");
    try testing.expectEqualSlices(u8, seq.next().?, "1");
    try testing.expectEqualSlices(u8, seq.next().?, "o");
    try testing.expectEqualSlices(u8, seq.next().?, "0");
    try testing.expect(seq.next() == null);

    br.unbuffered_reader.reset();

    var linecount: usize = 0;
    var lines = br.lines();
    while (lines.next()) |_| {
        linecount += 1;
    }
    try testing.expect(linecount == 9);
    try testing.expect(lines.next() == null);
}

test "tokenize on small buffer" {
    const gpa = std.testing.allocator;
    const data = "GET / HTTP/1.1\r\nHost: localhost.testing.run\r\n\r\n2\r\nHe\r\n2\r\nll\r\n1\r\no\r\n0\r\n\r\n";
    var br = try gpa.create(BufferedReader(8, 0, std.io.FixedBufferStream([]const u8)));
    br.* = .{ .unbuffered_reader = std.io.fixedBufferStream(data) };

    defer gpa.destroy(br);

    var lines = br.lines();
    try testing.expectEqualSlices(u8, lines.next().?, "GET / HT");
    try testing.expectEqualSlices(u8, lines.next().?, "TP/1.1");
    try testing.expectEqualSlices(u8, lines.next().?, "Host: lo");
    try testing.expectEqualSlices(u8, lines.next().?, "calhost.");
    try testing.expectEqualSlices(u8, lines.next().?, "testing.");
    try testing.expectEqualSlices(u8, lines.next().?, "run");
    try testing.expectEqualSlices(u8, lines.next().?, "2");
    try testing.expectEqualSlices(u8, lines.next().?, "He");
    try testing.expectEqualSlices(u8, lines.next().?, "2");
    try testing.expectEqualSlices(u8, lines.next().?, "ll");
    try testing.expectEqualSlices(u8, lines.next().?, "1");
    try testing.expectEqualSlices(u8, lines.next().?, "o");
    try testing.expectEqualSlices(u8, lines.next().?, "0");
    try testing.expect(lines.next() == null);
}

test "toWriter" {
    var buf: [255]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    const data = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n2\r\nHe\r\n2\r\nll\r\n1\r\no\r\n0\r\n\r\n";

    const gpa = std.testing.allocator;
    var br = try gpa.create(BufferedReader(4096, 0, std.io.FixedBufferStream([]const u8)));
    defer gpa.destroy(br);

    br.* = .{ .unbuffered_reader = std.io.fixedBufferStream(data) };

    try br.toWriter(fbs.writer());

    br.unbuffered_reader.reset();
    try br.toWriter(fbs.writer());

    br.unbuffered_reader.reset();
    try br.toWriter(fbs.writer());

    try testing.expectEqualSlices(u8, fbs.getWritten(), data ** 3);
}

test "pushbackReader" {
    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var fbs = io.fixedBufferStream(&bytes);
    var ps = pushbackReader(2, fbs.reader());

    var dest: [4]u8 = undefined;

    try ps.push(&[_]u8{ 10, 9 });

    try testing.expectError(error.NoSpaceLeft, ps.pushByte(1));

    var read = try ps.reader().read(dest[0..4]);
    try testing.expect(read == 4);
    try testing.expect(dest[0] == 10);
    try testing.expect(dest[1] == 9);
    try testing.expect(mem.eql(u8, dest[2..4], bytes[0..2]));

    read = try ps.reader().read(dest[0..4]);
    try testing.expect(read == 4);
    try testing.expect(mem.eql(u8, dest[0..4], bytes[2..6]));

    try ps.push(&[_]u8{ 11, 12 });
    const peekdest = try ps.peek(2);
    try testing.expect(peekdest.len == 2);
    try testing.expect(mem.eql(u8, peekdest[0..], &[_]u8{ 11, 12 }));
    try ps.discard(2);

    read = try ps.reader().read(dest[0..4]);
    try testing.expect(read == 2);
    try testing.expect(mem.eql(u8, dest[0..2], bytes[6..8]));

    try ps.pushByte(12);
    try testing.expectError(error.NoSpaceLeft, ps.push(&[_]u8{ 10, 9 }));
    try ps.pushByte(11);

    read = try ps.reader().read(dest[0..4]);
    try testing.expect(read == 2);
    try testing.expect(dest[0] == 11);
    try testing.expect(dest[1] == 12);
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

        fn reset(self: *Self) void {
            self.curr = 0;
        }
    };

    const str = "This is a test";
    var one_byte_stream = OneByteReadReader.init(str);
    var buf_reader = bufferedReader(one_byte_stream.reader());
    const stream = buf_reader.reader();

    const res = try stream.readAllAlloc(testing.allocator, str.len + 1);
    defer testing.allocator.free(res);
    try testing.expectEqualSlices(u8, str, res);

    // tokenize
    {
        const data = "GET / HTTP/1.1\r\nHost: localhost.testing.run\r\n\r\n2\r\nHe\r\n2\r\nll\r\n1\r\no\r\n0\r\n\r\n";
        var onebyte = OneByteReadReader.init(data);
        var br = bufferedReaderSize(8, onebyte.reader());

        var lines = br.lines();
        try testing.expectEqualSlices(u8, lines.next().?, "GET / HT");
        try testing.expectEqualSlices(u8, lines.next().?, "TP/1.1");
        try testing.expectEqualSlices(u8, lines.next().?, "Host: lo");
        try testing.expectEqualSlices(u8, lines.next().?, "calhost.");
        try testing.expectEqualSlices(u8, lines.next().?, "testing.");
        try testing.expectEqualSlices(u8, lines.next().?, "run");
        try testing.expectEqualSlices(u8, lines.next().?, "2");
        try testing.expectEqualSlices(u8, lines.next().?, "He");
        try testing.expectEqualSlices(u8, lines.next().?, "2");
        try testing.expectEqualSlices(u8, lines.next().?, "ll");
        try testing.expectEqualSlices(u8, lines.next().?, "1");
        try testing.expectEqualSlices(u8, lines.next().?, "o");
        try testing.expectEqualSlices(u8, lines.next().?, "0");
        try testing.expect(lines.next() == null);

        onebyte.reset();
        try testing.expectEqualSlices(u8, try br.peek(3), "GET");
        try br.discard(2);
        try testing.expectEqualSlices(u8, try br.peek(3), "T /");
        try br.discard(2);
        try testing.expectEqualSlices(u8, try br.peek(3), "/ H");
    }
}

fn smallBufferedReader(underlying_stream: anytype) BufferedReader(8, 0, @TypeOf(underlying_stream)) {
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
        var block_reader = BlockReader.init(block, 2);
        var test_buf_reader = BufferedReader(4, 0, BlockReader){ .unbuffered_reader = block_reader };
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
        var test_buf_reader = BufferedReader(4, 0, BlockReader){ .unbuffered_reader = block_reader };
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
        var test_buf_reader = BufferedReader(4, 0, BlockReader){ .unbuffered_reader = block_reader };
        var out_buf: [5]u8 = undefined;
        _ = try test_buf_reader.readAtLeast(&out_buf, out_buf.len);
        try testing.expectEqualSlices(u8, &out_buf, "01230");
        const n = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, out_buf[0..n], "123");
        try testing.expectEqual(try test_buf_reader.read(&out_buf), 0);
    }

    // len out == 0
    {
        var block_reader = BlockReader.init(block, 2);
        var test_buf_reader = BufferedReader(4, 0, BlockReader){ .unbuffered_reader = block_reader };
        var out_buf: [0]u8 = undefined;
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, "");
    }

    // len bufreader buf > block
    {
        var block_reader = BlockReader.init(block, 2);
        var test_buf_reader = BufferedReader(5, 0, BlockReader){ .unbuffered_reader = block_reader };
        var out_buf: [4]u8 = undefined;
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        _ = try test_buf_reader.read(&out_buf);
        try testing.expectEqualSlices(u8, &out_buf, block);
        try testing.expectEqual(try test_buf_reader.read(&out_buf), 0);
    }
}
