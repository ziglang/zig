const std = @import("../std.zig");
const io = std.io;

/// An OutStream that counts how many bytes has been written to it.
pub fn CountingOutStream(comptime OutStreamType: type) type {
    return struct {
        bytes_written: u64,
        child_stream: OutStreamType,

        pub const Error = OutStreamType.Error;
        pub const OutStream = io.OutStream(*Self, Error, write);

        const Self = @This();

        pub fn init(child_stream: OutStreamType) Self {
            return Self{
                .bytes_written = 0,
                .child_stream = child_stream,
            };
        }

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            const amt = try self.child_stream.write(bytes);
            self.bytes_written += amt;
            return amt;
        }

        pub fn outStream(self: *Self) OutStream {
            return .{ .context = self };
        }
    };
}

test "io.CountingOutStream" {
    var counting_stream = CountingOutStream(NullOutStream.Error).init(std.io.null_out_stream);
    const stream = &counting_stream.stream;

    const bytes = "yay" ** 10000;
    stream.write(bytes) catch unreachable;
    testing.expect(counting_stream.bytes_written == bytes.len);
}

