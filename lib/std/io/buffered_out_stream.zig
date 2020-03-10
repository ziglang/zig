const std = @import("../std.zig");
const io = std.io;

pub fn BufferedOutStream(comptime OutStreamType: type) type {
    return BufferedOutStreamCustom(4096, OutStreamType);
}

pub fn BufferedOutStreamCustom(comptime buffer_size: usize, comptime OutStreamType: type) type {
    return struct {
        unbuffered_out_stream: OutStreamType,
        fifo: FifoType,

        pub const Error = OutStreamType.Error;
        pub const OutStream = io.OutStream(*Self, Error, write);

        const Self = @This();
        const FifoType = std.fifo.LinearFifo(u8, std.fifo.LinearFifoBufferType{ .Static = buffer_size });

        pub fn init(unbuffered_out_stream: OutStreamType) Self {
            return Self{
                .unbuffered_out_stream = unbuffered_out_stream,
                .fifo = FifoType.init(),
            };
        }

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

pub fn bufferedOutStream(
    comptime buffer_size: usize,
    underlying_stream: var,
) BufferedOutStreamCustom(buffer_size, @TypeOf(underlying_stream)) {
    return BufferedOutStreamCustom(buffer_size, @TypeOf(underlying_stream)).init(underlying_stream);
}

