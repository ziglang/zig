const std = @import("../std.zig");
const io = std.io;
const assert = std.debug.assert;
const testing = std.testing;

pub fn BufferedInStream(comptime buffer_type: std.fifo.LinearFifoBufferType, comptime InStreamType: type) type {
    return struct {
        unbuffered_in_stream: InStreamType,
        fifo: FifoType,

        pub const Error = InStreamType.Error;
        pub const InStream = io.InStream(*Self, Error, read);

        const Self = @This();
        const FifoType = std.fifo.LinearFifo(u8, buffer_type);

        pub usingnamespace switch (buffer_type) {
            .Static => struct {
                pub fn init(unbuffered_in_stream: InStreamType) Self {
                    return .{
                        .unbuffered_in_stream = unbuffered_in_stream,
                        .fifo = FifoType.init(),
                    };
                }
            },
            .Slice => struct {
                pub fn init(unbuffered_in_stream: InStreamType, buf: []u8) Self {
                    return .{
                        .unbuffered_in_stream = unbuffered_in_stream,
                        .fifo = FifoType.init(buf),
                    };
                }
            },
            .Dynamic => struct {
                pub fn init(unbuffered_in_stream: InStreamType, allocator: *mem.Allocator) Self {
                    return .{
                        .unbuffered_in_stream = unbuffered_in_stream,
                        .fifo = FifoType.init(allocator),
                    };
                }
            },
        };

        pub fn deinit(self: Self) void {
            self.fifo.deinit();
        }

        pub fn read(self: *Self, dest: []u8) Error!usize {
            var dest_index: usize = 0;
            while (dest_index < dest.len) {
                const written = self.fifo.read(dest[dest_index..]);
                if (written == 0) {
                    // fifo empty, fill it
                    const writable = self.fifo.writableSlice(0);
                    assert(writable.len > 0);
                    const n = try self.unbuffered_in_stream.read(writable);
                    if (n == 0) {
                        // reading from the unbuffered stream returned nothing
                        // so we have nothing left to read.
                        return dest_index;
                    }
                    self.fifo.update(n);
                }
                dest_index += written;
            }
            return dest.len;
        }

        pub fn inStream(self: *Self) InStream {
            return .{ .context = self };
        }
    };
}

/// A buffering wrapper around another stream
/// Uses a statically allocated buffer; no need to .deinit().
pub fn bufferedInStream(underlying_stream: var) BufferedInStream(.{ .Static = 4096 }, @TypeOf(underlying_stream)) {
    return BufferedInStream(.{ .Static = 4096 }, @TypeOf(underlying_stream)).init(underlying_stream);
}

test "io.BufferedInStream" {
    const OneByteReadInStream = struct {
        str: []const u8,
        curr: usize,

        const Error = error{NoError};
        const Self = @This();
        const InStream = io.InStream(*Self, Error, read);

        fn init(str: []const u8) Self {
            return Self{
                .str = str,
                .curr = 0,
            };
        }

        fn read(self: *Self, dest: []u8) Error!usize {
            if (self.str.len <= self.curr or dest.len == 0)
                return 0;

            dest[0] = self.str[self.curr];
            self.curr += 1;
            return 1;
        }

        fn inStream(self: *Self) InStream {
            return .{ .context = self };
        }
    };

    const str = "This is a test";
    var one_byte_stream = OneByteReadInStream.init(str);
    var buf_in_stream = bufferedInStream(one_byte_stream.inStream());
    const stream = buf_in_stream.inStream();

    const res = try stream.readAllAlloc(testing.allocator, str.len + 1);
    defer testing.allocator.free(res);
    testing.expectEqualSlices(u8, str, res);
}

test "io.BufferedInStream.putBack*" {
    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var fbs = io.fixedBufferStream(&bytes);
    var ps = BufferedInStream(.{ .Static = 2 }, @TypeOf(fbs.inStream())).init(fbs.inStream());
    defer ps.deinit();

    var dest: [4]u8 = undefined;

    try ps.putBackByte(9);
    try ps.putBackByte(10);

    var read = try ps.inStream().read(dest[0..4]);
    testing.expectEqual(@as(usize, 4), read);
    testing.expectEqual(@as(u8, 10), dest[0]);
    testing.expectEqual(@as(u8, 9), dest[1]);
    testing.expectEqualSlices(u8, bytes[0..2], dest[2..4]);

    read = try ps.inStream().read(dest[0..4]);
    testing.expectEqual(@as(usize, 4), read);
    testing.expectEqualSlices(u8, bytes[2..6], dest[0..4]);

    read = try ps.inStream().read(dest[0..4]);
    testing.expectEqual(@as(usize, 2), read);
    testing.expectEqualSlices(u8, bytes[6..8], dest[0..2]);

    try ps.putBackByte(11);
    try ps.putBackByte(12);

    read = try ps.inStream().read(dest[0..4]);
    testing.expectEqual(@as(usize, 2), read);
    testing.expectEqual(@as(u8, 12), dest[0]);
    testing.expectEqual(@as(u8, 11), dest[1]);
}
