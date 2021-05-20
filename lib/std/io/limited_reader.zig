// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const io = std.io;
const assert = std.debug.assert;
const testing = std.testing;

pub fn LimitedReader(comptime ReaderType: type) type {
    return struct {
        inner_reader: ReaderType,
        bytes_left: u64,

        pub const Error = ReaderType.Error;
        pub const Reader = io.Reader(*Self, Error, read);

        const Self = @This();

        pub fn read(self: *Self, dest: []u8) Error!usize {
            const max_read = std.math.min(self.bytes_left, dest.len);
            const n = try self.inner_reader.read(dest[0..max_read]);
            self.bytes_left -= n;
            return n;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

/// Returns an initialised `LimitedReader`
/// `bytes_left` is a `u64` to be able to take 64 bit file offsets
pub fn limitedReader(inner_reader: anytype, bytes_left: u64) LimitedReader(@TypeOf(inner_reader)) {
    return .{ .inner_reader = inner_reader, .bytes_left = bytes_left };
}

test "basic usage" {
    const data = "hello world";
    var fbs = std.io.fixedBufferStream(data);
    var early_stream = limitedReader(fbs.reader(), 3);

    var buf: [5]u8 = undefined;
    try testing.expectEqual(@as(usize, 3), try early_stream.reader().read(&buf));
    try testing.expectEqualSlices(u8, data[0..3], buf[0..3]);
    try testing.expectEqual(@as(usize, 0), try early_stream.reader().read(&buf));
    try testing.expectError(error.EndOfStream, early_stream.reader().skipBytes(10, .{}));
}
