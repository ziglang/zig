const std = @import("../std.zig");
const deflate = @import("flate/deflate.zig");
const inflate = @import("flate/inflate.zig");

/// Decompress compressed data from reader and write plain data to the writer.
pub fn decompress(reader: *std.io.BufferedReader, writer: *std.io.BufferedWriter) !void {
    try inflate.decompress(.gzip, reader, writer);
}

pub const Decompressor = inflate.Decompressor(.gzip);

/// Compression level, trades between speed and compression size.
pub const Options = deflate.Options;

/// Compress plain data from reader and write compressed data to the writer.
pub fn compress(reader: *std.io.BufferedReader, writer: *std.io.BufferedWriter, options: Options) !void {
    try deflate.compress(.gzip, reader, writer, options);
}

pub const Compressor = deflate.Compressor(.gzip);

/// Huffman only compression. Without Lempel-Ziv match searching. Faster
/// compression, less memory requirements but bigger compressed sizes.
pub const huffman = struct {
    pub fn compress(reader: *std.io.BufferedReader, writer: *std.io.BufferedWriter) !void {
        try deflate.huffman.compress(.gzip, reader, writer);
    }

    pub const Compressor = deflate.huffman.Compressor(.gzip);
};

// No compression store only. Compressed size is slightly bigger than plain.
pub const store = struct {
    pub fn compress(reader: *std.io.BufferedReader, writer: *std.io.BufferedWriter) !void {
        try deflate.store.compress(.gzip, reader, writer);
    }

    pub const Compressor = deflate.store.Compressor(.gzip);
};
