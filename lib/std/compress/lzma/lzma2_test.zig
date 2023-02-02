const std = @import("../../std.zig");
const lzma = @import("../lzma.zig");

fn testDecompress(compressed: []const u8, writer: anytype) !void {
    const allocator = std.testing.allocator;
    var stream = std.io.fixedBufferStream(compressed);
    try lzma.lzma2Decompress(allocator, stream.reader(), writer);
}

fn testDecompressEqual(expected: []const u8, compressed: []const u8) !void {
    const allocator = std.testing.allocator;
    var decomp = std.ArrayList(u8).init(allocator);
    defer decomp.deinit();
    try testDecompress(compressed, decomp.writer());
    try std.testing.expectEqualSlices(u8, expected, decomp.items);
}

fn testDecompressError(expected: anyerror, compressed: []const u8) !void {
    return std.testing.expectError(expected, testDecompress(compressed, std.io.null_writer));
}

test {
    try testDecompressEqual(
        "Hello\nWorld!\n",
        &[_]u8{ 0x01, 0x00, 0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x0A, 0x02, 0x00, 0x06, 0x57, 0x6F, 0x72, 0x6C, 0x64, 0x21, 0x0A, 0x00 },
    );
}
