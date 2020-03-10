const std = @import("../std.zig");
const io = std.io;
const assert = std.debug.assert;
const testing = std.testing;

pub fn BufferedInStream(comptime buffer_size: usize, comptime InStreamType: type) type {
    return struct {
        unbuffered_in_stream: InStreamType,
        fifo: FifoType = FifoType.init(),

        pub const Error = InStreamType.Error;
        pub const InStream = io.InStream(*Self, Error, read);

        const Self = @This();
        const FifoType = std.fifo.LinearFifo(u8, std.fifo.LinearFifoBufferType{ .Static = buffer_size });

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

pub fn bufferedInStream(underlying_stream: var) BufferedInStream(4096, @TypeOf(underlying_stream)) {
    return .{ .unbuffered_in_stream = underlying_stream };
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
