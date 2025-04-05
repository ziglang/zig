const std = @import("../std.zig");
const deflate = @import("flate/deflate.zig");
const inflate = @import("flate/inflate.zig");

/// Decompress compressed data from reader and write plain data to the writer.
pub fn decompress(reader: *std.io.BufferedReader, writer: *std.io.BufferedWriter) !void {
    try inflate.decompress(.zlib, reader, writer);
}

pub const Decompressor = inflate.Decompressor(.zlib);

/// Compression level, trades between speed and compression size.
pub const Options = deflate.Options;

/// Compress plain data from reader and write compressed data to the writer.
pub fn compress(reader: *std.io.BufferedReader, writer: *std.io.BufferedWriter, options: Options) !void {
    try deflate.compress(.zlib, reader, writer, options);
}

pub const Compressor = deflate.Compressor(.zlib);

/// Huffman only compression. Without Lempel-Ziv match searching. Faster
/// compression, less memory requirements but bigger compressed sizes.
pub const huffman = struct {
    pub fn compress(reader: *std.io.BufferedReader, writer: *std.io.BufferedWriter) !void {
        try deflate.huffman.compress(.zlib, reader, writer);
    }

    pub const Compressor = deflate.huffman.Compressor(.zlib);
};

// No compression store only. Compressed size is slightly bigger than plain.
pub const store = struct {
    pub fn compress(reader: *std.io.BufferedReader, writer: *std.io.BufferedWriter) !void {
        try deflate.store.compress(.zlib, reader, writer);
    }

    pub const Compressor = deflate.store.Compressor(.zlib);
};

test "should not overshoot" {
    // Compressed zlib data with extra 4 bytes at the end.
    const data = [_]u8{
        0x78, 0x9c, 0x73, 0xce, 0x2f, 0xa8, 0x2c, 0xca, 0x4c, 0xcf, 0x28, 0x51, 0x08, 0xcf, 0xcc, 0xc9,
        0x49, 0xcd, 0x55, 0x28, 0x4b, 0xcc, 0x53, 0x08, 0x4e, 0xce, 0x48, 0xcc, 0xcc, 0xd6, 0x51, 0x08,
        0xce, 0xcc, 0x4b, 0x4f, 0x2c, 0xc8, 0x2f, 0x4a, 0x55, 0x30, 0xb4, 0xb4, 0x34, 0xd5, 0xb5, 0x34,
        0x03, 0x00, 0x8b, 0x61, 0x0f, 0xa4, 0x52, 0x5a, 0x94, 0x12,
    };

    var stream = std.io.fixedBufferStream(data[0..]);
    const reader = stream.reader();

    var dcp = Decompressor.init(reader);
    var out: [128]u8 = undefined;

    // Decompress
    var n = try dcp.reader().readAll(out[0..]);

    // Expected decompressed data
    try std.testing.expectEqual(46, n);
    try std.testing.expectEqualStrings("Copyright Willem van Schaik, Singapore 1995-96", out[0..n]);

    // Decompressor don't overshoot underlying reader.
    // It is leaving it at the end of compressed data chunk.
    try std.testing.expectEqual(data.len - 4, stream.getPos());
    try std.testing.expectEqual(0, dcp.unreadBytes());

    // 4 bytes after compressed chunk are available in reader.
    n = try reader.readAll(out[0..]);
    try std.testing.expectEqual(n, 4);
    try std.testing.expectEqualSlices(u8, data[data.len - 4 .. data.len], out[0..n]);
}
