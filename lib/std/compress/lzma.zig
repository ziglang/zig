const std = @import("../std.zig");
const Allocator = std.mem.Allocator;
const FixedBufferStream = std.io.FixedBufferStream;

pub const decode = @import("lzma/decode.zig");
pub const LzmaParams = decode.lzma.LzmaParams;
pub const LzmaDecoder = decode.lzma.LzmaDecoder;
pub const Lzma2Decoder = decode.lzma2.Lzma2Decoder;

pub fn lzmaDecompress(
    allocator: Allocator,
    reader: anytype,
    writer: anytype,
    options: decode.Options,
) !void {
    const params = try LzmaParams.readHeader(reader, options);
    var decoder = try LzmaDecoder.init(allocator, params, options.memlimit);
    defer decoder.deinit(allocator);
    return decoder.decompress(allocator, reader, writer);
}

pub fn lzma2Decompress(
    allocator: Allocator,
    reader: anytype,
    writer: anytype,
) !void {
    var decoder = try Lzma2Decoder.init(allocator);
    defer decoder.deinit(allocator);
    return decoder.decompress(allocator, reader, writer);
}

test {
    _ = @import("lzma/lzma_test.zig");
    _ = @import("lzma/lzma2_test.zig");
    _ = @import("lzma/vec2d.zig");
}
