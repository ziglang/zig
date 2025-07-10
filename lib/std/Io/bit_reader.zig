const std = @import("../std.zig");

//General note on endianess:
//Big endian is packed starting in the most significant part of the byte and subsequent
// bytes contain less significant bits. Thus we always take bits from the high
// end and place them below existing bits in our output.
//Little endian is packed starting in the least significant part of the byte and
// subsequent bytes contain more significant bits. Thus we always take bits from
// the low end and place them above existing bits in our output.
//Regardless of endianess, within any given byte the bits are always in most
// to least significant order.
//Also regardless of endianess, the buffer always aligns bits to the low end
// of the byte.

/// Creates a bit reader which allows for reading bits from an underlying standard reader
pub fn BitReader(comptime endian: std.builtin.Endian, comptime Reader: type) type {
    return struct {
        reader: Reader,
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

        fn Bits(comptime T: type) type {
            return struct {
                T,
                u16,
            };
        }

        fn initBits(comptime T: type, out: anytype, num: u16) Bits(T) {
            const UT = std.meta.Int(.unsigned, @bitSizeOf(T));
            return .{
                @bitCast(@as(UT, @intCast(out))),
                num,
            };
        }

        /// Reads `bits` bits from the reader and returns a specified type
        ///  containing them in the least significant end, returning an error if the
        ///  specified number of bits could not be read.
        pub fn readBitsNoEof(self: *@This(), comptime T: type, num: u16) !T {
            const b, const c = try self.readBitsTuple(T, num);
            if (c < num) return error.EndOfStream;
            return b;
        }

        /// Reads `bits` bits from the reader and returns a specified type
        ///  containing them in the least significant end. The number of bits successfully
        ///  read is placed in `out_bits`, as reaching the end of the stream is not an error.
        pub fn readBits(self: *@This(), comptime T: type, num: u16, out_bits: *u16) !T {
            const b, const c = try self.readBitsTuple(T, num);
            out_bits.* = c;
            return b;
        }

        /// Reads `bits` bits from the reader and returns a tuple of the specified type
        ///  containing them in the least significant end, and the number of bits successfully
        ///  read. Reaching the end of the stream is not an error.
        pub fn readBitsTuple(self: *@This(), comptime T: type, num: u16) !Bits(T) {
            const UT = std.meta.Int(.unsigned, @bitSizeOf(T));
            const U = if (@bitSizeOf(T) < 8) u8 else UT; //it is a pain to work with <u8

            //dump any bits in our buffer first
            if (num <= self.count) return initBits(T, self.removeBits(@intCast(num)), num);

            var out_count: u16 = self.count;
            var out: U = self.removeBits(self.count);

            //grab all the full bytes we need and put their
            //bits where they belong
            const full_bytes_left = (num - out_count) / 8;

            for (0..full_bytes_left) |_| {
                const byte = self.reader.readByte() catch |err| switch (err) {
                    error.EndOfStream => return initBits(T, out, out_count),
                    else => |e| return e,
                };

                switch (endian) {
                    .big => {
                        if (U == u8) out = 0 else out <<= 8; //shifting u8 by 8 is illegal in Zig
                        out |= byte;
                    },
                    .little => {
                        const pos = @as(U, byte) << @intCast(out_count);
                        out |= pos;
                    },
                }
                out_count += 8;
            }

            const bits_left = num - out_count;
            const keep = 8 - bits_left;

            if (bits_left == 0) return initBits(T, out, out_count);

            const final_byte = self.reader.readByte() catch |err| switch (err) {
                error.EndOfStream => return initBits(T, out, out_count),
                else => |e| return e,
            };

            switch (endian) {
                .big => {
                    out <<= @intCast(bits_left);
                    out |= final_byte >> @intCast(keep);
                    self.bits = final_byte & low_bit_mask[keep];
                },
                .little => {
                    const pos = @as(U, final_byte & low_bit_mask[bits_left]) << @intCast(out_count);
                    out |= pos;
                    self.bits = final_byte >> @intCast(bits_left);
                },
            }

            self.count = @intCast(keep);
            return initBits(T, out, num);
        }

        //convenience function for removing bits from
        //the appropriate part of the buffer based on
        //endianess.
        fn removeBits(self: *@This(), num: u4) u8 {
            if (num == 8) {
                self.count = 0;
                return self.bits;
            }

            const keep = self.count - num;
            const bits = switch (endian) {
                .big => self.bits >> @intCast(keep),
                .little => self.bits & low_bit_mask[num],
            };
            switch (endian) {
                .big => self.bits &= low_bit_mask[keep],
                .little => self.bits >>= @intCast(num),
            }

            self.count = keep;
            return bits;
        }

        pub fn alignToByte(self: *@This()) void {
            self.bits = 0;
            self.count = 0;
        }
    };
}

pub fn bitReader(comptime endian: std.builtin.Endian, reader: anytype) BitReader(endian, @TypeOf(reader)) {
    return .{ .reader = reader };
}

///////////////////////////////

test "api coverage" {
    const mem_be = [_]u8{ 0b11001101, 0b00001011 };
    const mem_le = [_]u8{ 0b00011101, 0b10010101 };

    var mem_in_be = std.io.fixedBufferStream(&mem_be);
    var bit_stream_be = bitReader(.big, mem_in_be.reader());

    var out_bits: u16 = undefined;

    const expect = std.testing.expect;
    const expectError = std.testing.expectError;

    try expect(1 == try bit_stream_be.readBits(u2, 1, &out_bits));
    try expect(out_bits == 1);
    try expect(2 == try bit_stream_be.readBits(u5, 2, &out_bits));
    try expect(out_bits == 2);
    try expect(3 == try bit_stream_be.readBits(u128, 3, &out_bits));
    try expect(out_bits == 3);
    try expect(4 == try bit_stream_be.readBits(u8, 4, &out_bits));
    try expect(out_bits == 4);
    try expect(5 == try bit_stream_be.readBits(u9, 5, &out_bits));
    try expect(out_bits == 5);
    try expect(1 == try bit_stream_be.readBits(u1, 1, &out_bits));
    try expect(out_bits == 1);

    mem_in_be.pos = 0;
    bit_stream_be.count = 0;
    try expect(0b110011010000101 == try bit_stream_be.readBits(u15, 15, &out_bits));
    try expect(out_bits == 15);

    mem_in_be.pos = 0;
    bit_stream_be.count = 0;
    try expect(0b1100110100001011 == try bit_stream_be.readBits(u16, 16, &out_bits));
    try expect(out_bits == 16);

    _ = try bit_stream_be.readBits(u0, 0, &out_bits);

    try expect(0 == try bit_stream_be.readBits(u1, 1, &out_bits));
    try expect(out_bits == 0);
    try expectError(error.EndOfStream, bit_stream_be.readBitsNoEof(u1, 1));

    var mem_in_le = std.io.fixedBufferStream(&mem_le);
    var bit_stream_le = bitReader(.little, mem_in_le.reader());

    try expect(1 == try bit_stream_le.readBits(u2, 1, &out_bits));
    try expect(out_bits == 1);
    try expect(2 == try bit_stream_le.readBits(u5, 2, &out_bits));
    try expect(out_bits == 2);
    try expect(3 == try bit_stream_le.readBits(u128, 3, &out_bits));
    try expect(out_bits == 3);
    try expect(4 == try bit_stream_le.readBits(u8, 4, &out_bits));
    try expect(out_bits == 4);
    try expect(5 == try bit_stream_le.readBits(u9, 5, &out_bits));
    try expect(out_bits == 5);
    try expect(1 == try bit_stream_le.readBits(u1, 1, &out_bits));
    try expect(out_bits == 1);

    mem_in_le.pos = 0;
    bit_stream_le.count = 0;
    try expect(0b001010100011101 == try bit_stream_le.readBits(u15, 15, &out_bits));
    try expect(out_bits == 15);

    mem_in_le.pos = 0;
    bit_stream_le.count = 0;
    try expect(0b1001010100011101 == try bit_stream_le.readBits(u16, 16, &out_bits));
    try expect(out_bits == 16);

    _ = try bit_stream_le.readBits(u0, 0, &out_bits);

    try expect(0 == try bit_stream_le.readBits(u1, 1, &out_bits));
    try expect(out_bits == 0);
    try expectError(error.EndOfStream, bit_stream_le.readBitsNoEof(u1, 1));
}
