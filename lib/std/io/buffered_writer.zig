const std = @import("../std.zig");

const io = std.io;
const mem = std.mem;

pub fn BufferedWriter(comptime buffer_size: usize, comptime WriterType: type) type {
    return struct {
        unbuffered_writer: WriterType,
        buf: [buffer_size]u8 = undefined,
        end: usize = 0,

        pub const Error = WriterType.Error;
        pub const Writer = io.Writer(*Self, Error, writev);

        const Self = @This();

        pub fn flush(self: *Self) !void {
            try self.unbuffered_writer.writeAll(self.buf[0..self.end]);
            self.end = 0;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn writev(self: *Self, iov: []const std.os.iovec_const) Error!usize {
            var written: usize = 0;
            for (iov) |v| {
                const bytes = v.iov_base[0..v.iov_len];
                if (self.end + bytes.len > self.buf.len) {
                    try self.flush();
                    if (bytes.len > self.buf.len)
                        return self.unbuffered_writer.write(bytes);
                }

                const new_end = self.end + bytes.len;
                @memcpy(self.buf[self.end..new_end], bytes);
                self.end = new_end;
                written += bytes.len;
            }
            return written;
        }
    };
}

pub fn bufferedWriter(underlying_stream: anytype) BufferedWriter(4096, @TypeOf(underlying_stream)) {
    return .{ .unbuffered_writer = underlying_stream };
}
