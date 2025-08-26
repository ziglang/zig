const std = @import("../std.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const lzma = std.compress.lzma;
const Writer = std.Io.Writer;
const Reader = std.Io.Reader;

/// An accumulating buffer for LZ sequences
pub const AccumBuffer = struct {
    /// Buffer
    buf: ArrayList(u8),
    /// Buffer memory limit
    memlimit: usize,
    /// Total number of bytes sent through the buffer
    len: usize,

    pub fn init(memlimit: usize) AccumBuffer {
        return .{
            .buf = .{},
            .memlimit = memlimit,
            .len = 0,
        };
    }

    pub fn appendByte(self: *AccumBuffer, allocator: Allocator, byte: u8) !void {
        try self.buf.append(allocator, byte);
        self.len += 1;
    }

    /// Reset the internal dictionary
    pub fn reset(self: *AccumBuffer, writer: *Writer) !void {
        try writer.writeAll(self.buf.items);
        self.buf.clearRetainingCapacity();
        self.len = 0;
    }

    /// Retrieve the last byte or return a default
    pub fn lastOr(self: AccumBuffer, lit: u8) u8 {
        const buf_len = self.buf.items.len;
        return if (buf_len == 0)
            lit
        else
            self.buf.items[buf_len - 1];
    }

    /// Retrieve the n-th last byte
    pub fn lastN(self: AccumBuffer, dist: usize) !u8 {
        const buf_len = self.buf.items.len;
        if (dist > buf_len) {
            return error.CorruptInput;
        }

        return self.buf.items[buf_len - dist];
    }

    /// Append a literal
    pub fn appendLiteral(
        self: *AccumBuffer,
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
        self: *AccumBuffer,
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

    pub fn finish(self: *AccumBuffer, writer: *Writer) !void {
        try writer.writeAll(self.buf.items);
        self.buf.clearRetainingCapacity();
    }

    pub fn deinit(self: *AccumBuffer, allocator: Allocator) void {
        self.buf.deinit(allocator);
        self.* = undefined;
    }
};

pub const Decode = struct {
    lzma_decode: lzma.Decode,

    pub fn init(gpa: Allocator) !Decode {
        return .{ .lzma_decode = try lzma.Decode.init(gpa, .{ .lc = 0, .lp = 0, .pb = 0 }) };
    }

    pub fn deinit(self: *Decode, gpa: Allocator) void {
        self.lzma_decode.deinit(gpa);
        self.* = undefined;
    }

    pub fn decompress(d: *Decode, reader: *Reader, allocating: *Writer.Allocating) !void {
        const gpa = allocating.allocator;

        var accum = AccumBuffer.init(std.math.maxInt(usize));
        defer accum.deinit(gpa);

        while (true) {
            const status = try reader.takeByte();

            switch (status) {
                0 => break,
                1 => try parseUncompressed(reader, allocating, &accum, true),
                2 => try parseUncompressed(reader, allocating, &accum, false),
                else => try d.parseLzma(reader, allocating, &accum, status),
            }
        }

        try accum.finish(&allocating.writer);
    }

    fn parseLzma(
        d: *Decode,
        reader: *Reader,
        allocating: *Writer.Allocating,
        accum: *AccumBuffer,
        status: u8,
    ) !void {
        if (status & 0x80 == 0) return error.CorruptInput;

        const Reset = struct {
            dict: bool,
            state: bool,
            props: bool,
        };

        const reset: Reset = switch ((status >> 5) & 0x3) {
            0 => .{
                .dict = false,
                .state = false,
                .props = false,
            },
            1 => .{
                .dict = false,
                .state = true,
                .props = false,
            },
            2 => .{
                .dict = false,
                .state = true,
                .props = true,
            },
            3 => .{
                .dict = true,
                .state = true,
                .props = true,
            },
            else => unreachable,
        };

        const unpacked_size = blk: {
            var tmp: u64 = status & 0x1F;
            tmp <<= 16;
            tmp |= try reader.takeInt(u16, .big);
            break :blk tmp + 1;
        };

        const packed_size = blk: {
            const tmp: u17 = try reader.takeInt(u16, .big);
            break :blk tmp + 1;
        };

        if (reset.dict) try accum.reset(&allocating.writer);

        const ld = &d.lzma_decode;

        if (reset.state) {
            var new_props = ld.properties;

            if (reset.props) {
                var props = try reader.takeByte();
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

            try ld.resetState(allocating.allocator, new_props);
        }

        var range_decoder = try lzma.RangeDecoder.init(reader);

        while (true) {
            if (accum.len >= unpacked_size) break;
            if (range_decoder.isFinished()) break;
            switch (try ld.process(reader, allocating, accum, &range_decoder)) {
                .more => continue,
                .finished => break,
            }
        }
        if (accum.len != unpacked_size) return error.DecompressedSizeMismatch;

        // TODO restore this error
        //if (counter.bytes_read != packed_size) {
        //    return error.CorruptInput;
        //}
        _ = packed_size;
    }

    fn parseUncompressed(
        reader: *Reader,
        allocating: *Writer.Allocating,
        accum: *AccumBuffer,
        reset_dict: bool,
    ) !void {
        const unpacked_size = @as(u17, try reader.takeInt(u16, .big)) + 1;

        if (reset_dict) try accum.reset(&allocating.writer);

        const gpa = allocating.allocator;

        var i = unpacked_size;
        while (i != 0) {
            try accum.appendByte(gpa, try reader.takeByte());
            i -= 1;
        }
    }
};

test "decompress hello world stream" {
    const expected = "Hello\nWorld!\n";
    const compressed = &[_]u8{ 0x01, 0x00, 0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x0A, 0x02, 0x00, 0x06, 0x57, 0x6F, 0x72, 0x6C, 0x64, 0x21, 0x0A, 0x00 };

    const gpa = std.testing.allocator;

    var decode = try Decode.init(gpa);
    defer decode.deinit(gpa);

    var stream: std.Io.Reader = .fixed(compressed);
    var result: std.Io.Writer.Allocating = .init(gpa);
    defer result.deinit();

    try decode.decompress(&stream, &result);
    try std.testing.expectEqualStrings(expected, result.written());
}
