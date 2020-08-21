// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const io = std.io;
const mem = std.mem;
const testing = std.testing;

/// Creates a stream which supports 'un-reading' data, so that it can be read again.
/// This makes look-ahead style parsing much easier.
/// TODO merge this with `std.io.BufferedReader`: https://github.com/ziglang/zig/issues/4501
pub fn PeekStream(
    comptime buffer_type: std.fifo.LinearFifoBufferType,
    comptime ReaderType: type,
) type {
    return struct {
        unbuffered_in_stream: ReaderType,
        fifo: FifoType,

        pub const Error = ReaderType.Error;
        pub const Reader = io.Reader(*Self, Error, read);
        /// Deprecated: use `Reader`
        pub const InStream = Reader;

        const Self = @This();
        const FifoType = std.fifo.LinearFifo(u8, buffer_type);

        pub usingnamespace switch (buffer_type) {
            .Static => struct {
                pub fn init(base: ReaderType) Self {
                    return .{
                        .unbuffered_in_stream = base,
                        .fifo = FifoType.init(),
                    };
                }
            },
            .Slice => struct {
                pub fn init(base: ReaderType, buf: []u8) Self {
                    return .{
                        .unbuffered_in_stream = base,
                        .fifo = FifoType.init(buf),
                    };
                }
            },
            .Dynamic => struct {
                pub fn init(base: ReaderType, allocator: *mem.Allocator) Self {
                    return .{
                        .unbuffered_in_stream = base,
                        .fifo = FifoType.init(allocator),
                    };
                }
            },
        };

        pub fn putBackByte(self: *Self, byte: u8) !void {
            try self.putBack(&[_]u8{byte});
        }

        pub fn putBack(self: *Self, bytes: []const u8) !void {
            try self.fifo.unget(bytes);
        }

        pub fn read(self: *Self, dest: []u8) Error!usize {
            // copy over anything putBack()'d
            var dest_index = self.fifo.read(dest);
            if (dest_index == dest.len) return dest_index;

            // ask the backing stream for more
            dest_index += try self.unbuffered_in_stream.read(dest[dest_index..]);
            return dest_index;
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

pub fn peekStream(
    comptime lookahead: comptime_int,
    underlying_stream: anytype,
) PeekStream(.{ .Static = lookahead }, @TypeOf(underlying_stream)) {
    return PeekStream(.{ .Static = lookahead }, @TypeOf(underlying_stream)).init(underlying_stream);
}

test "PeekStream" {
    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var fbs = io.fixedBufferStream(&bytes);
    var ps = peekStream(2, fbs.reader());

    var dest: [4]u8 = undefined;

    try ps.putBackByte(9);
    try ps.putBackByte(10);

    var read = try ps.reader().read(dest[0..4]);
    testing.expect(read == 4);
    testing.expect(dest[0] == 10);
    testing.expect(dest[1] == 9);
    testing.expect(mem.eql(u8, dest[2..4], bytes[0..2]));

    read = try ps.reader().read(dest[0..4]);
    testing.expect(read == 4);
    testing.expect(mem.eql(u8, dest[0..4], bytes[2..6]));

    read = try ps.reader().read(dest[0..4]);
    testing.expect(read == 2);
    testing.expect(mem.eql(u8, dest[0..2], bytes[6..8]));

    try ps.putBackByte(11);
    try ps.putBackByte(12);

    read = try ps.reader().read(dest[0..4]);
    testing.expect(read == 2);
    testing.expect(dest[0] == 12);
    testing.expect(dest[1] == 11);
}
