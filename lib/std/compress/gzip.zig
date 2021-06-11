// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Decompressor for GZIP data streams (RFC1952)

const std = @import("std");
const io = std.io;
const fs = std.fs;
const testing = std.testing;
const mem = std.mem;
const deflate = std.compress.deflate;

// Flags for the FLG field in the header
const FTEXT = 1 << 0;
const FHCRC = 1 << 1;
const FEXTRA = 1 << 2;
const FNAME = 1 << 3;
const FCOMMENT = 1 << 4;

pub fn GzipStream(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        pub const Error = ReaderType.Error ||
            deflate.InflateStream(ReaderType).Error ||
            error{ CorruptedData, WrongChecksum };
        pub const Reader = io.Reader(*Self, Error, read);

        allocator: *mem.Allocator,
        inflater: deflate.InflateStream(ReaderType),
        in_reader: ReaderType,
        hasher: std.hash.Crc32,
        window_slice: []u8,
        read_amt: usize,

        info: struct {
            filename: ?[]const u8,
            comment: ?[]const u8,
            modification_time: u32,
        },

        fn init(allocator: *mem.Allocator, source: ReaderType) !Self {
            // gzip header format is specified in RFC1952
            const header = try source.readBytesNoEof(10);

            // Check the ID1/ID2 fields
            if (header[0] != 0x1f or header[1] != 0x8b)
                return error.BadHeader;

            const CM = header[2];
            // The CM field must be 8 to indicate the use of DEFLATE
            if (CM != 8) return error.InvalidCompression;
            // Flags
            const FLG = header[3];
            // Modification time, as a Unix timestamp.
            // If zero there's no timestamp available.
            const MTIME = mem.readIntLittle(u32, header[4..8]);
            // Extra flags
            const XFL = header[8];
            // Operating system where the compression took place
            const OS = header[9];

            if (FLG & FEXTRA != 0) {
                // Skip the extra data, we could read and expose it to the user
                // if somebody needs it.
                const len = try source.readIntLittle(u16);
                try source.skipBytes(len, .{});
            }

            var filename: ?[]const u8 = null;
            if (FLG & FNAME != 0) {
                filename = try source.readUntilDelimiterAlloc(
                    allocator,
                    0,
                    std.math.maxInt(usize),
                );
            }
            errdefer if (filename) |p| allocator.free(p);

            var comment: ?[]const u8 = null;
            if (FLG & FCOMMENT != 0) {
                comment = try source.readUntilDelimiterAlloc(
                    allocator,
                    0,
                    std.math.maxInt(usize),
                );
            }
            errdefer if (comment) |p| allocator.free(p);

            if (FLG & FHCRC != 0) {
                // TODO: Evaluate and check the header checksum. The stdlib has
                // no CRC16 yet :(
                _ = try source.readIntLittle(u16);
            }

            // The RFC doesn't say anything about the DEFLATE window size to be
            // used, default to 32K.
            var window_slice = try allocator.alloc(u8, 32 * 1024);

            return Self{
                .allocator = allocator,
                .inflater = deflate.inflateStream(source, window_slice),
                .in_reader = source,
                .hasher = std.hash.Crc32.init(),
                .window_slice = window_slice,
                .info = .{
                    .filename = filename,
                    .comment = comment,
                    .modification_time = MTIME,
                },
                .read_amt = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.window_slice);
            if (self.info.filename) |filename|
                self.allocator.free(filename);
            if (self.info.comment) |comment|
                self.allocator.free(comment);
        }

        // Implements the io.Reader interface
        pub fn read(self: *Self, buffer: []u8) Error!usize {
            if (buffer.len == 0)
                return 0;

            // Read from the compressed stream and update the computed checksum
            const r = try self.inflater.read(buffer);
            if (r != 0) {
                self.hasher.update(buffer[0..r]);
                self.read_amt += r;
                return r;
            }

            // We've reached the end of stream, check if the checksum matches
            const hash = try self.in_reader.readIntLittle(u32);
            if (hash != self.hasher.final())
                return error.WrongChecksum;

            // The ISIZE field is the size of the uncompressed input modulo 2^32
            const input_size = try self.in_reader.readIntLittle(u32);
            if (self.read_amt & 0xffffffff != input_size)
                return error.CorruptedData;

            return 0;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

pub fn gzipStream(allocator: *mem.Allocator, reader: anytype) !GzipStream(@TypeOf(reader)) {
    return GzipStream(@TypeOf(reader)).init(allocator, reader);
}

fn testReader(data: []const u8, comptime expected: []const u8) !void {
    var in_stream = io.fixedBufferStream(data);

    var gzip_stream = try gzipStream(testing.allocator, in_stream.reader());
    defer gzip_stream.deinit();

    // Read and decompress the whole file
    const buf = try gzip_stream.reader().readAllAlloc(testing.allocator, std.math.maxInt(usize));
    defer testing.allocator.free(buf);
    // Calculate its SHA256 hash and check it against the reference
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(buf, hash[0..], .{});

    try assertEqual(expected, &hash);
}

// Assert `expected` == `input` where `input` is a bytestring.
pub fn assertEqual(comptime expected: []const u8, input: []const u8) !void {
    var expected_bytes: [expected.len / 2]u8 = undefined;
    for (expected_bytes) |*r, i| {
        r.* = std.fmt.parseInt(u8, expected[2 * i .. 2 * i + 2], 16) catch unreachable;
    }

    try testing.expectEqualSlices(u8, &expected_bytes, input);
}

// All the test cases are obtained by compressing the RFC1952 text
//
// https://tools.ietf.org/rfc/rfc1952.txt length=25037 bytes
// SHA256=164ef0897b4cbec63abf1b57f069f3599bd0fb7c72c2a4dee21bd7e03ec9af67
test "compressed data" {
    try testReader(
        @embedFile("rfc1952.txt.gz"),
        "164ef0897b4cbec63abf1b57f069f3599bd0fb7c72c2a4dee21bd7e03ec9af67",
    );
}

test "sanity checks" {
    // Truncated header
    try testing.expectError(
        error.EndOfStream,
        testReader(&[_]u8{ 0x1f, 0x8B }, ""),
    );
    // Wrong CM
    try testing.expectError(
        error.InvalidCompression,
        testReader(&[_]u8{
            0x1f, 0x8b, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03,
        }, ""),
    );
    // Wrong checksum
    try testing.expectError(
        error.WrongChecksum,
        testReader(&[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x00,
        }, ""),
    );
    // Truncated checksum
    try testing.expectError(
        error.EndOfStream,
        testReader(&[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00,
        }, ""),
    );
    // Wrong initial size
    try testing.expectError(
        error.CorruptedData,
        testReader(&[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x01,
        }, ""),
    );
    // Truncated initial size field
    try testing.expectError(
        error.EndOfStream,
        testReader(&[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00,
        }, ""),
    );
}
