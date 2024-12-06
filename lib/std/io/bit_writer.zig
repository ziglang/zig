const std = @import("../std.zig");

//General note on endianess:
//Big endian is packed starting in the most significant part of the byte and subsequent
// bytes contain less significant bits. Thus we write out bits from the high end
// of our input first.
//Little endian is packed starting in the least significant part of the byte and
// subsequent bytes contain more significant bits. Thus we write out bits from
// the low end of our input first.
//Regardless of endianess, within any given byte the bits are always in most
// to least significant order.
//Also regardless of endianess, the buffer always aligns bits to the low end
// of the byte.

/// Creates a bit writer which allows for writing bits to an underlying standard writer
pub fn BitWriter(comptime endian: std.builtin.Endian, comptime Writer: type) type {
    return struct {
        writer: Writer,
        bits: u8 = 0,
        count: u4 = 0,

        const low_bit_mask = [9]u8{
            0b00000000,
            0b00000001,
            0b00000011,
            0b00000111,
            0b00001111,
            0b00011111,
            0b00111111,
            0b01111111,
            0b11111111,
        };

        /// Write the specified number of bits to the writer from the least significant bits of
        ///  the specified value. Bits will only be written to the writer when there
        ///  are enough to fill a byte.
        pub fn writeBits(self: *@This(), value: anytype, num: u16) !void {
            const T = @TypeOf(value);
            const UT = std.meta.Int(.unsigned, @bitSizeOf(T));
            const U = if (@bitSizeOf(T) < 8) u8 else UT; //<u8 is a pain to work with

            var in: U = @as(UT, @bitCast(value));
            var in_count: u16 = num;

            if (self.count > 0) {
                //if we can't fill the buffer, add what we have
                const bits_free = 8 - self.count;
                if (num < bits_free) {
                    self.addBits(@truncate(in), @intCast(num));
                    return;
                }

                //finish filling the buffer and flush it
                if (num == bits_free) {
                    self.addBits(@truncate(in), @intCast(num));
                    return self.flushBits();
                }

                switch (endian) {
                    .big => {
                        const bits = in >> @intCast(in_count - bits_free);
                        self.addBits(@truncate(bits), bits_free);
                    },
                    .little => {
                        self.addBits(@truncate(in), bits_free);
                        in >>= @intCast(bits_free);
                    },
                }
                in_count -= bits_free;
                try self.flushBits();
            }

            //write full bytes while we can
            const full_bytes_left = in_count / 8;
            for (0..full_bytes_left) |_| {
                switch (endian) {
                    .big => {
                        const bits = in >> @intCast(in_count - 8);
                        try self.writer.writeByte(@truncate(bits));
                    },
                    .little => {
                        try self.writer.writeByte(@truncate(in));
                        if (U == u8) in = 0 else in >>= 8;
                    },
                }
                in_count -= 8;
            }

            //save the remaining bits in the buffer
            self.addBits(@truncate(in), @intCast(in_count));
        }

        //convenience funciton for adding bits to the buffer
        //in the appropriate position based on endianess
        fn addBits(self: *@This(), bits: u8, num: u4) void {
            if (num == 8) self.bits = bits else switch (endian) {
                .big => {
                    self.bits <<= @intCast(num);
                    self.bits |= bits & low_bit_mask[num];
                },
                .little => {
                    const pos = bits << @intCast(self.count);
                    self.bits |= pos;
                },
            }
            self.count += num;
        }

        /// Flush any remaining bits to the writer, filling
        /// unused bits with 0s.
        pub fn flushBits(self: *@This()) !void {
            if (self.count == 0) return;
            if (endian == .big) self.bits <<= @intCast(8 - self.count);
            try self.writer.writeByte(self.bits);
            self.bits = 0;
            self.count = 0;
        }
    };
}

pub fn bitWriter(comptime endian: std.builtin.Endian, writer: anytype) BitWriter(endian, @TypeOf(writer)) {
    return .{ .writer = writer };
}

///////////////////////////////

test "api coverage" {
    var mem_be = [_]u8{0} ** 2;
    var mem_le = [_]u8{0} ** 2;

    var mem_out_be = std.io.fixedBufferStream(&mem_be);
    var bit_stream_be = bitWriter(.big, mem_out_be.writer());

    const testing = std.testing;

    try bit_stream_be.writeBits(@as(u2, 1), 1);
    try bit_stream_be.writeBits(@as(u5, 2), 2);
    try bit_stream_be.writeBits(@as(u128, 3), 3);
    try bit_stream_be.writeBits(@as(u8, 4), 4);
    try bit_stream_be.writeBits(@as(u9, 5), 5);
    try bit_stream_be.writeBits(@as(u1, 1), 1);

    try testing.expect(mem_be[0] == 0b11001101 and mem_be[1] == 0b00001011);

    mem_out_be.pos = 0;

    try bit_stream_be.writeBits(@as(u15, 0b110011010000101), 15);
    try bit_stream_be.flushBits();
    try testing.expect(mem_be[0] == 0b11001101 and mem_be[1] == 0b00001010);

    mem_out_be.pos = 0;
    try bit_stream_be.writeBits(@as(u32, 0b110011010000101), 16);
    try testing.expect(mem_be[0] == 0b01100110 and mem_be[1] == 0b10000101);

    try bit_stream_be.writeBits(@as(u0, 0), 0);

    var mem_out_le = std.io.fixedBufferStream(&mem_le);
    var bit_stream_le = bitWriter(.little, mem_out_le.writer());

    try bit_stream_le.writeBits(@as(u2, 1), 1);
    try bit_stream_le.writeBits(@as(u5, 2), 2);
    try bit_stream_le.writeBits(@as(u128, 3), 3);
    try bit_stream_le.writeBits(@as(u8, 4), 4);
    try bit_stream_le.writeBits(@as(u9, 5), 5);
    try bit_stream_le.writeBits(@as(u1, 1), 1);

    try testing.expect(mem_le[0] == 0b00011101 and mem_le[1] == 0b10010101);

    mem_out_le.pos = 0;
    try bit_stream_le.writeBits(@as(u15, 0b110011010000101), 15);
    try bit_stream_le.flushBits();
    try testing.expect(mem_le[0] == 0b10000101 and mem_le[1] == 0b01100110);

    mem_out_le.pos = 0;
    try bit_stream_le.writeBits(@as(u32, 0b1100110100001011), 16);
    try testing.expect(mem_le[0] == 0b00001011 and mem_le[1] == 0b11001101);

    try bit_stream_le.writeBits(@as(u0, 0), 0);
}
