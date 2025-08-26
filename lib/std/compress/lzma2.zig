const std = @import("../std.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const lzma = std.compress.lzma;
const Writer = std.Io.Writer;
const Reader = std.Io.Reader;

/// An accumulating buffer for LZ sequences
pub const LzAccumBuffer = struct {
    /// Buffer
    buf: ArrayList(u8),

    /// Buffer memory limit
    memlimit: usize,

    /// Total number of bytes sent through the buffer
    len: usize,

    pub fn init(memlimit: usize) LzAccumBuffer {
        return .{
            .buf = .{},
            .memlimit = memlimit,
            .len = 0,
        };
    }

    pub fn appendByte(self: *LzAccumBuffer, allocator: Allocator, byte: u8) !void {
        try self.buf.append(allocator, byte);
        self.len += 1;
    }

    /// Reset the internal dictionary
    pub fn reset(self: *LzAccumBuffer, writer: *Writer) !void {
        try writer.writeAll(self.buf.items);
        self.buf.clearRetainingCapacity();
        self.len = 0;
    }

    /// Retrieve the last byte or return a default
    pub fn lastOr(self: LzAccumBuffer, lit: u8) u8 {
        const buf_len = self.buf.items.len;
        return if (buf_len == 0)
            lit
        else
            self.buf.items[buf_len - 1];
    }

    /// Retrieve the n-th last byte
    pub fn lastN(self: LzAccumBuffer, dist: usize) !u8 {
        const buf_len = self.buf.items.len;
        if (dist > buf_len) {
            return error.CorruptInput;
        }

        return self.buf.items[buf_len - dist];
    }

    /// Append a literal
    pub fn appendLiteral(
        self: *LzAccumBuffer,
        allocator: Allocator,
        lit: u8,
        writer: *Writer,
    ) !void {
        _ = writer;
        if (self.len >= self.memlimit) {
            return error.CorruptInput;
        }
        try self.buf.append(allocator, lit);
        self.len += 1;
    }

    /// Fetch an LZ sequence (length, distance) from inside the buffer
    pub fn appendLz(
        self: *LzAccumBuffer,
        allocator: Allocator,
        len: usize,
        dist: usize,
        writer: *Writer,
    ) !void {
        _ = writer;

        const buf_len = self.buf.items.len;
        if (dist > buf_len) {
            return error.CorruptInput;
        }

        var offset = buf_len - dist;
        var i: usize = 0;
        while (i < len) : (i += 1) {
            const x = self.buf.items[offset];
            try self.buf.append(allocator, x);
            offset += 1;
        }
        self.len += len;
    }

    pub fn finish(self: *LzAccumBuffer, writer: *Writer) !void {
        try writer.writeAll(self.buf.items);
        self.buf.clearRetainingCapacity();
    }

    pub fn deinit(self: *LzAccumBuffer, allocator: Allocator) void {
        self.buf.deinit(allocator);
        self.* = undefined;
    }
};

pub const Decode = struct {
    lzma_decode: lzma.Decode,

    pub fn init(allocator: Allocator) !Decode {
        return Decode{
            .lzma_decode = try lzma.Decode.init(
                allocator,
                .{
                    .lc = 0,
                    .lp = 0,
                    .pb = 0,
                },
                null,
            ),
        };
    }

    pub fn deinit(self: *Decode, allocator: Allocator) void {
        self.lzma_decode.deinit(allocator);
        self.* = undefined;
    }

    pub fn decompress(
        self: *Decode,
        allocator: Allocator,
        reader: *Reader,
        writer: *Writer,
    ) !void {
        var accum = LzAccumBuffer.init(std.math.maxInt(usize));
        defer accum.deinit(allocator);

        while (true) {
            const status = try reader.readByte();

            switch (status) {
                0 => break,
                1 => try parseUncompressed(allocator, reader, writer, &accum, true),
                2 => try parseUncompressed(allocator, reader, writer, &accum, false),
                else => try self.parseLzma(allocator, reader, writer, &accum, status),
            }
        }

        try accum.finish(writer);
    }

    fn parseLzma(
        self: *Decode,
        allocator: Allocator,
        reader: *Reader,
        writer: *Writer,
        accum: *LzAccumBuffer,
        status: u8,
    ) !void {
        if (status & 0x80 == 0) {
            return error.CorruptInput;
        }

        const Reset = struct {
            dict: bool,
            state: bool,
            props: bool,
        };

        const reset = switch ((status >> 5) & 0x3) {
            0 => Reset{
                .dict = false,
                .state = false,
                .props = false,
            },
            1 => Reset{
                .dict = false,
                .state = true,
                .props = false,
            },
            2 => Reset{
                .dict = false,
                .state = true,
                .props = true,
            },
            3 => Reset{
                .dict = true,
                .state = true,
                .props = true,
            },
            else => unreachable,
        };

        const unpacked_size = blk: {
            var tmp: u64 = status & 0x1F;
            tmp <<= 16;
            tmp |= try reader.readInt(u16, .big);
            break :blk tmp + 1;
        };

        const packed_size = blk: {
            const tmp: u17 = try reader.readInt(u16, .big);
            break :blk tmp + 1;
        };

        if (reset.dict) {
            try accum.reset(writer);
        }

        if (reset.state) {
            var new_props = self.lzma_decode.properties;

            if (reset.props) {
                var props = try reader.readByte();
                if (props >= 225) {
                    return error.CorruptInput;
                }

                const lc = @as(u4, @intCast(props % 9));
                props /= 9;
                const lp = @as(u3, @intCast(props % 5));
                props /= 5;
                const pb = @as(u3, @intCast(props));

                if (lc + lp > 4) {
                    return error.CorruptInput;
                }

                new_props = .{ .lc = lc, .lp = lp, .pb = pb };
            }

            try self.lzma_decode.resetState(allocator, new_props);
        }

        self.lzma_decode.unpacked_size = unpacked_size + accum.len;

        var counter = std.io.countingReader(reader);
        const counter_reader = counter.reader();

        var rangecoder = try lzma.RangeDecoder.init(counter_reader);
        while (try self.lzma_decode.process(allocator, counter_reader, writer, accum, &rangecoder) == .continue_) {}

        if (counter.bytes_read != packed_size) {
            return error.CorruptInput;
        }
    }

    fn parseUncompressed(
        allocator: Allocator,
        reader: *Reader,
        writer: *Writer,
        accum: *LzAccumBuffer,
        reset_dict: bool,
    ) !void {
        const unpacked_size = @as(u17, try reader.readInt(u16, .big)) + 1;

        if (reset_dict) {
            try accum.reset(writer);
        }

        var i: @TypeOf(unpacked_size) = 0;
        while (i < unpacked_size) : (i += 1) {
            try accum.appendByte(allocator, try reader.readByte());
        }
    }
};

test "decompress hello world stream" {
    const expected = "Hello\nWorld!\n";
    const compressed = &[_]u8{ 0x01, 0x00, 0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x0A, 0x02, 0x00, 0x06, 0x57, 0x6F, 0x72, 0x6C, 0x64, 0x21, 0x0A, 0x00 };

    const gpa = std.testing.allocator;

    var stream: std.Io.Reader = .fixed(compressed);

    var decode = try Decode.init(gpa, &stream);
    defer decode.deinit(gpa);

    const result = try decode.reader.allocRemaining(gpa, .unlimited);
    defer gpa.free(result);

    try std.testing.expectEqualStrings(expected, result);
}
