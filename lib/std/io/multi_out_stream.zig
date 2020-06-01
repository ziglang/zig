const std = @import("../std.zig");
const io = std.io;
const testing = std.testing;

/// Takes a tuple of streams, and constructs a new stream that writes to all of them
pub fn MultiOutStream(comptime OutStreams: type) type {
    comptime var ErrSet = error{};
    inline for (@typeInfo(OutStreams).Struct.fields) |field| {
        const StreamType = field.field_type;
        ErrSet = ErrSet || StreamType.Error;
    }

    return struct {
        const Self = @This();

        streams: OutStreams,

        pub const Error = ErrSet;
        pub const OutStream = io.OutStream(*Self, Error, write);
        pub fn outStream(self: *Self) OutStream {
            return .{ .context = self };
        }

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            var batch = std.event.Batch(Error!void, self.streams.len, .auto_async).init();
            comptime var i = 0;
            inline while (i < self.streams.len) : (i += 1) {
                const stream = self.streams[i];
                // TODO: remove ptrCast: https://github.com/ziglang/zig/issues/5258
                batch.add(@ptrCast(anyframe->Error!void, &async stream.writeAll(bytes)));
            }
            try batch.wait();
            return bytes.len;
        }
    };
}

pub fn multiOutStream(streams: var) MultiOutStream(@TypeOf(streams)) {
    return .{ .streams = streams };
}

test "MultiOutStream" {
    var buf1: [255]u8 = undefined;
    var fbs1 = io.fixedBufferStream(&buf1);
    var buf2: [255]u8 = undefined;
    var fbs2 = io.fixedBufferStream(&buf2);
    var stream = multiOutStream(.{ fbs1.outStream(), fbs2.outStream() });
    try stream.outStream().print("HI", .{});
    testing.expectEqualSlices(u8, "HI", fbs1.getWritten());
    testing.expectEqualSlices(u8, "HI", fbs2.getWritten());
}
