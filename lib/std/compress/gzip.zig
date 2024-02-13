//
// Compressor/Decompressor for GZIP data streams (RFC1952)

const std = @import("../std.zig");
const io = std.io;
const fs = std.fs;
const testing = std.testing;
const mem = std.mem;
const deflate = std.compress.deflate;

const magic = &[2]u8{ 0x1f, 0x8b };

// Flags for the FLG field in the header
const FTEXT = 1 << 0;
const FHCRC = 1 << 1;
const FEXTRA = 1 << 2;
const FNAME = 1 << 3;
const FCOMMENT = 1 << 4;

const max_string_len = 1024;

pub const Header = struct {
    extra: ?[]const u8 = null,
    filename: ?[]const u8 = null,
    comment: ?[]const u8 = null,
    modification_time: u32 = 0,
    operating_system: u8 = 255,
};

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
        read_amt: u32,

        info: Header,

        fn init(allocator: mem.Allocator, in_reader: ReaderType) !Self {
            var hasher = std.compress.hashedReader(in_reader, std.hash.Crc32.init());
            const hashed_reader = hasher.reader();

            // gzip header format is specified in RFC1952
            const header = try hashed_reader.readBytesNoEof(10);

            // Check the ID1/ID2 fields
            if (!std.mem.eql(u8, header[0..2], magic))
                return error.BadHeader;

            const CM = header[2];
            // The CM field must be 8 to indicate the use of DEFLATE
            if (CM != 8) return error.InvalidCompression;
            // Flags
            const FLG = header[3];
            // Modification time, as a Unix timestamp.
            // If zero there's no timestamp available.
            const MTIME = mem.readInt(u32, header[4..8], .little);
            // Extra flags
            const XFL = header[8];
            // Operating system where the compression took place
            const OS = header[9];
            _ = XFL;

            const extra = if (FLG & FEXTRA != 0) blk: {
                const len = try hashed_reader.readInt(u16, .little);
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
                const hash = try in_reader.readInt(u16, .little);
                if (hash != @as(u16, @truncate(hasher.hasher.final())))
                    return error.WrongChecksum;
            }

            return .{
                .allocator = allocator,
                .inflater = try deflate.decompressor(allocator, in_reader, null),
                .in_reader = in_reader,
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

        /// Implements the io.Reader interface
        pub fn read(self: *Self, buffer: []u8) Error!usize {
            if (buffer.len == 0)
                return 0;

            // Read from the compressed stream and update the computed checksum
            const r = try self.inflater.read(buffer);
            if (r != 0) {
                self.hasher.update(buffer[0..r]);
                self.read_amt +%= @truncate(r);
                return r;
            }

            try self.inflater.close();

            // We've reached the end of stream, check if the checksum matches
            const hash = try self.in_reader.readInt(u32, .little);
            if (hash != self.hasher.final())
                return error.WrongChecksum;

            // The ISIZE field is the size of the uncompressed input modulo 2^32
            const input_size = try self.in_reader.readInt(u32, .little);
            if (self.read_amt != input_size)
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

pub const CompressOptions = struct {
    header: Header = .{},
    hash_header: bool = true,
    level: deflate.Compression = .default_compression,
};

pub fn Compress(comptime WriterType: type) type {
    return struct {
        const Self = @This();

        pub const Error = WriterType.Error ||
            deflate.Compressor(WriterType).Error;
        pub const Writer = io.Writer(*Self, Error, write);

        allocator: mem.Allocator,
        deflater: deflate.Compressor(WriterType),
        out_writer: WriterType,
        hasher: std.hash.Crc32,
        write_amt: u32,

        fn init(allocator: mem.Allocator, out_writer: WriterType, options: CompressOptions) !Self {
            var hasher = std.compress.hashedWriter(out_writer, std.hash.Crc32.init());
            const hashed_writer = hasher.writer();

            // ID1/ID2
            try hashed_writer.writeAll(magic);
            // CM
            try hashed_writer.writeByte(8);
            // Flags
            try hashed_writer.writeByte(
                @as(u8, if (options.hash_header) FHCRC else 0) |
                    @as(u8, if (options.header.extra) |_| FEXTRA else 0) |
                    @as(u8, if (options.header.filename) |_| FNAME else 0) |
                    @as(u8, if (options.header.comment) |_| FCOMMENT else 0),
            );
            // Modification time
            try hashed_writer.writeInt(u32, options.header.modification_time, .little);
            // Extra flags
            try hashed_writer.writeByte(0);
            // Operating system
            try hashed_writer.writeByte(options.header.operating_system);

            if (options.header.extra) |extra| {
                try hashed_writer.writeInt(u16, @intCast(extra.len), .little);
                try hashed_writer.writeAll(extra);
            }

            if (options.header.filename) |filename| {
                try hashed_writer.writeAll(filename);
                try hashed_writer.writeByte(0);
            }

            if (options.header.comment) |comment| {
                try hashed_writer.writeAll(comment);
                try hashed_writer.writeByte(0);
            }

            if (options.hash_header) {
                try out_writer.writeInt(
                    u16,
                    @truncate(hasher.hasher.final()),
                    .little,
                );
            }

            return .{
                .allocator = allocator,
                .deflater = try deflate.compressor(allocator, out_writer, .{ .level = options.level }),
                .out_writer = out_writer,
                .hasher = std.hash.Crc32.init(),
                .write_amt = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.deflater.deinit();
        }

        /// Implements the io.Writer interface
        pub fn write(self: *Self, buffer: []const u8) Error!usize {
            if (buffer.len == 0)
                return 0;

            // Write to the compressed stream and update the computed checksum
            const r = try self.deflater.write(buffer);
            self.hasher.update(buffer[0..r]);
            self.write_amt +%= @truncate(r);
            return r;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn flush(self: *Self) Error!void {
            try self.deflater.flush();
        }

        pub fn close(self: *Self) Error!void {
            try self.deflater.close();
            try self.out_writer.writeInt(u32, self.hasher.final(), .little);
            try self.out_writer.writeInt(u32, self.write_amt, .little);
        }
    };
}

pub fn compress(allocator: mem.Allocator, writer: anytype, options: CompressOptions) !Compress(@TypeOf(writer)) {
    return Compress(@TypeOf(writer)).init(allocator, writer, options);
}

fn testReader(expected: []const u8, data: []const u8) !void {
    var in_stream = io.fixedBufferStream(data);

    var gzip_stream = try decompress(testing.allocator, in_stream.reader());
    defer gzip_stream.deinit();

    // Read and decompress the whole file
    const buf = try gzip_stream.reader().readAllAlloc(testing.allocator, std.math.maxInt(usize));
    defer testing.allocator.free(buf);

    // Check against the reference
    try testing.expectEqualSlices(u8, expected, buf);
}

fn testWriter(expected: []const u8, data: []const u8, options: CompressOptions) !void {
    var actual = std.ArrayList(u8).init(testing.allocator);
    defer actual.deinit();

    var gzip_stream = try compress(testing.allocator, actual.writer(), options);
    defer gzip_stream.deinit();

    // Write and compress the whole file
    try gzip_stream.writer().writeAll(data);
    try gzip_stream.close();

    // Check against the reference
    try testing.expectEqualSlices(u8, expected, actual.items);
}

// All the test cases are obtained by compressing the RFC1952 text
//
// https://tools.ietf.org/rfc/rfc1952.txt length=25037 bytes
// SHA256=164ef0897b4cbec63abf1b57f069f3599bd0fb7c72c2a4dee21bd7e03ec9af67
test "compressed data" {
    const plain = @embedFile("testdata/rfc1952.txt");
    const compressed = @embedFile("testdata/rfc1952.txt.gz");
    try testReader(plain, compressed);
    try testWriter(compressed, plain, .{
        .header = .{
            .filename = "rfc1952.txt",
            .modification_time = 1706533053,
            .operating_system = 3,
        },
    });
}

test "sanity checks" {
    // Truncated header
    try testing.expectError(
        error.EndOfStream,
        testReader(undefined, &[_]u8{ 0x1f, 0x8B }),
    );
    // Wrong CM
    try testing.expectError(
        error.InvalidCompression,
        testReader(undefined, &[_]u8{
            0x1f, 0x8b, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03,
        }),
    );
    // Wrong checksum
    try testing.expectError(
        error.WrongChecksum,
        testReader(undefined, &[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x00,
        }),
    );
    // Truncated checksum
    try testing.expectError(
        error.EndOfStream,
        testReader(undefined, &[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00,
        }),
    );
    // Wrong initial size
    try testing.expectError(
        error.CorruptedData,
        testReader(undefined, &[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x01,
        }),
    );
    // Truncated initial size field
    try testing.expectError(
        error.EndOfStream,
        testReader(undefined, &[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00,
        }),
    );
}

test "header checksum" {
    try testReader("", &[_]u8{
        // GZIP header
        0x1f, 0x8b, 0x08, 0x12, 0x00, 0x09, 0x6e, 0x88, 0x00, 0xff, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x00,

        // header.FHCRC (should cover entire header)
        0x99, 0xd6,

        // GZIP data
        0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    });
}
