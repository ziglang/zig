// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const io = std.io;
const assert = std.debug.assert;
const testing = std.testing;

pub fn BufferedReader(comptime buffer_size: usize, comptime ReaderType: type) type {
    return struct {
        unbuffered_reader: ReaderType,
        fifo: FifoType = FifoType.init(),

        pub const Error = ReaderType.Error;
        pub const Reader = io.Reader(*Self, Error, read);
        /// Deprecated: use `Reader`
        pub const InStream = Reader;

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
                    const n = try self.unbuffered_reader.read(writable);
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

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        /// Deprecated: use `reader`
        pub fn inStream(self: *Self) InStream {
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
    testing.expectEqualSlices(u8, str, res);
}
