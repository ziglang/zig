const std = @import("../../std.zig");
const testing = std.testing;
const xz = std.compress.xz;

fn decompress(data: []const u8) ![]u8 {
    const gpa = testing.allocator;

    var in_stream: std.Io.Reader = .fixed(data);

    var xz_stream = try xz.Decompress.init(&in_stream, gpa, &.{});
    defer xz_stream.deinit();

    return xz_stream.reader.allocRemaining(gpa, .unlimited);
}

fn testReader(data: []const u8, expected: []const u8) !void {
    const gpa = testing.allocator;

    const result = try decompress(data);
    defer gpa.free(result);

    try testing.expectEqualSlices(u8, expected, result);
}

fn testDecompressError(expected: anyerror, compressed: []const u8) !void {
    const gpa = std.testing.allocator;
    var stream: std.Io.Reader = .fixed(compressed);

    var decompressor = try xz.Decompress.init(&stream, gpa, &.{});
    defer decompressor.deinit();

    try std.testing.expectError(error.ReadFailed, decompressor.reader.allocRemaining(gpa, .unlimited));
    try std.testing.expectEqual(expected, decompressor.err orelse return error.TestFailed);
}

test "fixture good-0-empty.xz" {
    try testReader(@embedFile("testdata/good-0-empty.xz"), "");
}

const hello_world_text =
    \\Hello
    \\World!
    \\
;

test "fixture good-1-check-none.xz" {
    try testReader(@embedFile("testdata/good-1-check-none.xz"), hello_world_text);
}

test "fixture good-1-check-crc32.xz" {
    try testReader(@embedFile("testdata/good-1-check-crc32.xz"), hello_world_text);
}

test "fixture good-1-check-crc64.xz" {
    try testReader(@embedFile("testdata/good-1-check-crc64.xz"), hello_world_text);
}

test "fixture good-1-check-sha256.xz" {
    try testReader(@embedFile("testdata/good-1-check-sha256.xz"), hello_world_text);
}

test "fixture good-2-lzma2.xz" {
    try testReader(@embedFile("testdata/good-2-lzma2.xz"), hello_world_text);
}

test "fixture good-1-block_header-1.xz" {
    try testReader(@embedFile("testdata/good-1-block_header-1.xz"), hello_world_text);
}

test "fixture good-1-block_header-2.xz" {
    try testReader(@embedFile("testdata/good-1-block_header-2.xz"), hello_world_text);
}

test "fixture good-1-block_header-3.xz" {
    try testReader(@embedFile("testdata/good-1-block_header-3.xz"), hello_world_text);
}

const lorem_ipsum_text =
    \\Lorem ipsum dolor sit amet, consectetur adipisicing 
    \\elit, sed do eiusmod tempor incididunt ut 
    \\labore et dolore magna aliqua. Ut enim 
    \\ad minim veniam, quis nostrud exercitation ullamco 
    \\laboris nisi ut aliquip ex ea commodo 
    \\consequat. Duis aute irure dolor in reprehenderit 
    \\in voluptate velit esse cillum dolore eu 
    \\fugiat nulla pariatur. Excepteur sint occaecat cupidatat 
    \\non proident, sunt in culpa qui officia 
    \\deserunt mollit anim id est laborum. 
    \\
;

test "fixture good-1-lzma2-1.xz" {
    try testReader(@embedFile("testdata/good-1-lzma2-1.xz"), lorem_ipsum_text);
}

test "fixture good-1-lzma2-2.xz" {
    try testReader(@embedFile("testdata/good-1-lzma2-2.xz"), lorem_ipsum_text);
}

test "fixture good-1-lzma2-3.xz" {
    try testReader(@embedFile("testdata/good-1-lzma2-3.xz"), lorem_ipsum_text);
}

test "fixture good-1-lzma2-4.xz" {
    try testReader(@embedFile("testdata/good-1-lzma2-4.xz"), lorem_ipsum_text);
}

test "fixture good-1-lzma2-5.xz" {
    try testReader(@embedFile("testdata/good-1-lzma2-5.xz"), "");
}

test "fixture good-1-delta-lzma2.tiff.xz" {
    try testDecompressError(error.Unsupported, @embedFile("testdata/good-1-delta-lzma2.tiff.xz"));
}

test "fixture good-1-x86-lzma2.xz" {
    try testDecompressError(error.Unsupported, @embedFile("testdata/good-1-x86-lzma2.xz"));
}

test "fixture good-1-sparc-lzma2.xz" {
    try testDecompressError(error.Unsupported, @embedFile("testdata/good-1-sparc-lzma2.xz"));
}

test "fixture good-1-arm64-lzma2-1.xz" {
    try testDecompressError(error.Unsupported, @embedFile("testdata/good-1-arm64-lzma2-1.xz"));
}

test "fixture good-1-arm64-lzma2-2.xz" {
    try testDecompressError(error.Unsupported, @embedFile("testdata/good-1-arm64-lzma2-2.xz"));
}

test "fixture good-1-3delta-lzma2.xz" {
    try testDecompressError(error.Unsupported, @embedFile("testdata/good-1-3delta-lzma2.xz"));
}

test "fixture good-1-empty-bcj-lzma2.xz" {
    try testDecompressError(error.Unsupported, @embedFile("testdata/good-1-empty-bcj-lzma2.xz"));
}

fn testDontPanic(data: []const u8) !void {
    const buf = decompress(data) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        else => return,
    };
    defer testing.allocator.free(buf);
}

test "size fields: integer overflow avoidance" {
    // These cases were found via fuzz testing and each previously caused
    // an integer overflow when decoding. We just want to ensure they no longer
    // cause a panic
    // TODO this not a sufficient way to test. tests should always check the result,
    // not merely ensure that the code does not crash.
    const header_size_overflow = "\xfd7zXZ\x00\x00\x01i\"\xde6z";
    try testDontPanic(header_size_overflow);
    const lzma2_chunk_size_overflow = "\xfd7zXZ\x00\x00\x01i\"\xde6\x02\x00!\x01\x08\x00\x00\x00\xd8\x0f#\x13\x01\xff\xff";
    try testDontPanic(lzma2_chunk_size_overflow);
    const backward_size_overflow = "\xfd7zXZ\x00\x00\x01i\"\xde6\x00\x00\x00\x00\x1c\xdfD!\x90B\x99\r\x01\x00\x00\xff\xff\x10\x00\x00\x00\x01DD\xff\xff\xff\x01";
    try testDontPanic(backward_size_overflow);
}
