//! The deflate package is a translation of the Go code of the compress/flate package from
//! https://go.googlesource.com/go/+/refs/tags/go1.17/src/compress/flate/

const deflate = @import("deflate/compressor.zig");
const inflate = @import("deflate/decompressor.zig");

pub const Compression = deflate.Compression;
pub const CompressorOptions = deflate.CompressorOptions;
pub const Compressor = deflate.Compressor;
pub const Decompressor = inflate.Decompressor;

pub const compressor = deflate.compressor;
pub const decompressor = inflate.decompressor;

/// Copies elements from a source `src` slice into a destination `dst` slice.
/// The copy never returns an error but might not be complete if the destination is too small.
/// Returns the number of elements copied, which will be the minimum of `src.len` and `dst.len`.
/// TODO: remove this smelly function
pub fn copy(dst: []u8, src: []const u8) usize {
    if (dst.len <= src.len) {
        @memcpy(dst, src[0..dst.len]);
        return dst.len;
    } else {
        @memcpy(dst[0..src.len], src);
        return src.len;
    }
}

test {
    _ = @import("deflate/token.zig");
    _ = @import("deflate/bits_utils.zig");
    _ = @import("deflate/dict_decoder.zig");

    _ = @import("deflate/huffman_code.zig");
    _ = @import("deflate/huffman_bit_writer.zig");

    _ = @import("deflate/compressor.zig");
    _ = @import("deflate/compressor_test.zig");

    _ = @import("deflate/deflate_fast.zig");
    _ = @import("deflate/deflate_fast_test.zig");

    _ = @import("deflate/decompressor.zig");
}
