const std = @import("../std.zig");
const io = std.io;

/// Takes a tuple of streams, and constructs a new stream that writes to all of them
pub fn MultiWriter(comptime Writers: type) type {
    comptime var ErrSet = error{};
    inline for (@typeInfo(Writers).@"struct".fields) |field| {
        const StreamType = field.type;
        ErrSet = ErrSet || StreamType.Error;
    }

    return struct {
        const Self = @This();

        streams: Writers,

        pub const Error = ErrSet;
        pub const Writer = io.Writer(*Self, Error, write);

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            inline for (self.streams) |stream|
                try stream.writeAll(bytes);
            return bytes.len;
        }
    };
}

pub fn multiWriter(streams: anytype) MultiWriter(@TypeOf(streams)) {
    return .{ .streams = streams };
}

const testing = std.testing;

test "MultiWriter" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var f = try tmp.dir.createFile("t.txt", .{});

    var buf1: [255]u8 = undefined;
    var fbs1 = io.fixedBufferStream(&buf1);
    var buf2: [255]u8 = undefined;
    var stream = multiWriter(.{ fbs1.writer(), f.writer() });

    try stream.writer().print("HI", .{});
    f.close();

    try testing.expectEqualSlices(u8, "HI", fbs1.getWritten());
    try testing.expectEqualSlices(u8, "HI", try tmp.dir.readFile("t.txt", &buf2));
}
