const std = @import("std");

pub const ReversedByteReader = struct {
    remaining_bytes: usize,
    bytes: []const u8,

    const Reader = std.io.Reader(*ReversedByteReader, error{}, readFn);

    pub fn init(bytes: []const u8) ReversedByteReader {
        return .{
            .bytes = bytes,
            .remaining_bytes = bytes.len,
        };
    }

    pub fn reader(self: *ReversedByteReader) Reader {
        return .{ .context = self };
    }

    fn readFn(ctx: *ReversedByteReader, buffer: []u8) !usize {
        if (ctx.remaining_bytes == 0) return 0;
        const byte_index = ctx.remaining_bytes - 1;
        buffer[0] = ctx.bytes[byte_index];
        // buffer[0] = @bitReverse(ctx.bytes[byte_index]);
        ctx.remaining_bytes = byte_index;
        return 1;
    }
};

/// A bit reader for reading the reversed bit streams used to encode
/// FSE compressed data.
pub const ReverseBitReader = struct {
    byte_reader: ReversedByteReader,
    bit_reader: std.io.BitReader(.Big, ReversedByteReader.Reader),

    pub fn init(self: *ReverseBitReader, bytes: []const u8) error{BitStreamHasNoStartBit}!void {
        self.byte_reader = ReversedByteReader.init(bytes);
        self.bit_reader = std.io.bitReader(.Big, self.byte_reader.reader());
        if (bytes.len == 0) return;
        var i: usize = 0;
        while (i < 8 and 0 == self.readBitsNoEof(u1, 1) catch unreachable) : (i += 1) {}
        if (i == 8) return error.BitStreamHasNoStartBit;
    }

    pub fn readBitsNoEof(self: *@This(), comptime U: type, num_bits: usize) error{EndOfStream}!U {
        return self.bit_reader.readBitsNoEof(U, num_bits);
    }

    pub fn readBits(self: *@This(), comptime U: type, num_bits: usize, out_bits: *usize) error{}!U {
        return try self.bit_reader.readBits(U, num_bits, out_bits);
    }

    pub fn alignToByte(self: *@This()) void {
        self.bit_reader.alignToByte();
    }

    pub fn isEmpty(self: ReverseBitReader) bool {
        return self.byte_reader.remaining_bytes == 0 and self.bit_reader.bit_count == 0;
    }
};

pub fn BitReader(comptime Reader: type) type {
    return struct {
        underlying: std.io.BitReader(.Little, Reader),

        pub fn readBitsNoEof(self: *@This(), comptime U: type, num_bits: usize) !U {
            return self.underlying.readBitsNoEof(U, num_bits);
        }

        pub fn readBits(self: *@This(), comptime U: type, num_bits: usize, out_bits: *usize) !U {
            return self.underlying.readBits(U, num_bits, out_bits);
        }

        pub fn alignToByte(self: *@This()) void {
            self.underlying.alignToByte();
        }
    };
}

pub fn bitReader(reader: anytype) BitReader(@TypeOf(reader)) {
    return .{ .underlying = std.io.bitReader(.Little, reader) };
}
