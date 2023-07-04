const std = @import("../std.zig");

const io = std.io;
const mem = std.mem;
const meta = std.meta;

pub fn BufferedWriter(comptime buffer_size: usize, comptime WriterType: type) type {
    return struct {
        unbuffered_writer: WriterType,
        buf: [buffer_size]u8 = undefined,
        end: usize = 0,

        pub const Error = WriterType.Error;
        pub const Writer = io.Writer(*Self, Error, write);

        const Self = @This();

        pub fn flush(self: *Self) !void {
            try self.unbuffered_writer.writeAll(self.buf[0..self.end]);
            self.end = 0;
        }

        pub const Container = if (meta.trait.isContainer(WriterType)) WriterType else meta.Child(WriterType);
        pub const Seeker = if (@hasDecl(Container, "seeker"))
            io.Seeker(*Self, Container.SeekError, seek)
        else
            @compileError("must implement Seeker interface for " ++ @typeName(Container));

        pub fn seeker(self: *Self) Seeker {
            return .{ .context = self };
        }

        pub fn seek(self: *Self, whence: io.Whence) Container.SeekError!u64 {
            if (comptime !@hasDecl(Container, "seeker")) {
                @compileError("must implement Seeker interface for " ++ @typeName(Container));
            }
            switch (whence) {
                .start => {
                    try self.flush();
                },
                .current, .end => |offset| {
                    if (whence != .current or offset != 0) {
                        try self.flush();
                    }
                },
                .get_end_pos, .set_end_pos => {},
            }
            return self.unbuffered_writer.seeker().seek(whence);
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
