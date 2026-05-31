const std = @import("../../std.zig");
const lzma = std.compress.lzma;

fn testDecompress(compressed: []const u8) ![]u8 {
    const gpa = std.testing.allocator;
    var stream: std.Io.Reader = .fixed(compressed);

    var decompressor = try lzma.Decompress.initOptions(&stream, gpa, &.{}, .{}, std.math.maxInt(u32));
    defer decompressor.deinit();
    return decompressor.reader.allocRemaining(gpa, .unlimited);
}

fn testDecompressEqual(expected: []const u8, compressed: []const u8) !void {
    const gpa = std.testing.allocator;
    const decomp = try testDecompress(compressed);
    defer gpa.free(decomp);
    try std.testing.expectEqualSlices(u8, expected, decomp);
}

fn testDecompressError(expected: anyerror, compressed: []const u8) !void {
    const gpa = std.testing.allocator;
    var stream: std.Io.Reader = .fixed(compressed);

    var decompressor = try lzma.Decompress.initOptions(&stream, gpa, &.{}, .{}, std.math.maxInt(u32));
    defer decompressor.deinit();

    try std.testing.expectError(error.ReadFailed, decompressor.reader.allocRemaining(gpa, .unlimited));
    try std.testing.expectEqual(expected, decompressor.err orelse return error.TestFailed);
}

test "decompress empty world" {
    try testDecompressEqual(
        "",
        &[_]u8{
            0x5d, 0x00, 0x00, 0x80, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x83, 0xff,
            0xfb, 0xff, 0xff, 0xc0, 0x00, 0x00, 0x00,
        },
    );
}

test "decompress hello world" {
    try testDecompressEqual(
        "Hello world\n",
        &[_]u8{
            0x5d, 0x00, 0x00, 0x80, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x24, 0x19,
            0x49, 0x98, 0x6f, 0x10, 0x19, 0xc6, 0xd7, 0x31, 0xeb, 0x36, 0x50, 0xb2, 0x98, 0x48, 0xff, 0xfe,
            0xa5, 0xb0, 0x00,
        },
    );
}

test "decompress huge dict" {
    try testDecompressEqual(
        "Hello world\n",
        &[_]u8{
            0x5d, 0x7f, 0x7f, 0x7f, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x24, 0x19,
            0x49, 0x98, 0x6f, 0x10, 0x19, 0xc6, 0xd7, 0x31, 0xeb, 0x36, 0x50, 0xb2, 0x98, 0x48, 0xff, 0xfe,
            0xa5, 0xb0, 0x00,
        },
    );
}

test "unknown size with end of payload marker" {
    try testDecompressEqual(
        "Hello\nWorld!\n",
        @embedFile("testdata/good-unknown_size-with_eopm.lzma"),
    );
}

test "known size without end of payload marker" {
    try testDecompressEqual(
        "Hello\nWorld!\n",
        @embedFile("testdata/good-known_size-without_eopm.lzma"),
    );
}

test "known size with end of payload marker" {
    try testDecompressEqual(
        "Hello\nWorld!\n",
        @embedFile("testdata/good-known_size-with_eopm.lzma"),
    );
}

test "too big uncompressed size in header" {
    try testDecompressError(
        error.DecompressedSizeMismatch,
        @embedFile("testdata/bad-too_big_size-with_eopm.lzma"),
    );
}

test "too small uncompressed size in header" {
    try testDecompressError(
        error.DecompressedSizeMismatch,
        @embedFile("testdata/bad-too_small_size-without_eopm-3.lzma"),
    );
}

test "reading one byte" {
    const gpa = std.testing.allocator;
    const compressed = @embedFile("testdata/good-known_size-with_eopm.lzma");
    var stream: std.Io.Reader = .fixed(compressed);
    var decompressor = try lzma.Decompress.initOptions(&stream, gpa, &.{}, .{}, std.math.maxInt(u32));
    defer decompressor.deinit();

    var buffer: [1]u8 = undefined;
    try decompressor.reader.readSliceAll(&buffer);
    try std.testing.expectEqual(72, buffer[0]);
}
