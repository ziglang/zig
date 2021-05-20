// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const io = std.io;
const testing = std.testing;

/// A Reader that counts how many bytes has been read from it.
pub fn CountingReader(comptime ReaderType: anytype) type {
    return struct {
        child_reader: ReaderType,
        bytes_read: u64 = 0,

        pub const Error = ReaderType.Error;
        pub const Reader = io.Reader(*@This(), Error, read);

        pub fn read(self: *@This(), buf: []u8) Error!usize {
            const amt = try self.child_reader.read(buf);
            self.bytes_read += amt;
            return amt;
        }

        pub fn reader(self: *@This()) Reader {
            return .{ .context = self };
        }
    };
}

pub fn countingReader(reader: anytype) CountingReader(@TypeOf(reader)) {
    return .{ .child_reader = reader };
}

test "io.CountingReader" {
    const bytes = "yay" ** 100;
    var fbs = io.fixedBufferStream(bytes);

    var counting_stream = countingReader(fbs.reader());
    const stream = counting_stream.reader();

    //read and discard all bytes
    while (stream.readByte()) |_| {} else |err| {
        try testing.expect(err == error.EndOfStream);
    }

    try testing.expect(counting_stream.bytes_read == bytes.len);
}
