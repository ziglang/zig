const std = @import("../std.zig");
const Allocator = std.mem.Allocator;

pub const decode = @import("lzma/decode.zig");

pub fn decompress(
    allocator: Allocator,
    reader: anytype,
    writer: anytype,
    options: decode.Options,
) !void {
    const params = try decode.Params.readHeader(reader, options);
    var decoder = try decode.Decoder.init(allocator, params, options.memlimit);
    defer decoder.deinit(allocator);
    return decoder.decompress(allocator, reader, writer);
}

test {
    _ = @import("lzma/test.zig");
    _ = @import("lzma/vec2d.zig");
}
