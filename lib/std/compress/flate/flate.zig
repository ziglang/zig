/// Deflate is a lossless data compression file format that uses a combination
/// of LZ77 and Huffman coding.
pub const deflate = @import("deflate.zig");

/// Inflate is the decoding process that takes a Deflate bitstream for
/// decompression and correctly produces the original full-size data or file.
pub const inflate = @import("inflate.zig");

/// Decompress compressed data from reader and write plain data to the writer.
pub fn decompress(reader: anytype, writer: anytype) !void {
    try inflate.decompress(.raw, reader, writer);
}

/// Decompressor type
pub fn Decompressor(comptime ReaderType: type) type {
    return inflate.Inflate(.raw, ReaderType);
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

/// Container defines header/footer arround deflate bit stream. Gzip and zlib
/// compression algorithms are containers arround deflate bit stream body.
const Container = @import("container.zig").Container;
const std = @import("std");
const testing = std.testing;
const fixedBufferStream = std.io.fixedBufferStream;
const print = std.debug.print;

test "flate compress/decompress" {
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
            .data = @embedFile("testdata/rfc1951.txt"),
            .gzip_sizes = [_]usize{ 11513, 11217, 11139, 11126, 11122, 11119 },
            .huffman_only_size = 20287,
            .store_size = 36967,
        },
        .{
            .data = @embedFile("testdata/fuzz/roundtrip1.input"),
            .gzip_sizes = [_]usize{ 373, 370, 370, 370, 370, 370 },
            .huffman_only_size = 393,
            .store_size = 393,
        },
        .{
            .data = @embedFile("testdata/fuzz/roundtrip2.input"),
            .gzip_sizes = [_]usize{ 373, 373, 373, 373, 373, 373 },
            .huffman_only_size = 394,
            .store_size = 394,
        },
        .{
            .data = @embedFile("testdata/fuzz/deflate-stream.expect"),
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
