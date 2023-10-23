//
// Decompressor for GZIP data streams (RFC1952)

const std = @import("../std.zig");
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

const max_string_len = 1024;

pub fn Decompress(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        pub const Error = ReaderType.Error ||
            deflate.Decompressor(ReaderType).Error ||
            error{ CorruptedData, WrongChecksum };
        pub const Reader = io.Reader(*Self, Error, read);

        allocator: mem.Allocator,
        inflater: deflate.Decompressor(ReaderType),
        in_reader: ReaderType,
        hasher: std.hash.Crc32,
        read_amt: usize,

        info: struct {
            extra: ?[]const u8,
            filename: ?[]const u8,
            comment: ?[]const u8,
            modification_time: u32,
            operating_system: u8,
        },

        fn init(allocator: mem.Allocator, source: ReaderType) !Self {
            var hasher = std.compress.hashedReader(source, std.hash.Crc32.init());
            const hashed_reader = hasher.reader();

            // gzip header format is specified in RFC1952
            const header = try hashed_reader.readBytesNoEof(10);

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
            _ = XFL;

            const extra = if (FLG & FEXTRA != 0) blk: {
                const len = try hashed_reader.readIntLittle(u16);
                const tmp_buf = try allocator.alloc(u8, len);
                errdefer allocator.free(tmp_buf);

                try hashed_reader.readNoEof(tmp_buf);
                break :blk tmp_buf;
            } else null;
            errdefer if (extra) |p| allocator.free(p);

            const filename = if (FLG & FNAME != 0)
                try hashed_reader.readUntilDelimiterAlloc(allocator, 0, max_string_len)
            else
                null;
            errdefer if (filename) |p| allocator.free(p);

            const comment = if (FLG & FCOMMENT != 0)
                try hashed_reader.readUntilDelimiterAlloc(allocator, 0, max_string_len)
            else
                null;
            errdefer if (comment) |p| allocator.free(p);

            if (FLG & FHCRC != 0) {
                const hash = try source.readIntLittle(u16);
                if (hash != @as(u16, @truncate(hasher.hasher.final())))
                    return error.WrongChecksum;
            }

            return Self{
                .allocator = allocator,
                .inflater = try deflate.decompressor(allocator, source, null),
                .in_reader = source,
                .hasher = std.hash.Crc32.init(),
                .info = .{
                    .filename = filename,
                    .comment = comment,
                    .extra = extra,
                    .modification_time = MTIME,
                    .operating_system = OS,
                },
                .read_amt = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.inflater.deinit();
            if (self.info.extra) |extra|
                self.allocator.free(extra);
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

pub fn decompress(allocator: mem.Allocator, reader: anytype) !Decompress(@TypeOf(reader)) {
    return Decompress(@TypeOf(reader)).init(allocator, reader);
}

fn testReader(data: []const u8, comptime expected: []const u8) !void {
    var in_stream = io.fixedBufferStream(data);

    var gzip_stream = try decompress(testing.allocator, in_stream.reader());
    defer gzip_stream.deinit();

    // Read and decompress the whole file
    const buf = try gzip_stream.reader().readAllAlloc(testing.allocator, std.math.maxInt(usize));
    defer testing.allocator.free(buf);

    // Check against the reference
    try testing.expectEqualSlices(u8, expected, buf);
}

// All the test cases are obtained by compressing the RFC1952 text
//
// https://tools.ietf.org/rfc/rfc1952.txt length=25037 bytes
// SHA256=164ef0897b4cbec63abf1b57f069f3599bd0fb7c72c2a4dee21bd7e03ec9af67
test "compressed data" {
    try testReader(
        @embedFile("testdata/rfc1952.txt.gz"),
        @embedFile("testdata/rfc1952.txt"),
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

test "header checksum" {
    try testReader(&[_]u8{
        // GZIP header
        0x1f, 0x8b, 0x08, 0x12, 0x00, 0x09, 0x6e, 0x88, 0x00, 0xff, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x00,

        // header.FHCRC (should cover entire header)
        0x99, 0xd6,

        // GZIP data
        0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    }, "");
}
