const std = @import("../std.zig");
const io = std.io;

pub fn BufferedOutStream(comptime buffer_size: usize, comptime OutStreamType: type) type {
    return struct {
        unbuffered_out_stream: OutStreamType,
        fifo: FifoType = FifoType.init(),

        pub const Error = OutStreamType.Error;
        pub const OutStream = io.OutStream(*Self, Error, write);

        const Self = @This();
        const FifoType = std.fifo.LinearFifo(u8, std.fifo.LinearFifoBufferType{ .Static = buffer_size });

        pub fn flush(self: *Self) !void {
            while (true) {
                const slice = self.fifo.readableSlice(0);
                if (slice.len == 0) break;
                try self.unbuffered_out_stream.writeAll(slice);
                self.fifo.discard(slice.len);
            }
        }

        pub fn outStream(self: *Self) OutStream {
            return .{ .context = self };
        }

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            if (bytes.len >= self.fifo.writableLength()) {
                try self.flush();
                return self.unbuffered_out_stream.write(bytes);
            }
            self.fifo.writeAssumeCapacity(bytes);
            return bytes.len;
        }
    };
}

pub fn bufferedOutStream(underlying_stream: var) BufferedOutStream(4096, @TypeOf(underlying_stream)) {
    return .{ .unbuffered_out_stream = underlying_stream };
}
