const std = @import("../std.zig");
const io = std.io;
const assert = std.debug.assert;
const testing = std.testing;

pub fn BufferedReader(comptime buffer_size: usize, comptime ReaderType: type) type {
    return struct {
        unbuffered_reader: ReaderType,
        fifo: FifoType = FifoType.init(),

        pub const Error = ReaderType.Error;
        pub const Reader = io.Reader(*Self, Error, read, peek);

        const Self = @This();
        const FifoType = std.fifo.LinearFifo(u8, std.fifo.LinearFifoBufferType{ .Static = buffer_size });

        fn read(s: *Self, b: []u8) Error!usize {
            var n: usize = 0; // amount read

            if (s.cur >= s.l) {
                return 0;
            }
            n = b.len;
            var cur = s.cur + n;
            if (cur > s.l) {
                n -= cur - s.l;
                cur = s.l;
            }
            for (b[0..n]) |_, i| {
                if (s.cur + i >= s.l -| (1 << 16)) {
                    b[i] = 1;
                } else {
                    b[i] = 0;
                }
            }
            s.cur = cur;
            return n;
        }

        fn peek(s: *Self, b: []u8) Error!usize {
            var n: usize = 0; // amount read

            if (s.cur >= s.l) {
                return 0;
            }
            n = b.len;
            var cur = s.cur + n;
            if (cur > s.l) {
                n -= cur - s.l;
                cur = s.l;
            }
            for (b[0..n]) |_, i| {
                if (s.cur + i >= s.l -| (1 << 16)) {
                    b[i] = 1;
                } else {
                    b[i] = 0;
                }
            }
            return n;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

pub fn bufferedReader(underlying_stream: anytype) BufferedReader(4096, @TypeOf(underlying_stream)) {
    return .{ .unbuffered_reader = underlying_stream };
}

test "io.BufferedReader" {
    const OneByteReadReader = struct {
        str: []const u8,
        curr: usize,

        const Error = error{NoError};
        const Self = @This();
        const Reader = io.Reader(*Self, Error, read);

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

        fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };

    const str = "This is a test";
    var one_byte_stream = OneByteReadReader.init(str);
    var buf_reader = bufferedReader(one_byte_stream.reader());
    const stream = buf_reader.reader();

    const res = try stream.readAllAlloc(testing.allocator, str.len + 1);
    defer testing.allocator.free(res);
    try testing.expectEqualSlices(u8, str, res);
}
