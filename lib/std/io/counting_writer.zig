const std = @import("../std.zig");
const io = std.io;
const testing = std.testing;

/// A Writer that counts how many bytes has been written to it.
pub fn CountingWriter(comptime WriterType: type) type {
    return struct {
        bytes_written: u64,
        child_stream: WriterType,

        pub const Error = WriterType.Error;
        pub const Writer = io.Writer(*Self, Error, write);
        /// Deprecated: use `Writer`
        pub const OutStream = Writer;

        const Self = @This();

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            const amt = try self.child_stream.write(bytes);
            self.bytes_written += amt;
            return amt;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        /// Deprecated: use `writer`
        pub fn outStream(self: *Self) OutStream {
            return .{ .context = self };
        }
    };
}

pub fn countingWriter(child_stream: anytype) CountingWriter(@TypeOf(child_stream)) {
    return .{ .bytes_written = 0, .child_stream = child_stream };
}

test "io.CountingWriter" {
    var counting_stream = countingWriter(std.io.null_writer);
    const stream = counting_stream.writer();

    const bytes = "yay" ** 100;
    stream.writeAll(bytes) catch unreachable;
    testing.expect(counting_stream.bytes_written == bytes.len);
}
