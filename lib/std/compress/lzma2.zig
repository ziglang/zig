const std = @import("../std.zig");
const Allocator = std.mem.Allocator;

pub const decode = @import("lzma2/decode.zig");

pub fn decompress(
    allocator: Allocator,
    reader: anytype,
    writer: anytype,
) !void {
    var decoder = try decode.Decoder.init(allocator);
    defer decoder.deinit(allocator);
    return decoder.decompress(allocator, reader, writer);
}

test {
    const expected = "Hello\nWorld!\n";
    const compressed = &[_]u8{ 0x01, 0x00, 0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x0A, 0x02, 0x00, 0x06, 0x57, 0x6F, 0x72, 0x6C, 0x64, 0x21, 0x0A, 0x00 };

    const allocator = std.testing.allocator;
    var decomp = std.ArrayList(u8).init(allocator);
    defer decomp.deinit();
    var stream = std.io.fixedBufferStream(compressed);
    try decompress(allocator, stream.reader(), decomp.writer());
    try std.testing.expectEqualSlices(u8, expected, decomp.items);
}
