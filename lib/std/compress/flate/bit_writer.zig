const std = @import("std");
const assert = std.debug.assert;

/// Bit writer for use in deflate (compression).
///
/// Has internal bits buffer of 64 bits and internal bytes buffer of 248 bytes.
/// When we accumulate 48 bits 6 bytes are moved to the bytes buffer. When we
/// accumulate 240 bytes they are flushed to the underlying inner_writer.
///
pub fn BitWriter(comptime WriterType: type) type {
    // buffer_flush_size indicates the buffer size
    // after which bytes are flushed to the writer.
    // Should preferably be a multiple of 6, since
    // we accumulate 6 bytes between writes to the buffer.
    const buffer_flush_size = 240;

    // buffer_size is the actual output byte buffer size.
    // It must have additional headroom for a flush
    // which can contain up to 8 bytes.
    const buffer_size = buffer_flush_size + 8;

    return struct {
        inner_writer: WriterType,

        // Data waiting to be written is bytes[0 .. nbytes]
        // and then the low nbits of bits.  Data is always written
        // sequentially into the bytes array.
        bits: u64 = 0,
        nbits: u32 = 0, // number of bits
        bytes: [buffer_size]u8 = undefined,
        nbytes: u32 = 0, // number of bytes

        const Self = @This();

        pub const Error = WriterType.Error || error{UnfinishedBits};

        pub fn init(writer: WriterType) Self {
            return .{ .inner_writer = writer };
        }

        pub fn setWriter(self: *Self, new_writer: WriterType) void {
            //assert(self.bits == 0 and self.nbits == 0 and self.nbytes == 0);
            self.inner_writer = new_writer;
        }

        pub fn flush(self: *Self) Error!void {
            var n = self.nbytes;
            while (self.nbits != 0) {
                self.bytes[n] = @as(u8, @truncate(self.bits));
                self.bits >>= 8;
                if (self.nbits > 8) { // Avoid underflow
                    self.nbits -= 8;
                } else {
                    self.nbits = 0;
                }
                n += 1;
            }
            self.bits = 0;
            _ = try self.inner_writer.write(self.bytes[0..n]);
            self.nbytes = 0;
        }

        pub fn writeBits(self: *Self, b: u32, nb: u32) Error!void {
            self.bits |= @as(u64, @intCast(b)) << @as(u6, @intCast(self.nbits));
            self.nbits += nb;
            if (self.nbits < 48)
                return;

            var n = self.nbytes;
            std.mem.writeInt(u64, self.bytes[n..][0..8], self.bits, .little);
            n += 6;
            if (n >= buffer_flush_size) {
                _ = try self.inner_writer.write(self.bytes[0..n]);
                n = 0;
            }
            self.nbytes = n;
            self.bits >>= 48;
            self.nbits -= 48;
        }

        pub fn writeBytes(self: *Self, bytes: []const u8) Error!void {
            var n = self.nbytes;
            if (self.nbits & 7 != 0) {
                return error.UnfinishedBits;
            }
            while (self.nbits != 0) {
                self.bytes[n] = @as(u8, @truncate(self.bits));
                self.bits >>= 8;
                self.nbits -= 8;
                n += 1;
            }
            if (n != 0) {
                _ = try self.inner_writer.write(self.bytes[0..n]);
            }
            self.nbytes = 0;
            _ = try self.inner_writer.write(bytes);
        }
    };
}
