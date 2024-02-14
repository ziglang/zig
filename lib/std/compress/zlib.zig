const deflate = @import("flate/deflate.zig");
const inflate = @import("flate/inflate.zig");

/// Decompress compressed data from reader and write plain data to the writer.
pub fn decompress(reader: anytype, writer: anytype) !void {
    try inflate.decompress(.zlib, reader, writer);
}

/// Decompressor type
pub fn Decompressor(comptime ReaderType: type) type {
    return inflate.Inflate(.zlib, ReaderType);
}

/// Create Decompressor which will read compressed data from reader.
pub fn decompressor(reader: anytype) Decompressor(@TypeOf(reader)) {
    return inflate.decompressor(.zlib, reader);
}

/// Compression level, trades between speed and compression size.
pub const Options = deflate.Options;

/// Compress plain data from reader and write compressed data to the writer.
pub fn compress(reader: anytype, writer: anytype, options: Options) !void {
    try deflate.compress(.zlib, reader, writer, options);
}

/// Compressor type
pub fn Compressor(comptime WriterType: type) type {
    return deflate.Compressor(.zlib, WriterType);
}

/// Create Compressor which outputs compressed data to the writer.
pub fn compressor(writer: anytype, options: Options) !Compressor(@TypeOf(writer)) {
    return try deflate.compressor(.zlib, writer, options);
}

/// Huffman only compression. Without Lempel-Ziv match searching. Faster
/// compression, less memory requirements but bigger compressed sizes.
pub const huffman = struct {
    pub fn compress(reader: anytype, writer: anytype) !void {
        try deflate.huffman.compress(.zlib, reader, writer);
    }

    pub fn Compressor(comptime WriterType: type) type {
        return deflate.huffman.Compressor(.zlib, WriterType);
    }

    pub fn compressor(writer: anytype) !huffman.Compressor(@TypeOf(writer)) {
        return deflate.huffman.compressor(.zlib, writer);
    }
};

// No compression store only. Compressed size is slightly bigger than plain.
pub const store = struct {
    pub fn compress(reader: anytype, writer: anytype) !void {
        try deflate.store.compress(.zlib, reader, writer);
    }

    pub fn Compressor(comptime WriterType: type) type {
        return deflate.store.Compressor(.zlib, WriterType);
    }

    pub fn compressor(writer: anytype) !store.Compressor(@TypeOf(writer)) {
        return deflate.store.compressor(.zlib, writer);
    }
};
