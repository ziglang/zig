const std = @import("../std.zig");
const io = std.io;
const testing = std.testing;

/// An OutStream that counts how many bytes has been written to it.
pub fn CountingOutStream(comptime OutStreamType: type) type {
    return struct {
        bytes_written: u64,
        child_stream: OutStreamType,

        pub const Error = OutStreamType.Error;
        pub const OutStream = io.OutStream(*Self, Error, write);

        const Self = @This();

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

pub fn countingOutStream(child_stream: var) CountingOutStream(@TypeOf(child_stream)) {
    return .{ .bytes_written = 0, .child_stream = child_stream };
}

test "io.CountingOutStream" {
    var counting_stream = countingOutStream(std.io.null_out_stream);
    const stream = counting_stream.outStream();

    const bytes = "yay" ** 100;
    stream.writeAll(bytes) catch unreachable;
    testing.expect(counting_stream.bytes_written == bytes.len);
}
