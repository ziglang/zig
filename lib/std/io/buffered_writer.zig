const std = @import("../std.zig");
const io = std.io;

pub fn BufferedWriter(comptime buffer_size: usize, comptime WriterType: type) type {
    return struct {
        unbuffered_writer: WriterType,
        fifo: FifoType = FifoType.init(),

        pub const Error = WriterType.Error;
        pub const Writer = io.Writer(*Self, Error, write);
        /// Deprecated: use `Writer`
        pub const OutStream = Writer;

        const Self = @This();
        const FifoType = std.fifo.LinearFifo(u8, std.fifo.LinearFifoBufferType{ .Static = buffer_size });

        pub fn flush(self: *Self) !void {
            while (true) {
                const slice = self.fifo.readableSlice(0);
                if (slice.len == 0) break;
                try self.unbuffered_writer.writeAll(slice);
                self.fifo.discard(slice.len);
            }
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        /// Deprecated: use writer
        pub fn outStream(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            if (bytes.len >= self.fifo.writableLength()) {
                try self.flush();
                return self.unbuffered_writer.write(bytes);
            }
            self.fifo.writeAssumeCapacity(bytes);
            return bytes.len;
        }
    };
}

pub fn bufferedWriter(underlying_stream: anytype) BufferedWriter(4096, @TypeOf(underlying_stream)) {
    return .{ .unbuffered_writer = underlying_stream };
}
