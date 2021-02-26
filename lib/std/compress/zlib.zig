// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Decompressor for ZLIB data streams (RFC1950)

const std = @import("std");
const io = std.io;
const fs = std.fs;
const testing = std.testing;
const mem = std.mem;
const deflate = std.compress.deflate;

pub fn ZlibStream(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        pub const Error = ReaderType.Error ||
            deflate.InflateStream(ReaderType).Error ||
            error{ WrongChecksum, Unsupported };
        pub const Reader = io.Reader(*Self, Error, read);

        allocator: *mem.Allocator,
        inflater: deflate.InflateStream(ReaderType),
        in_reader: ReaderType,
        hasher: std.hash.Adler32,
        window_slice: []u8,

        fn init(allocator: *mem.Allocator, source: ReaderType) !Self {
            // Zlib header format is specified in RFC1950
            const header = try source.readBytesNoEof(2);

            const CM = @truncate(u4, header[0]);
            const CINFO = @truncate(u4, header[0] >> 4);
            const FCHECK = @truncate(u5, header[1]);
            const FDICT = @truncate(u1, header[1] >> 5);

            if ((@as(u16, header[0]) << 8 | header[1]) % 31 != 0)
                return error.BadHeader;

            // The CM field must be 8 to indicate the use of DEFLATE
            if (CM != 8) return error.InvalidCompression;
            // CINFO is the base-2 logarithm of the window size, minus 8.
            // Values above 7 are unspecified and therefore rejected.
            if (CINFO > 7) return error.InvalidWindowSize;
            const window_size: u16 = @as(u16, 1) << (CINFO + 8);

            // TODO: Support this case
            if (FDICT != 0)
                return error.Unsupported;

            var window_slice = try allocator.alloc(u8, window_size);

            return Self{
                .allocator = allocator,
                .inflater = deflate.inflateStream(source, window_slice),
                .in_reader = source,
                .hasher = std.hash.Adler32.init(),
                .window_slice = window_slice,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.window_slice);
        }

        // Implements the io.Reader interface
        pub fn read(self: *Self, buffer: []u8) Error!usize {
            if (buffer.len == 0)
                return 0;

            // Read from the compressed stream and update the computed checksum
            const r = try self.inflater.read(buffer);
            if (r != 0) {
                self.hasher.update(buffer[0..r]);
                return r;
            }

            // We've reached the end of stream, check if the checksum matches
            const hash = try self.in_reader.readIntBig(u32);
            if (hash != self.hasher.final())
                return error.WrongChecksum;

            return 0;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

pub fn zlibStream(allocator: *mem.Allocator, reader: anytype) !ZlibStream(@TypeOf(reader)) {
    return ZlibStream(@TypeOf(reader)).init(allocator, reader);
}

fn testReader(data: []const u8, comptime expected: []const u8) !void {
    var in_stream = io.fixedBufferStream(data);

    var zlib_stream = try zlibStream(testing.allocator, in_stream.reader());
    defer zlib_stream.deinit();

    // Read and decompress the whole file
    const buf = try zlib_stream.reader().readAllAlloc(testing.allocator, std.math.maxInt(usize));
    defer testing.allocator.free(buf);
    // Calculate its SHA256 hash and check it against the reference
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(buf, hash[0..], .{});

    assertEqual(expected, &hash);
}

// Assert `expected` == `input` where `input` is a bytestring.
pub fn assertEqual(comptime expected: []const u8, input: []const u8) void {
    var expected_bytes: [expected.len / 2]u8 = undefined;
    for (expected_bytes) |*r, i| {
        r.* = std.fmt.parseInt(u8, expected[2 * i .. 2 * i + 2], 16) catch unreachable;
    }

    testing.expectEqualSlices(u8, &expected_bytes, input);
}

// All the test cases are obtained by compressing the RFC1950 text
//
// https://tools.ietf.org/rfc/rfc1950.txt length=36944 bytes
// SHA256=5ebf4b5b7fe1c3a0c0ab9aa3ac8c0f3853a7dc484905e76e03b0b0f301350009
test "compressed data" {
    // Compressed with compression level = 0
    try testReader(
        @embedFile("rfc1951.txt.z.0"),
        "5ebf4b5b7fe1c3a0c0ab9aa3ac8c0f3853a7dc484905e76e03b0b0f301350009",
    );
    // Compressed with compression level = 9
    try testReader(
        @embedFile("rfc1951.txt.z.9"),
        "5ebf4b5b7fe1c3a0c0ab9aa3ac8c0f3853a7dc484905e76e03b0b0f301350009",
    );
    // Compressed with compression level = 9 and fixed Huffman codes
    try testReader(
        @embedFile("rfc1951.txt.fixed.z.9"),
        "5ebf4b5b7fe1c3a0c0ab9aa3ac8c0f3853a7dc484905e76e03b0b0f301350009",
    );
}

test "don't read past deflate stream's end" {
    try testReader(
        &[_]u8{
            0x08, 0xd7, 0x63, 0xf8, 0xcf, 0xc0, 0xc0, 0x00, 0xc1, 0xff,
            0xff, 0x43, 0x30, 0x03, 0x03, 0xc3, 0xff, 0xff, 0xff, 0x01,
            0x83, 0x95, 0x0b, 0xf5,
        },
        // SHA256 of
        // 00ff 0000 00ff 0000 00ff 00ff ffff 00ff ffff 0000 0000 ffff ff
        "3bbba1cc65408445c81abb61f3d2b86b1b60ee0d70b4c05b96d1499091a08c93",
    );
}

test "sanity checks" {
    // Truncated header
    testing.expectError(
        error.EndOfStream,
        testReader(&[_]u8{0x78}, ""),
    );
    // Failed FCHECK check
    testing.expectError(
        error.BadHeader,
        testReader(&[_]u8{ 0x78, 0x9D }, ""),
    );
    // Wrong CM
    testing.expectError(
        error.InvalidCompression,
        testReader(&[_]u8{ 0x79, 0x94 }, ""),
    );
    // Wrong CINFO
    testing.expectError(
        error.InvalidWindowSize,
        testReader(&[_]u8{ 0x88, 0x98 }, ""),
    );
    // Wrong checksum
    testing.expectError(
        error.WrongChecksum,
        testReader(&[_]u8{ 0x78, 0xda, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00 }, ""),
    );
    // Truncated checksum
    testing.expectError(
        error.EndOfStream,
        testReader(&[_]u8{ 0x78, 0xda, 0x03, 0x00, 0x00 }, ""),
    );
}
