const std = @import("../std.zig");
const io = std.io;
const assert = std.debug.assert;
const testing = std.testing;
const meta = std.meta;
const math = std.math;

/// Creates a stream which allows for reading bit fields from another stream
pub fn BitReader(comptime endian: std.builtin.Endian, comptime ReaderType: type) type {
    return struct {
        forward_reader: ReaderType,
        bit_buffer: ?u8,
        bit_count: u3,

        pub const Error = ReaderType.Error;
        pub const Reader = io.Reader(*Self, Error, read);

        const Self = @This();
        const u8_bit_count = @bitSizeOf(u8);
        const u7_bit_count = @bitSizeOf(u7);
        const u4_bit_count = @bitSizeOf(u4);

        pub fn init(forward_reader: ReaderType) Self {
            return Self{
                .forward_reader = forward_reader,
                .bit_buffer = null,
                .bit_count = 0,
            };
        }

        /// Reads `bits` bits from the stream and returns a specified unsigned int type
        ///  containing them in the least significant end, returning an error if the
        ///  specified number of bits could not be read.
        pub fn readBitsNoEof(self: *Self, comptime U: type, bits: usize) !U {
            var n: usize = undefined;
            const result = try self.readBits(U, bits, &n);
            if (n < bits) return error.EndOfStream;
            return result;
        }

        /// Reads `bits` bits from the stream and returns a specified unsigned int type
        ///  containing them in the least significant end. The number of bits successfully
        ///  read is placed in `out_bits`, as reaching the end of the stream is not an error.
        pub fn readBits(self: *Self, comptime U: type, bits: usize, out_bits: *usize) Error!U {
            // By extending the buffer to a minimum of u8 we can cover a number
            // of edge cases related to shifting and casting.
            const u_bit_count = @bitSizeOf(U);
            const buf_bit_count = bc: {
                assert(u_bit_count >= bits);
                break :bc if (u_bit_count <= u8_bit_count) u8_bit_count else u_bit_count;
            };
            const Buf = std.meta.Int(.unsigned, buf_bit_count);
            const BufShift = math.Log2Int(Buf);

            out_bits.* = @as(usize, 0);
            if (U == u0 or bits == 0) return 0;
            var out_buffer = @as(Buf, 0);

            if (self.bit_buffer) |bit_buffer| {
                const n: u4 = if (self.bit_count >= bits)
                    @intCast(bits)
                else
                    @as(u4, self.bit_count) + 1;
                const shift: u3 = @intCast(u8_bit_count - n);
                switch (endian) {
                    .big => {
                        out_buffer = @as(Buf, bit_buffer >> shift);
                        if (n >= u8_bit_count)
                            self.bit_buffer = null
                        else
                            self.bit_buffer.? <<= @intCast(n);
                    },
                    .little => {
                        const value = (bit_buffer << shift) >> shift;
                        out_buffer = @as(Buf, value);
                        if (n >= u8_bit_count)
                            self.bit_buffer = null
                        else
                            self.bit_buffer.? >>= @intCast(n);
                    },
                }
                if (self.bit_count < n)
                    self.bit_buffer = null
                else
                    self.bit_count -= @intCast(n);
                out_bits.* = n;
            }

            // Copy bytes until we have enough bits, then leave the rest in bit_buffer
            while (out_bits.* < bits) {
                const n = bits - out_bits.*;
                const next_byte = self.forward_reader.readByte() catch |err| switch (err) {
                    error.EndOfStream => return @as(U, @intCast(out_buffer)),
                    else => |e| return e,
                };

                switch (endian) {
                    .big => {
                        if (n >= u8_bit_count) {
                            out_buffer <<= u7_bit_count;
                            out_buffer <<= 1;
                            out_buffer |= @as(Buf, next_byte);
                            out_bits.* += u8_bit_count;
                            continue;
                        }
                        const shift: u3 = @intCast(u8_bit_count - n);
                        out_buffer <<= @as(BufShift, @intCast(n));
                        out_buffer |= @as(Buf, next_byte >> shift);
                        out_bits.* += n;
                        self.bit_buffer = next_byte << @intCast(n);
                        self.bit_count = shift - 1;
                    },
                    .little => {
                        if (n >= u8_bit_count) {
                            out_buffer |= @as(Buf, next_byte) << @as(BufShift, @intCast(out_bits.*));
                            out_bits.* += u8_bit_count;
                            continue;
                        }
                        const shift: u3 = @intCast(u8_bit_count - n);
                        const value = (next_byte << shift) >> shift;
                        out_buffer |= @as(Buf, value) << @as(BufShift, @intCast(out_bits.*));
                        out_bits.* += n;
                        self.bit_buffer = next_byte >> @intCast(n);
                        self.bit_count = shift - 1;
                    },
                }
            }

            return @as(U, @intCast(out_buffer));
        }

        pub fn countBits(self: *Self, equal_to: u1) Error!usize {
            const xor: u8 = if (equal_to == 0) 0x00 else 0xFF;
            var count: usize = 0;

            if (self.bit_buffer) |bit_buffer| {
                switch (endian) {
                    .big => {
                        const n: u4 = @clz(bit_buffer ^ xor);
                        if (n <= self.bit_count) {
                            self.bit_buffer.? <<= @intCast(n);
                            self.bit_count -= @intCast(n);
                            return count + n;
                        } else {
                            self.bit_buffer = null;
                            count += @as(usize, self.bit_count) + 1;
                        }
                    },
                    .little => {
                        const n: u4 = @ctz(bit_buffer ^ xor);
                        if (n <= self.bit_count) {
                            self.bit_buffer.? >>= @intCast(n);
                            self.bit_count -= @intCast(n);
                            return count + n;
                        } else {
                            self.bit_buffer = null;
                            count += @as(usize, self.bit_count) + 1;
                        }
                    },
                }
            }

            while (self.bit_buffer == null) {
                const next_byte: u8 = self.forward_reader.readByte() catch |err|
                    switch (err) {
                    error.EndOfStream => return count,
                    else => |e| return e,
                };
                switch (endian) {
                    .big => {
                        const n_u4: u4 = @clz(next_byte ^ xor);
                        count += n_u4;
                        if (n_u4 < u8_bit_count) {
                            const n: u3 = @intCast(n_u4);
                            self.bit_buffer = next_byte << n;
                            self.bit_count = u7_bit_count - n;
                        }
                    },
                    .little => {
                        const n_u4: u4 = @ctz(next_byte ^ xor);
                        count += n_u4;
                        if (n_u4 < u8_bit_count) {
                            const n: u3 = @intCast(n_u4);
                            self.bit_buffer = next_byte >> n;
                            self.bit_count = u7_bit_count - n;
                        }
                    },
                }
            }
            return count;
        }

        pub fn alignToByte(self: *Self) void {
            self.bit_buffer = null;
            self.bit_count = 0;
        }

        pub fn read(self: *Self, buffer: []u8) Error!usize {
            var out_bits: usize = undefined;
            var out_bits_total = @as(usize, 0);
            //@NOTE: I'm not sure this is a good idea, maybe alignToByte should be forced
            if (self.bit_count > 0) {
                for (buffer) |*b| {
                    b.* = try self.readBits(u8, u8_bit_count, &out_bits);
                    out_bits_total += out_bits;
                }
                const incomplete_byte = @intFromBool(out_bits_total % u8_bit_count > 0);
                return (out_bits_total / u8_bit_count) + incomplete_byte;
            }

            return self.forward_reader.read(buffer);
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

pub fn bitReader(
    comptime endian: std.builtin.Endian,
    underlying_stream: anytype,
) BitReader(endian, @TypeOf(underlying_stream)) {
    return BitReader(endian, @TypeOf(underlying_stream)).init(underlying_stream);
}

test "api coverage" {
    const expectEqual = testing.expectEqual;
    const expectError = testing.expectError;

    var out_bits: usize = undefined;

    const mem_be = [_]u8{ 0b11001101, 0b00001011 };
    var mem_in_be = io.fixedBufferStream(&mem_be);
    var bit_stream_be = bitReader(.big, mem_in_be.reader());

    try expectEqual(@as(u8, 1), try bit_stream_be.readBits(u2, 1, &out_bits));
    try expectEqual(@as(usize, 1), out_bits);
    try expectEqual(@as(u8, 2), try bit_stream_be.readBits(u5, 2, &out_bits));
    try expectEqual(@as(usize, out_bits), 2);
    try expectEqual(@as(u128, 3), try bit_stream_be.readBits(u128, 3, &out_bits));
    try expectEqual(@as(usize, out_bits), 3);
    try expectEqual(@as(u8, 4), try bit_stream_be.readBits(u8, 4, &out_bits));
    try expectEqual(@as(usize, out_bits), 4);
    try expectEqual(@as(u9, 5), try bit_stream_be.readBits(u9, 5, &out_bits));
    try expectEqual(@as(usize, out_bits), 5);
    try expectEqual(@as(u1, 1), try bit_stream_be.readBits(u1, 1, &out_bits));
    try expectEqual(@as(usize, out_bits), 1);

    mem_in_be.pos = 0;
    bit_stream_be.alignToByte();
    try expectEqual(@as(u15, 0b110011010000101), try bit_stream_be.readBits(u15, 15, &out_bits));
    try expectEqual(@as(usize, 15), out_bits);

    mem_in_be.pos = 0;
    bit_stream_be.alignToByte();
    try expectEqual(@as(u16, 0b1100110100001011), try bit_stream_be.readBits(u16, 16, &out_bits));
    try expectEqual(@as(usize, out_bits), 16);

    _ = try bit_stream_be.readBits(u0, 0, &out_bits);

    try expectEqual(@as(u1, 0), try bit_stream_be.readBits(u1, 1, &out_bits));
    try expectEqual(@as(usize, out_bits), 0);
    try expectError(error.EndOfStream, bit_stream_be.readBitsNoEof(u1, 1));

    const mem_le = [_]u8{ 0b00011101, 0b10010101 };
    var mem_in_le = io.fixedBufferStream(&mem_le);
    var bit_stream_le = bitReader(.little, mem_in_le.reader());

    try expectEqual(@as(u2, 1), try bit_stream_le.readBits(u2, 1, &out_bits));
    try expectEqual(@as(usize, 1), out_bits);
    try expectEqual(@as(u5, 2), try bit_stream_le.readBits(u5, 2, &out_bits));
    try expectEqual(@as(usize, 2), out_bits);
    try expectEqual(@as(u128, 3), try bit_stream_le.readBits(u128, 3, &out_bits));
    try expectEqual(@as(usize, out_bits), 3);
    try expectEqual(@as(u8, 4), try bit_stream_le.readBits(u8, 4, &out_bits));
    try expectEqual(@as(usize, 4), out_bits);
    try expectEqual(@as(u9, 5), try bit_stream_le.readBits(u9, 5, &out_bits));
    try expectEqual(@as(usize, 5), out_bits);
    try expectEqual(@as(u1, 1), try bit_stream_le.readBits(u1, 1, &out_bits));
    try expectEqual(@as(usize, 1), out_bits);

    mem_in_le.pos = 0;
    bit_stream_le.alignToByte();
    try expectEqual(@as(u15, 0b001010100011101), try bit_stream_le.readBits(u15, 15, &out_bits));
    try expectEqual(@as(usize, 15), out_bits);

    mem_in_le.pos = 0;
    bit_stream_le.alignToByte();
    try expectEqual(@as(u16, 0b1001010100011101), try bit_stream_le.readBits(u16, 16, &out_bits));
    try expectEqual(@as(usize, 16), out_bits);

    _ = try bit_stream_le.readBits(u0, 0, &out_bits);

    try expectEqual(@as(u1, 0), try bit_stream_le.readBits(u1, 1, &out_bits));
    try expectEqual(@as(usize, 0), out_bits);
    try expectError(error.EndOfStream, bit_stream_le.readBitsNoEof(u1, 1));
}

test "counting bits" {
    const expectEqual = testing.expectEqual;

    const mem_be = [_]u8{ 0b11001101, 0b10001011 };
    var mem_in_be = io.fixedBufferStream(&mem_be);
    var bit_stream_be = bitReader(.big, mem_in_be.reader());

    try expectEqual(@as(usize, 0), try bit_stream_be.countBits(0));
    try expectEqual(@as(usize, 2), try bit_stream_be.countBits(1));
    try expectEqual(@as(usize, 2), try bit_stream_be.countBits(0));
    try expectEqual(@as(usize, 2), try bit_stream_be.countBits(1));
    try expectEqual(@as(usize, 1), try bit_stream_be.countBits(0));
    try expectEqual(@as(usize, 2), try bit_stream_be.countBits(1));
    try expectEqual(@as(usize, 3), try bit_stream_be.countBits(0));
    try expectEqual(@as(usize, 1), try bit_stream_be.countBits(1));
    try expectEqual(@as(usize, 1), try bit_stream_be.countBits(0));
    try expectEqual(@as(usize, 2), try bit_stream_be.countBits(1));
    try expectEqual(@as(usize, 0), try bit_stream_be.countBits(0));
    try expectEqual(@as(usize, 0), try bit_stream_be.countBits(1));

    const mem_le = [_]u8{ 0b10110011, 0b11010001 };
    var mem_in_le = io.fixedBufferStream(&mem_le);
    var bit_stream_le = bitReader(.little, mem_in_le.reader());

    try expectEqual(@as(usize, 0), try bit_stream_le.countBits(0));
    try expectEqual(@as(usize, 2), try bit_stream_le.countBits(1));
    try expectEqual(@as(usize, 2), try bit_stream_le.countBits(0));
    try expectEqual(@as(usize, 2), try bit_stream_le.countBits(1));
    try expectEqual(@as(usize, 1), try bit_stream_le.countBits(0));
    try expectEqual(@as(usize, 2), try bit_stream_le.countBits(1));
    try expectEqual(@as(usize, 3), try bit_stream_le.countBits(0));
    try expectEqual(@as(usize, 1), try bit_stream_le.countBits(1));
    try expectEqual(@as(usize, 1), try bit_stream_le.countBits(0));
    try expectEqual(@as(usize, 2), try bit_stream_le.countBits(1));
    try expectEqual(@as(usize, 0), try bit_stream_le.countBits(0));
    try expectEqual(@as(usize, 0), try bit_stream_le.countBits(1));
}
