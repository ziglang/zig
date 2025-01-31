/// Deflate is a lossless data compression file format that uses a combination
/// of LZ77 and Huffman coding.
pub const deflate = @import("flate/deflate.zig");

/// Inflate is the decoding process that takes a Deflate bitstream for
/// decompression and correctly produces the original full-size data or file.
pub const inflate = @import("flate/inflate.zig");

/// Decompress compressed data from reader and write plain data to the writer.
pub fn decompress(reader: anytype, writer: anytype) !void {
    try inflate.decompress(.raw, reader, writer);
}

/// Decompressor type
pub fn Decompressor(comptime ReaderType: type) type {
    return inflate.Decompressor(.raw, ReaderType);
}

/// Create Decompressor which will read compressed data from reader.
pub fn decompressor(reader: anytype) Decompressor(@TypeOf(reader)) {
    return inflate.decompressor(.raw, reader);
}

/// Compression level, trades between speed and compression size.
pub const Options = deflate.Options;

/// Compress plain data from reader and write compressed data to the writer.
pub fn compress(reader: anytype, writer: anytype, options: Options) !void {
    try deflate.compress(.raw, reader, writer, options);
}

/// Compressor type
pub fn Compressor(comptime WriterType: type) type {
    return deflate.Compressor(.raw, WriterType);
}

/// Create Compressor which outputs compressed data to the writer.
pub fn compressor(writer: anytype, options: Options) !Compressor(@TypeOf(writer)) {
    return try deflate.compressor(.raw, writer, options);
}

/// Huffman only compression. Without Lempel-Ziv match searching. Faster
/// compression, less memory requirements but bigger compressed sizes.
pub const huffman = struct {
    pub fn compress(reader: anytype, writer: anytype) !void {
        try deflate.huffman.compress(.raw, reader, writer);
    }

    pub fn Compressor(comptime WriterType: type) type {
        return deflate.huffman.Compressor(.raw, WriterType);
    }

    pub fn compressor(writer: anytype) !huffman.Compressor(@TypeOf(writer)) {
        return deflate.huffman.compressor(.raw, writer);
    }
};

// No compression store only. Compressed size is slightly bigger than plain.
pub const store = struct {
    pub fn compress(reader: anytype, writer: anytype) !void {
        try deflate.store.compress(.raw, reader, writer);
    }

    pub fn Compressor(comptime WriterType: type) type {
        return deflate.store.Compressor(.raw, WriterType);
    }

    pub fn compressor(writer: anytype) !store.Compressor(@TypeOf(writer)) {
        return deflate.store.compressor(.raw, writer);
    }
};

/// Container defines header/footer around deflate bit stream. Gzip and zlib
/// compression algorithms are containers around deflate bit stream body.
const Container = @import("flate/container.zig").Container;
const std = @import("std");
const testing = std.testing;
const fixedBufferStream = std.io.fixedBufferStream;
const print = std.debug.print;
const builtin = @import("builtin");

test {
    _ = deflate;
    _ = inflate;
}

test "compress/decompress" {
    var cmp_buf: [64 * 1024]u8 = undefined; // compressed data buffer
    var dcm_buf: [64 * 1024]u8 = undefined; // decompressed data buffer

    const levels = [_]deflate.Level{ .level_4, .level_5, .level_6, .level_7, .level_8, .level_9 };
    const cases = [_]struct {
        data: []const u8, // uncompressed content
        // compressed data sizes per level 4-9
        gzip_sizes: [levels.len]usize = [_]usize{0} ** levels.len,
        huffman_only_size: usize = 0,
        store_size: usize = 0,
    }{
        .{
            .data = @embedFile("flate/testdata/rfc1951.txt"),
            .gzip_sizes = [_]usize{ 11513, 11217, 11139, 11126, 11122, 11119 },
            .huffman_only_size = 20287,
            .store_size = 36967,
        },
        .{
            .data = @embedFile("flate/testdata/fuzz/roundtrip1.input"),
            .gzip_sizes = [_]usize{ 373, 370, 370, 370, 370, 370 },
            .huffman_only_size = 393,
            .store_size = 393,
        },
        .{
            .data = @embedFile("flate/testdata/fuzz/roundtrip2.input"),
            .gzip_sizes = [_]usize{ 373, 373, 373, 373, 373, 373 },
            .huffman_only_size = 394,
            .store_size = 394,
        },
        .{
            .data = @embedFile("flate/testdata/fuzz/deflate-stream.expect"),
            .gzip_sizes = [_]usize{ 351, 347, 347, 347, 347, 347 },
            .huffman_only_size = 498,
            .store_size = 747,
        },
    };

    for (cases, 0..) |case, case_no| { // for each case
        const data = case.data;

        for (levels, 0..) |level, i| { // for each compression level

            inline for (Container.list) |container| { // for each wrapping
                var compressed_size: usize = if (case.gzip_sizes[i] > 0)
                    case.gzip_sizes[i] - Container.gzip.size() + container.size()
                else
                    0;

                // compress original stream to compressed stream
                {
                    var original = fixedBufferStream(data);
                    var compressed = fixedBufferStream(&cmp_buf);
                    try deflate.compress(container, original.reader(), compressed.writer(), .{ .level = level });
                    if (compressed_size == 0) {
                        if (container == .gzip)
                            print("case {d} gzip level {} compressed size: {d}\n", .{ case_no, level, compressed.pos });
                        compressed_size = compressed.pos;
                    }
                    try testing.expectEqual(compressed_size, compressed.pos);
                }
                // decompress compressed stream to decompressed stream
                {
                    var compressed = fixedBufferStream(cmp_buf[0..compressed_size]);
                    var decompressed = fixedBufferStream(&dcm_buf);
                    try inflate.decompress(container, compressed.reader(), decompressed.writer());
                    try testing.expectEqualSlices(u8, data, decompressed.getWritten());
                }

                // compressor writer interface
                {
                    var compressed = fixedBufferStream(&cmp_buf);
                    var cmp = try deflate.compressor(container, compressed.writer(), .{ .level = level });
                    var cmp_wrt = cmp.writer();
                    try cmp_wrt.writeAll(data);
                    try cmp.finish();

                    try testing.expectEqual(compressed_size, compressed.pos);
                }
                // decompressor reader interface
                {
                    var compressed = fixedBufferStream(cmp_buf[0..compressed_size]);
                    var dcm = inflate.decompressor(container, compressed.reader());
                    var dcm_rdr = dcm.reader();
                    const n = try dcm_rdr.readAll(&dcm_buf);
                    try testing.expectEqual(data.len, n);
                    try testing.expectEqualSlices(u8, data, dcm_buf[0..n]);
                }
            }
        }
        // huffman only compression
        {
            inline for (Container.list) |container| { // for each wrapping
                var compressed_size: usize = if (case.huffman_only_size > 0)
                    case.huffman_only_size - Container.gzip.size() + container.size()
                else
                    0;

                // compress original stream to compressed stream
                {
                    var original = fixedBufferStream(data);
                    var compressed = fixedBufferStream(&cmp_buf);
                    var cmp = try deflate.huffman.compressor(container, compressed.writer());
                    try cmp.compress(original.reader());
                    try cmp.finish();
                    if (compressed_size == 0) {
                        if (container == .gzip)
                            print("case {d} huffman only compressed size: {d}\n", .{ case_no, compressed.pos });
                        compressed_size = compressed.pos;
                    }
                    try testing.expectEqual(compressed_size, compressed.pos);
                }
                // decompress compressed stream to decompressed stream
                {
                    var compressed = fixedBufferStream(cmp_buf[0..compressed_size]);
                    var decompressed = fixedBufferStream(&dcm_buf);
                    try inflate.decompress(container, compressed.reader(), decompressed.writer());
                    try testing.expectEqualSlices(u8, data, decompressed.getWritten());
                }
            }
        }

        // store only
        {
            inline for (Container.list) |container| { // for each wrapping
                var compressed_size: usize = if (case.store_size > 0)
                    case.store_size - Container.gzip.size() + container.size()
                else
                    0;

                // compress original stream to compressed stream
                {
                    var original = fixedBufferStream(data);
                    var compressed = fixedBufferStream(&cmp_buf);
                    var cmp = try deflate.store.compressor(container, compressed.writer());
                    try cmp.compress(original.reader());
                    try cmp.finish();
                    if (compressed_size == 0) {
                        if (container == .gzip)
                            print("case {d} store only compressed size: {d}\n", .{ case_no, compressed.pos });
                        compressed_size = compressed.pos;
                    }

                    try testing.expectEqual(compressed_size, compressed.pos);
                }
                // decompress compressed stream to decompressed stream
                {
                    var compressed = fixedBufferStream(cmp_buf[0..compressed_size]);
                    var decompressed = fixedBufferStream(&dcm_buf);
                    try inflate.decompress(container, compressed.reader(), decompressed.writer());
                    try testing.expectEqualSlices(u8, data, decompressed.getWritten());
                }
            }
        }
    }
}

fn testDecompress(comptime container: Container, compressed: []const u8, expected_plain: []const u8) !void {
    var in = fixedBufferStream(compressed);
    var out = std.ArrayList(u8).init(testing.allocator);
    defer out.deinit();

    try inflate.decompress(container, in.reader(), out.writer());
    try testing.expectEqualSlices(u8, expected_plain, out.items);
}

test "don't read past deflate stream's end" {
    try testDecompress(.zlib, &[_]u8{
        0x08, 0xd7, 0x63, 0xf8, 0xcf, 0xc0, 0xc0, 0x00, 0xc1, 0xff,
        0xff, 0x43, 0x30, 0x03, 0x03, 0xc3, 0xff, 0xff, 0xff, 0x01,
        0x83, 0x95, 0x0b, 0xf5,
    }, &[_]u8{
        0x00, 0xff, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00, 0xff,
        0x00, 0xff, 0xff, 0xff, 0x00, 0xff, 0xff, 0xff, 0x00, 0x00,
        0x00, 0x00, 0xff, 0xff, 0xff,
    });
}

test "zlib header" {
    // Truncated header
    try testing.expectError(
        error.EndOfStream,
        testDecompress(.zlib, &[_]u8{0x78}, ""),
    );
    // Wrong CM
    try testing.expectError(
        error.BadZlibHeader,
        testDecompress(.zlib, &[_]u8{ 0x79, 0x94 }, ""),
    );
    // Wrong CINFO
    try testing.expectError(
        error.BadZlibHeader,
        testDecompress(.zlib, &[_]u8{ 0x88, 0x98 }, ""),
    );
    // Wrong checksum
    try testing.expectError(
        error.WrongZlibChecksum,
        testDecompress(.zlib, &[_]u8{ 0x78, 0xda, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00 }, ""),
    );
    // Truncated checksum
    try testing.expectError(
        error.EndOfStream,
        testDecompress(.zlib, &[_]u8{ 0x78, 0xda, 0x03, 0x00, 0x00 }, ""),
    );
}

test "gzip header" {
    // Truncated header
    try testing.expectError(
        error.EndOfStream,
        testDecompress(.gzip, &[_]u8{ 0x1f, 0x8B }, undefined),
    );
    // Wrong CM
    try testing.expectError(
        error.BadGzipHeader,
        testDecompress(.gzip, &[_]u8{
            0x1f, 0x8b, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03,
        }, undefined),
    );

    // Wrong checksum
    try testing.expectError(
        error.WrongGzipChecksum,
        testDecompress(.gzip, &[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x00,
        }, undefined),
    );
    // Truncated checksum
    try testing.expectError(
        error.EndOfStream,
        testDecompress(.gzip, &[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00,
        }, undefined),
    );
    // Wrong initial size
    try testing.expectError(
        error.WrongGzipSize,
        testDecompress(.gzip, &[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x01,
        }, undefined),
    );
    // Truncated initial size field
    try testing.expectError(
        error.EndOfStream,
        testDecompress(.gzip, &[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00,
        }, undefined),
    );

    try testDecompress(.gzip, &[_]u8{
        // GZIP header
        0x1f, 0x8b, 0x08, 0x12, 0x00, 0x09, 0x6e, 0x88, 0x00, 0xff, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x00,
        // header.FHCRC (should cover entire header)
        0x99, 0xd6,
        // GZIP data
        0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    }, "");
}

test "public interface" {
    const plain_data = [_]u8{ 'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', 0x0a };

    // deflate final stored block, header + plain (stored) data
    const deflate_block = [_]u8{
        0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, // deflate fixed buffer header len, nlen
    } ++ plain_data;

    // gzip header/footer + deflate block
    const gzip_data =
        [_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03 } ++ // gzip header (10 bytes)
        deflate_block ++
        [_]u8{ 0xd5, 0xe0, 0x39, 0xb7, 0x0c, 0x00, 0x00, 0x00 }; // gzip footer checksum (4 byte), size (4 bytes)

    // zlib header/footer + deflate block
    const zlib_data = [_]u8{ 0x78, 0b10_0_11100 } ++ // zlib header (2 bytes)}
        deflate_block ++
        [_]u8{ 0x1c, 0xf2, 0x04, 0x47 }; // zlib footer: checksum

    const gzip = @import("gzip.zig");
    const zlib = @import("zlib.zig");
    const flate = @This();

    try testInterface(gzip, &gzip_data, &plain_data);
    try testInterface(zlib, &zlib_data, &plain_data);
    try testInterface(flate, &deflate_block, &plain_data);
}

fn testInterface(comptime pkg: type, gzip_data: []const u8, plain_data: []const u8) !void {
    var buffer1: [64]u8 = undefined;
    var buffer2: [64]u8 = undefined;

    var compressed = fixedBufferStream(&buffer1);
    var plain = fixedBufferStream(&buffer2);

    // decompress
    {
        var in = fixedBufferStream(gzip_data);
        try pkg.decompress(in.reader(), plain.writer());
        try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
    }
    plain.reset();
    compressed.reset();

    // compress/decompress
    {
        var in = fixedBufferStream(plain_data);
        try pkg.compress(in.reader(), compressed.writer(), .{});
        compressed.reset();
        try pkg.decompress(compressed.reader(), plain.writer());
        try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
    }
    plain.reset();
    compressed.reset();

    // compressor/decompressor
    {
        var in = fixedBufferStream(plain_data);
        var cmp = try pkg.compressor(compressed.writer(), .{});
        try cmp.compress(in.reader());
        try cmp.finish();

        compressed.reset();
        var dcp = pkg.decompressor(compressed.reader());
        try dcp.decompress(plain.writer());
        try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
    }
    plain.reset();
    compressed.reset();

    // huffman
    {
        // huffman compress/decompress
        {
            var in = fixedBufferStream(plain_data);
            try pkg.huffman.compress(in.reader(), compressed.writer());
            compressed.reset();
            try pkg.decompress(compressed.reader(), plain.writer());
            try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
        }
        plain.reset();
        compressed.reset();

        // huffman compressor/decompressor
        {
            var in = fixedBufferStream(plain_data);
            var cmp = try pkg.huffman.compressor(compressed.writer());
            try cmp.compress(in.reader());
            try cmp.finish();

            compressed.reset();
            try pkg.decompress(compressed.reader(), plain.writer());
            try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
        }
    }
    plain.reset();
    compressed.reset();

    // store
    {
        // store compress/decompress
        {
            var in = fixedBufferStream(plain_data);
            try pkg.store.compress(in.reader(), compressed.writer());
            compressed.reset();
            try pkg.decompress(compressed.reader(), plain.writer());
            try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
        }
        plain.reset();
        compressed.reset();

        // store compressor/decompressor
        {
            var in = fixedBufferStream(plain_data);
            var cmp = try pkg.store.compressor(compressed.writer());
            try cmp.compress(in.reader());
            try cmp.finish();

            compressed.reset();
            try pkg.decompress(compressed.reader(), plain.writer());
            try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
        }
    }
}
