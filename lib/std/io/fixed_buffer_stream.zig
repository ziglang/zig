// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const io = std.io;
const testing = std.testing;
const mem = std.mem;
const assert = std.debug.assert;

/// This turns a byte buffer into an `io.Writer`, `io.Reader`, or `io.SeekableStream`.
/// If the supplied byte buffer is const, then `io.Writer` is not available.
pub fn FixedBufferStream(comptime Buffer: type) type {
    return struct {
        /// `Buffer` is either a `[]u8` or `[]const u8`.
        buffer: Buffer,
        pos: usize,

        pub const ReadError = error{};
        pub const WriteError = error{NoSpaceLeft};
        pub const SeekError = error{};
        pub const GetSeekPosError = error{};

        pub const Reader = io.Reader(*Self, ReadError, read);
        pub const Writer = io.Writer(*Self, WriteError, write);

        pub const SeekableStream = io.SeekableStream(
            *Self,
            SeekError,
            GetSeekPosError,
            seekTo,
            seekBy,
            getPos,
            getEndPos,
        );

        const Self = @This();

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn seekableStream(self: *Self) SeekableStream {
            return .{ .context = self };
        }

        pub fn read(self: *Self, dest: []u8) ReadError!usize {
            const size = std.math.min(dest.len, self.buffer.len - self.pos);
            const end = self.pos + size;

            mem.copy(u8, dest[0..size], self.buffer[self.pos..end]);
            self.pos = end;

            return size;
        }

        /// If the returned number of bytes written is less than requested, the
        /// buffer is full. Returns `error.NoSpaceLeft` when no bytes would be written.
        /// Note: `error.NoSpaceLeft` matches the corresponding error from
        /// `std.fs.File.WriteError`.
        pub fn write(self: *Self, bytes: []const u8) WriteError!usize {
            if (bytes.len == 0) return 0;
            if (self.pos >= self.buffer.len) return error.NoSpaceLeft;

            const n = if (self.pos + bytes.len <= self.buffer.len)
                bytes.len
            else
                self.buffer.len - self.pos;

            mem.copy(u8, self.buffer[self.pos .. self.pos + n], bytes[0..n]);
            self.pos += n;

            if (n == 0) return error.NoSpaceLeft;

            return n;
        }

        pub fn seekTo(self: *Self, pos: u64) SeekError!void {
            self.pos = if (std.math.cast(usize, pos)) |x| x else |_| self.buffer.len;
        }

        pub fn seekBy(self: *Self, amt: i64) SeekError!void {
            if (amt < 0) {
                const abs_amt = std.math.absCast(amt);
                const abs_amt_usize = std.math.cast(usize, abs_amt) catch std.math.maxInt(usize);
                if (abs_amt_usize > self.pos) {
                    self.pos = 0;
                } else {
                    self.pos -= abs_amt_usize;
                }
            } else {
                const amt_usize = std.math.cast(usize, amt) catch std.math.maxInt(usize);
                const new_pos = std.math.add(usize, self.pos, amt_usize) catch std.math.maxInt(usize);
                self.pos = std.math.min(self.buffer.len, new_pos);
            }
        }

        pub fn getEndPos(self: *Self) GetSeekPosError!u64 {
            return self.buffer.len;
        }

        pub fn getPos(self: *Self) GetSeekPosError!u64 {
            return self.pos;
        }

        pub fn getWritten(self: Self) Buffer {
            return self.buffer[0..self.pos];
        }

        pub fn reset(self: *Self) void {
            self.pos = 0;
        }
    };
}

pub fn fixedBufferStream(buffer: anytype) FixedBufferStream(NonSentinelSpan(@TypeOf(buffer))) {
    return .{ .buffer = mem.span(buffer), .pos = 0 };
}

fn NonSentinelSpan(comptime T: type) type {
    var ptr_info = @typeInfo(mem.Span(T)).Pointer;
    ptr_info.sentinel = null;
    return @Type(std.builtin.TypeInfo{ .Pointer = ptr_info });
}

test "FixedBufferStream output" {
    var buf: [255]u8 = undefined;
    var fbs = fixedBufferStream(&buf);
    const stream = fbs.writer();

    try stream.print("{s}{s}!", .{ "Hello", "World" });
    try testing.expectEqualSlices(u8, "HelloWorld!", fbs.getWritten());
}

test "FixedBufferStream output 2" {
    var buffer: [10]u8 = undefined;
    var fbs = fixedBufferStream(&buffer);

    try fbs.writer().writeAll("Hello");
    try testing.expect(mem.eql(u8, fbs.getWritten(), "Hello"));

    try fbs.writer().writeAll("world");
    try testing.expect(mem.eql(u8, fbs.getWritten(), "Helloworld"));

    try testing.expectError(error.NoSpaceLeft, fbs.writer().writeAll("!"));
    try testing.expect(mem.eql(u8, fbs.getWritten(), "Helloworld"));

    fbs.reset();
    try testing.expect(fbs.getWritten().len == 0);

    try testing.expectError(error.NoSpaceLeft, fbs.writer().writeAll("Hello world!"));
    try testing.expect(mem.eql(u8, fbs.getWritten(), "Hello worl"));
}

test "FixedBufferStream input" {
    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6, 7 };
    var fbs = fixedBufferStream(&bytes);

    var dest: [4]u8 = undefined;

    var read = try fbs.reader().read(dest[0..4]);
    try testing.expect(read == 4);
    try testing.expect(mem.eql(u8, dest[0..4], bytes[0..4]));

    read = try fbs.reader().read(dest[0..4]);
    try testing.expect(read == 3);
    try testing.expect(mem.eql(u8, dest[0..3], bytes[4..7]));

    read = try fbs.reader().read(dest[0..4]);
    try testing.expect(read == 0);
}
