const std = @import("../std.zig");

const io = std.io;
const meta = std.meta;
const mem = std.mem;

pub fn BufferedWriter(comptime buffer_size: usize, comptime WriterType: type) type {
    return struct {
        unbuffered_writer: WriterType,
        buf: [mem.alignForward(usize, buffer_size, @sizeOf(usize))]u8 = undefined,
        end: usize = 0,

        pub const WriterContainer = if (meta.trait.isContainer(WriterType)) WriterType else meta.Child(WriterType);
        pub const Error = if (@hasDecl(WriterContainer, "WriteError")) WriterContainer.WriteError else WriterContainer.Error;
        pub const Writer = io.Writer(*Self, Error, write);

        const Self = @This();

        pub fn flush(self: *Self) Error!void {
            if (self.end > 0) {
                try self.unbuffered_writer.writeAll(self.buf[0..self.end]);
                self.end = 0;
            }
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            if (self.end + bytes.len > self.buf.len) {
                try self.flush();
                if (bytes.len > self.buf.len)
                    return self.unbuffered_writer.write(bytes);
            }

            const new_end = self.end + bytes.len;
            @memcpy(self.buf[self.end..new_end], bytes);
            self.end = new_end;
            return bytes.len;
        }
    };
}

pub fn bufferedWriter(underlying_stream: anytype) BufferedWriter(4096, @TypeOf(underlying_stream)) {
    return .{ .unbuffered_writer = underlying_stream };
}
